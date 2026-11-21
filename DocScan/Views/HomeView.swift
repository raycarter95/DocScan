import SwiftUI
import PhotosUI

@MainActor
struct HomeView: View {
    @EnvironmentObject private var settings: SettingsStore

    private struct FlowRoute: Identifiable {
        let id = UUID()
        let image: UIImage?
    }

    @State private var route: FlowRoute?
    @State private var photoItem: PhotosPickerItem?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 84, weight: .light))
                    .foregroundStyle(.tint)
                Text("Dokument scannen")
                    .font(.largeTitle.bold())
                Text("Foto machen, Ränder prüfen, Namen bestätigen – fertig.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()

                Button {
                    route = FlowRoute(image: nil)
                } label: {
                    Label("Foto aufnehmen", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Aus Fotos wählen", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if let target = settings.defaultTarget {
                    Button { showSettings = true } label: {
                        Label("Hochladen nach: \(target.title)", systemImage: target.icon)
                            .font(.footnote)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                }
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .fullScreenCover(item: $route) { route in
                ScanFlowView(image: route.image)
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        route = FlowRoute(image: image)
                    }
                    photoItem = nil
                }
            }
        }
    }
}
