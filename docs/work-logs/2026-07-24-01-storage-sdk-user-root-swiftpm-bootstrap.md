# 2026-07-24 — StorageSDK user-root SwiftPM bootstrap

## 작업 목적

`storage-sdk-ios`를 실제 앱에서 Swift Package Manager Git URL로 붙일 수 있는 첫 iOS SDK로 부트스트랩한다.

## 기존 상태

- `https://github.com/Spectra-Platform/storage-sdk-ios.git` 원격 repo는 존재했지만 비어 있었다.
- `storage-platform`에는 user-root API 구현 slice가 존재했다.
- iOS SDK repo, Swift Package, 문서, CI와 테스트는 아직 없었다.

## 적용 내용

- Swift Package `SpectraStorageSDK`를 생성했다.
- AuthSDK hard dependency 없이 `SpectraStorageAccessTokenProviding` protocol을 추가했다.
- Storage Platform user-root API에 맞춰 list/get/head/upload intent/complete/download intent/delete client를 구현했다.
- `uploadDataToUserRoot(...)` convenience를 추가해 SHA-256 checksum 계산, upload intent, signed PUT, complete 흐름을 하나로 묶었다.
- Storage error response를 decode해 status, code, message, retryable, request id를 확인할 수 있게 했다.
- README, HANDOFF, integration guide, release checklist와 SwiftPM CI를 추가했다.

## 주요 변경 파일

- `Package.swift`
- `Sources/SpectraStorageSDK/SpectraStorageSDK.swift`
- `Tests/SpectraStorageSDKTests/SpectraStorageClientTests.swift`
- `.github/workflows/ci.yml`
- `README.md`
- `HANDOFF.md`
- `WORKLOG.md`
- `docs/guides/ios-storage-sdk-integration.md`
- `docs/guides/release-checklist.md`

## 검증

- `swift package resolve`
- `swift package describe`
- `swift test`
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci.yml")'`
- `git diff --check`

## 남은 작업

- Auth Platform app-user access token producer와 실제 introspection E2E를 연결한다.
- Console Storage browser와 실제 앱 integration을 연결한다.
- empty folder marker, recursive folder operation, multipart upload, malware scanner, upload expiry GC와 MediaConvert/HLS derivative metadata는 후속 slice로 진행한다.

## 커밋 기록

- 이번 작업 커밋에서 기록한다.
