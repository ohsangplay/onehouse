# App Store 등록 정보 (한지붕 가계부)

화면 순서대로 칸마다 넣을 값을 정리했어요. iOS 빌드·업로드는 Mac 없이 GitHub Actions(`.github/workflows/ios-testflight.yml`, 앱 `budget`)로 해요.

## 기본 값

| 항목 | 값 |
|---|---|
| 번들 ID (iOS) | `com.ohsang.util.onehouse.budget` |
| 패키지명 (Android) | `com.ohsang.util.onehouse.budget` |
| 홈 화면 표시 이름 | 한지붕 가계부 |
| App Store 이름 | 한지붕 가계부 - 함께 쓰는 공유 가계부 |
| 부제 | 초대코드로 가족과 같이 쓰는 가계부 |
| SKU | `onehouse-budget-001` |
| 버전 / 빌드 | 1.0.0 / 자동 (GitHub Actions 실행 번호) |
| 지원 기기 | iPhone 전용 |
| 가격 | 무료 · **하단 배너 광고(AdMob)** · 인앱 결제 없음 |
| 개인정보처리방침 | https://api.ohsangplay.com/onehouse/budget/privacy |
| 안내 페이지 (마케팅 URL) | https://api.ohsangplay.com/onehouse/budget/ |

> 서버 주소는 `https://api.ohsangplay.com/onehouse/budget`이에요 (한지붕 메모와 같은 서버). 앱 안 링크(개인정보처리방침·문의)는 서버 주소를 따라가서 따로 고칠 필요가 없어요.

---

## 0. AdMob 광고 설정 (먼저)

앱 하단에 **Google AdMob 배너**가 들어가 있어요. 실제 광고 ID를 넣지 않으면 Google 테스트 광고로 빌드되고, 업로드 워크플로는 테스트 광고 출시를 막으려고 멈춰요.

1. https://admob.google.com → **앱 → 앱 추가**
   - 플랫폼 **iOS** → "앱이 지원되는 앱 스토어에 등록되어 있나요?" → **아니요** (출시 후 스토어와 연결) → 앱 이름 `한지붕 가계부`
   - 같은 방법으로 **Android** 앱도 하나 더 추가
2. 각 앱에서 **광고 단위 → 배너** → 이름 `가계부 하단 배너` → 만들기
3. 나오는 ID 4개를 GitHub에 넣기: `ohsangplay/onehouse` → Settings → Secrets and variables → Actions → **Variables** 탭 → New repository variable (비밀값이 아니라서 Secrets가 아니라 Variables예요)

| Name | 값 | 모양 |
|---|---|---|
| `BUDGET_ADMOB_APP_ID_IOS` | iOS 앱의 **앱 ID** | `ca-app-pub-1234567890123456~1111111111` (물결 ~) |
| `BUDGET_ADMOB_BANNER_IOS` | iOS 배너의 **광고 단위 ID** | `ca-app-pub-1234567890123456/2222222222` (빗금 /) |
| `BUDGET_ADMOB_APP_ID_ANDROID` | Android 앱의 앱 ID | `ca-app-pub-…~…` |
| `BUDGET_ADMOB_BANNER_ANDROID` | Android 배너의 광고 단위 ID | `ca-app-pub-…/…` |

4. AdMob → **결제** 정보(지급 받을 계좌·세금 정보)는 수익이 쌓이기 전까지만 넣으면 돼요.
5. **app-ads.txt**: AdMob → 앱 → app-ads.txt 설정에 나오는 한 줄을 개발자 웹사이트 도메인 루트에 올려야 광고가 제대로(더 많이) 나와요. 스토어의 개발자 웹사이트/마케팅 URL을 `https://ohsangplay.com`으로 두고 `https://ohsangplay.com/app-ads.txt`에 올리는 걸 추천해요. 출시 뒤에 해도 돼요.
6. 내 폰에서 실제 광고를 반복해서 누르면 계정이 정지될 수 있어요. 확인할 땐 AdMob → 설정 → **테스트 기기**에 내 폰을 등록하세요.

## 1. Certificates, Identifiers & Profiles

https://developer.apple.com/account/resources/identifiers/list

**Identifiers → + → App IDs → 계속 → App → 계속**

