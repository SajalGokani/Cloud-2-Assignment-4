#!/bin/bash
set -e

BUCKET_NAME="coupons"

cat << 'POLICY' > bucket_policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyDeleteWithoutMFA",
      "Effect": "Deny",
      "Principal": "*",
      "Action": [
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
        "s3:DeleteBucket"
      ],
      "Resource": [
        "arn:aws:s3:::coupons",
        "arn:aws:s3:::coupons/*"
      ],
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
POLICY

awslocal s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy file://bucket_policy.json
awslocal s3api get-bucket-policy --bucket "$BUCKET_NAME" --query Policy --output text | python3 -m json.tool
