package httpapi

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"mime"
	"net/http"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/go-chi/chi/v5"

	"tek-sensor-monitor/backend/internal/apperr"
	"tek-sensor-monitor/backend/internal/jsonx"
	"tek-sensor-monitor/backend/internal/models"
	"tek-sensor-monitor/backend/internal/service"
	"tek-sensor-monitor/backend/internal/validate"
)

// fieldError is one entry of FastAPI's 422 {"detail": [...]} list.
type fieldError struct {
	Type  string         `json:"type"`
	Loc   []any          `json:"loc"`
	Msg   string         `json:"msg"`
	Input any            `json:"input"`
	Ctx   map[string]any `json:"ctx,omitempty"`
}

// validationError renders as 422 {"detail": [...]}.
type validationError struct{ errs []fieldError }

func (v *validationError) Error() string { return "validation error" }

// rc carries one request through parsing, auth, validation and rate limiting
// in FastAPI's order: JSON decode -> dependencies (auth) -> params/body
// validation -> rate limit -> handler.
type rc struct {
	api  *API
	w    http.ResponseWriter
	r    *http.Request
	errs []fieldError

	bodyBytes []byte
	bodyAny   any
	hasBody   bool
	notJSON   bool

	user *models.User
}

const maxBodyBytes = 1 << 20

// readBody reads and JSON-decodes the request body. A malformed body fails
// immediately with json_invalid (before auth), like FastAPI.
func (c *rc) readBody() error {
	data, err := io.ReadAll(io.LimitReader(c.r.Body, maxBodyBytes))
	if err != nil {
		return err
	}
	if len(bytes.TrimSpace(data)) == 0 {
		return nil
	}
	c.bodyBytes = data
	c.hasBody = true
	if ct := c.r.Header.Get("Content-Type"); ct != "" {
		mt, _, _ := mime.ParseMediaType(ct)
		if mt != "application/json" && !strings.HasSuffix(mt, "+json") {
			c.notJSON = true
			c.bodyAny = string(data)
			return nil
		}
	}
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.UseNumber()
	var v any
	if err := dec.Decode(&v); err != nil || dec.More() {
		pos, msg := jsonErrorPosition(data, err, dec.InputOffset())
		return &validationError{errs: []fieldError{{
			Type: "json_invalid", Loc: []any{"body", pos}, Msg: "JSON decode error",
			Input: map[string]any{}, Ctx: map[string]any{"error": msg},
		}}}
	}
	c.bodyAny = v
	return nil
}

// jsonErrorPosition approximates Python json's error position (character
// index of the offending input) and message.
func jsonErrorPosition(data []byte, err error, consumed int64) (int, string) {
	if err == nil {
		// Valid value followed by more data.
		return utf8.RuneCount(data[:consumed]) + countLeadingSpace(data[consumed:]), "Extra data"
	}
	var syn *json.SyntaxError
	if !errors.As(err, &syn) {
		return utf8.RuneCount(data), "Expecting value"
	}
	off := int(syn.Offset) - 1
	if off < 0 {
		off = 0
	}
	if off > len(data) {
		off = len(data)
	}
	prev := byte(0)
	for i := off - 1; i >= 0; i-- {
		if c := data[i]; c != ' ' && c != '\t' && c != '\r' && c != '\n' {
			prev = c
			break
		}
	}
	msg := "Expecting value"
	switch {
	case strings.Contains(syn.Error(), "unexpected end of JSON input"):
		off = len(data)
	case prev == '{':
		msg = "Expecting property name enclosed in double quotes"
	case prev == '"' && strings.Contains(syn.Error(), "after object key"):
		msg = "Expecting ':' delimiter"
	case strings.Contains(syn.Error(), "after object key:value pair") || strings.Contains(syn.Error(), "after array element"):
		msg = "Expecting ',' delimiter"
	case prev == ',' && strings.Contains(syn.Error(), "looking for beginning of object key"):
		msg = "Expecting property name enclosed in double quotes"
	}
	return utf8.RuneCount(data[:off]), msg
}

func countLeadingSpace(b []byte) int {
	n := 0
	for _, c := range b {
		if c != ' ' && c != '\t' && c != '\r' && c != '\n' {
			break
		}
		n++
	}
	return n
}

