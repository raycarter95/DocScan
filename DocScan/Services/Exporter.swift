import UIKit
import CoreText

enum ExportError: LocalizedError {
    case encoding
    var errorDescription: String? { "Die Datei konnte nicht erstellt werden." }
}

enum Exporter {
    /// Erstellt eine temporäre Datei (PDF oder JPEG) mit dem gewünschten Namen.
    static func makeFile(image: UIImage, lines: [OCRLine], name: String, format: FileFormat) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(sanitized(name)).appendingPathExtension(format.fileExtension)

        let scaled = image.normalized(maxDimension: 2400)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.75) else { throw ExportError.encoding }

        switch format {
        case .jpeg:
            try jpeg.write(to: url)
        case .pdf:
            try pdfData(jpeg: jpeg, pixelSize: scaled.size, lines: lines).write(to: url)
        }
        return url
    }

    static func fileName(for name: String, format: FileFormat) -> String {
        "\(sanitized(name)).\(format.fileExtension)"
    }

    static func sanitized(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let cleaned = name.components(separatedBy: invalid).joined(separator: " ")
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Scan" : String(cleaned.prefix(120))
    }

    /// PDF-Seite mit dem Bild (JPEG wird direkt eingebettet, bleibt klein) und unsichtbarem OCR-Text.
    private static func pdfData(jpeg: Data, pixelSize: CGSize, lines: [OCRLine]) throws -> Data {
        guard let provider = CGDataProvider(data: jpeg as CFData),
              let cgImage = CGImage(jpegDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { throw ExportError.encoding }

        let pageWidth: CGFloat = 595.2 // A4-Breite in Punkten
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageWidth * pixelSize.height / pixelSize.width)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { throw ExportError.encoding }

        ctx.beginPDFPage(nil)
        ctx.draw(cgImage, in: mediaBox)

        // Unsichtbare Textebene -> PDF ist durchsuchbar und Text kopierbar
        ctx.setTextDrawingMode(.invisible)
        let W = mediaBox.width, H = mediaBox.height
        for line in lines {
            let rect = CGRect(x: line.box.minX * W, y: line.box.minY * H, width: line.box.width * W, height: line.box.height * H)
            guard rect.height > 1, rect.width > 1 else { continue }
            let font = CTFontCreateWithName("Helvetica" as CFString, rect.height * 0.85, nil)
            let attributed = NSAttributedString(
                string: line.text,
                attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]
            )
            let ctLine = CTLineCreateWithAttributedString(attributed)
            let lineWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
            ctx.saveGState()
            ctx.textMatrix = .identity
            ctx.translateBy(x: rect.minX, y: rect.minY + rect.height * 0.2)
            if lineWidth > 0 { ctx.scaleBy(x: rect.width / lineWidth, y: 1) }
            ctx.textPosition = .zero
            CTLineDraw(ctLine, ctx)
            ctx.restoreGState()
        }

        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }
}

/// Speichert Dateien im Dokumente-Ordner der App (sichtbar in der Dateien-App unter „Auf meinem iPhone“).
enum LocalStore {
    static func save(_ file: URL) throws -> URL {
        let fm = FileManager.default
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let base = file.deletingPathExtension().lastPathComponent
        let ext = file.pathExtension
        var destination = docs.appendingPathComponent(file.lastPathComponent)
        var counter = 2
        while fm.fileExists(atPath: destination.path) {
            destination = docs.appendingPathComponent("\(base) (\(counter)).\(ext)")
            counter += 1
        }
        try fm.copyItem(at: file, to: destination)
        return destination
    }
}
