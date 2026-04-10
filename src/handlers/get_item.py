"""Lambda handler: GET /items/{id} — fetch a single item."""
import logging

from utils.dynamodb import get_table, get_item_by_id
from utils.response import error, internal_error, not_found, success

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def handler(event: dict, context) -> dict:
    logger.info("get_item invoked", extra={"event": event})

    path_params = event.get("pathParameters") or {}
    item_id = path_params.get("id")

    if not item_id:
        return error("Missing path parameter: id", 400)

    try:
        table = get_table()
        item = get_item_by_id(table, item_id)

        if not item:
            logger.info("Item not found", extra={"item_id": item_id})
            return not_found("Item")

        logger.info("Item fetched", extra={"item_id": item_id})
        return success(item)
    except Exception as e:
        logger.exception("Failed to get item")
        return internal_error(e)
