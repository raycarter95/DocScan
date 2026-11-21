import Foundation
import SwiftUI

enum FileFormat: String, Codable, CaseIterable, Identifiable {
    case pdf, jpeg

    var id: String { rawValue }
    var label: String { self == .pdf ? "PDF (durchsuchbar)" : "JPEG-Bild" }
    var fileExtension: String { self == .pdf ? "pdf" : "jpg" }
    var mimeType: String { self == .pdf ? "application/pdf" : "image/jpeg" }
}

/// Ein Ziel, wohin „Hochladen“ das Dokument schickt.
struct UploadTarget: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case googleDrive
        case onDevice
    }

    var id = UUID()
    var kind: Kind
    var title: String
    var folderID: String?

    var icon: String {
        switch kind {
        case .googleDrive: return "externaldrive.badge.icloud"
        case .onDevice: return "iphone"
        }
    }

    static let onDevice = UploadTarget(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        kind: .onDevice,
        title: "Auf dem iPhone (Dateien-App)"
    )
}

struct AppSettings: Codable, Equatable {
    var targets: [UploadTarget] = [.onDevice]
    var defaultTargetID: UUID? = UploadTarget.onDevice.id
    var includeDate = false
    var useAI = true
    var enhanceImage = true
    var fileFormat: FileFormat = .pdf
}

@MainActor
final class SettingsStore: ObservableObject {
    private static let key = "appSettings.v1"

    @Published var data: AppSettings {
        didSet { save() }
    }

    init() {
        if let raw = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: raw) {
            data = decoded
        } else {
            data = AppSettings()
        }
    }

    var defaultTarget: UploadTarget? {
        data.targets.first { $0.id == data.defaultTargetID } ?? data.targets.first
    }

    func addDriveTarget(folderID: String, path: String) {
        if let existing = data.targets.first(where: { $0.folderID == folderID }) {
            data.defaultTargetID = existing.id
            return
        }
        let target = UploadTarget(kind: .googleDrive, title: path, folderID: folderID)
        data.targets.append(target)
        data.defaultTargetID = target.id
    }

    func removeTargets(at offsets: IndexSet) {
        let removable = offsets.filter { data.targets[$0].kind != .onDevice }
        data.targets.remove(atOffsets: IndexSet(removable))
        if defaultTarget?.id != data.defaultTargetID {
            data.defaultTargetID = data.targets.first?.id
        }
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: Self.key)
        }
    }
}
