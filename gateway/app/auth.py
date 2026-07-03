from fastapi import Header, HTTPException

from app.config import settings


def require_gateway_secret(x_gateway_secret: str | None = Header(default=None)) -> None:
    """All routes except /healthz require this header (CLAUDE.md §3)."""
    if x_gateway_secret != settings.gateway_shared_secret:
        raise HTTPException(status_code=401, detail="invalid or missing X-Gateway-Secret")
