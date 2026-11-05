# App Review 답변 (한지붕 메모, Guideline 2.1 Information Needed)

App Store Connect → 앱 → 1.0 → **앱 심사 정보 → 메모**에 아래 영문을 그대로 붙여 넣는다 (메모는 4,000자 이하).
화면 녹화는 같은 화면의 **첨부 파일**에 올린다(mp4/mov). 용량 때문에 안 되면 Google Drive 등 "링크가 있는 사람 보기" 링크를 메모 1번에 넣는다.

## 녹화 순서 (실제 아이폰 2대, 최신 iOS)

**영상 1 (방장 폰)**
1. 홈 화면에서 앱 아이콘을 눌러 실행하는 장면부터 시작
2. 새 메모집 만들기 → 메모집 이름·닉네임 → 만들기 → 복구코드 "안전한 곳에 저장했어요" → 시작
3. 새 메모 → 글 메모 하나 쓰기(자동 저장) → 뒤로
4. 새 메모 → 체크리스트 하나 만들고 항목 2~3개 → 하나 체크
5. 메모 길게 누르기 → 맨 위에 고정 / 휴지통으로 → 휴지통 열어서 되살리기·완전히 지우기
6. 설정(톱니) → 초대코드 보이기

**영상 2 (두 번째 폰 + 방장 폰)**
1. 두 번째 폰에서 앱 실행 → 초대코드로 참여하기 → 코드·닉네임 → 승인 대기 화면
2. 방장 폰: 메모집 카드의 "참여 요청 1" → 설정 → 멤버 관리 → 승인
3. 두 번째 폰: 새로고침 → 메모집 들어가서 방장이 쓴 메모 열기 → ⋮ → **신고하기** → 사유 고르고 보내기
4. 두 번째 폰: 설정 → **신고하기**(메모집 신고) 화면만 보여 주기
5. 방장 폰: 멤버 관리 → 두 번째 멤버 누르기 → **신고 / 차단** 메뉴 보여 주기 → 차단
6. (선택) 두 번째 폰에서 메모집이 사라진 것 확인

## 메모 (영문)

```
1. Screen recordings
Two recordings are attached (App Review Information > Attachment), both captured on physical iPhones running the latest iOS.
- Video 1: launching the app, creating a notebook without sign-up or login, writing a text memo and a checklist, pinning, moving a memo to the trash and restoring / permanently deleting it, and the invite code in Settings.
- Video 2: a second iPhone joining with the invite code, the owner approving the request in Settings > 멤버 관리 (Members), the second user reporting a memo (memo > ⋯ > 신고하기) and the notebook (Settings > 신고하기), and the owner opening a member's menu to report or block (차단) them.

2. Purpose and target audience
Onehouse Memo (한지붕 메모) is a shared memo app for families, couples and small groups of friends in Korea. Each notebook has an invite code; people who receive it request to join and the owner (or a co-owner) approves them. Members write text memos and checklists together, such as a grocery list checked off at the store, travel packing lists, weekly dinner menus or school schedules. It solves "where did we write that?" and "who already bought the milk?" without a messenger thread or sign-up. Edits from different people are merged automatically, and checklists can be checked offline.

3. How to use (no login or credentials needed)
- On first launch the app creates an anonymous device account. No registration, login or password.
- Tap "새 메모집 만들기" (Create notebook), enter a notebook name and nickname, tap "만들기". Check "안전한 곳에 저장했어요" on the recovery code screen and continue.
- Tap "새 메모" (New memo) > "글 메모" (text memo) or "체크리스트" (checklist). Text memos save automatically.
- Long-press a memo to pin it, move it to the trash or report it. The trash icon at the top restores memos within 30 days or deletes them permanently.
- The gear icon (Settings) has the invite code, 멤버 관리 (approve, block, report), 신고하기 (report), privacy policy, contact, leave notebook and 메모집 삭제 (delete notebook).
- Sharing needs a second device: "초대코드로 참여하기" (Join with invite code), enter the code and a nickname; the owner approves in Settings > 멤버 관리.

User-generated content (Guideline 1.2)
- Memos are visible only to members approved by the owner. No public content, feed, search or chat.
- Report: any member can report another member's memo (open it > ⋯ > 신고하기, or long-press it in the list), the notebook (Settings > 신고하기) or a member (멤버 관리 > member > 신고). Reports are stored on our server and reviewed within 24 hours; we remove content and block users as needed.
- Block: the owner and co-owners can block a member at any time; a blocked member loses access immediately. Anyone can leave a notebook at any time.
- Contact: dkwkehd2@gmail.com (Settings > 문의하기).

Account deletion
There is no account creation; the anonymous device account only links the phone to its notebooks. Users can permanently delete memos from the trash, owners can delete a notebook and members can leave; deleted notebooks are permanently removed from the server after 30 days. Users can also request deletion by email: https://api.ohsangplay.com/onehouse/memo/privacy#delete

4. External services
- Cloudflare Workers and D1: our own API server and database.
- Google AdMob: a banner ad at the bottom of list screens (no ads on editing screens). The app does not request App Tracking Transparency or use IDFA.
No login provider, payment processor, analytics SDK or AI service.

5. Regional differences
Offered in Korea only, Korean UI. Features and content are the same for all users.

6. Regulated industry / third-party material
Not applicable. It is a personal note-taking tool with no third-party content.
```
