#!/usr/bin/env python3
"""Export reviewed source captures as complete, readable theme-comparison spreads.

Run with bundled Python: python3 design/lookbook-v2/tools/export_pdf.py
Requires evidence/{screen}-{graphite|frost}-390.jpg from the rendered boards.
Variable-height spreads preserve complete scrollable screens without clipping.
"""
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader

ROOT = Path(__file__).resolve().parents[3]
DESIGN = ROOT / 'design' / 'lookbook-v2'
OUTPUT = ROOT / 'output' / 'pdf' / 'Caliber-Lookbook-V2.pdf'
BOARDS = [
    ('diary', 'Fuel / Diary', 'One calm overview.', 'A centered energy summary, equal macro columns and meal cards that keep food names easy to scan.'),
    ('today', 'Today', 'Your next action, clear.', 'Nutrition, training and check-ins share one daily view. The hierarchy starts with the next useful action.'),
    ('train', 'Train', 'Built for the next set.', 'Saved workout context, readable set rows and generous controls. No invented training prescription.'),
    ('stack', 'Stack', 'Private by default.', 'A discreet logbook with explicit locked and opted-out states. This design does not enable a dosage calculator.'),
    ('progress', 'Progress', 'Change over time.', 'A readable weight trend with a check-in timeline for photos and notes. Patterns do not imply causation.'),
    ('food-entry', 'Add food', 'A shorter path to logging.', 'Search, capture and reusable foods together. Exact source and meal context stay visible at review.'),
    ('food-review', 'Review food', 'You stay in control.', 'Portions and reported calories/macros remain editable. Preview controls do not persist any records.'),
]


def text_block(pdf, text, x, y, width, size=14, color='#41536B'):
    from reportlab.pdfbase.pdfmetrics import stringWidth
    pdf.setFillColor(HexColor(color)); pdf.setFont('Helvetica', size)
    words = text.split(); line = ''
    for word in words:
        test = f'{line} {word}'.strip()
        if stringWidth(test, 'Helvetica', size) > width and line:
            pdf.drawString(x, y, line); y -= size * 1.5; line = word
        else:
            line = test
    if line:
        pdf.drawString(x, y, line); y -= size * 1.5
    return y


def footer(pdf, width, page):
    pdf.setFillColor(HexColor('#41536B')); pdf.setFont('Helvetica', 11)
    pdf.drawString(48, 30, 'CALIBER / V2   -   Original design, fictional data   -   October 2026')
    pdf.drawRightString(width - 48, 30, str(page))


def main():
    captures = {}
    for key, *_ in BOARDS:
        for theme in ('graphite', 'frost'):
            path = DESIGN / 'evidence' / f'{key}-{theme}-390.jpg'
            if not path.is_file():
                raise SystemExit(f'Missing reviewed board capture: {path}')
            captures[key, theme] = ImageReader(str(path))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    width = 1190
    pdf = canvas.Canvas(str(OUTPUT), pagesize=(width, 842), pageCompression=1)
    pdf.setTitle('Caliber - Lookbook V2'); pdf.setAuthor('Caliber design collaboration')
    pdf.setFillColor(HexColor('#0A0B0E')); pdf.rect(0, 0, width, 842, fill=1, stroke=0)
    pdf.setFillColor(HexColor('#C4CAD4')); pdf.setFont('Helvetica', 13)
    pdf.drawString(64, 760, 'CALIBER / VISUAL DIRECTION 02')
    pdf.setFillColor(HexColor('#F5F7FA')); pdf.setFont('Helvetica-Bold', 64)
    pdf.drawString(60, 620, 'A clearer view')
    pdf.drawString(60, 546, 'of your whole day.')
    text_block(pdf, 'Graphite depth. Frost clarity. One considered system for food, training, body and your private logbook.', 64, 454, 700, 24, '#C4CAD4')
    pdf.setStrokeColor(HexColor('#637085')); pdf.line(64, 320, 1126, 320)
    text_block(pdf, 'Design checkpoint: full-screen theme comparisons. Complete scrollable boards are preserved on tall spreads so content stays readable without cropping.', 64, 270, 460, 16, '#C4CAD4')
    text_block(pdf, 'Next: native iPhone implementation and verification, then iPad/resizing layouts and broader light-mode beta. This book does not certify native accessibility, clinical accuracy or release readiness.', 650, 270, 460, 16, '#C4CAD4')
    pdf.setFont('Helvetica', 11); pdf.setFillColor(HexColor('#C4CAD4'))
    pdf.drawString(64, 55, 'Original work / synthetic fixtures / no installed-app changes at this checkpoint')
    pdf.showPage()
    image_width = 350
    for page, (key, title, headline, description) in enumerate(BOARDS, start=2):
        images = [captures[key, t] for t in ('graphite', 'frost')]
        heights = [img.getSize()[1] * image_width / img.getSize()[0] for img in images]
        height = max(842, max(heights) + 190)
        pdf.setPageSize((width, height))
        pdf.setFillColor(HexColor('#F1F4F8')); pdf.rect(0, 0, width, height, fill=1, stroke=0)
        pdf.setFillColor(HexColor('#41536B')); pdf.setFont('Helvetica', 12)
        pdf.drawString(48, height - 54, f'CALIBER / {title.upper()}')
        pdf.setFillColor(HexColor('#172335')); pdf.setFont('Helvetica-Bold', 25)
        y = text_block(pdf, headline, 48, height - 126, 220, 24, '#172335')
        text_block(pdf, description, 48, y - 20, 220, 15)
        text_block(pdf, 'Rendered at 390 CSS px. Fictional data. Preview actions do not save.', 48, y - 165, 220, 12)
        for x, theme, img, ih in zip((350, 750), ('Graphite', 'Frost'), images, heights):
            pdf.setFillColor(HexColor('#172335')); pdf.setFont('Helvetica-Bold', 17)
            pdf.drawString(x, height - 82, theme)
            pdf.drawImage(img, x, height - 108 - ih, width=image_width, height=ih)
        footer(pdf, width, page); pdf.showPage()
    pdf.save()
    print(OUTPUT)


if __name__ == '__main__':
    main()
