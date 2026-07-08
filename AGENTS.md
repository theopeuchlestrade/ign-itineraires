# Contribution Guidelines

## Workflow

When working on new features or changes:

1. **Always create a branch from main**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes and commit**
   ```bash
   git add .
   git commit -m "Your commit message"
   ```

3. **Create a Pull Request**
   - Push your branch: `git push origin feature/your-feature-name`
   - Create a PR from your branch to main on GitHub
   - Wait for review (if applicable)
   - Merge the PR

## Notes

- CODEOWNERS: @theopeuchlestrade is the sole code owner
- PR workflow is recommended for traceability and review purposes
