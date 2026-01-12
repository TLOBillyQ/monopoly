# Quick Migration Commands

Run these commands locally with proper GitHub authentication to make `rewrite2` the main branch:

```bash
# One-liner migration (review script first!)
git fetch --all && \
git checkout main && \
git branch main-backup-$(date +%Y%m%d-%H%M%S) && \
git reset --hard origin/rewrite2 && \
echo "Ready to push. Run: git push origin main --force"

# Then delete obsolete branches (run separately for better error handling)
git push origin --delete copilot/reduce-codebase-line-count
git push origin --delete rewrite/no-spoke
```

Or use the automated script:
```bash
./migrate_branches.sh --dry-run  # Preview
./migrate_branches.sh            # Execute
```

See `README_MIGRATION.md` and `BRANCH_MIGRATION_GUIDE.md` for full documentation.
