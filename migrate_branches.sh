#!/usr/bin/env bash
# Branch Migration Script
# This script migrates the rewrite2 branch to become the main branch
# and removes other branches.
#
# IMPORTANT: Run this script locally with proper GitHub authentication
# DO NOT run in CI/CD without careful consideration
#
# Usage: ./migrate_branches.sh [--dry-run]

set -e  # Exit on error

DRY_RUN=false
if [ "$1" == "--dry-run" ]; then
    DRY_RUN=true
    echo "=== DRY RUN MODE - No changes will be made ==="
    echo
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a git repository
if [ ! -d .git ]; then
    print_error "Not in a git repository!"
    exit 1
fi

# Check if we have the right repository
REPO_URL=$(git remote get-url origin)
if [[ ! "$REPO_URL" =~ "TLOBillyQ/monopoly" ]]; then
    print_warning "Repository URL doesn't match expected: $REPO_URL"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

print_step "Fetching all branches..."
if [ "$DRY_RUN" = false ]; then
    git fetch --all --prune
else
    echo "  Would run: git fetch --all --prune"
fi

# Check if rewrite2 exists
if [ "$DRY_RUN" = false ]; then
    if ! git rev-parse --verify origin/rewrite2 > /dev/null 2>&1; then
        print_error "Branch 'rewrite2' does not exist on origin!"
        exit 1
    fi
else
    echo "  Would verify origin/rewrite2 exists"
fi

print_warning "This operation will:"
echo "  1. Replace 'main' branch content with 'rewrite2' branch content"
echo "  2. Delete branches: copilot/reduce-codebase-line-count, rewrite/no-spoke"
echo "  3. This is a DESTRUCTIVE operation!"
echo

if [ "$DRY_RUN" = false ]; then
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
fi

BACKUP_BRANCH=""  # Initialize backup branch name
print_step "Creating backup of main branch..."
if [ "$DRY_RUN" = false ]; then
    git checkout main 2>/dev/null || git checkout -b main origin/main
    BACKUP_BRANCH="main-backup-$(date +%Y%m%d-%H%M%S)"
    git branch "$BACKUP_BRANCH"
    echo "  Created backup branch: $BACKUP_BRANCH"
else
    BACKUP_BRANCH="main-backup-<TIMESTAMP>"
    echo "  Would create backup branch: $BACKUP_BRANCH"
fi

print_step "Resetting main to rewrite2..."
if [ "$DRY_RUN" = false ]; then
    git reset --hard origin/rewrite2
    echo "  Main branch now points to rewrite2 content"
else
    echo "  Would run: git reset --hard origin/rewrite2"
fi

print_step "Pushing updated main branch..."
if [ "$DRY_RUN" = false ]; then
    print_warning "Force pushing to main branch in 3 seconds... (Ctrl+C to abort)"
    sleep 3
    git push origin main --force
    echo "  Main branch updated on origin"
else
    echo "  Would run: git push origin main --force"
fi

print_step "Deleting obsolete branches..."
BRANCHES_TO_DELETE=(
    "copilot/reduce-codebase-line-count"
    "rewrite/no-spoke"
)

for branch in "${BRANCHES_TO_DELETE[@]}"; do
    if [ "$DRY_RUN" = false ]; then
        if git rev-parse --verify "origin/$branch" > /dev/null 2>&1; then
            git push origin --delete "$branch" || print_warning "Failed to delete $branch"
            echo "  Deleted remote branch: $branch"
        else
            print_warning "Branch $branch does not exist on origin, skipping"
        fi
        
        # Delete local branch if it exists
        if git rev-parse --verify "$branch" > /dev/null 2>&1; then
            git branch -D "$branch" 2>/dev/null || true
            echo "  Deleted local branch: $branch"
        fi
    else
        echo "  Would delete branch: $branch"
    fi
done

print_step "Cleaning up old rewrite2 branch (optional)..."
if [ "$DRY_RUN" = false ]; then
    read -p "Do you want to delete the rewrite2 branch now that it's merged? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin --delete rewrite2 || print_warning "Failed to delete rewrite2"
        git branch -D rewrite2 2>/dev/null || true
        echo "  Deleted rewrite2 branch"
    fi
else
    echo "  Would optionally delete rewrite2 branch"
fi

echo
print_step "Migration complete!"
echo "  Main branch now contains rewrite2 content"
echo "  Obsolete branches have been deleted"
echo "  Backup branch: $BACKUP_BRANCH (local only)"
echo
print_warning "Remember to:"
echo "  1. Update any CI/CD configurations"
echo "  2. Notify team members of the change"
echo "  3. Update documentation if necessary"
echo "  4. Consider updating the default branch in GitHub settings"
