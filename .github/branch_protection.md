# Branch Protection Configuration

This document describes the branch protection settings for the `main` branch.

## Current State

The `main` branch currently allows direct pushes. This should be changed to require
Pull Requests with the following conditions.

## Desired Configuration

### Protection Rule for `main`

- **Require a pull request before merging**
  - ✅ Required
  - Require approvals: 1
  - Dismiss stale pull request approvals when new commits are pushed
  - **Require review from Code Owners: No** (to allow self-approval)
  - Require last push approval: No

- **Require status checks to pass before merging**
  - ✅ Required
  - Require branches to be up to date before merging
  - Status checks that are required:
    - `CI` (from `.github/workflows/ci.yml`)
    - `check-owner-approval` (from `.github/workflows/require-owner-approval.yml`)

- **Require linear history**
  - ✅ Required (enforces rebase/squash merge)

- **Other restrictions**
  - ✅ Do not allow force pushes
  - ✅ Do not allow deletions
  - ✅ Require conversation resolution before merging
  - ❌ Require signed commits: No
  - ❌ Require deployments to succeed: No
  - ❌ Restrict who can push to matching branches: No

### Code Owners

- **CODEOWNERS file**: `.github/CODEOWNERS`
- **Content**: `* @theopeuchlestrade`
- **Note**: Code owners review is NOT required for merging, but the `owner-approval` workflow
  enforces that only @theopeuchlestrade can approve PRs (including self-approval)

## How to Configure

### Via GitHub Web UI

1. Go to **Settings** → **Branches**
2. Click **Add branch protection rule**
3. Enter `main` in the **Branch name pattern** field
4. Enable the following options:
   - ✅ Require a pull request before merging
     - Require approvals: 1
     - ✅ Dismiss stale pull request approvals when new commits are pushed
     - ❌ **Require review from Code Owners: NO** (to allow self-approval)
   - ✅ Require status checks to pass before merging
     - ✅ Require branches to be up to date before merging
     - Search for and select: `CI` and `check-owner-approval`
   - ✅ Require linear history
   - ✅ Do not allow bypassing the above settings
   - ✅ Require conversation resolution before merging
   - ✅ Do not allow force pushes
   - ✅ Do not allow deletions
5. Click **Create**

### Via GitHub API

```bash
# Requires a personal access token with repo admin permissions
GITHUB_TOKEN="your_personal_access_token"
REPO_OWNER="theopeuchlestrade"
REPO_NAME="ign-itineraires"

# Enable branch protection for main
curl -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/branches/main/protection" \
  -d '{
    "required_status_checks": {
      "strict": true,
      "contexts": ["CI", "check-owner-approval"]
    },
    "enforce_admins": true,
    "required_pull_request_reviews": {
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": false,
      "required_approving_review_count": 1
    },
    "restrictions": null,
    "required_linear_history": true,
    "allow_force_pushes": false,
    "allow_deletions": false,
    "require_conversation_resolution": true,
    "require_signed_commits": false
  }'
```

## Impact

After this configuration:

- ✅ No direct pushes to `main` will be allowed (even for admins)
- ✅ All changes must go through a Pull Request
- ✅ PR must have at least 1 approval **from @theopeuchlestrade**
- ✅ PR must pass CI checks
- ✅ PR must pass the `owner-approval` check (validates approver)
- ✅ PR must be up-to-date with `main` (linear history/rebase required)
- ✅ All discussions in the PR must be resolved before merging
- ✅ Self-approval is **allowed** for @theopeuchlestrade

## Workflow

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make your changes and commit
3. Push to your branch: `git push origin feature/my-feature`
4. Create a Pull Request from your branch to `main`
5. Wait for CI to pass
6. Get approval from @theopeuchlestrade (can be self-approval)
7. Resolve any discussions
8. Rebase your branch on `main` if needed
9. Ensure `owner-approval` check passes
10. Merge the PR

## Notes

- The CI workflow already runs on both `push` to `main` and on `pull_request` events
- Once branch protection is enabled, the `push` trigger for `main` will only be used
  by administrators (who can still push directly if they bypass protection, but this is blocked by enforce_admins: true)
- All regular contributors will need to use PRs

## How it works

This configuration uses a combination of:

1. **CODEOWNERS file** (`.github/CODEOWNERS`): Defines @theopeuchlestrade as the code owner for all files
2. **Branch protection**: Requires PR with 1 approval, but does NOT require code owner review (to allow self-approval)
3. **owner-approval workflow** (`.github/workflows/require-owner-approval.yml`): Validates that all approvals come from @theopeuchlestrade

This approach allows:
- ✅ Only @theopeuchlestrade can approve PRs (enforced by workflow)
- ✅ @theopeuchlestrade can self-approve (allowed by workflow)
- ✅ No direct pushes to main (enforced by branch protection)
- ✅ PR must pass CI checks (enforced by branch protection)
