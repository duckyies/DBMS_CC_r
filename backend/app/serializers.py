"""JSON output that matches what the React frontend already expects (ISO-8601 UTC with milliseconds)."""

import json
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Any

from fastapi.responses import JSONResponse


def _default(value: Any) -> Any:
    if isinstance(value, datetime):
        if value.tzinfo is not None:
            value = value.astimezone(timezone.utc).replace(tzinfo=None)
        return f"{value:%Y-%m-%dT%H:%M:%S}.{value.microsecond // 1000:03d}Z"
    if isinstance(value, date):
        return f"{value:%Y-%m-%d}T00:00:00.000Z"
    if isinstance(value, Decimal):
        return int(value) if value == value.to_integral_value() else float(value)
    raise TypeError(f"Cannot serialize {type(value).__name__}")


class ApiResponse(JSONResponse):
    def render(self, content: Any) -> bytes:
        return json.dumps(content, default=_default, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def respond(data: Any, status_code: int = 200) -> ApiResponse:
    return ApiResponse(content=data, status_code=status_code)
