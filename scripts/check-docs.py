#!/usr/bin/env python3
"""Validate generated PDF files and README preview links before Git push."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
pdf_dir = root / 'docs' / 'pdf'
readme = root / 'README.md'
required = ['schematic.pdf', 'pcb-front.pdf', 'pcb-back.pdf', 'pcb-layers.pdf']

errors = []
for filename in required:
    path = pdf_dir / filename
    if not path.is_file() or path.stat().st_size == 0:
        errors.append(f'Missing or empty PDF: {path}')
        continue
    result = subprocess.run(['pdfinfo', str(path)], capture_output=True, text=True)
    match = re.search(r'^Pages:\s+(\d+)', result.stdout, re.M)
    if result.returncode or not match:
        errors.append(f'Invalid PDF: {path}')
        continue
    pages = int(match.group(1))
    prefix = filename.removesuffix('.pdf')
    for index in range(1, pages + 1):
        image = root / 'docs' / 'images' / f'{prefix}-{index:03d}.png'
        if not image.is_file() or image.stat().st_size == 0:
            errors.append(f'Missing image for {filename} page {index}: {image}')
    print(f'{filename}: {pages} page(s)')

if not readme.is_file():
    errors.append('README.md is missing')
else:
    content = readme.read_text(encoding='utf-8')
    match = re.search(r'<!-- AUTO-DOCS-START -->(.*?)<!-- AUTO-DOCS-END -->', content, re.S)
    if not match:
        errors.append('README is missing AUTO-DOCS markers')
    else:
        block = match.group(1)
        for rel in re.findall(r'!\[[^\]]*\]\(([^)]+)\)|\[[^\]]*\]\(([^)]+)\)', block):
            target = rel[0] or rel[1]
            if target.startswith(('http://', 'https://', '#')):
                continue
            if not (root / target).is_file():
                errors.append(f'Broken README link: {target}')
        if '/sheets/' in block or 'sheet-' in block:
            errors.append('Unused independent schematic sheets still shown in README')

if errors:
    print('\n'.join('ERROR: ' + e for e in errors), file=sys.stderr)
    sys.exit(1)
print('Documentation validation passed')
