#!/usr/bin/env python3
"""Fail if generated PDFs or README preview links are incomplete or invalid."""
from pathlib import Path
import re
import subprocess
import sys
ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / 'docs/pdf'
IMG = ROOT / 'docs/images'
README = ROOT / 'README.md'
NAMES = ('schematic', 'pcb-front', 'pcb-back', 'pcb-layers')
errors = []
for name in NAMES:
    path = PDF / f'{name}.pdf'
    if not path.is_file() or path.stat().st_size == 0:
        errors.append(f'Missing/empty PDF: {path}')
        continue
    result = subprocess.run(['pdfinfo', str(path)], text=True, capture_output=True)
    match = re.search(r'^Pages:\s+(\d+)', result.stdout, re.M)
    if result.returncode or not match or int(match.group(1)) < 1:
        errors.append(f'Unreadable PDF: {path}')
        continue
    count = int(match.group(1))
    for n in range(1, count + 1):
        image = IMG / f'{name}-{n:03d}.png'
        if not image.is_file() or image.stat().st_size == 0:
            errors.append(f'Missing preview: {image}')
    print(f'{name}.pdf: {count} page(s)')
if not README.is_file():
    errors.append('README.md missing')
else:
    body = README.read_text(encoding='utf-8')
    match = re.search(r'<!-- AUTO-DOCS-START -->(.*?)<!-- AUTO-DOCS-END -->', body, re.S)
    if not match:
        errors.append('README generated section missing')
    else:
        block = match.group(1)
        for link in re.findall(r'!?(?:\[[^\]]*\])\(([^)]+)\)', block):
            if not link.startswith(('https://', 'http://', '#')) and not (ROOT / link).is_file():
                errors.append(f'Broken README link: {link}')
        if '/sheets/' in block or 'sheet-' in block:
            errors.append('Unused draft schematic sheets included')
if errors:
    for error in errors:
        print('ERROR:', error, file=sys.stderr)
    sys.exit(1)
print('Documentation validation passed')
