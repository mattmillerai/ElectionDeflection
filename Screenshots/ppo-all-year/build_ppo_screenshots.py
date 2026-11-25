#!/usr/bin/env python3
"""Compose draft App Store PPO screenshot treatments for ElectionDeflection.

All app UI is taken from real captures in the dev repo. Headlines are
marketing typography on a branded canvas. Output is 1320x2868 RGB PNG
(no alpha) for the iPhone 6.9" App Store size.
"""

from __future__ import annotations

import math
import os
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

def _discover_paths() -> tuple[Path, Path]:
    here = Path(__file__).resolve().parent
    # Running from the box export directory, or from Screenshots/ppo-all-year in the repo.
    if (here / "variant-a").exists() or here.name == "ed-ppo-screenshots":
        out = here
    else:
        out = Path("/workspace/ed-ppo-screenshots")
    candidates = [
        Path("/workspace/ElectionDeflection-dev"),
        here.parents[1] if len(here.parents) > 1 else None,
        here.parent,
        Path.cwd(),
    ]
    repo = None
    for c in candidates:
        if c and (c / "Screenshots").is_dir() and (c / "ElectionDeflection").is_dir():
            repo = c
            break
    if repo is None:
        raise SystemExit("Could not find the ElectionDeflection-dev repo (expected Screenshots/ and ElectionDeflection/).")
    return repo, out

REPO, OUT = _discover_paths()
FONTS = Path("/tmp/ed-fonts")

# Brand colors from ElectionDeflection/Extensions/Color+Hex.swift
NAVY = (0x30, 0x47, 0x89)
PRO_NAVY = (0x1E, 0x2D, 0x4F)
GOLD = (0xD4, 0xA8, 0x43)
WHITE = (255, 255, 255)
SUB_WHITE = (230, 234, 245)
KICKER = (212, 168, 67)

W, H = 1320, 2868

FONT_HEAD = FONTS / "Geist-800.ttf"
FONT_SUB = FONTS / "Geist-500.ttf"
FONT_KICKER = FONTS / "Geist-600.ttf"
FONT_UI = FONTS / "Geist-500.ttf"

APP_ICON = REPO / "ElectionDeflection/Assets.xcassets/AppIcon.appiconset/1024.png"

# Real UI sources
SCENE1 = REPO / "Screenshots/scene-1_onboarding-welcome_6.9-iphone17promax.png"
SCENE2 = REPO / "Screenshots/scene-2_free-tier-home_6.9-iphone17promax.png"
SCENE4 = REPO / "Screenshots/scene-4_pro-settings_6.9-iphone17promax.png"
FILTER_MENU = REPO / "Screenshots/processed/ios26_filter_menu.png"
FILTER_PICKER = REPO / "Screenshots/IMG_7035.PNG"


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def rounded_icon(path: Path, size: int, radius: int | None = None) -> Image.Image:
    im = Image.open(path).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    if radius is None:
        radius = int(size * 0.2237)  # iOS squircle-ish
    mask = rounded_mask((size, size), radius)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(im, (0, 0))
    out.putalpha(mask)
    return out


def letter_spacing_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    xy: tuple[int, int],
    font: ImageFont.FreeTypeFont,
    fill,
    spacing: float,
    anchor: str = "mm",
) -> tuple[int, int]:
    """Draw text with added tracking. Returns (width, height)."""
    if not text:
        return (0, 0)
    widths = []
    for ch in text:
        bbox = font.getbbox(ch)
        widths.append(bbox[2] - bbox[0])
    total = sum(widths) + spacing * (len(text) - 1)
    # height from full string
    tb = font.getbbox(text)
    height = tb[3] - tb[1]
    x, y = xy
    if "m" in anchor[0]:
        # horizontal mid
        x = int(x - total / 2)
    if anchor.endswith("m"):
        y = int(y - height / 2 - tb[1])
    elif anchor.endswith("a"):
        y = int(y - tb[1])
    cx = x
    for ch, w in zip(text, widths):
        draw.text((cx, y), ch, font=font, fill=fill)
        cx += w + spacing
    return (int(total), int(height))


