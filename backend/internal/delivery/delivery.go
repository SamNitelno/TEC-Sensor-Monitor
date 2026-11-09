// Package delivery sends verification / password-reset codes by email
// (SMTP with STARTTLS) or SMS (sms.ru), or records them in-memory ("test")
// or only logs them ("log"), depending on VERIFICATION_DELIVERY_MODE.
package delivery

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"mime"
	"net"
	"net/http"
	"net/smtp"
	"net/textproto"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"tek-sensor-monitor/backend/internal/config"
	"tek-sensor-monitor/backend/internal/validate"
)

// Delivery is safe for concurrent use.
type Delivery struct {
	cfg *config.Config
	log *slog.Logger

	mu        sync.Mutex
	testCodes map[string]string

	// SMSEndpoint can be overridden in tests.
	SMSEndpoint string
	httpClient  *http.Client
}

func New(cfg *config.Config, log *slog.Logger) *Delivery {
	return &Delivery{
		cfg:         cfg,
		log:         log,
		testCodes:   map[string]string{},
		SMSEndpoint: "https://sms.ru/sms/send",
		httpClient:  &http.Client{Timeout: 20 * time.Second},
	}
}

func (d *Delivery) mode() string {
	return strings.ToLower(strings.TrimSpace(d.cfg.VerificationDeliveryMode))
}

func (d *Delivery) hasEmail() bool {
	return strings.TrimSpace(d.cfg.VerificationSMTPUser) != "" && strings.TrimSpace(d.cfg.VerificationSMTPPassword) != ""
}

func (d *Delivery) hasSMS() bool { return strings.TrimSpace(d.cfg.VerificationSMSAPIID) != "" }

// Ready reports whether codes can reach users at all.
func (d *Delivery) Ready() bool {
	switch d.mode() {
	case "test":
		return true
	case "production":
		return d.hasEmail() || d.hasSMS()
	case "log":
		return !d.cfg.IsProduction()
	}
	return false
}

// ChannelReady reports readiness of "email" or "phone".
func (d *Delivery) ChannelReady(channel string) bool {
	switch d.mode() {
	case "test":
		return true
	case "log":
		return !d.cfg.IsProduction()
	case "production":
		switch channel {
		case "email":
			return d.hasEmail()
		case "phone":
			return d.hasSMS()
		}
	}
	return false
}

// TestCode returns the last code sent to destination in "test" mode.
func (d *Delivery) TestCode(channel, destination string) (string, bool) {
	d.mu.Lock()
	defer d.mu.Unlock()
	c, ok := d.testCodes[channel+":"+destination]
	return c, ok
}

func (d *Delivery) remember(channel, destination, code string) {
	if d.mode() != "test" {
		return
	}
	d.mu.Lock()
	d.testCodes[channel+":"+destination] = code
	d.mu.Unlock()
}

// ErrSMTPAuth marks SMTP authentication failures (rendered with a hint).
var ErrSMTPAuth = errors.New("smtp authentication failed")

// FormatError renders a delivery error for API responses.
func FormatError(err error) string {
	if errors.Is(err, ErrSMTPAuth) {
		return "Gmail отклонил логин или пароль SMTP. " +
			"Нужен пароль приложения Google (16 символов), не обычный пароль аккаунта: " +
			"https://myaccount.google.com/apppasswords " +
			"Либо установите VERIFICATION_DELIVERY_MODE=log."
	}
	return err.Error()
}

func (d *Delivery) SendEmailVerificationCode(ctx context.Context, to, code string) error {
	body := "Здравствуйте!\n\n" +
		"Код подтверждения email для системы мониторинга ТЭК: " + code + "\n\n" +
		"Код действует 10 минут. Если вы не запрашивали привязку, проигнорируйте письмо.\n"
	return d.deliverEmail(ctx, to, code, "ТЭК · Код подтверждения email", body)
}

func (d *Delivery) SendPasswordResetEmail(ctx context.Context, to, code string) error {
	body := "Здравствуйте!\n\n" +
		"Код для сброса пароля в системе мониторинга ТЭК: " + code + "\n\n" +
		"Код действует 10 минут. Если вы не запрашивали сброс, проигнорируйте письмо.\n"
	return d.deliverEmail(ctx, to, code, "ТЭК · Сброс пароля", body)
}

