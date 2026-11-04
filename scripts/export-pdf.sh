#!/usr/bin/env bash
# Generate PDFs from the active KiCad hierarchy and PCB, then README PNG previews.
# Uses the project configured in .kicad-automation.conf.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source "$ROOT/.kicad-automation.conf"
: "${PROJECT_NAME:?Missing PROJECT_NAME}"
SCH="$ROOT/$PROJECT_NAME.kicad_sch"
PCB="$ROOT/$PROJECT_NAME.kicad_pcb"
PDF_DIR="$ROOT/docs/pdf"
for cmd in kicad-cli pdftoppm pdfinfo python3; do
  command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 1; }
done
python3 -c 'from PIL import Image' >/dev/null || { echo 'Install python3-pil (Pillow)' >&2; exit 1; }
[[ -f "$SCH" && -f "$PCB" ]] || { echo "Missing schematic or PCB for $PROJECT_NAME" >&2; exit 1; }
mkdir -p "$PDF_DIR"
# Do not recursively export all .kicad_sch files: unused draft sheets must not appear.
echo '[1/5] Active hierarchical schematic'
kicad-cli sch export pdf --no-background-color -o "$PDF_DIR/schematic.pdf" "$SCH"
echo '[2/5] PCB front'
kicad-cli pcb export pdf --mode-single --layers 'F.Cu,F.SilkS,Edge.Cuts' --check-zones -o "$PDF_DIR/pcb-front.pdf" "$PCB"
echo '[3/5] PCB back'
kicad-cli pcb export pdf --mode-single --layers 'B.Cu,B.SilkS,Edge.Cuts' --check-zones -o "$PDF_DIR/pcb-back.pdf" "$PCB"
echo '[4/5] Individual PCB layers'
kicad-cli pcb export pdf --mode-multipage --layers 'F.Cu,B.Cu,F.SilkS,B.SilkS' --common-layers 'Edge.Cuts' --check-zones -o "$PDF_DIR/pcb-layers.pdf" "$PCB"
echo '[5/5] Cropped PNG previews and README'
python3 "$ROOT/scripts/generate-readme.py"
python3 "$ROOT/scripts/check-docs.py"
echo 'Documentation export passed'
