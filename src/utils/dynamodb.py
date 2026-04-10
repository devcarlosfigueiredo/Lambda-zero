"""DynamoDB client helper."""
import os
import boto3
from boto3.dynamodb.conditions import Key


def get_table():
    dynamodb = boto3.resource("dynamodb", region_name=os.environ.get("AWS_REGION", "eu-west-1"))
    table_name = os.environ["DYNAMODB_TABLE"]
    return dynamodb.Table(table_name)


def put_item(table, item: dict) -> dict:
    table.put_item(Item=item)
    return item


def get_item_by_id(table, item_id: str) -> dict | None:
    response = table.get_item(Key={"id": item_id})
    return response.get("Item")


def delete_item_by_id(table, item_id: str) -> bool:
    response = table.delete_item(
        Key={"id": item_id},
        ReturnValues="ALL_OLD",
    )
    return bool(response.get("Attributes"))


def scan_all_items(table) -> list:
    response = table.scan()
    items = response.get("Items", [])
    # Handle pagination
    while "LastEvaluatedKey" in response:
        response = table.scan(ExclusiveStartKey=response["LastEvaluatedKey"])
        items.extend(response.get("Items", []))
    return items


def query_by_category(table, category: str) -> list:
    response = table.query(
        IndexName="category-index",
        KeyConditionExpression=Key("category").eq(category),
    )
    return response.get("Items", [])
