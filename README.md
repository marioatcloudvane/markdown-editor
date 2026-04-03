# Markdown Editor

A native macOS markdown editor with a clean WYSIWYG editing experience.

## Features

- **WYSIWYG editing** — write in a live rendered view; see headings, bold, lists and links as you type, not as syntax
- **Markdown source view** — switch to raw markdown at any time to copy, inspect or paste syntax
- **Native document tabs** — open multiple files in one window, just like Safari or Finder
- **Full formatting toolbar** — bold, italic, strikethrough, headings (H1–H6), bullet list, numbered list, inline code, code block, blockquote, link, and export — all one click away
- **Save & auto-save** — standard macOS save behaviour with unsaved-change indicator (blue dot on tab)
- **Export** — export any document as HTML or PDF
- **Preferences** — choose editor font, font size, tab width, line numbers, word wrap, and spell check
- **Markdown Syntax Guide** — built-in reference guide, opens as a document inside the editor
- **Full menu bar** — complete File / Edit / Format / View / Window / Help menus with keyboard shortcuts
- **macOS native** — built with AppKit, supports Dark Mode, full-screen, and system font rendering

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac

## Installation

1. Download `Markdown Editor.zip` from the [Releases](../../releases) page
2. Unzip and drag **Markdown Editor.app** to your `/Applications` folder
3. Right-click → Open on first launch (app is not notarised)

## Building from Source

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/marioatcloudvane/markdown-editor.git
cd markdown-editor
xcodegen generate
xcodebuild -project MdEditor.xcodeproj -scheme MdEditor -configuration Release -derivedDataPath build build
open build/Build/Products/Release/MdEditor.app
```

## Keyboard Shortcuts

| Action | Shortcut |
|---|---|
| New document | ⌘N |
| New tab | ⌘T |
| Open file | ⌘O |
| Save | ⌘S |
| Save As | ⌘⇧S |
| Bold | ⌘B |
| Italic | ⌘I |
| Strikethrough | ⌘⇧X |
| Inline code | ⌘\` |
| Heading 1–6 | ⌘1 – ⌘6 |
| Bullet list | ⌘⇧8 |
| Numbered list | ⌘⇧7 |
| Insert link | ⌘K |
| WYSIWYG mode | ⌘⇧E |
| Markdown source | ⌘⇧M |
