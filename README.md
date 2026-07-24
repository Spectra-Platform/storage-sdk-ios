# Spectra Storage SDK for iOS

Swift Package 기반의 Spectra Platform Storage iOS SDK다. 이 첫 slice는 iOS 앱이 AuthSDK에서 받은 app-user access token을 token provider로 주입하고, Storage Platform의 user-root API를 `/photos/a.png` 같은 사용자 루트 경로로 호출하는 경계를 제공한다.

## 현재 구현 상태

- Swift Package: `SpectraStorageSDK`
- Package URL: `https://github.com/Spectra-Platform/storage-sdk-ios.git`
- Public configuration: `baseURL`, `projectId`
- Public token provider: `SpectraStorageAccessTokenProviding`
- User-root API:
  - list `GET /storage/user-root/objects`
  - get/head `GET|HEAD /storage/user-root/objects/{path...}`
  - upload intent `POST /storage/user-root/upload-intents`
  - complete upload `POST /storage/user-root/upload-intents/{upload_id}/complete`
  - download intent `POST /storage/user-root/objects/{path...}/download-intents`
  - delete `DELETE /storage/user-root/objects/{path...}`
- Convenience helper: `uploadDataToUserRoot(...)`
- 검증: `swift test`

Project API token은 iOS 앱 bundle에 넣지 않는다. iOS 앱은 AuthSDK로 app-user token을 얻고, StorageSDK는 token provider protocol만 의존한다.

## 설치

Xcode에서 `File > Add Package Dependencies...`를 열고 아래 Git URL을 추가한다.

```text
https://github.com/Spectra-Platform/storage-sdk-ios.git
```

개발 중에는 `main` branch를 사용할 수 있다.

```swift
.package(
    url: "https://github.com/Spectra-Platform/storage-sdk-ios.git",
    branch: "main"
)
```

버전 태그가 발행된 뒤에는 앱에서 SemVer 범위를 고정한다.

```swift
.package(
    url: "https://github.com/Spectra-Platform/storage-sdk-ios.git",
    .upToNextMinor(from: "0.1.0")
)
```

target dependency에는 product 이름을 사용한다.

```swift
.product(name: "SpectraStorageSDK", package: "storage-sdk-ios")
```

릴리즈 전 확인 절차는 [release checklist](docs/guides/release-checklist.md)를 따른다. 현재 저장소는 SwiftPM Git package로 소비 가능하도록 준비하며, 최초 SemVer tag는 공개 버전 번호를 확정한 뒤 별도로 생성한다.

## 사용 예시

자세한 앱 통합 흐름은 [iOS StorageSDK integration guide](docs/guides/ios-storage-sdk-integration.md)를 기준으로 본다.

```swift
import Foundation
import SpectraAuthSDK
import SpectraStorageSDK

struct StorageTokenProvider: SpectraStorageAccessTokenProviding {
    let auth: any TokenProvider

    func accessToken() async throws -> String {
        try await auth.getAccessToken().value
    }
}

let storage = SpectraStorageClient(
    configuration: SpectraStorageClientConfiguration(
        baseURL: URL(string: "https://storage.spectra.kr")!,
        projectId: "project_123"
    ),
    tokenProvider: StorageTokenProvider(auth: authClient)
)

let listing = try await storage.listUserRoot(prefix: "/photos/")
```

## 로컬 검증

```bash
swift package describe
swift test
```

## 현재 미완료 경계

- Auth Platform의 실제 app-user access token 발급·갱신·검증 E2E
- Console Storage browser 연동
- empty folder marker와 recursive folder operation
- upload expiry GC, malware scanner, multipart upload
- MediaConvert/HLS derivative metadata와 outbox event
- 실제 Spectra iOS 앱 integration과 실기기 E2E
