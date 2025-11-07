# AWS Deployment Guide

## Overview

This guide covers deploying the US Law Severity Map to AWS with multiple architecture options, from low-cost static hosting to scalable container solutions.

---

## 🎯 Recommended: S3 + CloudFront (Static Website)

**Best for**: Low traffic, minimal cost, static content  
**Estimated Cost**: $0.50 - $1.00/month for 5-50 daily visits  
**Complexity**: Low

### Architecture

```
GitHub → GitHub Actions → S3 Bucket → CloudFront CDN → Users
```

### Features
- ✅ Automatic HTTPS via CloudFront
- ✅ Global CDN distribution
- ✅ CI/CD with GitHub Actions
- ✅ Version control and rollback
- ✅ 99.99% availability SLA

### Cost Breakdown (Monthly)
| Service | Usage | Cost |
|---------|-------|------|
| S3 Storage | ~10MB | $0.023 |
| S3 Requests | 1,500 GET | $0.006 |
| CloudFront | 50 requests/day | $0 (Free tier) |
| **Total** | | **~$0.03/month** |

*Note: Route53 domain adds ~$0.50/month if using custom domain*

### Prerequisites
- AWS Account
- AWS CLI configured
- GitHub account (for CI/CD)

### Deployment Steps

#### Option A: Manual Deployment

```bash
# 1. Create S3 bucket
aws s3 mb s3://us-law-severity-map --region us-east-1

# 2. Enable static website hosting
aws s3 website s3://us-law-severity-map \
  --index-document us_law_severity_map_interactive.html

# 3. Upload files
python main.py  # Generate latest HTML
aws s3 sync . s3://us-law-severity-map \
  --exclude ".git/*" \
  --exclude "*.py" \
  --exclude "venv/*" \
  --exclude "*.md"

# 4. Make bucket public (read-only)
aws s3api put-bucket-policy --bucket us-law-severity-map \
  --policy file://aws/s3-bucket-policy.json
```

#### Option B: Automated with GitHub Actions (Recommended)

See `.github/workflows/deploy-to-s3.yml` for full CI/CD setup.

---

## 🚀 Alternative: AWS Amplify Hosting

**Best for**: Easy deployment, built-in CI/CD  
**Estimated Cost**: $0/month (Free tier: 1000 build minutes, 15GB bandwidth)  
**Complexity**: Very Low

### Features
- ✅ Free tier very generous
- ✅ Automatic builds from GitHub
- ✅ Custom domain with free SSL
- ✅ Preview deployments for PRs
- ✅ No infrastructure management

### Deployment Steps

```bash
# Install Amplify CLI
npm install -g @aws-amplify/cli

# Configure Amplify
amplify init

# Add hosting
amplify add hosting

# Deploy
amplify publish
```

Or use AWS Console:
1. Go to AWS Amplify Console
2. Connect GitHub repository
3. Configure build settings (see `amplify.yml`)
4. Deploy automatically on push

---

## 📊 Scalability Path: Lambda + API Gateway

**Best for**: Dynamic content, server-side rendering  
**Estimated Cost**: $0.20 - $5.00/month  
**Complexity**: Medium

### When to Use
- Need to regenerate map on-demand
- Want to add user interactivity (save preferences, etc.)
- Need backend API for future features

### Architecture

```
User → CloudFront → API Gateway → Lambda → S3 (static assets)
                                    ↓
                               DynamoDB (optional)
```

### Cost Breakdown
| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 1,500 requests | $0 (Free tier) |
| API Gateway | 1,500 requests | $0.005 |
| DynamoDB | Read/Write | $0 (Free tier) |
| **Total** | | **~$0.01/month** |

### Infrastructure as Code

See `terraform/lambda-deployment/` for complete setup.

---

## 🐳 Advanced: EKS (Kubernetes)

**Best for**: High traffic, microservices, enterprise scale  
**Estimated Cost**: $72+ /month  
**Complexity**: High

### Cost Analysis
| Component | Cost |
|-----------|------|
| EKS Control Plane | $72/month |
| EC2 t3.medium nodes (2x) | $60/month |
| Load Balancer | $18/month |
| **Total** | **$150+/month** |

### Recommendation
❌ **Not recommended** for current traffic levels (5-50 visits/day)

✅ **Consider when**:
- Traffic exceeds 10,000+ requests/day
- Need auto-scaling and high availability
- Running multiple microservices
- Team has Kubernetes expertise

