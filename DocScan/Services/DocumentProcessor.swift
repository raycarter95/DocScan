import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

enum DocumentProcessor {
    private static let context = CIContext()

    /// Sucht die Umrisse des Dokuments im Foto. Gibt nil zurück, wenn nichts gefunden wurde.
    static func detectDocument(in image: UIImage) async -> Quad? {
        await runInBackground { detectSync(image) }
    }

    private static func detectSync(_ image: UIImage) -> Quad? {
        guard let cgImage = image.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // 1. Versuch: Apples spezialisierte Dokument-Erkennung
        let segmentation = VNDetectDocumentSegmentationRequest()
        try? handler.perform([segmentation])
        var observation = segmentation.results?.first(where: { $0.confidence > 0.5 })

        // 2. Versuch: allgemeine Rechteck-Erkennung
        if observation == nil {
            let rectangles = VNDetectRectanglesRequest()
            rectangles.minimumAspectRatio = 0.3
            rectangles.maximumAspectRatio = 1.0
            rectangles.minimumSize = 0.2
            rectangles.quadratureTolerance = 30
            rectangles.minimumConfidence = 0.5
            rectangles.maximumObservations = 1
            try? handler.perform([rectangles])
            observation = rectangles.results?.first
        }

        guard let obs = observation else { return nil }
        // Vision: Ursprung unten links -> umrechnen auf oben links
        func convert(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }
        return Quad(
            topLeft: convert(obs.topLeft),
            topRight: convert(obs.topRight),
            bottomRight: convert(obs.bottomRight),
            bottomLeft: convert(obs.bottomLeft)
        )
    }

    /// Schneidet das Dokument aus, entzerrt die Perspektive und optimiert optional den Kontrast.
    static func extract(_ image: UIImage, quad: Quad, enhance: Bool) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let input = CIImage(cgImage: cgImage)
        let w = input.extent.width
        let h = input.extent.height
        func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * w, y: (1 - p.y) * h) }

        var output = input
        if quad != .full {
            let filter = CIFilter.perspectiveCorrection()
            filter.inputImage = input
            filter.topLeft = point(quad.topLeft)
            filter.topRight = point(quad.topRight)
            filter.bottomRight = point(quad.bottomRight)
            filter.bottomLeft = point(quad.bottomLeft)
            if let corrected = filter.outputImage, corrected.extent.width > 10, corrected.extent.height > 10 {
                output = corrected
            }
        }

        if enhance {
            output = enhanced(output)
        }

        let extent = output.extent.integral
        guard let result = context.createCGImage(output, from: extent) else { return image }
        return UIImage(cgImage: result)
    }

    private static func enhanced(_ image: CIImage) -> CIImage {
        if let filter = CIFilter(name: "CIDocumentEnhancer") {
            filter.setValue(image, forKey: kCIInputImageKey)
            if let out = filter.outputImage { return out.cropped(to: image.extent) }
        }
        let controls = CIFilter.colorControls()
        controls.inputImage = image
        controls.contrast = 1.15
        controls.brightness = 0.02
        return controls.outputImage?.cropped(to: image.extent) ?? image
    }
}

extension UIImage {
    /// Richtet das Bild auf (EXIF-Orientierung) und begrenzt die Größe.
    func normalized(maxDimension: CGFloat = 3000) -> UIImage {
        let longest = max(size.width, size.height)
        let factor = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
