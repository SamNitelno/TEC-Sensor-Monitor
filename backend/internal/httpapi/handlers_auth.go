package httpapi

import (
	"net/http"

	"tek-sensor-monitor/backend/internal/service"
)

func (a *API) capabilities(c *rc) (int, any, error) {
	return http.StatusOK, a.svc.Capabilities(), nil
}

func (a *API) login(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	b := c.object()
	login, _ := b.str("login", true, false, 0, 0)
	password, _ := b.str("password", true, false, 0, 0)
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	if err := c.rateLimit("auth_login", a.svc.Cfg.AuthLoginRateLimit); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.Login(c.r.Context(), *login, *password)
	return http.StatusOK, resp, err
}

func (a *API) register(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	b := c.object()
	login, _ := b.str("login", true, false, 3, 64)
	password, _ := b.str("password", true, false, 8, 128)
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	if err := c.rateLimit("auth_register", a.svc.Cfg.AuthRegisterRateLimit); err != nil {
		return 0, nil, err
	}
	if err := a.svc.EnsurePublicRegistration(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.Register(c.r.Context(), *login, *password)
	return http.StatusCreated, resp, err
}

func (a *API) checkLogin(c *rc) (int, any, error) {
	login := c.queryStr("login", true, 3, 64)
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	if err := c.rateLimit("auth_check_login", a.svc.Cfg.AuthLoginRateLimit); err != nil {
		return 0, nil, err
	}
	if err := a.svc.EnsurePublicRegistration(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.CheckLogin(c.r.Context(), *login)
	return http.StatusOK, resp, err
}

func (a *API) me(c *rc) (int, any, error) {
	user, err := c.currentUser()
	if err != nil {
		return 0, nil, err
	}
	return http.StatusOK, a.svc.Profile(user), nil
}

// profileFields parses ProfileUpdateRequest / ContactSendCodesRequest.
func profileFields(b *obj) service.ProfileUpdateRequest {
	login, _ := b.str("login", false, true, 3, 64)
	email, _ := b.str("email", false, true, 0, 255)
	clearEmail := b.boolean("clear_email", false)
	phone, _ := b.str("phone", false, true, 0, 32)
	clearPhone := b.boolean("clear_phone", false)
	return service.ProfileUpdateRequest{Login: login, Email: email, ClearEmail: clearEmail, Phone: phone, ClearPhone: clearPhone}
}

func (a *API) updateMe(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	user, err := c.currentUser()
	if err != nil {
		return 0, nil, err
	}
	req := profileFields(c.object())
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.UpdateProfile(c.r.Context(), user, req)
	return http.StatusOK, resp, err
}

func (a *API) changePassword(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	user, err := c.currentUser()
	if err != nil {
		return 0, nil, err
	}
	b := c.object()
	current, _ := b.str("current_password", true, false, 0, 0)
	next, _ := b.str("new_password", true, false, 8, 128)
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.ChangePassword(c.r.Context(), user, *current, *next)
	return http.StatusOK, resp, err
}

func (a *API) passwordResetRequest(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	b := c.object()
	email, _ := b.str("email", false, true, 0, 255)
	phone, _ := b.str("phone", false, true, 0, 32)
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	if err := c.rateLimit("password_reset_request", a.svc.Cfg.AuthVerifyRateLimit); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.RequestPasswordReset(c.r.Context(), email, phone)
	return http.StatusOK, resp, err
}

func (a *API) passwordResetConfirm(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	b := c.object()
	batchID, _ := b.str("batch_id", true, false, 0, 0)
	code, _ := b.str("code", true, false, 4, 8)
	newPassword, _ := b.str("new_password", true, false, 8, 128)
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	if err := c.rateLimit("password_reset_confirm", a.svc.Cfg.AuthVerifyRateLimit); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.ConfirmPasswordReset(c.r.Context(), *batchID, *code, *newPassword)
	return http.StatusOK, resp, err
}

func (a *API) sendContactCodes(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	user, err := c.currentUser()
	if err != nil {
		return 0, nil, err
	}
	req := profileFields(c.object())
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	if err := c.rateLimit("contact_send_codes", a.svc.Cfg.AuthVerifyRateLimit); err != nil {
		return 0, nil, err
	}
	if err := a.svc.EnsureVerificationFeatures(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.SendContactCodes(c.r.Context(), user, req)
	return http.StatusOK, resp, err
}

func (a *API) verifyContact(channel string) handlerFunc {
	return func(c *rc) (int, any, error) {
		if err := c.readBody(); err != nil {
			return 0, nil, err
		}
		user, err := c.currentUser()
		if err != nil {
			return 0, nil, err
		}
		b := c.object()
		batchID, _ := b.str("batch_id", true, false, 0, 0)
		code, _ := b.str("code", true, false, 4, 8)
		if err := c.checkValidation(); err != nil {
			return 0, nil, err
		}
		if err := c.rateLimit("contact_verify_"+channel, a.svc.Cfg.AuthVerifyRateLimit); err != nil {
			return 0, nil, err
		}
		if err := a.svc.EnsureVerificationFeatures(); err != nil {
			return 0, nil, err
		}
		resp, err := a.svc.VerifyContactCode(c.r.Context(), user, *batchID, *code, channel)
		return http.StatusOK, resp, err
	}
}

// ---- users -------------------------------------------------------------------

func (a *API) listUsers(c *rc) (int, any, error) {
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.ListUsers(c.r.Context())
	return http.StatusOK, resp, err
}

func (a *API) adminResetPassword(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	actor, err := c.admin()
	if err != nil {
		return 0, nil, err
	}
	id := c.pathInt("user_id")
	b := c.object()
	pw, _ := b.str("new_password", true, false, 8, 128)
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.AdminResetPassword(c.r.Context(), actor, id, *pw)
	return http.StatusOK, resp, err
}

func (a *API) promoteUser(c *rc) (int, any, error) {
	actor, err := c.admin()
	if err != nil {
		return 0, nil, err
	}
	id := c.pathInt("user_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.PromoteUser(c.r.Context(), actor, id)
	return http.StatusOK, resp, err
}

func (a *API) demoteUser(c *rc) (int, any, error) {
	actor, err := c.admin()
	if err != nil {
		return 0, nil, err
	}
	id := c.pathInt("user_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.DemoteUser(c.r.Context(), actor, id)
	return http.StatusOK, resp, err
}

// ---- notifications --------------------------------------------------------------

func (a *API) listNotifications(c *rc) (int, any, error) {
	user, err := c.currentUser()
	if err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.ListUnreadNotifications(c.r.Context(), user)
	return http.StatusOK, resp, err
}

func (a *API) unreadCount(c *rc) (int, any, error) {
	user, err := c.currentUser()
	if err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.UnreadCount(c.r.Context(), user)
	return http.StatusOK, resp, err
}

func (a *API) ackAll(c *rc) (int, any, error) {
	user, err := c.currentUser()
	if err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.AcknowledgeAll(c.r.Context(), user)
	return http.StatusOK, resp, err
}

func (a *API) ackNotification(c *rc) (int, any, error) {
	user, err := c.currentUser()
	if err != nil {
		return 0, nil, err
	}
	id := c.pathInt("notification_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.AcknowledgeNotification(c.r.Context(), user, id)
	return http.StatusOK, resp, err
}
