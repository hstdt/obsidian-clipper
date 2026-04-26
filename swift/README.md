# ObsidianClipper Swift Package

ObsidianClipper is a Swift package for capturing and extracting readable webpage content from WebKit-based apps. It bundles a Defuddle-based JavaScript bridge for live `WKWebView` and SwiftUI `WebPage` surfaces, and exposes Swift models for Markdown and Obsidian-style note rendering.

## Products

- `ObsidianClipper`: Swift models and runtime helpers for webpage clipping.

## Installation

Add this repository as a Swift package dependency and link the `ObsidianClipper` product:

```swift
.package(url: "https://github.com/<owner>/obsidian-clipper.git", branch: "main")
```

## Entry Points

- `WKWebView.makeObsidianClipperSnapshot()` captures the currently loaded page DOM.
- `WKWebView.extractObsidianClipperResult()` runs the bundled Defuddle-based JavaScript extractor in the current page.
- `WebPage.makeObsidianClipperSnapshot()` and `WebPage.extractObsidianClipperResult()` provide the same current-page extraction API for SwiftUI `WebPage`.
- `WKWebPageDefuddleExtractor.extract(from:)` loads a `WebPageSnapshot` into an internal `WKWebView` and runs the bundled Defuddle extractor.
- `ObsidianClipper.clip(_:template:)` attaches an optional rendered note to an existing Defuddle result.
- `ObsidianTemplateRenderer.render(result:template:)` creates an Obsidian-style note with frontmatter and Markdown body.

This package intentionally does not provide a pure Swift readability or HTML parser. Webpage extraction is performed by the bundled Defuddle JavaScript bridge in WebKit.

## Usage

Extract the currently loaded page from a `WKWebView`:

```swift
import ObsidianClipper
import WebKit

let result = try await webView.extractObsidianClipperResult()
print(result.title ?? "Untitled")
print(result.markdown)
```

Extract the currently loaded page from SwiftUI `WebPage`:

```swift
import ObsidianClipper
import WebKit

if #available(iOS 26.0, macOS 26.0, *) {
    let result = try await page.extractObsidianClipperResult()
    print(result.markdown)
}
```

Render an Obsidian-style note from the extracted result:

```swift
let note = ObsidianTemplateRenderer().render(result: result, template: .default)
print(note.fullContent)
```

Extract from provided HTML by loading it into an internal WebKit view and then running the same Defuddle bridge:

```swift
let snapshot = WebPageSnapshot(
    url: URL(string: "https://example.com/article")!,
    html: html
)

let result = try await WKWebPageDefuddleExtractor().extract(from: snapshot)
```

## Updating The Bundled Defuddle Extractor

Run from the repository root:

```bash
swift/Scripts/update-defuddle-resource.sh
```

The script installs npm dependencies from the lockfile, bundles a small Defuddle bridge, and writes only:

```text
swift/Sources/ObsidianClipper/Resources/obsidian-clipper-extractor.js
```

It does not modify upstream `src/` files.

Set `OBSIDIAN_CLIPPER_SKIP_NPM_INSTALL=1` to reuse an existing `node_modules` directory during local iteration.
