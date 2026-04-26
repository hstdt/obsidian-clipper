#if canImport(WebKit)
import Foundation
import WebKit

@MainActor
public extension WKWebView {
    func makeObsidianClipperSnapshot(
        includeSelection: Bool = true
    ) async throws -> WebPageSnapshot {
        let script = ObsidianClipperJavaScriptResource.currentPageSnapshotScript(
            includeSelection: includeSelection,
            source: .wkWebView
        )
        guard let json = try await evaluateJavaScript(script) as? String else {
            throw ObsidianClipperResourceError.invalidSnapshotPayload
        }
        return try ObsidianClipperJSON.decodeSnapshot(from: json)
    }

    func extractObsidianClipperResult(
        configuration: WebPageClipperConfiguration = WebPageClipperConfiguration()
    ) async throws -> WebPageDefuddleResult {
        let script = try ObsidianClipperJavaScriptResource.currentPageExtractionScript(configuration: configuration)
        guard let json = try await evaluateJavaScript(script) as? String else {
            throw ObsidianClipperResourceError.invalidJavaScriptResult
        }
        return try ObsidianClipperJSON.decodeDefuddleResult(from: json)
    }

    func makeObsidianClip(
        configuration: WebPageClipperConfiguration = WebPageClipperConfiguration(),
        template: ObsidianClipTemplate? = nil
    ) async throws -> WebPageClip {
        let result = try await extractObsidianClipperResult(configuration: configuration)
        let note = template.map { ObsidianTemplateRenderer().render(result: result, template: $0) }
        return WebPageClip(defuddleResult: result, obsidianNote: note)
    }
}

@available(iOS 26.0, macOS 26.0, *)
@MainActor
public extension WebPage {
    func makeObsidianClipperSnapshot(
        includeSelection: Bool = true
    ) async throws -> WebPageSnapshot {
        let script = ObsidianClipperJavaScriptResource.currentPageSnapshotFunctionBody(
            includeSelection: includeSelection,
            source: .webPage
        )
        guard let json = try await callJavaScript(script) as? String else {
            throw ObsidianClipperResourceError.invalidSnapshotPayload
        }
        return try ObsidianClipperJSON.decodeSnapshot(from: json)
    }

    func extractObsidianClipperResult(
        configuration: WebPageClipperConfiguration = WebPageClipperConfiguration()
    ) async throws -> WebPageDefuddleResult {
        let script = try ObsidianClipperJavaScriptResource.currentPageExtractionFunctionBody(configuration: configuration)
        guard let json = try await callJavaScript(script) as? String else {
            throw ObsidianClipperResourceError.invalidJavaScriptResult
        }
        var result = try ObsidianClipperJSON.decodeDefuddleResult(from: json)
        result.diagnostics.engine = "defuddle-webpage"
        return result
    }

    func makeObsidianClip(
        configuration: WebPageClipperConfiguration = WebPageClipperConfiguration(),
        template: ObsidianClipTemplate? = nil
    ) async throws -> WebPageClip {
        let result = try await extractObsidianClipperResult(configuration: configuration)
        let note = template.map { ObsidianTemplateRenderer().render(result: result, template: $0) }
        return WebPageClip(defuddleResult: result, obsidianNote: note)
    }
}

@MainActor
public final class WKWebPageDefuddleExtractor {
    private let webViewConfiguration: WKWebViewConfiguration

    public init(webViewConfiguration: WKWebViewConfiguration = WKWebViewConfiguration()) {
        self.webViewConfiguration = webViewConfiguration
    }

    public func extract(
        from snapshot: WebPageSnapshot,
        configuration: WebPageClipperConfiguration = WebPageClipperConfiguration(),
        timeoutNanoseconds: UInt64 = 15_000_000_000
    ) async throws -> WebPageDefuddleResult {
        let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        let waiter = WKWebPageLoadWaiter(timeoutNanoseconds: timeoutNanoseconds)
        webView.navigationDelegate = waiter
        try await waiter.load(snapshot.html, baseURL: snapshot.baseURL ?? snapshot.url, in: webView)
        var result = try await webView.extractObsidianClipperResult(configuration: configuration)
        if configuration.includeSelection, result.selectedHTML == nil {
            result.selectedHTML = snapshot.selectedHTML
        }
        return result
    }
}

@MainActor
private final class WKWebPageLoadWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    private let timeoutNanoseconds: UInt64

    init(timeoutNanoseconds: UInt64) {
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    func load(_ html: String, baseURL: URL?, in webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadHTMLString(html, baseURL: baseURL)
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                self.finish(.failure(ObsidianClipperResourceError.webPageLoadTimedOut))
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<Void, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
#endif
