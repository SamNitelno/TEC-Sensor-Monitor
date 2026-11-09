//go:build integration

package apitest

import (
	"testing"
)

func newViewer(t *testing.T) (login, token string) {
	t.Helper()
	login = unique("cv_")
	expectStatus(t, do(t, "POST", "/api/v1/auth/register", map[string]string{"login": login, "password": "Passw0rd"}), 201)
	return login, loginToken(t, login, "Passw0rd")
}

// ---- test_contact_verification.py ----

func TestContactVerificationEmailThenPhone(t *testing.T) {
	_, tok := newViewer(t)
	email := unique("mail") + "@example.com"
	phone := "8 (900) " + unique("")[0:3] + "-11-22"
	send := do(t, "POST", "/api/v1/auth/me/contact/send-codes", map[string]any{"email": email, "phone": phone}, bearer(tok))
	expectStatus(t, send, 200)
	sb := send.json(t)
	if sb["step"] != "email" || sb["batch_id"] == "" || sb["message"] != "Код отправлен на email" {
		t.Fatalf("send %s", send.body)
	}
	code, _ := env.svc.Delivery.TestCode("email", email)
	ve := do(t, "POST", "/api/v1/auth/me/contact/verify-email", map[string]any{"batch_id": sb["batch_id"], "code": code}, bearer(tok))
	expectStatus(t, ve, 200)
	if ve.json(t)["step"] != "phone" {
		t.Fatalf("verify-email %s", ve.body)
	}
	normalized := "+7900" + phone[8:11] + "1122"
	pcode, ok := env.svc.Delivery.TestCode("phone", normalized)
	if !ok {
		t.Fatalf("no sms code for %s", normalized)
	}
	vp := do(t, "POST", "/api/v1/auth/me/contact/verify-phone", map[string]any{"batch_id": sb["batch_id"], "code": pcode}, bearer(tok))
	expectStatus(t, vp, 200)
	profile := vp.json(t)["profile"].(map[string]any)
	if vp.json(t)["step"] != "complete" || profile["email"] != email || profile["phone"] != normalized {
		t.Fatalf("verify-phone %s", vp.body)
	}
}

func TestProfileUpdateLoginOnly(t *testing.T) {
	login, tok := newViewer(t)
	r := do(t, "POST", "/api/v1/auth/me/contact/send-codes", map[string]any{"login": login}, bearer(tok))
	expectStatus(t, r, 200)
	b := r.json(t)
	if b["step"] != "complete" || b["message"] != "Изменений не обнаружено" || b["batch_id"] != "" {
		t.Fatalf("body %s", r.body)
	}
}

func TestDirectEmailPatchBlocked(t *testing.T) {
	_, tok := newViewer(t)
	r := do(t, "PATCH", "/api/v1/auth/me", map[string]any{"email": "new@example.com"}, bearer(tok))
	expectStatus(t, r, 400)
	if r.json(t)["detail"] != "Email changes require verification. Use /auth/me/contact/send-codes" {
		t.Fatalf("detail %s", r.body)
	}
}

// Bug fix: invalid email/phone used to produce a 500.
func TestSendCodesInvalidContactIs400(t *testing.T) {
	_, tok := newViewer(t)
	r := do(t, "POST", "/api/v1/auth/me/contact/send-codes", map[string]any{"email": "not-an-email"}, bearer(tok))
	expectStatus(t, r, 400)
	if r.json(t)["detail"] != "Invalid email format" {
		t.Fatalf("detail %s", r.body)
	}
	r = do(t, "POST", "/api/v1/auth/me/contact/send-codes", map[string]any{"phone": "123"}, bearer(tok))
	expectStatus(t, r, 400)
	if r.json(t)["detail"] != "Phone must be a Russian number, e.g. +79001234567" {
		t.Fatalf("detail %s", r.body)
	}
}

