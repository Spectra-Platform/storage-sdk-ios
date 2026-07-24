# iOS StorageSDK Integration Guide

이 문서는 iOS 앱에서 `SpectraStorageSDK`를 Swift Package로 붙이고, AuthSDK token provider를 통해 Storage Platform user-root API를 호출하는 현재 기준을 설명한다.

## 1. Package 추가

Xcode 기준:

1. `File > Add Package Dependencies...`
2. `https://github.com/Spectra-Platform/storage-sdk-ios.git` 입력
3. 개발 중에는 `main`, 릴리즈 후에는 SemVer tag를 선택
4. app target에 `SpectraStorageSDK` product 추가

`Package.swift`를 사용하는 앱/샘플이면 다음처럼 dependency를 둔다.

```swift
.package(
    url: "https://github.com/Spectra-Platform/storage-sdk-ios.git",
    branch: "main"
)
```

AuthSDK와 함께 사용할 경우:

```swift
.package(
    url: "https://github.com/Spectra-Platform/auth-sdk-ios.git",
    branch: "main"
),
.package(
    url: "https://github.com/Spectra-Platform/storage-sdk-ios.git",
    branch: "main"
)
```

## 2. AuthSDK token provider adapter

앱 bundle에 Project API token을 넣지 않는다. AuthSDK가 app-user access token을 제공하고, StorageSDK는 얇은 adapter를 통해 token string만 받는다.

```swift
import SpectraAuthSDK
import SpectraStorageSDK

struct StorageTokenProvider: SpectraStorageAccessTokenProviding {
    let auth: any TokenProvider

    func accessToken() async throws -> String {
        try await auth.getAccessToken().value
    }
}
```

현재 `storage-sdk-ios`는 AuthSDK에 hard dependency를 두지 않는다. 패키지 결합을 피하기 위해 앱에서 adapter를 소유한다.

## 3. Client 생성

```swift
let storage = SpectraStorageClient(
    configuration: SpectraStorageClientConfiguration(
        baseURL: URL(string: "https://storage.spectra.kr")!,
        projectId: "project_xxx"
    ),
    tokenProvider: StorageTokenProvider(auth: authClient)
)
```

SDK에서 보는 `/`는 현재 로그인한 app user의 root다. 서버는 token introspection의 `app_user_id`를 기준으로 다른 사용자의 object와 격리한다.

## 4. 목록 조회

```swift
let root = try await storage.listUserRoot(prefix: "/")
let photos = try await storage.listUserRoot(prefix: "/photos/")
```

`files`는 현재 prefix 바로 아래 파일이고, `prefixes`는 바로 아래 폴더처럼 보여줄 prefix projection이다. 실제 object store directory를 만든다는 뜻은 아니다.

## 5. 업로드

편의 helper:

```swift
let imageData = Data()
let object = try await storage.uploadDataToUserRoot(
    imageData,
    path: "/photos/a.png",
    contentType: "image/png",
    uploadIdempotencyKey: "upload-\(UUID().uuidString)",
    completeIdempotencyKey: "complete-\(UUID().uuidString)"
)
```

직접 제어가 필요하면 intent와 complete를 나눠 호출한다.

```swift
let intent = try await storage.createUserRootUploadIntent(
    SpectraUserRootUploadRequest(
        objectKey: "/photos/a.png",
        contentType: "image/png",
        byteSize: Int64(imageData.count),
        checksumSHA256: base64SHA256
    ),
    idempotencyKey: "upload-\(UUID().uuidString)"
)

// intent.uploadURL에 PUT 완료 후:
let completed = try await storage.completeUserRootUpload(
    uploadID: intent.uploadID,
    idempotencyKey: "complete-\(UUID().uuidString)"
)
```

## 6. 다운로드

```swift
let intent = try await storage.createUserRootDownloadIntent(
    path: "/photos/a.png",
    idempotencyKey: "download-\(UUID().uuidString)"
)

let data = try Data(contentsOf: intent.downloadURL)
```

운영 앱에서는 `Data(contentsOf:)` 대신 앱의 비동기 다운로드 파이프라인을 사용한다.

## 7. 삭제

```swift
try await storage.deleteUserRootObject(
    path: "/photos/a.png",
    idempotencyKey: "delete-\(UUID().uuidString)"
)
```

## 8. 현재 완료 상태

- Swift Package build/test
- Auth token provider protocol
- user-root list/get/head/upload intent/complete/download intent/delete
- signed PUT convenience
- Storage error response decode

## 아직 완료가 아닌 것

- Auth Platform app-user access token producer와 실제 introspection E2E
- Console Storage browser 연결
- empty folder marker와 recursive folder operation
- multipart upload, malware scanner, upload expiry GC
- MediaConvert/HLS derivative metadata
- 실제 Spectra iOS app integration
