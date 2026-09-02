import SwiftUI
import WebKit

#if canImport(UIKit)
import UIKit

public struct MermaidDiagramView: UIViewRepresentable {
    public let mermaidCode: String
    
    public init(mermaidCode: String) {
        self.mermaidCode = mermaidCode
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        let cleanCode = mermaidCode.replacingOccurrences(of: "`", with: "")
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <script type="module">
                import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
                mermaid.initialize({ startOnLoad: true, theme: 'dark', background: 'transparent' });
            </script>
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    background-color: transparent;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    color: white;
                    font-family: -apple-system, sans-serif;
                }
                .mermaid {
                    background: transparent;
                }
            </style>
        </head>
        <body>
            <div class="mermaid">
                \(cleanCode)
            </div>
        </body>
        </html>
        """
        uiView.loadHTMLString(html, baseURL: nil)
    }
}
#endif
