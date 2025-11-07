# AWS Cost Analysis - US Law Severity Map

## Expected Traffic: 5-50 visits/day (~1,500 visits/month)

---

## 💰 Recommended Solution: S3 + CloudFront

### Monthly Cost Breakdown

| Service                      | Usage                | Unit Cost      | Monthly Cost            |
| ---------------------------- | -------------------- | -------------- | ----------------------- |
| **S3 Storage**               | 10 MB                | $0.023/GB      | **$0.0002**             |
| **S3 PUT Requests**          | 30 (1/day)           | $0.005/1000    | **$0.0002**             |
| **S3 GET Requests**          | 1,500 (50/day)       | $0.0004/1000   | **$0.0006**             |
| **CloudFront Data Transfer** | 15 MB (1,500 × 10KB) | $0 (Free tier) | **$0**                  |
| **CloudFront Requests**      | 1,500                | $0 (Free tier) | **$0**                  |
| **Route53 Hosted Zone**      | 1 zone (optional)    | $0.50/zone     | **$0.50**               |
|                              |                      | **TOTAL**      | **$0.50 - $0.51/month** |

### Free Tier Benefits (First 12 Months)

- ✅ S3: 5GB storage, 20,000 GET, 2,000 PUT (FREE)
- ✅ CloudFront: 1TB data transfer, 10M requests (FREE)
- ✅ Route53: First hosted zone free with domain registration

**Your actual cost in first year: $0.00 - $0.50/month** (only domain if used)

---

## 📊 Detailed Service Costs

### 1. Amazon S3 (Simple Storage Service)

#### Pricing Structure

```
Storage:        $0.023 per GB/month
PUT requests:   $0.005 per 1,000 requests
GET requests:   $0.0004 per 1,000 requests
Data transfer:  $0.09 per GB (out to internet)
```

#### Your Usage (50 visits/day)

```
Storage:               10 MB = 0.01 GB
  Cost: 0.01 × $0.023 = $0.0002/month

Daily uploads:         1 deployment/day = 30/month
  Cost: (30/1000) × $0.005 = $0.0002/month

Daily downloads:       50 × 10KB = 500KB/day = 15MB/month
  Requests: 1,500 GET
  Cost: (1500/1000) × $0.0004 = $0.0006/month

Data transfer:         Via CloudFront (free), not direct
  Cost: $0

TOTAL S3: ~$0.001/month
```

✅ **Within Free Tier: Actual cost = $0**

---

### 2. Amazon CloudFront (CDN)

#### Pricing Structure

```
Data transfer out (per GB):
  - First 10 TB:       $0.085/GB (US/Europe)
  - Next 40 TB:        $0.080/GB
  - Next 100 TB:       $0.060/GB

HTTP/HTTPS Requests:   $0.0075 per 10,000 requests
```

#### Your Usage (50 visits/day)

```
Data transfer:         15 MB/month = 0.015 GB
  Cost: 0.015 × $0.085 = $0.001/month

HTTP requests:         1,500/month
  Cost: (1500/10000) × $0.0075 = $0.001/month

TOTAL CloudFront: $0.002/month
```

✅ **Within Free Tier (1TB, 10M requests): Actual cost = $0**

---

### 3. Amazon Route53 (DNS) - OPTIONAL

#### Pricing Structure

```
Hosted zone:           $0.50/month per zone
Standard queries:      $0.40 per million queries
```

#### Your Usage (if using custom domain)

```
Hosted zone:           1 zone × $0.50 = $0.50/month
DNS queries:           ~3,000/month (2 per visit)
  Cost: (3000/1000000) × $0.40 = $0.001/month

TOTAL Route53: $0.50/month
```

❌ **No free tier for hosted zones**

**Alternative**: Use CloudFront default domain (free)

- Example: `d111111abcdef8.cloudfront.net`
- No Route53 needed = $0

---

### 4. AWS Certificate Manager (ACM) - FREE

#### For Custom Domain HTTPS

```
SSL/TLS Certificate:   $0 (FREE with CloudFront)
Certificate renewals:  $0 (automatic)
```

✅ **Always FREE**

---

### 5. GitHub Actions - FREE

#### CI/CD Pipeline

```
GitHub Actions:        2,000 minutes/month (FREE for public repos)
Your usage:            ~5 minutes/deployment × 30 = 150 min/month
```

✅ **Within Free Tier: Actual cost = $0**

---

## 📈 Cost Scaling Examples

### Scenario 1: Current Traffic (50 visits/day)

```
Total: $0.00 - $0.50/month
  - Without custom domain: $0.00
  - With custom domain:    $0.50 (Route53 only)
```

### Scenario 2: Growth to 500 visits/day

```
S3 Storage:              $0.0002
S3 Requests:             $0.006
CloudFront Transfer:     $0.013 (150MB)
CloudFront Requests:     $0.011
Route53 (optional):      $0.50
───────────────────────────────
Total: $0.53/month (or $0.03 without domain)
```

