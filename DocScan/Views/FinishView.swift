import SwiftUI

@MainActor
struct FinishView: View {
    @ObservedObject var session: ScanSession
    let onNewScan: () -> Void
    let onDone: () -> Void

    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var google: GoogleAuth
    @Environment(\.openURL) private var openURL
    @FocusState private var nameFocused: Bool

    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    private enum Status {
        case idle
        case working(String)
        case success(String, link: URL?)
        case failure(String)
    }

    @State private var shareItem: ShareItem?
    @State private var status: Status = .idle

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(uiImage: session.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .frame(maxWidth: .infinity)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)

                    nameSection
                    actionSection
                    statusView
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Dokument")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onNewScan() } label: { Label("Neuer Scan", systemImage: "camera") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig", action: onDone).bold()
                }
            }
            .sheet(item: $shareItem) { item in
                ActivityView(items: [item.url])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name des Dokuments").font(.headline)
            HStack {
                TextField("z. B. Rechnung Zahnarzt", text: $session.name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                if session.isAnalyzing {
                    ProgressView()
                }
            }

            if !session.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Image(systemName: "sparkles").foregroundStyle(.tint)
                        ForEach(session.suggestions, id: \.self) { suggestion in
                            Button(suggestion) { session.apply(suggestion) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(suggestion == session.name ? Color.accentColor : Color.secondary)
                        }
                    }
                }
            }

            Text(session.isAnalyzing
                 ? "Text wird erkannt …"
                 : "Datei: \(Exporter.fileName(for: session.name, format: settings.data.fileFormat))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Teilen & Hochladen

    private var actionSection: some View {
        VStack(spacing: 12) {
            if let target = settings.defaultTarget {
                Button {
                    Task { await upload(to: target) }
                } label: {
                    VStack(spacing: 2) {
                        Label("Hochladen", systemImage: "icloud.and.arrow.up").font(.headline)
                        Text(target.title).font(.caption).lineLimit(1).opacity(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isWorking)
            }

            HStack(spacing: 12) {
                Button {
                    share()
                } label: {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if settings.data.targets.count > 1 {
                    Menu {
                        ForEach(settings.data.targets) { target in
                            Button {
                                Task { await upload(to: target) }
                            } label: {
                                Label(target.title, systemImage: target.icon)
                            }
                        }
                    } label: {
                        Label("Anderes Ziel", systemImage: "folder")
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .disabled(isWorking)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .idle:
            EmptyView()
        case .working(let text):
            HStack(spacing: 10) {
                ProgressView()
                Text(text)
            }
            .frame(maxWidth: .infinity)
        case .success(let text, let link):
            VStack(spacing: 10) {
                Label(text, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
                if let link {
                    Button("In Google Drive öffnen") { openURL(link) }
                }
            }
            .frame(maxWidth: .infinity)
        case .failure(let text):
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var isWorking: Bool {
        if case .working = status { return true }
        return false
    }

    // MARK: - Aktionen

    private func makeFile() throws -> URL {
        try Exporter.makeFile(image: session.image, lines: session.lines,
                              name: session.name, format: settings.data.fileFormat)
    }

    private func share() {
        nameFocused = false
        do {
            shareItem = ShareItem(url: try makeFile())
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func upload(to target: UploadTarget) async {
        nameFocused = false
        status = .working("Wird hochgeladen …")
        do {
            let file = try makeFile()
            switch target.kind {
            case .onDevice:
                _ = try LocalStore.save(file)
                status = .success("Gespeichert in der Dateien-App", link: nil)
            case .googleDrive:
                guard let folderID = target.folderID else { throw DriveError.notConfigured }
                let token = try await google.accessToken()
                let uploaded = try await DriveClient(token: token)
                    .upload(fileAt: file, mimeType: settings.data.fileFormat.mimeType, to: folderID)
                status = .success("Hochgeladen: \(uploaded.name)", link: uploaded.webViewLink.flatMap { URL(string: $0) })
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            status = .failure(error.localizedDescription)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
