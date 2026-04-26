import XCTest
@testable import ObsidianClipper

final class ObsidianNoteRendererTests: XCTestCase {
    func testRendersObsidianNoteFromTemplate() throws {
        let result = WebPageDefuddleResult(
            url: try XCTUnwrap(URL(string: "https://example.com/post")),
            title: "A / Post",
            author: "Author",
            description: "Description",
            site: "Example",
            published: "2026-04-26",
            contentHTML: "<p>Hello</p>",
            markdown: "Hello",
            wordCount: 1,
            metaTags: [],
            blocks: [.paragraph(id: "block-1", text: "Hello")],
            capturedAt: Date(timeIntervalSince1970: 1_800_000_000),
            diagnostics: WebPageClipDiagnostics(
                engine: "test",
                inputHTMLCharacters: 12,
                contentHTMLCharacters: 12,
                markdownCharacters: 5,
                blockCount: 1
            )
        )
        let template = ObsidianClipTemplate(
            id: "article",
            name: "Article",
            noteNameFormat: "{{title}}",
            noteContentFormat: "Source: {{url}}\n\n{{content}}",
            properties: [
                ObsidianProperty(name: "source", value: "{{url}}", type: "text"),
                ObsidianProperty(name: "published", value: "{{published}}", type: "date"),
                ObsidianProperty(name: "words", value: "{{words}}", type: "number")
            ]
        )

        let note = ObsidianTemplateRenderer().render(result: result, template: template)

        XCTAssertEqual(note.noteName, "A - Post")
        XCTAssertTrue(note.frontmatter.contains("source: \"https://example.com/post\""))
        XCTAssertTrue(note.frontmatter.contains("published: 2026-04-26"))
        XCTAssertTrue(note.frontmatter.contains("words: 1"))
        XCTAssertEqual(note.content, "Source: https://example.com/post\n\nHello")
        XCTAssertTrue(note.fullContent.hasPrefix("---\n"))
        XCTAssertEqual(note.templateID, "article")
    }

    func testClipCanAttachRenderedNoteToExistingDefuddleResult() throws {
        let result = WebPageDefuddleResult(
            url: try XCTUnwrap(URL(string: "https://example.com")),
            title: "Hello",
            contentHTML: "<p>Body</p>",
            markdown: "Body",
            wordCount: 1,
            blocks: [.paragraph(id: "block-1", text: "Body")],
            diagnostics: WebPageClipDiagnostics(
                engine: "defuddle-wkwebview",
                inputHTMLCharacters: 128,
                contentHTMLCharacters: 11,
                markdownCharacters: 4,
                blockCount: 1
            )
        )

        let clip = ObsidianClipper().clip(result, template: .default)

        XCTAssertEqual(clip.defuddleResult.markdown, "Body")
        XCTAssertEqual(clip.obsidianNote?.noteName, "Hello")
        XCTAssertTrue(clip.obsidianNote?.fullContent.contains("Body") == true)
    }
}
