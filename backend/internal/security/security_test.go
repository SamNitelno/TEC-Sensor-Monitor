package security

import (
	"strings"
	"testing"
)

// Fixtures generated with the former Python stack (passlib bcrypt, PyJWT).
const (
	passlibHash = "$2b$12$8hW2QtMhNkka/zNzqa9neuzx2BzKSXgXld3AOXzFe.vTMfXxIcU7a" // "Passw0rd-тест"
	pyjwtToken  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZG1pbiIsInVpZCI6MSwicm9sZSI6ImFkbWluIiwiZXhwIjo0MTAyNDQ0ODAwfQ.mC9N9-R3ei8AS_P3Fn4hUAKRG00m24R11ZBEZK_I6ts"
	pyjwtSecret = "secret-secret-secret-secret-secret"
)

func TestVerifiesPasslibBcryptHash(t *testing.T) {
	if !VerifyPassword("Passw0rd-тест", passlibHash) {
		t.Fatal("existing passlib hash rejected")
	}
	if VerifyPassword("wrong", passlibHash) {
		t.Fatal("wrong password accepted")
	}
}

func TestBcryptTruncatesLikePasslib(t *testing.T) {
	long := strings.Repeat("a", 80) + "1"
	h, err := HashPassword(long)
	if err != nil {
		t.Fatal(err)
	}
	if !VerifyPassword(strings.Repeat("a", 72), h) {
		t.Fatal("passwords longer than 72 bytes must be truncated")
	}
	if !strings.HasPrefix(h, "$2a$12$") && !strings.HasPrefix(h, "$2b$12$") {
		t.Fatalf("unexpected hash format %s", h)
	}
}

func TestDecodesPyJWTToken(t *testing.T) {
	c, err := DecodeAccessToken(pyjwtSecret, pyjwtToken)
	if err != nil {
		t.Fatal(err)
	}
	if c.Subject != "admin" || c.UID == nil || *c.UID != 1 || c.Role != "admin" {
		t.Fatalf("claims %+v", c)
	}
	if _, err := DecodeAccessToken("other-secret", pyjwtToken); err == nil {
		t.Fatal("bad signature accepted")
	}
}

func TestCreateAccessTokenRoundTrip(t *testing.T) {
	tok, err := CreateAccessToken("s3cr3t", 5, 42, "bob", "viewer")
	if err != nil {
		t.Fatal(err)
	}
	c, err := DecodeAccessToken("s3cr3t", tok)
	if err != nil || *c.UID != 42 || c.Subject != "bob" || c.Role != "viewer" || c.ExpiresAt == nil {
		t.Fatalf("claims %+v err %v", c, err)
	}
	expired, _ := CreateAccessToken("s3cr3t", -1, 42, "bob", "viewer")
	if _, err := DecodeAccessToken("s3cr3t", expired); err == nil {
		t.Fatal("expired token accepted")
	}
}

func TestDeviceTokenHashMatchesPython(t *testing.T) {
	if got := HashDeviceToken("abc", "pepper"); got != "911969fc1f463959e217f1d1535c3cfb64f953c0bd295136b39d29695f763204" {
		t.Fatalf("hash %s", got)
	}
	if !IsHashedDeviceToken(HashDeviceToken("x", "y")) || IsHashedDeviceToken("plain") {
		t.Fatal("IsHashedDeviceToken")
	}
	if tok := TokenURLSafe(32); len(tok) != 43 || strings.ContainsAny(tok, "+/=") {
		t.Fatalf("token %q", tok)
	}
}

func TestVerificationCodes(t *testing.T) {
	code := GenerateVerificationCode()
	if len(code) != 6 {
		t.Fatalf("code %q", code)
	}
	h := HashVerificationCode(code, "p")
	if !VerifyCodeHash(code, &h, "p") || VerifyCodeHash("000000x", &h, "p") || VerifyCodeHash(code, nil, "p") {
		t.Fatal("VerifyCodeHash")
	}
}
