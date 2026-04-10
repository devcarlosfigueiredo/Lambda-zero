"""Lambda handler: DELETE /items/{id} — delete an item."""
import logging

from utils.dynamodb import delete_item_by_id, get_table
from utils.response import error, internal_error, not_found, success

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def handler(event: dict, context) -> dict:
    logger.info("delete_item invoked", extra={"event": event})

    path_params = event.get("pathParameters") or {}
    item_id = path_params.get("id")

    if not item_id:
        return error("Missing path parameter: id", 400)

    try:
        table = get_table()
        deleted = delete_item_by_id(table, item_id)

        if not deleted:
            logger.info("Item not found for deletion", extra={"item_id": item_id})
            return not_found("Item")

        logger.info("Item deleted", extra={"item_id": item_id})
        return success({"message": "Item deleted successfully", "id": item_id})
    except Exception as e:
        logger.exception("Failed to delete item")
        return internal_error(e)
