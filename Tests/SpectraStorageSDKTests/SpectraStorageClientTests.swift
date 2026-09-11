import Foundation
import XCTest
@testable import SpectraStorageSDK

final class SpectraStorageClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testProductionConfigurationOwnsPlatformEndpoint() {
        let configuration = SpectraStorageClientConfiguration.production(projectId: "project_123")

        XCTAssertEqual(configuration.baseURL.absoluteString, "https://storage.spectra.kr")
        XCTAssertEqual(configuration.projectId, "project_123")
    }

    func testListUserRootAttachesBearerAndQuery() async throws {
        let client = makeClient()
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer user_access_token")
            XCTAssertEqual(request.url?.path, "/platform/v1/projects/project_123/storage/user-root/objects")
            XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "prefix" })?.value, "/photos/")
            return jsonResponse(
                status: 200,
                body: """
                {
                  "data": {
                    "files": [
                      {
                        "object_key": "/photos/a.png",
                        "status": "ready",
                        "visibility": "private",
                        "content_type": "image/png",
                        "byte_size": 4,
                        "checksum_sha256": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
                        "metadata": {},
                        "etag": "etag-1",
                        "public_url": null,
                        "rejection_category": null,
                        "created_at": "2026-07-24T01:00:00Z",
                        "updated_at": "2026-07-24T01:00:00Z"
                      }
                    ],
                    "prefixes": ["/photos/nested/"],
                    "next_cursor": null
                  }
                }
                """
            )
        }

        let listing = try await client.listUserRoot(prefix: "/photos/")

        XCTAssertEqual(listing.files.map(\.objectKey), ["/photos/a.png"])
        XCTAssertEqual(listing.prefixes, ["/photos/nested/"])
        XCTAssertNil(listing.nextCursor)
    }

    func testCreateUploadIntentUsesIdempotencyKeyAndBody() async throws {
        let client = makeClient()
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "upload-idempotency-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.url?.path, "/platform/v1/projects/project_123/storage/user-root/upload-intents")

            let body = try requestBodyData(request)
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["object_key"] as? String, "/photos/a.png")
            XCTAssertEqual(json?["content_type"] as? String, "image/png")
            XCTAssertEqual(json?["byte_size"] as? Int, 4)
            XCTAssertEqual(json?["checksum_sha256"] as? String, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")

            return jsonResponse(
                status: 201,
                body: """
                {
                  "data": {
                    "upload_id": "upl_123",
                    "object_key": "/photos/a.png",
                    "upload_method": "PUT",
                    "upload_url": "https://storage.example.test/signed-put",
                    "upload_headers": {
                      "Content-Type": "image/png"
                    },
                    "expires_at": "2026-07-24T01:15:00Z"
                  }
                }
                """
            )
        }

        let intent = try await client.createUserRootUploadIntent(
            SpectraUserRootUploadRequest(
                objectKey: "/photos/a.png",
                contentType: "image/png",
                byteSize: 4,
                checksumSHA256: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
            ),
            idempotencyKey: "upload-idempotency-key"
        )

        XCTAssertEqual(intent.uploadID, "upl_123")
        XCTAssertEqual(intent.uploadMethod, "PUT")
        XCTAssertEqual(intent.uploadHeaders["Content-Type"], "image/png")
    }

    func testDownloadIntentEncodesRootPathSegments() async throws {
        let client = makeClient()
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "download-idempotency-key")
            XCTAssertEqual(request.url?.path, "/platform/v1/projects/project_123/storage/user-root/objects/photos/a name.png/download-intents")
            XCTAssertEqual(request.url?.absoluteString.contains("a%20name.png"), true)
            return jsonResponse(
                status: 201,
                body: """
                {
                  "data": {
                    "object_key": "/photos/a name.png",
                    "download_url": "https://storage.example.test/signed-get",
                    "expires_at": "2026-07-24T01:05:00Z"
                  }
                }
                """
            )
        }

        let intent = try await client.createUserRootDownloadIntent(
            path: "/photos/a name.png",
            idempotencyKey: "download-idempotency-key"
        )

        XCTAssertEqual(intent.objectKey, "/photos/a name.png")
        XCTAssertEqual(intent.downloadURL.absoluteString, "https://storage.example.test/signed-get")
    }

    func testDeleteAcceptsNoContent() async throws {
        let client = makeClient()
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "delete-idempotency-key")
            XCTAssertEqual(request.url?.path, "/platform/v1/projects/project_123/storage/user-root/objects/photos/a.png")
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }

        try await client.deleteUserRootObject(path: "/photos/a.png", idempotencyKey: "delete-idempotency-key")
    }

    func testHTTPErrorDecodesStorageErrorWithoutLeakingToken() async throws {
        let client = makeClient()
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer user_access_token")
            return jsonResponse(
                status: 401,
                body: """
                {
                  "error": {
                    "code": "APP_USER_TOKEN_UNAUTHORIZED",
                    "message": "App user token is invalid.",
                    "retryable": false,
                    "field_errors": [],
                    "request_id": "req_123",
                    "details": {}
                  }
                }
                """
            )
        }

        do {
            _ = try await client.listUserRoot()
            XCTFail("Expected request to fail")
        } catch SpectraStorageError.httpStatus(let status, let payload) {
            XCTAssertEqual(status, 401)
            XCTAssertEqual(payload?.code, "APP_USER_TOKEN_UNAUTHORIZED")
            XCTAssertEqual(payload?.requestID, "req_123")
            XCTAssertNotEqual(payload?.message, "user_access_token")
        }
    }

    func testUploadProfileImageCreatesPurposePathMetadataAndCompletes() async throws {
        let client = makeClient()
        var requestIndex = 0
        MockURLProtocol.handler = { request in
            defer { requestIndex += 1 }
            switch requestIndex {
            case 0:
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "storage-profile_image-upload-profile-seed-1")
                XCTAssertEqual(request.url?.path, "/platform/v1/projects/project_123/storage/user-root/upload-intents")
                let body = try JSONSerialization.jsonObject(with: requestBodyData(request)) as? [String: Any]
                XCTAssertEqual(body?["object_key"] as? String, "/profile/images/profile-seed-1.png")
                XCTAssertEqual(body?["content_type"] as? String, "image/png")
                let metadata = try XCTUnwrap(body?["metadata"] as? [String: String])
                XCTAssertEqual(metadata["purpose"], "profile_image")
                return jsonResponse(
                    status: 201,
                    body: """
                    {
                      "data": {
                        "upload_id": "upl_profile",
                        "object_key": "/profile/images/profile-seed-1.png",
                        "upload_method": "PUT",
                        "upload_url": "https://storage.example.test/signed-put/profile",
                        "upload_headers": {
                          "Content-Type": "image/png"
                        },
                        "expires_at": "2026-07-24T01:15:00Z"
                      }
                    }
                    """
                )
            case 1:
                XCTAssertEqual(request.httpMethod, "PUT")
                XCTAssertEqual(request.url?.path, "/signed-put/profile")
                XCTAssertEqual(try requestBodyData(request), Data("image-data".utf8))
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            default:
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "storage-profile_image-complete-profile-seed-1")
                XCTAssertEqual(request.url?.path, "/platform/v1/projects/project_123/storage/user-root/upload-intents/upl_profile/complete")
                return storageObjectEnvelope(
                    status: 202,
                    objectKey: "/profile/images/profile-seed-1.png",
                    contentType: "image/png",
                    byteSize: 10,
                    metadata: ["purpose": "profile_image"]
                )
            }
        }

        let uploaded = try await client.uploadProfileImage(
            Data("image-data".utf8),
            contentType: "image/png",
            idempotencySeed: "profile-seed-1"
        )

        XCTAssertEqual(uploaded.purpose, .profileImage)
        XCTAssertEqual(uploaded.objectKey, "/profile/images/profile-seed-1.png")
        XCTAssertEqual(uploaded.metadata["purpose"], "profile_image")
        XCTAssertEqual(requestIndex, 3)
    }

    func testUploadFileParityMapsVisibilityMetadataChecksumAndProgress() async throws {
        let client = makeClient()
        var requestIndex = 0
        let checksum = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
        let progressRecorder = ProgressRecorder()

        MockURLProtocol.handler = { request in
            defer { requestIndex += 1 }
            switch requestIndex {
            case 0:
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.path, "/platform/v1/projects/project_123/storage/user-root/upload-intents")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key")?.hasPrefix("storage-upload-"), true)
                let body = try JSONSerialization.jsonObject(with: requestBodyData(request)) as? [String: Any]
                XCTAssertEqual(body?["object_key"] as? String, "/community/images/photo.png")
                XCTAssertEqual(body?["content_type"] as? String, "image/png")
                XCTAssertEqual(body?["byte_size"] as? Int, 10)
                XCTAssertEqual(body?["checksum_sha256"] as? String, checksum)
                XCTAssertEqual(body?["visibility"] as? String, "public_read")
                let metadata = try XCTUnwrap(body?["metadata"] as? [String: String])
                XCTAssertEqual(metadata["context"], "community-post")
                XCTAssertEqual(metadata["original_file_name"], "여름 캠프.png")
                XCTAssertEqual(metadata["file_fingerprint"], "fingerprint-1")
                XCTAssertEqual(metadata["last_modified"], "1788650000000")
                XCTAssertEqual(metadata["caption"], "main")
                return jsonResponse(
                    status: 201,
                    body: """
                    {
                      "data": {
                        "upload_id": "upl_file",
                        "object_key": "/community/images/photo.png",
                        "upload_method": "PUT",
                        "upload_url": "https://storage.example.test/signed-put/file",
                        "upload_headers": {
                          "Content-Type": "image/png"
                        },
                        "expires_at": "2026-09-11T01:15:00Z"
                      }
                    }
                    """
                )
            case 1:
                XCTAssertEqual(request.httpMethod, "PUT")
                XCTAssertEqual(request.url?.path, "/signed-put/file")
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                XCTAssertEqual(try requestBodyData(request), Data("image-data".utf8))
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            default:
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key")?.hasPrefix("storage-complete-"), true)
                XCTAssertEqual(request.url?.path, "/platform/v1/projects/project_123/storage/user-root/upload-intents/upl_file/complete")
                return storageObjectEnvelope(
                    status: 202,
                    objectKey: "/community/images/photo.png",
                    contentType: "image/png",
                    byteSize: 10,
                    metadata: ["context": "community-post"]
                )
            }
        }

        let uploaded = try await client.uploadFile(
            SpectraStorageUploadInput(
                data: Data("image-data".utf8),
                path: "/community/images/photo.png",
                contentType: "image/png",
                visibility: .publicRead,
                context: "community-post",
                fileInfo: SpectraStorageFileInfo(
                    originalName: "여름 캠프.png",
                    fingerprint: "fingerprint-1",
                    lastModified: "1788650000000"
                ),
                metadata: ["caption": "main"],
                checksumSha256: checksum,
                onProgress: { progressRecorder.append($0) }
            )
        )

        XCTAssertEqual(uploaded.objectKey, "/community/images/photo.png")
        XCTAssertEqual(uploaded.checksumSha256, uploaded.checksumSHA256)
        XCTAssertEqual(progressRecorder.events, [
            SpectraStorageUploadProgress(loaded: 0, total: 10),
            SpectraStorageUploadProgress(loaded: 10, total: 10),
        ])
        XCTAssertEqual(requestIndex, 3)
    }

    func testUploadImageParityRequiresImageAndBuildsDirectoryPath() async throws {
        let client = makeClient()
        var requestIndex = 0
        MockURLProtocol.handler = { request in
            defer { requestIndex += 1 }
            switch requestIndex {
            case 0:
                let body = try JSONSerialization.jsonObject(with: requestBodyData(request)) as? [String: Any]
                XCTAssertEqual(body?["object_key"] as? String, "/places/images/place_cover.jpg")
                XCTAssertEqual(body?["content_type"] as? String, "image/jpeg")
                XCTAssertEqual(body?["visibility"] as? String, "public_read")
                return jsonResponse(
                    status: 201,
                    body: """
                    {
                      "data": {
                        "upload_id": "upl_image",
                        "object_key": "/places/images/place_cover.jpg",
                        "upload_method": "PUT",
                        "upload_url": "https://storage.example.test/signed-put/image",
                        "upload_headers": {},
                        "expires_at": "2026-09-11T01:15:00Z"
                      }
                    }
                    """
                )
            case 1:
                XCTAssertEqual(request.httpMethod, "PUT")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
            default:
                return storageObjectEnvelope(
                    status: 202,
                    objectKey: "/places/images/place_cover.jpg",
                    contentType: "image/jpeg",
                    byteSize: 5,
                    metadata: [:]
                )
            }
        }

        let uploaded = try await client.uploadImage(
            SpectraStorageImageUploadInput(
                imageData: Data("image".utf8),
                directory: "/places/images/",
                fileName: "place cover.jpg",
                contentType: "image/jpeg",
                visibility: .publicRead
            )
        )

        XCTAssertEqual(uploaded.objectKey, "/places/images/place_cover.jpg")
        XCTAssertEqual(requestIndex, 3)

        do {
            _ = try await client.uploadImage(
                SpectraStorageImageUploadInput(
                    imageData: Data(),
                    path: "/places/images/a.txt",
                    contentType: "text/plain"
                )
            )
            XCTFail("Expected non-image content type to fail")
        } catch let error as SpectraStorageError {
            XCTAssertEqual(error.code, "CONTENT_TYPE_INVALID")
            XCTAssertFalse(String(describing: error).contains("text/plain"))
        }
    }

    func testUploadFileCancellationStopsBeforeNetworkRequest() async throws {
        let client = makeClient()
        let cancellation = SpectraStorageUploadCancellation()
        cancellation.cancel()
        MockURLProtocol.handler = { _ in
            XCTFail("Cancelled upload should not create a network request")
            return (HTTPURLResponse(url: URL(string: "https://storage.example.test")!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        do {
            _ = try await client.uploadFile(
                SpectraStorageUploadInput(
                    data: Data("image-data".utf8),
                    path: "/chat/media/cancelled.png",
                    contentType: "image/png",
                    cancellation: cancellation
                )
            )
            XCTFail("Expected upload to be cancelled")
        } catch is CancellationError {
            XCTAssertTrue(cancellation.isCancelled)
        }
    }

    func testListDownloadAndDeleteParityAliasesUseUserRootAPIs() async throws {
        let client = makeClient()
        var requestIndex = 0
        MockURLProtocol.handler = { request in
            defer { requestIndex += 1 }
            switch requestIndex {
            case 0:
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertEqual(request.url?.path, "/platform/v1/projects/project_123/storage/user-root/objects")
                XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "prefix" })?.value, "/chat/media/")
                return jsonResponse(
                    status: 200,
                    body: """
                    {
                      "data": {
                        "files": [],
                        "prefixes": ["/chat/media/room-1/"],
                        "next_cursor": "cursor-2"
                      }
                    }
                    """
                )
            case 1:
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.path, "/platform/v1/projects/project_123/storage/user-root/objects/chat/media/a.png/download-intents")
                return jsonResponse(
                    status: 201,
                    body: """
                    {
                      "data": {
                        "object_key": "/chat/media/a.png",
                        "download_url": "https://storage.example.test/signed-get/file",
                        "expires_at": "2026-09-11T01:05:00Z"
                      }
                    }
                    """
                )
            default:
                XCTAssertEqual(request.httpMethod, "DELETE")
                XCTAssertEqual(request.url?.path, "/platform/v1/projects/project_123/storage/user-root/objects/chat/media/a.png")
                return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
            }
        }

        let listing = try await client.listFiles(prefix: "/chat/media/", limit: 20)
        let url = try await client.getDownloadUrl(path: "/chat/media/a.png")
        try await client.deleteFile(path: "/chat/media/a.png")

        XCTAssertEqual(listing.prefixes, ["/chat/media/room-1/"])
        XCTAssertEqual(listing.nextCursor, "cursor-2")
        XCTAssertEqual(url.absoluteString, "https://storage.example.test/signed-get/file")
        XCTAssertEqual(requestIndex, 3)
    }

    func testParityDiagnosticsRedactRawPathFileNameAndMetadataKey() {
        let pathError = SpectraStorageError.invalidObjectPath("/profiles/private-name.png")
        let fileNameError = SpectraStorageError.invalidFileName("secret-name.pdf")
        let metadataError = SpectraStorageError.invalidMetadataKey("Original Name")

        XCTAssertFalse(String(describing: pathError).contains("private-name"))
        XCTAssertFalse(String(describing: fileNameError).contains("secret-name"))
        XCTAssertFalse(String(describing: metadataError).contains("Original Name"))
        XCTAssertEqual(pathError.code, "PATH_INVALID")
        XCTAssertEqual(fileNameError.code, "FILE_NAME_INVALID")
        XCTAssertEqual(metadataError.code, "METADATA_KEY_INVALID")
    }

    func testChatConveniencePathsAndMetadataAreStable() {
        XCTAssertEqual(
            SpectraStorageConveniencePaths.chatObjectKey(
                roomID: "room/1",
                kindDirectory: "images",
                clientMessageID: "message 1",
                fileName: "0.jpg"
            ),
            "/chat/room_1/images/message_1/0.jpg"
        )
        XCTAssertEqual(try SpectraStorageConveniencePaths.fileExtension(for: "audio/mp4"), "m4a")
        XCTAssertEqual(try SpectraStorageConveniencePaths.safeFileName("hello world.pdf"), "hello_world.pdf")
    }

    func testDownloadUserRootObjectToCacheUsesSignedURL() async throws {
        let client = makeClient()
        var requestIndex = 0
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        MockURLProtocol.handler = { request in
            defer { requestIndex += 1 }
            switch requestIndex {
            case 0:
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "download-cache-1")
                XCTAssertEqual(request.url?.path, "/platform/v1/projects/project_123/storage/user-root/objects/profile/images/a.png/download-intents")
                return jsonResponse(
                    status: 201,
                    body: """
                    {
                      "data": {
                        "object_key": "/profile/images/a.png",
                        "download_url": "https://storage.example.test/signed-get/profile",
                        "expires_at": "2026-07-24T01:05:00Z"
                      }
                    }
                    """
                )
            default:
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertEqual(request.url?.path, "/signed-get/profile")
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("downloaded-image".utf8)
                )
            }
        }

        let cachedURL = try await client.downloadUserRootObjectToCache(
            path: "/profile/images/a.png",
            cacheDirectory: temporaryDirectory,
            idempotencyKey: "download-cache-1"
        )

        XCTAssertEqual(try Data(contentsOf: cachedURL), Data("downloaded-image".utf8))
        XCTAssertEqual(cachedURL.lastPathComponent, "a.png")
        XCTAssertEqual(requestIndex, 2)
    }

    private func makeClient() -> SpectraStorageClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return SpectraStorageClient(
            configuration: SpectraStorageClientConfiguration(
                baseURL: URL(string: "https://storage.example.test")!,
                projectId: "project_123"
            ),
            tokenProvider: StaticSpectraStorageAccessTokenProvider(token: "user_access_token"),
            urlSession: session
        )
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedEvents: [SpectraStorageUploadProgress] = []

    var events: [SpectraStorageUploadProgress] {
        lock.lock()
        defer { lock.unlock() }
        return storedEvents
    }

    func append(_ progress: SpectraStorageUploadProgress) {
        lock.lock()
        storedEvents.append(progress)
        lock.unlock()
    }
}

