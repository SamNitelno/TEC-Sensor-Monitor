package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"

	"tek-sensor-monitor/backend/internal/db"
	"tek-sensor-monitor/backend/internal/models"
)

const contactCols = `id, user_id, pending_login, pending_email, pending_phone, clear_email, clear_phone,
	email_code_hash, phone_code_hash, email_verified, failed_attempts, expires_at, created_at`

func scanContactBatch(row pgx.Row) (*models.ContactVerificationBatch, error) {
	var b models.ContactVerificationBatch
	err := row.Scan(&b.ID, &b.UserID, &b.PendingLogin, &b.PendingEmail, &b.PendingPhone, &b.ClearEmail,
		&b.ClearPhone, &b.EmailCodeHash, &b.PhoneCodeHash, &b.EmailVerified, &b.FailedAttempts,
		&b.ExpiresAt, &b.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &b, nil
}

// CreateContactBatch deletes the user's previous batches and inserts a new one.
func CreateContactBatch(ctx context.Context, q db.DBTX, b *models.ContactVerificationBatch) error {
	if _, err := q.Exec(ctx, `DELETE FROM contact_verification_batches WHERE user_id = $1`, b.UserID); err != nil {
		return err
	}
	_, err := q.Exec(ctx, `INSERT INTO contact_verification_batches
		(id, user_id, pending_login, pending_email, pending_phone, clear_email, clear_phone,
		 email_code_hash, phone_code_hash, email_verified, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
		b.ID, b.UserID, b.PendingLogin, b.PendingEmail, b.PendingPhone, b.ClearEmail, b.ClearPhone,
		b.EmailCodeHash, b.PhoneCodeHash, b.EmailVerified, b.ExpiresAt)
	return err
}

func GetContactBatchForUser(ctx context.Context, q db.DBTX, batchID string, userID int64) (*models.ContactVerificationBatch, error) {
	return scanContactBatch(q.QueryRow(ctx, `SELECT `+contactCols+` FROM contact_verification_batches
		WHERE id = $1 AND user_id = $2`, batchID, userID))
}

func SaveContactBatch(ctx context.Context, q db.DBTX, b *models.ContactVerificationBatch) error {
	_, err := q.Exec(ctx, `UPDATE contact_verification_batches SET email_code_hash = $2, phone_code_hash = $3,
		email_verified = $4, failed_attempts = $5 WHERE id = $1`,
		b.ID, b.EmailCodeHash, b.PhoneCodeHash, b.EmailVerified, b.FailedAttempts)
	return err
}

func IncrementContactAttempts(ctx context.Context, q db.DBTX, batchID string) error {
	_, err := q.Exec(ctx, `UPDATE contact_verification_batches SET failed_attempts = failed_attempts + 1 WHERE id = $1`, batchID)
	return err
}

func DeleteContactBatch(ctx context.Context, q db.DBTX, batchID string) error {
	_, err := q.Exec(ctx, `DELETE FROM contact_verification_batches WHERE id = $1`, batchID)
	return err
}

const resetCols = `id, user_id, channel, destination, code_hash, failed_attempts, expires_at, consumed_at, created_at`

func CreateResetBatch(ctx context.Context, q db.DBTX, userID int64, id, channel, destination, codeHash string, expiresAt time.Time) error {
	_, err := q.Exec(ctx, `INSERT INTO password_reset_batches (id, user_id, channel, destination, code_hash, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6)`, id, userID, channel, destination, codeHash, expiresAt)
	return err
}

// GetActiveResetBatch returns an unconsumed batch by id.
func GetActiveResetBatch(ctx context.Context, q db.DBTX, id string) (*models.PasswordResetBatch, error) {
	var b models.PasswordResetBatch
	err := q.QueryRow(ctx, `SELECT `+resetCols+` FROM password_reset_batches WHERE id = $1 AND consumed_at IS NULL`, id).
		Scan(&b.ID, &b.UserID, &b.Channel, &b.Destination, &b.CodeHash, &b.FailedAttempts, &b.ExpiresAt, &b.ConsumedAt, &b.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &b, nil
}

func IncrementResetAttempts(ctx context.Context, q db.DBTX, id string) error {
	_, err := q.Exec(ctx, `UPDATE password_reset_batches SET failed_attempts = failed_attempts + 1 WHERE id = $1`, id)
	return err
}

func DeleteResetBatchesForUser(ctx context.Context, q db.DBTX, userID int64) error {
	_, err := q.Exec(ctx, `DELETE FROM password_reset_batches WHERE user_id = $1`, userID)
	return err
}
