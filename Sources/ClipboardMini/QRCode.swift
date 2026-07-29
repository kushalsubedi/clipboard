import AppKit
import CoreImage

enum QRCode {
    /// A version-40 QR code with medium error correction holds at most 2331 bytes.
    static let maxBytes = 2331

    static func image(for text: String, sidePixels: CGFloat = 512) -> NSImage? {
        guard let cgImage = cgImage(for: text, sidePixels: sidePixels) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: sidePixels, height: sidePixels))
    }

    static func pngData(for text: String, sidePixels: CGFloat = 512) -> Data? {
        guard let cgImage = cgImage(for: text, sidePixels: sidePixels) else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }

    private static func cgImage(for text: String, sidePixels: CGFloat) -> CGImage? {
        let message = Data(text.utf8)
        guard !message.isEmpty, message.count <= maxBytes,
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(message, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = sidePixels / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }
}
