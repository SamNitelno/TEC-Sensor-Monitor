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
        raise ValueError("Phone must be a Russian number, e.g. +79001234567")
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


def verification_delivery_ready() -> bool:
    """True when codes can reach users (production SMTP/SMS, dev log/test)."""
    mode = _delivery_mode()
    if mode == "test":
        return True
    if mode == "production":
        has_email = bool(
            settings.verification_smtp_user.strip()
            and settings.verification_smtp_password.strip()
        )
        has_sms = bool(settings.verification_sms_api_id.strip())
        return has_email or has_sms
    if mode == "log":
        return not settings.is_production
    return False


def delivery_channel_ready(channel: str) -> bool:
    mode = _delivery_mode()
    if mode == "test":
        return True
    if mode == "log":
        return not settings.is_production
    if mode != "production":
        return False
    if channel == "email":
        return bool(
            settings.verification_smtp_user.strip()
            and settings.verification_smtp_password.strip()
        )
    if channel == "phone":
        return bool(settings.verification_sms_api_id.strip())
    return False


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


async def send_sms_verification_code(*, to_phone: str, code: str) -> None:
    await _send_sms_code(
        to_phone=to_phone,
        code=code,
        purpose="phone",
    )


async def send_password_reset_email(*, to_email: str, code: str) -> None:
    subject = "ТЭК · Сброс пароля"
    body = (
        "Здравствуйте!\n\n"
        f"Код для сброса пароля в системе мониторинга ТЭК: {code}\n\n"
        "Код действует 10 минут. Если вы не запрашивали сброс, проигнорируйте письмо.\n"
    )
    await _deliver_email(to_email=to_email, code=code, subject=subject, body=body)


async def send_password_reset_sms(*, to_phone: str, code: str) -> None:
    await _send_sms_code(
        to_phone=to_phone,
        code=code,
        purpose="password_reset",
        text=f"ТЭК: код сброса пароля {code}. Действует 10 минут.",
    )


async def _deliver_email(*, to_email: str, code: str, subject: str, body: str) -> None:
    _remember_test_code("email", to_email, code)

    mode = _delivery_mode()
    if mode == "test":
        logger.info("TEST email queued for %s", mask_email(to_email))
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
    logger.info("Email sent to %s", mask_email(to_email))


async def send_email_verification_code(*, to_email: str, code: str) -> None:
    subject = "ТЭК · Код подтверждения email"
    body = (
        "Здравствуйте!\n\n"
        f"Код подтверждения email для системы мониторинга ТЭК: {code}\n\n"
        "Код действует 10 минут. Если вы не запрашивали привязку, проигнорируйте письмо.\n"
    )
    await _deliver_email(to_email=to_email, code=code, subject=subject, body=body)


async def _send_sms_code(
    *,
    to_phone: str,
    code: str,
    purpose: str,
    text: str | None = None,
) -> None:
    normalized = normalize_phone(to_phone)
    sms_text = text or f"ТЭК: код подтверждения телефона {code}. Действует 10 минут."
    _remember_test_code("phone", normalized, code)

    mode = _delivery_mode()
    if mode == "test":
        logger.info("TEST SMS queued for %s", mask_phone(normalized))
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
            "msg": sms_text,
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
    logger.info("SMS sent (%s) to %s", purpose, mask_phone(normalized))