func (c *rc) addErr(e fieldError) { c.errs = append(c.errs, e) }

// checkValidation returns the accumulated 422 error, if any.
func (c *rc) checkValidation() error {
	if len(c.errs) > 0 {
		return &validationError{errs: c.errs}
	}
	return nil
}

// ---- auth ---------------------------------------------------------------

func (c *rc) currentUser() (*models.User, error) {
	if c.user != nil {
		return c.user, nil
	}
	header := c.r.Header.Get("Authorization")
	scheme, credentials, _ := strings.Cut(header, " ")
	if header == "" || scheme == "" || credentials == "" || !strings.EqualFold(scheme, "bearer") {
		return nil, apperr.Unauthorized("Not authenticated")
	}
	user, err := c.api.svc.UserFromToken(c.r.Context(), credentials)
	if err != nil {
		return nil, err
	}
	c.user = user
	return user, nil
}

func (c *rc) requireRole(roles ...string) (*models.User, error) {
	user, err := c.currentUser()
	if err != nil {
		return nil, err
	}
	for _, r := range roles {
		if user.Role == r {
			return user, nil
		}
	}
	return nil, apperr.Forbidden("Insufficient permissions")
}

func (c *rc) admin() (*models.User, error) { return c.requireRole(models.RoleAdmin) }
func (c *rc) viewer() (*models.User, error) {
	return c.requireRole(models.RoleAdmin, models.RoleViewer)
}

// ---- rate limiting ---------------------------------------------------------

func (c *rc) rateLimit(route, spec string) error {
	return c.api.limiter.Check(route, spec, clientIP(c.r))
}

// ---- path / query ------------------------------------------------------------

func (c *rc) pathInt(name string) int64 {
	raw := chi.URLParam(c.r, name)
	n, ok := parseIntLax(raw)
	if !ok {
		c.addErr(fieldError{Type: "int_parsing", Loc: []any{"path", name},
			Msg: "Input should be a valid integer, unable to parse string as an integer", Input: raw})
	}
	return n
}

// queryLast mirrors Starlette's QueryParams.get (last value wins).
func (c *rc) queryLast(name string) (string, bool) {
	vals, ok := c.r.URL.Query()[name]
	if !ok || len(vals) == 0 {
		return "", false
	}
	return vals[len(vals)-1], true
}

func (c *rc) queryInt(name string) *int64 {
	raw, ok := c.queryLast(name)
	if !ok {
		return nil
	}
	n, valid := parseIntLax(raw)
	if !valid {
		c.addErr(fieldError{Type: "int_parsing", Loc: []any{"query", name},
			Msg: "Input should be a valid integer, unable to parse string as an integer", Input: raw})
		return nil
	}
	return &n
}

func (c *rc) queryIntList(name string) []int64 {
	vals := c.r.URL.Query()[name]
	out := make([]int64, 0, len(vals))
	for i, raw := range vals {
		n, ok := parseIntLax(raw)
		if !ok {
			c.addErr(fieldError{Type: "int_parsing", Loc: []any{"query", name, i},
				Msg: "Input should be a valid integer, unable to parse string as an integer", Input: raw})
			continue
		}
		out = append(out, n)
	}
	return out
}

func (c *rc) queryDateTime(name string) time.Time {
	raw, ok := c.queryLast(name)
	if !ok {
		c.addErr(fieldError{Type: "missing", Loc: []any{"query", name}, Msg: "Field required", Input: nil})
		return time.Time{}
	}
	t, err := service.ParseDateTime(raw)
	if err != nil {
		c.addErr(fieldError{Type: "datetime_from_date_parsing", Loc: []any{"query", name},
			Msg: "Input should be a valid datetime or date, " + err.Error(), Input: raw,
			Ctx: map[string]any{"error": err.Error()}})
	}
	return t
}

func (c *rc) queryEnum(name string, allowed []string) *string {
	raw, ok := c.queryLast(name)
	if !ok {
		return nil
	}
	for _, a := range allowed {
		if raw == a {
			v := raw
			return &v
		}
	}
	expected := enumExpected(allowed)
	c.addErr(fieldError{Type: "enum", Loc: []any{"query", name}, Msg: "Input should be " + expected,
		Input: raw, Ctx: map[string]any{"expected": expected}})
	return nil
}

