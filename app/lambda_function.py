"""A minimal public endpoint proving that the Python deployment is live."""

def lambda_handler(event, context):
    return {
        "statusCode": 200,
        "headers": {"content-type": "text/plain; charset=utf-8"},
        "body": "Hello from Python on AWS Lambda!\n",
    }
