
#!/usr/bin/env python3
"""Generate cropped PDF previews and README gallery."""

from pathlib import Path
import re
import subprocess

from PIL import Image, ImageChops, ImageOps

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / "docs/pdf"
IMAGES = ROOT / "docs/images"
README = ROOT / "README.md"

START = "<!-- AUTO-DOCS-START -->"
END = "<!-- AUTO-DOCS-END -->"

DPI = 180
MAX_WIDTH = 2400
PADDING = 32

IMAGES.mkdir(parents=True, exist_ok=True)


def pdf_pages(path):
    """Read the number of pages in a PDF."""
    result = subprocess.check_output(
        ["pdfinfo", str(path)], text=True
    )
    match = re.search(r"^Pages:\s+(\d+)", result, re.M)
    if not match:
        raise RuntimeError(f"Cannot read pages: {path}")
    return int(match.group(1))


def preview(pdf, page, name):
    """Render one PDF page and trim its white margins."""
    prefix = IMAGES / name

    subprocess.run(
        [
            "pdftoppm",
            "-f", str(page),
            "-l", str(page),
            "-singlefile",
            "-r", str(DPI),
            "-png",
            str(pdf),
            str(prefix),
        ],
        check=True,
    )

    target = prefix.with_suffix(".png")

    with Image.open(target) as source:
        image = source.convert("RGB")

    # Detect non-white pixels
    background = Image.new("RGB", image.size, "white")
    difference = ImageChops.difference(image, background)

    # Ignore near-white compression / rendering noise
    mask = difference.convert("L").point(
        lambda value: 255 if value > 15 else 0
    )

    bounds = mask.getbbox()

    if bounds:
        image = image.crop(bounds)

    # Small consistent border around the content
    image = ImageOps.expand(
        image, border=PADDING, fill="white"
    )

    if image.width > MAX_WIDTH:
        new_height = round(
            image.height * MAX_WIDTH / image.width
        )
        image = image.resize(
            (MAX_WIDTH, new_height),
            Image.Resampling.LANCZOS,
        )

    image.save(target, optimize=True)
    return target.relative_to(ROOT).as_posix()


def add_pdf(lines, pdf, title, prefix):
    """Add every PDF page to the README."""
    if not pdf.exists():
        return

    relative_pdf = pdf.relative_to(ROOT).as_posix()
    count = pdf_pages(pdf)

    lines.append(f"### {title}")
    lines.append("")

    for page in range(1, count + 1):
        image_name = f"{prefix}-{page:03d}"
        img = preview(pdf, page, image_name)

        lines.append(f"**Page {page}**")
        lines.append("")
        lines.append(f"![{title} page {page}]({img})")
        lines.append("")

    lines.append(f"[View vector PDF]({relative_pdf})")
    lines.append("")


def main():
    # Remove old generated previews
    for old in IMAGES.glob("*.png"):
        if old.name.startswith(("schematic-", "sheet-", "pcb-")):
            old.unlink()

    lines = [
        "## Schematic Documentation",
        "",
    ]

    # Complete project
    add_pdf(
        lines,
        PDF / "schematic.pdf",
        "Complete Hierarchical Schematic",
        "schematic",
    )

    # Discover every individually exported sheet
    for index, file in enumerate(
        sorted((PDF / "sheets").rglob("*.pdf")), 1
    ):
        name = file.relative_to(PDF / "sheets")
        title = name.with_suffix("").as_posix()

        add_pdf(
            lines,
            file,
            title,
            f"sheet-{index:03d}",
        )

    lines += [
        "## PCB Documentation",
        "",
    ]

    add_pdf(
        lines,
        PDF / "pcb-front.pdf",
        "PCB Front",
        "pcb-front",
    )
    add_pdf(
        lines,
        PDF / "pcb-back.pdf",
        "PCB Back",
        "pcb-back",
    )

    add_pdf(
        lines,
        PDF / "pcb-layers.pdf",
        "Individual PCB Layers",
        "pcb-layers",
    )

    generated = "\n".join(lines).rstrip()

    if README.exists():
        content = README.read_text(encoding="utf-8")
    else:
        content = (
            "# IOT_LC_PROTOTYPE_V1\n\n"
            "Modular IoT controller — KiCad hardware project.\n\n"
            "Work in progress. Not validated for mains safety.\n\n"
        )

    block = f"{START}\n{generated}\n{END}"

    if START in content and END in content:
        pattern = (
            re.escape(START)
            + r".*?"
            + re.escape(END)
        )
        content = re.sub(
            pattern, lambda _: block, content, flags=re.S
        )
    else:
        content = content.rstrip() + "\n\n" + block + "\n"

    README.write_text(content, encoding="utf-8")
    print(f"Updated: {README}")


if __name__ == "__main__":
    main()