func enumExpected(allowed []string) string {
	quoted := make([]string, len(allowed))
	for i, a := range allowed {
		quoted[i] = "'" + a + "'"
	}
	if len(quoted) == 1 {
		return quoted[0]
	}
	return strings.Join(quoted[:len(quoted)-1], ", ") + " or " + quoted[len(quoted)-1]
}

func (c *rc) queryStr(name string, required bool, minLen, maxLen int) *string {
	raw, ok := c.queryLast(name)
	if !ok {
		if required {
			c.addErr(fieldError{Type: "missing", Loc: []any{"query", name}, Msg: "Field required", Input: nil})
		}
		return nil
	}
	if !checkLen(c, []any{"query", name}, raw, minLen, maxLen) {
		return nil
	}
	return &raw
}

// ---- body object -------------------------------------------------------------

// obj gives typed, Pydantic-like access to the JSON body object.
type obj struct {
	c      *rc
	fields map[string]any
	input  any
	loc    []any
	ok     bool
}

// object validates that the body is a JSON object (or records an error).
func (c *rc) object() *obj {
	o := &obj{c: c, loc: []any{"body"}, input: c.bodyAny}
	if !c.hasBody {
		c.addErr(fieldError{Type: "missing", Loc: []any{"body"}, Msg: "Field required", Input: nil})
		return o
	}
	m, ok := c.bodyAny.(map[string]any)
	if !ok || c.notJSON {
		c.addErr(fieldError{Type: "model_attributes_type", Loc: []any{"body"},
			Msg: "Input should be a valid dictionary or object to extract fields from", Input: c.bodyAny})
		return o
	}
	o.fields, o.ok = m, true
	return o
}

func (o *obj) at(name string) []any {
	loc := append([]any{}, o.loc...)
	return append(loc, name)
}

func (o *obj) lookup(name string) (any, bool) {
	if !o.ok {
		return nil, false
	}
	v, ok := o.fields[name]
	return v, ok
}

func (o *obj) missing(name string) {
	if o.ok {
		o.c.addErr(fieldError{Type: "missing", Loc: o.at(name), Msg: "Field required", Input: o.input})
	}
}

func checkLen(c *rc, loc []any, s string, minLen, maxLen int) bool {
	n := utf8.RuneCountInString(s)
	if minLen > 0 && n < minLen {
		c.addErr(fieldError{Type: "string_too_short", Loc: loc,
			Msg: fmt.Sprintf("String should have at least %d character%s", minLen, plural(minLen)), Input: s,
			Ctx: map[string]any{"min_length": minLen}})
		return false
	}
	if maxLen > 0 && n > maxLen {
		c.addErr(fieldError{Type: "string_too_long", Loc: loc,
			Msg: fmt.Sprintf("String should have at most %d character%s", maxLen, plural(maxLen)), Input: s,
			Ctx: map[string]any{"max_length": maxLen}})
		return false
	}
	return true
}

func plural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}

// str reads a string field. required: absent -> "Field required"; nullable:
// null allowed (returns nil). Returns (value, present).
func (o *obj) str(name string, required, nullable bool, minLen, maxLen int) (*string, bool) {
	v, present := o.lookup(name)
	if !present {
		if required {
			o.missing(name)
		}
		return nil, false
	}
	if v == nil {
		if !nullable {
			o.c.addErr(fieldError{Type: "string_type", Loc: o.at(name), Msg: "Input should be a valid string", Input: nil})
		}
		return nil, true
	}
	s, ok := v.(string)
	if !ok {
		o.c.addErr(fieldError{Type: "string_type", Loc: o.at(name), Msg: "Input should be a valid string", Input: jsonInput(v)})
		return nil, true
	}
	if !checkLen(o.c, o.at(name), s, minLen, maxLen) {
		return nil, true
	}
	return &s, true
}

// color reads an optional "#RRGGBB" colour (null allowed) and upper-cases it.
func (o *obj) color(name string) *string {
	v, _ := o.str(name, false, true, 0, 0)
	if v == nil {
		return nil
	}
	c, err := validate.Color(*v)
	if err != nil {
		o.c.addErr(fieldError{Type: "value_error", Loc: o.at(name), Msg: "Value error, " + err.Error(),
			Input: *v, Ctx: map[string]any{"error": map[string]any{}}})
		return nil
	}
	return &c
}

