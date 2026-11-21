import SwiftUI

/// Durchsucht „Meine Ablage“ und lässt einen Ordner als Upload-Ziel wählen.
struct DriveFolderPicker: View {
    let onPick: (_ folderID: String, _ path: String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DriveFolderList(folderID: "root", path: ["Google Drive"], onPick: onPick)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                    }
                }
        }
    }
}

@MainActor
private struct DriveFolderList: View {
    let folderID: String
    let path: [String]
    let onPick: (_ folderID: String, _ path: String) -> Void

    @EnvironmentObject private var google: GoogleAuth
    @State private var folders: [DriveFolder] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showNewFolder = false
    @State private var newFolderName = ""

    var body: some View {
        List {
            Section {
                Button {
                    onPick(folderID, path.joined(separator: " › "))
                } label: {
                    Label("Diesen Ordner verwenden", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                }
            }

            Section("Unterordner") {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if folders.isEmpty {
                    Text("Keine Unterordner").foregroundStyle(.secondary)
                }
                ForEach(folders) { folder in
                    NavigationLink {
                        DriveFolderList(folderID: folder.id, path: path + [folder.name], onPick: onPick)
                    } label: {
                        Label(folder.name, systemImage: "folder.fill")
                    }
                }
            }
        }
        .navigationTitle(path.last ?? "Google Drive")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNewFolder = true } label: { Image(systemName: "folder.badge.plus") }
                    .accessibilityLabel("Neuer Ordner")
            }
        }
        .alert("Neuer Ordner", isPresented: $showNewFolder) {
            TextField("Name", text: $newFolderName)
            Button("Erstellen") { Task { await createFolder() } }
            Button("Abbrechen", role: .cancel) { newFolderName = "" }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let token = try await google.accessToken()
            folders = try await DriveClient(token: token).listFolders(in: folderID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createFolder() async {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        newFolderName = ""
        guard !name.isEmpty else { return }
        do {
            let token = try await google.accessToken()
            let folder = try await DriveClient(token: token).createFolder(named: name, in: folderID)
            folders.append(folder)
            folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
