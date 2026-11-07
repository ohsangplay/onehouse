# App Store 등록 정보 (한지붕 메모)

화면 순서대로 칸마다 넣을 값을 정리했어요. iOS 빌드·업로드는 Mac 없이 GitHub Actions(`.github/workflows/ios-testflight.yml`, 앱 `memo`)로 해요.

## 기본 값

| 항목 | 값 |
|---|---|
| 번들 ID (iOS) | `com.ohsang.util.onehouse.memo` |
| 패키지명 (Android) | `com.ohsang.util.onehouse.memo` |
| 홈 화면 표시 이름 | 한지붕 메모 |
| App Store 이름 | 한지붕 메모 - 함께 쓰는 공유 메모장 |
| 부제 | 초대코드로 가족과 같이 쓰는 메모 |
| SKU | `onehouse-memo-001` |
| 버전 / 빌드 | 1.0.0 / 자동 (GitHub Actions 실행 번호) |
| 지원 기기 | iPhone 전용 |
| 가격 | 무료 · 하단 배너 광고(AdMob) · 인앱 결제 없음 |
| 개인정보처리방침 | https://api.ohsangplay.com/onehouse/memo/privacy |
| 웹사이트 (마케팅 URL) | https://ohsangplay.com (app-ads.txt 있는 주소) |
| 지원 URL | https://api.ohsangplay.com/onehouse/memo/privacy#contact |

> 서버 주소는 `https://api.ohsangplay.com/onehouse/memo`예요 (가계부는 `…/onehouse/budget`, 같은 서버). 예전 주소 `onehouse-api.shark-keeper.workers.dev`도 당분간 열려 있지만, 스토어에는 위 새 주소를 넣어 주세요. 앱 안 링크는 서버 주소를 따라가서 따로 고칠 필요가 없어요.

---

## 1. Certificates, Identifiers & Profiles

https://developer.apple.com/account/resources/identifiers/list

**Identifiers → + → App IDs → 계속 → App → 계속**

| 칸 | 값 |
|---|---|
| Description | `Onehouse Memo` (영문·숫자·공백만 가능) |
| Bundle ID | **Explicit** · `com.ohsang.util.onehouse.memo` |
| Capabilities | 아무것도 체크하지 않음 |
| App Services | 아무것도 체크하지 않음 |

→ **계속 → Register**

인증서·프로파일은 만들지 않아도 돼요. 업로드 워크플로가 관리자 API 키로 클라우드 서명을 써요 (환율 기록과 같음).

## 2. App Store Connect → 신규 앱

https://appstoreconnect.apple.com/apps → **+ → 신규 앱**

| 칸 | 값 |
|---|---|
| 플랫폼 | iOS |
| 이름 | `한지붕 메모 - 함께 쓰는 공유 메모장` |
| 기본 언어 | 한국어 |
| 번들 ID | `Onehouse Memo - com.ohsang.util.onehouse.memo` |
| SKU | `onehouse-memo-001` |
| 사용자 액세스 | 전체 액세스 |

이름이 이미 사용 중이라고 나오면: `한지붕 메모: 가족 공유 메모장` 또는 `한지붕 메모 - 같이 쓰는 메모`

## 3. 앱 정보 (일반 → 앱 정보)

| 칸 | 값 |
|---|---|
| 부제 | `초대코드로 가족과 같이 쓰는 메모` |
| 카테고리 | 기본: **생산성** / 보조: **라이프스타일** |
| 콘텐츠 권한 | "타사 콘텐츠를 포함하거나 표시하나요?" → **아니요** |
| 개인정보 처리방침 URL | `https://api.ohsangplay.com/onehouse/memo/privacy` |

**연령 등급 설문**
- 폭력·선정성·공포·약물·욕설·도박·경연: 전부 **없음**
- 무제한 웹 접근: **아니요**
- 사용자 생성 콘텐츠·사용자 간 공유: 메모는 초대코드 + 방장 승인을 거친 멤버끼리만 보이는 비공개 공유예요.
  설문 문항이 "다른 사용자와 콘텐츠를 공유할 수 있나요"처럼 묻는다면 **예**로 답해 주세요 (정직하게 답하는 게 안전해요).
  공개 게시판·검색·채팅은 없어요.
