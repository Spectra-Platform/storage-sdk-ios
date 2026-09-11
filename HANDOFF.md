# HANDOFF — storage-sdk-ios

## 목적과 소유 범위

`storage-sdk-ios`는 Spectra Platform Storage의 iOS 공개 SDK를 소유한다. 앱이 AuthSDK에서 받은 app-user access token을 token provider로 주입하고, Storage Platform의 user-root API를 `/photos/a.png` 같은 사용자 루트 경로로 호출하는 경계를 제공한다.

이 저장소는 iOS SDK만 소유한다. Storage API producer, MinIO/S3 physical object store, Auth token producer/introspection, Console folder browser와 운영 배포는 각각 해당 플랫폼 저장소의 소유 범위다.

## 확정된 결정

- iOS 앱 bundle에는 Project API token, object store credential, presign secret, Console session cookie를 넣지 않는다.
- SDK는 AuthSDK에 hard dependency를 두지 않고 `SpectraStorageAccessTokenProviding` protocol을 주입받는다.
- SDK 사용자가 보는 `/`는 Storage 내부에서 `project_id + environment + app_user_id + logical_path`로 해석된다.
- user-root API는 bucket id를 노출하지 않는다.
- folder UI는 실제 object store directory가 아니라 `/` delimiter 기반 prefix projection이다.
- Swift Package Manager 배포는 Git URL 기반으로 시작한다. repository URL은 `https://github.com/Spectra-Platform/storage-sdk-ios.git`, product 이름은 `SpectraStorageSDK`다.
- release tag는 `vMAJOR.MINOR.PATCH` 형식으로 만들며, 최초 tag는 공개 버전 번호를 확정한 뒤 생성한다. 현재 문서와 CI는 tag 배포가 가능한 상태를 준비하지만 tag 자체는 만들지 않는다.
- 2026-09-11 Modo Camp iOS parity 목표는 React 웹 Storage SDK의 파일 중심 surface를
  Swift에도 추가하는 것이다. 앱-facing 이름은 `listFiles`, `uploadFile`, `uploadImage`,
  `getDownloadUrl`, `downloadData`, `downloadFile`, `deleteFile`로 수렴시키고, 기존
  user-root intent/complete helper는 하위호환 low-level API로 유지한다.
- Modo Camp 기본 경로는 `/profiles/...`, `/community/images/...`, `/places/images/...`,
  `/chat/media/...` 같은 user-root 절대 경로다. 채팅·공유 미디어는 `public_read`
  visibility와 완료 응답의 public URL metadata를 사용하되, signed URL과 파일명 원문은 진단에 남기지 않는다.

## 현재 구현 경계

- Swift Package `SpectraStorageSDK`가 생성됐다.
- `.github/workflows/ci.yml`이 SwiftPM resolve/describe/test를 검증한다.
- Public surface:
  - `SpectraStorageClientConfiguration`
  - `SpectraStorageAccessTokenProviding`
  - `StaticSpectraStorageAccessTokenProvider`
  - `SpectraStorageClient`
  - `SpectraStorageObject`
  - `SpectraStorageObjectHead`
  - `SpectraUserRootListing`
  - `SpectraUserRootUploadRequest`
  - `SpectraUserRootUploadIntent`
  - `SpectraUserRootDownloadIntent`
  - `SpectraStorageError`
- User-root list/get/head/upload intent/complete/download intent/delete와 signed PUT convenience를 제공한다.
- Unit test는 bearer header, query/path, JSON body, idempotency key, no-content delete와 error decode를 검증한다.
- iOS 앱 통합 기준 문서는 `docs/guides/ios-storage-sdk-integration.md`에 둔다.
- SwiftPM 릴리즈 기준은 `docs/guides/release-checklist.md`에 둔다.

## 변경 시 함께 확인할 계약·저장소

- `Spectra-Platform/storage-platform`: user-root API producer, object store, quota, audit, upload completion
- `Spectra-Platform/auth-platform`: app-user access token producer와 introspection/JWKS
- `Spectra-Platform/auth-sdk-ios`: Auth token provider adapter
- `Spectra-Platform/platform-docs`: developer guide와 Console browser 문서
- `Spectra-Platform/delivery-platform`: notification sound binary 저장소 소비

## 남은 작업과 미확정 항목

- Auth Platform의 실제 app-user access token 발급·갱신·검증 E2E
- Storage public contract와 platform docs에 user-root API 최종 반영
- Console Storage browser list/upload/download/delete 연결
- empty folder marker와 recursive folder operation
- upload expiry GC, malware scanner, multipart upload
- MediaConvert/HLS derivative metadata와 outbox event
- 실제 Spectra iOS 앱 integration과 실기기 E2E
- JS-parity 파일 중심 API alias와 객체형 upload input
- upload progress/cancel public contract와 injectable URLSession upload transport

## 마지막으로 코드와 대조한 날짜

- 2026-09-11 문서와 현재 public API를 Modo Camp parity 기준으로 재대조했다. 코드 구현 경계는 2026-07-24 상태에 파일 중심 API alias가 필요한 상태다.
