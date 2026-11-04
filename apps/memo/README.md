# 한지붕 메모 (Flutter)

패키지명·번들 ID: `com.ohsang.util.onehouse.memo` · 홈 화면 이름: 한지붕 메모

메모집별 초대코드로 가족이 함께 쓰는 메모장. 글 메모와 체크리스트.

## 처음 한 번: 플랫폼 폴더 생성

```bash
scripts/flutter_platforms.sh apps/memo memo "한지붕 메모"
cd apps/memo && flutter pub get
flutter run                                                   # 운영 서버
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787   # 로컬 서버
```

## 함께 고치기

| 상황 | 동작 |
| --- | --- |
| 아무도 안 고침 | 2.5초 멈추면 자동 저장, 화면을 나갈 때도 저장 |
| 다른 사람이 **다른 줄**을 먼저 고침 | 서버가 줄 단위로 합쳐서 저장, 화면에 바로 반영 + "○○님이 고친 내용과 합쳐서 저장했어요" |
| 다른 사람이 **같은 줄**을 다르게 고침 | 충돌 화면: 저장된 내용 / 내가 쓴 내용 탭, 다른 줄 색칠 → 둘 다 남기기(내 것은 "(내 수정본)" 새 메모) · 저장된 내용 쓰기(내 것은 클립보드) · 내 내용으로 저장 |
| 제목을 서로 다르게 고침 | 충돌 (제목은 통째로 비교) |
| 저장하는 사이 더 씀 | 쓴 글은 지키고, 다음 저장에서 서버가 다시 합침 |
| 다른 사람이 메모를 지움 | "새 메모로 저장" / "버리기" |
| 체크리스트 항목 | 한 줄씩 따로 저장 → 다른 항목은 동시에 고쳐도 안 부딪힘. 같은 항목 글자만 선택 창 |
| 체크·해제 | 마지막에 누른 사람이 이김 |
| 보고 있는 사람 | 메모를 연 동안 15초마다 신호 → "지금 엄마님이 고치고 있어요". 보고만 있는 동안 누가 고치면 새 내용으로 |

## 오프라인

연결 여부는 와이파이 상태가 아니라 **실제로 서버에 닿았는지**로 판단해요(요청 실패 → 오프라인, 5초마다 확인).

- 읽기: 마지막으로 받은 메모집·메모를 기기에 보관해서 보여줌
- 새 메모·메모집, 수정, 삭제, 항목 추가·글자 수정·순서 바꾸기: 비활성화 + 상단 "오프라인이에요" 띠
- 고치던 중 끊김: 쓰던 글은 초안으로 기기에 남고 저장 버튼만 꺼짐. 연결되면 자동으로 이어서 저장(서버가 병합)
- 앱을 꺼도 초안은 남음 (목록에 "저장 안 됨", 새 메모는 "쓰던 새 메모가 있어요")
- 체크·해제: 오프라인에서도 가능. 모아 뒀다가 연결되면 순서대로 보내고, 그사이 지워진 항목은 버림

## 구조

```
lib/
  main.dart                    앱 시작, 앱으로 돌아오면 연결 확인·오프라인 체크 전송
  config.dart                  API 주소, 자동 저장·보는 중 주기, 공간 설정(memoSpace: 문구·/notebooks)
  theme.dart                   메모 대표색
  models/memo.dart             Memo, MemoItem, MemoSummary, Viewer
  services/memo_store.dart     기기 저장(캐시·초안·오프라인 체크) — shared_preferences
  services/memo_services.dart  공통 서비스 + 저장소 + 오프라인 체크 보내기
  screens/
    notebook_list_screen.dart  내 메모집
    notebook_screen.dart       메모 목록 (길게 누르면 고정·휴지통), 휴지통·설정 버튼
    text_memo_screen.dart      글 메모 (자동 저장·병합·충돌·초안·보는 중)
    conflict_screen.dart       충돌 비교 화면
    checklist_screen.dart      체크리스트
    trash_screen.dart          휴지통 (30일)
  widgets/                     오프라인 띠, 보는 중 띠
  utils/                       상대 시간, 충돌 화면 줄 비교
```

## 광고

메모집 목록·메모 목록·휴지통 하단에 AdMob 배너 (`lib/ads/`). 광고 ID는 `config/ads.json` (비어 있으면 테스트 ID). 설정 방법은 `store-assets/memo/playstore-guide.md`의 "광고".

## 출시 후

- 실시간 반영(WebSocket), 이미지 첨부(R2), 푸시 알림
- 가계부 멤버를 메모집에 바로 초대
