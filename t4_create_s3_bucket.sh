#!/bin/bash
set -e

BUCKET_NAME="coupons"
REGION="us-east-1"

echo "Creating S3 bucket '$BUCKET_NAME' with private ACL..."
awslocal s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --acl private \
  --region "$REGION"

echo "Verifying S3 bucket list and ACL:"
awslocal s3 ls
awslocal s3api get-bucket-acl --bucket "$BUCKET_NAME"
