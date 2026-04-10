"""Lambda handler: GET /items — list all items or filter by category."""
import logging

from utils.dynamodb import get_table, query_by_category, scan_all_items
from utils.response import internal_error, success

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def handler(event: dict, context) -> dict:
    logger.info("list_items invoked")

    query_params = event.get("queryStringParameters") or {}
    category = query_params.get("category")

    try:
        table = get_table()

        if category:
            logger.info("Querying by category", extra={"category": category})
            items = query_by_category(table, category)
        else:
            logger.info("Scanning all items")
            items = scan_all_items(table)

        logger.info("Items listed", extra={"count": len(items)})
        return success({"items": items, "count": len(items)})
    except Exception as e:
        logger.exception("Failed to list items")
        return internal_error(e)
