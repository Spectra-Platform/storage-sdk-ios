import Foundation

public enum SpectraStorageVisibility: String, Codable, Equatable, Sendable {
    case `private`
    case publicRead = "public_read"
}

public struct SpectraStorageFileInfo: Equatable, Sendable {
    public var originalName: String?
    public var fingerprint: String?
    public var lastModified: String?

    public init(
        originalName: String? = nil,
        fingerprint: String? = nil,
        lastModified: String? = nil
    ) {
        self.originalName = originalName
        self.fingerprint = fingerprint
        self.lastModified = lastModified
    }
}

public struct SpectraStorageUploadProgress: Equatable, Sendable {
    public var loaded: Int64
    public var total: Int64

    public init(loaded: Int64, total: Int64) {
        self.loaded = loaded
        self.total = total
    }
}

public final class SpectraStorageUploadCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelHandler: (@Sendable () -> Void)?
    private var cancelled = false

    public init() {}

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    public func cancel() {
        let handler: (@Sendable () -> Void)?
        lock.lock()
        cancelled = true
        handler = cancelHandler
        lock.unlock()
        handler?()
    }

    func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }

    func setCancelHandler(_ handler: @escaping @Sendable () -> Void) {
        var shouldCancel = false
        lock.lock()
        cancelHandler = handler
        shouldCancel = cancelled
        lock.unlock()
        if shouldCancel {
            handler()
        }
    }

    func clearCancelHandler() {
        lock.lock()
        cancelHandler = nil
        lock.unlock()
    }
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
    public var cancellation: SpectraStorageUploadCancellation?

    public init(
        data: Data,
        path: String,
        contentType: String? = nil,
        visibility: SpectraStorageVisibility? = nil,
        context: String? = nil,
        fileInfo: SpectraStorageFileInfo? = nil,
        metadata: [String: String] = [:],
        checksumSha256: String? = nil,
        onProgress: (@Sendable (SpectraStorageUploadProgress) -> Void)? = nil,
        cancellation: SpectraStorageUploadCancellation? = nil
    ) {
        self.data = data
        self.path = path
        self.contentType = contentType
        self.visibility = visibility
        self.context = context
        self.fileInfo = fileInfo
        self.metadata = metadata
        self.checksumSha256 = checksumSha256
        self.onProgress = onProgress
        self.cancellation = cancellation
    }
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
    public var cancellation: SpectraStorageUploadCancellation?

    public init(
        imageData: Data,
        path: String? = nil,
        directory: String? = nil,
        fileName: String? = nil,
        contentType: String,
        visibility: SpectraStorageVisibility? = nil,
        context: String? = nil,
        fileInfo: SpectraStorageFileInfo? = nil,
        metadata: [String: String] = [:],
        checksumSha256: String? = nil,
        onProgress: (@Sendable (SpectraStorageUploadProgress) -> Void)? = nil,
        cancellation: SpectraStorageUploadCancellation? = nil
    ) {
        self.imageData = imageData
        self.path = path
        self.directory = directory
        self.fileName = fileName
        self.contentType = contentType
        self.visibility = visibility
        self.context = context
        self.fileInfo = fileInfo
        self.metadata = metadata
        self.checksumSha256 = checksumSha256
        self.onProgress = onProgress
        self.cancellation = cancellation
    }
}

public extension SpectraStorageClient {
    func listFiles(
        prefix: String? = nil,
        cursor: String? = nil,
        limit: Int? = nil
    ) async throws -> SpectraUserRootListing {
        try await listUserRoot(prefix: prefix ?? "/", cursor: cursor, limit: limit)
    }

    func uploadFile(_ input: SpectraStorageUploadInput) async throws -> SpectraStorageObject {
        let contentType = try SpectraStorageJSParity.normalizeContentType(
            input.contentType,
            fallback: "application/octet-stream"
        )
        return try await uploadDataToUserRoot(
            input.data,
            path: input.path,
            contentType: contentType,
            metadata: try SpectraStorageJSParity.buildUploadMetadata(
                input.metadata,
                context: input.context,
                fileInfo: input.fileInfo
            ),
            visibility: input.visibility,
            checksumSha256: input.checksumSha256,
            onProgress: input.onProgress,
            cancellation: input.cancellation,
            uploadIdempotencyKey: "storage-upload-\(UUID().uuidString)",
            completeIdempotencyKey: "storage-complete-\(UUID().uuidString)"
        )
    }

