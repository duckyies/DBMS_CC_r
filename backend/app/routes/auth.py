from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db, transaction
from ..deps import create_token, current_user, hash_password, json_body, verify_password
from ..queries import artist_dict, get_artist
from ..serializers import respond

router = APIRouter(prefix="/api/auth")


def _user_payload(user: dict, artist: dict | None) -> dict:
    return {
        "user_id": user["user_id"],
        "username": user["username"],
        "is_artist": bool(user["is_artist"]),
        "created_at": user["created_at"],
        "artist": artist,
    }


@router.post("/register")
def register(payload: dict = Depends(json_body), db=Depends(get_db)):
    username = payload.get("username")
    password = payload.get("password")
    is_artist = bool(payload.get("is_artist"))

    if not username or not password:
        raise HTTPException(400, "Username and password are required")
    if not isinstance(username, str) or not isinstance(password, str):
        raise HTTPException(400, "Username and password must be text")
    if len(password) < 6:
        raise HTTPException(400, "Password must be at least 6 characters")
    if len(username) > 100:
        raise HTTPException(400, "Username must be at most 100 characters")

    artist_name = payload.get("artist_name") or username
    country = payload.get("country") or None
    if is_artist:
        if not isinstance(artist_name, str) or len(artist_name) > 255:
            raise HTTPException(400, "Artist name must be at most 255 characters")
        if country is not None and (not isinstance(country, str) or len(country) > 100):
            raise HTTPException(400, "Country must be at most 100 characters")

    with transaction(db) as cur:
        cur.execute("SELECT 1 FROM User WHERE username = %s", (username,))
        if cur.fetchone():
            raise HTTPException(409, "Username already taken")

        cur.execute(
            "INSERT INTO User (username, password_hash, is_artist) VALUES (%s, %s, %s)",
            (username, hash_password(password), is_artist),
        )
        user_id = cur.lastrowid
        if is_artist:
            cur.execute(
                "INSERT INTO Artist (user_id, name, country, is_band) VALUES (%s, %s, %s, FALSE)",
                (user_id, artist_name, country),
            )

        cur.execute("SELECT user_id, username, is_artist, created_at FROM User WHERE user_id = %s", (user_id,))
        user = cur.fetchone()
        artist = get_artist(cur, user_id) if is_artist else None

    token = create_token(user["user_id"], user["username"], user["is_artist"])
    return respond({"token": token, "user": _user_payload(user, artist)}, 201)


@router.post("/login")
def login(payload: dict = Depends(json_body), db=Depends(get_db)):
    username = payload.get("username")
    password = payload.get("password")

    if not username or not password:
        raise HTTPException(400, "Username and password are required")
    if not isinstance(username, str) or not isinstance(password, str):
        raise HTTPException(400, "Username and password must be text")

    with transaction(db) as cur:
        cur.execute(
            "SELECT user_id, username, password_hash, is_artist, created_at FROM User WHERE username = %s",
            (username,),
        )
        user = cur.fetchone()
        if not user or not verify_password(password, user["password_hash"]):
            raise HTTPException(401, "Invalid credentials")

        cur.execute("UPDATE User SET last_login = NOW(3) WHERE user_id = %s", (user["user_id"],))
        artist = get_artist(cur, user["user_id"])

    token = create_token(user["user_id"], user["username"], user["is_artist"])
    return respond({"token": token, "user": _user_payload(user, artist)})


@router.get("/me")
def me(user=Depends(current_user), db=Depends(get_db)):
    with transaction(db) as cur:
        cur.execute(
            "SELECT user_id, username, is_artist, created_at, last_login FROM User WHERE user_id = %s",
            (user["userId"],),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(404, "User not found")
        artist = get_artist(cur, row["user_id"], with_house=True)

    data = _user_payload(row, artist)
    data["last_login"] = row["last_login"]
    return respond(data)
