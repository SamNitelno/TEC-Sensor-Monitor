import re

_PASSWORD_MIN_LEN = 8
_HAS_DIGIT = re.compile(r"\d")
_HAS_LATIN = re.compile(r"[A-Za-z]")


def validate_password(password: str) -> None:
    if len(password) < _PASSWORD_MIN_LEN:
        raise ValueError("Пароль должен содержать не менее 8 символов")
    if not _HAS_DIGIT.search(password):
        raise ValueError("Пароль должен содержать хотя бы одну цифру")
    if not _HAS_LATIN.search(password):
        raise ValueError("Пароль должен содержать латинские буквы")


def is_login_available_format(login: str) -> bool:
    return 3 <= len(login) <= 64 and login.isalnum() or "_" in login or "-" in login
