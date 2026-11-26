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
    # 출시 빌드 때 도는 Android lint(lintVital)가 빌드 도구 버전에 따라 내부 오류(NoSuchMethodError)로
    # 빌드를 멈추는 일이 있어서 끈다. 앱 코드 검사는 CI의 flutter analyze가 한다.
    s = kts.read_text(encoding='utf-8')
    if 'checkReleaseBuilds' not in s:
        s = re.sub(r'\n([ \t]*)buildTypes \{', lambda m: (
            f'\n{m.group(1)}lint {{\n'
            f'{m.group(1)}    checkReleaseBuilds = false\n'
            f'{m.group(1)}    abortOnError = false\n'
            f'{m.group(1)}}}\n\n{m.group(1)}buildTypes {{'), s, count=1)
        if 'checkReleaseBuilds' not in s:
            print('[주의] build.gradle.kts에 lint 설정을 넣지 못했어요')
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

# 푸시 알림 (firebase_messaging을 쓰는 앱만): Android 알림 아이콘, iOS 알림 권한(entitlements)·최소 버전
if 'firebase_messaging' in pathlib.Path('pubspec.yaml').read_text(encoding='utf-8'):
    res = pathlib.Path('android/app/src/main/res')
    if res.exists():
        (res / 'drawable').mkdir(exist_ok=True)
        # 상태 표시줄 알림 아이콘: 흰색 실루엣이어야 한다 (앱 아이콘을 그대로 쓰면 흰 네모로 보임)
        (res / 'drawable' / 'ic_notification.xml').write_text(
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">\n'
            '  <path android:fillColor="#FFFFFFFF" android:fillType="evenOdd" android:pathData="M12,3 L2,11.5 L4.6,11.5 L4.6,20 L19.4,20 L19.4,11.5 L22,11.5 Z'
            ' M12,8.6 A3.2,3.2 0 1,1 11.99,8.6 Z"/>\n'
            '</vector>\n', encoding='utf-8')
        (res / 'values').mkdir(exist_ok=True)
        (res / 'values' / 'notification_colors.xml').write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
            '    <color name="notification_color">#1F6F5C</color>\n</resources>\n', encoding='utf-8')
    if manifest.exists():
        s = manifest.read_text(encoding='utf-8')
        if 'default_notification_icon' not in s:
            meta = ('\n        <meta-data android:name="com.google.firebase.messaging.default_notification_icon"'
                    ' android:resource="@drawable/ic_notification"/>'
                    '\n        <meta-data android:name="com.google.firebase.messaging.default_notification_color"'
                    ' android:resource="@color/notification_color"/>')
            s = re.sub(r'(<application[^>]*>)', lambda m: m.group(1) + meta, s, count=1)
            manifest.write_text(s, encoding='utf-8')
    if plist.exists():
        import plistlib
        data = plistlib.loads(plist.read_bytes())
        modes = data.get('UIBackgroundModes', [])
        if 'remote-notification' not in modes:
            data['UIBackgroundModes'] = modes + ['remote-notification']
        plist.write_bytes(plistlib.dumps(data))
        ent = pathlib.Path('ios/Runner/Runner.entitlements')
        ent.write_bytes(plistlib.dumps({'aps-environment': 'development'}))
    if pbx.exists():
        s = pbx.read_text(encoding='utf-8')
        if 'CODE_SIGN_ENTITLEMENTS' not in s:
            # Runner 타깃 설정에만 (RunnerTests는 번들 ID 끝이 .RunnerTests)
            s, n = re.subn(r'(\n(\s*)PRODUCT_BUNDLE_IDENTIFIER = [\w.]+(?<!RunnerTests);)',
                           lambda m: f'\n{m.group(2)}CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;' + m.group(1), s)
            print(f'iOS 알림 권한(entitlements) 연결: {n}곳')
        # Firebase iOS SDK는 iOS 15 이상
        s = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;', s)
        pbx.write_text(s, encoding='utf-8')
    print('푸시 알림 설정: Android 알림 아이콘, iOS entitlements·iOS 15')

index = pathlib.Path('web/index.html')
if index.exists():
    s = index.read_text(encoding='utf-8')
    s = re.sub(r'<title>[^<]*</title>', f'<title>{label}</title>', s)
    index.write_text(s, encoding='utf-8')

print(f'앱 이름: {label}')
PY

# Firebase(푸시)는 iOS 15 이상: Podfile이 없으면 Flutter 기본 Podfile을 만들고 최소 버전을 정한다
if grep -q 'firebase_messaging' pubspec.yaml && [ -d ios ]; then
  if [ ! -f ios/Podfile ]; then
    FLUTTER_ROOT=$(cd "$(dirname "$(command -v flutter)")/.." && pwd)
    cp "$FLUTTER_ROOT/packages/flutter_tools/templates/cocoapods/Podfile-ios" ios/Podfile
  fi
  sed -i.bak -E "s/^#? *platform :ios, '[0-9.]+'/platform :ios, '15.0'/" ios/Podfile && rm -f ios/Podfile.bak
  grep -n "platform :ios" ios/Podfile || echo "[주의] Podfile에 iOS 최소 버전을 넣지 못했어요"
fi

# 아이콘: pubspec.yaml에 flutter_launcher_icons 설정이 있고 android·ios 폴더가 있으면 만든다 (웹만 만들 때는 건너뜀)
if grep -q '^flutter_launcher_icons:' pubspec.yaml && [ -d android ] && [ -d ios ]; then
  flutter pub get
  dart run flutter_launcher_icons
fi
