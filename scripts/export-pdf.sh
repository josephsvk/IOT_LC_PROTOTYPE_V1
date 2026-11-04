#!/usr/bin/env bash
# ============================================================
# KiCad Documentation Export
# ============================================================
# Generates vector PDFs and PNG previews for GitHub README.
#
# Outputs:
#   docs/pdf/schematic.pdf
#   docs/pdf/pcb-front.pdf
#   docs/pdf/pcb-back.pdf
#   docs/pdf/pcb-layers.pdf
#
#   docs/images/schematic.png
#   docs/images/pcb-front.png
#   docs/images/pcb-back.png
#
# Requirements:
#   - KiCad CLI 10
#   - poppler-utils (pdftoppm)
#
# Usage:
#   ./scripts/export-pdf.sh
# ============================================================

set -Eeuo pipefail

PROJECT="IOT_LC_PROTOTYPE_V1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PDF_DIR="$ROOT/docs/pdf"
IMG_DIR="$ROOT/docs/images"

SCH="$ROOT/$PROJECT.kicad_sch"
PCB="$ROOT/$PROJECT.kicad_pcb"

# Verify dependencies and project files
for CMD in kicad-cli pdftoppm; do
    command -v "$CMD" >/dev/null || {
        echo "Missing dependency: $CMD"
        exit 1
    }
done

[[ -f "$SCH" && -f "$PCB" ]] || {
    echo "KiCad project files not found"
    exit 1
}

mkdir -p "$PDF_DIR" "$IMG_DIR"

echo "KiCad: $(kicad-cli version)"

# 1. Complete hierarchical schematic PDF
echo "[1/5] Schematic PDF"

kicad-cli sch export pdf \
    --no-background-color \
    -o "$PDF_DIR/schematic.pdf" \
    "$SCH"

# 2. PCB front view
echo "[2/5] PCB front PDF"

kicad-cli pcb export pdf \
    --mode-single \
    --layers "F.Cu,F.SilkS,Edge.Cuts" \
    --check-zones \
    -o "$PDF_DIR/pcb-front.pdf" \
    "$PCB"

# 3. PCB back view
echo "[3/5] PCB back PDF"

kicad-cli pcb export pdf \
    --mode-single \
    --layers "B.Cu,B.SilkS,Edge.Cuts" \
    --check-zones \
    -o "$PDF_DIR/pcb-back.pdf" \
    "$PCB"

# 4. Separate PCB layers in one PDF
echo "[4/5] PCB multilayer PDF"

kicad-cli pcb export pdf \
    --mode-multipage \
    --layers "F.Cu,B.Cu,F.SilkS,B.SilkS" \
    --common-layers "Edge.Cuts" \
    --check-zones \
    -o "$PDF_DIR/pcb-layers.pdf" \
    "$PCB"

# 5. Render first PDF page as a PNG preview
echo "[5/5] PNG previews"

for NAME in schematic pcb-front pcb-back; do
    pdftoppm \
        -f 1 \
        -l 1 \
        -singlefile \
        -png \
        -r 150 \
        -scale-to 2400 \
        "$PDF_DIR/$NAME.pdf" \
        "$IMG_DIR/$NAME"
done

echo "Documentation export completed"
ls -lh "$PDF_DIR"/*.pdf "$IMG_DIR"/*.png
