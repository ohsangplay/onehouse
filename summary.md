# CI 17e75e623f7815dc40713d702618f949fe3ee7d0 (main)

| 작업 | 결과 |
| --- | --- |
| 서버 | success |
| 한지붕 가계부 | failure |
| 한지붕 메모 | success |

skipped = 이번 변경과 상관없어서 건너뜀

## 서버

| 단계 | 결과 |
| --- | --- |
| 타입체크·빌드·병합 단위 테스트 | success |
| 스모크 테스트 (가계부 + 메모) | success |

## 한지붕 가계부 (apps/budget)

| 단계 | 결과 |
| --- | --- |
| 공통 패키지 분석·테스트 | success |
| 플랫폼 폴더·패키지 | success |
| Flutter analyze | success |
| Flutter test | success |
| Flutter 웹 빌드 | success |
| 스크린샷 | failure |
| APK 빌드 | success |

## 한지붕 메모 (apps/memo)

| 단계 | 결과 |
| --- | --- |
| 공통 패키지 분석·테스트 | success |
| 플랫폼 폴더·패키지 | success |
| Flutter analyze | success |
| Flutter test | success |
| Flutter 웹 빌드 | success |
| 스크린샷 | success |
| APK 빌드 | success |
