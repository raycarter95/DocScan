import UIKit

/// Ein fertig zugeschnittenes Dokument inkl. Text und Namensvorschlägen.
@MainActor
final class ScanSession: ObservableObject {
    let image: UIImage
    @Published var name = ""
    @Published private(set) var suggestions: [String] = []
    @Published private(set) var isAnalyzing = true
    private(set) var lines: [OCRLine] = []
    private var lastAutoName = ""

    init(image: UIImage) {
        self.image = image
    }

    func analyze(includeDate: Bool, useAI: Bool) async {
        isAnalyzing = true
        lines = await TextRecognizer.recognize(image)

        let analysis = NameSuggester.analyze(lines)
        propose(NameSuggester.suggest(from: lines, includeDate: includeDate))
        if let type = analysis.documentType, analysis.subject != nil {
            addAlternative(NameSuggester.compose(type, date: analysis.date, includeDate: includeDate))
        }

        if useAI, let ai = await AINameSuggester.suggest(from: lines.map(\.text).joined(separator: "\n")) {
            propose(NameSuggester.compose(ai, date: analysis.date, includeDate: includeDate))
        }
        isAnalyzing = false
    }

    func apply(_ suggestion: String) {
        name = suggestion
        lastAutoName = suggestion
    }

    /// Übernimmt den Vorschlag ins Namensfeld – aber nur, wenn der Nutzer noch nichts selbst getippt hat.
    private func propose(_ suggestion: String) {
        addAlternative(suggestion, atFront: true)
        if name.isEmpty || name == lastAutoName { apply(suggestion) }
    }

    private func addAlternative(_ suggestion: String, atFront: Bool = false) {
        guard !suggestion.isEmpty, !suggestions.contains(suggestion) else { return }
        if atFront { suggestions.insert(suggestion, at: 0) } else { suggestions.append(suggestion) }
    }
}
