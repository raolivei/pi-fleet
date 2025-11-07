# Terraform: S3 + CloudFront Deployment

This Terraform configuration deploys the US Law Severity Map as a static website using S3 and CloudFront.

## Architecture

```
Users → CloudFront CDN → S3 Static Website
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account

## Quick Start

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply configuration
terraform apply
```

## Configuration

Edit `variables.tf` or create a `terraform.tfvars` file:

```hcl
bucket_name = "your-unique-bucket-name"
aws_region  = "us-east-1"
environment = "prod"
```

## Outputs

After successful deployment:

```bash
terraform output cloudfront_domain_name
# Returns: d111111abcdef8.cloudfront.net
```

Access your site at: `https://[cloudfront_domain_name]`

## Cost Estimate

- S3 Storage: ~$0.023/GB/month
- S3 Requests: ~$0.0004 per 1000 requests
- CloudFront: Free tier (1TB data transfer, 10M requests)

**Total for 50 visits/day**: ~$0.50/month

## Clean Up

```bash
terraform destroy
```

## Maintenance

### Update Website Content

```bash
# Generate new map
cd ../..
python main.py

# Upload to S3
aws s3 sync . s3://us-law-severity-map \
  --exclude ".git/*" --exclude "*.py" --exclude "venv/*"

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

