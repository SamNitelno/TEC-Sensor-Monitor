//go:build integration

package apitest

import (
	"context"
	"strconv"
	"testing"

	"tek-sensor-monitor/backend/internal/store"
)

func itoa(v int64) string { return strconv.FormatInt(v, 10) }

// ---- test_users.py ----

func TestRegisterAndLogin(t *testing.T) {
	login := unique("user_")
	r := do(t, "GET", "/api/v1/auth/check-login?login="+login, nil)
	expectStatus(t, r, 200)
	if r.json(t)["available"] != true {
		t.Fatalf("expected available: %s", r.body)
	}
	reg := do(t, "POST", "/api/v1/auth/register", map[string]string{"login": login, "password": "Passw0rd"})
	expectStatus(t, reg, 201)
	if reg.json(t)["role"] != "viewer" {
		t.Fatalf("role %s", reg.body)
	}
	r = do(t, "GET", "/api/v1/auth/check-login?login="+login, nil)
	if r.json(t)["available"] != false {
		t.Fatalf("expected taken: %s", r.body)
	}
	bad := do(t, "POST", "/api/v1/auth/register", map[string]string{"login": unique("weak_"), "password": "12345678"})
	if bad.status != 400 && bad.status != 422 {
		t.Fatalf("weak password status %d", bad.status)
	}
	if bad.json(t)["detail"] != "Пароль должен содержать латинские буквы" {
		t.Fatalf("detail %s", bad.body)
	}
	dup := do(t, "POST", "/api/v1/auth/register", map[string]string{"login": login, "password": "Passw0rd"})
	expectStatus(t, dup, 409)
	loginToken(t, login, "Passw0rd")
	short := do(t, "POST", "/api/v1/auth/register", map[string]string{"login": "ab", "password": "Passw0rd"})
	expectStatus(t, short, 422)
	if msg := short.json(t)["detail"].([]any)[0].(map[string]any)["msg"]; msg != "String should have at least 3 characters" {
		t.Fatalf("msg %v", msg)
	}
}

func TestProfileUpdateAndContactBinding(t *testing.T) {
	tok := adminToken(t)
	me := do(t, "GET", "/api/v1/auth/me", nil, bearer(tok))
	expectStatus(t, me, 200)
	if me.json(t)["login"] != "admin" {
		t.Fatalf("me %s", me.body)
	}
	email := unique("admin") + "@test.local"
	send := do(t, "POST", "/api/v1/auth/me/contact/send-codes", map[string]any{"email": email}, bearer(tok))
	expectStatus(t, send, 200)
	code, ok := env.svc.Delivery.TestCode("email", email)
	if !ok {
		t.Fatal("no test code recorded")
	}
	verify := do(t, "POST", "/api/v1/auth/me/contact/verify-email",
		map[string]any{"batch_id": send.json(t)["batch_id"], "code": code}, bearer(tok))
	expectStatus(t, verify, 200)
	if verify.json(t)["profile"].(map[string]any)["email"] != email {
		t.Fatalf("verify %s", verify.body)
	}
}

func TestPromoteDemoteHierarchy(t *testing.T) {
	tok := adminToken(t)
	login := unique("promo_")
	expectStatus(t, do(t, "POST", "/api/v1/auth/register", map[string]string{"login": login, "password": "Passw0rd"}), 201)
	users := do(t, "GET", "/api/v1/users", nil, bearer(tok)).list(t)
	var id int64
	for _, u := range users {
		m := u.(map[string]any)
		if m["login"] == login {
			id = int64(num(m["id"]))
		}
	}
	p := do(t, "POST", "/api/v1/users/"+itoa(id)+"/promote", nil, bearer(tok))
	expectStatus(t, p, 200)
	if p.json(t)["user"].(map[string]any)["role"] != "admin" || p.json(t)["message"] != "User promoted to admin" {
		t.Fatalf("promote %s", p.body)
	}
	expectStatus(t, do(t, "POST", "/api/v1/users/"+itoa(id)+"/promote", nil, bearer(tok)), 400)

	// The promoted admin cannot demote the root admin.
	promotedTok := loginToken(t, login, "Passw0rd")
	adminID := int64(num(do(t, "GET", "/api/v1/auth/me", nil, bearer(tok)).json(t)["id"]))
	r := do(t, "POST", "/api/v1/users/"+itoa(adminID)+"/demote", nil, bearer(promotedTok))
	expectStatus(t, r, 403)
	if r.json(t)["detail"] != "You can only demote admins from your promotion branch" {
		t.Fatalf("detail %s", r.body)
	}
	expectStatus(t, do(t, "POST", "/api/v1/users/"+itoa(adminID)+"/demote", nil, bearer(tok)), 400)

	d := do(t, "POST", "/api/v1/users/"+itoa(id)+"/demote", nil, bearer(tok))
	expectStatus(t, d, 200)
	if d.json(t)["user"].(map[string]any)["role"] != "viewer" || d.json(t)["user"].(map[string]any)["promoted_by_user_id"] != nil {
		t.Fatalf("demote %s", d.body)
	}
	// Role-change notifications were created for the target.
	notes := do(t, "GET", "/api/v1/notifications", nil, bearer(loginToken(t, login, "Passw0rd"))).list(t)
	if len(notes) < 2 {
		t.Fatalf("expected role notifications, got %v", notes)
	}
	expectStatus(t, do(t, "POST", "/api/v1/users/999999/promote", nil, bearer(tok)), 404)
}

