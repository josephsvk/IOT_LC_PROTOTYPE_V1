
#!/usr/bin/env bash
# KiCad documentation generator
#
# Exports:
#   - Complete hierarchical schematic PDF
#   - Individual schematic file PDFs
#   - Front and back PCB PDFs
#   - Multi-page PCB layer PDF
#   - Cropped PNG previews
#   - Dynamic README gallery
#
# Usage: ./scripts/export-pdf.sh

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="IOT_LC_PROTOTYPE_V1"
PDF_DIR="$ROOT/docs/pdf"
SCH_DIR="$PDF_DIR/sheets"
IMG_DIR="$ROOT/docs/images"

for cmd in kicad-cli pdftoppm pdfinfo python3; do
    command -v "$cmd" >/dev/null || {
        echo "Missing dependency: $cmd"
        exit 1
    }
done

python3 -c "from PIL import Image" || {
    echo "Install python3-pil"
    exit 1
}

mkdir -p "$SCH_DIR" "$IMG_DIR"

# Main hierarchical schematic
echo "[1/4] Complete schematic"

kicad-cli sch export pdf \
    --no-background-color \
    -o "$PDF_DIR/schematic.pdf" \
    "$ROOT/$PROJECT.kicad_sch"

# Each schematic source file independently
echo "[2/4] Individual schematic files"

find "$ROOT" \
    \( -name .git -o -name .history \
       -o -name docs -o -name production \
       -o -name '*-backups' \
       -o -name '_restore_backup_*' \) -prune -o \
    -name '*.kicad_sch' -type f -print0 |
while IFS= read -r -d '' file; do
    relative="${file#"$ROOT"/}"
    output="$SCH_DIR/${relative%.kicad_sch}.pdf"

    mkdir -p "$(dirname "$output")"

    echo "Exporting $relative"

    if ! kicad-cli sch export pdf \
        --no-background-color \
        -o "$output" \
        "$file"; then
        echo "WARNING: Could not export $relative" >&2
        rm -f "$output"
    fi
done

# PCB export
echo "[3/4] PCB documentation"

PCB="$ROOT/$PROJECT.kicad_pcb"

kicad-cli pcb export pdf \
    --mode-single \
    --layers "F.Cu,F.SilkS,Edge.Cuts" \
    --check-zones \
    -o "$PDF_DIR/pcb-front.pdf" "$PCB"

kicad-cli pcb export pdf \
    --mode-single \
    --layers "B.Cu,B.SilkS,Edge.Cuts" \
    --check-zones \
    -o "$PDF_DIR/pcb-back.pdf" "$PCB"

kicad-cli pcb export pdf \
    --mode-multipage \
    --layers "F.Cu,B.Cu,F.SilkS,B.SilkS" \
    --common-layers "Edge.Cuts" \
    --check-zones \
    -o "$PDF_DIR/pcb-layers.pdf" "$PCB"

# Generate images and README
echo "[4/4] README gallery"

python3 "$ROOT/scripts/generate-readme.py"

echo "Documentation generated successfully."

