"""Tests for get_item, list_items, and delete_item Lambda handlers."""
import json
import uuid
from datetime import datetime, timezone

import pytest
from moto import mock_aws

from handlers.delete_item import handler as delete_handler
from handlers.get_item import handler as get_handler
from handlers.list_items import handler as list_handler


def seed_item(table, name="Widget", category="electronics"):
    item = {
        "id": str(uuid.uuid4()),
        "name": name,
        "category": category,
        "description": "A seeded item",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    table.put_item(Item=item)
    return item


# ── get_item tests ────────────────────────────────────────────────────────────

@mock_aws
def test_get_item_success(dynamodb_table):
    item = seed_item(dynamodb_table)
    event = {"pathParameters": {"id": item["id"]}}
    response = get_handler(event, None)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["id"] == item["id"]
    assert body["name"] == item["name"]


@mock_aws
def test_get_item_not_found(dynamodb_table):
    event = {"pathParameters": {"id": "nonexistent-id"}}
    response = get_handler(event, None)

    assert response["statusCode"] == 404
    body = json.loads(response["body"])
    assert "not found" in body["error"].lower()


@mock_aws
def test_get_item_missing_id(dynamodb_table):
    response = get_handler({"pathParameters": {}}, None)

    assert response["statusCode"] == 400


# ── list_items tests ──────────────────────────────────────────────────────────

@mock_aws
def test_list_items_empty(dynamodb_table):
    response = list_handler({"queryStringParameters": None}, None)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["items"] == []
    assert body["count"] == 0


@mock_aws
def test_list_items_returns_all(dynamodb_table):
    seed_item(dynamodb_table, "Item A", "tools")
    seed_item(dynamodb_table, "Item B", "electronics")
    seed_item(dynamodb_table, "Item C", "tools")

    response = list_handler({"queryStringParameters": None}, None)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["count"] == 3


@mock_aws
def test_list_items_filter_by_category(dynamodb_table):
    seed_item(dynamodb_table, "Hammer", "tools")
    seed_item(dynamodb_table, "Drill", "tools")
    seed_item(dynamodb_table, "Phone", "electronics")

    response = list_handler({"queryStringParameters": {"category": "tools"}}, None)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["count"] == 2
    assert all(i["category"] == "tools" for i in body["items"])


# ── delete_item tests ─────────────────────────────────────────────────────────

@mock_aws
def test_delete_item_success(dynamodb_table):
    item = seed_item(dynamodb_table)
    event = {"pathParameters": {"id": item["id"]}}
    response = delete_handler(event, None)

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["id"] == item["id"]

    # Confirm it's actually gone
    get_response = get_handler(event, None)
    assert get_response["statusCode"] == 404


@mock_aws
def test_delete_item_not_found(dynamodb_table):
    event = {"pathParameters": {"id": "ghost-id"}}
    response = delete_handler(event, None)

    assert response["statusCode"] == 404


@mock_aws
def test_delete_item_missing_id(dynamodb_table):
    response = delete_handler({"pathParameters": {}}, None)

    assert response["statusCode"] == 400
