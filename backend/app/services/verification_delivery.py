import hashlib
import logging
import re
import secrets
import smtplib
import urllib.parse
import urllib.request
from email.message import EmailMessage

from app.core.config import settings

logger = logging.getLogger(__name__)

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_PHONE_DIGITS_RE = re.compile(r"\D")

_test_codes: dict[str, str] = {}


def normalize_email(value: str) -> str:
    return value.strip().lower()


def validate_email(value: str) -> str:
    normalized = normalize_email(value)
    if not _EMAIL_RE.match(normalized):
        raise ValueError("Invalid email format")
    return normalized


def normalize_phone(value: str) -> str:
    digits = _PHONE_DIGITS_RE.sub("", value.strip())
    if digits.startswith("8") and len(digits) == 11:
        digits = "7" + digits[1:]
    if len(digits) == 10:
        digits = "7" + digits
    if not digits.startswith("7") or len(digits) != 11:
        raise ValueError("Phone must be a Russian number, e.g. +79135466546")
    return f"+{digits}"


def mask_email(email: str) -> str:
    local, _, domain = email.partition("@")
    if len(local) <= 2:
        masked_local = local[0] + "*"
    else:
        masked_local = local[0] + "*" * (len(local) - 2) + local[-1]
    return f"{masked_local}@{domain}"


def mask_phone(phone: str) -> str:
    digits = _PHONE_DIGITS_RE.sub("", phone)
    if len(digits) < 4:
        return phone
    return f"+{digits[0]} *** ***-{digits[-4:-2]}-{digits[-2:]}"


def generate_verification_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_verification_code(code: str) -> str:
    payload = f"{code}:{settings.jwt_secret}".encode()
    return hashlib.sha256(payload).hexdigest()


def verify_code_hash(code: str, code_hash: str | None) -> bool:
    if not code_hash:
        return False
    return secrets.compare_digest(hash_verification_code(code), code_hash)


def get_test_code(channel: str, destination: str) -> str | None:
    return _test_codes.get(f"{channel}:{destination}")


def _remember_test_code(channel: str, destination: str, code: str) -> None:
    if settings.verification_delivery_mode == "test":
        _test_codes[f"{channel}:{destination}"] = code


def _delivery_mode() -> str:
    return settings.verification_delivery_mode.strip().lower()


def _send_for_real() -> bool:
    return _delivery_mode() == "production"


def format_delivery_error(exc: Exception) -> str:
    if isinstance(exc, smtplib.SMTPAuthenticationError):
        return (
            "Gmail отклонил логин или пароль SMTP. "
            "Нужен пароль приложения Google (16 символов), не обычный пароль аккаунта: "
            "https://myaccount.google.com/apppasswords "
            "Либо установите VERIFICATION_DELIVERY_MODE=log и смотрите код в логах backend."
        )
    return str(exc)


async def send_email_verification_code(*, to_email: str, code: str) -> None:
    subject = "ТЭК · Код подтверждения email"
    body = (
        "Здравствуйте!\n\n"
        f"Код подтверждения email для системы мониторинга ТЭК: {code}\n\n"
        "Код действует 10 минут. Если вы не запрашивали привязку, проигнорируйте письмо.\n"
    )
    _remember_test_code("email", to_email, code)

    mode = _delivery_mode()
    if mode == "test":
        logger.info("TEST email code for %s: %s", to_email, code)
        return

    logger.info("Email verification code for %s: %s", to_email, code)

    if not _send_for_real():
        logger.info(
            "VERIFICATION_DELIVERY_MODE=%s — письмо не отправляется, код только в логе",
            mode,
        )
        return

    if not settings.verification_smtp_password:
        raise RuntimeError(
            "VERIFICATION_SMTP_PASSWORD не задан (нужен пароль приложения Gmail)"
        )

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = settings.verification_smtp_user
    message["To"] = to_email
    message.set_content(body)

    with smtplib.SMTP(settings.verification_smtp_host, settings.verification_smtp_port, timeout=20) as smtp:
        smtp.starttls()
        smtp.login(settings.verification_smtp_user, settings.verification_smtp_password)
        smtp.send_message(message)


async def send_sms_verification_code(*, to_phone: str, code: str) -> None:
    normalized = normalize_phone(to_phone)
    text = f"ТЭК: код подтверждения телефона {code}. Действует 10 минут."
    _remember_test_code("phone", normalized, code)

    mode = _delivery_mode()
    if mode == "test":
        logger.info("TEST SMS code for %s: %s", normalized, code)
        return

    logger.info("SMS verification code for %s: %s", normalized, code)

    if not _send_for_real():
        logger.info(
            "VERIFICATION_DELIVERY_MODE=%s — SMS не отправляется, код только в логе",
            mode,
        )
        return

    if not settings.verification_sms_api_id:
        raise RuntimeError("VERIFICATION_SMS_API_ID не задан")

    params = urllib.parse.urlencode(
        {
            "api_id": settings.verification_sms_api_id,
            "to": normalized,
            "msg": text,
            "json": "1",
        }
    )
    url = f"https://sms.ru/sms/send?{params}"
    with urllib.request.urlopen(url, timeout=20) as response:
        payload = response.read().decode("utf-8", errors="replace")
        logger.info("SMS.ru response: %s", payload)
