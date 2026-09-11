# WORKLOG — storage-sdk-ios

## 2026-09-11 — JS parity convenience API implementation

- 상태: 완료, local unit 검증 통과
- 목적: Modo Camp iOS SwiftUI 앱이 React 웹 Storage SDK와 같은 의미로 Storage를 사용할 수
  있도록 파일 중심 public API를 추가한다.
- 결과: `SpectraStorageVisibility`, `SpectraStorageUploadInput`,
  `SpectraStorageImageUploadInput`, `SpectraStorageFileInfo`,
  `SpectraStorageUploadProgress`, `SpectraStorageUploadCancellation`과
  `listFiles`, `uploadFile`, `uploadImage`, `getDownloadUrl`, `downloadData`,
  `downloadFile`, `deleteFile` alias를 구현했다. Upload intent body는
  `visibility`, metadata/context/fileInfo, caller checksum을 전달하고 signed PUT은
  Task/request cancellation과 연결된다.
- 검증 상태: `swift test` 14 tests 통과, `git diff --check` 통과.
- 상세 기록: [`docs/work-logs/2026-09-11-02-js-parity-convenience-api.md`](docs/work-logs/2026-09-11-02-js-parity-convenience-api.md)

## 2026-09-11 — Modo Camp Storage parity draft

- 상태: 문서 계약 초안 완료, 파일 중심 JS-parity alias 구현은 미완료
- 목적: Modo Camp iOS가 React 웹 Storage SDK와 같은 의미의 upload/list/download/delete
  API를 사용할 수 있도록 Swift public API 목표를 고정한다.
- 결과: `docs/guides/modo-camp-ios-storage-parity.md`에 Modo production 설정, API 초안,
  user-root path guide, `public_read` visibility, progress/cancel 구현 방향, redaction 규칙과
  JS parity checklist를 추가했다.
- 검증: 문서 변경만 수행했다. Swift code는 변경하지 않았다.
- 상세 기록: [`docs/work-logs/2026-09-11-01-modo-camp-storage-parity.md`](docs/work-logs/2026-09-11-01-modo-camp-storage-parity.md)

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
