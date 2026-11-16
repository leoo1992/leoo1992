#!/usr/bin/env bash
# Single entry point for the remaining GitHub account maintenance.
# Run from the root of a clone of https://github.com/leoo1992/leoo1992
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -f "$ROOT/scripts/curate-github-profile.sh" ] || { echo "Missing scripts/curate-github-profile.sh"; exit 2; }
[ -f "$ROOT/scripts/rewrite-public-git-history.sh" ] || { echo "Missing scripts/rewrite-public-git-history.sh"; exit 2; }

echo "Step 1/2: pin selected projects and archive the listed exercise repositories."
bash "$ROOT/scripts/curate-github-profile.sh"

echo
echo "Step 2/2: back up, scan, rewrite, force-push, and verify public repository histories."
bash "$ROOT/scripts/rewrite-public-git-history.sh"

echo
echo "Maintenance scripts completed. Keep the history backups until all deployments and collaborators are verified."