private func jsonResponse(status: Int, body: String) -> (HTTPURLResponse, Data) {
    let url = URL(string: "https://storage.example.test")!
    return (
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!,
        Data(body.utf8)
    )
}

private func storageObjectEnvelope(
    status: Int,
    objectKey: String,
    contentType: String,
    byteSize: Int64,
    metadata: [String: String]
) -> (HTTPURLResponse, Data) {
    let metadataJSON = metadata
        .map { #""\#($0.key)": "\#($0.value)""# }
        .sorted()
        .joined(separator: ",")
    return jsonResponse(
        status: status,
        body: """
        {
          "data": {
            "object_key": "\(objectKey)",
            "status": "ready",
            "visibility": "private",
            "content_type": "\(contentType)",
            "byte_size": \(byteSize),
            "checksum_sha256": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
            "metadata": { \(metadataJSON) },
            "etag": "etag-1",
            "public_url": null,
            "rejection_category": null,
            "created_at": "2026-07-24T01:00:00Z",
            "updated_at": "2026-07-24T01:00:00Z"
          }
        }
        """
    )
}

private func requestBodyData(_ request: URLRequest) throws -> Data {
    if let body = request.httpBody {
        return body
    }
    if let stream = request.httpBodyStream {
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                throw stream.streamError ?? URLError(.cannotDecodeRawData)
            }
            if read == 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }
    return Data()
}
