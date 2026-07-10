# Contribution Guidelines

## Workflow

When working on new features or changes:

1. **Always create a branch from main**
   ```bash
   git switch main
   git pull --ff-only origin main
   git switch -c feature/your-feature-name
   ```

2. **Make your changes and commit**
   ```bash
   git add .
   git commit -m "Your commit message"
   ```

3. **Create a Pull Request**
   - Push your branch: `git push origin feature/your-feature-name`
   - Create a PR from your branch to main on GitHub
   - Keep the branch up to date with main
   - Wait for the `IGN Itineraires CI` status check to pass
   - Resolve all review conversations
   - Use **Squash and merge**

## Notes

- CODEOWNERS: @theopeuchlestrade is the sole code owner
- Pull requests are required; direct pushes to main are blocked
- Approvals and code owner reviews are not required
- Source branches are deleted automatically after merge
