import Foundation

/// Represents a node in the folder file tree.
/// Can be either a file or a directory with children.
class FolderNode: NSObject {
    /// Display name for the file or folder
    let name: String
    /// Full URL on disk
    let url: URL
    /// Whether this node represents a directory
    let isFolder: Bool
    /// Child nodes (empty for files)
    let children: [FolderNode]

    init(name: String, url: URL, isFolder: Bool, children: [FolderNode] = []) {
        self.name = name
        self.url = url
        self.isFolder = isFolder
        self.children = children
    }
}

/// Recursively scans a directory and builds a file tree model,
/// filtering for supported markdown file extensions and excluding
/// hidden and development-related directories.
enum FolderScanner {

    /// Scans a folder at the given URL and returns a tree of FolderNodes.
    /// - Parameter url: The root directory URL to scan.
    /// - Returns: A FolderNode representing the root directory with its children.
    static func scanFolder(at url: URL) -> FolderNode {
        let children = scanDirectory(at: url, depth: 0)
        return FolderNode(name: url.lastPathComponent, url: url, isFolder: true, children: children)
    }

    /// Counts the total number of files (not folders) in a tree.
    static func countFiles(in node: FolderNode) -> Int {
        if !node.isFolder {
            return 1
        }
        return node.children.reduce(0) { $0 + countFiles(in: $1) }
    }

    /// Collects all file URLs from the tree.
    static func allFileURLs(in node: FolderNode) -> [URL] {
        if !node.isFolder {
            return [node.url]
        }
        return node.children.flatMap { allFileURLs(in: $0) }
    }

    // MARK: - Private

    private static let maxDepth = 10

    private static func scanDirectory(at url: URL, depth: Int) -> [FolderNode] {
        guard depth < maxDepth else { return [] }

        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var folders: [FolderNode] = []
        var files: [FolderNode] = []

        for itemURL in contents {
            let name = itemURL.lastPathComponent

            // Skip hidden files/folders
            if name.hasPrefix(".") { continue }

            // Skip excluded directories
            if ExcludedDirectories.names.contains(name) { continue }

            // Check if it's a directory
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let isDirectory = resourceValues?.isDirectory ?? false
            let isSymlink = resourceValues?.isSymbolicLink ?? false

            // Skip symlinks to prevent loops
            if isSymlink { continue }

            if isDirectory {
                let children = scanDirectory(at: itemURL, depth: depth + 1)
                // Only include directories that contain markdown files (directly or nested)
                if !children.isEmpty {
                    folders.append(FolderNode(name: name, url: itemURL, isFolder: true, children: children))
                }
            } else {
                let ext = itemURL.pathExtension.lowercased()
                if SupportedExtensions.folderScan.contains(ext) {
                    let displayName: String
                    if SupportedExtensions.hideExtension.contains(ext) {
                        displayName = itemURL.deletingPathExtension().lastPathComponent
                    } else {
                        displayName = name
                    }
                    files.append(FolderNode(name: displayName, url: itemURL, isFolder: false))
                }
            }
        }

        // Sort: folders first (alphabetically), then files (alphabetically)
        folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return folders + files
    }
}
