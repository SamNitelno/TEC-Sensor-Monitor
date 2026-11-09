package service

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/apperr"
	"tek-sensor-monitor/backend/internal/delivery"
	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/security"
	"tek-sensor-monitor/backend/internal/store"
	"tek-sensor-monitor/backend/internal/validate"
)

// validatePendingValues checks uniqueness of requested login/email/phone.
// Invalid email/phone formats now return 400 (they were a 500 before).
func (s *Service) validatePendingValues(ctx context.Context, user *models.User, req ProfileUpdateRequest) (login, email, phone *string, err error) {
	if req.Login != nil && *req.Login != "" {
		trimmed := strings.TrimSpace(*req.Login)
		if trimmed != user.Login {
			login = &trimmed
		}
	}
	if login != nil {
		existing, err := store.GetUserByLogin(ctx, s.Pool, *login)
		if err != nil {
			return nil, nil, nil, err
		}
		if existing != nil && existing.ID != user.ID {
			return nil, nil, nil, apperr.Conflict("Login already taken")
		}
	}
	if req.Email != nil && !req.ClearEmail {
		v, verr := validate.Email(*req.Email)
		if verr != nil {
			return nil, nil, nil, apperr.BadRequest(verr.Error())
		}
		email = &v
		existing, err := store.GetUserByEmail(ctx, s.Pool, v)
		if err != nil {
			return nil, nil, nil, err
		}
		if existing != nil && existing.ID != user.ID {
			return nil, nil, nil, apperr.Conflict("Email already taken")
		}
	}
	if req.Phone != nil && !req.ClearPhone {
		v, verr := validate.Phone(*req.Phone)
		if verr != nil {
			return nil, nil, nil, apperr.BadRequest(verr.Error())
		}
		phone = &v
		existing, err := store.GetUserByPhone(ctx, s.Pool, v)
		if err != nil {
			return nil, nil, nil, err
		}
		if existing != nil && existing.ID != user.ID {
			return nil, nil, nil, apperr.Conflict("Phone already taken")
		}
	}
	return login, email, phone, nil
}

func needsEmailVerification(user *models.User, email *string, clear bool) bool {
	if clear || email == nil {
		return false
	}
	return !(user.Email != nil && *user.Email != "" && validate.NormalizeEmail(*user.Email) == *email)
}

func needsPhoneVerification(user *models.User, phone *string, clear bool) bool {
	if clear || phone == nil {
		return false
	}
	if user.Phone != nil && *user.Phone != "" {
		if current, err := validate.Phone(*user.Phone); err == nil && current == *phone {
			return false
		}
	}
	return true
}

func (s *Service) SendContactCodes(ctx context.Context, user *models.User, req ProfileUpdateRequest) (*ContactSendCodesResponse, error) {
	if !s.Delivery.Ready() {
		return nil, apperr.Unavailable(FeatureInDevelopment)
	}
	pendingLogin, pendingEmail, pendingPhone, err := s.validatePendingValues(ctx, user, req)
	if err != nil {
		return nil, err
	}
	needsEmail := needsEmailVerification(user, pendingEmail, req.ClearEmail)
	needsPhone := needsPhoneVerification(user, pendingPhone, req.ClearPhone)
	hasDirectChanges := pendingLogin != nil || req.ClearEmail || req.ClearPhone

	if !needsEmail && !needsPhone {
		if !hasDirectChanges {
			p := toProfile(user)
			return &ContactSendCodesResponse{Step: "complete", Message: "Изменений не обнаружено", Profile: &p}, nil
		}
		err := store.UpdateUserProfile(ctx, s.Pool, user, store.ProfileUpdate{
			Login: pendingLogin, ClearEmail: req.ClearEmail, ClearPhone: req.ClearPhone,
		})
		if err != nil {
			if isUniqueViolation(err) {
				return nil, apperr.Conflict("Login already taken")
			}
			return nil, err
		}
		p := toProfile(user)
		resp := &ContactSendCodesResponse{Step: "complete", Message: "Профиль сохранён", Profile: &p}
		if pendingLogin != nil {
			token, err := s.issueToken(user)
			if err != nil {
				return nil, err
			}
			resp.AccessToken = &token
		}
		return resp, nil
	}

	code := security.GenerateVerificationCode()
	codeHash := security.HashVerificationCode(code, s.Cfg.JWTSecret)
	batch := &models.ContactVerificationBatch{
		ID:           uuid.NewString(),
		UserID:       user.ID,
		PendingLogin: pendingLogin,
		ClearEmail:   req.ClearEmail,
		ClearPhone:   req.ClearPhone,
		ExpiresAt:    s.now().Add(time.Duration(s.Cfg.VerificationCodeTTLMinutes) * time.Minute),
	}
	if needsEmail {
		batch.PendingEmail = pendingEmail
		if needsPhone {
			batch.PendingPhone = pendingPhone
		}
		batch.EmailCodeHash = &codeHash
	} else {
		batch.PendingPhone = pendingPhone
		batch.PhoneCodeHash = &codeHash
	}
	if err := s.tx(ctx, func(tx pgx.Tx) error { return store.CreateContactBatch(ctx, tx, batch) }); err != nil {
		return nil, err
	}

	if needsEmail {
		if err := s.Delivery.SendEmailVerificationCode(ctx, *pendingEmail, code); err != nil {
			return nil, apperr.BadGateway("Не удалось отправить код на email: " + delivery.FormatError(err))
		}
		return &ContactSendCodesResponse{
			BatchID: batch.ID, Step: "email", DestinationMasked: strPtr(validate.MaskEmail(*pendingEmail)),
			Message: "Код отправлен на email",
		}, nil
	}
	if err := s.Delivery.SendSMSVerificationCode(ctx, *pendingPhone, code); err != nil {
		return nil, apperr.BadGateway("Не удалось отправить SMS: " + delivery.FormatError(err))
	}
	return &ContactSendCodesResponse{
		BatchID: batch.ID, Step: "phone", DestinationMasked: strPtr(validate.MaskPhone(*pendingPhone)),
		Message: "Код отправлен в SMS",
	}, nil
}

