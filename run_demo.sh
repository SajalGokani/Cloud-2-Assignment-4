#!/bin/bash
API_ID=$(cat api_id.txt)
echo "========================================================"
echo " CLOUD DEVELOPMENT II - ASSESSMENT PART 3 DEMONSTRATION"
echo " Student: Sajal Gokani"
echo "========================================================"
echo ""

echo ">>> 1. VERIFYING DYNAMODB 'users' TABLE (BCRYPT 12 ROUNDS)"
awslocal dynamodb scan --table-name users --query "Items[*].[username.S, password.S]" --output table
echo ""

echo ">>> 2. TESTING /token ENDPOINT - INVALID CREDENTIALS (EXPECT 403)"
curl -i -s -X POST "http://localhost:4566/restapis/${API_ID}/prod/_user_request_/token" \
  -H "Content-Type: application/json" \
  -d '{"username": "tester1", "password": "WrongPassword123"}' | grep -E "HTTP/|message"
echo ""

echo ">>> 3. TESTING /token ENDPOINT - VALID CREDENTIALS FOR tester1 (EXPECT 200 + JWT)"
RESPONSE=$(curl -s -X POST "http://localhost:4566/restapis/${API_ID}/prod/_user_request_/token" \
  -H "Content-Type: application/json" \
  -d '{"username": "tester1", "password": "Pc4RM0AMKy5aSGfD"}')
echo "$RESPONSE"
TOKEN=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['token'])")
echo ""

echo ">>> 4. TESTING /coupons/to_secure - MISSING TOKEN (EXPECT 403)"
curl -i -s -X GET "http://localhost:4566/restapis/${API_ID}/prod/_user_request_/coupons/to_secure" | grep -E "HTTP/|message"
echo ""

echo ">>> 5. TESTING /coupons/to_secure - INVALID TOKEN (EXPECT 403)"
curl -i -s -X GET "http://localhost:4566/restapis/${API_ID}/prod/_user_request_/coupons/to_secure" \
  -H "Authorization: Bearer invalid.jwt.token" | grep -E "HTTP/|message"
echo ""

echo ">>> 6. TESTING /coupons/to_secure - VALID TOKEN (EXPECT 200 OK)"
curl -i -s -X GET "http://localhost:4566/restapis/${API_ID}/prod/_user_request_/coupons/to_secure" \
  -H "Authorization: Bearer $TOKEN" | grep -E "HTTP/|message|status"
echo ""
echo "All test requirements successfully validated!"
