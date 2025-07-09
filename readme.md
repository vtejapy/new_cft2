# Contact Center CloudFormation Infrastructure

This repository contains AWS CloudFormation templates for deploying a comprehensive Contact Center infrastructure including Amazon Connect, Lambda functions, API Gateway, RDS, DynamoDB, and supporting AWS services.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Deployment Guide](#deployment-guide)
- [Configuration](#configuration)
- [Resource Details](#resource-details)
- [Monitoring and Alarms](#monitoring-and-alarms)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Architecture Overview

The Contact Center infrastructure includes:
- **Amazon Connect** - Cloud-based contact center service
- **VPC & Networking** - Isolated network with public/private subnets
- **RDS PostgreSQL** - Database for storing contact center data
- **Lambda Functions** - Serverless compute for various integrations
- **API Gateway** - REST APIs for internal and external integrations
- **Kinesis Streams** - Real-time data streaming for CTR and agent events
- **S3 Buckets** - Storage for recordings, transcripts, and reports
- **CloudWatch** - Monitoring, logging, and alerting

## Prerequisites

### Required Tools
- AWS CLI v2.x or higher
- Python 3.8+ (for cfn-lint)
- jq (for JSON processing)
- Git
- Bash or compatible shell

### AWS Account Requirements
- Administrator access or appropriate IAM permissions
- Service limits checked for:
  - VPC and subnets
  - Lambda concurrent executions
  - RDS instances
  - Kinesis shards
  - API Gateway APIs

### Installation
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install cfn-lint
pip install cfn-lint

# Install jq
# On macOS
brew install jq
# On Ubuntu/Debian
sudo apt-get install jq
```

## Project Structure

```
cloudformation/
├── main.yaml                    # Master template orchestrating nested stacks
├── templates/                   # Nested stack templates
│   ├── vpc.yaml                # VPC and networking
│   ├── s3.yaml                 # S3 buckets
│   ├── iam.yaml                # IAM roles and policies
│   ├── lambda.yaml             # Lambda functions and layers
│   ├── kinesis.yaml            # Kinesis streams
│   ├── eventbridge.yaml        # EventBridge rules
│   ├── endpoints.yaml          # VPC endpoints
│   ├── dynamodb.yaml           # DynamoDB tables
│   ├── api-gateway.yaml        # API Gateway configuration
│   ├── connect.yaml            # Amazon Connect instance
│   ├── rds.yaml                # RDS PostgreSQL
│   ├── security-groups.yaml    # Security groups
│   └── cloudwatch.yaml         # CloudWatch dashboards and alarms
├── parameters/                  # Environment-specific parameters
│   ├── dev.json                # Development parameters
│   ├── stg.json                # Staging parameters
│   └── prod.json               # Production parameters
├── scripts/                     # Deployment and utility scripts
│   ├── deploy.sh               # Main deployment script
│   ├── validate.sh             # Template validation script
│   └── cleanup.sh              # Stack cleanup script
├── lambda-code/                # Lambda function source code
│   ├── functions/              # Function packages
│   └── layers/                 # Lambda layers
└── README.md                   # This file
```

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd cloudformation
   ```

2. **Configure AWS credentials**
   ```bash
   aws configure
   ```

3. **Validate templates**
   ```bash
   ./scripts/validate.sh
   ```

4. **Deploy to development environment**
   ```bash
   ./scripts/deploy.sh dev us-east-1
   ```

## Deployment Guide

### Step 1: Prepare S3 Buckets

The deployment script automatically creates S3 buckets for templates and Lambda code. Ensure the bucket names in your parameter files are unique.

### Step 2: Upload Lambda Code

Place your Lambda function code in the `lambda-code/` directory:
- `lambda-code/functions/` - ZIP files for each Lambda function
- `lambda-code/layers/` - ZIP files for Lambda layers

### Step 3: Configure Parameters

Edit the parameter files in `parameters/` directory for your environment:
- `dev.json` - Development environment
- `stg.json` - Staging environment  
- `prod.json` - Production environment

Key parameters to configure:
- `VpcCidr` - CIDR block for VPC
- `Client` - Client identifier
- `DatabasePassword` - Will be prompted during deployment
- `TemplatesBucket` - S3 bucket for CloudFormation templates
- `LambdaCodeBucket` - S3 bucket for Lambda code

### Step 4: Deploy the Stack

```bash
# Deploy to development
./scripts/deploy.sh dev us-east-1

# Deploy to staging  
./scripts/deploy.sh stg us-east-1

# Deploy to production with custom stack name
./scripts/deploy.sh prod us-east-1 prod-contact-center
```

### Step 5: Verify Deployment

After deployment, the script will display stack outputs including:
- VPC ID and subnet IDs
- API Gateway URLs
- Amazon Connect instance ID
- RDS endpoint
- S3 bucket names

## Configuration

### Environment Variables

Each Lambda function uses environment variables configured in the `lambda.yaml` template:
- `DATABASE_ENDPOINT` - RDS endpoint
- `DATABASE_PORT` - Database port (5432)
- `SCHEME_NAME` - Database schema name
- `SECRET_MANAGER_NAME` - Secrets Manager secret for RDS
- `INSTANCE_ID` - Amazon Connect instance ID
- `S3_BUCKET` - Relevant S3 bucket name

### Security Groups

Security groups are configured to follow the principle of least privilege:
- Lambda functions can only access required services
- RDS is only accessible from Lambda security groups
- VPC endpoints restrict access to AWS services

### VPC Endpoints

The following VPC endpoints are created for secure access:
- S3
- DynamoDB
- API Gateway
- Secrets Manager
- Lambda
- Comprehend
- Transcribe
- Lex V2

## Resource Details

### Lambda Functions

| Function | Purpose | Runtime | Timeout |
|----------|---------|---------|---------|
| command-center-lambda | Command center API operations | Python 3.10 | 30s |
| contact-center-core-api-lambda | Core API functionality | Python 3.10 | 30s |
| kvs-processor-lambda | Process Kinesis Video Streams | Node.js 20.x | 180s |
| contactlens-evaluation-loader | Load Contact Lens evaluations | Python 3.10 | 900s |
| ctr-processor-lambda | Process Contact Trace Records | Node.js 18.x | 600s |
| queue-experience-utility | Queue management utilities | Python 3.10 | 300s |

### API Gateway Endpoints

**Connect Core API** (`/api/`):
- `/calllog/getcalllogs` - Retrieve call logs
- `/ctr/putctr` - Store CTR data
- `/fraudnumber/get_number_by_id/{number}` - Check fraud numbers
- `/postcallsurvey/*` - Post-call survey operations
- `/insurance-core/*` - Insurance-specific endpoints

**Command Center API** (`/api/{proxy+}`):
- Proxy all requests to Lambda function

### S3 Buckets

| Bucket | Purpose | Lifecycle Policy |
|--------|---------|------------------|
| rec-trans-* | Call recordings & transcripts | 2555 days, Glacier after 365 days |
| exp-reports-* | Exported reports | 180 days |
| screen-rec-* | Screen recordings | 60 days |
| voicemail-* | Voicemail storage | 30 days |
| command-center-* | Command center assets | No expiration |
| lex-bot-grammar-* | Lex bot configurations | 180 days |

### RDS Configuration

- **Engine**: PostgreSQL 16.3
- **Instance Class**: db.t3.medium (dev), db.r6g.xlarge (prod)
- **Multi-AZ**: Enabled in staging and production
- **Backup**: 7-30 days retention
- **Encryption**: Enabled
- **Monitoring**: Enhanced monitoring enabled

### Kinesis Streams

| Stream | Purpose | Shards | Retention |
|--------|---------|--------|-----------|
| queue-exp-kinesis-stream | Queue experience events | 2 | 48 hours |
| CTR-kinesis-streams | Contact trace records | 1-4 | 24-168 hours |
| agent-event-kinesis-streams | Agent events | 1-4 | 24-168 hours |

## Monitoring and Alarms

### CloudWatch Alarms

The following alarms are configured:
- **Longest Queue Wait Time** - Alerts when wait time exceeds threshold
- **Calls Per Interval** - Alerts on low call volume
- **API Gateway Latency** - Monitors API response times
- **API Gateway 5XX Errors** - Tracks server errors
- **Packet Loss Rate** - Monitors call quality
- **Contact Flow Errors** - Tracks IVR issues

### CloudWatch Dashboard

A custom dashboard `Amazon-Connect-Metrics-{Client}-{Environment}` displays:
- Call metrics
- Queue statistics  
- API Gateway performance
- Error rates

## Cleanup

To remove all resources:

```bash
./scripts/cleanup.sh <environment> <region> [stack-name]
```

**Warning**: This will delete all resources including:
- RDS database and backups
- S3 buckets and their contents
- Lambda functions and layers
- Amazon Connect instance

## Troubleshooting

### Common Issues

1. **Stack creation fails with "Resource already exists"**
   - Check if resources with same names exist
   - Use unique names in parameters

2. **Lambda function fails with timeout**
   - Increase timeout in template
   - Check VPC endpoint configuration
   - Verify security group rules

3. **API Gateway returns 5XX errors**
   - Check Lambda function logs
   - Verify IAM permissions
   - Test Lambda function independently

4. **RDS connection issues**
   - Verify security group rules
   - Check subnet configuration
   - Validate secrets in Secrets Manager

### Debug Commands

```bash
# Check stack events
aws cloudformation describe-stack-events --stack-name <stack-name>

# View Lambda logs
aws logs tail /aws/lambda/<function-name> --follow

# Test API endpoint
curl -X POST https://<api-id>.execute-api.<region>.amazonaws.com/<stage>/api/endpoint

# Check RDS status
aws rds describe-db-instances --db-instance-identifier <instance-id>
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Use meaningful resource names
- Add descriptions to all resources
- Tag all resources appropriately
- Validate templates before committing
- Update documentation for new features

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Create an issue in the repository
- Contact the Cloud Infrastructure team
- Check AWS documentation for service-specific questions