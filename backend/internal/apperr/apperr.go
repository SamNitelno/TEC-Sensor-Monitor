// Package apperr defines the HTTP-aware error used by services, rendered as
// FastAPI's {"detail": "..."} body.
package apperr

import (
	"errors"
	"net/http"
)

type Error struct {
	Status int
	Detail string
}

func (e *Error) Error() string { return e.Detail }

func New(status int, detail string) *Error { return &Error{Status: status, Detail: detail} }

func BadRequest(detail string) *Error   { return New(http.StatusBadRequest, detail) }
func Unauthorized(detail string) *Error { return New(http.StatusUnauthorized, detail) }
func Forbidden(detail string) *Error    { return New(http.StatusForbidden, detail) }
func NotFound(detail string) *Error     { return New(http.StatusNotFound, detail) }
func Conflict(detail string) *Error     { return New(http.StatusConflict, detail) }
func Gone(detail string) *Error         { return New(http.StatusGone, detail) }
func Unprocessable(detail string) *Error {
	return New(http.StatusUnprocessableEntity, detail)
}
func TooMany(detail string) *Error     { return New(http.StatusTooManyRequests, detail) }
func BadGateway(detail string) *Error  { return New(http.StatusBadGateway, detail) }
func Unavailable(detail string) *Error { return New(http.StatusServiceUnavailable, detail) }

// As extracts an *Error from err.
func As(err error) (*Error, bool) {
	var e *Error
	if errors.As(err, &e) {
		return e, true
	}
	return nil, false
}
