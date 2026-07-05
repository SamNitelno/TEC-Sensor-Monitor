import hashlib
import secrets

from app.core.config import settings


def hash_device_token(plaintext: str, *, pepper: str | None = None) -> str:
    pepper = pepper or settings.jwt_secret
    payload = f"{plaintext}:{pepper}".encode()
    return hashlib.sha256(payload).hexdigest()


def store_device_token(plaintext: str) -> str:
    return hash_device_token(plaintext, pepper=settings.jwt_secret)


def verify_device_token(plaintext: str, stored_hash: str, *, pepper: str | None = None) -> bool:
    pepper = pepper or settings.jwt_secret
    if not plaintext or not stored_hash:
        return False
    expected = hash_device_token(plaintext, pepper=pepper)
    return secrets.compare_digest(expected, stored_hash)


def is_hashed_device_token(value: str) -> bool:
    return len(value) == 64 and all(c in "0123456789abcdef" for c in value)
