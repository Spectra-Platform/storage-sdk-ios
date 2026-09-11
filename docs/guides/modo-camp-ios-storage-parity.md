# Modo Camp iOS Storage SDK parity draft

Last checked: 2026-09-11

This guide documents the Swift Storage SDK target for Modo Camp iOS. It is based
on the local `@spectra-platform/storage-sdk` source. The user supplied web
version is `0.1.3`; the local checked source is `0.1.4` and includes
`public_read`, `publicUrl` and object-style upload input, so the Swift
convenience API tracks that newer local contract.

## Current state

- Existing SwiftPM package: `SpectraStorageSDK`
- Current iOS package implements user-root list/get/head/upload-intent/complete,
  download-intent/delete and data upload convenience.
- Current iOS package also exposes JS-parity aliases: `listFiles`, `uploadFile`,
  `uploadImage`, `getDownloadUrl`, `downloadData`, `downloadFile` and
  `deleteFile`.
- Upload input supports `visibility`, raw safe metadata, `context`, `fileInfo`,
  caller-supplied `checksumSha256`, progress start/end callbacks and explicit
  cancellation through `SpectraStorageUploadCancellation`.
- Existing lower-level names such as `listUserRoot` and `uploadDataToUserRoot`
  remain available for compatibility.
- Byte-level progress, multipart upload and pause/resume remain future transport
  work.

## Recommended package structure

Keep the existing separate SwiftPM package:

```swift
.package(
    url: "https://github.com/Spectra-Platform/storage-sdk-ios.git",
    .upToNextMinor(from: "0.1.0")
)
```

Do not create a new storage-specific mono-package. Chat SDK can depend on this
package for attachment upload helpers, while apps may also install Storage
directly for profile, community and place media.

## Modo Camp configuration

```swift
let storage = SpectraStorageClient(
    configuration: .init(
        baseURL: URL(string: "https://storage.spectra.kr")!,
        projectId: "13d7ce4b-dd2a-4267-b15f-bbdb80b853da"
    ),
    tokenProvider: storageTokenProvider
)
```

`storageTokenProvider` must obtain `auth.getAccessToken(service: .storage)`.
Do not pass the default Auth access token to Storage when the server expects a
Storage service token, and do not use a Storage token for Modo backend
bootstrap.

## Swift public API

```swift
public enum SpectraStorageVisibility: String, Codable, Sendable {
    case `private`
    case publicRead = "public_read"
}

public struct SpectraStorageFileInfo: Codable, Sendable {
    public var originalName: String?
    public var fingerprint: String?
    public var lastModified: String?
}

public struct SpectraStorageUploadProgress: Sendable {
    public var loaded: Int64
    public var total: Int64
}

public struct SpectraStorageUploadInput: Sendable {
    public var data: Data
    public var path: String
    public var contentType: String?
    public var visibility: SpectraStorageVisibility?
    public var context: String?
    public var fileInfo: SpectraStorageFileInfo?
    public var metadata: [String: String]
    public var checksumSha256: String?
    public var onProgress: (@Sendable (SpectraStorageUploadProgress) -> Void)?
}

public struct SpectraStorageImageUploadInput: Sendable {
    public var imageData: Data
    public var path: String?
    public var directory: String?
    public var fileName: String?
    public var contentType: String
    public var visibility: SpectraStorageVisibility?
    public var context: String?
    public var fileInfo: SpectraStorageFileInfo?
    public var metadata: [String: String]
    public var checksumSha256: String?
    public var onProgress: (@Sendable (SpectraStorageUploadProgress) -> Void)?
}

public actor SpectraStorageClient {
    public func listFiles(
        prefix: String?,
        cursor: String?,
        limit: Int?
    ) async throws -> SpectraUserRootListing

    public func uploadFile(
        _ input: SpectraStorageUploadInput
    ) async throws -> SpectraStorageObject

    public func uploadImage(
        _ input: SpectraStorageImageUploadInput
    ) async throws -> SpectraStorageObject

    public func getDownloadUrl(path: String) async throws -> URL
    public func downloadData(path: String) async throws -> Data
    public func downloadFile(path: String, to directory: URL) async throws -> URL
    public func deleteFile(path: String) async throws
}
```

Swift cancellation uses normal `Task` cancellation and can also be triggered by
passing `SpectraStorageUploadCancellation` to upload input and calling
`cancel()`. The signed PUT step uses `URLSessionUploadTask`, so cancellation
reaches the underlying request. Progress currently mirrors the JS fetch contract:
it fires at `loaded: 0` before upload and at `loaded: total` after signed PUT.
Byte-level progress should be added with an injectable upload transport when
large-file UX needs it.

## Modo Camp path guide

Use user-root absolute paths:

- `/profiles/...`
- `/community/images/...`
- `/places/images/...`
- `/chat/media/...`

For cross-user chat/media preview, use `visibility: .publicRead` and pass only
the returned `objectKey`, content metadata and optional public URL into Chat.
Do not expose bucket names, physical keys, signed PUT URLs or Storage provider
credentials to app code.

## Diagnostics and errors

Expose only safe fields:

- `code`
- `status`
- `requestId`
- `message`
- `retryable`

Never log bearer tokens, signed upload/download URLs, raw file names or raw
email-like metadata. File names may be sent to the server as `fileInfo` when
needed, but diagnostics should redact them.

## JS to Swift parity checklist

| JS local 0.1.4 contract | Swift target | Current iOS state |
| --- | --- | --- |
| `listFiles({ prefix, cursor, limit })` | `listFiles(prefix:cursor:limit:)` | Implemented alias over `listUserRoot` |
| `uploadFile({ file, path, ... })` | `uploadFile(_ input:)` | Implemented alias over user-root upload |
| `uploadImage({ file, path/directory, ... })` | `uploadImage(_ input:)` | Implemented; `directory` uses `fileName`, `fileInfo.originalName`, or generated image name |
| `visibility: "private" | "public_read"` | `SpectraStorageVisibility` | Implemented in upload intent body |
| `fileInfo`, `context`, raw metadata validation | Swift upload input mapping | Implemented; mapped to `context`, `original_file_name`, `file_fingerprint`, `last_modified` |
| automatic checksum | SHA-256 base64 | Implemented for data upload; caller `checksumSha256` override supported |
| `onProgress` | progress closure | Implemented start/end parity; byte-level remains future transport work |
| cancellation | Swift Task cancellation + explicit handle | Implemented for signed upload request cancellation |
| `getDownloadUrl(path)` | `getDownloadUrl(path:)` | Implemented alias over download intent |
| `downloadBlob(path)` | `downloadData` / `downloadFile` | Implemented |
| `deleteFile(path)` | `deleteFile(path:)` | Implemented alias over delete |
