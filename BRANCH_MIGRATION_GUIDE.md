# Branch Migration Guide

## Objective
Make the `rewrite2` branch the main branch and delete all other branches.

## Current Branch Structure
Based on GitHub API:
- `main` - current main branch
- `rewrite2` - target branch to become main
- `copilot/delete-other-branches` - current PR branch
- `copilot/reduce-codebase-line-count` - to be deleted
- `rewrite/no-spoke` - to be deleted

## Rewrite2 Branch Structure
The `rewrite2` branch contains a complete refactoring with:
- `src/` directory with organized subdirectories:
  - `src/adapters/` - Platform adapters (love2d, etc.)
  - `src/bootstrap/` - Initialization code
  - `src/config/` - Configuration files
  - `src/core/` - Core game logic  
  - `src/gameplay/` - Gameplay systems
  - `src/util/` - Utility functions
- `scripts/` directory with development scripts
- `docs/` directory with documentation
- `assets/` directory for game assets
- `main.lua` - Entry point

## Migration Steps

### Option 1: Manual Git Commands (Recommended)
Run these commands locally with proper GitHub authentication:

```bash
# 1. Fetch all branches
git fetch --all

# 2. Create a backup of main (optional but recommended)
git checkout main
git branch main-backup

# 3. Replace main with rewrite2 content
git checkout main
git reset --hard origin/rewrite2

# 4. Force push to main (WARNING: This overwrites main!)
git push origin main --force

# 5. Delete other branches
git push origin --delete copilot/reduce-codebase-line-count
git push origin --delete rewrite/no-spoke
# Keep copilot/delete-other-branches until this PR is closed

# 6. Cleanup local branches
git branch -D copilot/reduce-codebase-line-count
git branch -D rewrite/no-spoke
```

### Option 2: Via GitHub Web Interface
1. Go to repository settings
2. Change default branch from `main` to `rewrite2`
3. Create a PR to merge `rewrite2` into `main` (or just rename branches)
4. Delete unwanted branches via GitHub interface:
   - Navigate to "Branches" page
   - Click delete icon next to each branch to remove

### Option 3: Using GitHub API/CLI
```bash
# Using GitHub CLI (gh)
gh api repos/TLOBillyQ/monopoly/git/refs/heads/main \
  --method PATCH \
  -f sha=$(gh api repos/TLOBillyQ/monopoly/git/refs/heads/rewrite2 -q .object.sha)

# Delete branches
gh api repos/TLOBillyQ/monopoly/git/refs/heads/copilot/reduce-codebase-line-count --method DELETE
gh api repos/TLOBillyQ/monopoly/git/refs/heads/rewrite/no-spoke --method DELETE
```

## Important Notes
- **BACKUP FIRST**: Make sure you have backups before force-pushing
- **BREAKING CHANGE**: This completely replaces the repository structure
- **Coordination**: Notify all collaborators about the change
- **Default Branch**: Consider updating the default branch setting in GitHub repository settings

## Verification
After migration, verify:
1. Main branch has the correct file structure (src/, scripts/, etc.)
2. The game runs correctly: `love .` (assuming LÖVE 2D framework)
3. All necessary files are present
4. Unwanted branches are deleted

## Rollback Plan
If something goes wrong:
```bash
# Restore from backup
git checkout main
git reset --hard main-backup
git push origin main --force
```
