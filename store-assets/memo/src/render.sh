#!/usr/bin/env bash
# 아이콘·대표 이미지 SVG → PNG (헤드리스 Chrome + Pillow). 저장소 맨 위에서: bash store-assets/memo/src/render.sh
set -euo pipefail
cd "$(dirname "$0")"
OUT=../out
CHROME=${CHROME:-$(command -v google-chrome || command -v chromium || command -v chromium-browser)}
shot() { # svg png w h
  local html; html=$(mktemp --suffix=.html)
  printf '<html><body style="margin:0;background:transparent">%s</body></html>' "$(cat "$1")" > "$html"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --default-background-color=00000000 \
    --window-size="$3,$4" --screenshot="$2" "file://$html" >/dev/null 2>&1
  rm -f "$html"
}
shot icon.svg "$OUT/icon-1024.png" 1024 1024
shot icon-foreground.svg "$OUT/android-adaptive-foreground.png" 1024 1024
shot icon-background.svg "$OUT/android-adaptive-background.png" 1024 1024
shot feature.svg "$OUT/play-feature-graphic-1024x500.png" 1024 500
python3 - "$OUT" <<'PY'
import sys
from PIL import Image
out = sys.argv[1]
icon = Image.open(f"{out}/icon-1024.png").convert("RGB")   # App Store: 투명도 없음
icon.save(f"{out}/icon-1024.png")
icon.resize((512, 512), Image.LANCZOS).save(f"{out}/play-icon-512.png")
Image.open(f"{out}/play-feature-graphic-1024x500.png").convert("RGB").save(f"{out}/play-feature-graphic-1024x500.png")
for name in ["icon-1024", "play-icon-512", "android-adaptive-foreground", "android-adaptive-background", "play-feature-graphic-1024x500"]:
    im = Image.open(f"{out}/{name}.png"); print(name, im.size, im.mode)
PY
