import CryptoKit
import Foundation

public protocol SpectraStorageAccessTokenProviding: Sendable {
    func accessToken() async throws -> String
}

public struct StaticSpectraStorageAccessTokenProvider: SpectraStorageAccessTokenProviding {
    private let token: String

    public init(token: String) {
        self.token = token
    }

    public func accessToken() async throws -> String {
        token
    }
}

public struct SpectraStorageClientConfiguration: Sendable {
    public static let productionBaseURL = URL(string: "https://storage.spectra.kr")!

    public var baseURL: URL
    public var projectId: String

    public init(baseURL: URL = Self.productionBaseURL, projectId: String) {
        self.baseURL = baseURL
        self.projectId = projectId
    }

    public static func production(projectId: String) -> SpectraStorageClientConfiguration {
        SpectraStorageClientConfiguration(projectId: projectId)
    }

    public static func custom(baseURL: URL, projectId: String) -> SpectraStorageClientConfiguration {
        SpectraStorageClientConfiguration(baseURL: baseURL, projectId: projectId)
    }
}

public struct SpectraStorageObject: Codable, Equatable, Sendable {
    public var objectKey: String
    public var status: String
    public var visibility: String?
    public var contentType: String
    public var byteSize: Int64
    public var checksumSHA256: String
    public var metadata: [String: String]
    public var eTag: String?
    public var publicURL: URL?
    public var rejectionCategory: String?
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case objectKey = "object_key"
        case status
        case visibility
        case contentType = "content_type"
        case byteSize = "byte_size"
        case checksumSHA256 = "checksum_sha256"
        case metadata
        case eTag = "etag"
        case publicURL = "public_url"
        case rejectionCategory = "rejection_category"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public var publicUrl: URL? {
        publicURL
    }

    public var checksumSha256: String {
        checksumSHA256
    }
}

public struct SpectraStorageObjectHead: Equatable, Sendable {
    public var objectKey: String
    public var status: String?
    public var contentType: String?
    public var byteSize: Int64?
    public var checksumSHA256: String?
    public var eTag: String?
}

public struct SpectraUserRootListing: Codable, Equatable, Sendable {
    public var files: [SpectraStorageObject]
    public var prefixes: [String]
    public var nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case files
        case prefixes
        case nextCursor = "next_cursor"
    }
}

public struct SpectraUserRootUploadRequest: Codable, Equatable, Sendable {
    public var objectKey: String
    public var contentType: String
    public var byteSize: Int64
    public var checksumSHA256: String
    public var visibility: SpectraStorageVisibility?
    public var metadata: [String: String]

    public init(
        objectKey: String,
        contentType: String,
        byteSize: Int64,
        checksumSHA256: String,
        visibility: SpectraStorageVisibility? = nil,
        metadata: [String: String] = [:]
    ) {
        self.objectKey = objectKey
        self.contentType = contentType
        self.byteSize = byteSize
        self.checksumSHA256 = checksumSHA256
        self.visibility = visibility
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case objectKey = "object_key"
        case contentType = "content_type"
        case byteSize = "byte_size"
        case checksumSHA256 = "checksum_sha256"
        case visibility
        case metadata
    }
}

public struct SpectraUserRootUploadIntent: Codable, Equatable, Sendable {
    public var uploadID: String
    public var objectKey: String
    public var uploadMethod: String?
    public var uploadURL: URL
    public var uploadHeaders: [String: String]
    public var expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case uploadID = "upload_id"
        case objectKey = "object_key"
        case uploadMethod = "upload_method"
        case uploadURL = "upload_url"
        case uploadHeaders = "upload_headers"
        case expiresAt = "expires_at"
    }
}

public struct SpectraUserRootDownloadIntent: Codable, Equatable, Sendable {
    public var objectKey: String
    public var downloadURL: URL
    public var expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case objectKey = "object_key"
        case downloadURL = "download_url"
        case expiresAt = "expires_at"
    }
}

public struct SpectraStorageErrorResponse: Codable, Equatable, Sendable {
    public var code: String
    public var message: String
    public var retryable: Bool
    public var requestID: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case retryable
        case requestID = "request_id"
    }
}

public enum SpectraStorageError: Error, Equatable, Sendable {
    case invalidBaseURL
    case invalidObjectPath(String)
    case invalidResponse
    case invalidContentType(String)
    case invalidFileName(String)
    case invalidMetadataKey(String)
    case invalidChecksum
    case imagePathRequired
    case imagePathAmbiguous
    case httpStatus(Int, SpectraStorageErrorResponse?)

