import SwiftUI
import VisionKit

/// Live camera barcode/QR scanner (VisionKit). Calls `onCode` for every recognised payload.
/// Not available on the Simulator — check `CodeScannerView.isAvailable`.
struct CodeScannerView: UIViewControllerRepresentable {
    let onCode: @MainActor (String) -> Void

    @MainActor static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: @MainActor (String) -> Void

        init(onCode: @escaping @MainActor (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            report(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            report([item])
        }

        private func report(_ items: [RecognizedItem]) {
            for item in items {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onCode(payload)
                }
            }
        }
    }
}
