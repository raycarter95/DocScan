import SwiftUI

/// Ablauf: Kamera → Erkennung → Ränder anpassen → Name / Teilen / Hochladen
@MainActor
struct ScanFlowView: View {
    private enum Step {
        case camera
        case detecting(UIImage)
        case crop(UIImage, detected: Quad?)
        case processing
        case finish(ScanSession)
    }

    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step

    init(image: UIImage?) {
        _step = State(initialValue: image.map { .detecting($0) } ?? .camera)
    }

    var body: some View {
        switch step {
        case .camera:
            CameraPicker { image in
                if let image { step = .detecting(image) } else { dismiss() }
            }
            .ignoresSafeArea()

        case .detecting(let raw):
            busy("Dokument wird erkannt …")
                .task { await detect(raw) }

        case .crop(let image, let detected):
            CropView(
                image: image,
                detectedQuad: detected,
                onCancel: { dismiss() },
                onRetake: { step = .camera },
                onConfirm: { quad in Task { await finish(image, quad: quad) } }
            )

        case .processing:
            busy("Wird verarbeitet …")

        case .finish(let session):
            FinishView(session: session, onNewScan: { step = .camera }, onDone: { dismiss() })
        }
    }

    private func busy(_ text: String) -> some View {
        ProgressView(text)
            .tint(.white)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
    }

    private func detect(_ raw: UIImage) async {
        let image = await runInBackground { raw.normalized() }
        let quad = await DocumentProcessor.detectDocument(in: image)
        step = .crop(image, detected: quad)
    }

    private func finish(_ image: UIImage, quad: Quad) async {
        step = .processing
        let enhance = settings.data.enhanceImage
        let result = await runInBackground {
            DocumentProcessor.extract(image, quad: quad, enhance: enhance)
        }
        let session = ScanSession(image: result)
        step = .finish(session)
        await session.analyze(includeDate: settings.data.includeDate, useAI: settings.data.useAI)
    }
}