func (d *Delivery) SendSMSVerificationCode(ctx context.Context, to, code string) error {
	return d.sendSMS(ctx, to, code, "phone", "ТЭК: код подтверждения телефона "+code+". Действует 10 минут.")
}

func (d *Delivery) SendPasswordResetSMS(ctx context.Context, to, code string) error {
	return d.sendSMS(ctx, to, code, "password_reset", "ТЭК: код сброса пароля "+code+". Действует 10 минут.")
}

func (d *Delivery) deliverEmail(ctx context.Context, to, code, subject, body string) error {
	d.remember("email", to, code)
	switch d.mode() {
	case "test":
		d.log.Info("TEST email queued", "to", validate.MaskEmail(to))
		return nil
	case "log":
		d.log.Info("VERIFICATION_DELIVERY_MODE=log - email not sent", "to", validate.MaskEmail(to))
		return nil
	case "production":
	default:
		return nil
	}
	if d.cfg.VerificationSMTPPassword == "" {
		return errors.New("VERIFICATION_SMTP_PASSWORD не задан (нужен пароль приложения Gmail)")
	}
	if err := d.sendSMTP(ctx, to, subject, body); err != nil {
		return err
	}
	d.log.Info("Email sent", "to", validate.MaskEmail(to))
	return nil
}

func (d *Delivery) sendSMTP(ctx context.Context, to, subject, body string) error {
	host := d.cfg.VerificationSMTPHost
	addr := net.JoinHostPort(host, strconv.Itoa(d.cfg.VerificationSMTPPort))
	dialer := &net.Dialer{Timeout: 20 * time.Second}
	conn, err := dialer.DialContext(ctx, "tcp", addr)
	if err != nil {
		return err
	}
	_ = conn.SetDeadline(time.Now().Add(20 * time.Second))
	c, err := smtp.NewClient(conn, host)
	if err != nil {
		conn.Close()
		return err
	}
	defer c.Close()
	if err := c.StartTLS(&tls.Config{ServerName: host}); err != nil {
		return err
	}
	auth := smtp.PlainAuth("", d.cfg.VerificationSMTPUser, d.cfg.VerificationSMTPPassword, host)
	if err := c.Auth(auth); err != nil {
		var tpErr *textproto.Error
		if errors.As(err, &tpErr) && tpErr.Code == 535 {
			return fmt.Errorf("%w: %v", ErrSMTPAuth, err)
		}
		return err
	}
	from := d.cfg.VerificationSMTPUser
	if err := c.Mail(from); err != nil {
		return err
	}
	if err := c.Rcpt(to); err != nil {
		return err
	}
	w, err := c.Data()
	if err != nil {
		return err
	}
	msg := "Subject: " + mime.QEncoding.Encode("utf-8", subject) + "\r\n" +
		"From: " + from + "\r\n" +
		"To: " + to + "\r\n" +
		"Content-Type: text/plain; charset=\"utf-8\"\r\n" +
		"Content-Transfer-Encoding: 8bit\r\n" +
		"MIME-Version: 1.0\r\n\r\n" +
		strings.ReplaceAll(body, "\n", "\r\n")
	if _, err := io.WriteString(w, msg); err != nil {
		return err
	}
	if err := w.Close(); err != nil {
		return err
	}
	return c.Quit()
}

func (d *Delivery) sendSMS(ctx context.Context, to, code, purpose, text string) error {
	normalized, err := validate.Phone(to)
	if err != nil {
		return err
	}
	d.remember("phone", normalized, code)
	switch d.mode() {
	case "test":
		d.log.Info("TEST SMS queued", "to", validate.MaskPhone(normalized))
		return nil
	case "log":
		d.log.Info("VERIFICATION_DELIVERY_MODE=log - SMS not sent", "to", validate.MaskPhone(normalized))
		return nil
	case "production":
	default:
		return nil
	}
	if d.cfg.VerificationSMSAPIID == "" {
		return errors.New("VERIFICATION_SMS_API_ID не задан")
	}
	form := url.Values{"to": {normalized}, "msg": {text}, "json": {"1"}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, d.SMSEndpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Authorization", "Bearer "+d.cfg.VerificationSMSAPIID)
	resp, err := d.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body)
	if resp.StatusCode >= 400 {
		return fmt.Errorf("HTTP Error %d: %s", resp.StatusCode, http.StatusText(resp.StatusCode))
	}
	d.log.Info("SMS sent", "purpose", purpose, "to", validate.MaskPhone(normalized))
	return nil
}
