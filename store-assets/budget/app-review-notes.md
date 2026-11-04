# App Review 답변 (한지붕 가계부, Guideline 2.1 Information Needed)

App Store Connect → 앱 → 1.0 → **앱 심사 정보 → 메모**에 아래 영문을 그대로 붙여 넣는다.
화면 녹화는 같은 화면의 **첨부 파일**에 올린다(mp4/mov). 용량 때문에 안 되면 Google Drive 등 "링크가 있는 사람 보기" 링크를 메모 1번에 넣는다.

```
1. Screen recording
The screen recording is attached to this submission (App Review Information > Attachment). It was captured on a physical iPhone running the latest iOS and starts from launching the app. It shows: creating a budget (no sign-up/login), adding/editing/deleting records, list and calendar views, the category filter, category management, the invite code, a join request from a second device and its approval, the content reporting flows (Settings > 신고하기 "Report", reporting a member, and reporting another member's record with the flag icon), blocking a member, leaving, and deleting the budget.

2. Purpose and target audience
Onehouse Budget (한지붕 가계부) is a shared household budget book for families, couples and roommates in Korea. Each budget has an invite code; people who receive the code request to join, and the budget owner (or a co-owner) approves them. Members record their own income and expenses on their own phones and everyone in the budget sees the same records, so a family can manage living expenses together without passing one phone around or using a spreadsheet. It does not connect to banks or cards and does not move money; users type their own records.

3. How to use the main features (no login or credentials needed)
- On first launch the app creates an anonymous device account automatically. There is no registration, login or password.
- Tap "새 가계부 만들기" (Create budget), enter a budget name and a nickname, tap "만들기". A one-time owner recovery code is shown; check "안전한 곳에 저장했어요" and continue.
- Open the budget and tap "+" to add a record: choose 지출 (expense) or 수입 (income), enter an amount, pick a category, tap "저장" (Save). Tap a record to edit or delete it.
- Switch between 목록 (list) and 달력 (calendar) at the top. Tap "필터" (Filter) to show only selected categories.
- The menu icon (가계부 설정 / Settings) shows the invite code, 카테고리 관리 (categories), 멤버 관리 (members: approve, block, report), 신고하기 (report), privacy policy, contact, and 가계부 삭제 (delete budget).
- Sharing needs a second device: choose "초대코드로 참여하기" (Join with invite code), enter the code and a nickname; the owner approves it in Settings > 멤버 관리.

User-generated content safeguards (Guideline 1.2)
- Records are visible only to members the owner approved; there is no public content, feed, search or chat.
- Report: any member can report the budget (Settings > 신고하기), a member (멤버 관리 > member > 신고) or another member's record (open the record > flag icon). Reports are stored on our server and reviewed by the developer within 24 hours; we remove content and block users as needed.
- Block: the owner and co-owners can block a member at any time (멤버 관리 > member > 차단); a blocked member immediately loses access. Any member can leave a budget at any time.
- Contact: dkwkehd2@gmail.com (also in Settings > 문의하기).

Account deletion
The app has no account creation. The anonymous device account only links the phone to its budgets. Owners can delete a budget (Settings > 가계부 삭제) and members can leave it; deleted data is permanently removed from the server after 30 days. Users can also request deletion of all their data by email, as described at https://api.ohsangplay.com/onehouse/budget/privacy#delete

4. External services
- Cloudflare Workers and Cloudflare D1 (our own API server and database that store budgets, records, nicknames and reports).
- Google AdMob (Google Mobile Ads SDK) for a banner ad at the bottom of the main screens. The app does not request App Tracking Transparency and does not use IDFA.
No other third-party services: no login provider, no payment processor, no analytics SDK, no AI service, no bank/card data provider.

5. Regional differences
The app is offered in Korea only, with a Korean user interface. All features and content are the same for every user; there are no region-specific features.

6. Regulated industry / third-party material
Not applicable. The app is a personal record-keeping tool, not a financial service: it does not connect to financial institutions, process payments, transfer money, give financial advice or show third-party content. All content is entered by users.
```
