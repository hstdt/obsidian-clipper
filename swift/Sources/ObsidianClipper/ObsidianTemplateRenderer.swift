import Foundation

public struct ObsidianTemplateRenderer: Sendable {
    public init() {}

    public func render(
        result: WebPageDefuddleResult,
        template: ObsidianClipTemplate
    ) -> ObsidianNote {
        let variables = Self.variables(from: result)
        let noteName = Self.sanitizedFileName(applyVariables(template.noteNameFormat, variables: variables))
        let renderedProperties = template.properties.map { property in
            ObsidianProperty(
                id: property.id,
                name: property.name,
                value: applyVariables(property.value, variables: variables),
                type: property.type
            )
        }
        let frontmatter = Self.frontmatter(for: renderedProperties)
        let content = applyVariables(template.noteContentFormat, variables: variables)
        let fullContent = frontmatter.isEmpty ? content : frontmatter + content
        return ObsidianNote(
            noteName: noteName.isEmpty ? "Untitled" : noteName,
            frontmatter: frontmatter,
            content: content,
            fullContent: fullContent,
            properties: renderedProperties,
            templateID: template.id
        )
    }

    private func applyVariables(_ template: String, variables: [String: String]) -> String {
        variables.reduce(template) { partial, entry in
            partial.replacingOccurrences(of: "{{\(entry.key)}}", with: entry.value)
        }
    }

    private static func variables(from result: WebPageDefuddleResult) -> [String: String] {
        let domain = result.url.host ?? ""
        return [
            "author": result.author ?? "",
            "content": result.markdown,
            "contentHtml": result.contentHTML,
            "date": ISO8601DateFormatter().string(from: result.capturedAt),
            "description": result.description ?? "",
            "domain": domain,
            "image": result.imageURL?.absoluteString ?? "",
            "language": result.language ?? "",
            "noteName": sanitizedFileName(result.title ?? "Untitled"),
            "published": result.published ?? "",
            "site": result.site ?? "",
            "time": ISO8601DateFormatter().string(from: result.capturedAt),
            "title": result.title ?? "Untitled",
            "url": result.url.absoluteString,
            "words": "\(result.wordCount ?? 0)"
        ]
    }

    private static func frontmatter(for properties: [ObsidianProperty]) -> String {
        guard properties.contains(where: { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }) else {
            return ""
        }
        var output = "---\n"
        for property in properties {
            let key = yamlKey(property.name)
            let value = property.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.isEmpty == false else {
                output += "\(key):\n"
                continue
            }
            switch property.type {
            case "number":
                let numeric = value.replacingOccurrences(of: #"[^0-9.\-]"#, with: "", options: .regularExpression)
                output += "\(key): \(numeric.isEmpty ? "\"\(yamlEscaped(value))\"" : numeric)\n"
            case "checkbox":
                let boolValue = ["true", "1", "yes"].contains(value.lowercased()) ? "true" : "false"
                output += "\(key): \(boolValue)\n"
            case "date", "datetime":
                output += "\(key): \(value)\n"
            case "multitext":
                let items = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false }
                output += "\(key):\n"
                for item in items {
                    output += "  - \"\(yamlEscaped(item))\"\n"
                }
            default:
                output += "\(key): \"\(yamlEscaped(value))\"\n"
            }
        }
        output += "---\n"
        return output
    }

    private static func yamlKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let needsQuotes = trimmed.range(of: #"[:\s\{\}\[\],&*#?|<>=!%@\\-]"#, options: .regularExpression) != nil
            || trimmed.first?.isNumber == true
        return needsQuotes ? "\"\(yamlEscaped(trimmed))\"" : trimmed
    }

    private static func yamlEscaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func sanitizedFileName(_ value: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\?%*:|\"<>")
        let scalars = value.unicodeScalars.map { illegal.contains($0) ? "-" : String($0) }.joined()
        return scalars
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
