//
//  VisionKitDataScannerView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Hardware-Accelerated VisionKit DataScannerViewController SwiftUI Representable
//

import SwiftUI

#if canImport(VisionKit)
import VisionKit
#endif

#if canImport(UIKit)
import UIKit
#endif

public struct VisionKitDataScannerView: UIViewControllerRepresentable {
    @Binding public var isScanning: Bool
    public let onTextRecognized: ([String]) -> Void
    public let onItemTapped: (String) -> Void
    
    public init(
        isScanning: Binding<Bool>,
        onTextRecognized: @escaping ([String]) -> Void,
        onItemTapped: @escaping (String) -> Void
    ) {
        self._isScanning = isScanning
        self.onTextRecognized = onTextRecognized
        self.onItemTapped = onItemTapped
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public func makeUIViewController(context: Context) -> UIViewController {
        #if canImport(VisionKit) && canImport(UIKit)
        if #available(iOS 16.0, *) {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                let scannerVC = DataScannerViewController(
                    recognizedDataTypes: [.text()],
                    qualityLevel: .accurate,
                    recognizesMultipleItems: true,
                    isHighFrameRateTrackingEnabled: true,
                    isPinchToZoomEnabled: true,
                    isGuidanceEnabled: true,
                    isHighlightingEnabled: true
                )
                scannerVC.delegate = context.coordinator
                do {
                    try scannerVC.startScanning()
                } catch {}
                return scannerVC
            }
        }
        #endif
        
        let fallbackVC = UIViewController()
        fallbackVC.view.backgroundColor = .black
        let label = UILabel()
        label.text = "VisionKit Data Scanner is not available on this device"
        label.textColor = .white.withAlphaComponent(0.7)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        fallbackVC.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: fallbackVC.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: fallbackVC.view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: fallbackVC.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: fallbackVC.view.trailingAnchor, constant: -20)
        ])
        return fallbackVC
    }
    
    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        #if canImport(VisionKit) && canImport(UIKit)
        if #available(iOS 16.0, *), let scanner = uiViewController as? DataScannerViewController {
            if isScanning && !scanner.isScanning {
                try? scanner.startScanning()
            } else if !isScanning && scanner.isScanning {
                scanner.stopScanning()
            }
        }
        #endif
    }
    
    #if canImport(VisionKit) && canImport(UIKit)
    public final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: VisionKitDataScannerView
        
        init(parent: VisionKitDataScannerView) {
            self.parent = parent
        }
        
        @available(iOS 16.0, *)
        public func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            processItems(allItems)
        }
        
        @available(iOS 16.0, *)
        public func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            processItems(allItems)
        }
        
        @available(iOS 16.0, *)
        public func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let textItem) = item {
                let text = textItem.transcript
                parent.onItemTapped(text)
            }
        }
        
        @available(iOS 16.0, *)
        private func processItems(_ items: [RecognizedItem]) {
            let texts: [String] = items.compactMap { item in
                if case .text(let textItem) = item {
                    return textItem.transcript
                }
                return nil
            }
            if !texts.isEmpty {
                parent.onTextRecognized(texts)
            }
        }
    }
    #else
    public final class Coordinator: NSObject {
        let parent: VisionKitDataScannerView
        init(parent: VisionKitDataScannerView) { self.parent = parent }
    }
    #endif
}
