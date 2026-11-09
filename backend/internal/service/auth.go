package service

import (
	"context"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/apperr"
	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/security"
	"tek-sensor-monitor/backend/internal/store"
	"tek-sensor-monitor/backend/internal/validate"
)

func (s *Service) Capabilities() AuthCapabilitiesResponse {
	return AuthCapabilitiesResponse{
		PublicRegistration: s.Cfg.AllowPublicRegistration,
		PasswordReset:      s.Delivery.Ready(),
	}
}

// EnsurePublicRegistration returns 404 "Not found" when registration is off.
func (s *Service) EnsurePublicRegistration() error {
	if !s.Cfg.AllowPublicRegistration {
		return apperr.NotFound("Not found")
	}
	return nil
}

// EnsureVerificationFeatures returns 503 when codes cannot be delivered.
func (s *Service) EnsureVerificationFeatures() error {
	if !s.Delivery.Ready() {
		return apperr.Unavailable(FeatureInDevelopment)
	}
	return nil
}

func (s *Service) Login(ctx context.Context, login, password string) (*TokenResponse, error) {
	user, err := store.GetUserByLogin(ctx, s.Pool, login)
	if err != nil {
		return nil, err
	}
	if user == nil || !user.IsActive || !security.VerifyPassword(password, user.PasswordHash) {
		return nil, apperr.Unauthorized("Invalid login or password")
	}
	token, err := s.issueToken(user)
	if err != nil {
		return nil, err
	}
	return &TokenResponse{AccessToken: token, TokenType: "bearer", Role: user.Role}, nil
}

func (s *Service) Register(ctx context.Context, login, password string) (*TokenResponse, error) {
	if err := validate.Password(password); err != nil {
		return nil, apperr.BadRequest(err.Error())
	}
	existing, err := store.GetUserByLogin(ctx, s.Pool, login)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, apperr.Conflict("Login already taken")
	}
	hash, err := security.HashPassword(password)
	if err != nil {
		return nil, err
	}
	user, err := store.CreateUser(ctx, s.Pool, login, hash, models.RoleViewer)
	if err != nil {
		if isUniqueViolation(err) {
			return nil, apperr.Conflict("Login already taken")
		}
		return nil, err
	}
	token, err := s.issueToken(user)
	if err != nil {
		return nil, err
	}
	return &TokenResponse{AccessToken: token, TokenType: "bearer", Role: user.Role}, nil
}

func (s *Service) CheckLogin(ctx context.Context, login string) (*LoginAvailabilityResponse, error) {
	existing, err := store.GetUserByLogin(ctx, s.Pool, login)
	if err != nil {
		return nil, err
	}
	return &LoginAvailabilityResponse{Login: login, Available: existing == nil}, nil
}

func (s *Service) Profile(u *models.User) UserProfile { return toProfile(u) }

type ProfileUpdateRequest struct {
	Login      *string
	Email      *string
	ClearEmail bool
	Phone      *string
	ClearPhone bool
}

func strDiffers(v *string, current *string) bool {
	if v == nil {
		return false
	}
	return current == nil || *current != *v
}

func (s *Service) UpdateProfile(ctx context.Context, user *models.User, req ProfileUpdateRequest) (*ProfileUpdateResponse, error) {
	loginChanged := req.Login != nil && *req.Login != user.Login
	if loginChanged {
		existing, err := store.GetUserByLogin(ctx, s.Pool, *req.Login)
		if err != nil {
			return nil, err
		}
		if existing != nil && existing.ID != user.ID {
			return nil, apperr.Conflict("Login already taken")
		}
	}
	if strDiffers(req.Email, user.Email) {
		return nil, apperr.BadRequest("Email changes require verification. Use /auth/me/contact/send-codes")
	}
	if strDiffers(req.Phone, user.Phone) {
		return nil, apperr.BadRequest("Phone changes require verification. Use /auth/me/contact/send-codes")
	}
	err := store.UpdateUserProfile(ctx, s.Pool, user, store.ProfileUpdate{
		Login: req.Login, Email: req.Email, ClearEmail: req.ClearEmail, Phone: req.Phone, ClearPhone: req.ClearPhone,
	})
	if err != nil {
		if isUniqueViolation(err) {
			return nil, apperr.Conflict("Login already taken")
		}
		return nil, err
	}
	resp := &ProfileUpdateResponse{Profile: toProfile(user)}
	if loginChanged {
		token, err := s.issueToken(user)
		if err != nil {
			return nil, err
		}
		resp.AccessToken = &token
	}
	return resp, nil
}

