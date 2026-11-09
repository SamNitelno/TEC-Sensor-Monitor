package service

import (
	"context"
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

const (
	genericResetMessage = "Если указанный контакт привязан к аккаунту, мы отправили код подтверждения."
	invalidCodeMessage  = "Неверный или просроченный код подтверждения"
)

func (s *Service) RequestPasswordReset(ctx context.Context, emailIn, phoneIn *string) (*PasswordResetRequestResponse, error) {
	if !s.Delivery.Ready() {
		return nil, apperr.Unavailable(FeatureInDevelopment)
	}
	var email, phone, channel string
	switch {
	case emailIn != nil && *emailIn != "":
		v, err := validate.Email(*emailIn)
		if err != nil {
			return nil, apperr.BadRequest(err.Error())
		}
		email, channel = v, "email"
		if !s.Delivery.ChannelReady("email") {
			return nil, apperr.Unavailable("Отправка email не настроена. Обратитесь к администратору.")
		}
	case phoneIn != nil && *phoneIn != "":
		v, err := validate.Phone(*phoneIn)
		if err != nil {
			return nil, apperr.BadRequest(err.Error())
		}
		phone, channel = v, "phone"
		if !s.Delivery.ChannelReady("phone") {
			return nil, apperr.Unavailable("Отправка SMS не настроена. Обратитесь к администратору.")
		}
	default:
		return nil, apperr.BadRequest("Укажите email или телефон")
	}

	batchID := uuid.NewString()
	var user *models.User
	var err error
	if email != "" {
		user, err = store.GetUserByEmail(ctx, s.Pool, email)
	} else {
		user, err = store.GetUserByPhone(ctx, s.Pool, phone)
	}
	if err != nil {
		return nil, err
	}

	if user != nil && user.IsActive {
		code := security.GenerateVerificationCode()
		destination := email
		if destination == "" {
			destination = phone
		}
		err := s.tx(ctx, func(tx pgx.Tx) error {
			if err := store.DeleteResetBatchesForUser(ctx, tx, user.ID); err != nil {
				return err
			}
			expires := s.now().Add(time.Duration(s.Cfg.VerificationCodeTTLMinutes) * time.Minute)
			return store.CreateResetBatch(ctx, tx, user.ID, batchID, channel, destination,
				security.HashVerificationCode(code, s.Cfg.JWTSecret), expires)
		})
		if err != nil {
			return nil, err
		}
		var sendErr error
		if channel == "email" {
			sendErr = s.Delivery.SendPasswordResetEmail(ctx, destination, code)
		} else {
			sendErr = s.Delivery.SendPasswordResetSMS(ctx, destination, code)
		}
		if sendErr != nil {
			return nil, apperr.BadGateway("Не удалось отправить код: " + delivery.FormatError(sendErr))
		}
	}

	masked := validate.MaskPhone(phone)
	if email != "" {
		masked = validate.MaskEmail(email)
	}
	return &PasswordResetRequestResponse{BatchID: batchID, DestinationMasked: masked, Message: genericResetMessage}, nil
}

func (s *Service) ConfirmPasswordReset(ctx context.Context, batchID, code, newPassword string) (*MessageResponse, error) {
	if !s.Delivery.Ready() {
		return nil, apperr.Unavailable(FeatureInDevelopment)
	}
	if err := validate.Password(newPassword); err != nil {
		return nil, apperr.BadRequest(err.Error())
	}
	batch, err := store.GetActiveResetBatch(ctx, s.Pool, batchID)
	if err != nil {
		return nil, err
	}
	if batch == nil {
		return nil, apperr.BadRequest(invalidCodeMessage)
	}
	if batch.ExpiresAt.Before(s.now()) {
		return nil, apperr.Gone(invalidCodeMessage)
	}
	if batch.FailedAttempts >= s.Cfg.VerificationMaxAttempts {
		return nil, apperr.TooMany("Слишком много попыток. Запросите новый код.")
	}
	codeHash := batch.CodeHash
	if !security.VerifyCodeHash(code, &codeHash, s.Cfg.JWTSecret) {
		if err := store.IncrementResetAttempts(ctx, s.Pool, batch.ID); err != nil {
			return nil, err
		}
		return nil, apperr.BadRequest(invalidCodeMessage)
	}
	user, err := store.GetUserByID(ctx, s.Pool, batch.UserID)
	if err != nil {
		return nil, err
	}
	if user == nil || !user.IsActive {
		return nil, apperr.BadRequest(invalidCodeMessage)
	}
	hash, err := security.HashPassword(newPassword)
	if err != nil {
		return nil, err
	}
	err = s.tx(ctx, func(tx pgx.Tx) error {
		if err := store.SetUserPasswordHash(ctx, tx, user.ID, hash); err != nil {
			return err
		}
		return store.DeleteResetBatchesForUser(ctx, tx, user.ID)
	})
	if err != nil {
		return nil, err
	}
	return &MessageResponse{Message: "Пароль успешно изменён. Войдите с новым паролем."}, nil
}

func (s *Service) AdminResetPassword(ctx context.Context, actor *models.User, targetID int64, newPassword string) (*MessageResponse, error) {
	if actor.Role != models.RoleAdmin {
		return nil, apperr.Forbidden("Admin only")
	}
	target, err := store.GetUserByID(ctx, s.Pool, targetID)
	if err != nil {
		return nil, err
	}
	if target == nil {
		return nil, apperr.NotFound("User not found")
	}
	if err := validate.Password(newPassword); err != nil {
		return nil, apperr.BadRequest(err.Error())
	}
	hash, err := security.HashPassword(newPassword)
	if err != nil {
		return nil, err
	}
	err = s.tx(ctx, func(tx pgx.Tx) error {
		if err := store.SetUserPasswordHash(ctx, tx, target.ID, hash); err != nil {
			return err
		}
		return store.DeleteResetBatchesForUser(ctx, tx, target.ID)
	})
	if err != nil {
		return nil, err
	}
	return &MessageResponse{Message: "Password reset by administrator"}, nil
}
