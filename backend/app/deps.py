from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Header, HTTPException, Request

from .config import settings

_BCRYPT_MAX_BYTES = 72  # bcrypt ignores everything past this; newer libraries refuse it instead


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8")[:_BCRYPT_MAX_BYTES], bcrypt.gensalt(10)).decode("ascii")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8")[:_BCRYPT_MAX_BYTES], password_hash.encode("ascii"))
    except ValueError:
        return False


def create_token(user_id: int, username: str, is_artist: bool) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "userId": user_id,
            "username": username,
            "isArtist": bool(is_artist),
            "iat": now,
            "exp": now + timedelta(days=7),
        },
        settings.jwt_secret,
        algorithm="HS256",
    )


def current_user(authorization: str | None = Header(default=None)) -> dict:
    """Same contract as the old Express middleware: Bearer JWT, payload {userId, username, isArtist}."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Missing or invalid Authorization header")
    try:
        payload = jwt.decode(authorization.split(" ", 1)[1], settings.jwt_secret, algorithms=["HS256"])
    except jwt.PyJWTError:
        raise HTTPException(401, "Invalid or expired token")
    if not isinstance(payload.get("userId"), int):
        raise HTTPException(401, "Invalid or expired token")
    return payload


async def json_body(request: Request) -> dict:
    """Request body as a dict; empty or malformed bodies count as {} (like express.json())."""
    try:
        body = await request.json()
    except ValueError:
        return {}
    return body if isinstance(body, dict) else {}
