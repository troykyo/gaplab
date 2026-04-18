import AppKit
import ImageIO
import CoreGraphics

enum ImageResizer {
    static let maxLongEdge: CGFloat = 1568
    static let jpegQuality: CGFloat = 0.85

    static func resize(_ image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let original = CGSize(width: cgImage.width, height: cgImage.height)
        let scale = min(1.0, maxLongEdge / max(original.width, original.height))
        let targetSize = CGSize(width: (original.width * scale).rounded(),
                                height: (original.height * scale).rounded())

        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil,
                                  width:  Int(targetSize.width),
                                  height: Int(targetSize.height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        guard let resized = ctx.makeImage() else { return nil }

        let mutable = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutable, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, resized, [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutable as Data
    }

    static func makeThumbnail(_ image: NSImage, size: CGFloat = 200) -> Data? {
        let thumb = NSImage(size: NSSize(width: size, height: size))
        let src = image.size
        let scale = min(size / src.width, size / src.height)
        let drawSize = NSSize(width: src.width * scale, height: src.height * scale)
        let origin = NSPoint(x: (size - drawSize.width) / 2,
                             y: (size - drawSize.height) / 2)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: origin, size: drawSize))
        thumb.unlockFocus()
        return thumb.tiffRepresentation
            .flatMap { NSBitmapImageRep(data: $0) }
            .flatMap { $0.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) }
    }
}
