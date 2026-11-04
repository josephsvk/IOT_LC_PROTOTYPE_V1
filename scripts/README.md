# KiCad Automatic Git Backup
#
# Purpose:
#   Commit and push saved changes to GitHub.
#
# Schedule:
#   Every 15 minutes via systemd user timer.
#
# Features:
#   - Prevents overlapping executions
#   - Works on the main branch
#   - Respects .gitignore
#   - Skips commits when no changes exist
#   - Pushes pending commits to origin/main
#
# Usage:
#   ./scripts/auto-git.sh
