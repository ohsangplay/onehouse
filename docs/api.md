# API 명세

- 기기 토큰은 `Authorization: Bearer <token>` 헤더로 보낸다.
- 가계부 하위 API는 매 요청마다 `status = approved`와 역할을 서버에서 확인한다.
- 오류 응답: `{"error": {"code": "...", "message": "..."}}`
- 금액은 원 단위 정수, 날짜는 `YYYY-MM-DD`, 시각은 ISO 8601(UTC).

## 기기

| 메서드 | 경로 | 권한 | 설명 |
| --- | --- | --- | --- |
| POST | /devices | 없음 | `{install_key}` → `{device_id, token}`. 이미 있으면 409 |
| POST | /devices/restore | 없음 | `{install_key}` → 새 토큰 (같은 폰 재설치) |
| POST | /devices/transfer-codes | 기기 | 1회용 이전 코드 `{code, expires_at}` (10분) |
| POST | /devices/transfer | 없음 | `{code, install_key}` → 같은 기기 계정에 새 토큰, 이전 폰 토큰 무효 |

## 가계부

| 메서드 | 경로 | 권한 | 설명 |
| --- | --- | --- | --- |
| GET | /ledgers | 기기 | 내 가계부 목록 (승인 대기 포함, 대기 중이면 역할·금액 숨김) |
| POST | /ledgers | 기기 | `{name, nickname}` → 초대코드 + 복구코드(1회 표시), 기본 공통 카테고리 9개 |
| POST | /ledgers/join | 기기 | `{code, nickname}` → `pending`. 거절·차단·나감 후 재요청은 같은 행이 대기로 |
| POST | /ledgers/recover | 기기 | `{code}` 복구코드 → 방장 권한을 이 기기로, 새 복구코드 반환 |
| POST | /ledgers/:id/cancel-request | 요청자 | 승인 대기 취소 |
| GET | /ledgers/:id | 승인 멤버 | 상세. 초대코드는 방장·부방장만, `needs_recovery_code`는 방장만 |
| PATCH | /ledgers/:id | 방장 | `{name}` 이름 수정 |
| DELETE | /ledgers/:id | 방장 | `{confirm_name}` 이름 재입력 후 삭제 |
| POST | /ledgers/:id/invite-code | 방장 | 초대코드 재발급 |
| POST | /ledgers/:id/recovery-code | 방장 | 복구코드 재발급 (이전 코드 무효) |
| POST | /ledgers/:id/transfer-owner | 방장 | `{member_id}` 양도. 기존 방장은 부방장(자리 없으면 멤버), 복구코드는 새 방장이 발급 |
| POST | /ledgers/:id/leave | 부방장·멤버 | 나가기 |
| PATCH | /ledgers/:id/me | 승인 멤버 | `{nickname}` 내 닉네임 |
| GET | /ledgers/:id/events | 방장 | 관리 이력 최근 100건 |

## 멤버

| 메서드 | 경로 | 권한 | 설명 |
| --- | --- | --- | --- |
| GET | /ledgers/:id/members | 방장·부방장 | `{members, pending}`, `was_revoked` 포함 |
| GET | /ledgers/:id/members/:mid | 방장·부방장 | 참여일, 승인한 사람, 이번 달 작성 건수·지출 |
| POST | /ledgers/:id/members/:mid/approve | 방장·부방장 | 승인. `{link_to_member_id}`를 주면 기존 멤버로 연결 |
| POST | /ledgers/:id/members/:mid/reject | 방장·부방장 | 거절 |
| POST | /ledgers/:id/members/:mid/revoke | 방장·부방장 | 차단 (부방장은 일반 멤버만) |
| PATCH | /ledgers/:id/members/:mid/role | 방장 | `{role: co_owner\|member}` 부방장 지정·해제, 최대 3명 |

## 카테고리

| 메서드 | 경로 | 권한 | 설명 |
| --- | --- | --- | --- |
| GET | /ledgers/:id/categories | 승인 멤버 | 공통 → 지출 → 수입 순 |
| POST | /ledgers/:id/categories | 방장·부방장 | `{type: common\|expense\|income, name}` (10자 이하) |
| PATCH | /ledgers/:id/categories/:cid | 방장·부방장 | `{name?, sort_order?}` |
| DELETE | /ledgers/:id/categories/:cid | 방장·부방장 | 삭제. 해당 내역은 미분류로 |

이름 중복 규칙: 공통은 모든 종류와, 지출·수입은 공통 + 같은 종류와 겹치면 409.

## 내역

| 메서드 | 경로 | 권한 | 설명 |
| --- | --- | --- | --- |
| GET | /ledgers/:id/transactions?month=YYYY-MM | 승인 멤버 | `{month, summary: {income, expense}, transactions}` |
| | `&category_ids=a,b&uncategorized=1` | | 카테고리 필터 (OR) |
| GET | /ledgers/:id/transactions?since=ISO | 승인 멤버 | 변경분 동기화 (삭제 포함) |
| POST | /ledgers/:id/transactions | 승인 멤버 | `{type, amount, spent_at, category_id?, memo?}` |
| PATCH | /ledgers/:id/transactions/:tid | 승인 멤버 | 부분 수정. 작성자 표시는 유지 |
| DELETE | /ledgers/:id/transactions/:tid | 승인 멤버 | 삭제 |

카테고리 종류 검사: 지출에는 공통·지출, 수입에는 공통·수입 카테고리만.

## 오류 코드

| 상태 | 의미 |
| --- | --- |
| 401 | 토큰 없음·무효 (다른 기기로 이전됨) → 앱은 기기 계정을 다시 준비 |
| 403 | 승인 안 됨, 차단됨, 권한 없음 |
| 404 | 코드가 맞지 않음, 대상 없음 |
| 409 | 중복, 상태가 맞지 않음, 인원 제한 |
| 429 | 코드 입력 시도 횟수 초과 |