func TestPromotionCycleDoesNotHang(t *testing.T) {
	ctx := context.Background()
	tok := adminToken(t)
	a, b := unique("cyca_"), unique("cycb_")
	for _, l := range []string{a, b} {
		expectStatus(t, do(t, "POST", "/api/v1/auth/register", map[string]string{"login": l, "password": "Passw0rd"}), 201)
	}
	ua, _ := store.GetUserByLogin(ctx, env.pool, a)
	ub, _ := store.GetUserByLogin(ctx, env.pool, b)
	// Forge a promotion cycle a <-> b directly in the DB.
	if _, err := env.pool.Exec(ctx, `UPDATE users SET role='admin', promoted_by_user_id=$2 WHERE id=$1`, ua.ID, ub.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := env.pool.Exec(ctx, `UPDATE users SET role='admin', promoted_by_user_id=$2 WHERE id=$1`, ub.ID, ua.ID); err != nil {
		t.Fatal(err)
	}
	// Root admin is not in the cycle: must answer 403 instead of looping forever.
	expectStatus(t, do(t, "POST", "/api/v1/users/"+itoa(ua.ID)+"/demote", nil, bearer(tok)), 403)
}

func TestEntityColors(t *testing.T) {
	tok := adminToken(t)
	r := do(t, "POST", "/api/v1/workshops", map[string]any{"name": "Red", "color": "#ff0000"}, bearer(tok))
	expectStatus(t, r, 201)
	if r.json(t)["color"] != "#FF0000" {
		t.Fatalf("color %s", r.body)
	}
	bad := do(t, "POST", "/api/v1/workshops", map[string]any{"name": "Bad", "color": "red"}, bearer(tok))
	expectStatus(t, bad, 422)
	if msg := bad.json(t)["detail"].([]any)[0].(map[string]any)["msg"]; msg != "Value error, Color must be in #RRGGBB format" {
		t.Fatalf("msg %v", msg)
	}
}

func TestAdminResetPassword(t *testing.T) {
	tok := adminToken(t)
	login := unique("reset_")
	expectStatus(t, do(t, "POST", "/api/v1/auth/register", map[string]string{"login": login, "password": "Passw0rd"}), 201)
	u, _ := store.GetUserByLogin(context.Background(), env.pool, login)
	r := do(t, "POST", "/api/v1/users/"+itoa(u.ID)+"/reset-password", map[string]string{"new_password": "NewPass123"}, bearer(tok))
	expectStatus(t, r, 200)
	if r.json(t)["message"] != "Password reset by administrator" {
		t.Fatalf("body %s", r.body)
	}
	loginToken(t, login, "NewPass123")
	expectStatus(t, do(t, "POST", "/api/v1/users/999999/reset-password", map[string]string{"new_password": "NewPass123"}, bearer(tok)), 404)
}

func TestChangePassword(t *testing.T) {
	login := unique("chpw_")
	expectStatus(t, do(t, "POST", "/api/v1/auth/register", map[string]string{"login": login, "password": "Passw0rd"}), 201)
	tok := loginToken(t, login, "Passw0rd")
	r := do(t, "POST", "/api/v1/auth/me/password", map[string]string{"current_password": "wrong", "new_password": "Passw0rd2"}, bearer(tok))
	expectStatus(t, r, 400)
	if r.json(t)["detail"] != "Wrong current password" {
		t.Fatalf("detail %s", r.body)
	}
	expectStatus(t, do(t, "POST", "/api/v1/auth/me/password", map[string]string{"current_password": "Passw0rd", "new_password": "Passw0rd2"}, bearer(tok)), 200)
	loginToken(t, login, "Passw0rd2")
	r = do(t, "POST", "/api/v1/auth/login", map[string]string{"login": login, "password": "Passw0rd"})
	expectStatus(t, r, 401)
	if r.json(t)["detail"] != "Invalid login or password" {
		t.Fatalf("detail %s", r.body)
	}
}

func TestLoginChangeIssuesNewToken(t *testing.T) {
	login := unique("rename_")
	expectStatus(t, do(t, "POST", "/api/v1/auth/register", map[string]string{"login": login, "password": "Passw0rd"}), 201)
	tok := loginToken(t, login, "Passw0rd")
	newLogin := unique("renamed_")
	r := do(t, "PATCH", "/api/v1/auth/me", map[string]any{"login": newLogin}, bearer(tok))
	expectStatus(t, r, 200)
	body := r.json(t)
	if body["access_token"] == nil || body["profile"].(map[string]any)["login"] != newLogin {
		t.Fatalf("body %s", r.body)
	}
	expectStatus(t, do(t, "PATCH", "/api/v1/auth/me", map[string]any{"login": "admin"}, bearer(tok)), 409)
	r = do(t, "PATCH", "/api/v1/auth/me", map[string]any{"email": "x@y.zz"}, bearer(tok))
	expectStatus(t, r, 400)
}
