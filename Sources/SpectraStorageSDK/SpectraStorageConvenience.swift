import Foundation

public enum SpectraStorageUploadPurpose: String, Codable, Equatable, Sendable {
    case profileImage = "profile_image"
    case chatImage = "chat_image"
    case chatFile = "chat_file"
    case chatVoiceMessage = "chat_voice_message"
    case notificationSound = "notification_sound"
}

public struct SpectraStorageUploadedAttachment: Equatable, Sendable {
    public let object: SpectraStorageObject
    public let purpose: SpectraStorageUploadPurpose
    public let objectKey: String
    public let contentType: String
    public let byteSize: Int64
    public let metadata: [String: String]

    public init(
        object: SpectraStorageObject,
        purpose: SpectraStorageUploadPurpose,
        objectKey: String,
        contentType: String,
        byteSize: Int64,
        metadata: [String: String]
    ) {
        self.object = object
        self.purpose = purpose
        self.objectKey = objectKey
        self.contentType = contentType
        self.byteSize = byteSize
        self.metadata = metadata
    }
}

public extension SpectraStorageClient {
    func uploadProfileImage(
        _ data: Data,
        contentType: String,
        idempotencySeed: String = UUID().uuidString,
        metadata: [String: String] = [:]
    ) async throws -> SpectraStorageUploadedAttachment {
        let fileExtension = try SpectraStorageConveniencePaths.fileExtension(for: contentType)
        let objectKey = "/profile/images/\(SpectraStorageConveniencePaths.safeSegment(idempotencySeed)).\(fileExtension)"
        return try await uploadConvenienceData(
            data,
            purpose: .profileImage,
            objectKey: objectKey,
            contentType: contentType,
            idempotencySeed: idempotencySeed,
            metadata: metadata
        )
    }

    func uploadChatImage(
        _ data: Data,
        roomID: String,
        clientMessageID: String,
        index: Int = 0,
        contentType: String,
        idempotencySeed: String = UUID().uuidString,
        metadata: [String: String] = [:]
    ) async throws -> SpectraStorageUploadedAttachment {
        let fileExtension = try SpectraStorageConveniencePaths.fileExtension(for: contentType)
        let objectKey = SpectraStorageConveniencePaths.chatObjectKey(
            roomID: roomID,
            kindDirectory: "images",
            clientMessageID: clientMessageID,
            fileName: "\(max(0, index)).\(fileExtension)"
        )
        return try await uploadConvenienceData(
            data,
            purpose: .chatImage,
            objectKey: objectKey,
            contentType: contentType,
            idempotencySeed: idempotencySeed,
            metadata: metadata.merging([
                "room_id": roomID,
                "client_message_id": clientMessageID,
                "attachment_index": String(max(0, index))
            ]) { current, _ in current }
        )
    }

    func uploadChatFile(
        _ data: Data,
        roomID: String,
        clientMessageID: String,
        originalFileName: String,
        contentType: String,
        idempotencySeed: String = UUID().uuidString,
        metadata: [String: String] = [:]
    ) async throws -> SpectraStorageUploadedAttachment {
        let safeFileName = try SpectraStorageConveniencePaths.safeFileName(originalFileName)
        let objectKey = SpectraStorageConveniencePaths.chatObjectKey(
            roomID: roomID,
            kindDirectory: "files",
            clientMessageID: clientMessageID,
            fileName: safeFileName
        )
        return try await uploadConvenienceData(
            data,
            purpose: .chatFile,
            objectKey: objectKey,
            contentType: contentType,
            idempotencySeed: idempotencySeed,
            metadata: metadata.merging([
                "room_id": roomID,
                "client_message_id": clientMessageID,
                "original_file_name": originalFileName
            ]) { current, _ in current }
        )
    }

