import XCTest
@testable import ObsidianClipper

final class ObsidianClipperResourceTests: XCTestCase {
    func testBundledExtractorResourceCanBuildCurrentPageScript() throws {
        let source = try ObsidianClipperJavaScriptResource.bundledExtractorSource()
        XCTAssertTrue(source.contains("__ObsidianClipperSwift"))
        XCTAssertTrue(source.contains("extractCurrentPage"))

        let script = try ObsidianClipperJavaScriptResource.currentPageExtractionScript(
            configuration: WebPageClipperConfiguration(includeFullHTML: true, includeSelection: false, maxBlockCount: 12)
        )

        XCTAssertTrue(script.contains("\"includeFullHTML\":true"))
        XCTAssertTrue(script.contains("\"includeSelection\":false"))
        XCTAssertTrue(script.contains("\"maxBlockCount\":12"))
        XCTAssertTrue(script.contains("absoluteURL"))
        XCTAssertTrue(script.contains("JSON.stringify"))

        let webPageSnapshotScript = ObsidianClipperJavaScriptResource.currentPageSnapshotScript(source: .webPage)
        XCTAssertTrue(webPageSnapshotScript.contains(#"source: "webPage""#))

        let webPageScript = try ObsidianClipperJavaScriptResource.currentPageExtractionFunctionBody(
            configuration: WebPageClipperConfiguration(maxBlockCount: 12)
        )
        XCTAssertTrue(webPageScript.contains("return JSON.stringify"))
    }

    func testJSONDecodesWKWebViewStyleSnapshotPayload() throws {
        let json = """
        {
          "url": "https://example.com/page",
          "baseURL": "https://example.com/",
          "title": "Loaded Page",
          "html": "<html><body></body></html>",
          "selectedHTML": "<p>Selected</p>",
          "capturedAt": "2026-04-26T08:00:00.123Z",
          "source": "wkWebView"
        }
        """

        let snapshot = try ObsidianClipperJSON.decodeSnapshot(from: json)

        XCTAssertEqual(snapshot.url.absoluteString, "https://example.com/page")
        XCTAssertEqual(snapshot.baseURL?.absoluteString, "https://example.com/")
        XCTAssertEqual(snapshot.title, "Loaded Page")
        XCTAssertEqual(snapshot.source, .wkWebView)
        XCTAssertEqual(snapshot.selectedHTML, "<p>Selected</p>")
    }

    func testJSONDecodesProvidedHTMLSnapshotSource() throws {
        let json = """
        {
          "url": "https://example.com/page",
          "title": "Provided Page",
          "html": "<html><body></body></html>",
          "capturedAt": "2026-04-26T08:00:00Z",
          "source": "providedHTML"
        }
        """

        let snapshot = try ObsidianClipperJSON.decodeSnapshot(from: json)

        XCTAssertEqual(snapshot.source, .providedHTML)
        XCTAssertEqual(snapshot.title, "Provided Page")
    }
}