// VerifyContactCode handles verify-email (channel "email") and verify-phone.
// Failed attempts are now persisted, so the attempt limit actually applies.
func (s *Service) VerifyContactCode(ctx context.Context, user *models.User, batchID, code, channel string) (*ContactVerifyCodeResponse, error) {
	batch, err := store.GetContactBatchForUser(ctx, s.Pool, batchID, user.ID)
	if err != nil {
		return nil, err
	}
	if batch == nil {
		return nil, apperr.NotFound("Verification batch not found")
	}
	if batch.ExpiresAt.Before(s.now()) {
		return nil, apperr.Gone("Verification code expired")
	}
	if batch.FailedAttempts >= s.Cfg.VerificationMaxAttempts {
		return nil, apperr.TooMany("Too many verification attempts")
	}

	invalid := func() error {
		if err := store.IncrementContactAttempts(ctx, s.Pool, batch.ID); err != nil {
			return err
		}
		return apperr.BadRequest("Invalid verification code")
	}

	if channel == "email" {
		if !security.VerifyCodeHash(code, batch.EmailCodeHash, s.Cfg.JWTSecret) {
			return nil, invalid()
		}
		batch.EmailVerified = true
		batch.EmailCodeHash = nil
		if batch.PendingPhone != nil {
			phoneCode := security.GenerateVerificationCode()
			h := security.HashVerificationCode(phoneCode, s.Cfg.JWTSecret)
			batch.PhoneCodeHash = &h
			if err := store.SaveContactBatch(ctx, s.Pool, batch); err != nil {
				return nil, err
			}
			if err := s.Delivery.SendSMSVerificationCode(ctx, *batch.PendingPhone, phoneCode); err != nil {
				return nil, apperr.BadGateway("Email подтверждён, но SMS не отправлено: " + delivery.FormatError(err))
			}
			return &ContactVerifyCodeResponse{
				Step: "phone", DestinationMasked: strPtr(validate.MaskPhone(*batch.PendingPhone)),
				Message: "Email подтверждён. Код отправлен в SMS",
			}, nil
		}
		return s.applyContactBatch(ctx, user, batch)
	}

	if !batch.EmailVerified && batch.PendingEmail != nil {
		return nil, apperr.BadRequest("Confirm email before phone")
	}
	if !security.VerifyCodeHash(code, batch.PhoneCodeHash, s.Cfg.JWTSecret) {
		return nil, invalid()
	}
	return s.applyContactBatch(ctx, user, batch)
}

func (s *Service) applyContactBatch(ctx context.Context, user *models.User, batch *models.ContactVerificationBatch) (*ContactVerifyCodeResponse, error) {
	err := s.tx(ctx, func(tx pgx.Tx) error {
		if err := store.UpdateUserProfile(ctx, tx, user, store.ProfileUpdate{
			Login: batch.PendingLogin, Email: batch.PendingEmail, ClearEmail: batch.ClearEmail,
			Phone: batch.PendingPhone, ClearPhone: batch.ClearPhone,
		}); err != nil {
			return err
		}
		return store.DeleteContactBatch(ctx, tx, batch.ID)
	})
	if err != nil {
		if isUniqueViolation(err) {
			return nil, apperr.Conflict("Login already taken")
		}
		return nil, err
	}
	p := toProfile(user)
	resp := &ContactVerifyCodeResponse{Step: "complete", Message: "Профиль сохранён", Profile: &p}
	if batch.PendingLogin != nil {
		token, err := s.issueToken(user)
		if err != nil {
			return nil, err
		}
		resp.AccessToken = &token
	}
	return resp, nil
}
