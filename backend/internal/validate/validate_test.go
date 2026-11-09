package validate

import "testing"

func TestPassword(t *testing.T) {
	cases := map[string]string{
		"short1A":    "Пароль должен содержать не менее 8 символов",
		"abcdefgh":   "Пароль должен содержать хотя бы одну цифру",
		"12345678":   "Пароль должен содержать латинские буквы",
		"пароль123":  "Пароль должен содержать латинские буквы",
		"Passw0rd":   "",
		"Пароль1a!!": "",
	}
	for in, want := range cases {
		err := Password(in)
		got := ""
		if err != nil {
			got = err.Error()
		}
		if got != want {
			t.Errorf("Password(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestPhone(t *testing.T) {
	ok := map[string]string{
		"+7 (900) 123-45-67": "+79001234567",
		"89001234567":        "+79001234567",
		"9001234567":         "+79001234567",
		"  7 900 123 45 67 ": "+79001234567",
	}
	for in, want := range ok {
		got, err := Phone(in)
		if err != nil || got != want {
			t.Errorf("Phone(%q) = %q, %v", in, got, err)
		}
	}
	for _, bad := range []string{"123", "+1 555 123 4567", "", "6900123456789"} {
		if _, err := Phone(bad); err == nil || err.Error() != "Phone must be a Russian number, e.g. +79001234567" {
			t.Errorf("Phone(%q) err = %v", bad, err)
		}
	}
}

func TestEmail(t *testing.T) {
	if got, err := Email("  John.Doe@Example.COM "); err != nil || got != "john.doe@example.com" {
		t.Fatalf("got %q %v", got, err)
	}
	for _, bad := range []string{"no-at", "a@b", "a b@c.d", "a@@b.c"} {
		if _, err := Email(bad); err == nil {
			t.Errorf("Email(%q) accepted", bad)
		}
	}
}

func TestMasks(t *testing.T) {
	cases := map[string]string{
		"john@example.com": "j**n@example.com",
		"ab@x.ru":          "a*@x.ru",
		"a@x.ru":           "a*@x.ru",
	}
	for in, want := range cases {
		if got := MaskEmail(in); got != want {
			t.Errorf("MaskEmail(%q) = %q, want %q", in, got, want)
		}
	}
	if got := MaskPhone("+79001234567"); got != "+7 *** ***-45-67" {
		t.Errorf("MaskPhone = %q", got)
	}
	if got := MaskPhone("12"); got != "12" {
		t.Errorf("MaskPhone short = %q", got)
	}
}

func TestColor(t *testing.T) {
	if c, err := Color("#a1b2c3"); err != nil || c != "#A1B2C3" {
		t.Fatalf("%q %v", c, err)
	}
	for _, bad := range []string{"a1b2c3", "#abc", "#GGGGGG", "#AABBCC\n"} {
		if _, err := Color(bad); err == nil {
			t.Errorf("Color(%q) accepted", bad)
		}
	}
}
