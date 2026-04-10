"""Lambda handler: POST /items — create a new item."""
import logging
import uuid
from datetime import datetime, timezone

from utils.dynamodb import get_table, put_item
from utils.response import error, internal_error, success
from utils.validators import (
    parse_body,
    sanitize_string,
    validate_required_fields,
    validate_string_length,
)

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

REQUIRED_FIELDS = ["name", "category"]
MAX_DESCRIPTION_LENGTH = 1000


def handler(event: dict, context) -> dict:
    logger.info("create_item invoked", extra={"event": event})

    body, parse_error = parse_body(event)
    if parse_error:
        return error(parse_error, 400)

    validation_error = validate_required_fields(body, REQUIRED_FIELDS)
    if validation_error:
        return error(validation_error, 400)

    name = sanitize_string(body["name"])
    category = sanitize_string(body["category"])
    description = sanitize_string(body.get("description", ""))

    if not name:
        return error("Field 'name' cannot be empty", 400)

    if description:
        length_error = validate_string_length(description, "description", MAX_DESCRIPTION_LENGTH)
        if length_error:
            return error(length_error, 400)

    item = {
        "id": str(uuid.uuid4()),
        "name": name,
        "category": category,
        "description": description,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }

    try:
        table = get_table()
        created = put_item(table, item)
        logger.info("Item created", extra={"item_id": created["id"]})
        return success(created, 201)
    except Exception as e:
        logger.exception("Failed to create item")
        return internal_error(e)