### Scenario 3: Viral Success (5,000 visits/day)

```
S3 Storage:              $0.0002
S3 Requests:             $0.06
CloudFront Transfer:     $0.128 (1.5GB)
CloudFront Requests:     $0.113
Route53 (optional):      $0.50
───────────────────────────────
Total: $0.80/month (or $0.30 without domain)
```

### Scenario 4: Enterprise Scale (50,000 visits/day)

```
S3 Storage:              $0.0002
S3 Requests:             $0.60
CloudFront Transfer:     $1.28 (15GB)
CloudFront Requests:     $1.13
Route53 (optional):      $0.50
───────────────────────────────
Total: $3.51/month (or $3.01 without domain)
```

---

## 💡 Cost Optimization Tips

### 1. Use CloudFront Default Domain (Save $0.50/month)

```bash
# Instead of: https://your-domain.com
# Use:        https://d111111abcdef8.cloudfront.net
```

### 2. Enable Compression (Reduce bandwidth by 70%)

```terraform
# In CloudFront settings
compress = true
```

### 3. Set Proper Cache Headers (Reduce requests by 90%)

```html
<!-- In HTML file -->
<meta http-equiv="Cache-Control" content="public, max-age=3600" />
```

### 4. Use S3 Lifecycle Policies (Clean old versions)

```terraform
lifecycle_rule {
  enabled = true
  noncurrent_version_expiration {
    days = 30
  }
}
```

### 5. Monitor with AWS Budgets (FREE)

```bash
aws budgets create-budget \
  --account-id YOUR_ACCOUNT \
  --budget '{
    "BudgetLimit": {"Amount": "1", "Unit": "USD"},
    "TimeUnit": "MONTHLY"
  }'
```

---

## 🚫 What NOT to Use (Expensive Options)

### ❌ EC2 Instance

```
t3.micro:              $8.47/month (744 hours)
Elastic IP:            $3.60/month
Data transfer:         $0.09/GB
───────────────────────────────
Minimum:               $12/month
```

**25x more expensive than S3+CloudFront**

### ❌ Elastic Beanstalk

```
Application load:      $16.20/month
EC2 instance:          $8.47/month
───────────────────────────────
Minimum:               $24.67/month
```

**50x more expensive**

### ❌ EKS (Kubernetes)

```
EKS control plane:     $72/month
2× t3.medium nodes:    $60/month
Load balancer:         $16/month
───────────────────────────────
Minimum:               $148/month
```

**300x more expensive**

### ❌ AWS Lightsail

```
Cheapest instance:     $3.50/month
```

**7x more expensive** (and less scalable)

---

## 📊 12-Month Cost Projection

### Without Custom Domain

```
Month 1-12:     $0.00/month × 12 = $0.00
Annual Total:   $0.00 (all within free tier)
```

### With Custom Domain

```
Month 1-12:     $0.50/month × 12 = $6.00
Domain registration (one-time):    $12.00
Annual Total:   $18.00
```

### After Free Tier Expires (Year 2+)

```
Month 13-24:    $0.51/month × 12 = $6.12
Annual Total:   $6.12 (without domain) or $18.12 (with domain)
```

---

## 💳 Payment & Billing

### AWS Free Tier Eligibility

- ✅ New AWS accounts get 12 months free tier
- ✅ S3: 5GB storage, 20K GET, 2K PUT requests
- ✅ CloudFront: 1TB transfer, 10M requests
- ✅ Always free: ACM certificates

### Billing Alerts Setup

```bash
# Set alert for $1/month
aws cloudwatch put-metric-alarm \
  --alarm-name "us-law-severity-map-billing" \
  --alarm-description "Alert if monthly cost exceeds $1" \
  --metric-name EstimatedCharges \
  --threshold 1.0
```

### Cost Tracking

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost"
```

---

## 🎯 Final Recommendation

### For Your Traffic (5-50 visits/day):

**Use: S3 + CloudFront (no custom domain initially)**

✅ **Total Cost: $0.00/month**

Benefits:

- 100% within AWS free tier
- Scales automatically if traffic increases
- Zero maintenance
- High availability (99.99% SLA)
- Global CDN distribution

If you need custom domain later:

- Add Route53: +$0.50/month
- Still extremely affordable

---

## 📞 Support Resources

### Cost Management Tools (FREE)

- AWS Cost Explorer
- AWS Budgets
- AWS Cost Anomaly Detection
- CloudWatch billing alarms

### Useful Commands

```bash
# Current month costs by service
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE

# Forecast next month
aws ce get-cost-forecast \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --metric UNBLENDED_COST \
  --granularity MONTHLY
```

---

**Last Updated**: October 29, 2025  
**Pricing Region**: us-east-1 (N. Virginia)  
**Currency**: USD

_Note: AWS pricing varies by region. Prices shown are for us-east-1 and may change. Always check [AWS Pricing Calculator](https://calculator.aws/) for current rates._
