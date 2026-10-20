"""SQL fragments and row -> JSON shaping shared by several routes."""

import json
from typing import Any

SONG_COLS = "s.song_id, s.song_name, s.duration, s.publish_date, s.genres, s.listen_count, s.is_published"

# Columns for a "user card": the user plus the (optional) artist name/country.
USER_CARD_COLS = (
    "u.user_id, u.username, u.is_artist, u.created_at, "
    "a.user_id AS artist_user_id, a.name AS artist_name, a.country AS artist_country"
)


def like(term: str) -> str:
    """Build a %term% LIKE pattern with the user's own wildcards escaped."""
    escaped = term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


def json_col(value: Any) -> Any:
    if isinstance(value, (str, bytes)):
        return json.loads(value)
    return value


def song_dict(r: dict) -> dict:
    return {
        "song_id": r["song_id"],
        "song_name": r["song_name"],
        "duration": r["duration"],
        "publish_date": r["publish_date"],
        "genres": json_col(r["genres"]),
        "listen_count": r["listen_count"],
        "is_published": bool(r["is_published"]),
    }


def artist_dict(r: dict) -> dict:
    return {
        "user_id": r["user_id"],
        "name": r["name"],
        "country": r["country"],
        "is_band": bool(r["is_band"]),
        "band_member_ids": json_col(r["band_member_ids"]),
        "country_of_origin": r["country_of_origin"],
        "production_house_id": r["production_house_id"],
        "created_at": r["created_at"],
    }


def house_dict(r: dict) -> dict | None:
    """Production house from a row that LEFT JOINed it as ph_id / ph_name / ph_type."""
    if r["ph_id"] is None:
        return None
    return {"production_house_id": r["ph_id"], "name": r["ph_name"], "type": r["ph_type"]}


PH_COLS = "ph.production_house_id AS ph_id, ph.name AS ph_name, ph.type AS ph_type"


def user_card(r: dict, include_created_at: bool = True) -> dict:
    out = {"user_id": r["user_id"], "username": r["username"], "is_artist": bool(r["is_artist"])}
    if include_created_at:
        out["created_at"] = r["created_at"]
    out["artist"] = (
        {"name": r["artist_name"], "country": r["artist_country"]}
        if r["artist_user_id"] is not None
        else None
    )
    return out


def get_artist(cur, user_id: int, with_house: bool = False) -> dict | None:
    cur.execute(
        f"SELECT a.*, {PH_COLS} FROM Artist a "
        "LEFT JOIN Production_House ph ON ph.production_house_id = a.production_house_id "
        "WHERE a.user_id = %s",
        (user_id,),
    )
    row = cur.fetchone()
    if row is None:
        return None
    artist = artist_dict(row)
    if with_house:
        artist["production_house"] = house_dict(row)
    return artist


def attach_song_artists(cur, songs: list[dict], primary_only: bool, detailed: bool = False) -> None:
    """Add song["artists"] = [{song_id, artist_id, role, is_primary, artist: {...}}, ...] to each song."""
    for song in songs:
        song["artists"] = []
    if not songs:
        return
    by_id = {s["song_id"]: s for s in songs}
    marks = ", ".join(["%s"] * len(by_id))
    cur.execute(
        f"SELECT sar.song_id, sar.artist_id, sar.role, sar.is_primary, "
        f"a.name AS artist_name, a.country AS artist_country, {PH_COLS} "
        "FROM Song_Artist_Relationship sar "
        "JOIN Artist a ON a.user_id = sar.artist_id "
        "LEFT JOIN Production_House ph ON ph.production_house_id = a.production_house_id "
        f"WHERE sar.song_id IN ({marks})" + (" AND sar.is_primary = 1" if primary_only else "") +
        " ORDER BY sar.song_id, sar.artist_id",
        list(by_id),
    )
    for r in cur.fetchall():
        artist = {"name": r["artist_name"], "user_id": r["artist_id"]}
        if detailed:
            artist["country"] = r["artist_country"]
            artist["production_house"] = house_dict(r)
        by_id[r["song_id"]]["artists"].append(
            {
                "song_id": r["song_id"],
                "artist_id": r["artist_id"],
                "role": r["role"],
                "is_primary": bool(r["is_primary"]),
                "artist": artist,
            }
        )


def playlist_dict(r: dict) -> dict:
    return {
        "playlist_id": r["playlist_id"],
        "name": r["name"],
        "created_by_user_id": r["created_by_user_id"],
        "cover_art_url": r["cover_art_url"],
        "duration": r["duration"],
        "release_type": r["release_type"],
        "last_updated": r["last_updated"],
        "is_shared": bool(r["is_shared"]),
    }


def playlist_summary(cur, playlist_id: int, with_collaborator_count: bool = False) -> dict | None:
    """Playlist + creator + _count, the shape returned by list/create/update."""
    cur.execute(
        "SELECT p.*, u.username AS creator_username, "
        "(SELECT COUNT(*) FROM Playlist_Song ps WHERE ps.playlist_id = p.playlist_id) AS songs_count, "
        "(SELECT COUNT(*) FROM Playlist_Collaborator pc WHERE pc.playlist_id = p.playlist_id) AS collaborators_count "
        "FROM Playlist p JOIN User u ON u.user_id = p.created_by_user_id WHERE p.playlist_id = %s",
        (playlist_id,),
    )
    row = cur.fetchone()
    return playlist_summary_dict(row, with_collaborator_count) if row else None


def playlist_summary_dict(r: dict, with_collaborator_count: bool) -> dict:
    out = playlist_dict(r)
    out["creator"] = {"user_id": r["created_by_user_id"], "username": r["creator_username"]}
    out["_count"] = {"songs": r["songs_count"]}
    if with_collaborator_count:
        out["_count"]["collaborators"] = r["collaborators_count"]
    return out


def recalc_playlist_duration(cur, playlist_id: int) -> None:
    cur.execute(
        "UPDATE Playlist SET last_updated = NOW(3), duration = ("
        "  SELECT COALESCE(SUM(s.duration), 0) FROM Playlist_Song ps "
        "  JOIN Song s ON s.song_id = ps.song_id WHERE ps.playlist_id = %s"
        ") WHERE playlist_id = %s",
        (playlist_id, playlist_id),
    )
