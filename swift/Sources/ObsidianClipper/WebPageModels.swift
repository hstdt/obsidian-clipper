import Foundation

public enum WebPageSnapshotSource: String, Codable, Sendable {
    case wkWebView
    case webPage
    case providedHTML
}

public struct WebPageSnapshot: Codable, Equatable, Sendable {
    public var url: URL
    public var baseURL: URL?
    public var title: String?
    public var html: String
    public var selectedHTML: String?
    public var capturedAt: Date
    public var source: WebPageSnapshotSource

    public init(
        url: URL,
        baseURL: URL? = nil,
        title: String? = nil,
        html: String,
        selectedHTML: String? = nil,
        capturedAt: Date = Date(),
        source: WebPageSnapshotSource = .providedHTML
    ) {
        self.url = url
        self.baseURL = baseURL
        self.title = title
        self.html = html
        self.selectedHTML = selectedHTML
        self.capturedAt = capturedAt
        self.source = source
    }
}

public struct WebPageMetaTag: Codable, Equatable, Sendable {
    public var name: String?
    public var property: String?
    public var content: String?

    public init(name: String? = nil, property: String? = nil, content: String? = nil) {
        self.name = name
        self.property = property
        self.content = content
    }
}

public enum WebPageBlockKind: String, Codable, Sendable {
    case heading
    case paragraph
    case list
    case quote
    case code
    case image
    case table
}

public struct WebPageBlock: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: WebPageBlockKind
    public var level: Int?
    public var text: String
    public var html: String?
    public var items: [String]
    public var ordered: Bool?
    public var language: String?
    public var url: URL?
    public var alt: String?
    public var markdown: String?
    public var sourceHint: String?

    public init(
        id: String,
        kind: WebPageBlockKind,
        level: Int? = nil,
        text: String,
        html: String? = nil,
        items: [String] = [],
        ordered: Bool? = nil,
        language: String? = nil,
        url: URL? = nil,
        alt: String? = nil,
        markdown: String? = nil,
        sourceHint: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.level = level
        self.text = text
        self.html = html
        self.items = items
        self.ordered = ordered
        self.language = language
        self.url = url
        self.alt = alt
        self.markdown = markdown
        self.sourceHint = sourceHint
    }

    public static func heading(id: String, level: Int, text: String, html: String? = nil) -> WebPageBlock {
        WebPageBlock(id: id, kind: .heading, level: level, text: text, html: html)
    }

    public static func paragraph(id: String, text: String, html: String? = nil) -> WebPageBlock {
        WebPageBlock(id: id, kind: .paragraph, text: text, html: html)
    }

    public static func code(id: String, text: String, language: String? = nil, html: String? = nil) -> WebPageBlock {
        WebPageBlock(id: id, kind: .code, text: text, html: html, language: language)
    }

    public static func list(id: String, items: [String], ordered: Bool = false, html: String? = nil) -> WebPageBlock {
        WebPageBlock(
            id: id,
            kind: .list,
            text: items.joined(separator: "\n"),
            html: html,
            items: items,
            ordered: ordered
        )
    }

    public static func quote(id: String, text: String, html: String? = nil) -> WebPageBlock {
        WebPageBlock(id: id, kind: .quote, text: text, html: html)
    }
}

public struct WebPageClipDiagnostics: Codable, Equatable, Sendable {
    public var engine: String
    public var inputHTMLCharacters: Int
    public var contentHTMLCharacters: Int
    public var markdownCharacters: Int
    public var blockCount: Int
    public var truncated: Bool
    public var warnings: [String]

    public init(
        engine: String,
        inputHTMLCharacters: Int,
        contentHTMLCharacters: Int,
        markdownCharacters: Int,
        blockCount: Int,
        truncated: Bool = false,
        warnings: [String] = []
    ) {
        self.engine = engine
        self.inputHTMLCharacters = inputHTMLCharacters
        self.contentHTMLCharacters = contentHTMLCharacters
        self.markdownCharacters = markdownCharacters
        self.blockCount = blockCount
        self.truncated = truncated
        self.warnings = warnings
    }
}

public struct WebPageDefuddleResult: Codable, Equatable, Sendable {
    public var url: URL
    public var baseURL: URL?
    public var title: String?
    public var author: String?
    public var description: String?
    public var site: String?
    public var published: String?
    public var language: String?
    public var contentHTML: String
    public var markdown: String
    public var fullHTML: String?
    public var selectedHTML: String?
    public var wordCount: Int?
    public var imageURL: URL?
    public var faviconURL: URL?
    public var schemaOrgJSON: String?
    public var metaTags: [WebPageMetaTag]
    public var blocks: [WebPageBlock]
    public var capturedAt: Date
    public var diagnostics: WebPageClipDiagnostics

    public init(
        url: URL,
        baseURL: URL? = nil,
        title: String? = nil,
        author: String? = nil,
        description: String? = nil,
        site: String? = nil,
        published: String? = nil,
        language: String? = nil,
        contentHTML: String,
        markdown: String,
        fullHTML: String? = nil,
        selectedHTML: String? = nil,
        wordCount: Int? = nil,
        imageURL: URL? = nil,
        faviconURL: URL? = nil,
        schemaOrgJSON: String? = nil,
        metaTags: [WebPageMetaTag] = [],
        blocks: [WebPageBlock],
        capturedAt: Date = Date(),
        diagnostics: WebPageClipDiagnostics
    ) {
        self.url = url
        self.baseURL = baseURL
        self.title = title
        self.author = author
        self.description = description
        self.site = site
        self.published = published
        self.language = language
        self.contentHTML = contentHTML
        self.markdown = markdown
        self.fullHTML = fullHTML
        self.selectedHTML = selectedHTML
        self.wordCount = wordCount
        self.imageURL = imageURL
        self.faviconURL = faviconURL
        self.schemaOrgJSON = schemaOrgJSON
        self.metaTags = metaTags
        self.blocks = blocks
        self.capturedAt = capturedAt
        self.diagnostics = diagnostics
    }
}

public struct WebPageClipperConfiguration: Codable, Equatable, Sendable {
    public var includeFullHTML: Bool
    public var includeSelection: Bool
    public var maxBlockCount: Int

    public init(
        includeFullHTML: Bool = false,
        includeSelection: Bool = true,
        maxBlockCount: Int = 400
    ) {
        self.includeFullHTML = includeFullHTML
        self.includeSelection = includeSelection
        self.maxBlockCount = max(1, maxBlockCount)
    }
}

public struct WebPageClip: Codable, Equatable, Sendable {
    public var defuddleResult: WebPageDefuddleResult
    public var obsidianNote: ObsidianNote?

    public init(defuddleResult: WebPageDefuddleResult, obsidianNote: ObsidianNote? = nil) {
        self.defuddleResult = defuddleResult
        self.obsidianNote = obsidianNote
    }
}
