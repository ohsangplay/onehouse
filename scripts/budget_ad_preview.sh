#!/usr/bin/env bash
# Android 에뮬레이터에서 가계부 화면(하단 배너 광고)을 찍는다. budget-ad-preview.yml이 에뮬레이터 안에서 실행.
# 전제: 로컬 API가 127.0.0.1:8787 (에뮬레이터에서는 10.0.2.2:8787), APK 두 개가 build-preview/에 있음
#   real.apk = 저장소 Variables의 실제 광고 단위 ID / test.apk = Google 테스트 광고 ID
set -uo pipefail
OUT=preview/budget-ad
PKG=com.ohsang.util.onehouse.budget
mkdir -p "$OUT"

shot() { sleep "${2:-3}"; adb exec-out screencap -p > "$OUT/$1.png"; echo "📸 $1"; }

tap_text() {
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    adb pull /sdcard/ui.xml "$OUT/ui.xml" >/dev/null 2>&1
    xy=$(python3 - "$1" "$OUT/ui.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
want, path = sys.argv[1], sys.argv[2]
try:
    root = ET.parse(path).getroot()
except Exception:
    sys.exit(0)
for n in root.iter('node'):
    label = (n.get('content-desc') or '') + ' ' + (n.get('text') or '')
    if want in label:
        x1, y1, x2, y2 = map(int, re.findall(r'\d+', n.get('bounds')))
        print((x1 + x2) // 2, (y1 + y2) // 2)
        break
PY
)
    if [ -n "$xy" ]; then adb shell input tap $xy; echo "👆 $1 ($xy)"; return 0; fi
    sleep 2
  done
  echo "못 찾음: $1"; return 1
}

launch() { adb shell am force-stop $PKG; adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; }

adb wait-for-device
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
adb logcat -c

# 1) 실제 광고 단위 ID 빌드
adb install -r build-preview/real.apk
launch
for i in $(seq 1 60); do
  n=$(cd server && npx wrangler d1 execute onehouse --local --json --command "SELECT COUNT(*) AS n FROM devices" 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin)[0]['results'][0]['n'])" 2>/dev/null || echo 0)
  [ "${n:-0}" -ge 1 ] && break; sleep 2
done
shot 00-start 2
(cd e2e && node budget-ad-preview-seed.mjs)

launch
shot real-01-list 20
tap_text "우리집 생활비" && shot real-02-home 20
tap_text "달력" && shot real-03-calendar 8

# 2) 같은 데이터로 Google 테스트 광고 빌드 (데이터 유지하며 덮어 설치)
adb install -r build-preview/test.apk
launch
shot test-01-list 20
tap_text "우리집 생활비" && shot test-02-home 20

adb logcat -d | grep -iE "flutter|Ads|광고" | grep -vE "^\s*$" | tail -200 > "$OUT/logcat.txt" || true
grep -E "배너 광고 실패|Ad failed|onAdFailedToLoad|Use RequestConfiguration|test device" "$OUT/logcat.txt" | head -20 > "$OUT/ad-errors.txt" || true
echo "끝"
