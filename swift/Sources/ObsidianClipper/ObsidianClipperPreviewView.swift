#if DEBUG && canImport(SwiftUI) && canImport(WebKit)
import SwiftUI
import WebKit

struct ObsidianClipperPreviewView: View {
    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            ObsidianClipperModernPreviewView()
        } else {
            ObsidianClipperWKOnlyPreviewView()
        }
    }
}

private enum ObsidianClipperPreviewPane: Hashable {
    case webView
    case result
}

private enum ObsidianClipperPreviewEngine: Hashable {
    case wkWebView
    case webPage
}

@available(iOS 26.0, macOS 26.0, *)
private struct ObsidianClipperModernPreviewView: View {
    @State private var urlString = ""
    @State private var engine = ObsidianClipperPreviewEngine.wkWebView
    @State private var selectedPane = ObsidianClipperPreviewPane.webView

    @StateObject private var wkWebViewModel = ObsidianClipperPreviewWKWebViewModel()
    @StateObject private var webPageModel = ObsidianClipperPreviewWebPageModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("URL", text: $urlString)
                    .onSubmit(go)
                Button("Go", action: go)
            }

            Picker("Engine", selection: $engine) {
                Text("WKWebView").tag(ObsidianClipperPreviewEngine.wkWebView)
                Text("WebPage").tag(ObsidianClipperPreviewEngine.webPage)
            }
            .pickerStyle(.menu)
            .onChange(of: engine) { _, _ in
                reloadSelectedEngine()
            }

            Picker("Preview", selection: $selectedPane) {
                Text("WebView").tag(ObsidianClipperPreviewPane.webView)
                Text("Result").tag(ObsidianClipperPreviewPane.result)
            }
            .pickerStyle(.segmented)

            Group {
                switch selectedPane {
                case .webView:
                    switch engine {
                    case .wkWebView:
                        ObsidianClipperPreviewWKWebView(model: wkWebViewModel)
                    case .webPage:
                        ObsidianClipperPreviewWebPageView(model: webPageModel)
                    }
                case .result:
                    ObsidianClipperResultList(
                        status: activeStatus,
                        isLoading: activeIsLoading,
                        result: activeResult,
                        note: activeNote
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .frame(minWidth: 760, minHeight: 640)
    }

    private var activeStatus: String {
        switch engine {
        case .wkWebView:
            wkWebViewModel.status
        case .webPage:
            webPageModel.status
        }
    }

    private var activeIsLoading: Bool {
        switch engine {
        case .wkWebView:
            wkWebViewModel.isLoading
        case .webPage:
            webPageModel.isLoading
        }
    }

    private var activeResult: WebPageDefuddleResult? {
        switch engine {
        case .wkWebView:
            wkWebViewModel.result
        case .webPage:
            webPageModel.result
        }
    }

    private var activeNote: ObsidianNote? {
        switch engine {
        case .wkWebView:
            wkWebViewModel.note
        case .webPage:
            webPageModel.note
        }
    }

    private func go() {
        guard let url = normalizedURL() else {
            setActiveStatus("Enter a valid URL.")
            return
        }
        reload(url)
    }

    private func reloadSelectedEngine() {
        guard let url = normalizedURL() else { return }
        reload(url)
    }

    private func reload(_ url: URL) {
        selectedPane = .webView
        switch engine {
        case .wkWebView:
            wkWebViewModel.load(url)
        case .webPage:
            webPageModel.load(url)
        }
    }

    private func normalizedURL() -> URL? {
        ObsidianClipperPreviewURLNormalizer.url(from: urlString)
    }

    private func setActiveStatus(_ status: String) {
        switch engine {
        case .wkWebView:
            wkWebViewModel.status = status
        case .webPage:
            webPageModel.status = status
        }
    }
}

private struct ObsidianClipperWKOnlyPreviewView: View {
    @State private var urlString = ""
    @State private var selectedPane = ObsidianClipperPreviewPane.webView
    @StateObject private var model = ObsidianClipperPreviewWKWebViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("URL", text: $urlString)
                    .onSubmit(go)
                Button("Go", action: go)
            }

            Picker("Preview", selection: $selectedPane) {
                Text("WebView").tag(ObsidianClipperPreviewPane.webView)
                Text("Result").tag(ObsidianClipperPreviewPane.result)
            }
            .pickerStyle(.segmented)

            Group {
                switch selectedPane {
                case .webView:
                    ObsidianClipperPreviewWKWebView(model: model)
                case .result:
                    ObsidianClipperResultList(
                        status: model.status,
                        isLoading: model.isLoading,
                        result: model.result,
                        note: model.note
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .frame(minWidth: 760, minHeight: 640)
    }

    private func go() {
        guard let url = ObsidianClipperPreviewURLNormalizer.url(from: urlString) else {
            model.status = "Enter a valid URL."
            return
        }
        selectedPane = .webView
        model.load(url)
    }
}

private enum ObsidianClipperPreviewURLNormalizer {
    static func url(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }
}

@MainActor
private final class ObsidianClipperPreviewWKWebViewModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var isLoading = false
    @Published var status = "Enter a URL and press Go."
    @Published var result: WebPageDefuddleResult?
    @Published var note: ObsidianNote?

    let webView: WKWebView

    override init() {
        self.webView = WKWebView()
        super.init()
        webView.navigationDelegate = self
    }

    func load(_ url: URL) {
        result = nil
        note = nil
        status = "Loading \(url.absoluteString)"
        isLoading = true
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            await generateFromLoadedPage()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    private func generateFromLoadedPage() async {
        status = "Generating result from the loaded page."
        do {
            let extracted = try await webView.extractObsidianClipperResult(
                configuration: WebPageClipperConfiguration(includeFullHTML: false, includeSelection: true)
            )
            result = extracted
            note = ObsidianTemplateRenderer().render(result: extracted, template: .default)
            status = "Generated \(extracted.blocks.count) blocks."
        } catch {
            fail(error)
        }
        isLoading = false
    }

    private func fail(_ error: Error) {
        isLoading = false
        status = error.localizedDescription
    }
}

@available(iOS 26.0, macOS 26.0, *)
@MainActor
private final class ObsidianClipperPreviewWebPageModel: ObservableObject {
    @Published var isLoading = false
    @Published var status = "Enter a URL and press Go."
    @Published var result: WebPageDefuddleResult?
    @Published var note: ObsidianNote?

    let page = WebPage(configuration: .obsidianClipperPreviewConfiguration())
    private var loadTask: Task<Void, Never>?

    func load(_ url: URL) {
        loadTask?.cancel()
        result = nil
        note = nil
        status = "Loading \(url.absoluteString)"
        isLoading = true
        loadTask = Task { @MainActor [weak self] in
            await self?.loadAndGenerate(url)
        }
    }

    private func loadAndGenerate(_ url: URL) async {
        do {
            let events = page.load(URLRequest(url: url))
            navigationLoop: for try await event in events {
                guard Task.isCancelled == false else { return }
                switch event {
                case .committed:
                    status = "Page loaded. Waiting for completion."
                case .finished:
                    break navigationLoop
                default:
                    continue
                }
            }

            guard Task.isCancelled == false else { return }
            status = "Generating result from the loaded page."
            let extracted = try await page.extractObsidianClipperResult(
                configuration: WebPageClipperConfiguration(includeFullHTML: false, includeSelection: true)
            )
            result = extracted
            note = ObsidianTemplateRenderer().render(result: extracted, template: .default)
            status = "Generated \(extracted.blocks.count) blocks."
        } catch {
            fail(error)
        }
        isLoading = false
    }

    private func fail(_ error: Error) {
        guard Task.isCancelled == false else { return }
        isLoading = false
        status = error.localizedDescription
    }
}

private struct ObsidianClipperResultList: View {
    let status: String
    let isLoading: Bool
    let result: WebPageDefuddleResult?
    let note: ObsidianNote?

    var body: some View {
        List {
            Section("Status") {
                Text(status)
                if isLoading {
                    ProgressView()
                }
            }

            if let result {
                Section("Page") {
                    InfoRow(label: "Title", value: result.title ?? "Untitled webpage")
                    InfoRow(label: "URL", value: result.url.absoluteString)
                    InfoRow(label: "Blocks", value: "\(result.blocks.count)")
                    InfoRow(label: "Words", value: "\(result.wordCount ?? 0)")
                    InfoRow(label: "Engine", value: result.diagnostics.engine)
                }

                Section("Extracted Blocks") {
                    ForEach(result.blocks) { block in
                        BlockRow(block: block)
                    }
                }
            }

            if let note {
                Section("Obsidian Note") {
                    InfoRow(label: "Name", value: note.noteName)
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(note.fullContent)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

private struct BlockRow: View {
    let block: WebPageBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(block.kind.rawValue)
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                if block.kind == .code {
                    Text(block.language ?? "code")
                        .font(.subheadline)
                    Text(block.text)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                } else if block.kind == .list {
                    ForEach(Array(block.items.enumerated()), id: \.offset) { index, item in
                        Text("\(index + 1). \(item)")
                    }
                } else {
                    Text(prefix(for: block) + block.text)
                        .font(font(for: block))
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func prefix(for block: WebPageBlock) -> String {
        block.kind == .quote ? "> " : ""
    }

    private func font(for block: WebPageBlock) -> Font {
        switch block.kind {
        case .heading:
            return .title3
        case .quote:
            return .body.italic()
        default:
            return .body
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.headline)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

#if os(macOS)
private struct ObsidianClipperPreviewWKWebView: NSViewRepresentable {
    @ObservedObject var model: ObsidianClipperPreviewWKWebViewModel

    func makeNSView(context: Context) -> WKWebView {
        model.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#elseif os(iOS)
private struct ObsidianClipperPreviewWKWebView: UIViewRepresentable {
    @ObservedObject var model: ObsidianClipperPreviewWKWebViewModel

    func makeUIView(context: Context) -> WKWebView {
        model.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif

@available(iOS 26.0, macOS 26.0, *)
private struct ObsidianClipperPreviewWebPageView: View {
    @ObservedObject var model: ObsidianClipperPreviewWebPageModel

    var body: some View {
        WebView(model.page)
    }
}

@available(iOS 26.0, macOS 26.0, *)
private extension WebPage.Configuration {
    static func obsidianClipperPreviewConfiguration() -> WebPage.Configuration {
        var configuration = WebPage.Configuration()
        var navigationPreferences = WebPage.NavigationPreferences()
        navigationPreferences.allowsContentJavaScript = true
        navigationPreferences.preferredHTTPSNavigationPolicy = .automaticFallbackToHTTP
        configuration.defaultNavigationPreferences = navigationPreferences
        configuration.loadsSubresources = true
        return configuration
    }
}

struct ObsidianClipperPreviewViewPreviews: PreviewProvider {
    static var previews: some View {
        ObsidianClipperPreviewView()
            .previewDisplayName("Obsidian Clipper")
    }
}
#endif
