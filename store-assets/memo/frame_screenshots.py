#!/usr/bin/env python3
"""
한지붕 메모 스토어 스크린샷: 앱 화면(raw/01.png ~)에 캡션을 입혀 스토어 규격으로 만든다.
(환율 기록 store-assets/frame_screenshots.py와 같은 방식)

사용법 (저장소 맨 위에서)
  pip install pillow
  python3 store-assets/memo/frame_screenshots.py

입력: store-assets/memo/raw/01.png ... (e2e/store-memo.mjs가 1206×2622로 찍음)
출력:
  out/screenshots/appstore/01.png ...   1206×2622 (App Store iPhone 6.3")
  out/screenshots/appstore-6.9/01.png ... 1320×2868 (App Store iPhone 6.9")
  out/screenshots/play/01.png ...       1080×1920 (Google Play 휴대폰)
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))

CAPTIONS = [
    ("가족과 함께 쓰는 메모장", "초대코드 하나로 메모집을 같이 써요"),
    ("장보기는 체크리스트로", "누가 체크했는지 바로 보여요"),
    ("지금 누가 고치는지 보여요", "같은 메모를 열면 바로 알려줘요"),
    ("동시에 고쳐도 걱정 없게", "다른 줄은 자동으로 합치고, 겹치면 골라요"),
    ("지하 마트에서도 체크", "연결되면 알아서 반영돼요"),
    ("방장이 승인해야 들어와요", "부방장 지정·차단까지 직접 관리"),
]

SIZES = {
    "appstore": (1206, 2622),
    "appstore-6.9": (1320, 2868),
    "play": (1080, 1920),
}

TOP = (189, 101, 49)     # #BD6531
BOTTOM = (138, 63, 22)   # #8A3F16

FONT_CANDIDATES = {
    "bold": [
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
        "/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc",
        "/System/Library/Fonts/AppleSDGothicNeo.ttc",
        r"C:\Windows\Fonts\malgunbd.ttf",
    ],
    "regular": [
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",
        "/System/Library/Fonts/AppleSDGothicNeo.ttc",
        r"C:\Windows\Fonts\malgun.ttf",
    ],
}


def load_font(kind, size):
    for path in FONT_CANDIDATES[kind]:
        if os.path.exists(path):
            index = 1 if "NotoSansCJK" in path else 0  # Noto CJK .ttc는 index 1이 KR
            try:
                return ImageFont.truetype(path, size, index=index)
            except OSError:
                continue
    sys.exit("한글 글꼴을 찾지 못했어요. FONT_CANDIDATES에 글꼴 경로를 추가해 주세요.")


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    px = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        px.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1), radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img.convert("RGB"), (0, 0), mask)
    return out, mask


def frame(raw_path, title, sub, size):
    W, H = size
    canvas = gradient(W, H).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    title_font = load_font("bold", round(W * 0.074))
    sub_font = load_font("regular", round(W * 0.040))
    top = round(H * 0.06)
    draw.text((W / 2, top), title, font=title_font, fill="white", anchor="mt")
    tb = draw.textbbox((W / 2, top), title, font=title_font, anchor="mt")
    draw.text((W / 2, tb[3] + round(H * 0.016)), sub, font=sub_font, fill=(255, 255, 255, 225), anchor="mt")

    # 앱 화면: 가로 84%, 화면의 80% 이상이 보이게 하고 아래쪽만 살짝 잘림
    shot = Image.open(raw_path).convert("RGB")
    y = round(H * 0.2)
    sw = round(min(W * 0.84, (H - y) / 0.8 * shot.width / shot.height))
    sh = round(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    radius = round(sw * 0.07)
    shot_rgba, mask = rounded(shot, radius)
    x = (W - sw) // 2

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sm = Image.new("L", canvas.size, 0)
    sm.paste(mask, (x, y + round(W * 0.012)))
    shadow.putalpha(sm.filter(ImageFilter.GaussianBlur(W * 0.02)).point(lambda a: a * 0.35))
    canvas = Image.alpha_composite(canvas, shadow)

    border = round(W * 0.012)
    bezel = Image.new("RGBA", (sw + border * 2, sh + border * 2), (0, 0, 0, 0))
    ImageDraw.Draw(bezel).rounded_rectangle(
        (0, 0, bezel.width - 1, bezel.height - 1), radius=radius + border, fill=(28, 22, 18, 255)
    )
    canvas.alpha_composite(bezel, (x - border, y - border))
    canvas.alpha_composite(shot_rgba, (x, y))
    return canvas.convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default=os.path.join(HERE, "raw"))
    ap.add_argument("--out", default=os.path.join(HERE, "out", "screenshots"))
    args = ap.parse_args()

    raws = sorted(f for f in os.listdir(args.raw) if f.lower().endswith(".png"))
    if not raws:
        sys.exit(f"{args.raw} 폴더에 캡처가 없어요 (01.png, 02.png ...)")
    for store, size in SIZES.items():
        os.makedirs(os.path.join(args.out, store), exist_ok=True)
        for i, name in enumerate(raws[: len(CAPTIONS)]):
            title, sub = CAPTIONS[i]
            img = frame(os.path.join(args.raw, name), title, sub, size)
            dst = os.path.join(args.out, store, f"{i + 1:02d}.png")
            img.save(dst, optimize=True)
            print(f"[ok] {dst} {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
