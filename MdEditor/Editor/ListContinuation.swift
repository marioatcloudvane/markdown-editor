import Foundation

/// Handles auto-continuation of markdown lists when the user presses Enter.
/// Supports bullet lists (-, *), numbered lists (1., 2.), and task lists (- [ ], - [x]).
enum ListContinuation {

    /// The result of analyzing a line for list continuation.
    enum Result {
        /// Continue the list with the given prefix on the next line.
        case continueList(prefix: String)
        /// Exit list mode by removing the prefix at the given range within the line.
        case exitList(prefixRange: NSRange)
    }

    /// Analyzes the current line and cursor position to determine list continuation behavior.
    /// - Parameters:
    ///   - lineText: The text of the current line (including any trailing newline).
    ///   - cursorOffset: The cursor position relative to the start of the line.
    /// - Returns: A continuation result, or nil if the line is not a list item.
    static func continuation(for lineText: String, cursorOffset: Int) -> Result? {
        let trimmedLine = lineText.trimmingCharacters(in: .newlines)
        let nsLine = trimmedLine as NSString

        // Task list: - [ ] or - [x]
        if let match = trimmedLine.range(of: #"^(\s*- \[[ x]\] )"#, options: .regularExpression) {
            let prefixStr = String(trimmedLine[match])
            let contentAfterPrefix = String(trimmedLine[match.upperBound...]).trimmingCharacters(in: .whitespaces)

            if contentAfterPrefix.isEmpty {
                // Empty list item: exit list mode
                let prefixRange = NSRange(location: 0, length: nsLine.length)
                return .exitList(prefixRange: prefixRange)
            }

            // Extract leading whitespace
            let leadingWhitespace = String(prefixStr.prefix(while: { $0 == " " || $0 == "\t" }))
            return .continueList(prefix: "\(leadingWhitespace)- [ ] ")
        }

        // Bullet list: - or *
        if let match = trimmedLine.range(of: #"^(\s*[-*] )"#, options: .regularExpression) {
            let prefixStr = String(trimmedLine[match])
            let contentAfterPrefix = String(trimmedLine[match.upperBound...]).trimmingCharacters(in: .whitespaces)

            if contentAfterPrefix.isEmpty {
                let prefixRange = NSRange(location: 0, length: nsLine.length)
                return .exitList(prefixRange: prefixRange)
            }

            return .continueList(prefix: prefixStr)
        }

        // Numbered list: 1. 2. etc.
        if let match = trimmedLine.range(of: #"^(\s*)(\d+)\.\s"#, options: .regularExpression) {
            let fullPrefix = String(trimmedLine[match])
            let contentAfterPrefix = String(trimmedLine[match.upperBound...]).trimmingCharacters(in: .whitespaces)

            if contentAfterPrefix.isEmpty {
                let prefixRange = NSRange(location: 0, length: nsLine.length)
                return .exitList(prefixRange: prefixRange)
            }

            // Extract the number and increment
            if let numberMatch = trimmedLine.range(of: #"(\d+)"#, options: .regularExpression) {
                let numberStr = String(trimmedLine[numberMatch])
                if let number = Int(numberStr) {
                    let leadingWhitespace = String(fullPrefix.prefix(while: { $0 == " " || $0 == "\t" }))
                    return .continueList(prefix: "\(leadingWhitespace)\(number + 1). ")
                }
            }
        }

        return nil
    }
}
