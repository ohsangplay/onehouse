#!/usr/bin/env bash
# Android 에뮬레이터에서 한지붕 메모를 띄워 하단 배너(Google 테스트 광고)가 나온 화면을 찍는다.
# ad-preview.yml이 에뮬레이터 안에서 실행한다. 결과: $OUT/01~04.png
set -uo pipefail
PKG=com.ohsang.util.onehouse.memo
OUT=${OUT:-shots}
mkdir -p "$OUT"
LOG="$OUT/run.txt"
: > "$LOG"
say() { echo "$*" | tee -a "$LOG"; }

dump() { timeout 25 adb exec-out uiautomator dump /dev/tty 2>/dev/null | sed 's/UI hierchary dumped to.*//'; }

# 화면에서 text 또는 content-desc에 $1이 들어간 요소의 가운데 좌표 (없으면 빈 값)
find_xy() {
  dump | python3 -c '
import re, sys, xml.etree.ElementTree as ET
want = sys.argv[1]; cls = sys.argv[2] if len(sys.argv) > 2 else ""
raw = sys.stdin.read()
try:
    root = ET.fromstring(raw[raw.find("<?xml"):] if "<?xml" in raw else raw)
except Exception:
    sys.exit(0)
for n in root.iter("node"):
    label = (n.get("text") or "") + " " + (n.get("content-desc") or "")
    if want and want not in label: continue
    if cls and cls not in (n.get("class") or ""): continue
    m = re.findall(r"\d+", n.get("bounds") or "")
    if len(m) == 4:
        x1, y1, x2, y2 = map(int, m)
        print((x1 + x2) // 2, (y1 + y2) // 2); break
' "$1" "${2:-}"
}

wait_for() { # 글자 [초]
  local t=${2:-40}
  for _ in $(seq 1 "$t"); do
    [ -n "$(find_xy "$1")" ] && { say "✓ 보임: $1"; return 0; }
    sleep 1
  done
  say "✗ 안 보임: $1"; adb exec-out screencap -p > "$OUT/error-$(date +%s).png"; dump > "$OUT/error-ui.xml"; return 1
}

tap() { # 글자 [클래스]
  local xy
  for _ in $(seq 1 30); do
    xy=$(find_xy "$1" "${2:-}")
    if [ -n "$xy" ]; then adb shell input tap $xy; say "탭: $1 ($xy)"; sleep 1.5; return 0; fi
    sleep 1
  done
  say "✗ 못 찾음: $1"; adb exec-out screencap -p > "$OUT/error-$(date +%s).png"; dump > "$OUT/error-ui.xml"; return 1
}

type_into() { # n번째 입력칸, 영문 글자
  local xy
  xy=$(dump | python3 -c '
import re, sys, xml.etree.ElementTree as ET
raw = sys.stdin.read(); i = int(sys.argv[1])
root = ET.fromstring(raw[raw.find("<?xml"):])
eds = [n for n in root.iter("node") if "EditText" in (n.get("class") or "")]
if len(eds) > i:
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", eds[i].get("bounds")))
    print((x1 + x2) // 2, (y1 + y2) // 2)
' "$1")
  [ -n "$xy" ] || { say "✗ 입력칸 $1 없음"; return 1; }
  adb shell input tap $xy; sleep 0.8; adb shell input text "$2"; sleep 0.8; say "입력: $2"
}

shot() { sleep "${2:-6}"; timeout 20 adb exec-out screencap -p > "$OUT/$1.png"; say "📸 $1"; }

start_app() {
  adb shell am force-stop $PKG
  adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
}

adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

say "시작 $(date +%T)"
start_app
sleep 8; timeout 20 adb exec-out screencap -p > "$OUT/00-launch.png"
wait_for "새 메모집 만들기" 40 || exit 1
tap "새 메모집 만들기" || exit 1
wait_for "메모집 이름" || exit 1
type_into 0 "Home" || exit 1
type_into 1 "Mom" || exit 1
adb shell input keyevent 111   # 키보드 닫기
tap "만들기" || exit 1
wait_for "복구코드" || exit 1
tap "안전한 곳에 저장했어요" || exit 1
tap "메모집 시작하기" || exit 1
wait_for "내 메모집" || exit 1

# 한글 이름·다른 멤버·메모 채우기 (호스트의 로컬 서버)
(cd "$GITHUB_WORKSPACE/e2e" && node ad-preview-seed.mjs) 2>&1 | tee -a "$LOG" || exit 1

start_app
wait_for "우리집 메모" 40 || exit 1
shot 01-notebook-list 10            # 메모집 목록 + 배너

tap "우리집 메모" || exit 1
wait_for "주말 장보기" || exit 1
shot 02-memo-list 8                  # 메모 목록 + 배너

tap "휴지통" || exit 1
wait_for "지난주 장보기" || exit 1
shot 03-trash 8                      # 휴지통 + 배너
adb shell input keyevent 4
sleep 2

tap "이번 주 저녁 메뉴" || exit 1
wait_for "김치찌개" || exit 1
shot 04-editor-no-ad 4               # 쓰기 화면 (광고 없음)
say "끝"