    public var statusCode: Int? {
        guard case .httpStatus(let status, _) = self else {
            return nil
        }
        return status
    }

    public var code: String {
        switch self {
        case .invalidBaseURL:
            return "BASE_URL_INVALID"
        case .invalidObjectPath:
            return "PATH_INVALID"
        case .invalidResponse:
            return "RESPONSE_INVALID"
        case .invalidContentType:
            return "CONTENT_TYPE_INVALID"
        case .invalidFileName:
            return "FILE_NAME_INVALID"
        case .invalidMetadataKey:
            return "METADATA_KEY_INVALID"
        case .invalidChecksum:
            return "CHECKSUM_INVALID"
        case .imagePathRequired:
            return "IMAGE_PATH_REQUIRED"
        case .imagePathAmbiguous:
            return "IMAGE_PATH_AMBIGUOUS"
        case .httpStatus(_, let payload):
            return payload?.code ?? "REQUEST_FAILED"
        }
    }

    public var requestID: String? {
        guard case .httpStatus(_, let payload) = self else {
            return nil
        }
        return payload?.requestID
    }

    public var requestId: String? {
        requestID
    }

    public var message: String {
        switch self {
        case .invalidBaseURL:
            return "Spectra Storage baseURL is invalid."
        case .invalidObjectPath:
            return "Storage object path is invalid."
        case .invalidResponse:
            return "Spectra Storage returned an invalid response."
        case .invalidContentType:
            return "Storage content type is invalid."
        case .invalidFileName:
            return "Storage file name is invalid."
        case .invalidMetadataKey:
            return "Storage metadata key is invalid."
        case .invalidChecksum:
            return "Storage checksumSha256 is invalid."
        case .imagePathRequired:
            return "uploadImage requires path or directory."
        case .imagePathAmbiguous:
            return "uploadImage accepts either path or directory, not both."
        case .httpStatus(_, let payload):
            return payload?.message ?? "Spectra Storage request failed."
        }
    }
}

extension SpectraStorageError: CustomStringConvertible, LocalizedError {
    public var description: String {
        if let statusCode {
            return "SpectraStorageError(code: \(code), status: \(statusCode), requestId: \(requestId ?? "nil"), message: \(message))"
        }
        return "SpectraStorageError(code: \(code), message: \(message))"
    }

    public var errorDescription: String? {
        message
    }
}

