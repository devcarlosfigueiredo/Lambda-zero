"""Tests for create_item Lambda handler."""
import json

import pytest
from moto import mock_aws

from handlers.create_item import handler


def make_event(body: dict | None = None, raw: str | None = None) -> dict:
    return {"body": json.dumps(body) if body is not None else raw}


@mock_aws
def test_create_item_success(dynamodb_table):
    event = make_event({"name": "Test Widget", "category": "electronics", "description": "A test item"})
    response = handler(event, None)

    assert response["statusCode"] == 201
    body = json.loads(response["body"])
    assert body["name"] == "Test Widget"
    assert body["category"] == "electronics"
    assert body["description"] == "A test item"
    assert "id" in body
    assert "created_at" in body


@mock_aws
def test_create_item_missing_name(dynamodb_table):
    event = make_event({"category": "electronics"})
    response = handler(event, None)

    assert response["statusCode"] == 400
    body = json.loads(response["body"])
    assert "name" in body["error"]


@mock_aws
def test_create_item_missing_category(dynamodb_table):
    event = make_event({"name": "Widget"})
    response = handler(event, None)

    assert response["statusCode"] == 400
    body = json.loads(response["body"])
    assert "category" in body["error"]


@mock_aws
def test_create_item_no_body(dynamodb_table):
    response = handler({"body": None}, None)

    assert response["statusCode"] == 400
    body = json.loads(response["body"])
    assert "body" in body["error"].lower()


@mock_aws
def test_create_item_invalid_json(dynamodb_table):
    event = make_event(raw="not-json{")
    response = handler(event, None)

    assert response["statusCode"] == 400
    body = json.loads(response["body"])
    assert "JSON" in body["error"]


@mock_aws
def test_create_item_description_too_long(dynamodb_table):
    event = make_event({"name": "Widget", "category": "test", "description": "x" * 1001})
    response = handler(event, None)

    assert response["statusCode"] == 400
    body = json.loads(response["body"])
    assert "description" in body["error"]


@mock_aws
def test_create_item_strips_whitespace(dynamodb_table):
    event = make_event({"name": "  Padded Name  ", "category": "  spaced  "})
    response = handler(event, None)

    assert response["statusCode"] == 201
    body = json.loads(response["body"])
    assert body["name"] == "Padded Name"
    assert body["category"] == "spaced"


@mock_aws
def test_create_item_without_description(dynamodb_table):
    event = make_event({"name": "Simple Item", "category": "tools"})
    response = handler(event, None)

    assert response["statusCode"] == 201
    body = json.loads(response["body"])
    assert body["description"] == ""
