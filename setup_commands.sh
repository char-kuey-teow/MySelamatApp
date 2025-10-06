#!/bin/bash

# Setup commands for S3 to DynamoDB import with separate tables

echo "🚀 Setting up S3 to DynamoDB import with separate tables..."

# 1. Create DynamoDB tables
echo "📊 Creating DynamoDB tables..."

# Create SOS table
aws dynamodb create-table \
  --table-name sos \
  --attribute-definitions \
    AttributeName=id,AttributeType=S \
    AttributeName=userId,AttributeType=S \
    AttributeName=timestamp,AttributeType=S \
    AttributeName=category,AttributeType=S \
    AttributeName=status,AttributeType=S \
    AttributeName=createdAt,AttributeType=S \
  --key-schema \
    AttributeName=id,KeyType=HASH \
  --global-secondary-indexes \
    IndexName=userId-timestamp-index,KeySchema='[{AttributeName=userId,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}]',Projection='{ProjectionType=ALL}' \
    IndexName=category-timestamp-index,KeySchema='[{AttributeName=category,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}]',Projection='{ProjectionType=ALL}' \
    IndexName=status-timestamp-index,KeySchema='[{AttributeName=status,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}]',Projection='{ProjectionType=ALL}' \
    IndexName=createdAt-index,KeySchema='[{AttributeName=createdAt,KeyType=HASH}]',Projection='{ProjectionType=ALL}' \
  --billing-mode PAY_PER_REQUEST \
  --time-to-live-specification AttributeName=ttl,Enabled=true

# Create Report table
aws dynamodb create-table \
  --table-name report \
  --attribute-definitions \
    AttributeName=id,AttributeType=S \
    AttributeName=userId,AttributeType=S \
    AttributeName=timestamp,AttributeType=S \
    AttributeName=disasterType,AttributeType=S \
    AttributeName=location,AttributeType=S \
    AttributeName=createdAt,AttributeType=S \
  --key-schema \
    AttributeName=id,KeyType=HASH \
  --global-secondary-indexes \
    IndexName=userId-timestamp-index,KeySchema='[{AttributeName=userId,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}]',Projection='{ProjectionType=ALL}' \
    IndexName=disasterType-timestamp-index,KeySchema='[{AttributeName=disasterType,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}]',Projection='{ProjectionType=ALL}' \
    IndexName=location-timestamp-index,KeySchema='[{AttributeName=location,KeyType=HASH},{AttributeName=timestamp,KeyType=RANGE}]',Projection='{ProjectionType=ALL}' \
    IndexName=createdAt-index,KeySchema='[{AttributeName=createdAt,KeyType=HASH}]',Projection='{ProjectionType=ALL}' \
  --billing-mode PAY_PER_REQUEST \
  --time-to-live-specification AttributeName=ttl,Enabled=true

echo "⏳ Waiting for tables to be created..."
aws dynamodb wait table-exists --table-name sos
aws dynamodb wait table-exists --table-name report

echo "✅ Tables created successfully!"

# 2. Create IAM role for Lambda
echo "🔐 Creating IAM role for Lambda..."

# Create trust policy
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name S3ToDynamoDBLambdaRole \
  --assume-role-policy-document file://trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name S3ToDynamoDBLambdaRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create custom policy for S3 and DynamoDB access
cat > lambda-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::selamat-app-reports/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-east-1:*:table/sos",
        "arn:aws:dynamodb:us-east-1:*:table/sos/index/*",
        "arn:aws:dynamodb:us-east-1:*:table/report",
        "arn:aws:dynamodb:us-east-1:*:table/report/index/*"
      ]
    }
  ]
}
EOF

# Create and attach custom policy
aws iam create-policy \
  --policy-name S3ToDynamoDBLambdaPolicy \
  --policy-document file://lambda-policy.json

aws iam attach-role-policy \
  --role-name S3ToDynamoDBLambdaRole \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/S3ToDynamoDBLambdaPolicy

echo "✅ IAM role created successfully!"

# 3. Create Lambda function
echo "🔧 Creating Lambda function..."

# Package the Lambda function
zip lambda_function.zip lambda_s3_to_dynamodb.py

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create Lambda function
aws lambda create-function \
  --function-name S3ToDynamoDBImporter \
  --runtime python3.9 \
  --role arn:aws:iam::${ACCOUNT_ID}:role/S3ToDynamoDBLambdaRole \
  --handler lambda_s3_to_dynamodb.lambda_handler \
  --zip-file fileb://lambda_function.zip \
  --timeout 60 \
  --memory-size 256

echo "✅ Lambda function created successfully!"

# 4. Create EventBridge rule for S3 events
echo "📡 Creating EventBridge rule..."

# Create EventBridge rule
aws events put-rule \
  --name S3ToDynamoDBImportRule \
  --description "Import S3 data to DynamoDB when uploaded" \
  --event-pattern '{
    "source": ["aws.s3"],
    "detail-type": ["Object Created"],
    "detail": {
      "bucket": {
        "name": ["selamat-app-reports"]
      },
      "object": {
        "key": [{
          "prefix": "sos/"
        }, {
          "prefix": "reports/"
        }]
      }
    }
  }' \
  --state ENABLED

# Add Lambda as target
aws events put-targets \
  --rule S3ToDynamoDBImportRule \
  --targets Id=1,Arn=arn:aws:lambda:us-east-1:${ACCOUNT_ID}:function:S3ToDynamoDBImporter

# Add permission for EventBridge to invoke Lambda
aws lambda add-permission \
  --function-name S3ToDynamoDBImporter \
  --statement-id allow-eventbridge \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:us-east-1:${ACCOUNT_ID}:rule/S3ToDynamoDBImportRule

echo "✅ EventBridge rule created successfully!"

# 5. Create batch import Lambda function
echo "📦 Creating batch import Lambda function..."

aws lambda create-function \
  --function-name S3ToDynamoDBBatchImporter \
  --runtime python3.9 \
  --role arn:aws:iam::${ACCOUNT_ID}:role/S3ToDynamoDBLambdaRole \
  --handler lambda_s3_to_dynamodb.batch_import_handler \
  --zip-file fileb://lambda_function.zip \
  --timeout 900 \
  --memory-size 512

echo "✅ Batch import Lambda function created successfully!"

# 6. Clean up temporary files
rm -f trust-policy.json lambda-policy.json lambda_function.zip

echo "🎉 Setup completed successfully!"
echo ""
echo "📋 Summary:"
echo "  ✅ DynamoDB tables: 'sos' and 'report'"
echo "  ✅ Lambda function: 'S3ToDynamoDBImporter' (auto-import)"
echo "  ✅ Lambda function: 'S3ToDynamoDBBatchImporter' (batch import)"
echo "  ✅ EventBridge rule: 'S3ToDynamoDBImportRule' (triggers on S3 uploads)"
echo "  ✅ IAM role: 'S3ToDynamoDBLambdaRole' (with proper permissions)"
echo ""
echo "🚀 Next steps:"
echo "  1. Upload files to S3 - they will be automatically imported to DynamoDB"
echo "  2. For existing data, trigger batch import:"
echo "     aws lambda invoke --function-name S3ToDynamoDBBatchImporter --payload '{\"bucket\":\"selamat-app-reports\",\"prefix\":\"sos/\"}' response.json"
echo "     aws lambda invoke --function-name S3ToDynamoDBBatchImporter --payload '{\"bucket\":\"selamat-app-reports\",\"prefix\":\"reports/\"}' response.json"