def wrap_text(text: str, font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    if "\n" in text:
        lines = []
        for part in text.split("\n"):
            lines.extend(wrap_text(part, font, max_width) if part else [""])
        return lines
    words = text.split(" ")
    lines: list[str] = []
    cur = ""
    for word in words:
        trial = word if not cur else f"{cur} {word}"
        bbox = font.getbbox(trial)
        if bbox[2] - bbox[0] <= max_width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def text_block_height(lines: list[str], font, line_gap: int) -> int:
    if not lines:
        return 0
    heights = []
    for line in lines:
        b = font.getbbox(line)
        heights.append(b[3] - b[1])
    return sum(heights) + line_gap * (len(lines) - 1)


def draw_centered_lines(
    draw: ImageDraw.ImageDraw,
    lines: list[str],
    center_x: int,
    top_y: int,
    font: ImageFont.FreeTypeFont,
    fill,
    line_gap: int,
) -> int:
    y = top_y
    for i, line in enumerate(lines):
        b = font.getbbox(line)
        h = b[3] - b[1]
        # Use anchor mm on the midline of this line
        draw.text((center_x, y - b[1]), line, font=font, fill=fill, anchor="ma")
        y += h + line_gap
    return y - line_gap


def make_background() -> Image.Image:
    """Navy vertical gradient with a soft gold glow behind the phone area."""
    img = Image.new("RGB", (W, H), NAVY)
    px = img.load()
    # Vertical gradient: slightly lighter at top, deeper toward bottom (blend to pro navy)
    for y in range(H):
        t = y / (H - 1)
        # ease
        te = t * t * (3 - 2 * t)
        r = int(NAVY[0] * (1 - te) + PRO_NAVY[0] * te)
        g = int(NAVY[1] * (1 - te) + PRO_NAVY[1] * te)
        b = int(NAVY[2] * (1 - te) + PRO_NAVY[2] * te)
        for x in range(W):
            px[x, y] = (r, g, b)

    # Soft radial gold glow, very subtle, centered where the phone sits (~ y=1700)
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    gp = glow.load()
    cx, cy = W / 2, 1680
    # elliptical radius
    rx, ry = 520, 780
    for y in range(H):
        for x in range(0, W, 2):  # slightly coarse, then blur
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            d = nx * nx + ny * ny
            if d < 1.0:
                a = (1.0 - math.sqrt(d)) ** 2
                # gold-ish, very dim
                gp[x, y] = (int(GOLD[0] * a), int(GOLD[1] * a), int(GOLD[2] * a))
                if x + 1 < W:
                    gp[x + 1, y] = gp[x, y]
    glow = glow.filter(ImageFilter.GaussianBlur(radius=80))
    # Screen blend-ish: add a little gold into navy
    base = img.load()
    gl = glow.load()
    for y in range(H):
        for x in range(W):
            gcol = gl[x, y]
            if gcol[0] or gcol[1] or gcol[2]:
                br, bg, bb = base[x, y]
                # mix 10% of glow
                base[x, y] = (
                    min(255, br + gcol[0] // 10),
                    min(255, bg + gcol[1] // 10),
                    min(255, bb + gcol[2] // 10),
                )
    # Very faint grain so large flats don't posterize
    import random

    rng = random.Random(42)
    for _ in range(W * H // 40):
        x = rng.randrange(W)
        y = rng.randrange(H)
        r, g, b = base[x, y]
        dlt = rng.randint(-3, 3)
        base[x, y] = (
            max(0, min(255, r + dlt)),
            max(0, min(255, g + dlt)),
            max(0, min(255, b + dlt)),
        )
    return img


def place_phone(
    canvas: Image.Image,
    source: Path,
    top: int,
    width: int,
    crop: str = "top",
    max_height: int | None = None,
    style: str = "phone",
) -> int:
    """Paste a real screenshot as a rounded phone screen or a detail card."""
    src = Image.open(source).convert("RGB")
    scale = width / src.width
    ph = int(src.height * scale)
    if max_height and ph > max_height:
        # crop source so scaled height == max_height
        crop_h = int(max_height / scale)
        if crop == "top":
            src = src.crop((0, 0, src.width, crop_h))
        elif crop == "center":
            y0 = (src.height - crop_h) // 2
            src = src.crop((0, y0, src.width, y0 + crop_h))
        elif crop == "bottom":
            src = src.crop((0, src.height - crop_h, src.width, src.height))
        elif crop == "filter_menu":
            # keep the menu card; image is already a crop
            src = src.crop((0, 0, src.width, min(crop_h, src.height)))
        ph = int(src.height * scale)
    phone = src.resize((width, ph), Image.Resampling.LANCZOS)

    if style == "card":
        # A mid-screen crop is not a phone; use modest card corners, no device bezel.
        radius = 44
        bezel = 3
    else:
        radius = max(48, int(width * 0.125))
        bezel = 8
    outer_w, outer_h = width + bezel * 2, ph + bezel * 2
    outer_r = radius + bezel

    # Shadow
    shadow_pad = 48
    shadow = Image.new("RGBA", (outer_w + shadow_pad * 2, outer_h + shadow_pad * 2), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (shadow_pad + 4, shadow_pad + 18, shadow_pad + outer_w - 4, shadow_pad + outer_h + 10),
        radius=outer_r,
        fill=(0, 0, 0, 160),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))

    left = (W - outer_w) // 2
    # paste shadow
    canvas.paste(
        Image.alpha_composite(canvas.convert("RGBA"), Image.new("RGBA", canvas.size, (0, 0, 0, 0))),
        (0, 0),
    )
    # Work in RGBA overlay
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    overlay.paste(shadow, (left - shadow_pad, top - shadow_pad), shadow)

    # Bezel body
    bezel_img = Image.new("RGBA", (outer_w, outer_h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bezel_img)
    # slightly darker than navy
    bd.rounded_rectangle((0, 0, outer_w - 1, outer_h - 1), radius=outer_r, fill=(14, 20, 38, 255))
    # thin gold-ish inner hairline
    bd.rounded_rectangle(
        (2, 2, outer_w - 3, outer_h - 3),
        radius=outer_r - 2,
        outline=(GOLD[0], GOLD[1], GOLD[2], 40),
        width=1,
    )
    overlay.paste(bezel_img, (left, top), bezel_img)

    # Screen
    mask = rounded_mask((width, ph), radius)
    screen = Image.new("RGBA", (width, ph), (0, 0, 0, 0))
    screen.paste(phone, (0, 0))
    screen.putalpha(mask)
    overlay.paste(screen, (left + bezel, top + bezel), screen)

    composed = Image.alpha_composite(canvas.convert("RGBA"), overlay).convert("RGB")
    canvas.paste(composed)
    return top + outer_h


def compose_card(
    source: Path,
    headline: str,
    subhead: str,
    crop: str = "top",
    phone_kind: str = "full",
) -> Image.Image:
    canvas = BACKGROUND.copy()
    draw = ImageDraw.Draw(canvas)

    cx = W // 2
    y = 96

    # App icon
    icon = rounded_icon(APP_ICON, 108, radius=24)
    # drop a tiny shadow under icon
    icon_shadow = Image.new("RGBA", (108 + 20, 108 + 20), (0, 0, 0, 0))
    isd = ImageDraw.Draw(icon_shadow)
    isd.rounded_rectangle((4, 8, 108 + 4, 108 + 12), radius=24, fill=(0, 0, 0, 90))
    icon_shadow = icon_shadow.filter(ImageFilter.GaussianBlur(6))
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    overlay.paste(icon_shadow, (cx - 54 - 4, y - 4), icon_shadow)
    overlay.paste(icon, (cx - 54, y), icon)
    canvas = Image.alpha_composite(canvas.convert("RGBA"), overlay).convert("RGB")
    draw = ImageDraw.Draw(canvas)
    y += 108 + 36

    # Kicker
    kicker_font = ImageFont.truetype(str(FONT_KICKER), 28)
    letter_spacing_text(
        draw,
        "ELECTIONDEFLECTION",
        (cx, y + 8),
        kicker_font,
        KICKER,
        spacing=6.5,
        anchor="mm",
    )
    y += 48

    # Headline
    # Size down if needed to fit width
    max_text_w = W - 120
    head_size = 86
    while head_size >= 64:
        head_font = ImageFont.truetype(str(FONT_HEAD), head_size)
        lines = wrap_text(headline, head_font, max_text_w)
        # Prefer 2-3 lines; if a single line is too wide it already wrapped
        widest = max(head_font.getbbox(line)[2] - head_font.getbbox(line)[0] for line in lines)
        if widest <= max_text_w and len(lines) <= 3:
            break
        head_size -= 2
    head_font = ImageFont.truetype(str(FONT_HEAD), head_size)
    head_lines = wrap_text(headline, head_font, max_text_w)
    head_gap = int(head_size * 0.12)
    y = draw_centered_lines(draw, head_lines, cx, y, head_font, WHITE, head_gap)
    y += 28

    # Gold rule
    rule_w = 72
    draw.rounded_rectangle((cx - rule_w // 2, y, cx + rule_w // 2, y + 5), radius=2, fill=GOLD)
    y += 28

    # Subhead
    sub_font = ImageFont.truetype(str(FONT_SUB), 36)
    sub_lines = wrap_text(subhead, sub_font, max_text_w - 20)
    sub_gap = 10
    y = draw_centered_lines(draw, sub_lines, cx, y, sub_font, SUB_WHITE, sub_gap)
    y += 48

    # Phone area — fill remaining with bottom margin
    bottom_margin = 72
    available = H - y - bottom_margin
    if phone_kind == "detail":
        # Don't crop as a tall phone; scale the real crop and give it rounded corners
        phone_w = 1140
    else:
        phone_w = 1040

    place_phone(
        canvas,
        source,
        top=y,
        width=phone_w,
        crop=crop,
        max_height=available,
        style="card" if phone_kind == "detail" else "phone",
    )
    # Ensure exact RGB, no alpha
    return canvas.convert("RGB")


@dataclass
class Shot:
    filename: str
    headline: str
    subhead: str
    source: Path
    crop: str = "top"
    phone_kind: str = "full"


VARIANTS: dict[str, dict] = {
    "a": {
        "angle": "Year-round lead",
        "note": (
            "Leads with the approved 'block unwanted texts all year' pitch, then "
            "immediately names election and political texts so it cannot be read "
            "as a general SMS or scam blocker."
        ),
        "shots": [
            Shot(
                "01-all-year_6.9-iphone-1320x2868.png",
                "Block unwanted texts\nall year",
                "Election and political texts, moved to your Spam folder",
                SCENE2,
            ),
            Shot(
                "02-political-texts-all-year_6.9-iphone-1320x2868.png",
                "Political texts\nshow up all year",
                "Campaign messages don't stop after Election Day",
                SCENE1,
            ),
            Shot(
                "03-moved-to-spam_6.9-iphone-1320x2868.png",
                "Moved to Spam,\nautomatically",
                "Uses Apple's built-in message filtering",
                FILTER_MENU,
                crop="filter_menu",
                phone_kind="detail",
            ),
            Shot(
                "04-turn-it-on_6.9-iphone-1320x2868.png",
                "Turn it on\nin Settings",
                "Choose ElectionDeflection as your Text Message Filter",
                FILTER_PICKER,
            ),
            Shot(
                "05-private-on-device_6.9-iphone-1320x2868.png",
                "Private.\nOn your device.",
                "No accounts, no tracking — and the code is open source",
                SCENE4,
            ),
        ],
    },
}


BACKGROUND = None  # set in main


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rgb = img.convert("RGB")
    assert rgb.size == (W, H), f"{path} size {rgb.size}"
    assert rgb.mode == "RGB"
    rgb.save(path, format="PNG", optimize=True)
    # verify
    check = Image.open(path)
    assert check.size == (W, H)
    assert check.mode == "RGB"


def build_contact_sheet(paths: dict[str, list[Path]]) -> Image.Image:
    thumb_w = 330
    thumb_h = int(thumb_w * H / W)
    label_h = 86
    row_label_w = 280
    pad = 28
    title_h = 180
    footer_h = 90
    cols = 5
    rows = len(paths)
    width = row_label_w + cols * thumb_w + (cols + 2) * pad
    height = title_h + rows * (thumb_h + label_h + pad) + footer_h + pad
    sheet = Image.new("RGB", (width, height), PRO_NAVY)
    d = ImageDraw.Draw(sheet)
    title_font = ImageFont.truetype(str(FONT_HEAD), 44)
    sub_font = ImageFont.truetype(str(FONT_SUB), 24)
    small = ImageFont.truetype(str(FONT_SUB), 20)
    tiny = ImageFont.truetype(str(FONT_SUB), 16)
    angle_font = ImageFont.truetype(str(FONT_HEAD), 26)
    d.text((pad + 8, 36), "ElectionDeflection  ·  PPO drafts", font=title_font, fill=WHITE)
    d.text(
        (pad + 8, 100),
        "Treatment A — “Block unwanted texts all year”  ·  50% traffic  ·  iPhone 6.9″  1320×2868",
        font=sub_font,
        fill=SUB_WHITE,
    )
    y = title_h
    order = [k for k in ("a", "b", "c") if k in paths]
    for key in order:
        meta = VARIANTS[key]
        # row label
        d.text((pad + 8, y + 12), f"Variant {key.upper()}", font=angle_font, fill=GOLD)
        # wrap angle
        note_font = ImageFont.truetype(str(FONT_SUB), 18)
        angle_lines = wrap_text(meta["angle"], note_font, row_label_w - 24)
        d.multiline_text(
            (pad + 8, y + 52),
            "\n".join(angle_lines),
            font=note_font,
            fill=SUB_WHITE,
            spacing=4,
        )
        x = row_label_w + pad
        for i, p in enumerate(paths[key]):
            im = Image.open(p).convert("RGB").resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
            # thin frame
            frame = Image.new("RGB", (thumb_w + 4, thumb_h + 4), GOLD)
            sheet.paste(frame, (x - 2, y - 2))
            sheet.paste(im, (x, y))
            shot = meta["shots"][i]
            caption = shot.headline.replace("\n", " ")
            cap_lines = wrap_text(caption, tiny, thumb_w - 8)
            d.multiline_text(
                (x, y + thumb_h + 8),
                "\n".join(cap_lines[:3]),
                font=tiny,
                fill=WHITE,
                spacing=2,
            )
            x += thumb_w + pad
        y += thumb_h + label_h + pad
    d.text(
        (pad + 8, height - footer_h + 16),
        "UI is real (repo Screenshots/ + IMG_7035). No accuracy %, no scam-blocking claims, no iPad size (listing is Designed for iPhone). Chosen treatment for the Nov 2026 PPO test, 50% traffic.",
        font=small,
        fill=SUB_WHITE,
    )
    return sheet


def main() -> None:
    global BACKGROUND
    print("Composing background…")
    bg_path = OUT / "_background.png"
    if bg_path.exists():
        BACKGROUND = Image.open(bg_path).convert("RGB")
        if BACKGROUND.size != (W, H):
            BACKGROUND = make_background()
            BACKGROUND.save(bg_path)
    else:
        BACKGROUND = make_background()
        BACKGROUND.save(bg_path)

    paths: dict[str, list[Path]] = {}
    for key, meta in VARIANTS.items():
        print(f"\n=== Variant {key.upper()} — {meta['angle']} ===")
        folder = OUT / f"variant-{key}"
        folder.mkdir(parents=True, exist_ok=True)
        paths[key] = []
        for shot in meta["shots"]:
            print(f"  {shot.filename}")
            img = compose_card(
                shot.source,
                shot.headline,
                shot.subhead,
                crop=shot.crop,
                phone_kind=shot.phone_kind,
            )
            dest = folder / shot.filename
            save_png(img, dest)
            paths[key].append(dest)
            print(f"    -> {dest} {img.size} {img.mode}")

    print("\nContact sheet…")
    sheet = build_contact_sheet(paths)
    sheet_path = OUT / "contact-sheet.png"
    sheet.convert("RGB").save(sheet_path, format="PNG", optimize=True)
    print(f"  {sheet_path} {sheet.size} {sheet.mode}")
    print("done")


if __name__ == "__main__":
    main()
