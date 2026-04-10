"""Request validation helpers."""
import json
from typing import Any


def parse_body(event: dict) -> tuple[dict | None, str | None]:
    """Parse and return request body or an error message."""
    body = event.get("body")
    if not body:
        return None, "Request body is required"
    try:
        if isinstance(body, str):
            return json.loads(body), None
        return body, None
    except json.JSONDecodeError:
        return None, "Invalid JSON in request body"


def validate_required_fields(data: dict, fields: list[str]) -> str | None:
    """Return error message if any required field is missing."""
    missing = [f for f in fields if not data.get(f)]
    if missing:
        return f"Missing required fields: {', '.join(missing)}"
    return None


def validate_string_length(value: str, field: str, max_length: int = 500) -> str | None:
    if len(value) > max_length:
        return f"Field '{field}' exceeds maximum length of {max_length} characters"
    return None


def sanitize_string(value: Any) -> str:
    """Convert to string and strip whitespace."""
    return str(value).strip()
