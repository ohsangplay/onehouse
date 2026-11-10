# 한지붕 가계부 — App Review 4.3 / 4.2.6 (스팸·템플릿) 회신

2026-11-10 반려에 대한 회신. **다시 제출하지 말고** App Review 회신창에 아래 영문을 보낸다 (회신창 4,000자 제한, 이 글 3,899자).

- 4번 베타 테스트: 프로토타입 검토(10/31~11/3)에서 반영한 화면 변경 + TestFlight 8~10. 가족·지인이 실제로 같이 써 봤다면 덧붙인다.
- 5~7번은 한지붕 메모 회신과 같은 구조. 메모 회신 5번의 "payment methods, per-member statistics"는 가계부에 없는 기능이라, 메모 쪽에서 다시 물어보면 고쳐서 답할 것.
- 다시 반려되면: 가계부·메모를 한 앱(한지붕)으로 합치는 방안.

```
Hello, thank you for the review. We believe the app meets 4.3 and 4.2.6, so we answer each question below.

1. What it does
A private shared account book for one household. The owner creates a budget and shares an invite code; family members request to join and the owner (or a co-owner) approves them. Each member records income and expenses on their own phone, and every record shows who wrote it. No sign-up: an anonymous device account is created on first launch. The month can be viewed as a list grouped by day or as a calendar with daily income/expense, with income, expense and balance totals. Categories are shared by the household and typed as common, expense-only or income-only (color-coded); a full-screen category filter shows matching records and their total. Owners can block members, anyone can report, and the owner can recover the budget on a new phone with a recovery code.

2. Users
Korean households of 2-6 people who share living expenses: couples, parents with children, people living with elderly parents, roommates. Often includes members who will not create accounts (grandparents, teenagers). Korea only, Korean UI.

3. Gap
Most Korean budget apps are personal: they read card and bank messages for one person, and sharing needs every member to sign up, or one phone is passed around. Families otherwise use a shared spreadsheet or a messenger chat, where totals and categories are lost. Our app needs only an invite code, works across iPhone and Android, lets the owner control who joins, shows who wrote each record, and keeps one set of household categories with a filter to see, for example, this month's spending on children.

4. Beta testing
Prototype builds (Oct 31 - Nov 3) were reviewed screen by screen, then TestFlight builds 8-10 and Android test builds (Nov 4-5) were tested on iPhones and an Android phone. Feedback applied: the category filter was moved to a full-screen sheet with removable labels and a "+N" chip when labels overflow; a calendar view was added next to the list; common categories usable for both income and expense were added; label colors by category type; the filter button did not respond on some screens (fixed); the banner area could stay blank while an ad loaded (now collapses); reporting of members and records was added.

5. Suite
Standalone, in a two-app "Onehouse" series that shares the same invite/approval model. Onehouse Budget records money: amounts, income/expense, typed categories, monthly totals, a calendar of daily totals and a category filter with sums. Onehouse Memo has none of these; it is a shared notebook for free text and checklists with concurrent editing. Other apps on our account are unrelated games and utilities.

6. Could it be inside another app?
Technically yes, but we kept it separate because (a) many families want a shared budget but no shared notes, and the reverse; (b) households often share finances with fewer people than a shopping list, so financial records stay in their own app with their own member list; (c) one purpose per app is simpler for elderly and young members.

7. Shared code on our account
Yes. Both Onehouse apps use our own Flutter package for the sharing layer only: anonymous device account, invite code join, owner approval, co-owners, block/report, recovery and device-transfer codes, settings and member screens. Both use our backend (Cloudflare Worker) with separate endpoints and data. Everything else is specific to Budget: record entry with amount formatting, typed categories and category management, monthly list and calendar, totals, and the category filter.

8. Third-party code
No, only standard frameworks (Flutter, Google Mobile Ads, http, flutter_secure_storage, url_launcher).

9. Client or template
No. Concept, content and branding are our own (developer: 오상플레이). Developed by us, not from a commercial template or app generation service.

Thank you.
```