func (s *Service) ChangePassword(ctx context.Context, user *models.User, current, next string) (*UserProfile, error) {
	if !security.VerifyPassword(current, user.PasswordHash) {
		return nil, apperr.BadRequest("Wrong current password")
	}
	if err := validate.Password(next); err != nil {
		return nil, apperr.BadRequest(err.Error())
	}
	hash, err := security.HashPassword(next)
	if err != nil {
		return nil, err
	}
	if err := store.SetUserPasswordHash(ctx, s.Pool, user.ID, hash); err != nil {
		return nil, err
	}
	user.PasswordHash = hash
	p := toProfile(user)
	return &p, nil
}

func (s *Service) ListUsers(ctx context.Context) ([]UserProfile, error) {
	users, err := store.ListUsers(ctx, s.Pool)
	if err != nil {
		return nil, err
	}
	out := make([]UserProfile, 0, len(users))
	for i := range users {
		out = append(out, toProfile(&users[i]))
	}
	return out, nil
}

func (s *Service) PromoteUser(ctx context.Context, actor *models.User, targetID int64) (*RoleChangeResponse, error) {
	if actor.Role != models.RoleAdmin {
		return nil, apperr.Forbidden("Admin only")
	}
	var target *models.User
	err := s.tx(ctx, func(tx pgx.Tx) error {
		var err error
		target, err = store.GetUserByID(ctx, tx, targetID)
		if err != nil {
			return err
		}
		if target == nil {
			return apperr.NotFound("User not found")
		}
		if target.Role == models.RoleAdmin {
			return apperr.BadRequest("Already admin")
		}
		actorID := actor.ID
		if err := store.SetUserRole(ctx, tx, target, models.RoleAdmin, &actorID); err != nil {
			return err
		}
		return store.CreateNotification(ctx, tx, target.ID,
			actor.Login+" повысил вас до уровня администратора", "role_promoted", s.now())
	})
	if err != nil {
		return nil, err
	}
	return &RoleChangeResponse{User: toProfile(target), Message: "User promoted to admin"}, nil
}

func (s *Service) DemoteUser(ctx context.Context, actor *models.User, targetID int64) (*RoleChangeResponse, error) {
	if actor.Role != models.RoleAdmin {
		return nil, apperr.Forbidden("Admin only")
	}
	if actor.ID == targetID {
		return nil, apperr.BadRequest("Use another admin to demote yourself")
	}
	var target *models.User
	err := s.tx(ctx, func(tx pgx.Tx) error {
		var err error
		target, err = store.GetUserByID(ctx, tx, targetID)
		if err != nil {
			return err
		}
		if target == nil {
			return apperr.NotFound("User not found")
		}
		if target.Role != models.RoleAdmin {
			return apperr.BadRequest("Already viewer")
		}
		ok, err := canDemoteAdmin(ctx, tx, actor, target)
		if err != nil {
			return err
		}
		if !ok {
			return apperr.Forbidden("You can only demote admins from your promotion branch")
		}
		if err := store.SetUserRole(ctx, tx, target, models.RoleViewer, nil); err != nil {
			return err
		}
		return store.CreateNotification(ctx, tx, target.ID,
			actor.Login+" понизил вас до уровня наблюдателя", "role_demoted", s.now())
	})
	if err != nil {
		return nil, err
	}
	return &RoleChangeResponse{User: toProfile(target), Message: "User demoted to viewer"}, nil
}

// canDemoteAdmin: the target must be in the actor's promotion tree. Root
// admins (promoted_by NULL) can never be demoted. A visited-set guards against
// promotion cycles (the Python version could loop forever).
func canDemoteAdmin(ctx context.Context, q pgx.Tx, actor, target *models.User) (bool, error) {
	if target.Role != models.RoleAdmin || target.PromotedByUserID == nil {
		return false, nil
	}
	if target.ID == actor.ID {
		return true, nil
	}
	visited := map[int64]bool{target.ID: true}
	current := target.PromotedByUserID
	for current != nil {
		if *current == actor.ID {
			return true, nil
		}
		if visited[*current] {
			return false, nil
		}
		visited[*current] = true
		promoter, err := store.GetUserByID(ctx, q, *current)
		if err != nil {
			return false, err
		}
		if promoter == nil {
			return false, nil
		}
		current = promoter.PromotedByUserID
	}
	return false, nil
}
