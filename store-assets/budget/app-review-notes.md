# App Review 답변 (한지붕 가계부, Guideline 2.1 Information Needed)

App Store Connect → 앱 → 1.0 → **앱 심사 정보 → 메모**에 아래 영문을 그대로 붙여 넣는다 (메모는 4,000자 이하, 지금 약 3,400자).
화면 녹화는 같은 화면의 **첨부 파일**에 올린다(mp4/mov). 용량 때문에 안 되면 Google Drive 등 "링크가 있는 사람 보기" 링크를 메모 1번에 넣는다.

```
1. Screen recordings
Two recordings are attached (App Review Information > Attachment), both captured on physical iPhones running the latest iOS.
- Video 1: launching the app, creating a budget without sign-up or login, the main screen, and the invite code in Settings.
- Video 2: a second iPhone joining with the invite code, the owner approving the request in Settings > 멤버 관리 (Members), and the report flow (신고): choosing a reason and sending the report.
Blocking (멤버 관리 > member > 차단) and deleting the budget (Settings > 가계부 삭제) are described in section 3.

2. Purpose and target audience
Onehouse Budget (한지붕 가계부) is a shared household budget book for families, couples and roommates in Korea. Each budget has an invite code; people who receive it request to join and the owner (or a co-owner) approves them. Members record income and expenses on their own phones and everyone sees the same records, so a family can manage living expenses together. It does not connect to banks or cards and does not move money; users type their own records.

3. How to use (no login or credentials needed)
- On first launch the app creates an anonymous device account. No registration, login or password.
- Tap "새 가계부 만들기" (Create budget), enter a budget name and nickname, tap "만들기". Check "안전한 곳에 저장했어요" on the recovery code screen and continue.
- Tap "+" to add a record: 지출 (expense) or 수입 (income), amount, category, "저장" (Save). Tap a record to edit or delete it.
- Switch 목록 (list) / 달력 (calendar) at the top; "필터" (Filter) shows selected categories only.
- The menu icon (Settings) has the invite code, 카테고리 관리 (categories), 멤버 관리 (approve, block, report), 신고하기 (report), privacy policy, contact and 가계부 삭제 (delete budget).
- Sharing needs a second device: "초대코드로 참여하기" (Join with invite code), enter the code and a nickname; the owner approves in Settings > 멤버 관리.

User-generated content (Guideline 1.2)
- Records are visible only to members approved by the owner. No public content, feed, search or chat.
- Report: any member can report the budget (Settings > 신고하기), a member (멤버 관리 > member > 신고) or another member's record (open it > flag icon). Reports are stored on our server and reviewed within 24 hours; we remove content and block users as needed.
- Block: the owner and co-owners can block a member at any time; a blocked member loses access immediately. Anyone can leave a budget at any time.
- Contact: dkwkehd2@gmail.com (Settings > 문의하기).

Account deletion
There is no account creation; the anonymous device account only links the phone to its budgets. Owners can delete a budget and members can leave; deleted data is permanently removed from the server after 30 days. Users can also request deletion by email: https://api.ohsangplay.com/onehouse/budget/privacy#delete

4. External services
- Cloudflare Workers and D1: our own API server and database.
- Google AdMob: a banner ad at the bottom of the main screens. The app does not request App Tracking Transparency or use IDFA.
No login provider, payment processor, analytics SDK, AI service or bank/card data provider.

5. Regional differences
Offered in Korea only, Korean UI. Features and content are the same for all users.

6. Regulated industry / third-party material
Not applicable. It is a personal record-keeping tool, not a financial service: no connection to financial institutions, no payments, transfers or financial advice, and no third-party content.
```
