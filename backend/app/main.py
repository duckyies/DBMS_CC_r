import logging
from datetime import datetime, timezone
from contextlib import asynccontextmanager

import pymysql
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from starlette.exceptions import HTTPException as StarletteHTTPException

from .config import settings
from .db import init_db
from .routes import artists, auth, collaborators, follow, playlists, songs, users
from .serializers import ApiResponse, respond

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("musiclib")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    settings.validate()
    init_db()
    log.info("Music Library API ready on port %s", settings.port)
    yield


app = FastAPI(title="MusicLib API", lifespan=lifespan, default_response_class=ApiResponse)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return respond({"status": "ok", "timestamp": datetime.now(timezone.utc).replace(tzinfo=None)})


# Order matters: the follow routes (/api/users/{id}/follow) are separate from users' /me/following.
for module in (auth, users, artists, songs, playlists, collaborators, follow):
    app.include_router(module.router)


# ── Errors: always {"error": "..."} like the previous API ────────────────────────────
@app.exception_handler(StarletteHTTPException)
async def http_error(_req: Request, exc: StarletteHTTPException):
    return respond({"error": exc.detail}, exc.status_code)


@app.exception_handler(RequestValidationError)
async def validation_error(_req: Request, exc: RequestValidationError):
    return respond({"error": "Invalid request: a path or query parameter has the wrong type"}, 400)


@app.exception_handler(pymysql.err.IntegrityError)
async def integrity_error(_req: Request, exc: pymysql.err.IntegrityError):
    code = exc.args[0] if exc.args else None
    if code == 1062:  # duplicate key
        return respond({"error": "A record with this value already exists."}, 409)
    if code == 1452:  # foreign key: parent row missing
        return respond({"error": "A referenced record does not exist."}, 400)
    if code == 1451:  # foreign key: row still referenced
        return respond({"error": "This record is still in use and cannot be deleted."}, 409)
    return await server_error(_req, exc)


@app.exception_handler(Exception)
async def server_error(_req: Request, exc: Exception):
    log.exception("Unhandled error")
    body = {"error": "Internal server error"}
    if settings.is_development:
        body["details"] = str(exc)
    return respond(body, 500)