- **광고(Advertising): 예** — 하단 AdMob 배너가 있어요. "아니요"로 두면 자동 검사에서 "Advertising 미선택"으로 심사가 멈춰요 (2026-11 실제로 반려됨)
- 예상 결과: **4+** (공유 항목을 "예"로 해도 보통 4+~9+ 사이)

## 4. 앱 개인정보 보호

**시작하기 → "이 앱에서 데이터를 수집합니까?" → 예**

| 데이터 유형 | 용도 | 사용자와 연결 | 추적 |
|---|---|---|---|
| 사용자 콘텐츠 → **기타 사용자 콘텐츠** (메모·체크리스트·닉네임) | 앱 기능 | **예** | 아니요 |
| 식별자 → **사용자 ID** (앱이 만든 기기 계정, 기기 고유번호·광고 ID 아님) | 앱 기능 | **예** | 아니요 |
| 식별자 → **기기 ID** (AdMob) | 타사 광고 | 아니요 | 아니요 |
| 위치 → **대략적인 위치** (AdMob, IP 기반) | 타사 광고 | 아니요 | 아니요 |
| 사용 데이터 → **제품 상호 작용**, **광고 데이터** (AdMob) | 타사 광고, 분석 | 아니요 | 아니요 |
| 진단 → **충돌 데이터**, **성능 데이터**, **기타 진단 데이터** (AdMob) | 타사 광고, 분석 | 아니요 | 아니요 |

- 연락처·이메일·이름·정확한 위치·건강·금융·검색 기록: **수집 안 함**
- 메모·닉네임의 "사용자와 연결"은 기기 계정에 묶이기 때문에 **예**예요 (실명·연락처와는 연결되지 않음).
- AdMob(Google 모바일 광고 SDK)이 기기에서 Google로 직접 보내는 항목도 Apple 기준으로는 "앱이 수집"하는 것이라 적어야 해요.
- **추적: 아니요** — 앱 추적 투명성(ATT) 허용을 묻지 않아서 IDFA를 쓰지 않아요 (한지붕 가계부와 같은 답).

## 5. 가격 및 사용 가능 여부

| 칸 | 값 |
|---|---|
| 가격 | 무료 (0원) |
| 사용 가능 국가 | 대한민국 (처음엔 한국만 추천) |

## 6. 버전 1.0 (iOS 앱 → 1.0 준비 중)

**스크린샷 · iPhone** (6장)
- 6.3" 칸 (1206×2622): `store-assets/memo/out/screenshots/appstore/01~06.png`
- 6.9" 칸이 필수로 나오면 (1320×2868): `store-assets/memo/out/screenshots/appstore-6.9/01~06.png`
- 웹 빌드를 아이폰 크기로 띄워 찍은 화면에 캡션을 입힌 것이에요. 실제 앱과 화면이 같지만, TestFlight로 아이폰에 설치한 뒤 직접 찍은 걸로 바꾸고 싶으면 `store-assets/memo/raw/01~06.png`를 교체하고 `python3 store-assets/memo/frame_screenshots.py`를 다시 돌리면 돼요.

| 순서 | 화면 | 캡션 |
|---|---|---|
| 1 | 메모 목록 | 가족과 함께 쓰는 메모장 |
| 2 | 체크리스트 | 장보기는 체크리스트로 |
| 3 | 보는 중 표시 | 지금 누가 고치는지 보여요 |
| 4 | 충돌 화면 | 동시에 고쳐도 걱정 없게 |
| 5 | 오프라인 체크 | 지하 마트에서도 체크 |
| 6 | 멤버 관리 | 방장이 승인해야 들어와요 |

**프로모션 텍스트** (170자)
```
초대코드 하나로 가족과 함께 쓰는 메모장이에요. 장보기는 체크리스트로, 일정은 글 메모로. 같이 고쳐도 자동으로 합쳐지고, 지하 마트에서도 체크할 수 있어요. 회원가입 없음.
```

