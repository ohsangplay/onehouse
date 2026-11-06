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
    import plistlib
    data = plistlib.loads(plist.read_bytes())
    data['CFBundleDisplayName'] = label
    data['CFBundleName'] = label
    # 표준 HTTPS 외 암호화 없음 → App Store Connect 수출 규정 질문을 매번 안 물어봄
    data['ITSAppUsesNonExemptEncryption'] = False
    # 기본 언어를 한국어로: iOS가 띄우는 메뉴·권한 창도 한국어로 나옴
    data['CFBundleDevelopmentRegion'] = 'ko'
    data['CFBundleLocalizations'] = ['ko']
    plist.write_bytes(plistlib.dumps(data))

pbx = pathlib.Path('ios/Runner.xcodeproj/project.pbxproj')
if pbx.exists():
    s = pbx.read_text(encoding='utf-8')
    # iPhone 전용 (iPad 스크린샷 없이 제출)
    s = s.replace('TARGETED_DEVICE_FAMILY = "1,2";', 'TARGETED_DEVICE_FAMILY = 1;')
    pbx.write_text(s, encoding='utf-8')

# 출시 서명: 환경변수 ANDROID_KEYSTORE_PATH 등이 있으면 업로드 키로, 없으면 디버그 키로 서명 (android-release.yml이 넣어 줌)
kts = pathlib.Path('android/app/build.gradle.kts')
if kts.exists():
    s = kts.read_text(encoding='utf-8')
    if 'ANDROID_KEYSTORE_PATH' not in s:
        s = re.sub(r'\n([ \t]*)buildTypes \{', lambda m: (
            f'\n{m.group(1)}signingConfigs {{\n'
            f'{m.group(1)}    create("release") {{\n'
            f'{m.group(1)}        System.getenv("ANDROID_KEYSTORE_PATH")?.let {{ storeFile = file(it) }}\n'
            f'{m.group(1)}        storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")\n'
            f'{m.group(1)}        keyAlias = System.getenv("ANDROID_KEY_ALIAS")\n'
            f'{m.group(1)}        keyPassword = System.getenv("ANDROID_KEY_PASSWORD")\n'
            f'{m.group(1)}    }}\n{m.group(1)}}}\n\n{m.group(1)}buildTypes {{'), s, count=1)
        s = s.replace('signingConfig = signingConfigs.getByName("debug")',
                      'signingConfig = if (System.getenv("ANDROID_KEYSTORE_PATH") != null) signingConfigs.getByName("release") else signingConfigs.getByName("debug")')
        if 'getByName("release")' not in s:
            print('[주의] build.gradle.kts에 출시 서명 설정을 넣지 못했어요')
        kts.write_text(s, encoding='utf-8')

# AdMob 앱 ID (google_mobile_ads를 쓰는 앱만). 환경변수가 없으면 Google 테스트 앱 ID.
#   ADMOB_APP_ID_ANDROID=ca-app-pub-xxxx~yyyy  ADMOB_APP_ID_IOS=ca-app-pub-xxxx~zzzz
import os
if 'google_mobile_ads' in pathlib.Path('pubspec.yaml').read_text(encoding='utf-8'):
    android_id = os.environ.get('ADMOB_APP_ID_ANDROID') or 'ca-app-pub-3940256099942544~3347511713'
    ios_id = os.environ.get('ADMOB_APP_ID_IOS') or 'ca-app-pub-3940256099942544~1458002511'
    if manifest.exists():
        s = manifest.read_text(encoding='utf-8')
        if 'com.google.android.gms.ads.APPLICATION_ID' not in s:
            meta = ('\n        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"'
                    f' android:value="{android_id}"/>')
            s = re.sub(r'(<application[^>]*>)', lambda m: m.group(1) + meta, s, count=1)
            manifest.write_text(s, encoding='utf-8')
    if plist.exists():
        import plistlib
        data = plistlib.loads(plist.read_bytes())
        data['GADApplicationIdentifier'] = ios_id
        # Google 광고 네트워크 (SKAdNetwork)
        data['SKAdNetworkItems'] = [{'SKAdNetworkIdentifier': 'cstr6suwn9.skadnetwork'}]
        plist.write_bytes(plistlib.dumps(data))
    # 출시 빌드(R8 축소)에서 광고 SDK가 쓰는 WorkManager/Room 클래스가 지워져 실행하자마자 죽는 문제 방지
    rules = pathlib.Path('android/app/proguard-rules.pro')
    if rules.parent.exists():
        keep = ('# google_mobile_ads -> WorkManager(Room). 지우면 시작 시 WorkDatabase 생성 실패로 앱이 죽는다\n'
                '-keep class * extends androidx.room.RoomDatabase { <init>(); *; }\n'
                '-keep class androidx.work.** { *; }\n'
                '-keep class androidx.startup.** { *; }\n'
                '-dontwarn androidx.work.**\n')
        old = rules.read_text(encoding='utf-8') if rules.exists() else ''
        if 'androidx.work' not in old:
            rules.write_text(old + keep, encoding='utf-8')
        kts = pathlib.Path('android/app/build.gradle.kts')
        if kts.exists():
            k = kts.read_text(encoding='utf-8')
            if 'proguard-rules.pro' not in k:
                k = re.sub(r'(\n([ \t]*)release \{)', lambda m: m.group(1) + f'\n{m.group(2)}    proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")', k, count=1)
                if 'proguard-rules.pro' not in k:
                    print('[주의] build.gradle.kts에 proguard 규칙을 연결하지 못했어요')
                kts.write_text(k, encoding='utf-8')
    # 플랫폼별로 따로 표시 (iOS 빌드에는 Android ID가 없어서 한 줄로 보이면 헷갈림)
    def kind(v):
        return '테스트 ID' if '3940256099942544' in v else f'실제 ID ({v})'
    if manifest.exists():
        print('AdMob 앱 ID (Android): ' + kind(android_id))
    if plist.exists():
        print('AdMob 앱 ID (iOS): ' + kind(ios_id))

index = pathlib.Path('web/index.html')
if index.exists():
    s = index.read_text(encoding='utf-8')
    s = re.sub(r'<title>[^<]*</title>', f'<title>{label}</title>', s)
    index.write_text(s, encoding='utf-8')

print(f'앱 이름: {label}')
PY

# 아이콘: pubspec.yaml에 flutter_launcher_icons 설정이 있고 android·ios 폴더가 있으면 만든다 (웹만 만들 때는 건너뜀)
if grep -q '^flutter_launcher_icons:' pubspec.yaml && [ -d android ] && [ -d ios ]; then
  flutter pub get
  dart run flutter_launcher_icons
fi
