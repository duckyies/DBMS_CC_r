from fastapi import APIRouter, Depends, HTTPException, Response

from ..db import get_db, transaction
from ..deps import current_user, json_body
from ..queries import (
    SONG_COLS,
    attach_song_artists,
    playlist_dict,
    playlist_summary,
    playlist_summary_dict,
    recalc_playlist_duration,
    song_dict,
)
from ..serializers import respond

router = APIRouter(prefix="/api/playlists")

RELEASE_TYPES = ("Single", "EP", "Album")


def _can_mutate(cur, playlist_id: int, user_id: int) -> bool:
    """Owner or collaborator."""
    cur.execute("SELECT created_by_user_id FROM Playlist WHERE playlist_id = %s", (playlist_id,))
    row = cur.fetchone()
    if not row:
        return False
    if row["created_by_user_id"] == user_id:
        return True
    cur.execute(
        "SELECT 1 FROM Playlist_Collaborator WHERE playlist_id = %s AND user_id = %s",
        (playlist_id, user_id),
    )
    return cur.fetchone() is not None


def _clean_release_type(value, user: dict):
    """Validate a release_type from the request body; returns the value to store (None clears it)."""
    if not value:
        return None
    if not user["isArtist"]:
        raise HTTPException(403, "Only artists can set a release type")
    if value not in RELEASE_TYPES:
        raise HTTPException(400, "Invalid release_type. Must be Single, EP, or Album")
    return value


def _clean_text(payload: dict, key: str, max_len: int, label: str):
    value = payload.get(key)
    if value is not None and (not isinstance(value, str) or len(value) > max_len):
        raise HTTPException(400, f"{label} must be text of at most {max_len} characters")
    return value


# List playlists the user owns OR collaborates on
@router.get("")
def list_playlists(user=Depends(current_user), db=Depends(get_db)):
    uid = user["userId"]
    with transaction(db) as cur:
        cur.execute(
            "SELECT p.*, u.username AS creator_username, "
            "(SELECT COUNT(*) FROM Playlist_Song ps WHERE ps.playlist_id = p.playlist_id) AS songs_count, "
            "(SELECT COUNT(*) FROM Playlist_Collaborator pc WHERE pc.playlist_id = p.playlist_id) AS collaborators_count "
            "FROM Playlist p JOIN User u ON u.user_id = p.created_by_user_id "
            "WHERE p.created_by_user_id = %s "
            "   OR EXISTS (SELECT 1 FROM Playlist_Collaborator c WHERE c.playlist_id = p.playlist_id AND c.user_id = %s) "
            "ORDER BY p.last_updated DESC, p.playlist_id DESC",
            (uid, uid),
        )
        return respond([playlist_summary_dict(r, True) for r in cur.fetchall()])


@router.post("")
def create_playlist(user=Depends(current_user), payload: dict = Depends(json_body), db=Depends(get_db)):
    name = payload.get("name")
    if not name:
        raise HTTPException(400, "Playlist name is required")
    if not isinstance(name, str) or len(name) > 255:
        raise HTTPException(400, "Playlist name must be text of at most 255 characters")
    cover_art_url = _clean_text(payload, "cover_art_url", 500, "cover_art_url") or None
    release_type = _clean_release_type(payload.get("release_type"), user)

    with transaction(db) as cur:
        cur.execute(
            "INSERT INTO Playlist (name, created_by_user_id, cover_art_url, release_type, is_shared, duration, last_updated) "
            "VALUES (%s, %s, %s, %s, %s, 0, NOW(3))",
            (name, user["userId"], cover_art_url, release_type, bool(payload.get("is_shared"))),
        )
        playlist = playlist_summary(cur, cur.lastrowid)

    return respond(playlist, 201)


