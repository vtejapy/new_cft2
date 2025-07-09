# CloudFormation Project Structure

## Directory Structure
```
cloudformation/
├── main.yaml                    # Master template orchestrating nested stacks
├── templates/
│   ├── vpc.yaml                # VPC and networking resources
│   ├── s3.yaml                 # S3 buckets and lifecycle policies
│   ├── iam.yaml                # IAM roles and policies
│   ├── lambda.yaml             # Lambda functions and layers
│   ├── kinesis.yaml            # Kinesis streams and Firehose
│   ├── eventbridge.yaml        # EventBridge rules
│   ├── endpoints.yaml          # VPC endpoints
│   ├── dynamodb.yaml           # DynamoDB tables
│   ├── api-gateway.yaml        # API Gateway resources
│   ├── connect.yaml            # Amazon Connect instance
│   ├── rds.yaml                # RDS database resources
│   ├── security-groups.yaml    # Security groups
│   └── cloudwatch.yaml         # CloudWatch dashboards and alarms
├── parameters/
│   ├── dev.json                # Development environment parameters
│   ├── stg.json                # Staging environment parameters
│   └── prod.json               # Production environment parameters
└── scripts/
    ├── deploy.sh               # Deployment script
    └── validate.sh             # Template validation script
```

## Template Dependencies
1. **Parameters & Outputs**: Each template exports key values for cross-stack references
2. **Dependency Order**:
   - VPC → Security Groups → RDS, Lambda, Endpoints
   - IAM → Lambda, API Gateway
   - S3 → Lambda
   - All resources → API Gateway (final integration)

## Deployment Strategy
1. Deploy infrastructure stacks first (VPC, IAM, S3)
2. Deploy compute resources (Lambda, RDS, Kinesis)
3. Deploy integration resources (API Gateway, EventBridge)
4. Use CloudFormation StackSets for multi-region deployment