public final class SpectraStorageClient: @unchecked Sendable {
    private let configuration: SpectraStorageClientConfiguration
    private let tokenProvider: any SpectraStorageAccessTokenProviding
    let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        configuration: SpectraStorageClientConfiguration,
        tokenProvider: any SpectraStorageAccessTokenProviding,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.tokenProvider = tokenProvider
        self.urlSession = urlSession
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder.spectraStorageDecoder
    }

    public convenience init(
        projectId: String,
        tokenProvider: any SpectraStorageAccessTokenProviding,
        urlSession: URLSession = .shared
    ) {
        self.init(
            configuration: .production(projectId: projectId),
            tokenProvider: tokenProvider,
            urlSession: urlSession
        )
    }

    public convenience init(
        auth tokenProvider: any SpectraStorageAccessTokenProviding,
        projectID: String,
        urlSession: URLSession = .shared
    ) {
        self.init(
            projectId: projectID,
            tokenProvider: tokenProvider,
            urlSession: urlSession
        )
    }

    public func listUserRoot(
        prefix: String = "/",
        cursor: String? = nil,
        limit: Int? = nil
    ) async throws -> SpectraUserRootListing {
        var query: [URLQueryItem] = []
        if !prefix.isEmpty {
            query.append(URLQueryItem(name: "prefix", value: prefix))
        }
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let limit {
            query.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        let url = try userRootURL(suffix: "/objects", queryItems: query)
        let request = try await makeRequest(url: url, method: "GET")
        return try await decodeDataResponse(request: request, expectedStatus: 200)
    }

    public func getUserRootObject(path: String) async throws -> SpectraStorageObject {
        let url = try userRootObjectURL(path: path)
        let request = try await makeRequest(url: url, method: "GET")
        return try await decodeDataResponse(request: request, expectedStatus: 200)
    }

    public func headUserRootObject(path: String) async throws -> SpectraStorageObjectHead {
        let url = try userRootObjectURL(path: path)
        let request = try await makeRequest(url: url, method: "HEAD")
        let (_, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpectraStorageError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw SpectraStorageError.httpStatus(http.statusCode, nil)
        }
        return SpectraStorageObjectHead(
            objectKey: normalizedRootPath(path),
            status: http.value(forHTTPHeaderField: "X-Spectra-Object-Status"),
            contentType: http.value(forHTTPHeaderField: "Content-Type"),
            byteSize: http.value(forHTTPHeaderField: "Content-Length").flatMap(Int64.init),
            checksumSHA256: http.value(forHTTPHeaderField: "X-Spectra-Checksum-Sha256"),
            eTag: http.value(forHTTPHeaderField: "ETag")
        )
    }

    public func createUserRootUploadIntent(
        _ input: SpectraUserRootUploadRequest,
        idempotencyKey: String
    ) async throws -> SpectraUserRootUploadIntent {
        let url = try userRootURL(suffix: "/upload-intents")
        let request = try await makeJSONRequest(
            url: url,
            method: "POST",
            idempotencyKey: idempotencyKey,
            body: input
        )
        return try await decodeDataResponse(request: request, expectedStatus: 201)
    }

    public func completeUserRootUpload(
        uploadID: String,
        idempotencyKey: String
    ) async throws -> SpectraStorageObject {
        let url = try userRootURL(suffix: "/upload-intents/\(encodedPathSegment(uploadID))/complete")
        let request = try await makeRequest(url: url, method: "POST", idempotencyKey: idempotencyKey)
        return try await decodeDataResponse(request: request, expectedStatus: 202)
    }

    public func createUserRootDownloadIntent(
        path: String,
        idempotencyKey: String
    ) async throws -> SpectraUserRootDownloadIntent {
        let encoded = try encodedRootObjectPath(path)
        let url = try userRootURL(suffix: "/objects/\(encoded)/download-intents")
        let request = try await makeRequest(url: url, method: "POST", idempotencyKey: idempotencyKey)
        return try await decodeDataResponse(request: request, expectedStatus: 201)
    }

    public func deleteUserRootObject(
        path: String,
        idempotencyKey: String
    ) async throws {
        let url = try userRootObjectURL(path: path)
        let request = try await makeRequest(url: url, method: "DELETE", idempotencyKey: idempotencyKey)
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpectraStorageError.invalidResponse
        }
        guard http.statusCode == 204 else {
            throw SpectraStorageError.httpStatus(http.statusCode, decodeError(from: data))
        }
    }

    public func uploadDataToUserRoot(
        _ data: Data,
        path: String,
        contentType: String,
        metadata: [String: String] = [:],
        visibility: SpectraStorageVisibility? = nil,
        checksumSha256: String? = nil,
        onProgress: (@Sendable (SpectraStorageUploadProgress) -> Void)? = nil,
        cancellation: SpectraStorageUploadCancellation? = nil,
        uploadIdempotencyKey: String,
        completeIdempotencyKey: String
    ) async throws -> SpectraStorageObject {
        try Task.checkCancellation()
        try cancellation?.checkCancellation()
        let total = Int64(data.count)
        let checksum = try checksumSha256.map(validateChecksumSha256)
            ?? Data(SHA256.hash(data: data)).base64EncodedString()
        onProgress?(SpectraStorageUploadProgress(loaded: 0, total: total))
        let intent = try await createUserRootUploadIntent(
            SpectraUserRootUploadRequest(
                objectKey: normalizedRootPath(path),
                contentType: contentType,
                byteSize: total,
                checksumSHA256: checksum,
                visibility: visibility,
                metadata: metadata
            ),
            idempotencyKey: uploadIdempotencyKey
        )

        try Task.checkCancellation()
        try cancellation?.checkCancellation()
        var put = URLRequest(url: intent.uploadURL)
        put.httpMethod = intent.uploadMethod ?? "PUT"
        for (name, value) in intent.uploadHeaders {
            put.setValue(value, forHTTPHeaderField: name)
        }
        if put.value(forHTTPHeaderField: "Content-Type") == nil {
            put.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        let http = try await uploadSignedData(data, request: put, cancellation: cancellation)
        guard 200 ..< 300 ~= http.statusCode else {
            throw SpectraStorageError.httpStatus(http.statusCode, nil)
        }
        onProgress?(SpectraStorageUploadProgress(loaded: total, total: total))

        try Task.checkCancellation()
        try cancellation?.checkCancellation()

        return try await completeUserRootUpload(
            uploadID: intent.uploadID,
            idempotencyKey: completeIdempotencyKey
        )
    }

    private func makeRequest(
        url: URL,
        method: String,
        idempotencyKey: String? = nil
    ) async throws -> URLRequest {
        let token = try await tokenProvider.accessToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        return request
    }

    private func makeJSONRequest<Body: Encodable>(
        url: URL,
        method: String,
        idempotencyKey: String? = nil,
        body: Body
    ) async throws -> URLRequest {
        var request = try await makeRequest(url: url, method: method, idempotencyKey: idempotencyKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return request
    }

    private func decodeDataResponse<T: Decodable>(
        request: URLRequest,
        expectedStatus: Int
    ) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpectraStorageError.invalidResponse
        }
        guard http.statusCode == expectedStatus else {
            throw SpectraStorageError.httpStatus(http.statusCode, decodeError(from: data))
        }
        return try decoder.decode(DataEnvelope<T>.self, from: data).data
    }

    private func decodeError(from data: Data) -> SpectraStorageErrorResponse? {
        try? decoder.decode(ErrorEnvelope.self, from: data).error
    }

    private func uploadSignedData(
        _ data: Data,
        request: URLRequest,
        cancellation: SpectraStorageUploadCancellation?
    ) async throws -> HTTPURLResponse {
        let taskBox = SpectraStorageURLSessionTaskBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = urlSession.uploadTask(with: request, from: data) { _, response, error in
                    cancellation?.clearCancelHandler()
                    if let error {
                        if (error as? URLError)?.code == .cancelled {
                            continuation.resume(throwing: CancellationError())
                        } else {
                            continuation.resume(throwing: error)
                        }
                        return
                    }
                    guard let http = response as? HTTPURLResponse else {
                        continuation.resume(throwing: SpectraStorageError.invalidResponse)
                        return
                    }
                    continuation.resume(returning: http)
                }
                taskBox.set(task)
                cancellation?.setCancelHandler {
                    taskBox.cancel()
                }
                task.resume()
                if cancellation?.isCancelled == true {
                    task.cancel()
                }
            }
        } onCancel: {
            taskBox.cancel()
        }
    }

    private func userRootObjectURL(path: String) throws -> URL {
        try userRootURL(suffix: "/objects/\(encodedRootObjectPath(path))")
    }

    private func userRootURL(suffix: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw SpectraStorageError.invalidBaseURL
        }
        let basePath = components.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let prefix = basePath.isEmpty ? "" : "/\(basePath)"
        components.percentEncodedPath = "\(prefix)/platform/v1/projects/\(encodedPathSegment(configuration.projectId))/storage/user-root\(suffix)"
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw SpectraStorageError.invalidBaseURL
        }
        return url
    }
}

private final class SpectraStorageURLSessionTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionTask?

    func set(_ task: URLSessionTask) {
        lock.lock()
        self.task = task
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        let current = task
        lock.unlock()
        current?.cancel()
    }
}

private struct DataEnvelope<T: Decodable>: Decodable {
    var data: T
}

private struct ErrorEnvelope: Decodable {
    var error: SpectraStorageErrorResponse
}

private func normalizedRootPath(_ path: String) -> String {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("/") {
        return trimmed
    }
    return "/\(trimmed)"
}

private func encodedRootObjectPath(_ path: String) throws -> String {
    let normalized = normalizedRootPath(path)
    let withoutLeadingSlash = String(normalized.dropFirst())
    guard !withoutLeadingSlash.isEmpty, !withoutLeadingSlash.hasSuffix("/") else {
        throw SpectraStorageError.invalidObjectPath(path)
    }
    let segments = withoutLeadingSlash.split(separator: "/", omittingEmptySubsequences: false)
    guard segments.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
        throw SpectraStorageError.invalidObjectPath(path)
    }
    return segments.map { encodedPathSegment(String($0)) }.joined(separator: "/")
}

private func encodedPathSegment(_ value: String) -> String {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=:")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}

private func validateChecksumSha256(_ value: String) throws -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw SpectraStorageError.invalidChecksum
    }
    return trimmed
}

private extension JSONDecoder {
    static var spectraStorageDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) {
                return date
            }

            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return decoder
    }
}
