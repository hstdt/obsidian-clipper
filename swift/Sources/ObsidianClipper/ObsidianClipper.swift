import Foundation

public struct ObsidianClipper: Sendable {
    public var noteRenderer: ObsidianTemplateRenderer

    public init(
        noteRenderer: ObsidianTemplateRenderer = ObsidianTemplateRenderer()
    ) {
        self.noteRenderer = noteRenderer
    }

    public func makeObsidianNote(
        from result: WebPageDefuddleResult,
        template: ObsidianClipTemplate = .default
    ) -> ObsidianNote {
        noteRenderer.render(result: result, template: template)
    }

    public func clip(
        _ result: WebPageDefuddleResult,
        template: ObsidianClipTemplate? = nil
    ) -> WebPageClip {
        let note = template.map { makeObsidianNote(from: result, template: $0) }
        return WebPageClip(defuddleResult: result, obsidianNote: note)
    }
}
