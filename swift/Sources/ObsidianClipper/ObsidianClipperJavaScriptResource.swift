import Foundation

public enum ObsidianClipperJavaScriptResource {
    public static func bundledExtractorSource() throws -> String {
        guard let url = Bundle.module.url(forResource: "obsidian-clipper-extractor", withExtension: "js") else {
            throw ObsidianClipperResourceError.missingExtractorResource
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func currentPageSnapshotScript(
        includeSelection: Bool = true,
        source: WebPageSnapshotSource = .wkWebView
    ) -> String {
        """
        (() => {
          function selectionHTML() {
            if (!\(includeSelection ? "true" : "false")) return null;
            const selection = window.getSelection && window.getSelection();
            if (!selection || selection.rangeCount === 0 || selection.isCollapsed) return null;
            const container = document.createElement('div');
            for (let index = 0; index < selection.rangeCount; index++) {
              container.appendChild(selection.getRangeAt(index).cloneContents());
            }
            return container.innerHTML;
          }
          return JSON.stringify({
            url: document.URL || window.location.href,
            baseURL: document.baseURI || null,
            title: document.title || null,
            html: document.documentElement ? document.documentElement.outerHTML : "",
            selectedHTML: selectionHTML(),
            capturedAt: new Date().toISOString(),
            source: "\(source.rawValue)"
          });
        })();
        """
    }

    static func currentPageSnapshotFunctionBody(
        includeSelection: Bool = true,
        source: WebPageSnapshotSource = .webPage
    ) -> String {
        "return \(currentPageSnapshotScript(includeSelection: includeSelection, source: source))"
    }

    public static func currentPageExtractionScript(
        configuration: WebPageClipperConfiguration = WebPageClipperConfiguration()
    ) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(configuration)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return """
        \(try bundledExtractorSource())
        JSON.stringify(window.__ObsidianClipperSwift.extractCurrentPage(\(json)));
        """
    }

    static func currentPageExtractionFunctionBody(
        configuration: WebPageClipperConfiguration = WebPageClipperConfiguration()
    ) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(configuration)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return """
        \(try bundledExtractorSource())
        return JSON.stringify(window.__ObsidianClipperSwift.extractCurrentPage(\(json)));
        """
    }
}

public enum ObsidianClipperResourceError: LocalizedError {
    case missingExtractorResource
    case invalidJavaScriptResult
    case invalidSnapshotPayload
    case webPageLoadTimedOut

    public var errorDescription: String? {
        switch self {
        case .missingExtractorResource:
            "The bundled obsidian-clipper-extractor.js resource is missing."
        case .invalidJavaScriptResult:
            "The webpage extraction JavaScript returned an invalid result."
        case .invalidSnapshotPayload:
            "The webpage snapshot JavaScript returned an invalid payload."
        case .webPageLoadTimedOut:
            "The webpage snapshot did not finish loading in the WebKit extractor."
        }
    }
}