    func uploadImage(_ input: SpectraStorageImageUploadInput) async throws -> SpectraStorageObject {
        let contentType = try SpectraStorageJSParity.normalizeContentType(
            input.contentType,
            fallback: ""
        )
        guard contentType.lowercased().hasPrefix("image/") else {
            throw SpectraStorageError.invalidContentType(contentType)
        }
        if input.path != nil, input.directory != nil {
            throw SpectraStorageError.imagePathAmbiguous
        }
        let path: String
        if let explicitPath = input.path {
            path = explicitPath
        } else if let directory = input.directory {
            path = try SpectraStorageJSParity.joinDirectory(
                directory,
                fileName: input.fileName ?? input.fileInfo?.originalName,
                contentType: contentType
            )
        } else {
            throw SpectraStorageError.imagePathRequired
        }
        return try await uploadFile(
            SpectraStorageUploadInput(
                data: input.imageData,
                path: path,
                contentType: contentType,
                visibility: input.visibility,
                context: input.context,
                fileInfo: input.fileInfo,
                metadata: input.metadata,
                checksumSha256: input.checksumSha256,
                onProgress: input.onProgress,
                cancellation: input.cancellation
            )
        )
    }

    func getDownloadUrl(path: String) async throws -> URL {
        try await createUserRootDownloadIntent(
            path: path,
            idempotencyKey: "storage-download-\(UUID().uuidString)"
        ).downloadURL
    }

    func downloadData(path: String) async throws -> Data {
        try await downloadDataFromUserRoot(path: path)
    }

    func downloadFile(path: String, to directory: URL) async throws -> URL {
        try await downloadUserRootObjectToCache(path: path, cacheDirectory: directory)
    }

    func downloadFile(path: String, to directory: URL, fileName: String) async throws -> URL {
        try await downloadUserRootObjectToCache(path: path, cacheDirectory: directory, fileName: fileName)
    }

    func deleteFile(path: String) async throws {
        try await deleteUserRootObject(
            path: path,
            idempotencyKey: "storage-delete-\(UUID().uuidString)"
        )
    }
}

private enum SpectraStorageJSParity {
    private static let metadataAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")

    static func normalizeContentType(_ value: String?, fallback: String) throws -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        guard !fallback.isEmpty else {
            throw SpectraStorageError.invalidContentType(value ?? "")
        }
        return fallback
    }

    static func buildUploadMetadata(
        _ rawMetadata: [String: String],
        context: String?,
        fileInfo: SpectraStorageFileInfo?
    ) throws -> [String: String] {
        var metadata: [String: String] = [:]
        for (key, value) in rawMetadata {
            try validateMetadataKey(key)
            metadata[key] = value
        }
        addMetadataValue(&metadata, key: "context", value: context)
        if let fileInfo {
            addMetadataValue(&metadata, key: "original_file_name", value: fileInfo.originalName)
            addMetadataValue(&metadata, key: "file_fingerprint", value: fileInfo.fingerprint)
            addMetadataValue(&metadata, key: "last_modified", value: fileInfo.lastModified)
        }
        return metadata
    }

    static func joinDirectory(
        _ directory: String,
        fileName: String?,
        contentType: String
    ) throws -> String {
        let prefix = try normalizePrefix(directory)
        let resolvedName = try resolvedImageFileName(fileName, contentType: contentType)
        let base = prefix.hasSuffix("/") ? String(prefix.dropLast()) : prefix
        return "\(base)/\(resolvedName)"
    }

    private static func validateMetadataKey(_ key: String) throws {
        guard !key.isEmpty,
              key.unicodeScalars.allSatisfy({ metadataAllowed.contains($0) }) else {
            throw SpectraStorageError.invalidMetadataKey(key)
        }
    }

    private static func addMetadataValue(
        _ metadata: inout [String: String],
        key: String,
        value: String?
    ) {
        guard let value else {
            return
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            metadata[key] = trimmed
        }
    }

    private static func normalizePrefix(_ prefix: String) throws -> String {
        let value = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("/") else {
            throw SpectraStorageError.invalidObjectPath(prefix)
        }
        let withoutLeadingSlash = String(value.dropFirst())
        var segments = withoutLeadingSlash.split(separator: "/", omittingEmptySubsequences: false)
        if segments.last == "" {
            segments.removeLast()
        }
        guard segments.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            if value == "/" {
                return "/"
            }
            throw SpectraStorageError.invalidObjectPath(prefix)
        }
        return value
    }

    private static func resolvedImageFileName(_ fileName: String?, contentType: String) throws -> String {
        if let fileName {
            return try SpectraStorageConveniencePaths.safeFileName(fileName)
        }
        let fileExtension = try SpectraStorageConveniencePaths.fileExtension(for: contentType)
        return "\(UUID().uuidString).\(fileExtension)"
    }
}