### Migration Path
If you need to scale to EKS later:
1. Containerize application (see `Dockerfile`)
2. Set up EKS cluster with Terraform
3. Deploy with Helm charts
4. Configure ingress and auto-scaling

Documentation: `docs/EKS_MIGRATION.md`

---

## 🛠️ Infrastructure as Code

### Terraform Modules Available

```bash
terraform/
├── s3-cloudfront/       # Static hosting (Recommended)
├── amplify/             # Amplify hosting
├── lambda-api/          # Serverless API
└── eks-cluster/         # Kubernetes (future)
```

### Deploy with Terraform

```bash
cd terraform/s3-cloudfront
terraform init
terraform plan
terraform apply
```

---

## 📈 Cost Comparison Summary

| Solution | Monthly Cost | Traffic Capacity | Complexity | Recommended For |
|----------|-------------|------------------|------------|-----------------|
| **S3 + CloudFront** | **$0.50** | Up to 100K/month | Low | ✅ **Current needs** |
| Amplify | $0 (Free tier) | 15GB bandwidth | Very Low | ✅ Quick start |
| Lambda + API | $1-5 | 1M requests | Medium | Future API needs |
| EKS | $150+ | Unlimited | High | Enterprise scale |

---

## 🔒 Security Best Practices

### S3 Bucket Security
- ✅ Enable bucket versioning
- ✅ Enable server access logging
- ✅ Use CloudFront with OAI (Origin Access Identity)
- ✅ Block public ACLs
- ✅ Enable encryption at rest

### CloudFront Security
- ✅ Enable HTTPS only
- ✅ Use custom SSL certificate (ACM)
- ✅ Enable AWS WAF for DDoS protection (optional)
- ✅ Configure security headers

### Example Security Headers

```json
{
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "X-XSS-Protection": "1; mode=block"
}
```

---

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

```yaml
# .github/workflows/deploy-to-s3.yml
name: Deploy to AWS S3
on:
  push:
    branches: [main]
    
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Generate map
        run: |
          python -m venv venv
          source venv/bin/activate
          pip install -r requirements.txt
          python main.py
      - name: Deploy to S3
        uses: jakejarvis/s3-sync-action@master
        env:
          AWS_S3_BUCKET: us-law-severity-map
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DIST_ID }} \
            --paths "/*"
```

---

## 🎯 Recommended Implementation Plan

### Phase 1: Initial Deployment (Week 1)
1. ✅ Set up S3 bucket with static website hosting
2. ✅ Configure CloudFront distribution
3. ✅ Deploy via GitHub Actions
4. ✅ Test with generated HTML file
5. ✅ Monitor costs and traffic

**Deliverable**: Live public website at CloudFront URL

### Phase 2: Custom Domain (Week 2)
1. Register domain or use existing
2. Configure Route53 hosted zone
3. Request ACM SSL certificate
4. Update CloudFront with custom domain
5. Configure DNS records

**Deliverable**: Custom domain with HTTPS

### Phase 3: Monitoring & Analytics (Week 3)
1. Enable CloudWatch metrics
2. Set up cost alerts
3. Configure CloudFront access logs
4. Add Google Analytics (optional)
5. Create monitoring dashboard

**Deliverable**: Full observability

### Phase 4: Optimization (Week 4)
1. Implement caching strategies
2. Optimize HTML size
3. Enable Brotli compression
4. Configure CloudFront cache behaviors
5. Document maintenance procedures

**Deliverable**: Optimized, production-ready site

---

## 📞 Support & Resources

### AWS Documentation
- [S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [CloudFront Getting Started](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/GettingStarted.html)
- [AWS Amplify Hosting](https://docs.amplify.aws/)

### Cost Calculators
- [AWS Pricing Calculator](https://calculator.aws/)
- [CloudFront Pricing](https://aws.amazon.com/cloudfront/pricing/)
- [S3 Pricing](https://aws.amazon.com/s3/pricing/)

### Useful Commands

```bash
# Check deployment cost
aws ce get-cost-and-usage --time-period Start=2025-10-01,End=2025-10-31

# Monitor CloudFront traffic
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront

# Check S3 bucket size
aws s3 ls s3://us-law-severity-map --recursive --human-readable --summarize
```

---

**Last Updated**: October 29, 2025  
**Version**: 2.0.0  
**Maintained by**: [Your Name]