**설명** (4,000자)
```
한지붕 메모는 초대코드 하나로 가족, 연인, 친구와 함께 쓰는 공유 메모장입니다. 회원가입 없이 바로 시작할 수 있어요.

■ 이렇게 써요
· 장보기 목록을 같이 채우고, 마트에서 하나씩 체크
· 여행 준비물, 이번 주 저녁 메뉴, 아이 학원 일정, 공과금 날짜를 한곳에
· 메모집을 여러 개 만들어 가족용, 부부용, 친구 모임용으로 나눠 쓰기

■ 메모집과 초대코드
· 메모집마다 초대코드가 있어요. 코드를 받은 사람이 참여를 요청하면 방장이 승인해야 들어올 수 있어요
· 부방장을 정해 승인을 함께 맡길 수 있고, 필요하면 언제든 멤버를 차단할 수 있어요
· 폰을 바꿔도 기기 이전 코드나 방장 복구코드로 그대로 이어서 써요

■ 글 메모와 체크리스트
· 글 메모는 고치다 멈추면 자동으로 저장돼요
· 체크리스트는 누가 체크했는지 함께 보여요
· 자주 보는 메모는 맨 위에 고정
· 지운 메모는 휴지통에서 30일 동안 되살릴 수 있고, 바로 완전히 지울 수도 있어요

■ 같이 고쳐도 안전하게
· 지금 누가 같은 메모를 보고 있거나 고치고 있는지 보여줘요
· 서로 다른 줄을 고쳤으면 자동으로 합쳐서 저장해요
· 같은 줄을 동시에 고쳤을 때만 두 내용을 나란히 보여주고 고를 수 있어요. "둘 다 남기기"를 고르면 내 글은 새 메모로 저장돼요

■ 인터넷이 끊겨도
· 마지막으로 본 메모는 오프라인에서도 볼 수 있어요
· 쓰던 중에 끊기면 기기에 남겨 두었다가 연결되면 이어서 저장해요
· 체크리스트 체크는 오프라인에서도 되고, 연결되면 알아서 반영돼요

■ 개인정보
회원가입과 로그인이 없고, 이름·연락처를 받지 않습니다. 함께 쓰는 메모와 닉네임만 서버에 저장되고, 같은 메모집 멤버에게만 보여요. 목록 화면 아래에는 배너 광고가 나오며, 메모 내용은 광고에 쓰이지 않아요.

한지붕 시리즈: 한지붕 가계부도 곧 만나요.

문의: dkwkehd2@gmail.com
```

**키워드** (100자, 쉼표로 구분, 이름·부제에 있는 단어는 빼도 돼요)
```
공유메모,메모장,가족메모,체크리스트,장보기,할일,투두,노트,부부,준비물,동시편집,초대코드,같이쓰기,가족,메모공유
```

**새로운 기능** (1.0은 비워 둠)

| 칸 | 값 |
|---|---|
| 지원 URL | `https://api.ohsangplay.com/onehouse/memo/privacy#contact` |
| 마케팅 URL | `https://ohsangplay.com` (app-ads.txt가 있는 주소, 아래 "광고" 참고) |
| 빌드 | 7단계에서 업로드한 빌드 선택 |
| 저작권 | `2026 오상원` (개인 계정이면 본인 이름, 사업자 명의면 `2026 오상플레이`) |
| 버전 출시 | 이 버전을 수동으로 출시 |

**앱 심사 정보**

| 칸 | 값 |
|---|---|
| 로그인 필요 | 체크 해제 (로그인 없음) |
| 연락처 | 이름 · 전화번호 · `dkwkehd2@gmail.com` |
| 첨부 파일 | 없음 (필요하면 두 기기로 함께 쓰는 화면 녹화) |

