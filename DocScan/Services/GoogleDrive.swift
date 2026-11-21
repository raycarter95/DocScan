import UIKit
import GoogleSignIn

enum DriveError: LocalizedError {
    case notConfigured
    case noPresenter
    case notSignedIn
    case api(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Google Drive ist noch nicht eingerichtet. Trage die Client-ID in Config/Secrets.xcconfig ein (siehe README)."
        case .noPresenter: return "Anmeldefenster konnte nicht geöffnet werden."
        case .notSignedIn: return "Bitte zuerst bei Google anmelden."
        case .api(let message): return "Google Drive: \(message)"
        }
    }
}

// MARK: - Anmeldung

@MainActor
final class GoogleAuth: ObservableObject {
    /// Voller Drive-Zugriff, damit beliebige bestehende Ordner als Ziel gewählt werden können.
    static let driveScope = "https://www.googleapis.com/auth/drive"

    @Published private(set) var user: GIDGoogleUser?

    var isSignedIn: Bool { user != nil }
    var email: String? { user?.profile?.email }

    var isConfigured: Bool {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else { return false }
        return !id.isEmpty && !id.contains("DEINE_CLIENT_ID") && !id.contains("$(")
    }

    func restore() async {
        guard isConfigured else { return }
        user = try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
    }

    func signIn() async throws {
        guard isConfigured else { throw DriveError.notConfigured }
        guard let presenter = UIApplication.shared.topViewController else { throw DriveError.noPresenter }
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presenter, hint: nil, additionalScopes: [Self.driveScope]
        )
        user = result.user
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        user = nil
    }

    /// Liefert ein gültiges Zugriffstoken; meldet bei Bedarf an bzw. fordert den Drive-Zugriff an.
    func accessToken() async throws -> String {
        if user == nil { try await signIn() }
        guard var current = user else { throw DriveError.notSignedIn }
        if !(current.grantedScopes ?? []).contains(Self.driveScope) {
            guard let presenter = UIApplication.shared.topViewController else { throw DriveError.noPresenter }
            current = try await current.addScopes([Self.driveScope], presenting: presenter).user
            user = current
        }
        let refreshed = try await current.refreshTokensIfNeeded()
        return refreshed.accessToken.tokenString
    }
}

extension UIApplication {
    var topViewController: UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var controller = scene?.keyWindow?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
}

// MARK: - Drive REST API v3

struct DriveFolder: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
}

struct DriveFile: Decodable {
    let id: String
    let name: String
    let webViewLink: String?
}

struct DriveClient {
    let token: String

    func listFolders(in parentID: String) async throws -> [DriveFolder] {
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "'\(parentID)' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false"),
            URLQueryItem(name: "fields", value: "files(id,name)"),
            URLQueryItem(name: "orderBy", value: "name"),
            URLQueryItem(name: "pageSize", value: "1000"),
            URLQueryItem(name: "supportsAllDrives", value: "true"),
            URLQueryItem(name: "includeItemsFromAllDrives", value: "true"),
        ]
        struct Response: Decodable { let files: [DriveFolder] }
        return try await send(URLRequest(url: components.url!), as: Response.self).files
    }

    func createFolder(named name: String, in parentID: String) async throws -> DriveFolder {
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files?supportsAllDrives=true&fields=id,name")!)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder",
            "parents": [parentID],
        ])
        return try await send(request, as: DriveFolder.self)
    }

    func upload(fileAt url: URL, mimeType: String, to folderID: String) async throws -> DriveFile {
        let boundary = "DocScan-\(UUID().uuidString)"
        let metadata = try JSONSerialization.data(withJSONObject: [
            "name": url.lastPathComponent,
            "parents": [folderID],
        ])
        var body = Data()
        body.append("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n")
        body.append(metadata)
        body.append("\r\n--\(boundary)\r\nContent-Type: \(mimeType)\r\n\r\n")
        body.append(try Data(contentsOf: url))
        body.append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true&fields=id,name,webViewLink")!)
        request.httpMethod = "POST"
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return try await send(request, as: DriveFile.self)
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(GoogleAPIError.self, from: data))?.error.message ?? "HTTP \(status)"
            throw DriveError.api(message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct GoogleAPIError: Decodable {
    struct Inner: Decodable { let message: String }
    let error: Inner
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
