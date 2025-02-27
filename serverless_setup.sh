# Set AWS Region
AWS_REGION="us-east-1"  # Change this if needed
DB_NAME="serverlessdb"
DB_USER="admin"
DB_PASS="YourSecurePassword123"
LAMBDA_ROLE_NAME="LambdaExecutionRole"
LAMBDA_FUNCTION_NAME="ServerlessLambda"
API_NAME="ServerlessAPI"

echo " Deploying Multi-Tier Serverless Architecture in $AWS_REGION..."

# 1.  Create an RDS Database Instance (MySQL)
echo " Creating RDS Database..."
aws rds create-db-instance \
    --db-instance-identifier $DB_NAME \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --allocated-storage 20 \
    --master-username $DB_USER \
    --master-user-password $DB_PASS \
    --backup-retention-period 7 \
    --region $AWS_REGION

# 2.  Create an IAM Role for Lambda Execution
echo " Creating IAM Role for Lambda..."
aws iam create-role \
    --role-name $LAMBDA_ROLE_NAME \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": { "Service": "lambda.amazonaws.com" },
            "Action": "sts:AssumeRole"
        }]
    }' \
    --region $AWS_REGION

# Attach permissions to the role
aws iam attach-role-policy \
    --role-name $LAMBDA_ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# 3. Create a Lambda Function
echo " Deploying Lambda Function..."
aws lambda create-function \
    --function-name $LAMBDA_FUNCTION_NAME \
    --runtime python3.9 \
    --role arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):role/$LAMBDA_ROLE_NAME \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://lambda_function.zip \
    --region $AWS_REGION

# 4. Create an API Gateway
echo " Creating API Gateway..."
API_ID=$(aws apigateway create-rest-api --name $API_NAME --query "id" --output text --region $AWS_REGION)

# Get the root resource ID
PARENT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[0].id" --output text --region $AWS_REGION)

# Create a resource under API Gateway
RESOURCE_ID=$(aws apigateway create-resource --rest-api-id $API_ID --parent-id $PARENT_ID --path-part "lambda" --query "id" --output text --region $AWS_REGION)

# Integrate API Gateway with Lambda
aws apigateway put-method --rest-api-id $API_ID --resource-id $RESOURCE_ID --http-method POST --authorization-type "NONE" --region $AWS_REGION
aws apigateway put-integration --rest-api-id $API_ID --resource-id $RESOURCE_ID --http-method POST --type AWS_PROXY --uri arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$AWS_REGION:$(aws sts get-caller-identity --query "Account" --output text):function:$LAMBDA_FUNCTION_NAME/invocations --region $AWS_REGION

# Deploy API Gateway
aws apigateway create-deployment --rest-api-id $API_ID --stage-name prod --region $AWS_REGION

echo " Deployment Complete!"
echo " API Gateway URL: https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/prod/lambda"
