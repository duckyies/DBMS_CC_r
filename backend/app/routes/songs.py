from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db, transaction
from ..deps import current_user, json_body
from ..queries import SONG_COLS, attach_song_artists, like, song_dict
from ..serializers import respond

router = APIRouter(prefix="/api/songs")


@router.get("")
def list_songs(q: str | None = None, genre: str | None = None, _user=Depends(current_user), db=Depends(get_db)):
    sql = f"SELECT {SONG_COLS} FROM Song s WHERE s.is_published = 1"
    params: list = []
    if q:
        sql += " AND s.song_name LIKE %s"
        params.append(like(q))
    if genre:
        # genres is a JSON array such as ["Pop", "Synthwave"]; match one whole (quoted) entry, so "Pop" never hits "Synthpop"
        sql += " AND LOWER(CAST(s.genres AS CHAR)) LIKE %s"
        params.append('%"' + like(genre.lower())[1:-1] + '"%')
    sql += " ORDER BY s.listen_count DESC, s.song_id ASC LIMIT 50"

    with transaction(db) as cur:
        cur.execute(sql, params)
        songs = [song_dict(r) for r in cur.fetchall()]
        attach_song_artists(cur, songs, primary_only=True)

    return respond(songs)


@router.get("/{song_id}")
def get_song(song_id: int, _user=Depends(current_user), db=Depends(get_db)):
    with transaction(db) as cur:
        cur.execute(f"SELECT {SONG_COLS} FROM Song s WHERE s.song_id = %s", (song_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(404, "Song not found")
        song = song_dict(row)
        attach_song_artists(cur, [song], primary_only=False, detailed=True)

    return respond(song)


@router.get("/{song_id}/lyrics")
def get_lyrics(song_id: int, _user=Depends(current_user), db=Depends(get_db)):
    with transaction(db) as cur:
        cur.execute("SELECT song_id, song_name FROM Song WHERE song_id = %s", (song_id,))
        song = cur.fetchone()
        if not song:
            raise HTTPException(404, "Song not found")
        cur.execute(
            "SELECT lyrics_id, lyrics_filename, lyrics_text FROM Lyrics WHERE song_id = %s ORDER BY lyrics_id",
            (song_id,),
        )
        lyrics = cur.fetchall()

    return respond({"song_id": song["song_id"], "song_name": song["song_name"], "lyrics": lyrics})


# Increment listen count + log the activity
@router.post("/{song_id}/listen")
def listen(song_id: int, user=Depends(current_user), payload: dict = Depends(json_body), db=Depends(get_db)):
    listening_time = payload.get("listening_time", 0)
    if listening_time is None:
        listening_time = 0
    if isinstance(listening_time, bool) or not isinstance(listening_time, int) or listening_time < 0:
        raise HTTPException(400, "listening_time must be a non-negative integer (seconds)")

    with transaction(db) as cur:
        cur.execute("UPDATE Song SET listen_count = listen_count + 1 WHERE song_id = %s", (song_id,))
        if cur.rowcount == 0:
            raise HTTPException(404, "Song not found")
        cur.execute(
            "INSERT INTO Listening_Activity (user_id, song_id, listening_time) VALUES (%s, %s, %s)",
            (user["userId"], song_id, listening_time),
        )

    return respond({"message": "Listened"})
