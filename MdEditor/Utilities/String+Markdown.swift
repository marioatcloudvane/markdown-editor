import Foundation

extension String {
    /// Returns true if the string looks like a URL.
    var isLikelyURL: Bool {
        return hasPrefix("http://") || hasPrefix("https://") || hasPrefix("ftp://")
    }

    /// Returns the string with the markdown file extension stripped if it is a known extension.
    var strippingMarkdownExtension: String {
        let ext = (self as NSString).pathExtension.lowercased()
        if SupportedExtensions.hideExtension.contains(ext) {
            return (self as NSString).deletingPathExtension
        }
        return self
    }
}
