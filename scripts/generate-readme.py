#!/usr/bin/env python3
"""Update the generated README section and create cropped PNGs from PDF pages."""
from pathlib import Path
import re
import subprocess
from PIL import Image, ImageChops, ImageOps

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / 'docs/pdf'
IMAGES = ROOT / 'docs/images'
README = ROOT / 'README.md'
START = '<!-- AUTO-DOCS-START -->'
END = '<!-- AUTO-DOCS-END -->'
IMAGES.mkdir(parents=True, exist_ok=True)


def pages(path):
    text = subprocess.check_output(['pdfinfo', str(path)], text=True)
    result = re.search(r'^Pages:\s+(\d+)', text, re.M)
    if not result or int(result.group(1)) < 1:
        raise ValueError(f'Invalid PDF page count: {path}')
    return int(result.group(1))


def render(pdf, page, prefix):
    target_prefix = IMAGES / f'{prefix}-{page:03d}'
    subprocess.run(['pdftoppm', '-f', str(page), '-l', str(page), '-singlefile',
                    '-r', '180', '-png', str(pdf), str(target_prefix)], check=True)
    target = target_prefix.with_suffix('.png')
    with Image.open(target) as loaded:
        im = loaded.convert('RGB')
    delta = ImageChops.difference(im, Image.new('RGB', im.size, 'white'))
    mask = delta.convert('L').point(lambda v: 255 if v > 15 else 0)
    rect = mask.getbbox()
    if rect:
        im = im.crop(rect)
    im = ImageOps.expand(im, border=28, fill='white')
    if im.width > 2400:
        im = im.resize((2400, round(im.height * 2400 / im.width)), Image.Resampling.LANCZOS)
    im.save(target, optimize=True)
    return target.relative_to(ROOT).as_posix()


def section(lines, filename, title):
    pdf = PDF / filename
    count = pages(pdf)
    prefix = pdf.stem
    lines.extend([f'### {title}', ''])
    for page in range(1, count + 1):
        img = render(pdf, page, prefix)
        lines.extend([f'**Page {page}**', '', f'![{title} — page {page}]({img})', ''])
    lines.extend([f'[View vector PDF]({pdf.relative_to(ROOT).as_posix()})', ''])


def main():
    for stale in IMAGES.glob('*.png'):
        if stale.name.startswith(('schematic-', 'sheet-', 'pcb-')):
            stale.unlink()
    lines = ['## Schematic documentation', '']
    section(lines, 'schematic.pdf', 'Complete active hierarchical schematic')
    lines.extend(['## PCB documentation', ''])
    section(lines, 'pcb-front.pdf', 'PCB front')
    section(lines, 'pcb-back.pdf', 'PCB back')
    section(lines, 'pcb-layers.pdf', 'Individual PCB layers')
    generated = f'{START}\n' + '\n'.join(lines).rstrip() + f'\n{END}'
    if README.exists():
        data = README.read_text(encoding='utf-8')
    else:
        data = '# KiCad hardware project\n\nWork in progress. Not validated for production or mains safety.\n'
    if START in data and END in data and data.index(START) < data.index(END):
        data = re.sub(re.escape(START) + r'.*?' + re.escape(END),
                      lambda _: generated, data, flags=re.S)
    elif START in data or END in data:
        raise ValueError('README has inconsistent AUTO-DOCS markers')
    else:
        data = data.rstrip() + '\n\n' + generated + '\n'
    # Keep generated output compatible with the pusher's staged whitespace check.
    # Normalize the whole file because hand-maintained text surrounds the gallery.
    data = '\n'.join(line.rstrip() for line in data.splitlines()) + '\n'
    README.write_text(data, encoding='utf-8')
    print('README gallery updated')


if __name__ == '__main__':
    main()