메모:
```
Onehouse Memo is a shared memo app for families. There is no sign-up or login: the app creates an anonymous device account on first launch.

How to test on one device:
1. Tap "새 메모집 만들기" (Create notebook), enter a notebook name and a nickname, tap "만들기". A one-time owner recovery code is shown; check "안전한 곳에 저장했어요" and continue.
2. Tap "새 메모" (New memo) → "글 메모" (text memo) or "체크리스트" (checklist). Text memos save automatically. Long-press a memo to pin it or move it to the trash. The trash (icon at the top of the memo list) can restore a memo within 30 days, or delete it permanently right away.
3. Settings (gear icon) shows the invite code, member management, privacy policy and contact.

Sharing (needs a second device or simulator): on the second device choose "초대코드로 참여하기" (Join with invite code), enter the code and a nickname. The owner approves the request in Settings → 멤버 관리 (Members). Members can edit any memo; if two people edit different lines at the same time the server merges them, and if they edit the same line a comparison screen lets the user choose.

Notes are visible only to members approved by the notebook owner; there is no public content, search or chat. Owners and co-owners can block members at any time.

Ads: list screens (notebook list, memo list, trash) show a Google AdMob banner at the bottom. Editing screens have no ads. The app does not request App Tracking Transparency and does not use the IDFA; there is no other analytics or tracking SDK.

Data deletion: memos can be deleted permanently from the trash; the owner can delete the whole notebook in Settings. See the privacy policy, section "데이터 삭제 요청 방법" (#delete).
```

## 7. 빌드 업로드 (GitHub Actions)

**저장소 Secrets** (`ohsangplay/onehouse` → Settings → Secrets and variables → Actions)
환율 기록 저장소에 넣은 값과 **같은 값**을 이 저장소에도 넣으면 돼요. 이름이 정확히 같아야 해요.

| Name | 값 | 찾는 곳 |
|---|---|---|
| `APPLE_TEAM_ID` | 10자리 팀 ID | developer.apple.com/account → 멤버십 세부사항 |
| `ASC_KEY_ID` | API 키 ID | App Store Connect → 사용자 및 액세스 → 통합 → App Store Connect API |
| `ASC_ISSUER_ID` | 발급자 ID | 같은 화면 위쪽 |
| `ASC_KEY_P8_BASE64` | p8 파일의 base64 | 아래 명령 |

- API 키 역할은 **관리자(Admin)** 여야 클라우드 서명이 돼요.
- p8 → base64 (PowerShell, 결과가 클립보드에 복사됨):
  ```powershell
  [Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\Downloads\AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard
  ```

**실행**: Actions → **iOS 빌드 → TestFlight 업로드** → Run workflow → 앱 **memo**, upload 체크
- 15~25분 뒤 App Store Connect → TestFlight에 빌드가 보여요 (처리 10~30분 추가).
- 앱은 운영 서버 `https://api.ohsangplay.com/onehouse/memo`에 붙어요 (빌드에 기본값으로 들어가 있음).
- TestFlight → 내부 테스트에 본인을 추가하고, 아이폰 TestFlight 앱으로 설치해서 확인하세요.
- 수출 규정 질문은 빌드에 `ITSAppUsesNonExemptEncryption = NO`가 들어가 있어서 따로 안 물어봐요.
- 실패하면 실행 로그의 빨간 단계를 알려주세요.

## 광고 (AdMob 하단 배너)

메모집 목록, 메모 목록, 휴지통 화면 맨 아래에 **Google AdMob 적응형 배너**가 나와요 (한지붕 가계부와 같은 코드·방식). 메모를 쓰는 화면(글 메모, 체크리스트, 충돌 화면)은 잘못 누르기 쉬워서 넣지 않았어요(AdMob 정책).

실제 광고 ID를 넣지 않으면 Google 테스트 광고로 빌드되고, 업로드 워크플로(TestFlight·Play 자동 업로드)는 테스트 광고 출시를 막으려고 멈춰요.

1. https://admob.google.com (4S 챌린지와 같은 계정) → **앱 → 앱 추가**
   - 플랫폼 **iOS** → "앱이 지원되는 앱 스토어에 등록되어 있나요?" → **아니요** → 앱 이름 `한지붕 메모`
   - 같은 방법으로 **Android** 앱도 하나 더 추가
