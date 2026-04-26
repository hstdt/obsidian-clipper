import Foundation

public enum ObsidianSaveBehavior: String, Codable, Sendable {
    case create
    case appendSpecific = "append-specific"
    case appendDaily = "append-daily"
    case prependSpecific = "prepend-specific"
    case prependDaily = "prepend-daily"
    case overwrite
}

public struct ObsidianProperty: Codable, Equatable, Sendable, Identifiable {
    public var id: String?
    public var name: String
    public var value: String
    public var type: String?

    public init(id: String? = nil, name: String, value: String, type: String? = nil) {
        self.id = id
        self.name = name
        self.value = value
        self.type = type
    }
}

public struct ObsidianClipTemplate: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var behavior: ObsidianSaveBehavior
    public var noteNameFormat: String
    public var path: String
    public var noteContentFormat: String
    public var properties: [ObsidianProperty]
    public var triggers: [String]
    public var vault: String?
    public var context: String?

    public init(
        id: String,
        name: String,
        behavior: ObsidianSaveBehavior = .create,
        noteNameFormat: String = "{{title}}",
        path: String = "",
        noteContentFormat: String = "{{content}}",
        properties: [ObsidianProperty] = [],
        triggers: [String] = [],
        vault: String? = nil,
        context: String? = nil
    ) {
        self.id = id
        self.name = name
        self.behavior = behavior
        self.noteNameFormat = noteNameFormat
        self.path = path
        self.noteContentFormat = noteContentFormat
        self.properties = properties
        self.triggers = triggers
        self.vault = vault
        self.context = context
    }

    public static let `default` = ObsidianClipTemplate(
        id: "default",
        name: "Default",
        noteNameFormat: "{{title}}",
        noteContentFormat: "{{content}}",
        properties: [
            ObsidianProperty(name: "source", value: "{{url}}", type: "text"),
            ObsidianProperty(name: "author", value: "{{author}}", type: "text"),
            ObsidianProperty(name: "published", value: "{{published}}", type: "date")
        ]
    )
}

public struct ObsidianNote: Codable, Equatable, Sendable {
    public var noteName: String
    public var frontmatter: String
    public var content: String
    public var fullContent: String
    public var properties: [ObsidianProperty]
    public var templateID: String?

    public init(
        noteName: String,
        frontmatter: String,
        content: String,
        fullContent: String,
        properties: [ObsidianProperty],
        templateID: String? = nil
    ) {
        self.noteName = noteName
        self.frontmatter = frontmatter
        self.content = content
        self.fullContent = fullContent
        self.properties = properties
        self.templateID = templateID
    }
}
