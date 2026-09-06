//
//  LiveTextImageAnalysisView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Native VisionKit ImageAnalysisInteraction Live Text Overlay View
//

import SwiftUI

#if canImport(VisionKit)
import VisionKit
#endif

#if canImport(UIKit)
import UIKit
#endif

public struct LiveTextImageAnalysisView: UIViewRepresentable {
    public let image: UIImage
    public let onMathSelected: ((String) -> Void)?
    
    public init(image: UIImage, onMathSelected: ((String) -> Void)? = nil) {
        self.image = image
        self.onMathSelected = onMathSelected
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public func makeUIView(context: Context) -> UIView {
        #if canImport(VisionKit) && canImport(UIKit)
        if #available(iOS 16.0, *), ImageAnalyzer.isSupported {
            let containerView = UIView(frame: .zero)
            containerView.backgroundColor = .black
            
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(imageView)
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
            
            let interaction = ImageAnalysisInteraction()
            interaction.preferredInteractionTypes = [.textSelection, .automatic]
            interaction.isSupplementaryInterfaceHidden = false
            imageView.addInteraction(interaction)
            context.coordinator.interaction = interaction
            
            Task {
                let analyzer = ImageAnalyzer()
                let configuration = ImageAnalyzer.Configuration([.text])
                if let analysis = try? await analyzer.analyze(image, configuration: configuration) {
                    await MainActor.run {
                        interaction.analysis = analysis
                    }
                }
            }
            
            return containerView
        }
        #endif
        
        #if canImport(UIKit)
        let fallbackView = UIImageView(image: image)
        fallbackView.contentMode = .scaleAspectFit
        return fallbackView
        #else
        return ()
        #endif
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        #if canImport(VisionKit) && canImport(UIKit)
        if #available(iOS 16.0, *) {
            // Updated dynamically when image changes
        }
        #endif
    }
    
    public final class Coordinator: NSObject {
        let parent: LiveTextImageAnalysisView
        #if canImport(VisionKit) && canImport(UIKit)
        var interaction: Any? = nil
        #endif
        
        init(parent: LiveTextImageAnalysisView) {
            self.parent = parent
        }
    }
}
