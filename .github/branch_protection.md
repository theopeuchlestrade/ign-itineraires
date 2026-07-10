# Branch Protection Configuration

## Main Branch

The `main` branch is protected and changes must be merged through a pull
request.

### Required Conditions

- The `IGN Itineraires CI` status check must pass.
- The pull request branch must be up to date with `main`.
- All review conversations must be resolved.
- Approvals are not required.
- Code owner review is not required.
- Administrators cannot bypass these requirements.

### Merge Strategy

- Squash merge is the only allowed merge method.
- The pull request title is used as the squash commit message.
- The source branch is deleted automatically after the merge.

### Code Owners

- CODEOWNERS: * @theopeuchlestrade
- You are the sole code owner for all files

### Restrictions

- Direct pushes to `main` are not allowed.
- Force pushes and deletion of `main` are not allowed.