func parseBoolLax(v any) (bool, string) {
	switch x := v.(type) {
	case bool:
		return x, ""
	case json.Number:
		switch x.String() {
		case "0", "0.0":
			return false, ""
		case "1", "1.0":
			return true, ""
		}
		return false, "bool_parsing"
	case string:
		switch strings.ToLower(strings.TrimSpace(x)) {
		case "0", "off", "f", "false", "n", "no":
			return false, ""
		case "1", "on", "t", "true", "y", "yes":
			return true, ""
		}
		return false, "bool_parsing"
	}
	return false, "bool_type"
}

func (o *obj) boolErr(name, typ string, v any) {
	msg := "Input should be a valid boolean"
	if typ == "bool_parsing" {
		msg += ", unable to interpret input"
	}
	o.c.addErr(fieldError{Type: typ, Loc: o.at(name), Msg: msg, Input: jsonInput(v)})
}

// boolean reads a non-nullable bool with a default (absent -> def).
func (o *obj) boolean(name string, def bool) bool {
	v, present := o.lookup(name)
	if !present {
		return def
	}
	b, errType := parseBoolLax(v)
	if errType != "" {
		o.boolErr(name, errType, v)
		return def
	}
	return b
}

// boolRequired reads a required bool.
func (o *obj) boolRequired(name string) bool {
	if _, present := o.lookup(name); !present {
		o.missing(name)
		return false
	}
	return o.boolean(name, false)
}

// optBool reads a "bool | None" field.
func (o *obj) optBool(name string) *bool {
	v, present := o.lookup(name)
	if !present || v == nil {
		return nil
	}
	b, errType := parseBoolLax(v)
	if errType != "" {
		o.boolErr(name, errType, v)
		return nil
	}
	return &b
}

// parseIntLax accepts integers, integral floats and numeric strings.
func parseIntLax(s string) (int64, bool) {
	s = strings.TrimSpace(s)
	if n, err := strconv.ParseInt(s, 10, 64); err == nil {
		return n, true
	}
	return 0, false
}

// integer reads "int" (required) or "int | None" (nullable, absent -> nil).
// Returns (value, present-and-not-null).
func (o *obj) integer(name string, required bool, ge *int64) (*int64, bool) {
	v, present := o.lookup(name)
	if !present {
		if required {
			o.missing(name)
		}
		return nil, false
	}
	if v == nil {
		if required {
			o.c.addErr(fieldError{Type: "int_type", Loc: o.at(name), Msg: "Input should be a valid integer", Input: nil})
		}
		return nil, true
	}
	var n int64
	switch x := v.(type) {
	case json.Number:
		if i, err := strconv.ParseInt(x.String(), 10, 64); err == nil {
			n = i
		} else if f, err := x.Float64(); err == nil {
			if f != math.Trunc(f) || math.IsInf(f, 0) {
				o.c.addErr(fieldError{Type: "int_from_float", Loc: o.at(name),
					Msg: "Input should be a valid integer, got a number with a fractional part", Input: jsonInput(v)})
				return nil, true
			}
			n = int64(f)
		}
	case string:
		i, ok := parseIntLax(x)
		if !ok {
			o.c.addErr(fieldError{Type: "int_parsing", Loc: o.at(name),
				Msg: "Input should be a valid integer, unable to parse string as an integer", Input: x})
			return nil, true
		}
		n = i
	case bool:
		if x {
			n = 1
		}
	default:
		o.c.addErr(fieldError{Type: "int_type", Loc: o.at(name), Msg: "Input should be a valid integer", Input: jsonInput(v)})
		return nil, true
	}
	if ge != nil && n < *ge {
		o.c.addErr(fieldError{Type: "greater_than_equal", Loc: o.at(name),
			Msg: fmt.Sprintf("Input should be greater than or equal to %d", *ge), Input: jsonInput(v),
			Ctx: map[string]any{"ge": *ge}})
		return nil, true
	}
	return &n, true
}

// bound is a numeric constraint with its Python repr (e.g. 0 vs 0.0).
type bound struct {
	v       float64
	isFloat bool
}