    func uploadVoiceMessage(
        _ data: Data,
        roomID: String,
        clientMessageID: String,
        durationSeconds: Double? = nil,
        contentType: String = "audio/m4a",
        idempotencySeed: String = UUID().uuidString,
        metadata: [String: String] = [:]
    ) async throws -> SpectraStorageUploadedAttachment {
        let fileExtension = try SpectraStorageConveniencePaths.fileExtension(for: contentType)
        let objectKey = SpectraStorageConveniencePaths.chatObjectKey(
            roomID: roomID,
            kindDirectory: "voice",
            clientMessageID: clientMessageID,
            fileName: "voice.\(fileExtension)"
        )
        var mergedMetadata = metadata.merging([
            "room_id": roomID,
            "client_message_id": clientMessageID
        ]) { current, _ in current }
        if let durationSeconds {
            mergedMetadata["duration_seconds"] = String(durationSeconds)
        }
        return try await uploadConvenienceData(
            data,
            purpose: .chatVoiceMessage,
            objectKey: objectKey,
            contentType: contentType,
            idempotencySeed: idempotencySeed,
            metadata: mergedMetadata
        )
    }

    func downloadDataFromUserRoot(
        path: String,
        idempotencyKey: String = UUID().uuidString
    ) async throws -> Data {
        let intent = try await createUserRootDownloadIntent(path: path, idempotencyKey: idempotencyKey)
        let (data, response) = try await urlSession.data(from: intent.downloadURL)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw SpectraStorageError.invalidResponse
        }
        return data
    }

    func downloadUserRootObjectToCache(
        path: String,
        cacheDirectory: URL,
        fileName: String? = nil,
        idempotencyKey: String = UUID().uuidString
    ) async throws -> URL {
        let data = try await downloadDataFromUserRoot(path: path, idempotencyKey: idempotencyKey)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let destination = cacheDirectory.appendingPathComponent(
            try fileName.map(SpectraStorageConveniencePaths.safeFileName)
                ?? SpectraStorageConveniencePaths.safeFileName(URL(fileURLWithPath: path).lastPathComponent)
        )
        try data.write(to: destination, options: [.atomic])
        return destination
    }

    private func uploadConvenienceData(
        _ data: Data,
        purpose: SpectraStorageUploadPurpose,
        objectKey: String,
        contentType: String,
        idempotencySeed: String,
        metadata: [String: String]
    ) async throws -> SpectraStorageUploadedAttachment {
        let mergedMetadata = metadata.merging(["purpose": purpose.rawValue]) { current, _ in current }
        let object = try await uploadDataToUserRoot(
            data,
            path: objectKey,
            contentType: contentType,
            metadata: mergedMetadata,
            uploadIdempotencyKey: "storage-\(purpose.rawValue)-upload-\(idempotencySeed)",
            completeIdempotencyKey: "storage-\(purpose.rawValue)-complete-\(idempotencySeed)"
        )
        return .init(
            object: object,
            purpose: purpose,
            objectKey: object.objectKey,
            contentType: contentType,
            byteSize: Int64(data.count),
            metadata: mergedMetadata
        )
    }
}

public enum SpectraStorageConveniencePaths {
    public static func chatObjectKey(
        roomID: String,
        kindDirectory: String,
        clientMessageID: String,
        fileName: String
    ) -> String {
        "/chat/\(safeSegment(roomID))/\(safeSegment(kindDirectory))/\(safeSegment(clientMessageID))/\(safeSegment(fileName))"
    }

    public static func safeFileName(_ fileName: String) throws -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              trimmed != ".",
              trimmed != "..",
              trimmed.contains("/") == false else {
            throw SpectraStorageError.invalidFileName(fileName)
        }
        return safeSegment(trimmed)
    }

    public static func safeSegment(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        let transformed = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let sanitized = String(transformed)
            .trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
        return sanitized.isEmpty ? "item" : String(sanitized.prefix(96))
    }

    public static func fileExtension(for contentType: String) throws -> String {
        switch contentType.lowercased().split(separator: ";", maxSplits: 1).first.map(String.init) {
        case "image/jpeg", "image/jpg":
            return "jpg"
        case "image/png":
            return "png"
        case "image/gif":
            return "gif"
        case "image/heic":
            return "heic"
        case "image/heif":
            return "heif"
        case "image/webp":
            return "webp"
        case "audio/m4a", "audio/x-m4a", "audio/mp4":
            return "m4a"
        case "audio/aac":
            return "aac"
        case "audio/wav", "audio/wave", "audio/x-wav":
            return "wav"
        case "application/pdf":
            return "pdf"
        case "text/plain":
            return "txt"
        default:
            throw SpectraStorageError.invalidContentType(contentType)
        }
    }
}
