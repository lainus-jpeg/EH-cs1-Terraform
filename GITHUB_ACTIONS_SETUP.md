# GitHub Actions CI/CD Setup Guide for Terraform

This guide walks through setting up GitHub Actions CI/CD for Terraform infrastructure management.

## Overview

The pipeline provides:
- **Automatic Plan on PR**: When you create a pull request, Terraform plan runs and comments on the PR
- **Automatic Apply on Merge**: When PR is merged to main, Terraform apply runs automatically
- **Remote State Management**: State is stored in S3 with DynamoDB locking
- **OIDC Authentication**: Secure authentication to AWS without storing credentials

## Prerequisites

✅ Already completed:
- [x] S3 bucket created for state: `eh-cs1-terraform-state-697568497210`
- [x] DynamoDB table created for locks: `terraform-locks`
- [x] GitHub OIDC provider configured in AWS
- [x] IAM role `github-actions-ecr-push` has state management permissions
- [x] Workflows created: `.github/workflows/terraform-*.yml`

## Setup Steps

### Step 1: Get Required AWS Values

Run these commands to gather the needed information:

```bash
# Get AWS Account ID
aws sts get-caller-identity --query Account --output text

# Get GitHub OIDC Role ARN
cd z:\Semester 3\github rep case1\infra\terraform\v4\dev
terraform output github_oidc_role_arn

# Get AWS Region
echo "eu-central-1"
```

Expected outputs:
- **AWS Account ID**: `697568497210`
- **GitHub OIDC Role ARN**: `arn:aws:iam::697568497210:role/github-actions-ecr-push`
- **AWS Region**: `eu-central-1`

### Step 2: Add GitHub Secrets

Go to your GitHub repository settings:
1. **Navigate to**: Settings → Secrets and variables → Actions → New repository secret

2. **Add these secrets**:

| Secret Name | Value | Notes |
|-------------|-------|-------|
| `AWS_REGION` | `eu-central-1` | AWS region for deployment |
| `AWS_ACCOUNT_ID` | `697568497210` | Your AWS account ID |
| `AWS_GITHUB_OIDC_ROLE_ARN` | `arn:aws:iam::697568497210:role/github-actions-ecr-push` | IAM role for OIDC |

**How to add a secret:**
- Click "New repository secret"
- Enter Name (e.g., `AWS_REGION`)
- Enter Value (e.g., `eu-central-1`)
- Click "Add secret"

### Step 3: Initialize Terraform Backend

Since you're using S3 backend, you need to initialize it locally once:

```bash
cd z:\Semester 3\github rep case1\infra\terraform\v4\dev

# Migrate local state to S3 (if you have existing state)
terraform init

# When prompted, confirm migration of state to S3:
# Do you want to copy existing state to the new backend?
# Type: yes
```

This uploads your existing state to S3 and configures the backend.

### Step 4: Commit and Test

Create a test PR to verify the pipeline works:

```bash
# Create a new branch
git checkout -b test/github-actions

# Make a small change (e.g., update a comment)
# Then commit
git add .
git commit -m "Test GitHub Actions workflow"
git push origin test/github-actions
```

Then:
1. Go to GitHub and create a Pull Request from `test/github-actions` to `main`
2. Check the "Actions" tab to see the workflow running
3. Once plan completes, it will post results as a comment on the PR

## How It Works

### Pull Request Flow (terraform-plan.yml)
```
1. PR created with .tf file changes
2. GitHub Actions automatically triggers
3. Terraform init/validate/plan runs
4. Plan output posted as PR comment
5. Team reviews before merging
```

### Merge to Main Flow (terraform-apply.yml)
```
1. PR merged to main branch
2. GitHub Actions automatically triggers
3. Terraform plan runs (should be no surprises)
4. Terraform apply automatically executes
5. Outputs saved as artifacts
6. Test summary created
```

## Troubleshooting

