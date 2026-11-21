import CoreGraphics

enum Corner: CaseIterable, Hashable {
    case topLeft, topRight, bottomRight, bottomLeft
}

/// Die vier Eckpunkte eines Dokuments, normalisiert auf 0...1, Ursprung oben links.
struct Quad: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    /// Das ganze Bild.
    static let full = Quad(
        topLeft: CGPoint(x: 0, y: 0), topRight: CGPoint(x: 1, y: 0),
        bottomRight: CGPoint(x: 1, y: 1), bottomLeft: CGPoint(x: 0, y: 1)
    )

    /// Startwert, wenn kein Dokument erkannt wurde.
    static let inset = Quad(
        topLeft: CGPoint(x: 0.08, y: 0.08), topRight: CGPoint(x: 0.92, y: 0.08),
        bottomRight: CGPoint(x: 0.92, y: 0.92), bottomLeft: CGPoint(x: 0.08, y: 0.92)
    )

    subscript(corner: Corner) -> CGPoint {
        get {
            switch corner {
            case .topLeft: return topLeft
            case .topRight: return topRight
            case .bottomRight: return bottomRight
            case .bottomLeft: return bottomLeft
            }
        }
        set {
            switch corner {
            case .topLeft: topLeft = newValue
            case .topRight: topRight = newValue
            case .bottomRight: bottomRight = newValue
            case .bottomLeft: bottomLeft = newValue
            }
        }
    }

    var points: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }
}
