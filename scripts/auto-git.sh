#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Prevent simultaneous executions
exec 9>"$ROOT/.git/auto-git.lock"
flock -n 9 || exit 0

# Only work on main branch
if [[ "$(git branch --show-current)" != "main" ]]; then
    echo "Skipping: not on main"
    exit 0
fi

# Stage changes, respecting .gitignore
git add -A

# Commit only when changes exist
if ! git diff --cached --quiet; then
    git diff --cached --check
    git commit -m "Auto backup: $(date '+%Y-%m-%d %H:%M:%S')"
fi

# Push pending commits
GIT_TERMINAL_PROMPT=0 git push origin main

echo "Git backup completed successfully"
