
#!/usr/bin/env bash
set -Eeuo pipefail

# Project configuration
PROJECT="IOT_LC_PROTOTYPE_V1"

# Resolve project root relative to this script
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/pdf"

SCHEMATIC="$ROOT/$PROJECT.kicad_sch"
PCB="$ROOT/$PROJECT.kicad_pcb"

# Validate dependencies
command -v kicad-cli >/dev/null || {
    echo "ERROR: kicad-cli is not installed"
    exit 1
}

[[ -f "$SCHEMATIC" ]] || {
    echo "ERROR: Schematic not found: $SCHEMATIC"
    exit 1
}

[[ -f "$PCB" ]] || {
    echo "ERROR: PCB not found: $PCB"
    exit 1
}

mkdir -p "$OUT"

echo "KiCad version: $(kicad-cli version)"
echo "Output directory: $OUT"

# 1. Complete hierarchical schematic
echo "[1/4] Exporting schematic..."

kicad-cli sch export pdf \
    --no-background-color \
    -o "$OUT/schematic.pdf" \
    "$SCHEMATIC"

# 2. Front PCB view
echo "[2/4] Exporting front PCB..."

kicad-cli pcb export pdf \
    --mode-single \
    --layers "F.Cu,F.SilkS,Edge.Cuts" \
    -o "$OUT/pcb-front.pdf" \
    "$PCB"

# 3. Back PCB view
echo "[3/4] Exporting back PCB..."

kicad-cli pcb export pdf \
    --mode-single \
    --layers "B.Cu,B.SilkS,Edge.Cuts" \
    -o "$OUT/pcb-back.pdf" \
    "$PCB"

# 4. Individual PCB layers
echo "[4/4] Exporting individual PCB layers..."

kicad-cli pcb export pdf \
    --mode-multipage \
    --layers "F.Cu,B.Cu,F.SilkS,B.SilkS,Edge.Cuts" \
    --common-layers "Edge.Cuts" \
    -o "$OUT/pcb-layers.pdf" \
    "$PCB"

echo
echo "Export completed:"
ls -lh "$OUT"/*.pdf
