from fastapi import APIRouter, Depends, HTTPException, Response

from ..db import get_db, transaction
from ..deps import current_user, json_body
from ..serializers import respond

router = APIRouter(prefix="/api/playlists")


def _get_playlist(cur, playlist_id: int) -> dict:
    cur.execute("SELECT playlist_id, created_by_user_id FROM Playlist WHERE playlist_id = %s", (playlist_id,))
    row = cur.fetchone()
    if not row:
        raise HTTPException(404, "Playlist not found")
    return row


@router.get("/{playlist_id}/collaborators")
def list_collaborators(playlist_id: int, user=Depends(current_user), db=Depends(get_db)):
    uid = user["userId"]
    with transaction(db) as cur:
        playlist = _get_playlist(cur, playlist_id)

        # Only the owner or a collaborator can view the list
        cur.execute(
            "SELECT 1 FROM Playlist_Collaborator WHERE playlist_id = %s AND user_id = %s",
            (playlist_id, uid),
        )
        if playlist["created_by_user_id"] != uid and not cur.fetchone():
            raise HTTPException(403, "Access denied")

        cur.execute(
            "SELECT u.user_id, u.username, u.is_artist FROM Playlist_Collaborator pc "
            "JOIN User u ON u.user_id = pc.user_id WHERE pc.playlist_id = %s ORDER BY u.user_id",
            (playlist_id,),
        )
        return respond(
            [
                {"user_id": r["user_id"], "username": r["username"], "is_artist": bool(r["is_artist"])}
                for r in cur.fetchall()
            ]
        )


# Add by username
@router.post("/{playlist_id}/collaborators")
def add_collaborator(
    playlist_id: int, user=Depends(current_user), payload: dict = Depends(json_body), db=Depends(get_db)
):
    username = payload.get("username")
    if not username or not isinstance(username, str):
        raise HTTPException(400, "Playlist ID and username are required")

    with transaction(db) as cur:
        playlist = _get_playlist(cur, playlist_id)
        if playlist["created_by_user_id"] != user["userId"]:
            raise HTTPException(403, "Only the playlist owner can add collaborators")

        cur.execute("SELECT user_id, username FROM User WHERE username = %s", (username,))
        target = cur.fetchone()
        if not target:
            raise HTTPException(404, f'User "{username}" not found')
        if target["user_id"] == user["userId"]:
            raise HTTPException(400, "You cannot add yourself as a collaborator")

        cur.execute(
            "SELECT 1 FROM Playlist_Collaborator WHERE playlist_id = %s AND user_id = %s",
            (playlist_id, target["user_id"]),
        )
        if cur.fetchone():
            raise HTTPException(409, "User is already a collaborator")

        cur.execute(
            "INSERT INTO Playlist_Collaborator (playlist_id, user_id) VALUES (%s, %s)",
            (playlist_id, target["user_id"]),
        )

    return respond(
        {
            "message": f"{username} added as collaborator",
            "user": {"user_id": target["user_id"], "username": target["username"]},
        },
        201,
    )


@router.delete("/{playlist_id}/collaborators/{target_user_id}")
def remove_collaborator(playlist_id: int, target_user_id: int, user=Depends(current_user), db=Depends(get_db)):
    with transaction(db) as cur:
        playlist = _get_playlist(cur, playlist_id)
        if playlist["created_by_user_id"] != user["userId"]:
            raise HTTPException(403, "Only the playlist owner can remove collaborators")

        cur.execute(
            "DELETE FROM Playlist_Collaborator WHERE playlist_id = %s AND user_id = %s",
            (playlist_id, target_user_id),
        )
        if cur.rowcount == 0:
            raise HTTPException(404, "User is not a collaborator on this playlist")

    return Response(status_code=204)
