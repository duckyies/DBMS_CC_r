import os
from urllib.parse import unquote, urlparse


def _flag(name: str, default: bool) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in ("1", "true", "yes", "on")


class Settings:
    def __init__(self) -> None:
        self.database_url = os.environ.get("DATABASE_URL", "")
        self.jwt_secret = os.environ.get("JWT_SECRET", "")
        self.port = int(os.environ.get("PORT", "3001"))
        self.is_development = os.environ.get("APP_ENV", "production").lower() == "development"
        self.seed_demo_data = _flag("SEED_DEMO_DATA", True)
        self.db_wait_seconds = int(os.environ.get("DB_WAIT_SECONDS", "90"))
        self.cors_origins = [
            o.strip()
            for o in os.environ.get(
                "CORS_ORIGINS", "http://localhost:5173,http://frontend:5173"
            ).split(",")
            if o.strip()
        ]

    def validate(self) -> None:
        if not self.jwt_secret:
            raise RuntimeError("JWT_SECRET is not set")
        if not self.database_url.startswith("mysql"):
            raise RuntimeError("DATABASE_URL must look like mysql://user:password@host:3306/dbname")

    def db_connect_args(self) -> dict:
        url = urlparse(self.database_url)
        return {
            "host": url.hostname,
            "port": url.port or 3306,
            "user": unquote(url.username or ""),
            "password": unquote(url.password or ""),
            "database": url.path.lstrip("/"),
        }


settings = Settings()