2. 각 앱에서 **광고 단위 → 배너** → 이름 `메모 하단 배너` → 만들기
3. 나오는 ID 4개를 GitHub에 넣기: `ohsangplay/onehouse` → Settings → Secrets and variables → Actions → **Variables** 탭 → New repository variable (비밀값이 아니라서 Secrets가 아니라 Variables예요)

| Name | 값 | 모양 |
|---|---|---|
| `MEMO_ADMOB_APP_ID_IOS` | iOS 앱의 **앱 ID** | `ca-app-pub-3934873497580609~…` (물결 ~) |
| `MEMO_ADMOB_BANNER_IOS` | iOS 배너의 **광고 단위 ID** | `ca-app-pub-3934873497580609/…` (빗금 /) |
| `MEMO_ADMOB_APP_ID_ANDROID` | Android 앱의 앱 ID | `ca-app-pub-…~…` |
| `MEMO_ADMOB_BANNER_ANDROID` | Android 배너의 광고 단위 ID | `ca-app-pub-…/…` |

4. **app-ads.txt**: `https://ohsangplay.com/app-ads.txt`에 아래 한 줄이 있어야 광고가 제대로 나와요 (4S 챌린지와 같은 게시자). 스토어의 웹사이트(마케팅 URL)를 `https://ohsangplay.com`으로 두면 AdMob이 여기서 찾아요. 출시 뒤에 해도 돼요.
   ```
   google.com, pub-3934873497580609, DIRECT, f08c47fec0942fa0
   ```
5. 출시 후 AdMob → 앱 → 앱 설정 → **앱 스토어 연결**로 스토어 앱을 연결하면 AdMob 앱 검토가 시작돼요. 통과 전에는 광고가 적게 나올 수 있어요.

**주의**
- 내 폰에서 실제 광고를 반복해서 누르면 계정이 정지될 수 있어요. 확인할 땐 AdMob → 설정 → **테스트 기기**에 내 폰을 등록하세요. 디버그 빌드(`flutter run`)는 항상 테스트 광고예요.
- iOS는 추적 허용(ATT)을 묻지 않아요. IDFA를 쓰지 않고 맞춤형이 아닌 광고가 나올 수 있어요.
- 유럽(EEA·영국)에 내면 동의 팝업(UMP)이 필요해요. 처음엔 **대한민국만** 출시하세요.

## 8. 심사 제출

6단계 화면 오른쪽 위 **심사에 추가 → 제출**. 보통 1~2일 안에 결과가 나와요.

**자주 걸리는 부분**
- **5.1.1 개인정보처리방침**: 링크가 열려야 하고, 앱 안(메모집 설정 → 개인정보처리방침, 시작 화면 아래)에서도 열려요. 서버 배포 후 주소가 열리는지 한 번 확인해 주세요.
- **5.1.1(v) 계정 삭제**: 회원가입이 없어서 해당하지 않을 가능성이 높아요. 개인정보처리방침에 삭제 방법(`#delete`)이 있고, 휴지통에서 메모를 바로 완전히 지울 수 있어요. 그래도 "계정을 만드는 앱"으로 판단해 거절되면, 설정에 "내 데이터 모두 지우기"(모든 메모집 나가기 + 기기 계정 삭제)를 넣으면 돼요.
- **1.2 사용자 생성 콘텐츠**: 공개 공간이 없고 승인된 멤버끼리만 보이며, 방장·부방장 차단과 문의 이메일이 있어요. 공개 커뮤니티로 오해받으면 심사 메모의 마지막 문단을 근거로 답하면 돼요.
- **2.3 정확한 메타데이터**: 스크린샷은 실제 앱 화면이에요. 상태바 없이 캡션 틀 안에 들어가 있어서 문제없지만, 지적받으면 아이폰에서 직접 찍은 걸로 바꾸세요.
- **4.2 최소 기능**: 네이티브 앱(Flutter)이고 오프라인·동시 수정·멤버 관리가 있어 괜찮을 가능성이 높아요.
