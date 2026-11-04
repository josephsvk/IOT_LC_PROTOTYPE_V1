#!/usr/bin/env bash
# KiCad automated documentation + Git backup.
# Runs from the systemd user timer every ~15 minutes.
# Only regenerates docs when source/design tools change.
# Never force-pushes or pulls/rebases automatically.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

exec 9>"$ROOT/.git/auto-git.lock"
flock -n 9 || { echo 'Another backup is running; skipping'; exit 0; }

if [[ "$(git branch --show-current)" != "main" ]]; then
    echo 'Not on main; skipping'
    exit 0
fi

# If project files are currently being written, skip this cycle.
# Do not use KiCad .lck files here: they remain while the editor is open.

for cmd in git sha256sum python3 pdfinfo; do
    command -v "$cmd" >/dev/null || { echo "Missing: $cmd" >&2; exit 1; }
done

# Hash all tracked and new, non-ignored design sources + export generators.
# This does not include README/docs, so output files cannot cause a loop.
source_hash="$({
    git ls-files --cached --others --exclude-standard -z -- \
      '*.kicad_sch' '*.kicad_pcb' '*.kicad_pro' '*.kicad_dru' \
      '*.kicad_sym' '*.kicad_mod' \
      'scripts/export-pdf.sh' 'scripts/generate-readme.py'
} | sort -zu | xargs -0 -r sha256sum | sha256sum | cut -d' ' -f1)"

stamp="$ROOT/.git/kicad-docs-source.sha256"
if [[ ! -f "$stamp" || "$(cat "$stamp")" != "$source_hash" ]]; then
    echo 'Design changed: generating documentation'
    /usr/bin/bash "$ROOT/scripts/export-pdf.sh"
    python3 "$ROOT/scripts/check-docs.py"
    printf '%s\n' "$source_hash" > "$stamp"
else
    echo 'Documentation unchanged; skipping export'
    python3 "$ROOT/scripts/check-docs.py"
fi

# Stage all non-ignored project files. Review .gitignore before keeping secrets locally.
git add -A
git diff --cached --check

if ! git diff --cached --quiet; then
    git commit -m "Auto backup: $(date '+%Y-%m-%d %H:%M:%S')"
fi

# Noninteractive; if offline, the local commits remain for next run.
GIT_TERMINAL_PROMPT=0 git push origin main
echo 'KiCad documentation and Git backup completed'
