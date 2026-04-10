"""Shared pytest fixtures for Lambda handler tests."""
import os
import sys

import boto3
import pytest
from moto import mock_aws

# Add src to path so handlers can import utils
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

TABLE_NAME = "test-items-table"
AWS_REGION = "eu-west-1"


@pytest.fixture(autouse=True)
def aws_credentials(monkeypatch):
    """Prevent any real AWS calls during tests."""
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_SECURITY_TOKEN", "testing")
    monkeypatch.setenv("AWS_SESSION_TOKEN", "testing")
    monkeypatch.setenv("AWS_DEFAULT_REGION", AWS_REGION)
    monkeypatch.setenv("AWS_REGION", AWS_REGION)
    monkeypatch.setenv("DYNAMODB_TABLE", TABLE_NAME)


@pytest.fixture
def dynamodb_table(aws_credentials):
    with mock_aws():
        dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
        table = dynamodb.create_table(
            TableName=TABLE_NAME,
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[
                {"AttributeName": "id", "AttributeType": "S"},
                {"AttributeName": "category", "AttributeType": "S"},
            ],
            GlobalSecondaryIndexes=[
                {
                    "IndexName": "category-index",
                    "KeySchema": [{"AttributeName": "category", "KeyType": "HASH"}],
                    "Projection": {"ProjectionType": "ALL"},
                    "ProvisionedThroughput": {"ReadCapacityUnits": 1, "WriteCapacityUnits": 1},
                }
            ],
            BillingMode="PAY_PER_REQUEST",
        )
        table.meta.client.get_waiter("table_exists").wait(TableName=TABLE_NAME)
        yield table
