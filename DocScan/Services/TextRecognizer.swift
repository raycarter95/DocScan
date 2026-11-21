import UIKit
import Vision

/// Eine erkannte Textzeile. `box` ist normalisiert, Ursprung unten links (Vision-Koordinaten).
struct OCRLine {
    let text: String
    let box: CGRect
}

enum TextRecognizer {
    static func recognize(_ image: UIImage) async -> [OCRLine] {
        await runInBackground { () -> [OCRLine] in
            guard let cgImage = image.cgImage else { return [] }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "en-US"]
            request.usesLanguageCorrection = true
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                return []
            }
            let lines = (request.results ?? []).compactMap { obs -> OCRLine? in
                guard let candidate = obs.topCandidates(1).first else { return nil }
                return OCRLine(text: candidate.string, box: obs.boundingBox)
            }
            // Leserichtung: von oben nach unten
            return lines.sorted { $0.box.maxY > $1.box.maxY }
        }
    }
}