| 칸 | 값 |
|---|---|
| Description | `Onehouse Budget` (영문·숫자·공백만 가능) |
| Bundle ID | **Explicit** · `com.ohsang.util.onehouse.budget` |
| Capabilities | 아무것도 체크하지 않음 |
| App Services | 아무것도 체크하지 않음 |

→ **계속 → Register**

인증서·프로파일은 만들지 않아도 돼요. 업로드 워크플로가 관리자 API 키로 클라우드 서명을 써요.

## 2. App Store Connect → 신규 앱

https://appstoreconnect.apple.com/apps → **+ → 신규 앱**

| 칸 | 값 |
|---|---|
| 플랫폼 | iOS |
| 이름 | `한지붕 가계부 - 함께 쓰는 공유 가계부` |
| 기본 언어 | 한국어 |
| 번들 ID | `Onehouse Budget - com.ohsang.util.onehouse.budget` |
| SKU | `onehouse-budget-001` |
| 사용자 액세스 | 전체 액세스 |

이름이 이미 사용 중이라고 나오면: `한지붕 가계부: 가족 공유 가계부` 또는 `한지붕 가계부 - 같이 쓰는 가계부`

## 3. 앱 정보 (일반 → 앱 정보)

| 칸 | 값 |
|---|---|
| 부제 | `초대코드로 가족과 같이 쓰는 가계부` |
| 카테고리 | 기본: **금융** / 보조: **생산성** |
| 콘텐츠 권한 | "타사 콘텐츠를 포함하거나 표시하나요?" → **아니요** |
| 개인정보 처리방침 URL | `https://api.ohsangplay.com/onehouse/budget/privacy` |

**연령 등급 설문**
- 폭력·선정성·공포·약물·욕설·도박·경연: 전부 **없음**
- 무제한 웹 접근: **아니요**
- 사용자 생성 콘텐츠·사용자 간 공유: 가계부는 초대코드 + 방장 승인을 거친 멤버끼리만 보이는 비공개 공유예요.
  "다른 사용자와 콘텐츠를 공유할 수 있나요"처럼 묻는 문항이 있으면 **예**로 답해 주세요.
  공개 게시판·검색·채팅은 없어요.
- 광고: **예** (하단 배너) — 등급에는 영향 없음
- 예상 결과: **4+**

## 4. 앱 개인정보 보호

**시작하기 → "이 앱에서 데이터를 수집합니까?" → 예**

| 데이터 유형 | 용도 | 사용자와 연결 | 추적 |
|---|---|---|---|
| 금융 정보 → **기타 금융 정보** (가계부 금액·수입/지출·카테고리) | 앱 기능 | **예** | 아니요 |
| 사용자 콘텐츠 → **기타 사용자 콘텐츠** (내역 메모·닉네임) | 앱 기능 | **예** | 아니요 |
| 식별자 → **사용자 ID** (앱이 만든 기기 계정, 기기 고유번호·광고 ID 아님) | 앱 기능 | **예** | 아니요 |
| 식별자 → **기기 ID** (AdMob) | 타사 광고 | 아니요 | 아니요 |
| 위치 → **대략적인 위치** (AdMob, IP 기반) | 타사 광고 | 아니요 | 아니요 |
| 사용 데이터 → **제품 상호 작용**, **광고 데이터** (AdMob) | 타사 광고, 분석 | 아니요 | 아니요 |
| 진단 → **충돌 데이터**, **성능 데이터**, **기타 진단 데이터** (AdMob) | 타사 광고, 분석 | 아니요 | 아니요 |

- AdMob(Google 모바일 광고 SDK)이 기기에서 Google로 직접 보내는 항목도 Apple 기준으로는 "앱이 수집"하는 것이라 적어야 해요.
- **추적: 아니요** — 앱 추적 투명성(ATT) 허용을 묻지 않아서 IDFA를 쓰지 않아요. 나중에 ATT 팝업을 넣어 맞춤 광고를 켜면 기기 ID·광고 데이터를 "추적: 예"로 바꿔야 해요.
- **결제 정보·신용 정보는 수집하지 않아요.** 카드번호·계좌번호를 읽거나 저장하지 않고, 이용자가 직접 적은 금액만 저장해요.
- 연락처·이메일·이름·정확한 위치·건강·검색 기록: **수집 안 함**
- Apple 정의상 "기타 금융 정보"는 수입·자산 등 금융 관련 정보 전반이라, 직접 적은 가계부 금액도 여기에 넣는 게 안전해요.

