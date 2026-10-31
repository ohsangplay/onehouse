#!/usr/bin/env bash
# 한지붕 앱의 플랫폼 폴더(android/ios/web)를 만들고 앱 이름·인터넷 권한을 맞춘다.
# 저장소에는 lib/, test/, pubspec.yaml만 두고 플랫폼 폴더는 이 스크립트로 만든다. 기존 lib/ 코드는 덮어쓰지 않는다.
#
# 사용: scripts/flutter_platforms.sh <앱 폴더> <프로젝트 이름> <홈 화면 이름> [플랫폼]
#   scripts/flutter_platforms.sh apps/budget budget "한지붕 가계부"
#   scripts/flutter_platforms.sh apps/memo memo "한지붕 메모" android,ios,web
#
# 번들 ID / 패키지명 = com.ohsang.util.onehouse.<프로젝트 이름>
#   → com.ohsang.util.onehouse.budget, com.ohsang.util.onehouse.memo
set -euo pipefail

APP_DIR=$1
NAME=$2
LABEL=$3
PLATFORMS=${4:-android,ios}

cd "$APP_DIR"
flutter create --org com.ohsang.util.onehouse --project-name "$NAME" --platforms "$PLATFORMS" .
rm -f test/widget_test.dart

python3 - "$LABEL" <<'PY'
import pathlib
import re
import sys

label = sys.argv[1]

manifest = pathlib.Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    s = manifest.read_text(encoding='utf-8')
    s = re.sub(r'android:label="[^"]*"', f'android:label="{label}"', s, count=1)
    # flutter create는 디버그 빌드에만 인터넷 권한을 넣는다. 릴리스에서도 서버에 닿아야 한다.
    if 'android.permission.INTERNET' not in s:
        s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
    manifest.write_text(s, encoding='utf-8')

plist = pathlib.Path('ios/Runner/Info.plist')
if plist.exists():
    s = plist.read_text(encoding='utf-8')
    for key in ('CFBundleDisplayName', 'CFBundleName'):
        s = re.sub(rf'(<key>{key}</key>\s*<string>)[^<]*(</string>)', lambda m: m.group(1) + label + m.group(2), s)
    plist.write_text(s, encoding='utf-8')

index = pathlib.Path('web/index.html')
if index.exists():
    s = index.read_text(encoding='utf-8')
    s = re.sub(r'<title>[^<]*</title>', f'<title>{label}</title>', s)
    index.write_text(s, encoding='utf-8')

print(f'앱 이름: {label}')
PY
