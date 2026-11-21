import Foundation

/// Schlägt aus dem erkannten Text einen Dokumentnamen vor, z.B. „Rechnung Zahnarzt“.
/// Funktioniert komplett offline mit Stichwortlisten – leicht erweiterbar.
enum NameSuggester {

    // MARK: - Stichwörter (Reihenfolge = Priorität, spezifisch vor allgemein)

    /// Dokumentart. Muster sind reguläre Ausdrücke (Groß-/Kleinschreibung egal).
    static let documentTypes: [(label: String, patterns: [String])] = [
        ("Nebenkostenabrechnung", [#"nebenkostenabrechnung"#, #"betriebskostenabrechnung"#, #"heizkostenabrechnung"#]),
        ("Lohnabrechnung", [#"lohnabrechnung"#, #"gehaltsabrechnung"#, #"entgeltabrechnung"#, #"verdienstabrechnung"#]),
        ("Heil- und Kostenplan", [#"heil- ?und kostenplan"#]),
        ("Kostenvoranschlag", [#"kostenvoranschlag"#]),
        ("Mahnung", [#"\bmahnung"#, #"zahlungserinnerung"#]),
        ("Gutschrift", [#"\bgutschrift\b"#]),
        ("Rechnung", [#"\brechnung"#, #"\binvoice\b"#, #"\bliquidation\b"#, #"privatrechnung"#, #"\bbeitragsrechnung"#]),
        ("Quittung", [#"\bquittung"#, #"kassenbon"#, #"kassenbeleg"#, #"\breceipt\b"#]),
        ("Kontoauszug", [#"kontoauszug"#]),
        ("Steuerbescheid", [#"steuerbescheid"#, #"einkommensteuer"#]),
        ("Kündigungsbestätigung", [#"kündigungsbestätigung"#, #"bestätigung ihrer kündigung"#]),
        ("Kündigung", [#"\bkündigung\b"#]),
        ("Mietvertrag", [#"mietvertrag"#]),
        ("Arbeitsvertrag", [#"arbeitsvertrag"#]),
        ("Vertrag", [#"\bvertrag\b"#]),
        ("Angebot", [#"\bangebot\b"#]),
        ("Auftragsbestätigung", [#"auftragsbestätigung"#, #"bestellbestätigung"#]),
        ("Lieferschein", [#"lieferschein"#]),
        ("Versicherungsschein", [#"versicherungsschein"#, #"\bpolice\b"#, #"versicherungspolice"#]),
        ("AU-Bescheinigung", [#"arbeitsunfähigkeit"#]),
        ("Arztbrief", [#"arztbrief"#, #"befundbericht"#, #"\bbefund\b"#, #"entlassungsbrief"#]),
        ("Rezept", [#"\brezept\b"#]),
        ("Bescheid", [#"\bbescheid\b"#]),
        ("Zeugnis", [#"zeugnis\b"#]),
        ("Bescheinigung", [#"bescheinigung\b"#]),
        ("Antrag", [#"\bantrag\b"#]),
        ("Bestätigung", [#"\bbestätigung\b"#]),
    ]

    /// Absender bzw. Thema.
    static let subjects: [(label: String, patterns: [String])] = [
        ("Kieferorthopäde", [#"kieferorthopäd"#]),
        ("Zahnarzt", [#"zahnarzt"#, #"zahnärzt"#, #"zahnmedizin"#, #"zahnheilkunde"#, #"\bdentist"#, #"\bdental"#]),
        ("Tierarzt", [#"tierarzt"#, #"tierärzt"#, #"tierklinik"#, #"veterinär"#]),
        ("Augenarzt", [#"augenarzt"#, #"augenärzt"#, #"augenheilkunde"#, #"\boptiker"#]),
        ("Hautarzt", [#"hautarzt"#, #"dermatolog"#]),
        ("Frauenarzt", [#"frauenarzt"#, #"frauenärzt"#, #"gynäkolog"#]),
        ("Kinderarzt", [#"kinderarzt"#, #"kinderärzt"#, #"kinder- und jugendmedizin"#]),
        ("Orthopäde", [#"\borthopäd"#]),
        ("Physiotherapie", [#"physiotherap"#, #"krankengymnast"#]),
        ("Apotheke", [#"apotheke"#]),
        ("Labor", [#"labormedizin"#, #"\blabor\b"#]),
        ("Krankenhaus", [#"krankenhaus"#, #"klinikum"#, #"\bklinik"#]),
        ("Arzt", [#"\barzt"#, #"ärztlich"#, #"\bdr\. ?med\b"#, #"allgemeinmedizin"#, #"hausarzt"#, #"arztpraxis"#]),
        ("Krankenkasse", [#"krankenkasse"#, #"\baok\b"#, #"\bbarmer\b"#, #"\bdak\b"#, #"\bikk\b"#, #"\bbkk\b"#, #"krankenversicherung"#]),
        ("Rentenversicherung", [#"rentenversicherung"#]),
        ("Finanzamt", [#"finanzamt"#]),
        ("Familienkasse", [#"familienkasse"#, #"kindergeld"#]),
        ("Jobcenter", [#"jobcenter"#]),
        ("Agentur für Arbeit", [#"agentur für arbeit"#, #"arbeitsagentur"#]),
        ("Rundfunkbeitrag", [#"rundfunkbeitrag"#, #"beitragsservice"#]),
        ("Kfz-Versicherung", [#"kfz-versicherung"#, #"kraftfahrtversicherung"#, #"kfz-haftpflicht"#]),
        ("Haftpflichtversicherung", [#"haftpflichtversicherung"#]),
        ("Hausratversicherung", [#"hausratversicherung"#]),
        ("Versicherung", [#"versicherung"#]),
        ("Stadtwerke", [#"stadtwerke"#]),
        ("Strom", [#"stromlieferung"#, #"\bstrom\b"#, #"stromverbrauch"#]),
        ("Gas", [#"gaslieferung"#, #"\berdgas\b"#]),
        ("Wasser", [#"wasserversorgung"#, #"abwasser"#]),
        ("Miete", [#"vermieter"#, #"\bmiete\b"#, #"hausverwaltung"#]),
        ("Telekom", [#"telekom"#]),
        ("Vodafone", [#"vodafone"#]),
        ("O2", [#"\bo2\b"#, #"telef[oó]nica"#]),
        ("1&1", [#"1&1"#]),
        ("Auto", [#"autohaus"#, #"werkstatt"#, #"\btüv\b"#, #"\bdekra\b"#, #"hauptuntersuchung"#]),
        ("Kita", [#"\bkita\b"#, #"kindertagesstätte"#, #"kindergarten"#]),
        ("Schule", [#"\bschule\b"#, #"gymnasium"#, #"grundschule"#, #"realschule"#]),
        ("Fitnessstudio", [#"fitness"#]),
        ("Gericht", [#"amtsgericht"#, #"landgericht"#]),
        ("Stadtverwaltung", [#"bürgeramt"#, #"stadtverwaltung"#, #"gemeindeverwaltung"#, #"landratsamt"#, #"ordnungsamt"#]),
        ("Amazon", [#"amazon"#]),
        ("IKEA", [#"\bikea\b"#]),
        ("Bank", [#"sparkasse"#, #"volksbank"#, #"raiffeisenbank"#, #"commerzbank"#, #"deutsche bank"#, #"postbank"#, #"\bdkb\b"#, #"comdirect"#]),
    ]

    // MARK: - Analyse

    struct Analysis {
        var documentType: String?
        var subject: String?
        var date: Date?
    }

    static func analyze(_ lines: [OCRLine]) -> Analysis {
        // Fußzeile (unterste ~12 %) ignorieren – dort stehen oft Bank, Steuernummer usw.
        let body = lines.filter { $0.box.minY > 0.12 }
        let fullText = (body.isEmpty ? lines : body).map(\.text).joined(separator: "\n")
        // „Überschriften“: kurze Zeilen im oberen Bereich
        let headerText = lines.prefix(25).filter { $0.text.count <= 45 }.map(\.text).joined(separator: "\n")

        let type = firstMatch(in: documentTypes, texts: [headerText, fullText])
        let subject = firstMatch(in: subjects, texts: [fullText]) ?? senderGuess(lines)
        return Analysis(documentType: type, subject: subject, date: extractDate(lines))
    }

    /// Fertiger Vorschlag, z.B. „Rechnung Zahnarzt“ oder „2026-11-21 Rechnung Zahnarzt“.
    static func suggest(from lines: [OCRLine], includeDate: Bool) -> String {
        let a = analyze(lines)
        var parts = [a.documentType, a.subject].compactMap { $0 }
        if parts.count == 2, parts[0].localizedCaseInsensitiveContains(parts[1]) { parts.removeLast() }
        let base = parts.isEmpty ? "Scan" : parts.joined(separator: " ")
        return compose(base, date: a.date, includeDate: includeDate)
    }

    static func compose(_ base: String, date: Date?, includeDate: Bool) -> String {
        guard includeDate else { return base }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date ?? Date())) \(base)"
    }

    // MARK: - Hilfsfunktionen

    private static func firstMatch(in list: [(label: String, patterns: [String])], texts: [String]) -> String? {
        for text in texts where !text.isEmpty {
            for entry in list where entry.patterns.contains(where: { matches($0, text) }) {
                return entry.label
            }
        }
        return nil
    }

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Wenn kein bekannter Absender gefunden wurde: Firmenname aus dem Briefkopf.
    private static func senderGuess(_ lines: [OCRLine]) -> String? {
        let suffix = #"\b(gmbh|ag|kg|ohg|e\.\s?k\.|e\.\s?v\.|ug|mbh|gbr)\b"#
        for line in lines.prefix(10) where matches(suffix, line.text) {
            var name = line.text.replacingOccurrences(of: suffix, with: "", options: [.regularExpression, .caseInsensitive])
            name = name.replacingOccurrences(of: #"[&+,\-–·|]+\s*$"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            let words = name.split(separator: " ").prefix(3).joined(separator: " ")
            if words.count >= 2 { return words }
        }
        return nil
    }

    private static let monthNames = [
        "januar": 1, "jan": 1, "februar": 2, "feb": 2, "märz": 3, "mär": 3, "maerz": 3, "april": 4, "apr": 4,
        "mai": 5, "juni": 6, "jun": 6, "juli": 7, "jul": 7, "august": 8, "aug": 8, "september": 9, "sep": 9,
        "sept": 9, "oktober": 10, "okt": 10, "november": 11, "nov": 11, "dezember": 12, "dez": 12,
    ]

    /// Dokumentdatum: bevorzugt aus Zeilen mit „Datum“, sonst das erste plausible Datum.
    static func extractDate(_ lines: [OCRLine]) -> Date? {
        let preferred = lines.filter { $0.text.localizedCaseInsensitiveContains("datum") }
        for line in preferred + lines {
            if let date = parseDate(in: line.text) { return date }
        }
        return nil
    }

    private static func parseDate(in text: String) -> Date? {
        let numeric = #"\b(\d{1,2})\.\s?(\d{1,2})\.\s?(\d{4}|\d{2})\b"#
        let written = #"\b(\d{1,2})\.?\s+([A-Za-zÄÖÜäöü]{3,9})\.?\s+(\d{4})\b"#
        let lower = text.lowercased()

        if let r = lower.range(of: numeric, options: .regularExpression) {
            let parts = lower[r].components(separatedBy: CharacterSet(charactersIn: ". ")).filter { !$0.isEmpty }
            if parts.count == 3, let d = Int(parts[0]), let m = Int(parts[1]), var y = Int(parts[2]) {
                if y < 100 { y += 2000 }
                if let date = makeDate(d, m, y) { return date }
            }
        }
        if let r = lower.range(of: written, options: .regularExpression) {
            let parts = lower[r].components(separatedBy: CharacterSet(charactersIn: ". ")).filter { !$0.isEmpty }
            if parts.count == 3, let d = Int(parts[0]), let m = monthNames[parts[1]], let y = Int(parts[2]) {
                return makeDate(d, m, y)
            }
        }
        return nil
    }

    private static func makeDate(_ day: Int, _ month: Int, _ year: Int) -> Date? {
        let currentYear = Calendar.current.component(.year, from: Date())
        guard (1...31).contains(day), (1...12).contains(month), (1990...currentYear + 1).contains(year) else { return nil }
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }
}
