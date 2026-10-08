import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Stores a smaller, upright JPEG instead of the original photo. Encoding a
/// fresh image also leaves the original location and camera metadata behind.
enum ProgressPhotoImporter {
    nonisolated static func importPhoto(data: Data) async throws -> Data {
        // This project isolates most code to the main actor. Image decoding is
        // CPU work, so explicitly move it off the actor that draws the screen.
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let imageData = try downsample(data: data)
            try Task.checkCancellation()
            return imageData
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    nonisolated private static func downsample(data: Data) throws -> Data {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            throw ProgressPhotoImportError.invalidImage
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_600,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ProgressPhotoImportError.invalidImage
        }
        try Task.checkCancellation()

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            throw ProgressPhotoImportError.cannotEncode
        }
        // Only pixel data and compression quality are passed to the encoder;
        // metadata from the source image is never copied into the saved JPEG.
        let properties = [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw ProgressPhotoImportError.cannotEncode
        }
        return output as Data
    }
}

enum ProgressPhotoImportError: LocalizedError {
    case invalidImage
    case cannotEncode

    nonisolated var errorDescription: String? {
        switch self {
        case .invalidImage:
            "This photo couldn't be read. Please choose another image."
        case .cannotEncode:
            "This photo couldn't be prepared for saving. Please try another image."
        }
    }
}
