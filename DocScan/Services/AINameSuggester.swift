import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Optional: Namensvorschlag mit dem On-Device-Sprachmodell von Apple Intelligence (iOS 26+).
/// Auf Geräten ohne Apple Intelligence wird nil zurückgegeben und der Stichwort-Vorschlag genutzt.
enum AINameSuggester {
    static func suggest(from text: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 20 else { return nil }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            let session = LanguageModelSession(instructions: """
                Du benennst eingescannte Dokumente. Antworte ausschließlich mit einem kurzen Namen auf Deutsch \
                aus 2 bis 4 Wörtern im Format "<Dokumentart> <Absender oder Thema>". \
                Beispiele: "Rechnung Zahnarzt", "Steuerbescheid 2025", "Kündigung Fitnessstudio", "Lohnabrechnung Oktober". \
                Kein Datum, keine Anführungszeichen, keine Satzzeichen, keine Dateiendung, keine Erklärung.
                """)
            do {
                let response = try await session.respond(to: "Text des Dokuments:\n\n\(String(trimmed.prefix(2500)))")
                return clean(response.content)
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    private static func clean(_ raw: String) -> String? {
        let firstLine = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let cleaned = firstLine
            .replacingOccurrences(of: #"(?i)\.(pdf|jpe?g)$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"["„“”'*:]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        guard !cleaned.isEmpty, cleaned.count <= 60 else { return nil }
        return cleaned
    }
}