// repr renders the bound the way Pydantic's error messages do (integral
// floats without ".0", e.g. "less than or equal to 1000").
func (b bound) repr() string {
	if b.v == math.Trunc(b.v) && math.Abs(b.v) < 1e16 {
		return strconv.FormatInt(int64(b.v), 10)
	}
	return pyFloatRepr(b.v)
}

func (b bound) ctxValue() any {
	if !b.isFloat {
		return int64(b.v)
	}
	return jsonx.Float(b.v)
}

func pyFloatRepr(f float64) string {
	if f == math.Trunc(f) && math.Abs(f) < 1e16 {
		return strconv.FormatFloat(f, 'f', 1, 64)
	}
	s := strconv.FormatFloat(f, 'g', -1, 64)
	return s
}

func intBound(v int64) *bound     { return &bound{v: float64(v)} }
func floatBound(v float64) *bound { return &bound{v: v, isFloat: true} }
func int64Ptr(v int64) *int64     { return &v }

// number reads "float" (required) or "float | None" with optional ge/le.
func (o *obj) number(name string, required bool, ge, le *bound) (*float64, bool) {
	v, present := o.lookup(name)
	if !present {
		if required {
			o.missing(name)
		}
		return nil, false
	}
	if v == nil {
		if required {
			o.c.addErr(fieldError{Type: "float_type", Loc: o.at(name), Msg: "Input should be a valid number", Input: nil})
		}
		return nil, true
	}
	f, ok := o.toFloat(name, v)
	if !ok {
		return nil, true
	}
	if ge != nil && !(f >= ge.v) {
		o.c.addErr(fieldError{Type: "greater_than_equal", Loc: o.at(name),
			Msg: "Input should be greater than or equal to " + ge.repr(), Input: jsonInput(v),
			Ctx: map[string]any{"ge": ge.ctxValue()}})
		return nil, true
	}
	if le != nil && !(f <= le.v) {
		o.c.addErr(fieldError{Type: "less_than_equal", Loc: o.at(name),
			Msg: "Input should be less than or equal to " + le.repr(), Input: jsonInput(v),
			Ctx: map[string]any{"le": le.ctxValue()}})
		return nil, true
	}
	return &f, true
}

func (o *obj) toFloat(name string, v any) (float64, bool) {
	switch x := v.(type) {
	case json.Number:
		f, err := x.Float64()
		if err != nil {
			o.c.addErr(fieldError{Type: "float_parsing", Loc: o.at(name),
				Msg: "Input should be a valid number, unable to parse string as a number", Input: x.String()})
			return 0, false
		}
		return f, true
	case string:
		f, err := strconv.ParseFloat(strings.TrimSpace(x), 64)
		if err != nil {
			o.c.addErr(fieldError{Type: "float_parsing", Loc: o.at(name),
				Msg: "Input should be a valid number, unable to parse string as a number", Input: x})
			return 0, false
		}
		return f, true
	case bool:
		if x {
			return 1, true
		}
		return 0, true
	}
	o.c.addErr(fieldError{Type: "float_type", Loc: o.at(name), Msg: "Input should be a valid number", Input: jsonInput(v)})
	return 0, false
}

// dateTime reads an optional datetime ("datetime | None").
func (o *obj) dateTime(name string) *time.Time {
	v, present := o.lookup(name)
	if !present || v == nil {
		return nil
	}
	var t time.Time
	var err error
	switch x := v.(type) {
	case string:
		t, err = service.ParseDateTime(x)
	case json.Number:
		var f float64
		f, err = x.Float64()
		if err == nil {
			t = service.FromUnix(f)
		}
	default:
		o.c.addErr(fieldError{Type: "datetime_type", Loc: o.at(name),
			Msg: "Input should be a valid datetime", Input: jsonInput(v)})
		return nil
	}
	if err != nil {
		o.c.addErr(fieldError{Type: "datetime_from_date_parsing", Loc: o.at(name),
			Msg: "Input should be a valid datetime or date, " + err.Error(), Input: jsonInput(v),
			Ctx: map[string]any{"error": err.Error()}})
		return nil
	}
	return &t
}

// jsonInput converts decoded values back to plain JSON-friendly values.
func jsonInput(v any) any {
	if n, ok := v.(json.Number); ok {
		if i, err := n.Int64(); err == nil {
			return i
		}
		if f, err := n.Float64(); err == nil {
			return f
		}
		return n.String()
	}
	return v
}
