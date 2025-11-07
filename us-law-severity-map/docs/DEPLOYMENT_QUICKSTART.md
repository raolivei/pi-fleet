# 🚀 Quick Start: Deploy to AWS in 10 Minutes

This guide gets your map live on AWS with minimal effort.

## Prerequisites

- AWS Account ([Sign up for free](https://aws.amazon.com/free/))
- AWS CLI installed and configured
- Python 3.8+ installed

## Step-by-Step Deployment

### Option 1: Manual S3 Deployment (Easiest - 5 minutes)

```bash
# 1. Generate the map
python main.py

# 2. Create S3 bucket (use unique name)
aws s3 mb s3://us-law-severity-map-[YOUR-NAME] --region us-east-1

# 3. Enable static website hosting
aws s3 website s3://us-law-severity-map-[YOUR-NAME] \
  --index-document us_law_severity_map_interactive.html

# 4. Upload the HTML file
aws s3 cp us_law_severity_map_interactive.html \
  s3://us-law-severity-map-[YOUR-NAME]/

# 5. Upload other files
aws s3 cp README.md s3://us-law-severity-map-[YOUR-NAME]/
aws s3 cp LICENSE s3://us-law-severity-map-[YOUR-NAME]/

# 6. Make it public
aws s3api put-bucket-policy \
  --bucket us-law-severity-map-[YOUR-NAME] \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::us-law-severity-map-[YOUR-NAME]/*"
    }]
  }'

# 7. Get your website URL
echo "Your website is live at:"
echo "http://us-law-severity-map-[YOUR-NAME].s3-website-us-east-1.amazonaws.com"
```

**Cost**: ~$0.03/month

---

### Option 2: Terraform Deployment (Recommended - 10 minutes)

```bash
# 1. Install Terraform (if not installed)
# macOS: brew install terraform
# Linux: snap install terraform
# Windows: choco install terraform

# 2. Navigate to Terraform directory
cd terraform/s3-cloudfront

# 3. Initialize Terraform
terraform init

# 4. Create terraform.tfvars
cat > terraform.tfvars <<EOF
bucket_name = "us-law-severity-map-[YOUR-NAME]"
aws_region  = "us-east-1"
environment = "prod"
EOF

# 5. Deploy infrastructure
terraform apply

# 6. Generate and upload map
cd ../..
python main.py
aws s3 sync . s3://us-law-severity-map-[YOUR-NAME] \
  --exclude ".git/*" --exclude "*.py" --exclude "venv/*" --exclude ".github/*"

# 7. Get CloudFront URL
cd terraform/s3-cloudfront
terraform output cloudfront_domain_name
```

**Cost**: ~$0.50/month (includes CloudFront CDN)

---

### Option 3: AWS Amplify (Zero Configuration - 2 minutes)

```bash
# 1. Push code to GitHub (already done!)

# 2. Go to AWS Amplify Console
open https://console.aws.amazon.com/amplify/

# 3. Click "New app" → "Host web app"

# 4. Connect GitHub repository: raolivei/us-law-severity-map

# 5. Configure build settings:
#    - Build command: python main.py
#    - Output directory: .
#    - Base directory: /

# 6. Deploy!
```

Amplify will:

- ✅ Build your map automatically
- ✅ Provide HTTPS URL
- ✅ Auto-deploy on git push
- ✅ Give you preview URLs for PRs

**Cost**: $0 (Free tier: 1000 build minutes, 15GB bandwidth)

---

## Verify Deployment

Test your deployed map:

```bash
# Option 1: S3 Website
curl -I http://[YOUR-BUCKET].s3-website-us-east-1.amazonaws.com

# Option 2: CloudFront
curl -I https://[YOUR-CLOUDFRONT-DOMAIN].cloudfront.net

# Option 3: Amplify
curl -I https://[YOUR-APP-ID].amplifyapp.com
```

You should see:

```
HTTP/1.1 200 OK
Content-Type: text/html
```

---

## Custom Domain (Optional)

### Using Route53

```bash
# 1. Register domain in Route53
aws route53domains register-domain \
  --domain-name your-domain.com \
  --duration-in-years 1

# 2. Create hosted zone
aws route53 create-hosted-zone \
  --name your-domain.com \
  --caller-reference $(date +%s)

# 3. Point to CloudFront
# (Use CloudFront domain from terraform output)
```

### Using External DNS (Namecheap, GoDaddy, etc.)

1. Get CloudFront domain: `terraform output cloudfront_domain_name`
2. Add CNAME record in your DNS provider:
   ```
   Type: CNAME
   Name: www
   Value: [YOUR-CLOUDFRONT-DOMAIN].cloudfront.net
   ```

---

## Monitoring & Costs

### Check Current Costs

```bash
# View AWS costs for this month
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --filter file://cost-filter.json
```

### Set Up Cost Alerts

```bash
# Create budget alert
aws budgets create-budget \
  --account-id [YOUR-ACCOUNT-ID] \
  --budget '{
    "BudgetName": "us-law-severity-map-budget",
    "BudgetLimit": {
      "Amount": "5",
      "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }'
```

---

## Update Your Map

After making code changes:

```bash
# 1. Regenerate map
python main.py

# 2. Upload to S3
aws s3 cp us_law_severity_map_interactive.html \
  s3://us-law-severity-map-[YOUR-NAME]/

# 3. Invalidate CloudFront cache (if using)
aws cloudfront create-invalidation \
  --distribution-id [YOUR-DIST-ID] \
  --paths "/*"
```

Or let GitHub Actions do it automatically! (see `.github/workflows/deploy-to-s3.yml`)

---

## Troubleshooting

### Issue: 403 Forbidden

```bash
# Fix: Update bucket policy
aws s3api put-bucket-policy \
  --bucket us-law-severity-map-[YOUR-NAME] \
  --policy file://aws/s3-bucket-policy.json
```

### Issue: Old content still showing

```bash
# Clear CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id [YOUR-DIST-ID] \
  --paths "/*"
```

### Issue: High costs

```bash
# Check what's costing money
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-31 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE
```

---

## Clean Up

To remove everything and stop incurring charges:

```bash
# Option 1: Manual
aws s3 rb s3://us-law-severity-map-[YOUR-NAME] --force

# Option 2: Terraform
cd terraform/s3-cloudfront
terraform destroy

# Option 3: Amplify
aws amplify delete-app --app-id [YOUR-APP-ID]
```

---

## Next Steps

- ✅ Set up automatic deployments with GitHub Actions
- ✅ Add custom domain
- ✅ Enable CloudWatch monitoring
- ✅ Set up cost alerts
- ✅ Add Google Analytics

See `docs/AWS_DEPLOYMENT.md` for advanced configurations.

---

**Need Help?** Open an issue on GitHub or consult [AWS Support](https://aws.amazon.com/support/)
