import json
import os
import boto3

if 'LOCALSTACK_HOSTNAME' in os.environ:
    endpoint_url = f"http://{os.environ['LOCALSTACK_HOSTNAME']}:4566"
elif 'AWS_ENDPOINT_URL' in os.environ:
    endpoint_url = os.environ['AWS_ENDPOINT_URL']
else:
    endpoint_url = "http://localhost:4566"

s3_client = boto3.client(
    's3',
    endpoint_url=endpoint_url,
    region_name='us-east-1'
)
BUCKET_NAME = "coupons"

def handler(event, context):
    try:
        body = event.get('body', event)
        if isinstance(body, str):
            body = json.loads(body)

        coupon_id = body.get('coupon_id')
        if not coupon_id:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"status": "error", "message": "Missing coupon_id"})
            }

        file_name = f"{coupon_id}.json"

        s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=file_name,
            Body=json.dumps(body, indent=2),
            ContentType="application/json"
        )

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "status": "success",
                "file": file_name,
                "bucket": BUCKET_NAME
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"status": "error", "message": str(e)})
        }
