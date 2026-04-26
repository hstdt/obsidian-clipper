import Foundation

enum ObsidianClipperJSON {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO 8601 date: \(value)"
            )
        }
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decodeDefuddleResult(from json: String) throws -> WebPageDefuddleResult {
        let data = Data(json.utf8)
        return try decoder().decode(WebPageDefuddleResult.self, from: data)
    }

    static func decodeSnapshot(from json: String) throws -> WebPageSnapshot {
        let data = Data(json.utf8)
        return try decoder().decode(WebPageSnapshot.self, from: data)
    }

    private static func date(from value: String) -> Date? {
        iso8601DateFormatter(options: [.withInternetDateTime, .withFractionalSeconds]).date(from: value)
            ?? iso8601DateFormatter(options: [.withInternetDateTime]).date(from: value)
    }

    private static func iso8601DateFormatter(options: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        return formatter
    }
}
