# GitHub Actions Workflows

## 🎯 Terraform Workflows (Recommended)

### Option A: Manual Apply (SAFEST) ⭐ **RECOMMENDED**

Perfect for production! You have full control.

**Workflows:**

- `terraform-pr-plan.yml` - Automatic plan on PR
- `terraform-pr-apply.yml` - Manual apply (you trigger it)

**How it works:**

1. Create PR → Plan runs automatically
2. Review plan in PR comment
3. Go to Actions → "Terraform Apply (Manual)" → Run workflow
4. Enter PR number → Apply runs
5. If success → Merge PR
6. If failure → Fix and retry

**Benefits:**

- ✅ Zero risk - you control when apply runs
- ✅ Branch protection prevents merge until apply succeeds
- ✅ Can test and fix before merging
- ✅ Complete audit trail

**Documentation:** See `docs/MANUAL_TERRAFORM_WORKFLOW.md`

**Setup:**

```bash
# Configure branch protection
./github/setup-branch-protection.sh
```

---

### Option B: Label-Triggered Apply (Safe)

Good middle ground - add label to trigger apply.

**Workflow:**

- `terraform-plan-and-apply.yml` - Plan + optional apply

**How it works:**

1. Create PR → Plan runs automatically
2. Add `test-apply` label to PR
3. Apply runs automatically
4. Review results → Merge if success

**Benefits:**

- ✅ Easy to trigger (just add label)
- ✅ Can test before merging
- ✅ Good for team workflows

**Documentation:** See `docs/TERRAFORM_TEST_BEFORE_MERGE.md`

---

### Option C: Auto Apply (Legacy)

⚠️ **Not Recommended** - Only for testing or trusted changes.

**Workflows:**

- `terraform-plan.yml` - Plan on PR
- `terraform-apply.yml` - Apply on merge to main

**How it works:**

1. Create PR → Plan runs
2. Merge PR → Apply runs automatically
3. Hope it works... 🤞

**Risks:**

- ❌ PR already merged if apply fails
- ❌ Must revert PR to rollback
- ❌ No testing before production

---

## 📊 Workflow Comparison

| Feature         | Option A<br/>Manual Apply | Option B<br/>Label Apply | Option C<br/>Auto Apply |
| --------------- | ------------------------- | ------------------------ | ----------------------- |
| **Control**     | 🟢 Full                   | 🟡 Medium                | 🔴 Low                  |
| **Safety**      | 🟢 Maximum                | 🟡 High                  | 🔴 Medium               |
| **Convenience** | 🟡 Manual                 | 🟢 Easy                  | 🟢 Automatic            |
| **Rollback**    | 🟢 Easy                   | 🟢 Easy                  | 🔴 Hard                 |
| **Best For**    | Production                | Team projects            | Testing only            |
| **Recommended** | ⭐ **YES**                | ✅ Yes                   | ⚠️ No                   |

---

## 🚀 Other Workflows

### `deploy-to-s3.yml`

Deploys the map HTML to S3 and invalidates CloudFront cache.

**Trigger:** Manual via workflow dispatch

**Use:** Deploy website updates after infrastructure is ready

---

### `terraform-destroy.yml`

Destroys all Terraform-managed infrastructure.

**Trigger:** Manual with confirmation

**Use:** Teardown infrastructure (use with caution!)

---

## 📝 Quick Start

### For New Projects (Recommended Setup)

```bash
# 1. Choose Option A (Manual Apply)
# Already set up! No changes needed.

# 2. Configure branch protection
./github/setup-branch-protection.sh

# 3. Test it
git checkout -b test/terraform-workflow
echo "# test" >> terraform/s3-cloudfront/README.md
git commit -am "test: verify terraform workflow"
git push origin test/terraform-workflow

# 4. Create PR on GitHub

# 5. Review plan in PR

# 6. Go to Actions → "Terraform Apply (Manual)"
#    Click "Run workflow"
#    Enter PR number

# 7. Wait for apply to complete

# 8. Merge PR if successful

# Done! 🎉
```

---

## 🔒 Security Notes

### Required Secrets

Add these to GitHub repository secrets:

```
AWS_ACCESS_KEY_ID       - AWS access key for Terraform
AWS_SECRET_ACCESS_KEY   - AWS secret key for Terraform
```

**How to add:**

1. Go to Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add both secrets

### Permissions

Workflows need these permissions:

- `contents: read` - Read repository code
- `pull-requests: write` - Comment on PRs
- `statuses: write` - Create status checks
- `issues: write` - Create issues on failure

---

## 📚 Documentation

- **Manual Workflow:** `docs/MANUAL_TERRAFORM_WORKFLOW.md`
- **Test Before Merge:** `docs/TERRAFORM_TEST_BEFORE_MERGE.md`
- **Failure Handling:** `docs/TERRAFORM_FAILURE_HANDLING.md`
- **All Workflows:** `docs/TERRAFORM_WORKFLOWS.md`
- **AWS Deployment:** `docs/AWS_DEPLOYMENT.md`
- **Cost Analysis:** `docs/AWS_COST_ANALYSIS.md`

---

## 🆘 Troubleshooting

### Workflow not triggering

**Check:**

- Workflow file is on `main` branch
- File paths match trigger conditions
- Branch protection doesn't block workflows

### Apply fails with state lock

```bash
# Check locks
aws dynamodb get-item \
  --table-name terraform-locks \
  --key '{"LockID": {"S": "us-law-severity-map/terraform.tfstate"}}'

# Force unlock (DANGER!)
cd terraform/s3-cloudfront
terraform force-unlock LOCK_ID
```

### Status check not showing

**Check:**

- Workflow completed (not still running)
- Status check name matches exactly
- GitHub status API is working

---

## 🎓 Best Practices

1. **Always use Option A** for production infrastructure
2. **Review plans** before triggering apply
3. **Test infrastructure** after apply succeeds
4. **Keep state in S3** (already configured)
5. **Use state locking** (already configured)
6. **Monitor AWS costs** regularly
7. **Document changes** in PR descriptions
8. **Merge promptly** after apply (don't leave PRs hanging)

---

## 📈 Metrics

Track these for your workflows:

- **Plan success rate** - Should be >95%
- **Apply success rate** - Should be >90%
- **Time to merge** - Average time from PR to merge
- **Failed applies** - Count and investigate
- **Cost per month** - AWS bill tracking

---

**Last Updated:** October 29, 2025  
**Status:** Production Ready ✅  
**Recommended:** Option A (Manual Apply) ⭐
