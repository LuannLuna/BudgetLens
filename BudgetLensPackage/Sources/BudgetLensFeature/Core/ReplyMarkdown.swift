import Foundation

/// Styles inline Markdown (emphasis, code) in a model reply and removes links, so a reply can never add a tappable URL.
enum ReplyMarkdown {
    static func render(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        // Text the parser rejects is shown as received.
        guard var parsed = try? AttributedString(markdown: text, options: options) else {
            return AttributedString(text)
        }
        let linkRanges = parsed.runs.filter { $0.link != nil }.map(\.range)
        for range in linkRanges {
            parsed[range].link = nil
        }
        return parsed
    }
}
