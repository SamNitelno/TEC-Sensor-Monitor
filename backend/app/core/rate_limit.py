from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

_TRUSTED_PROXY_NETS = ("127.0.0.1", "::1", "172.", "10.", "192.168.")


def _is_trusted_proxy(host: str | None) -> bool:
    if not host:
        return False
    return any(host == net or host.startswith(net) for net in _TRUSTED_PROXY_NETS)


def client_ip(request: Request) -> str:
    """Real client IP when request comes through nginx/docker network."""
    if request.client is not None and _is_trusted_proxy(request.client.host):
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
    if request.client is not None:
        return request.client.host
    return get_remote_address(request)