### "Error: Failed to acquire state lock"

**Cause**: DynamoDB table not accessible or permissions missing

**Solution**:
```bash
# Verify table exists
aws dynamodb describe-table --table-name terraform-locks --region eu-central-1

# If not found, create it:
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

### "Error: InvalidClientTokenId"

**Cause**: AWS credentials not properly configured or role ARN wrong

**Solution**:
1. Verify GitHub Secrets are set correctly
2. Check role ARN matches exactly: `aws iam get-role --role-name github-actions-ecr-push --query Role.Arn`
3. Ensure role has DynamoDB and S3 permissions

### Plan succeeds but Apply shows "No changes"

**Cause**: Normal - means infrastructure already matches code

**Solution**: This is expected behavior. Only changes will trigger apply.

### "provider.tf: Error reading"

**Cause**: Backend configuration cannot find bucket

**Solution**:
1. Verify bucket name in `provider.tf` matches actual bucket:
   ```bash
   aws s3api list-buckets --query 'Buckets[?contains(Name, `terraform-state`)].Name'
   ```
2. Update bucket name in `provider.tf` if needed

## Security Best Practices

✅ **Implemented**:
- [x] OIDC authentication (no secrets stored in AWS)
- [x] State locking with DynamoDB
- [x] Encrypted state at rest (S3 default)
- [x] Version control for state (S3 versioning enabled)
- [x] Least privilege IAM permissions
- [x] GitHub secrets for sensitive values

⚠️ **Additional Recommendations**:
- [ ] Enable versioning on `.gitignore` (keep sensitive files out of git)
- [ ] Rotate AWS credentials quarterly
- [ ] Use branch protection rules (require approvals before merge)
- [ ] Enable state locking timeout

To add branch protection:
1. Go to Settings → Branches
2. Add rule for `main` branch
3. Require reviews before merge
4. Require status checks to pass

## Monitoring & Debugging

### View Workflow Logs

1. Go to GitHub → Actions tab
2. Click on the workflow run
3. Click on "Terraform Plan" or "Terraform Apply" job
4. Expand steps to see logs

### View Terraform State

```bash
# List all states in S3
aws s3 ls s3://eh-cs1-terraform-state-697568497210/

# Download current state
aws s3 cp s3://eh-cs1-terraform-state-697568497210/dev/terraform.tfstate .

# View state contents
terraform show terraform.tfstate | head -50
```

### CI/CD Pipeline Metrics

```bash
# Check lock status
aws dynamodb scan --table-name terraform-locks --region eu-central-1

# View S3 state versions
aws s3api list-object-versions --bucket eh-cs1-terraform-state-697568497210
```

## Next Steps

1. ✅ Test the pipeline with a PR
2. ✅ Add branch protection rules to `main`
3. ✅ Document any environment-specific variables
4. Consider adding:
   - [ ] Terraform cost estimation in PRs (terraform-cost-estimation)
   - [ ] Policy checks (OPA/Sentinel)
   - [ ] Multi-environment support (dev/staging/prod)
   - [ ] Scheduled drift detection

## Rollback Procedure

If you need to rollback infrastructure:

```bash
# 1. Find the previous state version
aws s3api list-object-versions \
  --bucket eh-cs1-terraform-state-697568497210 \
  --prefix dev/terraform.tfstate

# 2. Restore from backup (local)
aws s3 cp s3://eh-cs1-terraform-state-697568497210/dev/terraform.tfstate.backup terraform.tfstate

# 3. Apply the old state
terraform apply --auto-approve

# Or revert code changes and let CI/CD handle it
git revert <commit-hash>
git push origin main
```

## Support

For issues:
1. Check workflow logs in Actions tab
2. Verify all GitHub Secrets are set
3. Confirm AWS permissions with: `aws iam simulate-principal-policy --policy-source-arn <role-arn>`
4. Review CloudTrail logs in AWS for authentication issues
