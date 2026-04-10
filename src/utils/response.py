"""HTTP response helpers for Lambda functions."""
import json
from typing import Any


def success(body: Any, status_code: int = 200) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "X-Content-Type-Options": "nosniff",
        },
        "body": json.dumps(body, default=str),
    }


def error(message: str, status_code: int = 400) -> dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"error": message}),
    }


def not_found(resource: str = "Item") -> dict:
    return error(f"{resource} not found", 404)


def internal_error(e: Exception) -> dict:
    return error(f"Internal server error: {str(e)}", 500)
