// Package store contains the SQL data-access functions. Every function takes
// a db.DBTX so callers decide on transaction boundaries.
package store

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/db"
	"tek-sensor-monitor/backend/internal/models"
)

const userCols = `id, login, password_hash, role::text, created_at, email, phone,
	promoted_by_user_id, updated_at, is_active`

func scanUser(row pgx.Row) (*models.User, error) {
	var u models.User
	err := row.Scan(&u.ID, &u.Login, &u.PasswordHash, &u.Role, &u.CreatedAt, &u.Email, &u.Phone,
		&u.PromotedByUserID, &u.UpdatedAt, &u.IsActive)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func collectUsers(rows pgx.Rows, err error) ([]models.User, error) {
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.User
	for rows.Next() {
		u, err := scanUser(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *u)
	}
	return out, rows.Err()
}

func GetUserByID(ctx context.Context, q db.DBTX, id int64) (*models.User, error) {
	return scanUser(q.QueryRow(ctx, `SELECT `+userCols+` FROM users WHERE id = $1`, id))
}

func GetUserByLogin(ctx context.Context, q db.DBTX, login string) (*models.User, error) {
	return scanUser(q.QueryRow(ctx, `SELECT `+userCols+` FROM users WHERE login = $1`, login))
}

// GetUserByEmail matches case-insensitively on an already-normalised email.
func GetUserByEmail(ctx context.Context, q db.DBTX, normalizedEmail string) (*models.User, error) {
	return scanUser(q.QueryRow(ctx, `SELECT `+userCols+` FROM users WHERE lower(email) = $1 LIMIT 1`, normalizedEmail))
}

// GetUserByPhone matches an already-normalised +7XXXXXXXXXX phone.
func GetUserByPhone(ctx context.Context, q db.DBTX, normalizedPhone string) (*models.User, error) {
	return scanUser(q.QueryRow(ctx, `SELECT `+userCols+` FROM users WHERE phone = $1 LIMIT 1`, normalizedPhone))
}

func ListUsers(ctx context.Context, q db.DBTX) ([]models.User, error) {
	return collectUsers(q.Query(ctx, `SELECT `+userCols+` FROM users ORDER BY id`))
}

func ListActiveUserIDs(ctx context.Context, q db.DBTX) ([]int64, error) {
	rows, err := q.Query(ctx, `SELECT id FROM users WHERE is_active IS true ORDER BY id`)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowTo[int64])
}

func CreateUser(ctx context.Context, q db.DBTX, login, passwordHash, role string) (*models.User, error) {
	return scanUser(q.QueryRow(ctx,
		`INSERT INTO users (login, password_hash, role) VALUES ($1, $2, $3::text::user_role)
		 RETURNING `+userCols, login, passwordHash, role))
}

// ProfileUpdate mirrors user_repository.update_profile keyword arguments.
type ProfileUpdate struct {
	Login        *string
	Email        *string // stored lower-cased/trimmed
	ClearEmail   bool
	Phone        *string
	ClearPhone   bool
	PasswordHash *string
}

func UpdateUserProfile(ctx context.Context, q db.DBTX, u *models.User, p ProfileUpdate) error {
	if p.Login != nil {
		u.Login = *p.Login
	}
	if p.ClearEmail {
		u.Email = nil
	} else if p.Email != nil {
		e := normalizeEmail(*p.Email)
		u.Email = &e
	}
	if p.ClearPhone {
		u.Phone = nil
	} else if p.Phone != nil {
		ph := *p.Phone
		u.Phone = &ph
	}
	if p.PasswordHash != nil {
		u.PasswordHash = *p.PasswordHash
	}
	_, err := q.Exec(ctx,
		`UPDATE users SET login = $2, email = $3, phone = $4, password_hash = $5 WHERE id = $1`,
		u.ID, u.Login, u.Email, u.Phone, u.PasswordHash)
	return err
}

func SetUserPasswordHash(ctx context.Context, q db.DBTX, userID int64, hash string) error {
	_, err := q.Exec(ctx, `UPDATE users SET password_hash = $2 WHERE id = $1`, userID, hash)
	return err
}

// SetUserRole sets role; promoted_by is kept only for admins (as before).
func SetUserRole(ctx context.Context, q db.DBTX, u *models.User, role string, promotedBy *int64) error {
	u.Role = role
	if role == models.RoleAdmin {
		u.PromotedByUserID = promotedBy
	} else {
		u.PromotedByUserID = nil
	}
	_, err := q.Exec(ctx, `UPDATE users SET role = $2::text::user_role, promoted_by_user_id = $3 WHERE id = $1`,
		u.ID, role, u.PromotedByUserID)
	return err
}
