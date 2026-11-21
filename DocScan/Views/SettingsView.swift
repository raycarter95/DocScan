import SwiftUI

@MainActor
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var google: GoogleAuth
    @Environment(\.dismiss) private var dismiss

    @State private var showFolderPicker = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(settings.data.targets) { target in
                        Button {
                            settings.data.defaultTargetID = target.id
                        } label: {
                            HStack {
                                Label(target.title, systemImage: target.icon)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if target.id == settings.defaultTarget?.id {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .deleteDisabled(target.kind == .onDevice)
                    }
                    .onDelete { settings.removeTargets(at: $0) }

                    Button {
                        Task { await addDriveFolder() }
                    } label: {
                        Label("Google-Drive-Ordner hinzufügen", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Hochladen nach")
                } footer: {
                    Text("Der markierte Ordner wird beim Tippen auf „Hochladen“ verwendet. Zum Löschen nach links wischen.")
                }

                Section("Google-Konto") {
                    if !google.isConfigured {
                        Label("Noch nicht eingerichtet – Client-ID in Config/Secrets.xcconfig eintragen (siehe README).",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    } else if google.isSignedIn {
                        LabeledContent("Angemeldet", value: google.email ?? "")
                        Button("Abmelden", role: .destructive) { google.signOut() }
                    } else {
                        Button("Mit Google anmelden") {
                            Task {
                                do { try await google.signIn() } catch { errorMessage = error.localizedDescription }
                            }
                        }
                    }
                }

                Section {
                    Toggle("Datum voranstellen", isOn: $settings.data.includeDate)
                    Toggle("Apple Intelligence nutzen", isOn: $settings.data.useAI)
                } header: {
                    Text("Namensvorschlag")
                } footer: {
                    Text("Mit Datum z. B. „2026-11-21 Rechnung Zahnarzt“ (Datum aus dem Dokument). Apple Intelligence verbessert die Vorschläge auf unterstützten iPhones mit iOS 26 – alles bleibt auf dem Gerät.")
                }

                Section("Datei") {
                    Picker("Format", selection: $settings.data.fileFormat) {
                        ForEach(FileFormat.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Kontrast optimieren", isOn: $settings.data.enhanceImage)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $showFolderPicker) {
                DriveFolderPicker { folderID, path in
                    settings.addDriveTarget(folderID: folderID, path: path)
                    showFolderPicker = false
                }
            }
            .alert("Fehler", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func addDriveFolder() async {
        do {
            _ = try await google.accessToken() // meldet bei Bedarf an
            showFolderPicker = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
