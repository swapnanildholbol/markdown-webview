#if os(macOS)

import SwiftUI
import WebKit

@available(macOS 11.0, *)
public struct MarkdownWebView: NSViewRepresentable {
    let markdownContent: String
    
    public init(_ markdownContent: String) {
        self.markdownContent = markdownContent
    }
    
    public func makeCoordinator() -> Coordinator { .init(parent: self) }
    
    public func makeNSView(context: Context) -> CustomWebView { context.coordinator.nsView }
    
    public func updateNSView(_ nsView: CustomWebView, context: Context) {
        guard !nsView.isLoading else { return } /// This function might be called when the page is still loading, at which time `window.proxy` is not available yet.
        nsView.updateMarkdownContent(self.markdownContent)
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: MarkdownWebView
        let nsView: CustomWebView
        
        init(parent: MarkdownWebView) {
            self.parent = parent
            
            let webViewConfiguration: WKWebViewConfiguration = .init()
            self.nsView = .init(frame: .zero, configuration: webViewConfiguration)
            
            super.init()
            
            self.nsView.navigationDelegate = self
            self.nsView.uiDelegate = self
            self.nsView.setContentHuggingPriority(.required, for: .vertical)
            
            self.nsView.setValue(true, forKey: "drawsTransparentBackground")
            
            guard let templateFileURL = Bundle.module.url(forResource: "template", withExtension: ""),
                  let templateString = try? String(contentsOf: templateFileURL),
                  let scriptFileURL = Bundle.module.url(forResource: "script", withExtension: ""),
                  let scriptString = try? String(contentsOf: scriptFileURL),
                  let stylesheetFileURL = Bundle.module.url(forResource: "default-macOS", withExtension: ""),
                  let stylesheetString = try? String(contentsOf: stylesheetFileURL)
            else { return }
            let htmlString = templateString
                .replacingOccurrences(of: "PLACEHOLDER_SCRIPT", with: scriptString)
                .replacingOccurrences(of: "PLACEHOLDER_STYLESHEET", with: stylesheetString)
            self.nsView.loadHTMLString(htmlString, baseURL: nil)
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            (webView as! CustomWebView).updateMarkdownContent(self.parent.markdownContent)
        }
    }
    
    public class CustomWebView: WKWebView {
        var contentHeight: Double = 0
        
        public override var intrinsicContentSize: NSSize {
            let width = super.intrinsicContentSize.width
            return .init(width: width, height: self.contentHeight)
        }
        
        public override func scrollWheel(with event: NSEvent) {
            self.nextResponder?.scrollWheel(with: event)
            return
        }
        
        public override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
            menu.items.removeAll { $0.identifier == .init("WKMenuItemIdentifierReload") }
        }
        
        func updateMarkdownContent(_ markdownContent: String) {
            guard let markdownContentBase64Encoded = markdownContent.data(using: .utf8)?.base64EncodedString() else { return }
            
            self.callAsyncJavaScript("window.updateWithMarkdownContentBase64Encoded(`\(markdownContentBase64Encoded)`)", in: nil, in: .page, completionHandler: nil)
            
            self.evaluateJavaScript("document.body.scrollHeight", in: nil, in: .page) { result in
                guard let contentHeight = try? result.get() as? Double else { return }
                self.contentHeight = contentHeight
                self.invalidateIntrinsicContentSize()
            }
        }
    }
}

#endif
