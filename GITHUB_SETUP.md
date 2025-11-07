# 📦 GitHub Repository Setup Guide

## 🎯 Create New Repository on GitHub

### Option 1: Using GitHub CLI (Recommended)

If you have GitHub CLI installed:

```bash
# Install gh if needed (macOS)
brew install gh

# Authenticate
gh auth login

# Create repository with SSH
gh repo create raolivei --private --source=. --remote=origin --push

# Push the branch
git push -u origin feat/atlantis-k3s-setup
```

### Option 2: Using GitHub Web UI

1. **Go to GitHub:**
   - Visit: https://github.com/new
   - Or click the "+" icon → "New repository"

2. **Repository Settings:**
   - **Owner:** raolivei
   - **Repository name:** `raolivei`
   - **Description:** "Personal workspace with Atlantis, SwimTO, and other projects"
   - **Visibility:** 
     - ✅ Private (recommended - contains infrastructure code)
     - ⚪ Public (if you want to share)
   - **Initialize repository:**
     - ⚠️ **DO NOT** check "Add a README file"
     - ⚠️ **DO NOT** check "Add .gitignore"
     - ⚠️ **DO NOT** check "Choose a license"
     - (We already have these locally)

3. **Create repository**
   - Click "Create repository"

4. **Push your code:**
   ```bash
   cd /Users/roliveira/WORKSPACE/raolivei
   git push -u origin feat/atlantis-k3s-setup
   ```

## ✅ Verify SSH Authentication

Make sure your SSH key is added to GitHub:

```bash
# Test SSH connection
ssh -T git@github.com

# Should see: "Hi raolivei! You've successfully authenticated..."
```

If authentication fails:

1. **Check for existing SSH keys:**
   ```bash
   ls -la ~/.ssh
   # Look for: id_ed25519.pub or id_rsa.pub
   ```

2. **Generate new SSH key (if needed):**
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   # Press Enter to accept defaults
   ```

3. **Add SSH key to ssh-agent:**
   ```bash
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```

4. **Copy public key:**
   ```bash
   cat ~/.ssh/id_ed25519.pub | pbcopy
   # Or manually copy the output
   ```

5. **Add to GitHub:**
   - Go to: https://github.com/settings/ssh/new
   - Title: "Raspberry Pi k3s cluster" (or whatever you prefer)
   - Key: Paste the copied public key
   - Click "Add SSH key"

6. **Test again:**
   ```bash
   ssh -T git@github.com
   ```

## 🚀 After Repository is Created

Once the repository exists on GitHub:

```bash
# Push the Atlantis setup branch
cd /Users/roliveira/WORKSPACE/raolivei
git push -u origin feat/atlantis-k3s-setup

# Create a Pull Request on GitHub to review changes
# Go to: https://github.com/raolivei/raolivei/pull/new/feat/atlantis-k3s-setup

# Or push main branch
git checkout main
git push -u origin main
```

## 📋 What Will Be Pushed

Your branch includes:

### Atlantis Setup (22 files)
- ✅ 9 comprehensive documentation files
- ✅ 5 Kubernetes manifests
- ✅ 3 configuration files
- ✅ 2 deployment scripts
- ✅ Repository config for us-law-severity-map

### Total
- **Files:** 22
- **Lines:** 4,623 lines of code and documentation
- **Size:** ~300KB

## 🔒 Security Notes

### Files Committed
- ✅ `.gitignore` - Prevents committing secrets
- ✅ `secret.yaml.example` - Example only (safe)
- ⚠️ **DO NOT** commit `secret.yaml` (actual secrets)

### Files NOT Committed (Good!)
- ❌ `atlantis/secret.yaml` - Excluded by .gitignore
- ❌ `.env` files - Excluded by .gitignore
- ❌ Terraform state files - Excluded by .gitignore

## 🎯 Recommended Repository Settings

After creating the repository, configure these settings:

### Branch Protection Rules

Go to: Repository → Settings → Branches → Add rule

**Protect main branch:**
- ✅ Require pull request reviews before merging (1 reviewer)
- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- ✅ Include administrators

### Secrets

Go to: Repository → Settings → Secrets and variables → Actions

Add these secrets (for GitHub Actions if you use them):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `ATLANTIS_GH_TOKEN` (if automating Atlantis deployment)

## 🌟 Next Steps

After pushing:

1. **Create Pull Request:**
   - Review the Atlantis setup
   - Check all files are correct
   - Merge to main

2. **Deploy Atlantis:**
   ```bash
   cd atlantis
   ./deploy.sh
   ```

3. **Configure Webhooks:**
   - Follow instructions in `atlantis/SETUP_GUIDE.md`

4. **Share with Team:**
   - Send them link to `atlantis/START_HERE.md`

## 🆘 Troubleshooting

### "Permission denied (publickey)"

Your SSH key isn't configured:
```bash
# Generate new key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to GitHub (see steps above)
```

### "Repository not found"

Repository doesn't exist yet:
- Create it on GitHub first (see Option 2 above)

### "Remote origin already exists"

Remote is already configured:
```bash
# Update remote URL to use SSH
git remote set-url origin git@github.com:raolivei/raolivei.git
```

---

Ready to create your repository! 🚀

