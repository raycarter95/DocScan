import Foundation

/// Führt rechenintensive Arbeit (Bildverarbeitung, Texterkennung) abseits des Main-Threads aus.
func runInBackground<T>(_ work: @escaping () -> T) async -> T {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            continuation.resume(returning: work())
        }
    }
}
