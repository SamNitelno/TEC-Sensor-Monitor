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
    import hashlib

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


def _log_dev_code(channel: str, destination: str) -> None:
    """Explicit dev-only path - never log the code itself."""
    logger.debug(
        "Verification code generated (%s) for %s",
        channel,
        mask_email(destination) if channel == "email" else mask_phone(destination),
    )


def format_delivery_error(exc: Exception) -> str:
    if isinstance(exc, smtplib.SMTPAuthenticationError):
        return (
            "Gmail отклонил логин или пароль SMTP. "
            "Нужен пароль приложения Google (16 символов), не обычный пароль аккаунта: "
            "https://myaccount.google.com/apppasswords "
            "Либо установите VERIFICATION_DELIVERY_MODE=log."
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
        logger.info("TEST email verification queued for %s", mask_email(to_email))
        return

    if mode == "log":
        _log_dev_code("email", to_email)
        logger.info(
            "VERIFICATION_DELIVERY_MODE=log - email not sent to %s",
            mask_email(to_email),
        )
        return

    if not _send_for_real():
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
    logger.info("Verification email sent to %s", mask_email(to_email))


async def send_sms_verification_code(*, to_phone: str, code: str) -> None:
    normalized = normalize_phone(to_phone)
    text = f"ТЭК: код подтверждения телефона {code}. Действует 10 минут."
    _remember_test_code("phone", normalized, code)

    mode = _delivery_mode()
    if mode == "test":
        logger.info("TEST SMS verification queued for %s", mask_phone(normalized))
        return

    if mode == "log":
        _log_dev_code("phone", normalized)
        logger.info(
            "VERIFICATION_DELIVERY_MODE=log - SMS not sent to %s",
            mask_phone(normalized),
        )
        return

    if not _send_for_real():
        return

    if not settings.verification_sms_api_id:
        raise RuntimeError("VERIFICATION_SMS_API_ID не задан")

    payload = urllib.parse.urlencode(
        {
            "to": normalized,
            "msg": text,
            "json": "1",
        }
    ).encode()
    url = "https://sms.ru/sms/send"
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Authorization": f"Bearer {settings.verification_sms_api_id}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=20) as response:
        response.read()
    logger.info("Verification SMS sent to %s", mask_phone(normalized))
