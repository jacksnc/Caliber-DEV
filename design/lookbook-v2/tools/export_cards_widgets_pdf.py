#!/usr/bin/env python3
"""Create the reviewed five-page phone-card and widget design addendum."""
from pathlib import Path
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph


ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "output" / "pdf" / "Caliber-Cards-and-Widgets-Lookbook.pdf"
W, H = 1190, 842

INK = HexColor("#F5F7FA")
MUTED = HexColor("#C4CAD4")
QUIET = HexColor("#8792A2")
BLUE = HexColor("#8AD0FF")
DARK = HexColor("#0A0B0E")
DARK_CARD = HexColor("#212327")
DARK_RAISED = HexColor("#282A2E")
LIGHT = HexColor("#F1F4F8")
LIGHT_INK = HexColor("#172335")
LIGHT_MUTED = HexColor("#53647B")
LIGHT_BLUE = HexColor("#0868B8")
LIGHT_CARD = HexColor("#FFFFFF")
LINE_D = HexColor("#555B66")
LINE_L = HexColor("#B9C4D1")


def bg(pdf, color):
    pdf.setFillColor(color)
    pdf.rect(0, 0, W, H, fill=1, stroke=0)


def box(pdf, x, y, w, h, fill, stroke=None, radius=18):
    pdf.setFillColor(fill)
    if stroke:
        pdf.setStrokeColor(stroke)
        pdf.setLineWidth(1)
    pdf.roundRect(x, y, w, h, radius, fill=1, stroke=bool(stroke))


def para(pdf, text, x, top, width, size=13, color=INK, leading=None, bold=False):
    style = ParagraphStyle(
        "copy", fontName="Helvetica-Bold" if bold else "Helvetica",
        fontSize=size, leading=leading or size * 1.42, textColor=color,
        alignment=TA_LEFT, spaceAfter=0, spaceBefore=0,
    )
    p = Paragraph(text, style)
    _, height = p.wrap(width, H)
    p.drawOn(pdf, x, top - height)
    return top - height


def label(pdf, text, x, y, size=10, color=MUTED, bold=False):
    pdf.setFillColor(color)
    pdf.setFont("Helvetica-Bold" if bold else "Helvetica", size)
    pdf.drawString(x, y, text)


def footer(pdf, page, dark=True):
    color = MUTED if dark else LIGHT_MUTED
    label(pdf, "CALIBER / ORIGINAL DESIGN / FICTIONAL SAMPLE DATA / NOVEMBER 2026", 46, 22, 8, color)
    label(pdf, str(page).zfill(2), W - 58, 22, 9, color, True)


def heading(pdf, number, title, subtitle, dark=True):
    primary = INK if dark else LIGHT_INK
    secondary = MUTED if dark else LIGHT_MUTED
    label(pdf, f"CALIBER / FIELD STUDY 03     {number}", 48, H - 44, 9, secondary, True)
    para(pdf, title, 48, H - 73, W - 96, 30, primary, 34, True)
    para(pdf, subtitle, 49, H - 116, W - 105, 13, secondary, 18)


