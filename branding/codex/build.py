from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
from pathlib import Path

from fontTools.ttLib import TTFont
from PIL import Image, ImageCms, ImageDraw, ImageFont, ImageChops

sys.dont_write_bytecode = True
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
SOURCE = ROOT / "tools/branding.py"
SPEC = importlib.util.spec_from_file_location("original_branding", SOURCE)
BASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)
SCALE = 2
WIDTH, HEIGHT = 1290, 2796
CREAM = "#F6F4F1"
INK = "#242522"
MUTED = "#73746E"
PINK = "#F27380"
RULE = "#D9D8D2"
WHITE = "#FFFFFF"
FONT_DIR = Path.home() / "Library/Fonts"
PROFILE = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
AUDIT = {"text": [], "keyboards": [], "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest()}


def font(size, weight="Regular"):
    return ImageFont.truetype(str(FONT_DIR / f"Pretendard-{weight}.otf"), round(size * SCALE))


def box(coords):
    return tuple(round(value * SCALE) for value in coords)


class Poster:
    def __init__(self, number, dark=False):
        self.name = f"screenshots/{number:02}.png"
        self.image = Image.new("RGB", (WIDTH * SCALE, HEIGHT * SCALE), INK if dark else CREAM)
        self.draw = ImageDraw.Draw(self.image)
        self.foreground = CREAM if dark else INK
        self.secondary = "#B8BAB1" if dark else MUTED
        self.line_color = "#50514B" if dark else RULE
        self.keyboards = []
        self.text("천지in", 96, 144, 47, "SemiBold")
        self.text("천지인 키보드", 282, 157, 29, fill=self.secondary)
        self.text(f"0{number}", 1140, 151, 32, fill=self.secondary)
        self.line(96, 241, 1194, 241)

    def text(self, value, left, top, size, weight="Regular", fill=None):
        selected_font = font(size, weight)
        position = box((left, top))
        bounds = self.draw.textbbox(position, value, font=selected_font, anchor="lt")
        self.draw.text(position, value, font=selected_font, fill=fill or self.foreground, anchor="lt")
        AUDIT["text"].append({"file": self.name, "text": value, "font": weight,
                              "bounds": [round(value / SCALE, 2) for value in bounds]})

    def line(self, left, top, right, bottom):
        self.draw.line(box((left, top, right, bottom)), fill=self.line_color, width=2 * SCALE)

    def roundrect(self, left, top, right, bottom, radius, fill):
        self.draw.rounded_rectangle(box((left, top, right, bottom)), radius=radius * SCALE, fill=fill)

    def heading(self, first, second):
        self.text(first, 96, 370, 116, "Bold")
        self.text(second, 96, 524, 116, "Bold")

    def keyboard(self, left, top, width, layer="korean", page=0):
        self.keyboards.append({"file": self.name, "x": left, "y": top, "width": width,
                               "layer": layer, "page": page})

    def field(self, value, left, top, width, size=61):
        self.roundrect(left, top, left + width, top + 178, 40, WHITE)
        self.text(value, left + 46, top + 60, size, fill=INK)
        advance = self.draw.textlength(value, font=font(size)) / SCALE
        self.roundrect(left + 60 + advance, top + 52, left + 65 + advance, top + 128, 2.5, INK)

    def footer(self, value):
        self.line(96, 2613, 1194, 2613)
        self.text(value, 96, 2663, 31, fill=self.secondary)

    def save(self):
        image = self.image.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
        for placement in self.keyboards:
            keyboard = BASE.finish(BASE.keyboard(placement["width"], placement["layer"], placement["page"]))
            image.paste(keyboard, (placement["x"], placement["y"]))
            AUDIT["keyboards"].append({**placement, "height": keyboard.height,
                                       "sha256": hashlib.sha256(keyboard.tobytes()).hexdigest()})
        image.save(OUT / self.name, icc_profile=PROFILE)


def build():
    (OUT / "screenshots").mkdir(exist_ok=True)
    icon = Image.open(OUT / "icon-source.png").convert("RGB")
    icon = icon.resize((1024, 1024), Image.Resampling.LANCZOS)
    icon.save(OUT / "icon-1024.png", icc_profile=PROFILE)

    hero = Poster(1)
    hero.heading("매일 쓰니까,", "가볍고 단정하게.")
    hero.text("꼭 필요한 것만 남긴 천지인 키보드", 100, 746, 46, fill=MUTED)
    hero.image.paste(icon.resize((420 * SCALE, 420 * SCALE), Image.Resampling.LANCZOS), box((435, 951)))
    hero.text("익숙한 세 획. 편안한 한글.", 96, 1486, 46, "Medium")
    hero.field("오늘은 조금 가볍게.", 96, 1598, 1098)
    hero.keyboard(56, 1830, 1178)
    hero.footer("광고 없음  ·  추적 없음  ·  오픈소스")
    hero.save()

    quiet = Poster(2, dark=True)
    quiet.heading("없는 게", "마음에 들어요.")
    quiet.text("입력할 때는, 입력에만.", 100, 746, 46, fill=quiet.secondary)
    for index, (label, detail) in enumerate([
        ("광고 없음", "시선을 빼앗지 않아요"),
        ("추적 없음", "입력하는 순간도 나답게"),
        ("구독 없음", "구독 없이, 가볍게")
    ]):
        top = 970 + index * 202
        quiet.text(label, 96, top, 74, "Medium")
        quiet.text(detail, 655, top + 26, 34, fill=quiet.secondary)
        quiet.line(96, top + 130, 1194, top + 130)
    quiet.field("지금 쓰고 싶은 말에만.", 96, 1570, 1098, 57)
    quiet.roundrect(36, 1790, 1254, 2583, 62, CREAM)
    quiet.keyboard(56, 1810, 1178)
    quiet.footer("덜어낸 만큼, 입력에 집중해요.")
    quiet.save()

    symbols = Poster(3)
    symbols.heading("숫자도 기호도,", "흐름은 그대로.")
    symbols.text("1/2 키로 두 쪽의 기호를 오가요.", 100, 746, 46, fill=MUTED)
    symbols.field("3시 30분 :)", 96, 870, 1098)
    symbols.keyboard(96, 1118, 1098, "symbols", 0)
    symbols.text("한 번 더 누르면, 더 많은 기호.", 96, 1900, 42, "Medium")
    symbols.keyboard(96, 2010, 1098, "symbols", 1)
    symbols.save()

    opened = Poster(4)
    opened.heading("안까지 투명한", "천지인 키보드.")
    opened.text("모든 코드를 누구나 살펴볼 수 있어요.", 100, 746, 46, fill=MUTED)
    opened.text("MIT", 84, 940, 310, "Light")
    opened.text("오픈소스", 729, 1015, 59, "Medium")
    opened.text("열린 코드, 열린 가능성.", 733, 1108, 31, fill=MUTED)
    opened.line(96, 1350, 1194, 1350)
    opened.text("GitHub", 96, 1420, 35, fill=MUTED)
    opened.text("oesoll/cheonjiin", 96, 1505, 67, "Medium")
    opened.text("가볍게 쓰고, 함께 다듬어요.", 96, 1715, 43, fill=MUTED)
    opened.keyboard(56, 1830, 1178)
    opened.footer("천지in  ·  MIT 라이선스  ·  오픈소스")
    opened.save()

    (OUT / "audit.json").write_text(json.dumps(AUDIT, ensure_ascii=False, indent=2) + "\n")
    contact = Image.new("RGB", (1768, 870), "#E9E7E2")
    contact.paste(icon.resize((256, 256), Image.Resampling.LANCZOS), (24, 280))
    for number in range(1, 5):
        shot = Image.open(OUT / f"screenshots/{number:02}.png")
        shot.thumbnail((350, 758), Image.Resampling.LANCZOS)
        contact.paste(shot, (320 + (number - 1) * 356, 56))
    contact.save(OUT / "contact-sheet.png", icc_profile=PROFILE)
    print("Built icon, four screenshots, contact sheet and audit.json")


def verify_specs():
    for relative in ["icon-1024.png"] + [f"screenshots/{number:02}.png" for number in range(1, 5)]:
        with Image.open(OUT / relative) as image:
            image.load()
            expected = (1024, 1024) if relative.startswith("icon") else (WIDTH, HEIGHT)
            assert image.size == expected, (relative, image.size)
            assert image.format == "PNG" and image.mode == "RGB", (relative, image.mode)
            assert "transparency" not in image.info and "A" not in image.getbands()
            assert image.info.get("icc_profile"), relative
            print(f"PASS {relative}: {image.size}, RGB PNG, no alpha, sRGB")


def verify_type():
    audit = json.loads((OUT / "audit.json").read_text())
    characters = {}
    for item in audit["text"]:
        characters.setdefault(item["font"], set()).update(item["text"])
        left, top, right, bottom = item["bounds"]
        assert 0 <= left < right <= WIDTH and 0 <= top < bottom <= HEIGHT, item
        assert not any(word in item["text"].lower() for word in ("무료", "free", "0원", "₩0", "할인", "최저가")), item
    characters.setdefault("Regular", set()).update("ㄱㅋㄴㄹㄷㅌㅂㅍㅅㅎㅈㅊㅇㅁ한/A123가0123456789-/:;()₩&@\"[]{}#%^*+=_\\|~<>$£¥•.,?!'")
    for weight, required in characters.items():
        with TTFont(FONT_DIR / f"Pretendard-{weight}.otf") as selected:
            cmap = selected.getBestCmap()
            missing = [character for character in required if not character.isspace() and ord(character) not in cmap]
            assert not missing, (weight, missing)
        print(f"PASS Pretendard {weight}: {len(required)} unique characters, no missing glyphs")
    print(f"PASS {len(audit['text'])} text runs: in bounds; no price claims")


def verify_keyboards():
    audit = json.loads((OUT / "audit.json").read_text())
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == audit["source_sha256"], "Renderer changed; rebuild first"
    for item in audit["keyboards"]:
        expected = BASE.finish(BASE.keyboard(item["width"], item["layer"], item["page"]))
        with Image.open(OUT / item["file"]) as shot:
            left, top = item["x"], item["y"]
            assert left + expected.width <= WIDTH and top + expected.height <= HEIGHT, item
            actual = shot.crop((left, top, left + expected.width, top + expected.height))
        assert ImageChops.difference(actual, expected).getbbox() is None, item
        print(f"PASS {item['file']} {item['layer']}/{item['page']}: pixel-identical to keyboard()")


if __name__ == "__main__":
    actions = {"build": build, "verify-specs": verify_specs, "verify-type": verify_type,
               "verify-keyboards": verify_keyboards}
    actions[sys.argv[1] if len(sys.argv) > 1 else "build"]()
