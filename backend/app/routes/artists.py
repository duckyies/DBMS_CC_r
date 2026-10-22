from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db, transaction
from ..deps import current_user
from ..queries import PH_COLS, SONG_COLS, artist_dict, house_dict, json_col, like, song_dict
from ..serializers import respond

router = APIRouter(prefix="/api/artists")

_ARTIST_SELECT = (
    f"SELECT a.*, u.username AS u_username, u.created_at AS u_created_at, {PH_COLS} "
    "FROM Artist a JOIN User u ON u.user_id = a.user_id "
    "LEFT JOIN Production_House ph ON ph.production_house_id = a.production_house_id"
)


def _songs_by_artist(
    cur, artist_ids: list[int], primary_only: bool, viewer_id: int, limit: int | None = None
) -> dict[int, list]:
    """Songs per artist. Unpublished songs are only visible to the artist they belong to."""
    out: dict[int, list] = {i: [] for i in artist_ids}
    if not artist_ids:
        return out
    marks = ", ".join(["%s"] * len(artist_ids))
    sql = (
        f"SELECT sar.artist_id, sar.role, sar.is_primary, {SONG_COLS} "
        "FROM Song_Artist_Relationship sar JOIN Song s ON s.song_id = sar.song_id "
        f"WHERE sar.artist_id IN ({marks})" + (" AND sar.is_primary = 1" if primary_only else "") +
        " AND (s.is_published = 1 OR sar.artist_id = %s)"
        " ORDER BY sar.artist_id, sar.song_id"
    )
    params: list = [*artist_ids, viewer_id]
    if limit is not None:
        sql += " LIMIT %s"
        params.append(limit)
    cur.execute(sql, params)
    for r in cur.fetchall():
        out[r["artist_id"]].append(
            {
                "song_id": r["song_id"],
                "artist_id": r["artist_id"],
                "role": r["role"],
                "is_primary": bool(r["is_primary"]),
                "song": song_dict(r),
            }
        )
    return out


def _band_members(cur, rows: list[dict]) -> dict[int, dict]:
    """Resolve the user ids stored in Artist.band_member_ids (a JSON array, so no FK) to usernames."""
    ids = sorted({m for r in rows for m in (json_col(r["band_member_ids"]) or []) if isinstance(m, int)})
    if not ids:
        return {}
    cur.execute(
        f"SELECT user_id, username FROM User WHERE user_id IN ({', '.join(['%s'] * len(ids))})", ids
    )
    return {r["user_id"]: {"user_id": r["user_id"], "username": r["username"]} for r in cur.fetchall()}


def _artist_payload(row: dict, songs: list, user_with_created_at: bool, members: dict[int, dict]) -> dict:
    out = artist_dict(row)
    user = {"user_id": row["user_id"], "username": row["u_username"]}
    if user_with_created_at:
        user["created_at"] = row["u_created_at"]
    out["user"] = user
    out["production_house"] = house_dict(row)
    out["band_members"] = [members[m] for m in (out["band_member_ids"] or []) if m in members]
    out["songs"] = songs
    return out


@router.get("")
def list_artists(name: str | None = None, user=Depends(current_user), db=Depends(get_db)):
    sql = _ARTIST_SELECT
    params: list = []
    if name:
        sql += " WHERE a.name LIKE %s"
        params.append(like(name))
    sql += " ORDER BY a.name ASC LIMIT 50"

    with transaction(db) as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
        songs = _songs_by_artist(cur, [r["user_id"] for r in rows], primary_only=False, viewer_id=user["userId"])
        members = _band_members(cur, rows)

    return respond([_artist_payload(r, songs[r["user_id"]], False, members) for r in rows])


@router.get("/{user_id}")
def get_artist(user_id: int, user=Depends(current_user), db=Depends(get_db)):
    with transaction(db) as cur:
        cur.execute(_ARTIST_SELECT + " WHERE a.user_id = %s", (user_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(404, "Artist not found")
        songs = _songs_by_artist(cur, [user_id], primary_only=False, viewer_id=user["userId"], limit=20)
        members = _band_members(cur, [row])

    return respond(_artist_payload(row, songs[user_id], True, members))