## 5. 가격 및 사용 가능 여부

| 칸 | 값 |
|---|---|
| 가격 | 무료 (0원) |
| 사용 가능 국가 | 대한민국 (처음엔 한국만 추천) |

## 6. 버전 1.0 (iOS 앱 → 1.0 준비 중)

**스크린샷 · iPhone** (6장)
- 6.3" 칸 (1206×2622): `store-assets/budget/out/screenshots/appstore/01~06.png`
- 6.9" 칸이 필수로 나오면 (1320×2868): `store-assets/budget/out/screenshots/appstore-6.9/01~06.png`
- 웹 빌드를 아이폰 크기로 띄워 찍은 실제 앱 화면에 캡션을 입힌 것이에요 (`.github/workflows/store-screenshots-budget.yml`).
  아이폰에서 직접 찍은 걸로 바꾸고 싶으면 `store-assets/budget/raw/01~06.png`를 교체하고 `python3 store-assets/budget/frame_screenshots.py`를 다시 돌리면 돼요.

| 순서 | 화면 | 캡션 |
|---|---|---|
| 1 | 월별 내역 | 가족과 함께 쓰는 가계부 |
| 2 | 달력 | 한 달을 달력으로 한눈에 |
| 3 | 카테고리 필터 | 카테고리로 모아보기 |
| 4 | 내역 추가 | 쓰기는 간단하게 |
| 5 | 카테고리 관리 | 우리 집에 맞는 카테고리 |
| 6 | 멤버 관리 | 방장이 승인해야 들어와요 |

**프로모션 텍스트** (170자)
```
초대코드 하나로 가족과 함께 쓰는 가계부예요. 누가 쓴 내역인지 바로 보이고, 달력과 카테고리 필터로 한 달 지출을 한눈에. 회원가입 없이 바로 시작.
```

**설명** (4,000자)
```
한지붕 가계부는 초대코드 하나로 가족, 부부, 함께 사는 사람과 같이 쓰는 공유 가계부입니다. 회원가입 없이 바로 시작할 수 있어요.

■ 이렇게 써요
· 생활비 가계부를 만들고 가족에게 초대코드를 보내면 끝
· 장보기, 관리비, 학원비를 각자 폰에서 적으면 바로 같이 보여요
· 가계부를 여러 개 만들어 생활비용, 부부 여행용, 경조사용으로 나눠 쓰기

■ 가계부와 초대코드
· 가계부마다 초대코드가 있어요. 코드를 받은 사람이 참여를 요청하면 방장이 승인해야 들어올 수 있어요
· 부방장을 정해 승인을 함께 맡길 수 있고, 필요하면 언제든 멤버를 차단할 수 있어요
· 폰을 바꿔도 기기 이전 코드나 방장 복구코드로 그대로 이어서 써요

■ 쓰기는 간단하게
· 지출·수입, 금액, 카테고리, 메모만 넣으면 끝
· 내역마다 누가 썼는지 닉네임으로 보여요

■ 한눈에 보기
· 목록과 달력 중 편한 걸로 보기. 달력에는 날짜마다 지출·수입이 보여요
· 이번 달 수입·지출·남은 돈을 바로 확인

■ 카테고리
· 공통·지출·수입 카테고리를 따로 만들 수 있어요. 공통은 지출·수입 어디서든 골라요
· 라벨 색으로 공통(회색)·지출(주황)·수입(파랑)을 한눈에 구분
· 카테고리 필터로 원하는 것만 모아 보고, 합계도 바로 확인
· 순서 바꾸기, 이름 바꾸기, 지우기 (지워도 내역은 미분류로 남아요)

■ 개인정보
회원가입과 로그인이 없습니다. 이름, 연락처를 받지 않고, 카드·계좌 정보도 읽지 않습니다. 직접 적은 내역과 닉네임만 서버에 저장되고, 같은 가계부 멤버에게만 보여요. 무료로 쓰실 수 있도록 화면 아래에 배너 광고가 나와요.

문의: dkwkehd2@gmail.com
```

**키워드** (100자, 쉼표로 구분)
```
공유가계부,부부가계부,가족가계부,커플가계부,가계부,생활비,지출관리,용돈기입장,가계부달력,초대코드,같이쓰기,가족,부부,살림,예산
```

