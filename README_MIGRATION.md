# Branch Migration: Rewrite2 → Main

## Overview
This PR provides tools and documentation to migrate the `rewrite2` branch to become the new `main` branch, and delete obsolete branches.

## Problem
The current repository has multiple branches, and we want to:
1. Make `rewrite2` the main/trunk branch
2. Delete other obsolete branches:
   - `copilot/reduce-codebase-line-count`
   - `rewrite/no-spoke`

## Solution Approach
Due to authentication and permission constraints in the CI environment, the actual branch migration cannot be performed automatically. Instead, this PR provides:

1. **Automated Script**: `migrate_branches.sh` - A bash script that performs the migration
2. **Manual Guide**: `BRANCH_MIGRATION_GUIDE.md` - Detailed step-by-step instructions
3. **Multiple Options**: Different approaches depending on your setup and preferences

## Quick Start

### Option 1: Using the Automated Script (Recommended)
```bash
# Clone the repository with proper authentication
git clone https://github.com/TLOBillyQ/monopoly.git
cd monopoly

# Checkout this PR branch to get the script
git checkout copilot/delete-other-branches

# Run in dry-run mode first to see what would happen
./migrate_branches.sh --dry-run

# If everything looks good, run the actual migration
./migrate_branches.sh
```

### Option 2: Manual Steps
See `BRANCH_MIGRATION_GUIDE.md` for detailed manual instructions covering:
- Git command-line approach
- GitHub web interface approach  
- GitHub CLI approach

## What the Script Does
1. **Fetches** all branches from remote
2. **Creates** a backup of the current main branch
3. **Resets** main branch to match rewrite2 content
4. **Force pushes** the updated main branch
5. **Deletes** obsolete branches (both remote and local)
6. **Optionally** removes the rewrite2 branch after migration

## Safety Features
- Dry-run mode to preview changes
- Confirmation prompts before destructive operations
- Automatic backup of main branch before migration
- Color-coded output for easy reading
- Detailed error handling and warnings

## Important Warnings
⚠️ **This is a destructive operation!**
- The current main branch content will be replaced
- Deleted branches cannot be easily recovered
- All collaborators should be notified
- Make sure you have backups

⚠️ **Requires proper authentication**
- Must run with GitHub credentials that have push access
- Cannot be run in CI/CD without proper token permissions
- Recommended to run locally with SSH or personal access token

## Repository Structure After Migration
The rewrite2 branch has a different structure:
```
monopoly/
├── src/              # Source code (new organized structure)
│   ├── adapters/     # Platform adapters
│   ├── bootstrap/    # Initialization
│   ├── config/       # Configuration
│   ├── core/         # Core game logic
│   ├── gameplay/     # Gameplay systems
│   └── util/         # Utilities
├── scripts/          # Development scripts
├── docs/             # Documentation
├── assets/           # Game assets
├── main.lua          # Entry point
└── README.md         # Project documentation
```

This replaces the current flat structure with many `.lua` files at root level.

## Verification Steps
After running the migration:
1. Check that main branch has the correct structure
2. Verify the game still runs: `love .` (if using LÖVE2D)
3. Confirm obsolete branches are deleted
4. Update CI/CD if necessary
5. Notify team members

## Rollback
If something goes wrong, restore from the backup:
```bash
git checkout main
git reset --hard main-backup-TIMESTAMP
git push origin main --force
```

## Questions?
- Check `BRANCH_MIGRATION_GUIDE.md` for more detailed information
- Review the script `migrate_branches.sh` to understand exactly what it does
- Test in a fork first if unsure

## Closing This PR
After successfully migrating the branches:
1. This PR branch (`copilot/delete-other-branches`) can be deleted
2. Consider closing any dependent PRs
3. Update documentation to reflect new structure
