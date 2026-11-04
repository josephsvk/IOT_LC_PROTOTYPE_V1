#!/usr/bin/env bash
# 15-minute idempotent job: re-export when sources change, validate, commit and push.
# Never pulls or force-pushes; offline/unmerged changes remain local.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source "$ROOT/.kicad-automation.conf"
: "${PROJECT_NAME:?Missing project name}"
: "${GIT_BRANCH:?Missing branch name}"
exec 9>"$(git rev-parse --git-path kicad-automation.lock)"
flock -n 9 || { echo 'Backup already running; skipped'; exit 0; }
if [[ "$(git branch --show-current)" != "$GIT_BRANCH" ]]; then
    echo "Skipping: checked-out branch differs from $GIT_BRANCH"
    exit 0
fi
for cmd in git sha256sum python3 pdfinfo; do
    command -v "$cmd" >/dev/null || { echo "Missing: $cmd" >&2; exit 1; }
done
# Use only existing files; tracked deletions should not break hashing.
# Each path and content is included in the digest. Outputs/docs are excluded.
calculate_source_hash() {
  git ls-files --cached --others --exclude-standard -z -- \
    '*.kicad_sch' '*.kicad_pcb' '*.kicad_pro' '*.kicad_dru' \
    '*.kicad_sym' '*.kicad_mod' '*.kicad_wks' \
    '.kicad-automation.conf' 'scripts/export-pdf.sh' \
    'scripts/generate-readme.py' 'scripts/check-docs.py' \
    | sort -zu | while IFS= read -r -d '' path; do
        [[ -f "$path" ]] && sha256sum -- "$path" || true
      done | sha256sum | cut -d' ' -f1
}
source_hash="$(calculate_source_hash)"
stamp="$(git rev-parse --git-path kicad-docs-source.sha256)"
if [[ ! -e "$stamp" || "$(cat "$stamp")" != "$source_hash" ]]; then
    echo 'Input changed; exporting KiCad documentation'
    bash "$ROOT/scripts/export-pdf.sh"
    # Avoid committing mixed files if a save happened during export.
    new_hash="$(calculate_source_hash)"
    if [[ "$source_hash" != "$new_hash" ]]; then
      echo 'Design changed during export; deferring commit to next cycle' >&2
      exit 1
    fi
    printf '%s\n' "$source_hash" > "$stamp"
else
    python3 "$ROOT/scripts/check-docs.py"
fi
# Honors .gitignore. Never commit secrets or unrelated files in this repository.
git add -A
git diff --cached --check -- "*.sh" "*.py" "*.md" ".gitignore" ".kicad-automation.conf"
if ! git diff --cached --quiet; then
    git commit -m "Auto backup: $(date '+%Y-%m-%d %H:%M:%S')"
fi
GIT_TERMINAL_PROMPT=0 git push origin "$GIT_BRANCH"
echo 'KiCad export, validation and Git push complete'
