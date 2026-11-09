// Package validate holds input rules shared by the HTTP layer and services:
// password policy, email/phone normalisation, colours and masking helpers.
package validate

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"
)

// Password enforces the password policy (same order and messages as before).
func Password(password string) error {
	if utf8.RuneCountInString(password) < 8 {
		return errors.New("Пароль должен содержать не менее 8 символов")
	}
	hasDigit, hasLatin := false, false
	for _, r := range password {
		if unicode.IsDigit(r) {
			hasDigit = true
		}
		if (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') {
			hasLatin = true
		}
	}
	if !hasDigit {
		return errors.New("Пароль должен содержать хотя бы одну цифру")
	}
	if !hasLatin {
		return errors.New("Пароль должен содержать латинские буквы")
	}
	return nil
}

// NormalizeEmail trims and lowercases (Unicode-aware, like Python str.lower).
func NormalizeEmail(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
}

var emailRe = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)

// Email validates and normalises an email address.
func Email(value string) (string, error) {
	normalized := NormalizeEmail(value)
	if !emailRe.MatchString(normalized) || containsUnicodeSpace(normalized) {
		return "", errors.New("Invalid email format")
	}
	return normalized, nil
}

func containsUnicodeSpace(s string) bool {
	return strings.IndexFunc(s, unicode.IsSpace) >= 0
}

// digitsOnly mirrors Python's re.sub(r"\D", "", s): every Unicode decimal
// digit is kept as-is.
func digitsOnly(s string) []rune {
	var out []rune
	for _, r := range s {
		if unicode.IsDigit(r) {
			out = append(out, r)
		}
	}
	return out
}

// Phone normalises a Russian phone number to +7XXXXXXXXXX.
func Phone(value string) (string, error) {
	digits := digitsOnly(strings.TrimSpace(value))
	if len(digits) == 11 && digits[0] == '8' {
		digits = append([]rune{'7'}, digits[1:]...)
	}
	if len(digits) == 10 {
		digits = append([]rune{'7'}, digits...)
	}
	if len(digits) != 11 || digits[0] != '7' {
		return "", errors.New("Phone must be a Russian number, e.g. +79001234567")
	}
	return "+" + string(digits), nil
}

// MaskEmail hides the middle of the local part.
func MaskEmail(email string) string {
	local, domain, _ := strings.Cut(email, "@")
	runes := []rune(local)
	var masked string
	switch {
	case len(runes) == 0:
		masked = "*"
	case len(runes) <= 2:
		masked = string(runes[0]) + "*"
	default:
		masked = string(runes[0]) + strings.Repeat("*", len(runes)-2) + string(runes[len(runes)-1])
	}
	return masked + "@" + domain
}

// MaskPhone renders +7 *** ***-NN-NN.
func MaskPhone(phone string) string {
	d := digitsOnly(phone)
	if len(d) < 4 {
		return phone
	}
	return fmt.Sprintf("+%c *** ***-%s-%s", d[0], string(d[len(d)-4:len(d)-2]), string(d[len(d)-2:]))
}

var hexColorRe = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)

// Color validates #RRGGBB and returns it upper-cased.
func Color(value string) (string, error) {
	if !hexColorRe.MatchString(value) {
		return "", errors.New("Color must be in #RRGGBB format")
	}
	return strings.ToUpper(value), nil
}
