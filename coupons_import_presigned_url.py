import json
import os
import boto3
from botocore.config import Config

# Internal endpoint used inside LocalStack Lambda container vs external URL for client
if 'LOCALSTACK_HOSTNAME' in os.environ:
    internal_endpoint = f"http://{os.environ['LOCALSTACK_HOSTNAME']}:4566"
elif 'AWS_ENDPOINT_URL' in os.environ:
    internal_endpoint = os.environ['AWS_ENDPOINT_URL']
else:
    internal_endpoint = "http://localhost:4566"

s3_client = boto3.client(
    's3',
    endpoint_url=internal_endpoint,
    region_name='us-east-1',
    config=Config(signature_version='s3v4')
)
BUCKET_NAME = "coupons"

def handler(event, context):
    try:
        body = event.get('body', event)
        if isinstance(body, str):
            body = json.loads(body) if body else {}
        elif body is None:
            body = {}

        # Default to coupon.json if filename is not explicitly passed, otherwise enforce requested filename
        filename = body.get('filename', 'coupon.json')
        if not filename:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"status": "error", "message": "Missing filename"})
            }

        # Generate pre-signed URL for PUT upload restricted to the specific filename
        presigned_url = s3_client.generate_presigned_url(
            ClientMethod='put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': filename
            },
            ExpiresIn=3600
        )

        # Ensure the returned URL uses localhost:4566 so the external client can reach it directly
        if 'LOCALSTACK_HOSTNAME' in os.environ:
            presigned_url = presigned_url.replace(
                f"http://{os.environ['LOCALSTACK_HOSTNAME']}:4566",
                "http://localhost:4566"
            )

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "status": "success",
                "filename": filename,
                "presigned_url": presigned_url
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"status": "error", "message": str(e)})
        }
