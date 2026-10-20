"""Direct MySQL access via PyMySQL: connections, per-request transactions, schema/seed bootstrap."""

import logging
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

import pymysql
from pymysql.connections import Connection
from pymysql.constants import CLIENT
from pymysql.cursors import DictCursor

from .config import settings

log = logging.getLogger("musiclib.db")

DB_DIR = Path(__file__).resolve().parent.parent / "db"

# Match the table collation so comparisons and LIKE searches behave the same everywhere.
_INIT_COMMAND = "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci"


def connect(**extra) -> Connection:
    return pymysql.connect(
        **settings.db_connect_args(),
        charset="utf8mb4",
        cursorclass=DictCursor,
        autocommit=False,
        init_command=_INIT_COMMAND,
        **extra,
    )


def get_db() -> Iterator[Connection]:
    """FastAPI dependency: one connection per request (closed afterwards)."""
    conn = connect()
    try:
        yield conn
    finally:
        conn.close()


@contextmanager
def transaction(conn: Connection):
    """Cursor for one unit of work: committed when the block ends, rolled back if it raises.

    Handlers commit here, before returning their response, so the client can never see its own
    write as missing on the next request (a yield-dependency's cleanup runs after the response).
    """
    cur = conn.cursor()
    try:
        yield cur
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()


def _run_script(cur, path: Path) -> None:
    cur.execute(path.read_text(encoding="utf-8"))
    while cur.nextset():  # surfaces errors from later statements in the script
        pass


def init_db() -> None:
    """Wait for MySQL, then create any missing tables and (optionally) load the demo data."""
    deadline = time.monotonic() + settings.db_wait_seconds
    while True:
        try:
            conn = connect(client_flag=CLIENT.MULTI_STATEMENTS)
            break
        except pymysql.err.OperationalError as exc:
            if time.monotonic() >= deadline:
                raise
            log.warning("Waiting for MySQL (%s)...", exc)
            time.sleep(2)

    try:
        with conn.cursor() as cur:
            _run_script(cur, DB_DIR / "schema.sql")
            log.info("Schema ready")
            if settings.seed_demo_data:
                _run_script(cur, DB_DIR / "seed.sql")
                log.info("Demo data ready")
        conn.commit()
    finally:
        conn.close()
