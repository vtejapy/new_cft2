#!/bin/bash

# Deployment script for Contact Center CloudFormation infrastructure
# Usage: ./deploy.sh <environment> <region> [stack-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_message $RED "AWS CLI is not installed. Please install it first."
        exit 1
    fi
}

# Function to check if jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        print_message $RED "jq is not installed. Please install it first."
        exit 1
    fi
}

# Function to validate environment
validate_environment() {
    local env=$1
    if [[ ! "$env" =~ ^(dev|stg|prod)$ ]]; then
        print_message $RED "Invalid environment: $env. Must be dev, stg, or prod."
        exit 1
    fi
}

# Function to validate region
validate_region() {
    local region=$1
    if ! aws ec2 describe-regions --region-names $region &> /dev/null; then
        print_message $RED "Invalid AWS region: $region"
        exit 1
    fi
}

# Function to upload templates to S3
upload_templates() {
    local bucket=$1
    local environment=$2
    
    print_message $YELLOW "Uploading templates to S3 bucket: $bucket"
    
    # Create bucket if it doesn't exist
    if ! aws s3 ls "s3://$bucket" 2>&1 | grep -q 'NoSuchBucket'; then
        print_message $GREEN "Bucket $bucket already exists"
    else
        print_message $YELLOW "Creating bucket $bucket"
        aws s3 mb "s3://$bucket" --region $REGION
    fi
    
    # Upload templates
    aws s3 sync templates/ "s3://$bucket/templates/" --delete
    print_message $GREEN "Templates uploaded successfully"
}

# Function to upload Lambda code
upload_lambda_code() {
    local bucket=$1
    
    print_message $YELLOW "Uploading Lambda code to S3 bucket: $bucket"
    
    # Create bucket if it doesn't exist
    if ! aws s3 ls "s3://$bucket" 2>&1 | grep -q 'NoSuchBucket'; then
        print_message $GREEN "Bucket $bucket already exists"
    else
        print_message $YELLOW "Creating bucket $bucket"
        aws s3 mb "s3://$bucket" --region $REGION
    fi
    
    # Check if Lambda code exists
    if [ -d "lambda-code" ]; then
        aws s3 sync lambda-code/ "s3://$bucket/" --delete
        print_message $GREEN "Lambda code uploaded successfully"
    else
        print_message $YELLOW "Lambda code directory not found. Skipping upload."
    fi
}

# Function to validate CloudFormation template
validate_template() {
    local template_file=$1
    
    print_message $YELLOW "Validating CloudFormation template: $template_file"
    
    if aws cloudformation validate-template --template-body file://$template_file &> /dev/null; then
        print_message $GREEN "Template validation successful"
    else
        print_message $RED "Template validation failed"
        exit 1
    fi
}

# Function to deploy stack
deploy_stack() {
    local stack_name=$1
    local environment=$2
    local parameter_file="parameters/${environment}.json"
    
    print_message $YELLOW "Deploying stack: $stack_name"
    
    # Check if parameter file exists
    if [ ! -f "$parameter_file" ]; then
        print_message $RED "Parameter file not found: $parameter_file"
        exit 1
    fi
    
    # Read parameters from file
    local parameters=$(cat $parameter_file | jq -r '.Parameters | to_entries | map("ParameterKey=\(.key),ParameterValue=\(.value)") | join(" ")')
    
    # Add database password parameter
    read -s -p "Enter RDS master password: " DB_PASSWORD
    echo
    parameters="$parameters ParameterKey=DatabasePassword,ParameterValue=$DB_PASSWORD"
    
    # Deploy stack
    aws cloudformation deploy \
        --template-file main.yaml \
        --stack-name $stack_name \
        --parameter-overrides $parameters \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --region $REGION \
        --tags Environment=$environment Project="Contact Center" ManagedBy=CloudFormation
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "Stack deployment completed successfully"
    else
        print_message $RED "Stack deployment failed"
        exit 1
    fi
}

# Function to get stack outputs
get_stack_outputs() {
    local stack_name=$1
    
    print_message $YELLOW "Getting stack outputs..."
    
    aws cloudformation describe-stacks \
        --stack-name $stack_name \
        --region $REGION \
        --query 'Stacks[0].Outputs' \
        --output table
}

# Main script
main() {
    # Check prerequisites
    check_aws_cli
    check_jq
    
    # Parse arguments
    ENVIRONMENT=$1
    REGION=$2
    STACK_NAME=${3:-"contact-center-$ENVIRONMENT"}
    
    # Validate inputs
    if [ -z "$ENVIRONMENT" ] || [ -z "$REGION" ]; then
        print_message $RED "Usage: $0 <environment> <region> [stack-name]"
        print_message $RED "Example: $0 dev us-east-1 my-contact-center"
        exit 1
    fi
    
    validate_environment $ENVIRONMENT
    validate_region $REGION
    
    # Get bucket names from parameter file
    TEMPLATES_BUCKET=$(cat parameters/${ENVIRONMENT}.json | jq -r '.Parameters.TemplatesBucket')
    LAMBDA_CODE_BUCKET=$(cat parameters/${ENVIRONMENT}.json | jq -r '.Parameters.LambdaCodeBucket')
    
    print_message $GREEN "Starting deployment for environment: $ENVIRONMENT in region: $REGION"
    
    # Upload resources
    upload_templates $TEMPLATES_BUCKET $ENVIRONMENT
    upload_lambda_code $LAMBDA_CODE_BUCKET
    
    # Validate main template
    validate_template main.yaml
    
    # Deploy stack
    deploy_stack $STACK_NAME $ENVIRONMENT
    
    # Get outputs
    get_stack_outputs $STACK_NAME
    
    print_message $GREEN "Deployment completed successfully!"
}

# Run main function
main "$@"