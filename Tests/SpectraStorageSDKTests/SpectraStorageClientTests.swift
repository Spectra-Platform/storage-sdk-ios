import Foundation
import XCTest
@testable import SpectraStorageSDK

final class SpectraStorageClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
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
