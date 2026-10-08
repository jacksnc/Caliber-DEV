import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import Caliber__DEV_

@Suite("Progress photo import")
@MainActor
struct ProgressPhotoImporterTests {
    /// Synthetic pixels keep tests independent of personal photos or files.
    private func makeImage(width: Int, height: Int, orientation: Int = 1) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil
        ))
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 0.95,
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 40.0,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 70.0,
                kCGImagePropertyGPSLongitudeRef: "W"
            ],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "Synthetic private metadata"]
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test("Large photos become bounded JPEGs with the original metadata removed")
    func downsampleAndStripMetadata() async throws {
        let original = try makeImage(width: 3_200, height: 800)
        let originalSource = try #require(CGImageSourceCreateWithData(original as CFData, nil))
        let originalProperties = try #require(CGImageSourceCopyPropertiesAtIndex(originalSource, 0, nil) as? [String: Any])
        #expect(originalProperties[kCGImagePropertyGPSDictionary as String] != nil)

        let prepared = try await ProgressPhotoImporter.importPhoto(data: original)
        let source = try #require(CGImageSourceCreateWithData(prepared as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        #expect((CGImageSourceGetType(source) as String?) == UTType.jpeg.identifier)
        #expect(properties[kCGImagePropertyPixelWidth as String] as? Int == 1_600)
        #expect(properties[kCGImagePropertyPixelHeight as String] as? Int == 400)
        #expect(properties[kCGImagePropertyGPSDictionary as String] == nil)
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        #expect(exif?[kCGImagePropertyExifUserComment as String] == nil)
        #expect(!prepared.isEmpty)
    }

    @Test("Camera orientation is applied to the pixels before saving")
    func orientationIsPreserved() async throws {
        // EXIF 6 means the source pixels must turn 90 degrees clockwise.
        let original = try makeImage(width: 3_200, height: 800, orientation: 6)
        let prepared = try await ProgressPhotoImporter.importPhoto(data: original)
        let source = try #require(CGImageSourceCreateWithData(prepared as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        #expect(properties[kCGImagePropertyPixelWidth as String] as? Int == 400)
        #expect(properties[kCGImagePropertyPixelHeight as String] as? Int == 1_600)
        let orientation = properties[kCGImagePropertyOrientation as String] as? Int
        #expect(orientation == nil || orientation == 1)
    }

    @Test("Small photos keep their dimensions instead of being enlarged")
    func smallImageRemainsSmall() async throws {
        let original = try makeImage(width: 120, height: 80)
        let prepared = try await ProgressPhotoImporter.importPhoto(data: original)
        let source = try #require(CGImageSourceCreateWithData(prepared as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        #expect(properties[kCGImagePropertyPixelWidth as String] as? Int == 120)
        #expect(properties[kCGImagePropertyPixelHeight as String] as? Int == 80)
    }

    @Test("Invalid and empty input are rejected")
    func invalidDataIsRejected() async {
        for data in [Data(), Data("This is not a photo".utf8)] {
            await #expect(throws: ProgressPhotoImportError.self) {
                try await ProgressPhotoImporter.importPhoto(data: data)
            }
        }
    }
}