def metric_widget(pdf, x, y, w, h, theme="dark", large=False, small=False):
    dark = theme == "dark"
    fill = DARK_CARD if dark else LIGHT_CARD
    text = INK if dark else LIGHT_INK
    muted = MUTED if dark else LIGHT_MUTED
    accent = BLUE if dark else LIGHT_BLUE
    stroke = LINE_D if dark else LINE_L
    box(pdf, x, y, w, h, fill, stroke, 18)
    label(pdf, "CALIBER  /  FUEL  /  TODAY", x + 18, y + h - 26, 8, muted, True)
    label(pdf, "1,462", x + 18, y + h - 77, 31 if not large else 26, text, True)
    label(pdf, "kcal logged", x + 19, y + h - 96, 10, muted)
    if large:
        rows = [("Breakfast", "420 cal"), ("Lunch", "650 cal"), ("Dinner", "0 cal"), ("Snacks", "392 cal")]
        row_top = y + h - 127
        for i, (name, value) in enumerate(rows):
            ry = row_top - i * 30
            pdf.setStrokeColor(stroke)
            pdf.line(x + 17, ry + 18, x + w - 17, ry + 18)
            label(pdf, name, x + 19, ry, 10, text)
            pdf.setFillColor(accent)
            pdf.setFont("Helvetica-Bold", 10)
            pdf.drawRightString(x + w - 20, ry, value)
    elif not small:
        for i, (title, value) in enumerate((("PROTEIN", "142 g"), ("CARBS", "118 g"), ("FAT", "52 g"))):
            col_w = (w - 42) / 3
            cx = x + 16 + i * (col_w + 5)
            box(pdf, cx, y + 16, col_w, 58, DARK_RAISED if dark else LIGHT, stroke, 10)
            label(pdf, title, cx + 8, y + 55, 7, muted, True)
            label(pdf, value, cx + 8, y + 31, 11, text, True)
    if small:
        label(pdf, "OPEN DIARY  >", x + 18, y + 17, 8, accent, True)
    elif not large:
        label(pdf, "OPEN DIARY  >", x + w - 104, y + h - 26, 8, accent, True)
    elif large:
        label(pdf, "OPEN DIARY  >", x + w - 104, y + 14, 8, accent, True)


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    pdf = canvas.Canvas(str(OUT), pagesize=(W, H), pageCompression=1)
    pdf.setTitle("Caliber - Cards and Widgets Lookbook")
    pdf.setAuthor("Caliber design collaboration")

    # Page 1: direction.
    bg(pdf, DARK)
    pdf.setFillColor(HexColor("#202D42"))
    pdf.ellipse(W - 360, H - 270, W + 50, H + 110, fill=1, stroke=0)
    label(pdf, "CALIBER / FIELD STUDY 03", 62, H - 76, 11, BLUE, True)
    para(pdf, "Cards and<br/>widgets", 62, H - 130, 640, 61, INK, 66, True)
    para(pdf, "Small surfaces. More signal.", 65, H - 295, 700, 25, MUTED, 31)
    para(pdf, "A swipeable daily nutrition summary and a family of iPhone widgets, extending the Graphite and Frost visual system.", 65, H - 352, 550, 17, MUTED, 24)
    box(pdf, 65, 160, 1060, 1, HexColor("#637085"), radius=0)
    para(pdf, "Design focus", 65, 139, 215, 12, BLUE, 16, True)
    para(pdf, "Recorded food values only. Labeled alternate controls. Private widget states. No new estimates, target math, shared data container, or dose content.", 65, 117, 730, 14, INK, 21)
    footer(pdf, 1)
    pdf.showPage()

    # Page 2: interactive card concept and updated meal heading.
    bg(pdf, LIGHT)
    heading(pdf, "01 / IN THE APP", "One card. Four views.", "A clearly labeled nutrition card can move between calories, protein, carbs and fat without moving the diary underneath it.", False)
    # Phone frame.
    box(pdf, 55, 54, 335, 603, HexColor("#DCE3EC"), HexColor("#98A7BA"), 30)
    box(pdf, 63, 62, 319, 587, LIGHT, None, 24)
    label(pdf, "9:41", 82, 624, 9, LIGHT_INK, True)
    label(pdf, "FUEL", 82, 598, 8, LIGHT_MUTED, True)
    label(pdf, "Diary", 82, 570, 21, LIGHT_INK, True)
    box(pdf, 324, 574, 42, 42, LIGHT_CARD, LINE_L, 21)
    label(pdf, "J", 340, 589, 12, LIGHT_INK, True)
    label(pdf, "Today  /  Friday, Oct 30", 128, 542, 9, LIGHT_MUTED)
    box(pdf, 78, 330, 289, 197, LIGHT_CARD, LINE_L, 17)
    label(pdf, "TODAY'S LOG", 96, 505, 8, LIGHT_MUTED, True)
    pdf.setFillColor(LIGHT_BLUE)
    pdf.circle(349, 502, 4, fill=1, stroke=0)
    label(pdf, "Calories", 178, 466, 11, LIGHT_MUTED)
    label(pdf, "1,462", 155, 415, 38, LIGHT_INK, True)
    label(pdf, "kcal recorded today", 151, 396, 10, LIGHT_MUTED)
    box(pdf, 93, 346, 42, 42, LIGHT, LINE_L, 21)
    box(pdf, 311, 346, 42, 42, LIGHT, LINE_L, 21)
    label(pdf, "<", 109, 359, 17, LIGHT_INK, True)
    label(pdf, ">", 327, 359, 17, LIGHT_INK, True)
    label(pdf, "01  /  04", 180, 363, 8, LIGHT_MUTED, True)
    label(pdf, "Swipe or use the arrows", 161, 333, 8, LIGHT_MUTED)
    box(pdf, 78, 168, 289, 146, LIGHT_CARD, LINE_L, 17)
    pdf.setFillColor(LIGHT_INK)
    pdf.setFont("Helvetica-Bold", 15)
    pdf.drawCentredString(222.5, 286, "Breakfast")
    pdf.setFillColor(LIGHT_MUTED)
    pdf.setFont("Helvetica", 9)
    pdf.drawCentredString(222.5, 269, "1 food  /  420 cal")
    box(pdf, 137, 226, 64, 30, LIGHT, LINE_L, 9)
    box(pdf, 206, 226, 102, 30, LIGHT_BLUE, None, 9)
    pdf.setFillColor(LIGHT_INK)
    pdf.setFont("Helvetica-Bold", 9)
    pdf.drawCentredString(169, 237, "Copy")
    pdf.setFillColor(HexColor("#06131F"))
    pdf.drawCentredString(257, 237, "+ Add food")
    pdf.setStrokeColor(LINE_L)
    pdf.line(96, 217, 349, 217)
    label(pdf, "Fictional oats and berries", 96, 194, 9, LIGHT_INK)
    label(pdf, "420 cal", 298, 194, 9, LIGHT_INK, True)
    # Right-side paging order and guarantees.
    x = 440
    label(pdf, "CARD ORDER", x, 607, 9, LIGHT_BLUE, True)
    rows = [("01", "Calories", "1,462 kcal"), ("02", "Protein", "142 g"), ("03", "Carbs", "118 g"), ("04", "Fat", "52 g")]
    for i, (num, name, value) in enumerate(rows):
        y = 561 - i * 51
        box(pdf, x, y - 12, 600, 42, LIGHT_CARD, LINE_L, 11)
        label(pdf, num, x + 14, y + 3, 9, LIGHT_BLUE, True)
        label(pdf, name, x + 61, y + 3, 12, LIGHT_INK, True)
        pdf.setFillColor(LIGHT_MUTED)
        pdf.setFont("Helvetica", 11)
        pdf.drawRightString(x + 580, y + 3, value)
    para(pdf, "The swipe stays inside the daily summary. Large previous/next controls and a page count keep the change discoverable; food rows keep their native edit and delete gestures.", x, 332, 595, 12, LIGHT_MUTED, 18)
    para(pdf, "Metric order reads as logged energy first, followed by the three logged macros. If a value is unavailable, show an em dash and a clear 'not recorded' label rather than a fabricated zero.", x, 243, 595, 12, LIGHT_MUTED, 18)
    footer(pdf, 2, False)
    pdf.showPage()

    # Page 3: small and medium widgets, both themes.
    bg(pdf, DARK)
    heading(pdf, "02 / SMALL + MEDIUM", "Choose the useful amount of detail.", "The same nutrition snapshot adapts to the space. The larger layout adds macros; it does not stretch a small layout.", True)
    label(pdf, "GRAPHITE", 70, 613, 9, BLUE, True)
    metric_widget(pdf, 70, 295, 280, 280, "dark", small=True)
    label(pdf, "FROST", 400, 613, 9, LIGHT_BLUE, True)
    metric_widget(pdf, 400, 295, 280, 280, "light", small=True)
    para(pdf, "SMALL / One logged daily total. A single clear tap opens the Diary.", 70, 275, 280, 11, MUTED, 16, True)
    label(pdf, "MEDIUM", 70, 216, 9, BLUE, True)
    metric_widget(pdf, 55, 52, 520, 192, "dark")
    metric_widget(pdf, 615, 52, 520, 192, "light")
    label(pdf, "Graphite", 70, 36, 8, MUTED)
    label(pdf, "Frost", 600, 36, 8, MUTED)
    footer(pdf, 3)
    pdf.showPage()

    # Page 4: large and locked previews.
    bg(pdf, LIGHT)
    heading(pdf, "03 / LARGE + PRIVACY", "Details appear by choice.", "Large widgets can add a meal-by-meal snapshot. A system privacy-redacted state keeps personal numbers out of view when settings require it.", False)
    label(pdf, "LARGE / FROST", 65, 604, 9, LIGHT_BLUE, True)
    metric_widget(pdf, 65, 300, 660, 265, "light", large=True)
    label(pdf, "LOCKED PREVIEW", 765, 604, 9, LIGHT_BLUE, True)
    box(pdf, 765, 300, 360, 265, LIGHT_CARD, LINE_L, 20)
    box(pdf, 782, 317, 326, 231, LIGHT, None, 16)
    label(pdf, "CALIBER / FUEL", 805, 515, 9, LIGHT_MUTED, True)
    label(pdf, "Your diary is private", 805, 477, 19, LIGHT_INK, True)
    para(pdf, "WidgetKit marks nutrition as sensitive. The person controls whether values appear while locked.", 805, 448, 275, 11, LIGHT_MUTED, 16)
    box(pdf, 805, 337, 170, 43, LIGHT_BLUE, None, 13)
    pdf.setFillColor(HexColor("#06131F"))
    pdf.setFont("Helvetica-Bold", 11)
    pdf.drawCentredString(890, 353, "Open Fuel")
    para(pdf, "The preview uses synthetic values and is a visual proposal. A shipped widget still needs a reviewed opt-in, data-sharing contract, protected snapshot, expiry rules, and tests around midnight and stale data.", 66, 257, 1050, 12, LIGHT_MUTED, 18)
    label(pdf, "NO STACK DETAILS   /   NO WEIGHT OR PHOTO   /   NO WIDGET-SIDE FOOD SAVE IN THIS STUDY", 66, 167, 9, LIGHT_BLUE, True)
    footer(pdf, 4, False)
    pdf.showPage()

    # Page 5: handoff rules and platform source links.
    bg(pdf, DARK)
    heading(pdf, "04 / IMPLEMENTATION NOTES", "Design direction, not a shipped widget.", "The prototype demonstrates hierarchy and states. Native work starts only after the local data boundary and user privacy choices are reviewed.", True)
    notes = [
        ("Swipe behavior", "Page only the logged calorie/protein/carbs/fat summary. Provide labeled previous/next controls, page position, keyboard and VoiceOver alternatives. Disable autoplay and honor Reduce Motion."),
        ("Widget behavior", "Small emphasizes one daily total, medium adds macro rows, large can show four meal totals. A tap opens the related Fuel screen; direct food logging is not part of this study."),
        ("Privacy boundary", "Widget content can be visible outside the unlocked app. Use WidgetKit sensitive-content redaction and a user-reviewed sharing boundary; Stack compounds, amounts, schedules and photos stay excluded."),
        ("Update behavior", "Refresh after a successful local save and use a timeline for known changes. WidgetKit schedules refreshes within a dynamic budget, so design honest stale-data language."),
    ]
    left_x, right_x = 58, 608
    for i, (title, body) in enumerate(notes):
        x = left_x if i < 2 else right_x
        y = 578 - (i % 2) * 177
        label(pdf, f"0{i + 1} / {title.upper()}", x, y, 9, BLUE, True)
        para(pdf, body, x, y - 18, 470, 13, INK, 19)
    pdf.setStrokeColor(HexColor("#637085"))
    pdf.line(58, 191, W - 58, 191)
    label(pdf, "APPLE PLATFORM REFERENCES", 58, 169, 9, BLUE, True)
    refs = [
        ("Human Interface Guidelines / Widgets", "https://developer.apple.com/design/human-interface-guidelines/widgets"),
        ("WidgetKit / WidgetFamily", "https://developer.apple.com/documentation/widgetkit/widgetfamily"),
        ("WidgetKit / Keeping a widget up to date", "https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date"),
        ("WidgetKit / Creating a widget extension", "https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension"),
    ]
    for i, (title, url) in enumerate(refs):
        col = 0 if i < 2 else 1
        row = i % 2
        x = left_x if col == 0 else right_x
        y = 143 - row * 27
        label(pdf, title, x, y, 8, MUTED)
        label(pdf, url, x, y - 11, 8, BLUE)
    footer(pdf, 5)
    pdf.save()
    print(OUT)


if __name__ == "__main__":
    main()
