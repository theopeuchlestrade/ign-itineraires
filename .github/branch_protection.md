# Branch Protection Configuration

This document describes the intended branch protection settings for the `main` branch.

## Current State

The `main` branch currently allows direct pushes. This should be changed to require
Pull Requests with the following conditions.

## Desired Configuration

### Protection Rule for `main`

- **Require a pull request before merging**
  - ✅ Required
  - Require approvals: 1
  - Dismiss stale pull request approvals when new commits are pushed
  - Require review from Code Owners: No
  - Require last push approval: No

- **Require status checks to pass before merging**
  - ✅ Required
  - Require branches to be up to date before merging
  - Status checks that are required:
    - `CI` (from `.github/workflows/ci.yml`)

- **Require linear history**
  - ✅ Required (enforces rebase/squash merge)

- **Other restrictions**
  - ❌ Do not allow force pushes
  - ❌ Do not allow deletions
  - ❌ Require conversation resolution before merging
  - ❌ Require signed commits: No
  - ❌ Require deployments to succeed: No
  - ❌ Restrict who can push to matching branches: No (only admins can merge PRs)

## How to Configure

### Via GitHub Web UI

1. Go to **Settings** → **Branches**
2. Click **Add branch protection rule**
3. Enter `main` in the **Branch name pattern** field
4. Enable the following options:
   - ✅ Require a pull request before merging
     - Require approvals: 1
     - ✅ Dismiss stale pull request approvals when new commits are pushed
   - ✅ Require status checks to pass before merging
     - ✅ Require branches to be up to date before merging
     - Search for and select: `CI`
   - ✅ Require linear history
   - ✅ Do not allow bypassing the above settings
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
      "contexts": ["CI"]
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

- ✅ No direct pushes to `main` will be allowed
- ✅ All changes must go through a Pull Request
- ✅ PR must have at least 1 approval
- ✅ PR must pass CI checks
- ✅ PR must be up-to-date with `main` (linear history/rebase required)
- ✅ All discussions in the PR must be resolved before merging

## Workflow

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make your changes and commit
3. Push to your branch: `git push origin feature/my-feature`
4. Create a Pull Request from your branch to `main`
5. Wait for CI to pass
6. Get at least 1 approval
7. Resolve any discussions
8. Rebase your branch on `main` if needed
9. Merge the PR

## Notes

- The CI workflow already runs on both `push` to `main` and on `pull_request` events
- Once branch protection is enabled, the `push` trigger for `main` will only be used
  by administrators (who can still push directly if they bypass protection)
- All regular contributors will need to use PRs
