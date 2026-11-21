import UIKit

/// Demo-Modus für den Simulator (der keine Kamera hat): ein mitgeliefertes Beispieldokument.
/// Auf einem echten iPhone ist er nur mit dem Startargument „-demo YES“ sichtbar.
enum DemoMode {
    static var isEnabled: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return UserDefaults.standard.bool(forKey: "demo")
        #endif
    }

    static var image: UIImage? {
        guard let url = Bundle.main.url(forResource: "DemoDokument", withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Für automatische Screenshots: Startargument „-demoStep crop“ oder „-demoStep finish“.
    static var startStep: String? {
        UserDefaults.standard.string(forKey: "demoStep")
    }
}