**새로운 기능** (1.0은 비워 둠)

| 칸 | 값 |
|---|---|
| 지원 URL | `https://api.ohsangplay.com/onehouse/budget/privacy#contact` |
| 마케팅 URL | `https://api.ohsangplay.com/onehouse/budget/` |
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
Onehouse Budget is a shared household budget app for families. There is no sign-up or login: the app creates an anonymous device account on first launch. It does not connect to banks or cards and does not move money; users type their own income and expense records.

How to test on one device:
1. Tap "새 가계부 만들기" (Create budget), enter a name and a nickname, tap "만들기". A one-time owner recovery code is shown; check "안전한 곳에 저장했어요" and continue.
2. Open the budget and tap "+" to add a record: choose expense (지출) or income (수입), enter an amount, pick a category, and tap "저장" (Save). Tap a record to edit or delete it.
3. Switch between list (목록) and calendar (달력) at the top. Tap "필터" to filter by categories.
4. The menu icon (가계부 설정) shows the invite code, category management (카테고리 관리), member management, privacy policy and contact.

Sharing (needs a second device or simulator): on the second device choose "초대코드로 참여하기" (Join with invite code), enter the code and a nickname. The owner approves the request in Settings → 멤버 관리 (Members).

Records are visible only to members approved by the budget owner; there is no public content, search or chat. Owners and co-owners can block members at any time. The app shows a Google AdMob banner at the bottom of the main screens; it does not request App Tracking Transparency and does not use IDFA. No third-party analytics.
```

## 7. 빌드 업로드 (GitHub Actions)

**저장소 Secrets** (`ohsangplay/onehouse` → Settings → Secrets and variables → Actions)
한지붕 메모와 **같은 저장소·같은 Secrets**를 써요. 이미 넣었으면 그대로 두면 돼요.

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

**저장소 Variables**: 0번의 `BUDGET_ADMOB_APP_ID_IOS`, `BUDGET_ADMOB_BANNER_IOS`가 있어야 업로드돼요 (없으면 "AdMob ID 없음"으로 멈춤).

**실행**: Actions → **iOS 빌드 → TestFlight 업로드** → Run workflow → 앱 **budget**, upload 체크
- 15~25분 뒤 App Store Connect → TestFlight에 빌드가 보여요 (처리 10~30분 추가).
- 앱은 운영 서버 `https://api.ohsangplay.com/onehouse/budget`에 붙어요 (빌드에 기본값으로 들어가 있음).
- TestFlight → 내부 테스트에 본인을 추가하고, 아이폰 TestFlight 앱으로 설치해서 확인하세요.
- 수출 규정 질문은 빌드에 `ITSAppUsesNonExemptEncryption = NO`가 들어가 있어서 따로 안 물어봐요.
- 실패하면 실행 로그의 빨간 단계를 알려주세요.

## 8. 심사 제출

6단계 화면 오른쪽 위 **심사에 추가 → 제출**. 보통 1~2일 안에 결과가 나와요.

**자주 걸리는 부분**
- **5.1.1 개인정보처리방침**: 링크가 열려야 하고, 앱 안(가계부 설정 → 개인정보처리방침, 시작 화면 아래)에서도 열려요.
- **5.1.1(v) 계정 삭제**: 회원가입이 없어서 해당하지 않을 가능성이 높아요. 그래도 거절되면 설정에 "내 데이터 모두 지우기"(모든 가계부 나가기 + 기기 계정 삭제)를 넣으면 돼요.
- **금융 카테고리**: 은행·카드 연동이나 송금이 없는 기록용 가계부라 금융 앱 추가 서류는 필요 없어요. 심사 메모 첫 문단에 적어 뒀어요.
- **1.2 사용자 생성 콘텐츠**: 공개 공간이 없고 승인된 멤버끼리만 보이며, 방장·부방장 차단과 문의 이메일이 있어요.
- **2.3 정확한 메타데이터**: 스크린샷은 실제 앱 화면이에요. 지적받으면 아이폰에서 직접 찍은 걸로 바꾸세요.
- **4.2 최소 기능**: 네이티브 앱(Flutter)이고 공유·달력·카테고리 필터·멤버 관리가 있어 괜찮을 가능성이 높아요.
