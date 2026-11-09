// Package security contains JWT, password and device-token primitives.
// All formats are byte-compatible with the former Python implementation so
// existing password hashes, device tokens and issued JWTs remain valid.
package security

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

// BcryptCost matches passlib's default bcrypt rounds.
const BcryptCost = 12

// bcrypt (and passlib) only use the first 72 bytes of a password; Go's
// implementation rejects longer input instead of truncating, so truncate.
func truncate72(password string) []byte {
	b := []byte(password)
	if len(b) > 72 {
		b = b[:72]
	}
	return b
}

func HashPassword(password string) (string, error) {
	h, err := bcrypt.GenerateFromPassword(truncate72(password), BcryptCost)
	if err != nil {
		return "", err
	}
	return string(h), nil
}

func VerifyPassword(password, hash string) bool {
	if hash == "" {
		return false
	}
	return bcrypt.CompareHashAndPassword([]byte(hash), truncate72(password)) == nil
}

// Claims mirrors the payload {"sub", "uid", "role", "exp"}.
type Claims struct {
	UID  *int64 `json:"uid,omitempty"`
	Role string `json:"role,omitempty"`
	jwt.RegisteredClaims
}

func CreateAccessToken(secret string, expireMinutes int, userID int64, login, role string) (string, error) {
	uid := userID
	claims := Claims{
		UID:  &uid,
		Role: role,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   login,
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(expireMinutes) * time.Minute)),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(secret))
}

var ErrInvalidToken = errors.New("invalid token")

// DecodeAccessToken validates signature and expiry (HS256 only, no leeway).
func DecodeAccessToken(secret, token string) (*Claims, error) {
	claims := &Claims{}
	parsed, err := jwt.ParseWithClaims(token, claims, func(t *jwt.Token) (any, error) {
		return []byte(secret), nil
	}, jwt.WithValidMethods([]string{"HS256"}))
	if err != nil || !parsed.Valid {
		return nil, ErrInvalidToken
	}
	return claims, nil
}

// TokenURLSafe mirrors secrets.token_urlsafe(n).
func TokenURLSafe(nbytes int) string {
	b := make([]byte, nbytes)
	if _, err := rand.Read(b); err != nil {
		panic(fmt.Sprintf("crypto/rand failed: %v", err))
	}
	return base64.RawURLEncoding.EncodeToString(b)
}

func pepperedSHA256(value, pepper string) string {
	sum := sha256.Sum256([]byte(value + ":" + pepper))
	return hex.EncodeToString(sum[:])
}

// HashDeviceToken: sha256("<plaintext>:<JWT_SECRET>") as lowercase hex.
func HashDeviceToken(plaintext, pepper string) string {
	return pepperedSHA256(plaintext, pepper)
}

// IsHashedDeviceToken reports whether a stored token is a 64-char hex digest.
func IsHashedDeviceToken(value string) bool {
	if len(value) != 64 {
		return false
	}
	for _, c := range value {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
			return false
		}
	}
	return true
}

func ConstantTimeEqual(a, b string) bool {
	return subtle.ConstantTimeCompare([]byte(a), []byte(b)) == 1
}

// GenerateVerificationCode returns a zero-padded 6-digit code.
func GenerateVerificationCode() string {
	n, err := rand.Int(rand.Reader, big.NewInt(1_000_000))
	if err != nil {
		panic(fmt.Sprintf("crypto/rand failed: %v", err))
	}
	return fmt.Sprintf("%06d", n.Int64())
}

// HashVerificationCode: sha256("<code>:<JWT_SECRET>") as hex.
func HashVerificationCode(code, pepper string) string {
	return pepperedSHA256(code, pepper)
}

func VerifyCodeHash(code string, codeHash *string, pepper string) bool {
	if codeHash == nil || *codeHash == "" {
		return false
	}
	return ConstantTimeEqual(HashVerificationCode(code, pepper), *codeHash)
}
