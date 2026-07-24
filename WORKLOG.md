# WORKLOG — storage-sdk-ios

## 2026-07-24 — StorageSDK user-root SwiftPM bootstrap

- 상태: 완료
- 목적: iOS 앱에서 Auth token provider를 주입해 Storage Platform user-root API를 호출할 수 있는 첫 Swift Package를 만든다.
- 주요 변경 영역:
  - Swift Package `SpectraStorageSDK` 생성
  - user-root list/get/head/upload intent/complete/download/delete client 구현
  - signed PUT convenience와 JSON error decode 추가
  - SwiftPM CI, README, HANDOFF, integration guide와 release checklist 추가
- 검증 상태: `swift package resolve`, `swift package describe`, `swift test` 5 tests, workflow YAML parse, `git diff --check` 통과
- 상세 기록: [`docs/work-logs/2026-07-24-01-storage-sdk-user-root-swiftpm-bootstrap.md`](docs/work-logs/2026-07-24-01-storage-sdk-user-root-swiftpm-bootstrap.md)
