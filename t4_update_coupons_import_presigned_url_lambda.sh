#!/bin/bash
set -e

REGION="us-east-1"
ACCOUNT_ID="000000000000"
API_NAME="coupons"
LAMBDA_NAME="coupons_import_presigned_url"
ROLE_ARN="arn:aws:iam::000000000000:role/coupons_lambda_role"

echo "======================================================================"
echo "PROVISIONING /coupons/import_presigned_url & coupons_import_presigned_url"
echo "======================================================================"

# 1. Package Lambda code
echo "1. Packaging Lambda code..."
rm -f coupons_import_presigned_url.zip
zip -q coupons_import_presigned_url.zip coupons_import_presigned_url.py

# 2. Create or update Lambda function
echo "2. Deploying Lambda function: $LAMBDA_NAME..."
if awslocal lambda get-function --function-name "$LAMBDA_NAME" >/dev/null 2>&1; then
  echo "Updating existing function code..."
  awslocal lambda update-function-code \
    --function-name "$LAMBDA_NAME" \
    --zip-file fileb://coupons_import_presigned_url.zip >/dev/null
else
  echo "Creating new function..."
  awslocal lambda create-function \
    --function-name "$LAMBDA_NAME" \
    --runtime python3.11 \
    --role "$ROLE_ARN" \
    --handler coupons_import_presigned_url.handler \
    --zip-file fileb://coupons_import_presigned_url.zip >/dev/null
fi

# 3. Retrieve API Gateway ID
if [ -f api_id.txt ]; then
  API_ID=$(cat api_id.txt)
else
  API_ID=$(awslocal apigateway get-rest-apis --query "items[?name=='$API_NAME'].id" --output text)
fi
echo "Using API ID: $API_ID"

PARENT_ROOT_ID=$(awslocal apigateway get-resources --rest-api-id "$API_ID" --query 'items[?path==`/`].id' --output text)

# 4. Check or create /coupons resource
COUPONS_RES_ID=$(awslocal apigateway get-resources --rest-api-id "$API_ID" --query "items[?path=='/coupons'].id" --output text)
if [ -z "$COUPONS_RES_ID" ] || [ "$COUPONS_RES_ID" == "None" ]; then
  echo "Creating resource /coupons..."
  COUPONS_RES_ID=$(awslocal apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$PARENT_ROOT_ID" \
    --path-part "coupons" \
    --query 'id' --output text)
fi

# 5. Check or create /coupons/import_presigned_url resource
PRESIGNED_RES_ID=$(awslocal apigateway get-resources --rest-api-id "$API_ID" --query "items[?path=='/coupons/import_presigned_url'].id" --output text)
if [ -z "$PRESIGNED_RES_ID" ] || [ "$PRESIGNED_RES_ID" == "None" ]; then
  echo "Creating resource /coupons/import_presigned_url..."
  PRESIGNED_RES_ID=$(awslocal apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$COUPONS_RES_ID" \
    --path-part "import_presigned_url" \
    --query 'id' --output text)
fi
echo "Resource ID for /coupons/import_presigned_url: $PRESIGNED_RES_ID"

LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${LAMBDA_NAME}"
INTEGRATION_URI="arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"

# 6. Create POST and GET methods and integrate with Lambda
for METHOD in POST GET; do
  awslocal apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$PRESIGNED_RES_ID" \
    --http-method "$METHOD" \
    --authorization-type "NONE" >/dev/null 2>&1 || true

  awslocal apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$PRESIGNED_RES_ID" \
    --http-method "$METHOD" \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "$INTEGRATION_URI" >/dev/null
done

# 7. Grant API Gateway permission to invoke Lambda
awslocal lambda add-permission \
  --function-name "$LAMBDA_NAME" \
  --statement-id "apigateway-presigned-$(date +%s)" \
  --action "lambda:InvokeFunction" \
  --principal "apigateway.amazonaws.com" \
  --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*/*" >/dev/null 2>&1 || true

# 8. Deploy to prod stage
echo "Deploying to prod stage..."
awslocal apigateway create-deployment --rest-api-id "$API_ID" --stage-name prod >/dev/null

echo "Endpoint ready: http://localhost:4566/restapis/${API_ID}/prod/_user_request_/coupons/import_presigned_url"
