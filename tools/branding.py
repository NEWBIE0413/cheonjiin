"""천지in 브랜딩 이미지: 앱 아이콘과 앱스토어 스크린샷(6.9", 1290x2796).

    python3 tools/branding.py

키보드 그림은 실제 키보드(Keyboard/KeyboardView.swift)의 배치·색·비율을 그대로 옮겨 그린다.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "branding"
FONT_DIR = Path.home() / "Library/Fonts"

CREAM = (246, 244, 241)
INK = (28, 28, 30)
GRAY = (110, 110, 116)
PINK = (242, 115, 128)  # warmPink — ㆍ(하늘)에만 쓴다
PANEL = (225, 226, 231)
KEY = (243, 243, 245)
WHITE = (255, 255, 255)

SS = 2  # 슈퍼샘플링 배율


def font(weight: str, size: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / f"Pretendard-{weight}.otf"), int(size * SS))


def canvas(w: int, h: int, color=CREAM) -> Image.Image:
    return Image.new("RGB", (w * SS, h * SS), color)


def finish(img: Image.Image) -> Image.Image:
    return img.resize((img.width // SS, img.height // SS), Image.LANCZOS)


def strokes(d: ImageDraw.ImageDraw, cx: float, cy: float, scale: float, ink=INK, dot=PINK):
    """로고: ㅣ ㆍ ㅡ 를 한 줄로. scale=1이면 1024 아이콘 크기."""
    s = scale * SS
    t = 44 * s  # 획 굵기
    bar_h, dot_d, eu_w, gap = 360 * s, 96 * s, 280 * s, 110 * s
    total = t + gap + dot_d + gap + eu_w
    x = cx - total / 2
    d.rounded_rectangle([x, cy - bar_h / 2, x + t, cy + bar_h / 2], radius=t / 2, fill=ink)
    x += t + gap
    d.ellipse([x, cy - dot_d / 2, x + dot_d, cy + dot_d / 2], fill=dot)
    x += dot_d + gap
    d.rounded_rectangle([x, cy - t / 2, x + eu_w, cy + t / 2], radius=t / 2, fill=ink)


def make_icon() -> Image.Image:
    img = canvas(1024, 1024)
    strokes(ImageDraw.Draw(img), 512 * SS, 512 * SS, 1.0)
    return finish(img)


# MARK: 키보드 그림

def key_label(d, rect, content, s):
    x0, y0, x1, y1 = rect
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    kind, value = content
    lw = max(2, 1.6 * s)
    if kind == "text":
        text, size = value
        f = font("Regular", size * s / SS)
        d.text((cx, cy), text, font=f, fill=INK, anchor="mm")
    elif kind == "vowel":
        if value == "i":
            d.rectangle([cx - 0.65 * s, cy - 8.5 * s, cx + 0.65 * s, cy + 8.5 * s], fill=INK)
        elif value == "dot":
            d.ellipse([cx - 1.5 * s, cy - 1.5 * s, cx + 1.5 * s, cy + 1.5 * s], fill=INK)
        else:
            d.rectangle([cx - 8.5 * s, cy - 0.65 * s, cx + 8.5 * s, cy + 0.65 * s], fill=INK)
    elif kind == "backspace":
        w, h = 22 * s, 16 * s
        pts = [(cx - w / 2, cy), (cx - w / 2 + 6 * s, cy - h / 2), (cx + w / 2, cy - h / 2),
               (cx + w / 2, cy + h / 2), (cx - w / 2 + 6 * s, cy + h / 2), (cx - w / 2, cy)]
        d.line(pts, fill=INK, width=int(lw), joint="curve")
        a = 3.6 * s
        mx = cx + 2.5 * s
        d.line([(mx - a, cy - a), (mx + a, cy + a)], fill=INK, width=int(lw))
        d.line([(mx - a, cy + a), (mx + a, cy - a)], fill=INK, width=int(lw))
    elif kind == "return":
        r = 8 * s
        d.line([(cx + r, cy - r), (cx + r, cy + 2 * s), (cx - r, cy + 2 * s)], fill=INK, width=int(lw), joint="curve")
        d.line([(cx - r, cy + 2 * s), (cx - r + 5 * s, cy - 3 * s)], fill=INK, width=int(lw))
        d.line([(cx - r, cy + 2 * s), (cx - r + 5 * s, cy + 7 * s)], fill=INK, width=int(lw))
    elif kind == "space":
        w = 18 * s
        d.line([(cx - w / 2, cy - 4 * s), (cx - w / 2, cy + 2 * s), (cx + w / 2, cy + 2 * s), (cx + w / 2, cy - 4 * s)],
               fill=INK, width=int(lw), joint="curve")


def keyboard(width_px: int, layer: str = "korean", page: int = 0) -> Image.Image:
    """실제 키보드와 같은 배치를 width_px 폭으로 그린다(375pt 기준 비율)."""
    s = width_px * SS / 375
    row = 54 * s
    top = 10 * s
    height = top + row * 4 + 14 * s
    img = Image.new("RGB", (int(width_px * SS), int(height)), CREAM)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, img.width, img.height + 60 * s], radius=34 * s, fill=PANEL)

    keys = []

    def add(content, x, y, w, h):
        keys.append(((x, y, x + w, y + h), content))

    if layer == "korean":
        col = 375 * s / 3.53
        grid = [[("vowel", "i"), ("vowel", "dot"), ("vowel", "eu")],
                [("text", ("ㄱ ㅋ", 19)), ("text", ("ㄴ ㄹ", 19)), ("text", ("ㄷ ㅌ", 19))],
                [("text", ("ㅂ ㅍ", 19)), ("text", ("ㅅ ㅎ", 19)), ("text", ("ㅈ ㅊ", 19))]]
        for r, line in enumerate(grid):
            for c, content in enumerate(line):
                add(content, c * col, top + r * row, col, row)
        y = top + 3 * row
        add(("text", ("123", 16)), 0, y, col / 2, row)
        add(("text", ("한/A", 15)), col / 2, y, col / 2, row)
        add(("text", ("ㅇ ㅁ", 19)), col, y, col, row)
        add(("space", None), 2 * col, y, col, row)
        side = 375 * s - 3 * col
        add(("backspace", None), 3 * col, top, side, row)
        add(("text", (".,?!", 17)), 3 * col, top + row, side, row)
        add(("return", None), 3 * col, top + 2 * row, side, 2 * row)
    else:
        unit = 375 * s / 10
        rows = ["1234567890", "-/:;()₩&@\""] if page == 0 else ["[]{}#%^*+=", "_\\|~<>$£¥•"]
        for r, line in enumerate(rows):
            for i, ch in enumerate(line):
                add(("text", (ch, 22 if r == 0 and page == 0 else 20)), i * unit, top + r * row, unit, row)
        y = top + 2 * row
        add(("text", ("1/2" if page == 0 else "2/2", 16)), 0, y, unit * 1.5, row)
        for i, ch in enumerate(".,?!'"):
            add(("text", (ch, 20)), unit * (1.5 + i * 1.4), y, unit * 1.4, row)
        add(("backspace", None), unit * 8.5, y, unit * 1.5, row)
        y += row
        add(("text", ("가", 16)), 0, y, unit * 2.5, row)
        add(("space", None), unit * 2.5, y, unit * 5.5, row)
        add(("return", None), unit * 8, y, unit * 2, row)

    inset = 3 * s
    for (x0, y0, x1, y1), content in keys:
        rect = (x0 + inset, y0 + inset, x1 - inset, y1 - inset)
        d.rounded_rectangle(rect, radius=8 * s, fill=KEY)
        key_label(d, rect, content, s)
    return img


# MARK: 스크린샷

W, H = 1290, 2796


def text_field(d, x, y, w, text, s):
    h = 150 * SS
    d.rounded_rectangle([x, y, x + w, y + h], radius=44 * SS, fill=WHITE)
    f = font("Regular", 60)
    tx = x + 56 * SS
    d.text((tx, y + h / 2), text, font=f, fill=INK, anchor="lm")
    end = tx + d.textlength(text, font=f) + 8 * SS
    d.rounded_rectangle([end, y + 40 * SS, end + 6 * SS, y + h - 40 * SS], radius=3 * SS, fill=PINK)


def shot(headline: str, sub: str, field: str | None, layer="korean", page=0, extra=None) -> Image.Image:
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    margin = 110 * SS
    y = 300 * SS
    # 작은 로고 마크
    strokes(d, margin + 70 * SS, y - 110 * SS, 0.2)
    head = font("Bold", 112)
    d.multiline_text((margin, y), headline, font=head, fill=INK, spacing=26 * SS)
    hb = d.multiline_textbbox((margin, y), headline, font=head, spacing=26 * SS)
    y = hb[3] + 64 * SS
    d.multiline_text((margin, y), sub, font=font("Regular", 50), fill=GRAY, spacing=22 * SS)
    if extra:
        extra(d, margin, d.multiline_textbbox((margin, y), sub, font=font("Regular", 50), spacing=22 * SS)[3] + 90 * SS)
    kb = keyboard(W, layer, page)
    img.paste(kb, (0, img.height - kb.height))
    if field is not None:
        text_field(d, margin, img.height - kb.height - 250 * SS, W * SS - margin * 2, field, SS)
    return finish(img)


def promise_list(d, x, y):
    f = font("Medium", 56)
    for i, line in enumerate(["광고 없음", "추적 없음", "구독 없음", "네트워크 코드 없음"]):
        yy = y + i * 120 * SS
        d.ellipse([x, yy + 20 * SS, x + 22 * SS, yy + 42 * SS], fill=PINK if i == 0 else INK)
        d.text((x + 60 * SS, yy + 31 * SS), line, font=f, fill=INK, anchor="lm")


def code_card(d, x, y):
    w = W * SS - x * 2
    h = 420 * SS
    d.rounded_rectangle([x, y, x + w, y + h], radius=44 * SS, fill=WHITE)
    mono = ImageFont.truetype("/System/Library/Fonts/SFNSMono.ttf", 40 * SS)
    lines = [("github.com/loesol/cheonjiin", INK), ("", INK), ("License   MIT", GRAY),
             ("Network   none", GRAY), ("Access    전체 접근 없이도 동작", GRAY)]
    for i, (line, color) in enumerate(lines):
        f = font("Regular", 40) if any("가" <= c <= "힣" for c in line) else mono
        if "전체" in line:
            d.text((x + 60 * SS, y + 70 * SS + i * 64 * SS), "Access    ", font=mono, fill=color)
            off = d.textlength("Access    ", font=mono)
            d.text((x + 60 * SS + off, y + 70 * SS + i * 64 * SS), "전체 접근 없이도 동작", font=font("Regular", 40), fill=color)
        else:
            d.text((x + 60 * SS, y + 70 * SS + i * 64 * SS), line, font=f, fill=color)


def main():
    OUT.mkdir(exist_ok=True)
    shots = OUT / "screenshots"
    shots.mkdir(exist_ok=True)

    icon = make_icon()
    icon.save(OUT / "icon-1024.png")
    icon.save(ROOT / "App/Assets.xcassets/AppIcon.appiconset/icon.png")

    shot("가장 가벼운\n천지인 키보드", "ㅣ ㆍ ㅡ 세 획이면 충분해요", "안녕하세요").save(shots / "01-hero.png")
    shot("없는 게\n자랑이에요", "가볍게, 조용하게, 입력만 해요", None, extra=promise_list).save(shots / "02-nothing.png")
    shot("코드가 전부\n공개돼 있어요", "오픈소스라 누구나 확인할 수 있어요", None, extra=code_card).save(shots / "03-open.png")
    shot("숫자와 기호도\n한 화면에서", "1/2 키로 기호 두 쪽을 오가요", "3시 30분 :)", layer="symbols").save(shots / "04-symbols.png")
    print("ok", sorted(p.name for p in shots.iterdir()))


if __name__ == "__main__":
    main()