@router.get("/{playlist_id}")
def get_playlist(playlist_id: int, user=Depends(current_user), db=Depends(get_db)):
    with transaction(db) as cur:
        cur.execute(
            "SELECT p.*, u.username AS creator_username FROM Playlist p "
            "JOIN User u ON u.user_id = p.created_by_user_id WHERE p.playlist_id = %s",
            (playlist_id,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(404, "Playlist not found")

        cur.execute(
            "SELECT pc.playlist_id, pc.user_id, u.username, u.is_artist FROM Playlist_Collaborator pc "
            "JOIN User u ON u.user_id = pc.user_id WHERE pc.playlist_id = %s ORDER BY pc.user_id",
            (playlist_id,),
        )
        collaborators = [
            {
                "playlist_id": c["playlist_id"],
                "user_id": c["user_id"],
                "user": {"user_id": c["user_id"], "username": c["username"], "is_artist": bool(c["is_artist"])},
            }
            for c in cur.fetchall()
        ]

        # Access: owner, collaborator, or the playlist is shared
        uid = user["userId"]
        is_owner = row["created_by_user_id"] == uid
        is_collaborator = any(c["user_id"] == uid for c in collaborators)
        if not is_owner and not is_collaborator and not row["is_shared"]:
            raise HTTPException(403, "Access denied")

        cur.execute(
            f"SELECT ps.playlist_id, ps.song_id, ps.`order`, {SONG_COLS} FROM Playlist_Song ps "
            "JOIN Song s ON s.song_id = ps.song_id WHERE ps.playlist_id = %s ORDER BY ps.`order` ASC, ps.song_id ASC",
            (playlist_id,),
        )
        entries = cur.fetchall()
        songs = [song_dict(e) for e in entries]
        attach_song_artists(cur, songs, primary_only=True)

    playlist = playlist_dict(row)
    playlist["creator"] = {"user_id": row["created_by_user_id"], "username": row["creator_username"]}
    playlist["songs"] = [
        {"playlist_id": e["playlist_id"], "song_id": e["song_id"], "order": e["order"], "song": song}
        for e, song in zip(entries, songs)
    ]
    playlist["collaborators"] = collaborators
    return respond(playlist)


@router.put("/{playlist_id}")
def update_playlist(
    playlist_id: int, user=Depends(current_user), payload: dict = Depends(json_body), db=Depends(get_db)
):
    with transaction(db) as cur:
        cur.execute("SELECT created_by_user_id FROM Playlist WHERE playlist_id = %s", (playlist_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(404, "Playlist not found")
        if row["created_by_user_id"] != user["userId"]:
            raise HTTPException(403, "Only the playlist owner can update it")

        # Only the fields present in the body are changed
        sets = ["last_updated = NOW(3)"]
        params: list = []
        if payload.get("name"):
            sets.append("name = %s")
            params.append(_clean_text(payload, "name", 255, "Playlist name"))
        if "cover_art_url" in payload:
            sets.append("cover_art_url = %s")
            params.append(_clean_text(payload, "cover_art_url", 500, "cover_art_url"))
        if "release_type" in payload:
            sets.append("release_type = %s")
            params.append(_clean_release_type(payload["release_type"], user))
        if "is_shared" in payload:
            sets.append("is_shared = %s")
            params.append(bool(payload["is_shared"]))

        cur.execute(f"UPDATE Playlist SET {', '.join(sets)} WHERE playlist_id = %s", (*params, playlist_id))
        playlist = playlist_summary(cur, playlist_id)

    return respond(playlist)


@router.delete("/{playlist_id}")
def delete_playlist(playlist_id: int, user=Depends(current_user), db=Depends(get_db)):
    with transaction(db) as cur:
        cur.execute("SELECT created_by_user_id FROM Playlist WHERE playlist_id = %s", (playlist_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(404, "Playlist not found")
        if row["created_by_user_id"] != user["userId"]:
            raise HTTPException(403, "Only the owner can delete a playlist")

        cur.execute("DELETE FROM Playlist WHERE playlist_id = %s", (playlist_id,))  # songs/collaborators cascade

    return Response(status_code=204)


@router.post("/{playlist_id}/songs")
def add_song(playlist_id: int, user=Depends(current_user), payload: dict = Depends(json_body), db=Depends(get_db)):
    raw_song_id = payload.get("song_id")
    try:
        song_id = int(raw_song_id)
    except (TypeError, ValueError):
        song_id = 0
    if not song_id:
        raise HTTPException(400, "Invalid playlist ID or song_id")

    with transaction(db) as cur:
        if not _can_mutate(cur, playlist_id, user["userId"]):
            raise HTTPException(403, "Access denied")

        cur.execute("SELECT 1 FROM Song WHERE song_id = %s AND is_published = 1", (song_id,))
        if not cur.fetchone():
            raise HTTPException(404, "Song not found")

        # Lock the playlist row so two concurrent adds cannot pick the same position
        cur.execute("SELECT playlist_id FROM Playlist WHERE playlist_id = %s FOR UPDATE", (playlist_id,))

        cur.execute("SELECT 1 FROM Playlist_Song WHERE playlist_id = %s AND song_id = %s", (playlist_id, song_id))
        if cur.fetchone():
            raise HTTPException(409, "Song already in playlist")

        cur.execute("SELECT COALESCE(MAX(`order`), 0) AS max_order FROM Playlist_Song WHERE playlist_id = %s", (playlist_id,))
        next_order = cur.fetchone()["max_order"] + 1

        cur.execute(
            "INSERT INTO Playlist_Song (playlist_id, song_id, `order`) VALUES (%s, %s, %s)",
            (playlist_id, song_id, next_order),
        )
        recalc_playlist_duration(cur, playlist_id)

    return respond({"message": "Song added to playlist"}, 201)


@router.delete("/{playlist_id}/songs/{song_id}")
def remove_song(playlist_id: int, song_id: int, user=Depends(current_user), db=Depends(get_db)):
    with transaction(db) as cur:
        if not _can_mutate(cur, playlist_id, user["userId"]):
            raise HTTPException(403, "Access denied")

        cur.execute("DELETE FROM Playlist_Song WHERE playlist_id = %s AND song_id = %s", (playlist_id, song_id))
        if cur.rowcount == 0:
            raise HTTPException(404, "Song is not in this playlist")
        recalc_playlist_duration(cur, playlist_id)

    return Response(status_code=204)
