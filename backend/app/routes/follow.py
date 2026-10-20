from fastapi import APIRouter, Depends, HTTPException, Response

from ..db import get_db, transaction
from ..deps import current_user
from ..serializers import respond

router = APIRouter(prefix="/api/users")


@router.post("/{user_id}/follow")
def follow(user_id: int, user=Depends(current_user), db=Depends(get_db)):
    follower_id = user["userId"]
    if user_id == follower_id:
        raise HTTPException(400, "You cannot follow yourself")

    with transaction(db) as cur:
        cur.execute("SELECT username FROM User WHERE user_id = %s", (user_id,))
        target = cur.fetchone()
        if not target:
            raise HTTPException(404, "User not found")

        cur.execute(
            "SELECT 1 FROM Follow WHERE follower_user_id = %s AND followed_user_id = %s",
            (follower_id, user_id),
        )
        if cur.fetchone():
            raise HTTPException(409, "Already following this user")

        cur.execute(
            "INSERT INTO Follow (follower_user_id, followed_user_id) VALUES (%s, %s)",
            (follower_id, user_id),
        )

    return respond({"message": f"Now following {target['username']}"}, 201)


@router.delete("/{user_id}/follow")
def unfollow(user_id: int, user=Depends(current_user), db=Depends(get_db)):
    with transaction(db) as cur:
        cur.execute(
            "DELETE FROM Follow WHERE follower_user_id = %s AND followed_user_id = %s",
            (user["userId"], user_id),
        )
        if cur.rowcount == 0:
            raise HTTPException(404, "You are not following this user")

    return Response(status_code=204)
