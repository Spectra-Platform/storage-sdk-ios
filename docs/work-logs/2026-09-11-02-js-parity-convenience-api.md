# 2026-09-11 — JS parity convenience API implementation

## 작업 목적과 이해한 내용

Modo Camp iOS SwiftUI 앱이 React 웹 Storage SDK와 같은 의미로 파일 업로드,
목록, 다운로드 URL 발급, 다운로드와 삭제를 호출할 수 있도록
`SpectraStorageSDK`에 파일 중심 public API를 추가했다.

## 문제 진단 또는 기존 동작

기존 iOS SDK는 user-root list/get/head/upload-intent/complete/download-intent/delete와
`uploadDataToUserRoot(...)`를 이미 제공했다. 다만 앱-facing 이름은
`listUserRoot`, `createUserRootUploadIntent`처럼 서버 흐름에 가까웠고,
JS SDK의 객체형 `uploadFile(input)`, `uploadImage(input)`, `visibility`,
`context`, `fileInfo`, progress/cancel contract와 바로 맞지 않았다.

## 적용한 내용과 주요 변경 파일

- `Sources/SpectraStorageSDK/SpectraStorageJSParity.swift`
  - `SpectraStorageVisibility`, `SpectraStorageFileInfo`,
    `SpectraStorageUploadProgress`, `SpectraStorageUploadCancellation`,
    `SpectraStorageUploadInput`, `SpectraStorageImageUploadInput`을 추가했다.
  - `listFiles`, `uploadFile`, `uploadImage`, `getDownloadUrl`,
    `downloadData`, `downloadFile`, `deleteFile` alias를 추가했다.
  - raw metadata key는 lowercase letter, number, `.`, `_`, `-`만 허용하고
    `context`/`fileInfo`는 안전한 Storage metadata key로 매핑한다.
- `Sources/SpectraStorageSDK/SpectraStorageSDK.swift`
  - upload intent request에 `visibility`를 추가했다.
  - `uploadDataToUserRoot(...)`에 optional visibility, checksum override,
    progress closure와 cancellation handle을 추가했다.
  - signed PUT을 `URLSessionUploadTask`로 실행해 Swift Task cancellation과
    explicit cancellation handle이 underlying request cancel로 이어지게 했다.
  - `SpectraStorageError.code/statusCode/requestId/message`와 redacted
    `CustomStringConvertible`/`LocalizedError`를 추가했다.
- `Tests/SpectraStorageSDKTests/SpectraStorageClientTests.swift`
  - JS parity upload/list/download/delete alias, visibility, metadata/fileInfo,
    checksum override, progress start/end, cancel-before-network와 diagnostics
    redaction 테스트를 추가했다.
- `README.md`, `HANDOFF.md`, `WORKLOG.md`,
  `docs/guides/modo-camp-ios-storage-parity.md`
  - 구현된 public API와 남은 대용량 전송 경계를 문서화했다.

## 실행한 검증과 결과

- `swift test` 통과: 14 tests, 0 failures
- `git diff --check` 통과

## 남은 작업, 미검증 항목 또는 주의사항

- 실제 Modo Camp iOS 앱 통합과 실기기 E2E는 수행하지 않았다.
- 실제 `storage.spectra.kr` public domain upload/download/delete smoke는 이번 SDK
  작업 범위에서 수행하지 않았다.
- byte-level progress, multipart upload, pause/resume과 injectable upload transport는
  별도 대용량 파일 UX 작업으로 남아 있다.
