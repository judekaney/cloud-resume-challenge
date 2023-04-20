import boto3
import os

test = "testing"
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
table = dynamodb.Table(table_name)
partition_key = os.environ['PARTITION_KEY']
website_name = os.environ['WEBSITE_NAME']
view_count = os.environ['VIEW_COUNT']

def lambda_handler(event, context, table=table, partition_key=partition_key, website_name=website_name, view_count=view_count, table_name=table_name):
    headers = event['headers']

    # Verify that "Visited" header is present
    if 'Visited' not in headers:
        return {
            'statusCode': 400,
            'body': 'Bad Request: "Visited" header is missing'
        }

    # Get the "Visited" header value and convert to lowercase
    visited = headers.get('Visited', '').lower()

    # Verify the contents of "Visited" header are valid
    if visited != 'unviewed' and visited != 'viewed':
        return {
            'statusCode': 400,
            'body': 'Bad Request: "Visited" header has invalid value.'
        }

    if visited == 'unviewed':
        # Update the visitor count
        table.update_item(
            TableName=table_name,
            Key={partition_key: website_name},
            UpdateExpression=f'SET {view_count} = {view_count} + :incr',
            ExpressionAttributeValues={':incr': 1},
        )

    # Retrieve the count
    response = table.get_item(
        Key={partition_key: website_name}
    )

    count = response['Item'][view_count]

    return {
        'statusCode': 200,
        'total': str(count),
    }
