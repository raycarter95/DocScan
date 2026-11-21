import SwiftUI
import AVFoundation

/// Zeigt das Foto mit den erkannten Dokumenträndern. Die vier Ecken lassen sich verschieben,
/// oben rechts bestätigt das Häkchen.
struct CropView: View {
    let image: UIImage
    let detectedQuad: Quad?
    let onCancel: () -> Void
    let onRetake: () -> Void
    let onConfirm: (Quad) -> Void

    @State private var quad: Quad
    @State private var activeCorner: Corner?
    @State private var dragStart: CGPoint?

    private let handleSize: CGFloat = 28
    private let loupeSize: CGFloat = 120
    private let loupeZoom: CGFloat = 2.5

    init(image: UIImage, detectedQuad: Quad?, onCancel: @escaping () -> Void,
         onRetake: @escaping () -> Void, onConfirm: @escaping (Quad) -> Void) {
        self.image = image
        self.detectedQuad = detectedQuad
        self.onCancel = onCancel
        self.onRetake = onRetake
        self.onConfirm = onConfirm
        _quad = State(initialValue: detectedQuad ?? .inset)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let rect = AVMakeRect(aspectRatio: image.size,
                                          insideRect: CGRect(origin: .zero, size: geo.size).insetBy(dx: 20, dy: 20))
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)

                        quadPath(in: rect)
                            .fill(Color.accentColor.opacity(0.18))
                        quadPath(in: rect)
                            .stroke(Color.accentColor, lineWidth: 2)

                        ForEach(Corner.allCases, id: \.self) { corner in
                            handle(for: corner, in: rect)
                        }

                        if let corner = activeCorner {
                            loupe(for: corner, in: rect, container: geo.size)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }

                bottomBar
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Ränder anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onConfirm(quad) } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                    }
                    .accessibilityLabel("Fertig")
                }
            }
        }
    }

    // MARK: - Teile

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Text(detectedQuad == nil
                 ? "Kein Dokument erkannt – zieh die Ecken an die Ränder."
                 : "Dokument erkannt. Ecken bei Bedarf verschieben.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))

            HStack {
                Button(action: onRetake) {
                    Label("Neu", systemImage: "camera.rotate")
                }
                Spacer()
                if let detected = detectedQuad, quad != detected {
                    Button { withAnimation { quad = detected } } label: {
                        Label("Automatisch", systemImage: "wand.and.stars")
                    }
                }
                Spacer()
                Button { withAnimation { quad = .full } } label: {
                    Label("Ganzes Bild", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func position(_ p: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
    }

    private func quadPath(in rect: CGRect) -> Path {
        Path { path in
            let pts = quad.points.map { position($0, in: rect) }
            path.move(to: pts[0])
            pts.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
        }
    }

    private func handle(for corner: Corner, in rect: CGRect) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))
            .frame(width: handleSize, height: handleSize)
            .scaleEffect(activeCorner == corner ? 1.25 : 1)
            .frame(width: 56, height: 56) // größere Trefferfläche
            .contentShape(Rectangle())
            .position(position(quad[corner], in: rect))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = quad[corner]
                            activeCorner = corner
                        }
                        guard let start = dragStart else { return }
                        quad[corner] = CGPoint(
                            x: min(max(start.x + value.translation.width / rect.width, 0), 1),
                            y: min(max(start.y + value.translation.height / rect.height, 0), 1)
                        )
                    }
                    .onEnded { _ in
                        dragStart = nil
                        activeCorner = nil
                    }
            )
    }

    /// Lupe, damit die Ecke unter dem Finger genau platziert werden kann.
    private func loupe(for corner: Corner, in rect: CGRect, container: CGSize) -> some View {
        let p = quad[corner]
        let zoomedW = rect.width * loupeZoom
        let zoomedH = rect.height * loupeZoom
        let onLeft = p.x < 0.5
        let center = CGPoint(x: onLeft ? container.width - loupeSize / 2 - 16 : loupeSize / 2 + 16,
                             y: loupeSize / 2 + 16)

        return ZStack {
            Image(uiImage: image)
                .resizable()
                .frame(width: zoomedW, height: zoomedH)
                .offset(x: zoomedW / 2 - p.x * zoomedW, y: zoomedH / 2 - p.y * zoomedH)
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: loupeSize, height: loupeSize)
        .background(Color.black)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(radius: 6)
        .position(center)
        .allowsHitTesting(false)
    }
}