// Bug fix: failed verification attempts are persisted and limited.
func TestContactVerificationAttemptLimit(t *testing.T) {
	_, tok := newViewer(t)
	email := unique("lim") + "@example.com"
	send := do(t, "POST", "/api/v1/auth/me/contact/send-codes", map[string]any{"email": email}, bearer(tok))
	expectStatus(t, send, 200)
	batch := send.json(t)["batch_id"]
	for i := 0; i < env.cfg.VerificationMaxAttempts; i++ {
		r := do(t, "POST", "/api/v1/auth/me/contact/verify-email", map[string]any{"batch_id": batch, "code": "0000000"}, bearer(tok))
		expectStatus(t, r, 400)
		if r.json(t)["detail"] != "Invalid verification code" {
			t.Fatalf("detail %s", r.body)
		}
	}
	r := do(t, "POST", "/api/v1/auth/me/contact/verify-email", map[string]any{"batch_id": batch, "code": "0000000"}, bearer(tok))
	expectStatus(t, r, 429)
	if r.json(t)["detail"] != "Too many verification attempts" {
		t.Fatalf("detail %s", r.body)
	}
	expectStatus(t, do(t, "POST", "/api/v1/auth/me/contact/verify-email", map[string]any{"batch_id": "nope", "code": "1234"}, bearer(tok)), 404)
}

func TestEmailAlreadyTaken(t *testing.T) {
	_, tok1 := newViewer(t)
	email := unique("dup") + "@example.com"
	send := do(t, "POST", "/api/v1/auth/me/contact/send-codes", map[string]any{"email": email}, bearer(tok1))
	code, _ := env.svc.Delivery.TestCode("email", email)
	expectStatus(t, do(t, "POST", "/api/v1/auth/me/contact/verify-email", map[string]any{"batch_id": send.json(t)["batch_id"], "code": code}, bearer(tok1)), 200)
	_, tok2 := newViewer(t)
	r := do(t, "POST", "/api/v1/auth/me/contact/send-codes", map[string]any{"email": "  " + email + " "}, bearer(tok2))
	expectStatus(t, r, 409)
	if r.json(t)["detail"] != "Email already taken" {
		t.Fatalf("detail %s", r.body)
	}
}

// ---- test_password_reset.py ----

func TestPasswordResetSameResponseUnknownUser(t *testing.T) {
	r := do(t, "POST", "/api/v1/auth/password-reset/request", map[string]any{"email": "nobody-" + unique("") + "@example.com"})
	expectStatus(t, r, 200)
	b := r.json(t)
	if b["batch_id"] == "" || b["message"] != "Если указанный контакт привязан к аккаунту, мы отправили код подтверждения." {
		t.Fatalf("body %s", r.body)
	}
	expectStatus(t, do(t, "POST", "/api/v1/auth/password-reset/request", map[string]any{}), 400)
}

func TestPasswordResetFlowWithTestDelivery(t *testing.T) {
	login, tok := newViewer(t)
	email := unique("rst") + "@example.com"
	send := do(t, "POST", "/api/v1/auth/me/contact/send-codes", map[string]any{"email": email}, bearer(tok))
	code, _ := env.svc.Delivery.TestCode("email", email)
	expectStatus(t, do(t, "POST", "/api/v1/auth/me/contact/verify-email", map[string]any{"batch_id": send.json(t)["batch_id"], "code": code}, bearer(tok)), 200)

	req := do(t, "POST", "/api/v1/auth/password-reset/request", map[string]any{"email": email})
	expectStatus(t, req, 200)
	rb := req.json(t)
	if rb["destination_masked"] == email {
		t.Fatalf("destination not masked: %v", rb)
	}
	resetCode, _ := env.svc.Delivery.TestCode("email", email)
	conf := do(t, "POST", "/api/v1/auth/password-reset/confirm", map[string]any{
		"batch_id": rb["batch_id"], "code": resetCode, "new_password": "Reset1234",
	})
	expectStatus(t, conf, 200)
	if conf.json(t)["message"] != "Пароль успешно изменён. Войдите с новым паролем." {
		t.Fatalf("body %s", conf.body)
	}
	loginToken(t, login, "Reset1234")
	// The batch is consumed.
	expectStatus(t, do(t, "POST", "/api/v1/auth/password-reset/confirm", map[string]any{
		"batch_id": rb["batch_id"], "code": resetCode, "new_password": "Reset1234",
	}), 400)
}

func TestPasswordResetInvalidCode(t *testing.T) {
	r := do(t, "POST", "/api/v1/auth/password-reset/confirm", map[string]any{
		"batch_id": "00000000-0000-0000-0000-000000000000", "code": "123456", "new_password": "Reset1234",
	})
	expectStatus(t, r, 400)
	if r.json(t)["detail"] != "Неверный или просроченный код подтверждения" {
		t.Fatalf("detail %s", r.body)
	}
}
