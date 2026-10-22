from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db, transaction
from ..deps import current_user
from ..queries import USER_CARD_COLS, get_artist, like, user_card
from ..serializers import respond

router = APIRouter(prefix="/api/users")


@router.get("")
def list_users(username: str | None = None, _user=Depends(current_user), db=Depends(get_db)):
    sql = f"SELECT {USER_CARD_COLS} FROM User u LEFT JOIN Artist a ON a.user_id = u.user_id"
    params: list = []
    if username:
        sql += " WHERE u.username LIKE %s"
        params.append(like(username))
    sql += " ORDER BY u.username ASC LIMIT 50"

    with transaction(db) as cur:
        cur.execute(sql, params)
        return respond([user_card(r) for r in cur.fetchall()])


# Must be declared before /{user_id}
@router.get("/me/following")
def my_following(user=Depends(current_user), db=Depends(get_db)):
    with transaction(db) as cur:
        cur.execute(
            f"SELECT {USER_CARD_COLS} FROM Follow f "
            "JOIN User u ON u.user_id = f.followed_user_id "
            "LEFT JOIN Artist a ON a.user_id = u.user_id "
            "WHERE f.follower_user_id = %s",
            (user["userId"],),
        )
        return respond([user_card(r, include_created_at=False) for r in cur.fetchall()])


# Must be declared before /{user_id}
@router.get("/me/listening")
def my_listening(user=Depends(current_user), db=Depends(get_db)):
    """The caller's 20 most recent plays, newest first (Listening_Activity joined to Song + its primary artist)."""
    with transaction(db) as cur:
        cur.execute(
            "SELECT la.activity_id, la.listening_time, la.timestamp, "
            "s.song_id, s.song_name, s.duration, "
            "(SELECT a.name FROM Song_Artist_Relationship sar JOIN Artist a ON a.user_id = sar.artist_id "
            " WHERE sar.song_id = s.song_id AND sar.is_primary = 1 ORDER BY sar.artist_id LIMIT 1) AS artist_name "
            "FROM Listening_Activity la JOIN Song s ON s.song_id = la.song_id "
            "WHERE la.user_id = %s ORDER BY la.timestamp DESC, la.activity_id DESC LIMIT 20",
            (user["userId"],),
        )
        return respond(
            [
                {
                    "activity_id": r["activity_id"],
                    "listening_time": r["listening_time"],
                    "timestamp": r["timestamp"],
                    "song": {
                        "song_id": r["song_id"],
                        "song_name": r["song_name"],
                        "duration": r["duration"],
                        "artist_name": r["artist_name"],
                    },
                }
                for r in cur.fetchall()
            ]
        )


@router.get("/{user_id}")
def get_user(user_id: int, _user=Depends(current_user), db=Depends(get_db)):
    with transaction(db) as cur:
        cur.execute(
            "SELECT u.user_id, u.username, u.is_artist, u.created_at, "
            "(SELECT COUNT(*) FROM Follow WHERE follower_user_id = u.user_id) AS following_count, "
            "(SELECT COUNT(*) FROM Follow WHERE followed_user_id = u.user_id) AS followers_count, "
            "(SELECT COUNT(*) FROM Playlist WHERE created_by_user_id = u.user_id) AS playlists_count "
            "FROM User u WHERE u.user_id = %s",
            (user_id,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(404, "User not found")
        artist = get_artist(cur, user_id, with_house=True)

    return respond(
        {
            "user_id": row["user_id"],
            "username": row["username"],
            "is_artist": bool(row["is_artist"]),
            "created_at": row["created_at"],
            "artist": artist,
            "_count": {
                "following": row["following_count"],
                "followers": row["followers_count"],
                "playlists": row["playlists_count"],
            },
        }
    )
