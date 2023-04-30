import boto3
from update_return import lambda_handler
from moto import mock_dynamodb


@mock_dynamodb
class TestLambda:

    def setup_method(self, method):
        self.table_name = 'visitor_test'
        self.partition_key = 'website'
        self.view_count = 'visitors'
        self.website_name = 'judekaney.com'

        dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
        self.table = dynamodb.create_table(
            TableName=self.table_name,
            KeySchema=[{'AttributeName': self.partition_key, 'KeyType': 'HASH'}],
            AttributeDefinitions=[{'AttributeName': self.partition_key, 'AttributeType': 'S'}],
            BillingMode='PAY_PER_REQUEST'
        )

        self.table = dynamodb.Table(self.table_name)
        self.table.put_item(
            TableName=self.table_name,
            Item={
                self.partition_key: self.website_name,
                self.view_count: 1,
            }
        )

    def test_unviewed(self):
        unviewed_test_event = {
            'headers': {
                'Visited': 'unviewed'
            }
        }

        response = lambda_handler(unviewed_test_event, None, table=self.table, partition_key=self.partition_key,
                                  website_name=self.website_name,
                                  view_count=self.view_count, table_name=self.table_name)
        assert response == {'statusCode': 200, 'total': '2'}
        self.table.delete()

    def test_viewed(self):
        viewed_test_event = {
            'headers': {
                'Visited': 'viewed'
            }
        }

        response = lambda_handler(viewed_test_event, None, table=self.table, partition_key=self.partition_key,
                                  website_name=self.website_name,
                                  view_count=self.view_count, table_name=self.table_name)
        assert response == {'statusCode': 200, 'total': '1'}
        self.table.delete()

    def test_no_visited_header(self):
        test_event = {
            'headers': {
            }
        }
        response = lambda_handler(test_event, None, table=self.table, partition_key=self.partition_key,
                                  website_name=self.website_name,
                                  view_count=self.view_count, table_name=self.table_name)
        assert response == {'statusCode': 400, 'body': 'Bad Request: "Visited" header is missing'}
        self.table.delete()

    def test_invalid_header(self):
        test_event = {
            'headers': {
                'Visited': 'bad'
            }
        }
        response = lambda_handler(test_event, None, table=self.table, partition_key=self.partition_key,
                                  website_name=self.website_name,
                                  view_count=self.view_count, table_name=self.table_name)
        assert response == {'statusCode': 400, 'body': 'Bad Request: "Visited" header has invalid value.'}
        self.table.delete()
