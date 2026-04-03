import Foundation

/// Bundled Markdown Syntax Guide content.
/// Opened as a new document in preview mode from the Help menu.
enum MarkdownSyntaxGuide {
    static let content = """
    # Markdown Syntax Guide

    This guide covers the Markdown syntax supported by MdEditor.

    ---

    ## Headings

    Use `#` symbols at the start of a line to create headings:

    ```
    # Heading 1
    ## Heading 2
    ### Heading 3
    #### Heading 4
    ##### Heading 5
    ###### Heading 6
    ```

    ---

    ## Emphasis

    - **Bold**: Wrap text with `**double asterisks**` -- **bold text**
    - *Italic*: Wrap text with `*single asterisks*` -- *italic text*
    - ~~Strikethrough~~: Wrap text with `~~double tildes~~` -- ~~strikethrough~~
    - ***Bold and Italic***: Wrap text with `***triple asterisks***`

    ---

    ## Links

    ```
    [Link Text](https://example.com)
    ```

    Result: [Example Link](https://example.com)

    ---

    ## Images

    ```
    ![Alt Text](image-url.png)
    ```

    ---

    ## Lists

    ### Unordered Lists

    ```
    - Item 1
    - Item 2
      - Nested item
    - Item 3
    ```

    ### Ordered Lists

    ```
    1. First item
    2. Second item
    3. Third item
    ```

    ### Task Lists

    ```
    - [ ] Unchecked task
    - [x] Completed task
    - [ ] Another task
    ```

    ---

    ## Code

    ### Inline Code

    Use backticks for `inline code`.

    ### Code Blocks

    Use triple backticks for code blocks:

    ```swift
    func greet(name: String) -> String {
        return "Hello, \\(name)!"
    }
    ```

    ---

    ## Blockquotes

    ```
    > This is a blockquote.
    > It can span multiple lines.
    ```

    > This is a blockquote.
    > It can span multiple lines.

    ---

    ## Tables

    ```
    | Column 1 | Column 2 | Column 3 |
    |----------|----------|----------|
    | Cell 1   | Cell 2   | Cell 3   |
    | Cell 4   | Cell 5   | Cell 6   |
    ```

    | Column 1 | Column 2 | Column 3 |
    |----------|----------|----------|
    | Cell 1   | Cell 2   | Cell 3   |
    | Cell 4   | Cell 5   | Cell 6   |

    ---

    ## Horizontal Rules

    Use three or more hyphens, asterisks, or underscores:

    ```
    ---
    ```

    ---

    ## Keyboard Shortcuts

    | Action | Shortcut |
    |--------|----------|
    | Bold | Cmd+B |
    | Italic | Cmd+I |
    | Link | Cmd+K |
    | Inline Code | Cmd+` |
    | Heading 1-6 | Cmd+1 through Cmd+6 |
    | Bullet List | Cmd+Shift+8 |
    | Numbered List | Cmd+Shift+7 |
    | Task List | Cmd+Shift+9 |
    | Blockquote | Cmd+Shift+. |
    | Code Block | Cmd+Shift+C |
    | Strikethrough | Cmd+Shift+X |
    | Insert Image | Cmd+Shift+I |
    | Insert Table | Cmd+Option+T |
    | Horizontal Rule | Cmd+Shift+- |
    | Edit Mode | Cmd+Shift+E |
    | Preview Mode | Cmd+Shift+P |
    | Toggle Sidebar | Cmd+\\\\ |
    | Find | Cmd+F |
    | Find and Replace | Cmd+Option+F |
    | Increase Font | Cmd+= |
    | Decrease Font | Cmd+- |
    | Reset Font | Cmd+0 |

    ---

    *MdEditor -- A native macOS Markdown editor.*
    """
}
