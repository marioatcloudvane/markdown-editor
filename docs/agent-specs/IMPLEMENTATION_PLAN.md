# Implementation Plan
# Feature: MdEditor -- macOS Native Markdown Editor
# Source: FEATURE_SPEC.md
# Design Direction: DESIGN_DIRECTION.md
# Created: 2026-04-01
# Status: DRAFT
# Architect: Swift App Architect
# Enriched: 2026-04-01

---

## System Overview

### How This Feature Fits Into the Existing App

This is a greenfield application. There is no existing codebase. The entire app is being built from scratch as a macOS Document-Based Application. The architecture centers on Apple's `NSDocument` infrastructure, which provides the app's lifecycle, file I/O, tab management, window restoration, auto-save, and dirty-state tracking for free. The app uses SwiftUI as the outer shell for declarative UI composition, with AppKit components (`NSTextView`, `WKWebView`, `NSToolbar`, `NSSplitViewController`, `NSOutlineView`) bridged in via `NSViewRepresentable` / `NSViewControllerRepresentable` where SwiftUI lacks the required control or performance characteristics.

The critical architectural decision: this is an `NSDocument`-based app, NOT a SwiftUI `DocumentGroup`-based app. `DocumentGroup` in SwiftUI does not provide the level of control needed for native `NSWindow` document tabs, `NSToolbar` integration, `NSSplitViewController` for the sidebar, or the fine-grained `NSTextView` configuration this app requires. The `NSDocument` / `NSWindowController` / `NSViewController` spine is AppKit. SwiftUI views are hosted within this AppKit skeleton using `NSHostingView` or `NSHostingController` where appropriate (status bar, preferences window, sidebar tree if using SwiftUI List).

### Module and File Structure

```
MdEditor/
├── App/
│   ├── AppDelegate.swift                  # NSApplicationDelegate, app lifecycle
│   ├── DocumentController.swift           # NSDocumentController subclass, untitled numbering, open-folder logic
│   └── Info.plist                          # Document type registrations, file associations
├── Document/
│   ├── MarkdownDocument.swift             # NSDocument subclass, file I/O, content model, auto-save
│   └── ViewMode.swift                     # .editing / .preview enum
├── WindowChrome/
│   ├── MainWindowController.swift         # NSWindowController, toolbar setup, unified titlebar
│   ├── MainSplitViewController.swift      # NSSplitViewController (sidebar + content)
│   ├── ToolbarManager.swift               # NSToolbar delegate, button creation, state management
│   └── ContentViewController.swift        # Container VC that swaps between editor and preview
├── Editor/
│   ├── EditorViewController.swift         # Hosts the NSTextView, manages layout, cursor tracking
│   ├── MarkdownTextView.swift             # NSTextView subclass (if needed for custom behavior)
│   ├── MarkdownTextStorage.swift          # NSTextStorage subclass for syntax highlighting
│   ├── MarkdownLayoutManager.swift        # Custom NSLayoutManager (if needed for line highlight)
│   ├── LineNumberGutter.swift             # NSRulerView subclass for line numbers
│   ├── FormattingCommands.swift           # Formatting action logic (bold, italic, heading, etc.)
│   └── ListContinuation.swift             # Auto-continue list logic
├── Preview/
│   ├── PreviewViewController.swift        # Hosts the WKWebView
│   ├── MarkdownRenderer.swift             # Markdown-to-HTML pipeline (wraps swift-markdown or cmark)
│   ├── preview.css                        # Bundled CSS for preview styling
│   ├── preview-dark.css                   # Dark mode overrides (or use @media in single file)
│   └── highlight.js                       # Bundled minimal syntax highlighter for code blocks
├── Sidebar/
│   ├── SidebarViewController.swift        # NSViewController hosting the outline view
│   ├── FileTreeDataSource.swift           # NSOutlineViewDataSource/Delegate, tree model
│   └── FolderScanner.swift                # Recursive directory scanning, filtering
├── StatusBar/
│   ├── StatusBarView.swift                # SwiftUI view for the status bar (hosted via NSHostingView)
│   └── DocumentMetrics.swift              # Word count, character count, cursor position computation
├── Preferences/
│   ├── PreferencesWindowController.swift  # NSWindowController for preferences (or SwiftUI Settings scene)
│   ├── EditorPreferencesView.swift        # SwiftUI view for Editor tab
│   ├── PreviewPreferencesView.swift       # SwiftUI view for Preview tab
│   ├── GeneralPreferencesView.swift       # SwiftUI view for General tab
│   └── AppPreferences.swift              # @Observable class wrapping UserDefaults, single source of truth
├── Export/
│   ├── HTMLExporter.swift                 # Generates standalone HTML with inlined CSS
│   └── PDFExporter.swift                  # Uses WKWebView.createPDF for PDF generation
├── Menus/
│   └── MenuBuilder.swift                  # Main menu bar construction (or MainMenu.xib)
├── Resources/
│   ├── MarkdownSyntaxGuide.md             # Bundled reference document
│   └── Assets.xcassets                    # App icon, SF Symbol customizations
└── Utilities/
    ├── Constants.swift                    # Layout constants, default values
    ├── String+Markdown.swift              # String extensions for markdown detection
    └── NSTextView+Formatting.swift        # Extensions for text manipulation
```

### Navigation Impact

This app does not use SwiftUI navigation (NavigationStack, NavigationSplitView). Navigation is implicit in the document-based model:

- **Document tabs** are native `NSWindow` document tabs managed by AppKit. Each `MarkdownDocument` gets an `NSWindowController`. The system handles tab bar rendering, drag-to-reorder, drag-to-new-window, and merge-all-windows.
- **Sidebar** is one pane of an `NSSplitViewController`. It appears/disappears based on whether a folder is open. The sidebar toggle animates the split view divider.
- **Edit/Preview toggle** swaps child views within the `ContentViewController` using a cross-dissolve transition. There is no navigation push/pop -- both views occupy the same spatial position.
- **Preferences window** is a separate `NSWindow` presented modally or as a standard preferences panel.
- **Popovers** (link insertion, image insertion, overflow formatting) are `NSPopover` instances anchored to toolbar buttons.

### Data Flow

```
UserDefaults (AppPreferences)
       |
       v
MarkdownDocument (NSDocument)  <---->  File System (UTF-8 .md files)
   |          |
   |     [content: String]
   |          |
   v          v
EditorVC    PreviewVC
(NSTextView)  (WKWebView)
   |              |
   |    MarkdownRenderer (swift-markdown -> HTML)
   |              |
   v              v
ToolbarManager  StatusBarView
(button state)  (metrics)
```

- **Source of truth for document content:** `MarkdownDocument.content` (a `String`). The `NSTextView`'s text storage is the live editing buffer. On every text change, the document's content is updated, which triggers the `NSDocument` dirty state and auto-save cycle.
- **Source of truth for preferences:** `AppPreferences`, an `@Observable` class backed by `UserDefaults`. Injected into SwiftUI views via `.environment()`. Read by AppKit view controllers via direct reference (singleton or passed during setup).
- **Source of truth for view mode:** `MarkdownDocument.viewMode` (per-document). The `ContentViewController` observes this and swaps between editor and preview.
- **Refresh strategy:** The editor view is live -- text changes are immediate. The preview is rendered on-demand when transitioning to preview mode (not continuously). Preferences changes are observed and applied immediately to all open editors/previews via KVO or Combine/observation on the `AppPreferences` object.

### Shared State and Side Effects

- **Untitled document counter:** Managed by the `DocumentController` (NSDocumentController subclass). This is session-level state. It increments monotonically and never recycles.
- **Recent files:** Managed by `NSDocumentController` automatically (it maintains the Open Recent menu).
- **Sidebar folder state:** Managed by the `MainSplitViewController`. When a folder is opened, the tree model is built and the sidebar pane is revealed. This is per-window state.
- **No cross-window sync:** Each window is independent. If the same file is open in two windows, changes do not sync between them (explicitly out of scope for v1).
- **No background tasks, widgets, or notifications.** This app has no side effects beyond the file system.

### Key Architectural Decisions

1. **NSDocument is the spine.** Every architectural decision flows from this. NSDocument gives us auto-save, dirty tracking, file I/O, the save/revert lifecycle, state restoration, and native tab support. Do not fight it or work around it.

2. **AppKit skeleton, SwiftUI leaves.** The window controller, split view controller, content view controller, editor view controller, and toolbar are all AppKit. SwiftUI is used for the status bar, preferences window, and potentially the sidebar file tree (if using SwiftUI List with disclosure groups instead of NSOutlineView). This is not a philosophical choice -- it is a pragmatic one. The app's core features (NSTextView, NSToolbar, NSSplitViewController, NSWindow document tabs) are AppKit APIs with no SwiftUI equivalent of sufficient quality.

3. **Markdown parsing library.** Use Apple's `swift-markdown` (swift package: `apple/swift-markdown`). It parses CommonMark and can be extended for GFM tables, strikethrough, and task lists. The parser is used in two places: (a) the syntax highlighter in the editor (applied to NSTextStorage), and (b) the markdown-to-HTML renderer for preview/export. The AST walk for syntax highlighting must be incremental or range-limited for performance.

4. **No Combine.** Use Swift concurrency (async/await) where needed, and direct observation (`@Observable`, KVO, `NSTextStorage` delegate) for reactive updates. The text editing pipeline is synchronous and on the main thread -- do not introduce unnecessary async boundaries in the typing path.

5. **All UI on @MainActor.** Every view controller, every view model, every UI-touching class is `@MainActor`. The only off-main-thread work is folder scanning (T-007.2) and potentially large-file loading.

---

## Roster Assumption

No `AGENT_ROSTER.md` was found in the project root. Based on the user's guidance, this plan assigns all tasks to **principal-frontend-engineer**, the Swift/SwiftUI/AppKit specialist responsible for building the native macOS application. If additional agents become available (e.g., a test-engineer, a designer for CSS/HTML assets), tasks can be reassigned. Any task that falls outside the principal-frontend-engineer's scope is flagged as UNASSIGNED.

---

## Design Direction Deviations from Feature Spec

The DESIGN_DIRECTION.md and FEATURE_SPEC.md diverge on several points. Where they conflict, the Design Direction takes precedence per stakeholder instruction. The following deviations are called out so the engineer is aware:

1. **No welcome screen.** The spec (section 4.7) describes a welcome view with app icon, action buttons, and recent files when no tabs are open. The Design Direction (Principle 4) explicitly rejects this: "Never show a Welcome screen." Instead, when no previous state exists, open a new blank untitled document immediately. When the last tab is closed, open a new blank document. The engineer should follow the Design Direction.

2. **Toolbar: 6 buttons + overflow, not 15+ buttons.** The spec (section 4.3) lists ~18 toolbar buttons across groups. The Design Direction (section 3) mandates a maximum of 6 formatting buttons in the center cluster (Bold, Italic, Link, Code, List, Heading) with an overflow `...` button for less common formatting (blockquote, table, horizontal rule, image, strikethrough). The engineer should follow the Design Direction for toolbar layout, while implementing all formatting actions from the spec -- the remaining ones live in the overflow popover and the Format menu.

3. **Sidebar file tree for Open Folder.** The spec (section 12, item 14) says "No file tree / project sidebar." The Design Direction (section 7) describes a full sidebar with `NSSplitViewController`, file tree, and collapsible folders. The Design Direction wins: implement the sidebar. Open Folder populates the sidebar tree rather than opening every file as a flat tab. Single-clicking a file in the sidebar opens it in a tab.

4. **Auto-save via NSDocument.** The spec (decision 9) says auto-save is off by default and configurable. The Design Direction (Principle 3) says "Save Is Not an Event" and mandates continuous auto-save via the native `NSDocument` model. The engineer should implement NSDocument-based auto-save as default behavior. Cmd+S remains supported for immediate save.

5. **Export HTML/PDF included.** The Design Direction ("What We Are NOT Doing") suggests deferring export to v2. However, the FEATURE_SPEC explicitly lists Export as HTML and Export as PDF with detailed behavior (sections 6.7, 6.8). This plan includes export as a later-stage story since it is in the approved spec, but it is the lowest priority and can be cut if timeline requires.

6. **Tab bar: native NSWindow document tabs.** The spec describes a custom tab bar with context menus. The Design Direction (section 6) mandates native `NSWindow.tabbingMode` document tabs. The engineer should use native tabs, which provide reorder, drag-to-new-window, and merge-all-windows for free. Context menu items from the spec (Close Other Tabs, Reveal in Finder, Copy File Path) should be added via `NSWindow` delegate or menu customization where possible.

---

## User Stories

### US-001: App Shell and Window Chrome

**As a** writer, **I want** the app to launch into a ready-to-use window with native macOS chrome, **so that** I can start writing immediately without setup or configuration.

**Architectural Guidance:**

This story builds the foundational AppKit skeleton that every other story depends on. The engineer must set up the `NSDocument` / `NSDocumentController` / `NSWindowController` triad correctly here -- mistakes in this foundation will cascade through the entire app. The project template should be "Document-Based App" in Xcode, but the engineer will need to heavily customize the default template.

- **Framework:** Pure AppKit. No SwiftUI in this story. The app delegate, document controller, document subclass, and window controller are all AppKit classes.
- **Pattern:** Standard macOS Document Architecture. `NSDocumentController` (subclassed as `DocumentController`) manages the document lifecycle. `MarkdownDocument` (NSDocument subclass) is the model. `MainWindowController` (NSWindowController subclass) owns the window and its toolbar.
- **Key contract:** `MarkdownDocument` stores `var content: String` as the raw markdown. It implements `data(ofType:)` returning `content.data(using: .utf8)!` and `read(from:ofType:)` setting `content` from the file data. It sets `autosavesInPlace` to return `true`. This is the single source of truth for document content.
- **Tab support:** Setting `NSWindow.tabbingMode = .preferred` on the window is necessary but not sufficient. The `NSWindowController` must also ensure `shouldCascadeWindows = false` and that `NSWindow.setFrameAutosaveName` is set, or tabs will not merge correctly. Test that Cmd+N creates a new tab in the existing window (not a new window) when the "New window behavior" preference is "New Tab".
- **State restoration:** `NSWindow.setFrameAutosaveName("MainWindow")` handles window frame. Document restoration is handled by `NSDocument`'s built-in state restoration (enabled by default on macOS). Verify by quitting the app with documents open and relaunching.
- **Integration points:** Every subsequent story depends on US-001. The `MarkdownDocument` class will grow properties (viewMode in US-004, cursor position in US-006) but its core shape is defined here. The `MainWindowController` will gain a toolbar (US-003) and a split view (US-007) but its window configuration is done here.

**Acceptance Criteria:**
- [ ] The app launches and displays a single window with unified titlebar/toolbar style (`NSWindow.StyleMask.unifiedTitleAndToolbar`)
- [ ] The window uses `NSVisualEffectView` materials for chrome areas (toolbar, titlebar)
- [ ] Window size and position are persisted across launches via standard macOS state restoration
- [ ] The window supports native full-screen mode (Cmd+Ctrl+F)
- [ ] The window supports system light/dark mode and updates dynamically when appearance changes
- [ ] On first launch (no previous state), a new blank untitled document is open with the cursor blinking and ready for input -- no welcome screen, no dialogs
- [ ] On subsequent launches, previously open documents are restored (native `NSDocument` restoration)
- [ ] The app respects the system accent color throughout

**Tasks:**

| Task ID  | Description | Agent | Depends On | Status |
|----------|-------------|-------|------------|--------|
| T-001.1  | Create the Xcode project as a macOS Document-Based App using Swift. Configure the project for macOS 14+ deployment target. Set up the `NSDocument` subclass (e.g., `MarkdownDocument`) that will serve as the document model. The document should store raw markdown `String` content, implement `read(from:ofType:)` and `data(ofType:)` for file I/O using UTF-8 encoding, and enable auto-save (`autosavesInPlace = true`). Register the document type for `.md`, `.markdown`, `.mdown`, `.mkd`, and `.txt` file extensions. Reference: FEATURE_SPEC section 3.2 for the data model, Design Direction Principle 3 for auto-save. | principal-frontend-engineer | -- | TODO |
| T-001.2  | Configure the main window. Use `NSWindowController` with unified titlebar/toolbar style. Enable native document tab support via `NSWindow.tabbingMode = .preferred`. Set the window to restore size/position across launches using `NSWindow.setFrameAutosaveName`. Ensure the window supports native full-screen mode. Reference: Design Direction section 6 (tabs) and Principle 6 (unified window). | principal-frontend-engineer | T-001.1 | TODO |
| T-001.3  | Build the app-level coordinator that manages application state: tracking open documents, managing untitled document numbering ("Untitled", "Untitled 2", etc. -- numbers never recycle within a session), and handling the case where the last document is closed (open a new blank document instead of showing an empty state). Reference: FEATURE_SPEC section 3.2 (AppState), section 6.1 (untitled naming), business rule 5. Design Direction Principle 4 (no welcome screen). | principal-frontend-engineer | T-001.1 | TODO |
| T-001.4  | Implement system appearance support. Ensure the entire app responds to light/dark mode changes dynamically. Use semantic system colors (`NSColor.textBackgroundColor`, `NSColor.textColor`, etc.) throughout -- do not hardcode any colors. Verify the system accent color is picked up for selection, active states, and indicators. Reference: Design Direction section 2 (Color Palette), Principle 5 (Respect the Platform). | principal-frontend-engineer | T-001.2 | TODO |

#### T-001.1 Architectural Hints

- **Module placement:** `Document/MarkdownDocument.swift` for the NSDocument subclass. `App/AppDelegate.swift` for the application delegate. Update `Info.plist` with document type declarations (UTIs for markdown).
- **Pattern:** Standard NSDocument subclass. Override `autosavesInPlace` to return `true`. Override `data(ofType:)` and `read(from:ofType:)`. The `content` property is a plain `String`. Do NOT use `NSAttributedString` for persistence -- the file format is plain UTF-8 text. Attributed strings are only for the editor's display layer (NSTextStorage).
- **Data flow:** `MarkdownDocument.content` is the canonical model. When the user edits in the text view (US-002), the `NSTextStorageDelegate` callback updates `content`. When `content` changes, `updateChangeCount(.changeDone)` is called to trigger the dirty indicator and auto-save. When reading a file, `content` is set from file data and then pushed to the text view.
- **Watch out for:** Register UTIs in Info.plist correctly. The app needs both "Imported Type Declarations" for markdown UTIs that macOS does not natively know (`net.daringfireball.markdown` or `org.letsmarkdown.markdown`) AND "Document Types" referencing those UTIs. Also register `public.plain-text` for `.txt` support. Get this wrong and Open/Save panels will not filter correctly. Test that double-clicking a `.md` file in Finder opens it in MdEditor.
- **NOT in scope:** Do not implement the text view, toolbar, or any UI in this task. This is the document model and project skeleton only.

#### T-001.2 Architectural Hints

- **Module placement:** `WindowChrome/MainWindowController.swift`. The window controller is instantiated by `MarkdownDocument.makeWindowControllers()`. Do NOT use a storyboard for the window controller if possible -- programmatic setup gives more control.
- **Pattern:** Subclass `NSWindowController`. In `windowDidLoad()`, configure the window: set `window?.styleMask` to include `.unifiedTitleAndToolbar` and `.fullSizeContentView`. Set `window?.tabbingMode = .preferred`. Set `window?.setFrameAutosaveName("MdEditorMainWindow")`. Set `self.shouldCascadeWindows = false` so that new document windows merge into tabs rather than cascading.
- **View hierarchy:** The window's `contentViewController` will eventually be the `MainSplitViewController` (US-007). For now, set it to a placeholder `NSViewController` that will be replaced. Or, better: set it to the `ContentViewController` directly, and wrap it in the split view later when US-007 is implemented.
- **Watch out for:** `tabbingMode = .preferred` means macOS will prefer tabs, but the user's system preference for "Prefer tabs when opening documents" also affects this. Test with the system preference set to both "Always" and "Never." Also: the `NSWindow.StyleMask.unifiedTitleAndToolbar` flag alone does not create the blended look -- you also need to set `titlebarAppearsTransparent` carefully (or not -- test the visual result). The Design Direction wants the window to feel unified but still have `NSVisualEffectView` materials for chrome. The standard unified style without `titlebarAppearsTransparent` is likely correct.
- **NOT in scope:** Toolbar buttons (US-003), sidebar (US-007), and editor content (US-002) are NOT part of this task. This is window chrome only.

#### T-001.3 Architectural Hints

- **Module placement:** `App/DocumentController.swift`. Subclass `NSDocumentController` and set it as the shared document controller in `AppDelegate.applicationWillFinishLaunching(_:)` (it MUST be set before the app finishes launching -- use `willFinishLaunching`, not `didFinishLaunching`).
- **Pattern:** The `DocumentController` maintains a private `var nextUntitledNumber: Int = 1` counter. Override `displayNameForDocument(_:)` or have `MarkdownDocument` compute its `displayName` by asking the controller for the next number. The counter increments monotonically and never recycles within a session, even when documents are closed.
- **State ownership:** The untitled counter is session-level state owned by `DocumentController`. It is not persisted.
- **Data flow:** When the last document is closed, the `DocumentController` must detect this and open a new blank document. Hook into `NSDocumentController`'s lifecycle -- override `removeDocument(_:)` or observe `NSWindow.willCloseNotification` and check if zero documents remain. If so, call `newDocument(nil)` on the next run loop iteration (use `DispatchQueue.main.async` to avoid re-entrancy during the close flow).
- **Watch out for:** The "open a new blank document when the last tab closes" behavior can cause infinite loops if implemented carelessly. The new document creation must not trigger another close check. Guard against this. Also: test with multiple windows. Closing the last tab in one window should open a new blank tab in THAT window, not in another window. This is subtle with native document tabs.
- **NOT in scope:** File open/save logic (US-005). This task is about the coordinator's lifecycle management, not file I/O.

#### T-001.4 Architectural Hints

- **Module placement:** No new files. This is a cross-cutting concern verified across all existing views.
- **Pattern:** Use only semantic `NSColor` constants: `.textBackgroundColor`, `.textColor`, `.secondaryLabelColor`, `.tertiaryLabelColor`, `.quaternaryLabelColor`, `.controlAccentColor`, `.separatorColor`, `.selectedContentBackgroundColor`. Never use `.white`, `.black`, or any hardcoded RGB/hex values. For SwiftUI views (later), use `Color(.textBackgroundColor)` to bridge NSColor into SwiftUI.
- **Watch out for:** `NSColor.textBackgroundColor` is NOT the same as `NSColor.windowBackgroundColor`. The design direction specifies `textBackgroundColor` for the editing canvas (pure white in light mode, true dark in dark mode). The chrome (toolbar, sidebar) uses `NSVisualEffectView` materials which handle their own colors. Do not manually set background colors on chrome -- let the visual effect view do its job. Test by toggling System Preferences > Appearance between Light and Dark while the app is running -- all colors must update instantly without an app restart.
- **NOT in scope:** Actual view implementation. This task validates the color strategy that will be applied as views are built in subsequent stories.

---

### US-002: Editing Canvas with Markdown Syntax Highlighting

**As a** writer, **I want** a clean, distraction-free editing surface with subtle markdown syntax highlighting, **so that** I can focus on my writing while still seeing the structure of my document.

**Architectural Guidance:**

This is the heart of the application. The editing canvas is an `NSTextView` hosted inside an `NSScrollView`, managed by an `EditorViewController`. This is NOT a SwiftUI TextEditor -- SwiftUI's text editing capabilities are insufficient for syntax highlighting, custom layout, gutter line numbers, and the level of typographic control required. The `NSTextView` will use a custom `NSTextStorage` subclass for syntax highlighting and a standard `NSLayoutManager` (or `NSTextLayoutManager` if targeting the newer TextKit 2 -- see decision below).

- **Framework:** AppKit (`NSTextView`, `NSTextStorage`, `NSLayoutManager`, `NSScrollView`). No SwiftUI in the editor view itself.
- **TextKit decision:** Use **TextKit 1** (`NSTextStorage` + `NSLayoutManager` + `NSTextContainer`). TextKit 2 (`NSTextContentStorage` + `NSTextLayoutManager`) is the future but has known issues with custom attribute rendering, performance for large documents, and incomplete API surface for features like line number gutters and custom background drawing. TextKit 1 is battle-tested and provides everything this app needs. Set `NSTextView.usesAdaptiveColorMappingForDarkAppearance = false` to maintain manual control of syntax colors.
- **Syntax highlighting strategy:** Subclass `NSTextStorage` as `MarkdownTextStorage`. Override `replaceCharacters(in:with:)` and `setAttributes(_:range:)` to maintain the backing store (a plain `NSMutableAttributedString`). After every edit, schedule a highlighting pass on the edited paragraph(s) plus any affected neighbors (e.g., a multi-line code block boundary change). Do NOT re-highlight the entire document on every keystroke. Use `processEditing()` to apply attributes in the `editedRange`. The highlighting logic parses the affected lines using regex or a lightweight line-by-line markdown scanner (NOT the full swift-markdown AST parser for per-keystroke highlighting -- that is too expensive).
- **Performance contract:** Typing latency must be imperceptible. The highlighting pass must complete within the `processEditing()` call synchronously on the main thread. For documents up to 1MB, line-by-line regex-based highlighting is fast enough. If performance becomes an issue with very large documents, implement visible-range-only highlighting triggered by `NSView.visibleRect` changes.
- **Data flow:** User types in NSTextView -> NSTextStorage `processEditing()` fires -> MarkdownTextStorage applies syntax attributes -> NSTextStorageDelegate `textStorageDidProcessEditing(_:)` updates `MarkdownDocument.content` with the plain string -> `updateChangeCount(.changeDone)` triggers dirty state and auto-save.
- **Integration points:** The editor view controller is owned by the `ContentViewController` (which swaps between editor and preview). Formatting commands (US-003) operate on the `NSTextView` by manipulating its text storage directly. The status bar (US-009) reads cursor position and content metrics from the editor. Preferences (US-010) change font, font size, tab width, line numbers, and word wrap.

**Acceptance Criteria:**
- [ ] The editing surface uses `NSTextView` (wrapped for use with SwiftUI if needed) with the system monospaced font at 14pt default
- [ ] Line height is 1.6x the font size
- [ ] Horizontal padding is 48pt minimum on each side; content width is capped at approximately 900px and centered in wider windows
- [ ] Bottom overscroll allows the last line to reach the vertical center of the viewport
- [ ] Top padding is 24pt from the toolbar/tab area to the first line of text
- [ ] The current line has a barely perceptible highlight (`NSColor.textColor` at 0.03 alpha)
- [ ] Markdown syntax characters (`#`, `**`, `*`, backticks) render in `NSColor.tertiaryLabelColor`
- [ ] Headings render at scaled sizes: H1 at 1.5x/semibold, H2 at 1.3x/semibold, H3 at 1.15x/semibold, H4-H6 at base size/semibold
- [ ] Bold text renders bold, italic text renders italic, links render in accent color at 0.7 opacity
- [ ] Code spans have a barely-visible background tint (`NSColor.quaternaryLabelColor`)
- [ ] The editor uses soft word wrap (no horizontal scrolling)
- [ ] An empty document shows nothing -- no placeholder text, no prompts. The blinking cursor is the invitation
- [ ] Undo/redo works with a minimum depth of 100 operations
- [ ] Tab key inserts spaces (4 by default, configurable)
- [ ] Standard macOS text editing: cut/copy/paste, find/replace, spell check all work
- [ ] Smooth, inertial, native `NSScrollView` scrolling at 60fps
- [ ] Typing has zero perceptible input lag

**Tasks:**

| Task ID  | Description | Agent | Depends On | Status |
|----------|-------------|-------|------------|--------|
| T-002.1  | Build the core `NSTextView`-based editing view. Configure it with the system monospaced font at 14pt, 1.6x line height, soft word wrap, and UTF-8 encoding. Set up the text storage and layout manager for the syntax highlighting pipeline (the actual highlighting rules come in T-002.2). Wire the text view's content to the `MarkdownDocument` model so edits update the document's content and trigger the dirty state / auto-save cycle. Ensure undo manager supports 100+ operations. Configure tab key to insert 4 spaces. Reference: FEATURE_SPEC section 4.4, Design Direction section 4 (Editing Canvas). | principal-frontend-engineer | T-001.1 | TODO |
| T-002.2  | Implement markdown syntax highlighting in the editor. Use `NSTextStorage` delegate or a custom `NSLayoutManager` approach to apply attributes as the user types. Rules: (a) Markdown syntax characters (`#`, `**`, `*`, `` ` ``, `>`, `-` list markers) render in `NSColor.tertiaryLabelColor`. (b) Heading content (not the `#` chars) renders at scaled sizes (H1=1.5x semibold, H2=1.3x semibold, H3=1.15x semibold, H4-H6=base semibold) in `NSColor.labelColor`. (c) Bold text gets heavier weight, not color. (d) Italic text gets slant, not color. (e) Links get system accent color at 0.7 opacity. (f) Code spans get `NSColor.quaternaryLabelColor` background tint. (g) List markers dimmed. Performance is critical: highlighting must not cause typing lag. Consider incremental/visible-range-only highlighting for large documents. Reference: Design Direction section 2 (Color and Typography, Syntax hints). | principal-frontend-engineer | T-002.1 | TODO |
| T-002.3  | Implement the canvas spatial layout. Horizontal padding: 48pt minimum each side. Content width capped at ~900px, centered when the window is wider. Top padding: 24pt below toolbar/tabs. Bottom overscroll: the last line can scroll to the vertical center of the viewport (implement via `NSTextView` `textContainerInset` or additional bottom inset). Current line highlight: draw a background rect on the line containing the cursor using `NSColor.textColor` at 0.03 alpha -- update on cursor movement. Reference: Design Direction section 4 (Spatial Design, Cursor and Selection). | principal-frontend-engineer | T-002.1 | TODO |
| T-002.4  | Implement line numbers gutter. Off by default. When enabled (via View menu or preferences), display line numbers in `NSColor.quaternaryLabelColor` with a thin 1px vertical rule in `NSColor.separatorColor` between the gutter and the content area. The gutter scrolls with the text. Reference: Design Direction section 4 (Line numbers), FEATURE_SPEC section 4.4. | principal-frontend-engineer | T-002.1 | TODO |
| T-002.5  | Implement auto-continue lists. When the user presses Enter at the end of a line starting with `- `, `* `, `1. ` (or any numbered), or `- [ ] ` / `- [x] `, automatically insert the appropriate prefix on the next line. For numbered lists, increment the number. When the user presses Enter on a list line that has only the prefix and no content, remove the prefix (exit list mode). Reference: FEATURE_SPEC section 4.4, FEATURE_SPEC section 7.2. | principal-frontend-engineer | T-002.1 | TODO |
| T-002.6  | Implement drag-and-drop on the editor. (a) Dropping an image file (png, jpg, jpeg, gif, svg, webp) onto the editor inserts `![filename](file-path)` at the drop position. Use a relative path if the image is in the same directory tree as the document; otherwise use absolute path. (b) Dropping a `.md` file onto the editor opens it as a new tab (does not insert text). (c) Dropping other file types is ignored. (d) If the editor is in preview mode when an image is dropped, switch to editing mode first, then insert. Reference: FEATURE_SPEC section 4.4 (drag-and-drop), section 7.5 (image paths), edge case table. | principal-frontend-engineer | T-002.1, T-001.3 | TODO |

#### T-002.1 Architectural Hints

- **Module placement:** `Editor/EditorViewController.swift` for the view controller. `Editor/MarkdownTextStorage.swift` for the custom NSTextStorage subclass (even though highlighting rules are in T-002.2, the subclass shell must be created here). The editor view controller creates the NSTextView + NSScrollView programmatically -- do not use Interface Builder.
- **Pattern:** Create the TextKit 1 stack manually: `MarkdownTextStorage` -> `NSLayoutManager` -> `NSTextContainer` -> `NSTextView`. Set the text view as the scroll view's document view. This manual stack creation is necessary because the default `NSTextView` convenience initializer creates its own text storage, and we need our custom subclass.
- **View hierarchy:** `EditorViewController.view` is an `NSScrollView`. The `NSScrollView.documentView` is the `NSTextView`. Configure the scroll view with `hasVerticalScroller = true`, `hasHorizontalScroller = false`, `autohidesScrollers = true`, and elastic scrolling via `verticalScrollElasticity = .allowed`.
- **State ownership:** The NSTextView's text storage is the live editing buffer. `MarkdownDocument.content` is kept in sync via the `NSTextStorageDelegate.textStorageDidProcessEditing(_:)` delegate method. When the document loads a file, it pushes content TO the text storage. When the user types, the text storage pushes content BACK to the document.
- **Data flow for content sync:** In `textStorageDidProcessEditing(_:)`, check that `editedMask.contains(.editedCharacters)` before updating `MarkdownDocument.content`. This avoids triggering content updates on attribute-only changes (which happen during syntax highlighting). Update the document content as `textStorage.string` (plain string, no attributes).
- **Line height:** Set via `NSMutableParagraphStyle.lineHeightMultiple = 1.6` applied as the default paragraph style. Also set it on the `NSTextView.defaultParagraphStyle`. The paragraph style must be re-applied after font changes (US-010 preferences).
- **Font:** `NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)`. Store the current font in `AppPreferences` so preferences can change it.
- **Soft word wrap:** Set `NSTextView.isHorizontallyResizable = false` and `NSTextContainer.widthTracksTextView = true`. This is the default for a vertically scrolling text view, but verify it.
- **Tab key:** Override `insertTab(_:)` in the NSTextView subclass (or use the text view delegate's `textView(_:doCommandBy:)`) to insert 4 spaces instead of a tab character. Read the tab width from `AppPreferences`.
- **Undo:** NSTextView provides built-in undo via its `undoManager`. The default undo depth is unlimited. Verify with `undoManager?.levelsOfUndo` and set to at least 100 if it is limited. Each user action (typing, formatting) should be a single undoable group. The `NSTextView` handles this automatically for typing. Formatting commands (US-003) must group their multi-step text mutations into a single undo group via `undoManager?.beginUndoGrouping()` / `endUndoGrouping()`.
- **Watch out for:** When setting the text storage content programmatically (e.g., when loading a document), wrap it in `beginEditing()` / `endEditing()` to avoid multiple partial layout passes. Also, when loading content, do NOT trigger `updateChangeCount(.changeDone)` -- the document is clean after loading. Use a flag like `isLoadingContent` to suppress the `textStorageDidProcessEditing` callback during initial load.
- **NOT in scope:** Syntax highlighting rules (T-002.2), spatial layout/padding (T-002.3), line numbers (T-002.4), list continuation (T-002.5), drag-and-drop (T-002.6). This task builds the bare text editing surface with correct font, line height, word wrap, tab behavior, undo, and document content sync.

#### T-002.2 Architectural Hints

- **Module placement:** `Editor/MarkdownTextStorage.swift` (extend the subclass created in T-002.1 with highlighting logic). Consider a separate `Editor/MarkdownHighlighter.swift` that encapsulates the regex patterns and attribute computation, called from `MarkdownTextStorage.processEditing()`.
- **Pattern:** In `MarkdownTextStorage.processEditing()`, after calling `super.processEditing()`, determine the range of lines affected by the edit (expand `editedRange` to full line boundaries, plus neighboring lines for multi-line constructs). Strip all custom syntax attributes from this range, then re-apply them by scanning the text line-by-line.
- **Highlighting strategy:** Use `NSRegularExpression` patterns applied line-by-line. Do NOT use the full `swift-markdown` AST parser here -- it is too slow for per-keystroke use. The AST parser is for the preview renderer (US-004). The editor highlighting is intentionally simpler and faster: regex for `^#{1,6}\s`, `\*\*...\*\*`, `\*...\*`, `` `...` ``, `\[...\]\(...\)`, `^[-*]\s`, `^>\s`, etc.
- **Attribute application:** For headings, apply both size-scaled font AND `NSColor.labelColor` to the content, AND `NSColor.tertiaryLabelColor` to the `#` characters. This means splitting the heading line into two attribute runs: the prefix (`### `) and the content. For bold, apply `.bold` trait to the font. For italic, apply `.italic` trait. For code spans, apply `NSColor.quaternaryLabelColor` as `.backgroundColor`. For links, apply `NSColor.controlAccentColor.withAlphaComponent(0.7)` as `.foregroundColor`.
- **Watch out for:** Changing font size attributes (for headings) within `processEditing()` can trigger layout recalculation which can trigger another `processEditing()` call. Guard against infinite recursion with an `isHighlighting` flag. Also: multi-line constructs (fenced code blocks with ``` delimiters) require expanding the affected range beyond the edited line. Detect fenced code block boundaries and re-highlight the entire block when any line within it changes.
- **Performance:** For the common case (user typing on a single line), only the current paragraph needs re-highlighting. This must complete in under 1ms. Profile with a 1MB document to verify no typing lag. If lag appears, implement visible-range-only highlighting: only highlight lines within `NSScrollView.documentVisibleRect`, and re-highlight on scroll.
- **NOT in scope:** Editor spatial layout (T-002.3). This task is purely about attribute application for syntax highlighting.

#### T-002.3 Architectural Hints

- **Module placement:** `Editor/EditorViewController.swift` (extend the view controller from T-002.1).
- **Pattern:** Use `NSTextView.textContainerInset` for top and horizontal padding. Set `textContainerInset = NSSize(width: 48, height: 24)` for the basic padding. For the 900px max width constraint, dynamically adjust the `NSTextContainer.size.width` (or equivalently, the `textContainerInset.width`) when the window resizes. In `viewDidLayout()` or via a window resize notification, compute: `let maxContentWidth: CGFloat = 900; let availableWidth = scrollView.bounds.width; let horizontalPadding = max(48, (availableWidth - maxContentWidth) / 2); textView.textContainerInset = NSSize(width: horizontalPadding, height: 24)`.
- **Bottom overscroll:** The last line should be scrollable to the vertical center. Implement by adding extra bottom inset to the `NSTextView`. Override `NSTextView.intrinsicContentSize` or add a large `textContainerInset` bottom component. The value should be approximately `scrollView.bounds.height / 2`. Recalculate on window resize. Alternatively, set `NSTextView.isVerticallyResizable = true` and add bottom padding via the text container's `lineFragmentPadding` or by appending a spacer to the text container inset.
- **Current line highlight:** Override `NSTextView.drawBackground(in:)` in a custom `NSTextView` subclass. In this override, call `super.drawBackground(in:)`, then compute the rect of the line containing the cursor (use `layoutManager.lineFragmentRect(forGlyphAt:effectiveRange:)` for the glyph at the cursor position). Fill this rect with `NSColor.textColor.withAlphaComponent(0.03)`. Invalidate the display of the old and new line rects when the cursor moves (observe `NSTextView.didChangeSelectionNotification`).
- **Watch out for:** The centering calculation in `viewDidLayout()` must account for the scroll view's insets and any gutter width (T-002.4). If line numbers are enabled, subtract the gutter width from the available width before computing padding. The bottom overscroll inset needs recalculation when the window resizes. Also: `textContainerInset` applies to all four edges of the text container relative to the scroll view. Changing it at runtime requires calling `NSTextView.invalidateTextContainerOrigin()` and potentially `needsLayout = true`.
- **NOT in scope:** Line numbers (T-002.4). But be aware that the gutter affects the horizontal layout, so the padding calculation must be extensible.

#### T-002.4 Architectural Hints

- **Module placement:** `Editor/LineNumberGutter.swift`. Subclass `NSRulerView` and add it as the `NSScrollView.verticalRulerView`.
- **Pattern:** NSRulerView is the standard macOS mechanism for scroll-synced gutters. Set `scrollView.hasVerticalRuler = true` and `scrollView.verticalRulerView = lineNumberGutter` and `scrollView.rulersVisible = showLineNumbers` (from preferences). The ruler view draws line numbers by iterating visible lines using the layout manager's `enumerateLineFragments(forGlyphRange:using:)`.
- **Data flow:** The gutter observes `NSTextStorage` changes (via notification) and `NSView.boundsDidChangeNotification` on the scroll view's clip view to know when to redraw. On each redraw, it queries the layout manager for the Y positions of visible line fragments and draws the corresponding line numbers.
- **Visual spec:** Line numbers in `NSColor.quaternaryLabelColor`, right-aligned in the gutter. A 1px vertical line in `NSColor.separatorColor` at the right edge of the gutter, separating numbers from content. Gutter width should auto-size based on the number of digits needed (e.g., wider gutter for 1000+ line documents).
- **Watch out for:** NSRulerView has its own drawing cycle separate from the text view. When the text view scrolls, the ruler view must redraw synchronously or the line numbers will lag behind. Use `postsBoundsChangedNotifications = true` on the clip view and observe `NSView.boundsDidChangeNotification`. Also: the gutter width affects the horizontal padding calculation from T-002.3 -- when line numbers are toggled on/off, the text container inset must be recalculated.
- **NOT in scope:** This is display-only. The gutter does not respond to clicks (no breakpoints, no code folding).

#### T-002.5 Architectural Hints

- **Module placement:** `Editor/ListContinuation.swift`. This logic hooks into the NSTextView's key event handling.
- **Pattern:** Override `insertNewline(_:)` in the NSTextView subclass (or use the delegate method `textView(_:doCommandBy:)` to intercept the `insertNewline:` selector). When Enter is pressed: (1) get the text of the current line, (2) check if it matches a list pattern (`/^(\s*)([-*]|\d+\.|[-*] \[[ x]\])\s/`), (3) if it matches AND there is content after the prefix, insert a new line with the same prefix (incrementing the number for numbered lists), (4) if it matches but the line is ONLY the prefix with no content, remove the prefix from the current line (exit list mode).
- **State ownership:** No new state. This operates purely on the text storage content at the moment of the keypress.
- **Watch out for:** The newline insertion and prefix insertion must be a single undo group. Wrap in `undoManager?.beginUndoGrouping()` / `endUndoGrouping()`. Also: handle the case where the cursor is in the MIDDLE of a list line (not at the end) -- the standard behavior is to split the line, and the prefix should appear on the NEW line with the content after the cursor, not on the original line. Test numbered lists carefully: inserting a new item between existing items should NOT renumber subsequent items (that is out of scope for v1).
- **NOT in scope:** Automatic renumbering of subsequent numbered list items when a new item is inserted or deleted.

#### T-002.6 Architectural Hints

- **Module placement:** `Editor/MarkdownTextView.swift` (the NSTextView subclass) or `Editor/EditorViewController.swift` via `NSDraggingDestination` protocol.
- **Pattern:** Register the text view for drag types: `NSPasteboard.PasteboardType.fileURL`. Implement `NSDraggingDestination` methods: `draggingEntered(_:)`, `performDragOperation(_:)`. In `performDragOperation`, read the file URLs from the pasteboard. For each URL: check the file extension. If it is an image type (png, jpg, jpeg, gif, svg, webp), compute the markdown image reference `![filename](path)` and insert it at the drop point. If it is a `.md` file, open it as a new tab via `NSDocumentController.shared.openDocument(withContentsOf:display:completionHandler:)`. If it is any other type, return `false` (ignore).
- **Data flow for image path:** If the document has a `fileURL`, compute a relative path from the document's directory to the image file using `URL.relativePath` or `FileManager`-based path computation. If the document is untitled (no `fileURL`), use the absolute path. The spec says to show a note "Save the document first for relative image paths" -- show this as a brief notification or in the status bar, not as a modal alert.
- **Watch out for:** When the document is in preview mode and an image is dropped, the drag destination must switch to edit mode FIRST (by setting `document.viewMode = .editing` and waiting for the transition), then insert the text. This requires coordination with the `ContentViewController` (US-004). Also: the drop point in the text view must be converted from the drag operation's location to a character index using `characterIndex(for:fractionOfDistanceBetweenInsertionPoints:)`.
- **NOT in scope:** Drag-and-drop reordering of text within the editor (that is standard NSTextView behavior and works out of the box). Only custom handling of file drops is in scope.

---

### US-003: Toolbar with Formatting Actions

**As a** writer, **I want** a minimal toolbar with formatting buttons and keyboard shortcuts, **so that** I can apply markdown formatting quickly without memorizing syntax.

**Architectural Guidance:**

The toolbar is an `NSToolbar` managed by a `ToolbarManager` class that acts as the `NSToolbarDelegate`. The toolbar is NOT a SwiftUI toolbar -- SwiftUI's `.toolbar` modifier does not provide the level of control needed for custom hover states, dynamic button visibility based on mode, animated fade-in/out of button clusters, and popover anchoring. The toolbar items are `NSToolbarItem` instances with custom `NSButton` views for the formatting buttons.

- **Framework:** AppKit (`NSToolbar`, `NSToolbarItem`, `NSButton`, `NSSegmentedControl`, `NSPopover`).
- **Pattern:** `ToolbarManager` conforms to `NSToolbarDelegate` and is owned by the `MainWindowController`. It creates and manages all toolbar items. The toolbar identifier scheme uses constants (e.g., `NSToolbarItem.Identifier("bold")`, `NSToolbarItem.Identifier("editPreviewToggle")`). The `ToolbarManager` holds a reference to the active editor and the document to read formatting state and view mode.
- **Formatting command architecture:** Separate the formatting LOGIC from the toolbar BUTTONS. Create a `FormattingCommands` class (or set of functions) in `Editor/FormattingCommands.swift` that takes an `NSTextView` and performs the text manipulation. The toolbar buttons and the menu bar items (US-008) and keyboard shortcuts all call the same `FormattingCommands` methods. This ensures consistency and avoids duplicating text manipulation logic.
- **Keyboard shortcuts:** Register shortcuts via `NSMenuItem` key equivalents in the main menu (US-008), NOT via `NSEvent.addLocalMonitorForEvents`. Menu-based shortcuts are the correct macOS pattern -- they appear in the menu, they participate in the responder chain, and they are automatically disabled when the menu item is disabled. The toolbar buttons do NOT need their own shortcut handling; they just call the same actions as the menu items.
- **Data flow:** When a toolbar button is clicked, it calls a formatting command method on the active editor's text view. When text selection changes in the editor, the editor notifies the `ToolbarManager` (via delegate or notification) to update button states (highlighted/not highlighted based on current formatting). When view mode changes, the `ToolbarManager` animates the center cluster visibility.

**Acceptance Criteria:**
- [ ] The toolbar lives in the native `NSToolbar` integrated with the titlebar (unified style)
- [ ] Left cluster: sidebar toggle button (visible only when a folder is open or always as a toggle)
- [ ] Center cluster (visible only in editing mode): 6 buttons -- Bold, Italic, Link, Code, List, Heading -- using monochrome SF Symbols, no borders, no labels
- [ ] Buttons in resting state show only the SF Symbol in `NSColor.secondaryLabelColor`; on hover they gain a subtle rounded-rect background
- [ ] When text is selected and a format applies, the corresponding button fills to `NSColor.controlAccentColor`
- [ ] A `...` overflow button opens a popover with: Strikethrough, Blockquote, Table, Horizontal Rule, Image, Code Block
- [ ] Right cluster: Edit/Preview segmented control (`NSSegmentedControl`) and a share/export button
- [ ] In Preview mode, the center formatting cluster fades out (not just disabled -- visually absent)
- [ ] Every formatting action has a keyboard shortcut shown in the button tooltip
- [ ] All formatting actions work correctly per the insertion behavior rules (wrap, toggle, line-prefix, block insertion) defined in the spec

**Tasks:**

| Task ID  | Description | Agent | Depends On | Status |
|----------|-------------|-------|------------|--------|
| T-003.1  | Build the `NSToolbar` with three clusters. Left: sidebar toggle button (SF Symbol `sidebar.left`, `NSColor.secondaryLabelColor`, no border). Center: 6 formatting buttons (Bold=`bold`, Italic=`italic`, Link=`link`, Code=`chevron.left.forwardslash.chevron.right`, List=`list.bullet`, Heading=`textformat.size`) plus `...` overflow button. Right: Edit/Preview segmented control and share/export button. All buttons use `NSColor.secondaryLabelColor` with no visible borders at rest, gaining a subtle rounded-rect background on hover. Each button has a tooltip showing the action name and its keyboard shortcut. Reference: Design Direction section 3 (Toolbar Design). | principal-frontend-engineer | T-001.2, T-002.1 | TODO |
| T-003.2  | Implement the 6 primary formatting actions triggered by toolbar buttons and keyboard shortcuts. (a) **Bold** (Cmd+B): wrap selection in `**...**`, or insert `**bold text**` with placeholder selected; toggle off if already bold. (b) **Italic** (Cmd+I): wrap in `*...*`, same pattern. (c) **Link** (Cmd+K): if text selected, open URL popover then wrap as `[text](url)`; if no selection, popover with both fields; auto-populate URL from clipboard if it contains a URL. (d) **Inline Code** (Cmd+E): wrap in backticks, same pattern. (e) **List** (Cmd+Shift+8 for bullet): toggle `- ` prefix on selected lines; secondary click or Cmd+Shift+7 for numbered list (`1. `); Cmd+Shift+9 for task list (`- [ ] `). (f) **Heading**: repeated clicks cycle through H1-H3; long-press or the overflow menu exposes H4-H6. Heading replaces any existing heading prefix. Keyboard shortcuts Cmd+1 through Cmd+6 for direct heading levels. Reference: FEATURE_SPEC section 7 (all subsections), Design Direction section 3. | principal-frontend-engineer | T-003.1, T-002.1 | TODO |
| T-003.3  | Implement the overflow popover formatting actions. The `...` button opens a popover containing: (a) **Strikethrough** (Cmd+Shift+X): wrap in `~~...~~`. (b) **Blockquote** (Cmd+Shift+.): prepend `> ` to selected lines; toggle off if already quoted. (c) **Code Block** (Cmd+Shift+C): wrap selection in fenced code block with language placeholder, or insert empty template with cursor inside. (d) **Horizontal Rule** (Cmd+Shift+-): insert `---` on a new line. (e) **Image** (Cmd+Shift+I): open popover with Alt Text, URL/Path fields, and "Choose File..." button; insert `![alt](path)`. (f) **Table** (Cmd+Option+T): insert 3x3 table template with cursor in first data cell. Reference: FEATURE_SPEC sections 7.1-7.5. | principal-frontend-engineer | T-003.1, T-002.1 | TODO |
| T-003.4  | Implement toolbar state management. (a) When text is selected, detect which formatting applies (is the selection bold? italic? inside a link? etc.) and fill the corresponding toolbar button to `NSColor.controlAccentColor`. (b) When switching to Preview mode, animate the center formatting cluster to fade out over 150ms (not just disable -- visually remove). When switching back to Edit, fade them back in. (c) The sidebar toggle button reflects sidebar visibility state. Reference: Design Direction section 3 (button state, toolbar in preview mode). | principal-frontend-engineer | T-003.1 | TODO |

#### T-003.1 Architectural Hints

- **Module placement:** `WindowChrome/ToolbarManager.swift`. This class conforms to `NSToolbarDelegate` and is owned by the `MainWindowController`. The toolbar is created in `MainWindowController.windowDidLoad()` and assigned to `window.toolbar`.
- **Pattern:** Implement `NSToolbarDelegate` methods: `toolbarAllowedItemIdentifiers(_:)`, `toolbarDefaultItemIdentifiers(_:)`, and `toolbar(_:itemForItemIdentifier:willBeInsertedIntoToolbar:)`. Use `NSToolbarItem.Identifier` constants defined in a private extension. For the center cluster, use a single `NSToolbarItemGroup` containing the 6 formatting buttons plus the overflow button. This allows treating them as a unit for animation (fade in/out). Use `NSToolbarItem.Identifier.flexibleSpace` to separate the three clusters.
- **Button styling:** Each formatting button is an `NSButton` with `bezelStyle = .texturedRounded` and `isBordered = false`. Set the button's image to the appropriate SF Symbol via `NSImage(systemSymbolName:accessibilityDescription:)`. Tint using `contentTintColor = .secondaryLabelColor`. For hover behavior, use `NSTrackingArea` on each button to detect mouse entry/exit and toggle `isBordered` or apply a custom background layer. Alternatively, use `NSButton.bezelStyle = .accessoryBarAction` which provides hover highlighting automatically on macOS 14+.
- **Tooltip format:** `"Bold (Cmd+B)"`, `"Italic (Cmd+I)"`, etc. Set via `button.toolTip`.
- **Edit/Preview segmented control:** Create a standard `NSSegmentedControl` with two segments labeled "Edit" and "Preview". Set `segmentStyle = .texturedRounded`. Wrap it in an `NSToolbarItem` and place it in the right cluster.
- **Watch out for:** `NSToolbar` items cannot be arbitrarily positioned left/center/right. Use `NSToolbarItem.Identifier.flexibleSpace` between clusters. The "center" cluster will not be perfectly centered -- it will be pushed right by the left cluster. This is standard macOS toolbar behavior and is acceptable. Do NOT try to force centering with custom layout -- it will break with window resizing.
- **NOT in scope:** Button actions (T-003.2), popover content (T-003.3), state management (T-003.4). This task builds the toolbar shell with non-functional buttons.

#### T-003.2 Architectural Hints

- **Module placement:** `Editor/FormattingCommands.swift`. This is a standalone class (or enum with static methods) that operates on an `NSTextView`. It is called by toolbar buttons (this task), menu items (US-008), and keyboard shortcuts (via the menu responder chain).
- **Pattern:** Each formatting action is a method that takes the `NSTextView` as a parameter (e.g., `static func toggleBold(in textView: NSTextView)`). The method reads `textView.selectedRange()`, inspects the text to determine current state, performs the text manipulation via `textView.insertText(_:replacementRange:)` or `textView.textStorage?.replaceCharacters(in:with:)`, and sets the new selection range.
- **Undo grouping:** CRITICAL. Each formatting action must be a single undoable operation. Wrap multi-step text changes in `textView.undoManager?.beginUndoGrouping()` / `endUndoGrouping()`. Without this, undoing a bold action would require multiple Cmd+Z presses (one for each `replaceCharacters` call).
- **Toggle detection for wrap-style formatting (bold, italic, code, strikethrough):** Check if the characters immediately surrounding the selection match the formatting markers. For bold: check if the 2 characters before the selection start are `**` AND the 2 characters after the selection end are `**`. If so, toggle OFF by removing the markers. If not, toggle ON by inserting markers. Handle edge cases: selection at document start/end, selection that partially includes markers.
- **Heading cycling:** The Heading toolbar button cycles through H1, H2, H3 on repeated clicks. Maintain a small state (last heading level applied) in the `ToolbarManager` or use the current line's heading level to determine the next level. Cmd+1 through Cmd+6 set heading levels directly. The heading action operates on the current line by replacing or adding the prefix at the line start.
- **Link popover:** When the Link action is triggered, present an `NSPopover` anchored to the Link toolbar button (or near the text cursor). The popover contains text fields for URL (and optionally link text if no selection). On confirm, insert the markdown link syntax. Check `NSPasteboard.general` for a URL string and auto-populate the URL field if found.
- **Watch out for:** Cmd+E is used by BOTH "Inline Code" (FEATURE_SPEC section 9) AND "Use Selection for Find" (standard macOS Edit menu). This is a conflict. The FEATURE_SPEC assigns Cmd+E to Inline Code. The engineer must remove the standard "Use Selection for Find" binding from the Edit menu or reassign it. This is a known deviation from standard macOS behavior -- note it but follow the spec.
- **NOT in scope:** Overflow formatting actions (T-003.3). Only the 6 primary formatting actions are implemented here.

#### T-003.3 Architectural Hints

- **Module placement:** `Editor/FormattingCommands.swift` (extend with overflow actions). `WindowChrome/OverflowPopoverViewController.swift` for the popover UI.
- **Pattern:** The `...` toolbar button presents an `NSPopover` containing a vertical stack of buttons for the overflow formatting actions. Each button calls a `FormattingCommands` method. The popover dismisses after an action is performed (or on click-outside).
- **Popover design:** Use `NSPopover` with `behavior = .semitransient` (dismisses on click outside, but stays open if the user clicks within it). The popover content is an `NSViewController` with a vertical `NSStackView` of buttons. Each button has an SF Symbol and a label ("Strikethrough", "Blockquote", etc.) with the keyboard shortcut shown in secondary text.
- **Image insertion popover:** This is more complex than the other overflow items. It needs two text fields (Alt Text, URL/Path) and a "Choose File..." button that opens `NSOpenPanel` filtered to image types. Place this in a separate popover or expand the overflow popover to show a form view when Image is selected.
- **Table insertion:** Insert the 3-column template as a single text insertion. Use `\n` for line breaks. Place the cursor in the first data cell by computing the character offset. This is purely a text manipulation in `FormattingCommands`.
- **Watch out for:** The Code Block action (Cmd+Shift+C) conflicts with no standard macOS shortcut, but verify. Inserting a fenced code block requires inserting ``` on the line before, ``` on the line after, and positioning the cursor between them. If text is selected, the selected text goes between the fences. The language placeholder after the opening ``` should be selected so the user can type the language immediately.
- **NOT in scope:** Toolbar state highlighting for overflow actions (T-003.4).

#### T-003.4 Architectural Hints

- **Module placement:** `WindowChrome/ToolbarManager.swift` (extend).
- **Pattern:** Observe `NSTextView.didChangeSelectionNotification` from the active editor. On each selection change, inspect the text around the selection to determine which formatting is active (bold? italic? inside a link? heading? list?). Update each toolbar button's appearance: active formatting buttons get `contentTintColor = .controlAccentColor`, inactive ones revert to `.secondaryLabelColor`.
- **Formatting detection:** Reuse the same logic from toggle detection in T-003.2, but read-only. For bold: check if the selection is enclosed in `**...**`. For heading: check if the current line starts with `# `. For list: check if the current line starts with `- ` or `1. `. This does not need to be perfect for every edge case -- it is a visual hint, not a parsing guarantee.
- **Mode transition animation:** When `MarkdownDocument.viewMode` changes to `.preview`, animate the center toolbar cluster to opacity 0 over 150ms using `NSAnimationContext.runAnimationGroup`. The items should also become disabled (not just invisible) so keyboard shortcuts for formatting do not fire in preview mode. When switching back to `.editing`, animate opacity back to 1. Observe the document's `viewMode` property via KVO or a delegate callback.
- **Watch out for:** When animating toolbar items, you are animating the `NSView` that is the toolbar item's custom view. The `NSToolbar` itself does not support per-item animation natively. You must get the toolbar item's `view` property and animate its `alphaValue`. If the toolbar rearranges items (e.g., on window resize), the animation state must be correct after rearrangement. Also: disabling toolbar items during preview must also disable the corresponding menu items. This is handled via the responder chain `validateMenuItem(_:)` in US-008.
- **NOT in scope:** The actual view mode toggle implementation (US-004). This task only handles toolbar state management in response to mode changes -- not the mode change itself.

---

### US-004: Edit/Preview Mode Toggle

**As a** writer, **I want** to toggle between editing my markdown and seeing the rendered preview, **so that** I can check how my document looks without leaving the app.

**Architectural Guidance:**

The edit/preview toggle is managed by a `ContentViewController` that acts as a container, swapping between the `EditorViewController` and the `PreviewViewController` with a cross-dissolve animation. Both child view controllers are kept alive (not destroyed on toggle) so that state is preserved. The view mode is stored per-document on `MarkdownDocument.viewMode`.

- **Framework:** AppKit for the container view controller and transition. `WKWebView` (WebKit) for the preview rendering. The preview HTML/CSS is bundled as app resources.
- **Pattern:** `ContentViewController` holds references to both `EditorViewController` and `PreviewViewController`. When `viewMode` changes, it runs a cross-dissolve by overlaying both views, animating alpha values, then removing the outgoing view. The `ContentViewController` is the `contentViewController` of the `MainSplitViewController`'s detail pane (or directly of the window if the sidebar is not active).
- **Markdown rendering pipeline:** `MarkdownRenderer` (in `Preview/MarkdownRenderer.swift`) takes a markdown `String` and produces an HTML `String`. It uses `swift-markdown` (or `cmark-gfm` for GFM support) to parse the AST and walk it to produce HTML. The HTML is wrapped in a full HTML document with the bundled CSS. The renderer is a pure function with no side effects -- it can be called from preview display (T-004.2), export as HTML (T-011.1), and export as PDF (T-011.2).
- **Scroll position preservation:** Before transitioning from edit to preview, capture the approximate document position. The simplest approach: compute the fraction of the document visible at the top of the editor (character offset / total characters). After the preview WKWebView finishes loading, execute JavaScript to scroll to the same fraction of the page (`window.scrollTo(0, document.body.scrollHeight * fraction)`). Going from preview back to edit: restore the cursor position and scroll offset that were saved when leaving edit mode.
- **Integration points:** The `ToolbarManager` (US-003 T-003.4) observes viewMode to animate formatting buttons. The `StatusBar` (US-009) changes its display based on viewMode. The toolbar's segmented control is the primary UI for changing viewMode.

**Acceptance Criteria:**
- [ ] A native `NSSegmentedControl` with "Edit" and "Preview" segments appears in the right area of the toolbar
- [ ] "Edit" is the default mode when any document is opened
- [ ] View mode is per-document: each tab independently tracks whether it is in Edit or Preview
- [ ] Toggling uses a cross-dissolve transition: editing text fades out (opacity 1 to 0) while preview fades in (opacity 0 to 1) over 150ms, with total transition under 200ms
- [ ] Scroll position is preserved: if the user was looking at a particular section in edit mode, the preview scrolls to the rendered position of that same content
- [ ] The toolbar formatting buttons fade out during the transition to Preview, and fade back in when returning to Edit
- [ ] Keyboard shortcut Cmd+Shift+P toggles to Preview; Cmd+Shift+E toggles to Edit
- [ ] Switching back to Edit preserves all content exactly

**Tasks:**

| Task ID  | Description | Agent | Depends On | Status |
|----------|-------------|-------|------------|--------|
| T-004.1  | Add the `viewMode` property (`.editing` / `.preview` enum) to the `MarkdownDocument` model so each document tracks its own mode independently. Wire the Edit/Preview `NSSegmentedControl` in the toolbar to this property. Implement Cmd+Shift+E and Cmd+Shift+P keyboard shortcuts to set the mode. Reference: FEATURE_SPEC section 3.2 (ViewMode), section 4.3 (view toggle). | principal-frontend-engineer | T-001.1, T-003.1 | TODO |
| T-004.2  | Build the preview rendering view using `WKWebView`. The view renders the document's markdown content as styled HTML. Use a bundled CSS stylesheet that follows Design Direction typography: system font (San Francisco) at 15pt body, 1.7x line height, max content width 680px centered, proper heading scale (H1=2em, H2=1.5em, H3=1.25em). The CSS must support both light and dark mode using `@media (prefers-color-scheme)` and semantic system-like colors. Include bundled syntax highlighting for code blocks (4 colors max: keyword, string, comment, default). Support all GFM features: tables with borders and alternating rows, task list checkboxes (visual only), blockquotes with left border, horizontal rules, autolinks, strikethrough, images. No external network requests. Reference: FEATURE_SPEC section 4.5, Design Direction section 2 (Preview typography). | principal-frontend-engineer | T-001.1 | TODO |
| T-004.3  | Implement the cross-dissolve transition between Edit and Preview modes. When toggling: (a) fade out the current view (opacity 1 to 0) over 150ms while simultaneously fading in the target view (opacity 0 to 1). (b) Simultaneously fade out/in the toolbar formatting buttons. (c) Preserve scroll position: before transitioning to Preview, capture the approximate content position (e.g., character offset or percentage through document), then after rendering Preview, scroll the WKWebView to the corresponding position. When returning to Edit, restore the cursor position and scroll offset. Total transition time must be under 200ms. Reference: Design Direction section 5 (transition details). | principal-frontend-engineer | T-004.1, T-004.2, T-002.1 | TODO |
| T-004.4  | Implement rich text copy from preview. When the user selects text in the preview `WKWebView` and copies it, ensure both HTML-formatted (rich) text and plain text are placed on the system pasteboard. Verify that pasting into external apps (Apple Notes, Slack, Google Docs, email) preserves formatting. This should work via the standard `WKWebView` copy behavior, but verify and fix if needed. Reference: FEATURE_SPEC section 4.5 (copy rich text), acceptance criteria. | principal-frontend-engineer | T-004.2 | TODO |

#### T-004.1 Architectural Hints

- **Module placement:** `Document/ViewMode.swift` for the enum. Add `var viewMode: ViewMode = .editing` to `MarkdownDocument.swift`. Wire the segmented control in `WindowChrome/ToolbarManager.swift`.
- **Pattern:** `ViewMode` is a simple enum with cases `.editing` and `.preview`. It is a stored property on `MarkdownDocument`, NOT on the view controller or the toolbar. This ensures each document tab has independent mode state. When the segmented control is clicked, it sets `document.viewMode`. The `ContentViewController` observes this property (via KVO on the NSDocument, or via a delegate protocol) and triggers the transition.
- **State ownership:** `viewMode` lives on `MarkdownDocument`. It is per-document, not global. It is NOT persisted to disk (it resets to `.editing` on document open). It IS preserved during tab switches (because the MarkdownDocument instance persists).
- **Keyboard shortcuts:** Cmd+Shift+E and Cmd+Shift+P are registered as menu items in the View menu (US-008). The menu item actions set `document.viewMode = .editing` or `.preview` respectively. They should also be available as `NSMenuItem` entries with key equivalents so they work through the responder chain.
- **Watch out for:** When adding `viewMode` to `MarkdownDocument`, do NOT include it in the document's serialized data (`data(ofType:)`). It is transient UI state. Also: the segmented control in the toolbar must stay synchronized with the document's `viewMode`. When switching tabs, the new active document's `viewMode` must be reflected in the segmented control immediately.
- **NOT in scope:** The actual view transition (T-004.3) and preview rendering (T-004.2). This task adds the data model property and wires the UI control.

#### T-004.2 Architectural Hints

- **Module placement:** `Preview/PreviewViewController.swift` for the WKWebView hosting. `Preview/MarkdownRenderer.swift` for the markdown-to-HTML conversion. `Preview/preview.css` and `Preview/highlight.js` as bundled resources.
- **Pattern:** `PreviewViewController` owns a `WKWebView`. When asked to display a markdown document, it calls `MarkdownRenderer.renderHTML(from: markdownString)` to get a complete HTML string, then loads it into the web view via `webView.loadHTMLString(html, baseURL: document.fileURL?.deletingLastPathComponent())`. Setting `baseURL` to the document's directory allows relative image paths to resolve correctly.
- **Markdown-to-HTML:** Use `cmark-gfm` (the C library, available as a Swift package `github.com/apple/swift-cmark` with GFM extensions) rather than `swift-markdown`. Reason: `swift-markdown` parses CommonMark but its HTML rendering requires manual AST walking. `cmark-gfm` provides `cmark_gfm_render_html()` which handles GFM tables, strikethrough, task lists, and autolinks out of the box with one function call. Wrap this C call in a Swift function in `MarkdownRenderer`.
- **CSS requirements:** The bundled CSS must handle: body font at 15pt system font, line-height 1.7, max-width 680px centered via `margin: 0 auto`, heading scale, table borders with alternating row colors, blockquote left border (4px solid in a subtle color), task list checkboxes (use CSS `list-style: none` with `input[type=checkbox]` elements), code block styling with the 4-color syntax highlighting. Use `@media (prefers-color-scheme: dark)` for dark mode colors. Use `-apple-system` font-family to get San Francisco.
- **Code block highlighting:** Bundle a minimal `highlight.js` with only the languages needed (or use a custom 4-color scheme that maps `hljs-keyword`, `hljs-string`, `hljs-comment`, and default). Keep the JS bundle small. Call `hljs.highlightAll()` after the HTML is loaded, via `webView.evaluateJavaScript("hljs.highlightAll()")`.
- **WKWebView configuration:** Set `WKWebViewConfiguration` preferences: `setValue(false, forKey: "allowFileAccessFromFileURLs")` is the default and correct for security. Set `WKPreferences.javaScriptEnabled = true` (needed for highlight.js). Disable link navigation by implementing `WKNavigationDelegate.decidePolicyFor(_:decisionHandler:)` -- allow only the initial `loadHTMLString` and block all other navigation. Links clicked in the preview should open in the system default browser via `NSWorkspace.shared.open(url)`.
- **No network requests:** The WKWebView must not make any external network requests. All CSS and JS are loaded from the HTML string itself (inlined) or from the app bundle (via `baseURL` pointing to the bundle resource path). Verify in the network inspector.
- **Watch out for:** WKWebView's `loadHTMLString(_:baseURL:)` has a behavior where `baseURL` must be a `file://` URL for local image resolution to work. If `baseURL` is `nil` (untitled document), relative image paths will not resolve -- this is expected and documented in the spec (broken image indicators for untitled documents). Also: WKWebView loads content asynchronously. The HTML will not be rendered when `loadHTMLString` returns. Use the `WKNavigationDelegate.webView(_:didFinish:)` callback to know when rendering is complete (needed for scroll position restoration in T-004.3).
- **NOT in scope:** The transition animation (T-004.3) or rich text copy (T-004.4). This task builds the preview view and the rendering pipeline.

#### T-004.3 Architectural Hints

- **Module placement:** `WindowChrome/ContentViewController.swift`. This is the container view controller that manages the transition.
- **Pattern:** `ContentViewController` owns both `EditorViewController` and `PreviewViewController` as child view controllers. Both are created once and reused. When transitioning from edit to preview: (1) Call `MarkdownRenderer.renderHTML(from: document.content)` to prepare the HTML. (2) Set the preview view's frame to match the editor view, set its `alphaValue = 0`, and add it as a subview. (3) Load the HTML into the WKWebView. (4) Animate: `NSAnimationContext.runAnimationGroup({ context in context.duration = 0.15; editorView.animator().alphaValue = 0; previewView.animator().alphaValue = 1 }, completionHandler: { self.editorView.removeFromSuperview() })`. (5) Notify the ToolbarManager to fade out formatting buttons. When transitioning back, reverse the process.
- **Scroll position preservation (edit to preview):** Before transitioning, compute `let scrollFraction = Double(cursorCharacterIndex) / Double(document.content.count)`. After the WKWebView finishes loading (wait for `webView(_:didFinish:)`), execute JavaScript: `window.scrollTo(0, document.body.scrollHeight * \(scrollFraction))`. This is approximate but effective for most documents.
- **Scroll position preservation (preview to edit):** Before leaving preview, there is no meaningful scroll position to transfer back (the WKWebView's scroll position does not map cleanly to a text view character offset). Instead, restore the cursor position and scroll offset that were saved when the user LEFT edit mode. Store these on the `MarkdownDocument` as transient properties: `var savedCursorRange: NSRange?` and `var savedScrollPosition: NSPoint?`.
- **Watch out for:** The WKWebView's `loadHTMLString` is asynchronous. If you start the animation immediately, the preview may show a blank white view during the fade-in. Strategy: begin the fade-out of the editor immediately (150ms), but delay the fade-in of the preview until `didFinish` fires. If `didFinish` fires before the 150ms fade-out completes, start the preview fade-in concurrently. If the HTML renders fast (< 50ms for most documents), this will look like a simultaneous cross-dissolve. If it renders slow, the editor fades out to white, then the preview fades in. This is acceptable per the Design Direction ("show the transition animation while rendering completes in the background").
- **Performance:** The total transition MUST be under 200ms for documents under 10,000 words. Profile the markdown rendering time. If `cmark_gfm_render_html` takes > 50ms for large documents, consider running it on a background thread and showing the animation while it completes. But cmark is extremely fast (handles megabytes in milliseconds), so this is unlikely to be needed.
- **NOT in scope:** The rich text copy behavior (T-004.4).

#### T-004.4 Architectural Hints

- **Module placement:** `Preview/PreviewViewController.swift` (verification only -- this should work out of the box).
- **Pattern:** WKWebView natively supports copy-as-rich-text. When the user selects text in the WKWebView and presses Cmd+C, the system places both `NSPasteboard.PasteboardType.html` and `NSPasteboard.PasteboardType.string` on the pasteboard. Verify this by: (1) selecting formatted text in the preview, (2) pressing Cmd+C, (3) pasting into Apple Notes, (4) verifying that bold, italic, headings, links, and code formatting are preserved.
- **Watch out for:** Some WKWebView configurations can interfere with the standard copy behavior. Ensure that `WKPreferences.javaScriptEnabled = true` (needed for the selection mechanism). Do not override the WKWebView's `performKeyEquivalent` or swallow Cmd+C events. If rich text copy does NOT work out of the box, the fallback is to implement a custom copy handler: use `webView.evaluateJavaScript("window.getSelection().getRangeAt(0).cloneContents()")` or similar to extract the selected HTML, then manually place it on the pasteboard with both HTML and plain-text types.
- **NOT in scope:** Modifying the copied HTML. The preview CSS is the only thing controlling how the rich text looks when pasted. If pasted formatting looks wrong in external apps, adjust the preview CSS (inline styles are more reliably preserved than class-based styles when pasting).

---

### US-005: File Operations (New, Open, Save, Save As)

**As a** writer, **I want** to create, open, and save markdown files using standard macOS conventions, **so that** my documents are persisted reliably and I can work with files from Finder or other apps.

**Architectural Guidance:**

Because the app uses `NSDocument`, most file operations are provided by the framework. `NSDocument` handles New, Open, Save, Save As, Revert, and auto-save. The engineer's job is to ensure the `MarkdownDocument` subclass correctly implements the data reading/writing methods, and to customize the open/save panel configurations. The `NSDocumentController` manages the recent files list automatically.

- **Framework:** AppKit (`NSDocument`, `NSDocumentController`, `NSOpenPanel`, `NSSavePanel`). No SwiftUI.
- **Pattern:** Override NSDocument lifecycle methods. Avoid reimplementing what NSDocument provides. The `DocumentController` (from T-001.3) customizes the `NSDocumentController` for untitled numbering and the "last tab closed" behavior. Standard menu items (New, Open, Save, Save As) are wired to `NSDocumentController` and `NSDocument` first-responder actions automatically when using the standard AppKit menu structure.
- **Data flow:** `NSDocument.read(from:ofType:)` reads data from disk and populates `content`. `NSDocument.data(ofType:)` serializes `content` to UTF-8 data for saving. Auto-save calls `data(ofType:)` periodically. `updateChangeCount(.changeDone)` is called whenever the content changes (from the text storage delegate). `updateChangeCount(.changeCleared)` is called after a successful save (NSDocument does this automatically).
- **Integration points:** File operations affect tabs (US-006) because opening a file creates a new tab. The sidebar (US-007) can trigger file opens when a file is clicked. The menu bar (US-008) wires menu items to these actions.

**Acceptance Criteria:**
- [ ] Cmd+N creates a new untitled document in a new tab with the cursor ready for input
- [ ] Cmd+O opens `NSOpenPanel` filtered to `.md`, `.markdown`, `.mdown`, `.mkd`, `.txt`; selected files open in new tabs
- [ ] If a file is already open in a tab, Cmd+O switches to that tab instead of opening a duplicate
- [ ] Cmd+S saves the active document; for untitled documents it triggers Save As
- [ ] Cmd+Shift+S opens `NSSavePanel` for Save As with default extension `.md`
- [ ] Cmd+Option+S saves all dirty documents, prompting Save As for untitled ones
- [ ] The tab dirty indicator (dot in close button) clears after a successful save
- [ ] Auto-save works continuously via `NSDocument` -- the user rarely needs to think about saving
- [ ] Files are read and written as UTF-8; non-UTF-8 files show an error
- [ ] Files over 10MB show a warning dialog; files over 50MB are refused
- [ ] File save errors (permissions, disk full) display an alert with the system error message
- [ ] Recently opened files are tracked and appear in File > Open Recent

**Tasks:**

| Task ID  | Description | Agent | Depends On | Status |
|----------|-------------|-------|------------|--------|
| T-005.1  | Implement New Document (Cmd+N). Creates a new `MarkdownDocument` with nil `fileURL` and empty content. Assigns the display name using the untitled numbering scheme ("Untitled", "Untitled 2", etc. -- numbers never recycle within a session). Opens it in a new tab via `NSDocumentController`. The new tab becomes active with the editor focused. Reference: FEATURE_SPEC section 6.1, business rule 5. | principal-frontend-engineer | T-001.3 | TODO |
| T-005.2  | Implement Open File (Cmd+O). Present `NSOpenPanel` allowing multiple file selection, filtered to `.md`, `.markdown`, `.mdown`, `.mkd`, `.txt`. For each selected file: check if it is already open (compare by resolved file URL) -- if so, switch to that tab; otherwise read the file, create a `MarkdownDocument`, and open it in a new tab. The last opened file becomes the active tab. Add each opened file to the recent files list. Handle errors: file not found (alert + remove from recents), permission denied (alert), non-UTF-8 (alert: "not a UTF-8 text file"), file >10MB (warning dialog with Open/Cancel), file >50MB (refused with error). Reference: FEATURE_SPEC sections 6.2, 10 (business rules 1, 6), 11 (edge cases). | principal-frontend-engineer | T-001.3, T-001.1 | TODO |
| T-005.3  | Implement Save (Cmd+S) and Save As (Cmd+Shift+S). Save: if the document has a `fileURL`, write content as UTF-8, update `lastSavedContent`, clear dirty state. If untitled, fall through to Save As. Save As: present `NSSavePanel` with current filename or "Untitled.md" as default, allowed extensions `.md`, `.markdown`, `.txt`. On confirm, write the file, update `fileURL`, `lastSavedContent`, and the tab display name. Handle write failures with an alert showing the system error. Implement Save All (Cmd+Option+S): iterate all dirty documents, save each; prompt Save As for untitled ones. Reference: FEATURE_SPEC sections 6.4, 6.5. | principal-frontend-engineer | T-001.1 | TODO |
| T-005.4  | Implement Close Tab (Cmd+W) and Close All (Cmd+Option+W). Close Tab: if dirty, show save prompt ("Save" / "Don't Save" / "Cancel"); Save triggers save flow (may prompt Save As for untitled), Don't Save discards, Cancel keeps tab open. If clean, close immediately. After closing, activate the next tab to the right (or left if none to the right). If no tabs remain, open a new blank document (per Design Direction -- no empty/welcome state). Close All: same flow for each dirty document. Reference: FEATURE_SPEC section 6.6, Design Direction Principle 4. | principal-frontend-engineer | T-001.3, T-005.3 | TODO |

#### T-005.1 Architectural Hints

- **Module placement:** `App/DocumentController.swift` (extend), `Document/MarkdownDocument.swift` (extend).
- **Pattern:** `NSDocumentController.newDocument(_:)` is the standard action for Cmd+N. The default implementation creates a new instance of the document class and calls `makeWindowControllers()`. Override `NSDocumentController.openUntitledDocumentAndDisplay(_:)` in `DocumentController` to assign the untitled display name from the monotonic counter. Alternatively, override `MarkdownDocument.displayName` to return the computed untitled name.
- **State ownership:** The untitled counter is on `DocumentController`. The display name is a computed property on `MarkdownDocument` that checks: if `fileURL` is non-nil, return the filename; if nil, return the assigned untitled name.
- **Watch out for:** NSDocument-based apps open a new untitled document on launch automatically (via `NSDocumentController.openUntitledDocumentAndDisplay(true)`). This is the correct behavior per the Design Direction. Do NOT suppress it. Ensure the untitled numbering handles the automatic launch document correctly (it should be "Untitled", the first one).
- **NOT in scope:** File open (T-005.2), save (T-005.3), or close (T-005.4).

#### T-005.2 Architectural Hints

- **Module placement:** `App/DocumentController.swift` (extend with open logic). Override `NSDocumentController.openDocument(_:)` or customize the `NSOpenPanel` configuration via `beginOpenPanel(_:forTypes:completionHandler:)`.
- **Pattern:** Override `DocumentController.beginOpenPanel(_:forTypes:completionHandler:)` to configure the open panel: `panel.allowsMultipleSelection = true`, `panel.allowedContentTypes` set to the UTIs for markdown and text files. The duplicate detection (already-open file) is partially handled by `NSDocumentController` -- it calls `document(for:)` to check if a URL is already open. If a document is found, it activates that document's window. Verify this works with native tabs (the existing tab should become selected, not a new window opened).
- **File size checks:** Override `MarkdownDocument.read(from:ofType:)` to check the file size before reading. If the file is > 50MB, throw an error. If > 10MB, this is harder -- you cannot show a dialog from within `read(from:ofType:)` because it is called during document opening. Instead, override `DocumentController.openDocument(withContentsOf:display:completionHandler:)` to check file size BEFORE calling through to super. Show the warning/refusal alert there.
- **UTF-8 validation:** In `MarkdownDocument.read(from:ofType:)`, attempt `String(data: data, encoding: .utf8)`. If this returns `nil`, throw a custom error: `NSError(domain: "MdEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "This file does not appear to be a UTF-8 text file and cannot be opened."])`. NSDocument will display this error to the user automatically.
- **Recent files:** NSDocumentController manages the recent files list automatically. Every document opened via the standard flow is added. Override `noteNewRecentDocumentURL(_:)` if custom behavior is needed, but it should not be.
- **Watch out for:** When opening multiple files from the open panel, they should all open in tabs within the same window. This depends on `NSWindow.tabbingMode = .preferred` being set correctly (T-001.2). If files open in separate windows instead of tabs, the issue is in the window controller configuration, not in the open logic.
- **NOT in scope:** Open Folder (US-007) is a separate story.

#### T-005.3 Architectural Hints

- **Module placement:** `Document/MarkdownDocument.swift` (extend). Save and Save As are built into `NSDocument`.
- **Pattern:** Cmd+S triggers `NSDocument.save(_:)` through the responder chain. If the document has a `fileURL`, this calls `data(ofType:)` and writes to the file. If untitled, NSDocument automatically presents `NSSavePanel` (Save As behavior). Cmd+Shift+S triggers `NSDocument.saveAs(_:)`. The `data(ofType:)` override returns `content.data(using: .utf8)!`. The `NSSavePanel` configuration (allowed file types, default filename) is set via `NSDocument.prepareSavePanel(_:)`.
- **Save All:** This is not a built-in NSDocument action. Implement it as a custom action on the `DocumentController` or `AppDelegate`. Iterate `NSDocumentController.shared.documents`, check `isDocumentEdited`, and call `save(nil)` on each dirty document. For untitled documents, `save(nil)` will trigger the Save As panel.
- **Watch out for:** `NSDocument.autosavesInPlace = true` means the system will auto-save periodically. `Cmd+S` forces an immediate save. The `lastSavedContent` property mentioned in the FEATURE_SPEC is not needed when using NSDocument -- NSDocument tracks its own dirty state via `isDocumentEdited`. The engineer can remove `lastSavedContent` from the model if relying fully on NSDocument's change count mechanism. However, if the engineer wants explicit dirty tracking (e.g., for the computed `isDirty` property), they can keep it and update it in the save completion callback.
- **NOT in scope:** Close Tab (T-005.4), Export (US-011).

#### T-005.4 Architectural Hints

- **Module placement:** `Document/MarkdownDocument.swift` and `App/DocumentController.swift`.
- **Pattern:** Cmd+W triggers `NSWindow.performClose(_:)`, which asks the document if it can close (`NSDocument.canClose(withDelegate:shouldClose:contextInfo:)`). NSDocument handles the dirty-document save prompt automatically ("Save" / "Don't Save" / "Cancel") -- do NOT reimplement this dialog manually. The built-in behavior is correct and matches macOS conventions.
- **Last-tab-closed behavior:** When the last tab closes, the window itself closes (standard macOS behavior). The `DocumentController` must detect this (via `removeDocument(_:)` or window delegate `windowWillClose(_:)`) and open a new blank document. Use `DispatchQueue.main.async` to open the new document AFTER the close completes, to avoid re-entrancy.
- **Close All:** Implement as a custom menu action that iterates the window's tabs and closes each one. NSDocument handles the save prompts for each dirty document. Alternatively, call `NSDocumentController.closeAllDocuments(withDelegate:didCloseAll:contextInfo:)` which handles the flow.
- **Tab activation after close:** When a tab is closed, the native tab bar automatically activates an adjacent tab. The "next to the right, or left if none" behavior is the macOS default. Verify this, but do not implement custom tab activation logic.
- **Watch out for:** When implementing "close last tab -> open new document", beware of the edge case where the user closes all tabs via Close All. Each close triggers the "last tab" check. Debounce or guard so only one new blank document is created, not one per closed tab. Use a flag like `isClosingAll` to suppress the new-document behavior until the Close All operation completes.
- **NOT in scope:** Tab management details (US-006), sidebar (US-007).

---

### US-006: Tab Management

**As a** writer, **I want** to work with multiple documents in tabs, **so that** I can switch between documents quickly and keep my workspace organized.

**Architectural Guidance:**

Tab management is largely free when using `NSWindow.tabbingMode = .preferred` with `NSDocument`-based architecture. Each document creates a window controller, and the system merges windows into tabs automatically. The engineer's work here is ensuring per-tab state preservation (cursor position, scroll offset, view mode) and customizing tab display names.

- **Framework:** AppKit (native `NSWindow` document tabs). No custom tab bar implementation.
- **Pattern:** Native document tabs. Each `MarkdownDocument` creates a `MainWindowController` via `makeWindowControllers()`. The system's tab bar handles rendering, reordering, drag-to-new-window, and merge-all-windows.
- **State ownership:** Per-document state (cursor position, scroll offset, view mode) lives on the `MarkdownDocument` instance. When a tab becomes active, the window controller reads this state and restores it in the editor. When a tab loses focus, the window controller saves the current state back to the document.
- **Integration points:** Tab display names are affected by the filename (US-005) and the duplicate-name disambiguation logic. Tab state preservation is needed by the editor (US-002) and the preview (US-004).

**Acceptance Criteria:**
- [ ] Multiple documents open as native macOS document tabs (using `NSWindow.tabbingMode`)
- [ ] Each tab shows the filename (no extension for `.md` files); if two files share a name, the parent folder is appended in parentheses
- [ ] The unsaved-changes indicator (dot in close button) uses native NSDocument behavior
- [ ] Tabs are reorderable via drag-and-drop
- [ ] Tabs can be dragged to a new window and merged back (native behavior)
- [ ] Switching tabs preserves cursor position and scroll position in each document
- [ ] Tab navigation: Ctrl+Tab / Ctrl+Shift+Tab for next/previous; Ctrl+1-9 for direct tab access
- [ ] A file can be open in multiple windows simultaneously; changes are independent (no cross-window sync)

**Tasks:**

| Task ID  | Description | Agent | Depends On | Status |
|----------|-------------|-------|------------|--------|
| T-006.1  | Configure native macOS document tabs. Set `NSWindow.tabbingMode = .preferred` (done in T-001.2). Ensure `NSDocumentController` creates new documents in tabs of the existing window by default (per the "New window behavior" preference, which defaults to "New Tab"). Implement tab display name logic: show filename without `.md` extension; if two open documents share a filename, append the parent folder in parentheses (e.g., `README (project)` and `README (docs)`). For untitled documents, show "Untitled", "Untitled 2", etc. Handle extremely long filenames with ellipsis truncation, full name in tooltip. Reference: Design Direction section 6, FEATURE_SPEC section 4.2, edge case (long filenames). | principal-frontend-engineer | T-001.2, T-001.3 | TODO |
| T-006.2  | Implement per-document state preservation when switching tabs. Each `MarkdownDocument` must store: cursor position (selection range), scroll offset, and view mode (edit/preview). When the user switches away from a tab, save these values. When switching back, restore cursor position, scroll offset, and mode. This ensures the user picks up exactly where they left off in each document. Reference: FEATURE_SPEC acceptance criteria (switching tabs preserves cursor and scroll). | principal-frontend-engineer | T-002.1, T-004.1 | TODO |
| T-006.3  | Implement tab keyboard navigation. Ctrl+Tab moves to the next tab, Ctrl+Shift+Tab to the previous tab (these may be provided by the native tab bar). Ctrl+1 through Ctrl+9 switches directly to the Nth tab. Note: Cmd+1-6 are reserved for heading levels (FEATURE_SPEC section 9, conflict resolution), so tab-by-number uses Ctrl modifier. Reference: FEATURE_SPEC section 9 (Tabs shortcuts, conflict resolution). | principal-frontend-engineer | T-006.1 | TODO |

#### T-006.1 Architectural Hints

- **Module placement:** `Document/MarkdownDocument.swift` (extend `displayName` computed property) and `App/DocumentController.swift` (extend for disambiguation logic).
- **Pattern:** Override `MarkdownDocument.displayName` to return the filename without the `.md` extension. For disambiguation: query `NSDocumentController.shared.documents` to find other open documents with the same filename. If duplicates exist, append the parent folder name in parentheses. This computation must be updated whenever a document is opened or closed (any document, because adding or removing a file with a duplicate name affects the display of the other file).
- **Data flow:** `NSDocument.displayName` is read by the window's tab bar to render the tab title. Overriding it is sufficient -- the system picks up the custom display name. Call `window?.tab.title = displayName` if the tab title does not update automatically, or post `NSDocument.didChangeDisplayNameNotification` (available via KVO on the `displayName` property).
- **Watch out for:** The disambiguation logic needs to be reactive. When a file named `README.md` is opened, check all other open documents for the same base name. If a match is found, BOTH documents need their display names updated (one becomes `README (docs)` and the other becomes `README (project)`). When one of the duplicates is closed, the remaining one reverts to just `README`. This requires observing document open/close events and refreshing display names. Use `NSNotificationCenter` with `NSDocumentController.didOpenDocumentNotification` or similar.
- **NOT in scope:** Tab state preservation (T-006.2), keyboard navigation (T-006.3).

#### T-006.2 Architectural Hints

- **Module placement:** `Document/MarkdownDocument.swift` (add transient state properties). `WindowChrome/MainWindowController.swift` or `WindowChrome/ContentViewController.swift` (implement save/restore logic).
- **Pattern:** Add transient (not serialized) properties to `MarkdownDocument`: `var savedSelectionRange: NSRange = NSRange(location: 0, length: 0)`, `var savedScrollPosition: NSPoint = .zero`. These are NOT included in `data(ofType:)` -- they are in-memory only. When the window controller detects that its tab is becoming inactive (via `NSWindow.didResignKeyNotification` or the `NSWindowDelegate.windowDidResignKey(_:)` callback), read the current cursor position from the text view (`textView.selectedRange()`) and scroll position from the scroll view (`scrollView.contentView.bounds.origin`) and store them on the document. When the tab becomes active again (`windowDidBecomeKey`), restore both.
- **State ownership:** The state lives on `MarkdownDocument` because the document persists across tab switches. The view controllers are potentially reused or re-created, so they cannot hold this state.
- **Watch out for:** With native document tabs, each tab is a separate `NSWindow`. Tab switching triggers `windowDidResignKey` on the old window and `windowDidBecomeKey` on the new window. However, the view controllers may be the SAME objects if the window controller reuses them (which it should not -- each document should have its own window controller and view controllers). Verify that each document tab has its own independent view controller hierarchy. If they share view controllers, state preservation becomes much more complex.
- **NOT in scope:** Tab keyboard navigation (T-006.3).

#### T-006.3 Architectural Hints

- **Module placement:** `Menus/MenuBuilder.swift` or `WindowChrome/MainWindowController.swift`.
- **Pattern:** Ctrl+Tab and Ctrl+Shift+Tab for next/previous tab are provided by the native tab bar automatically when using `NSWindow.tabbingMode`. Verify they work and do NOT implement custom handling unless they do not.
- **Ctrl+1 through Ctrl+9 for direct tab access:** These are NOT provided by the system. Implement as menu items in the Window menu with key equivalents using the `Control` modifier: `keyEquivalent = "1"`, `keyEquivalentModifierMask = [.control]`. The action handler must find the Nth tab in the window's `tabbedWindows` array and select it via `tab.makeKeyAndOrderFront(nil)` or `window.selectTabViewItem(at:)`.
- **Watch out for:** `NSWindow.tabbedWindows` returns the array of windows in the tab group. The ordering matches the visual tab order. Index 0 is the leftmost tab. Verify that `tabbedWindows` is non-nil (it is nil if the window is not in a tab group). Also: Ctrl+1-9 is non-standard for macOS. The spec acknowledges this as a compromise to avoid conflicting with Cmd+1-6 (headings). Document this in the Help menu and in keyboard shortcut tooltips.
- **NOT in scope:** Tab display names (T-006.1) or state preservation (T-006.2).

---

### US-007: Sidebar and Open Folder

**As a** writer, **I want** to open a folder and browse its markdown files in a sidebar, **so that** I can navigate a documentation project or set of notes without opening each file manually.

**Architectural Guidance:**

The sidebar is implemented as one pane of an `NSSplitViewController` that wraps the main content area. This is the standard macOS sidebar pattern used by Finder, Mail, Notes, and other Apple apps. The sidebar pane uses `NSVisualEffectView` for the standard vibrancy/translucency treatment. The file tree is displayed using `NSOutlineView` (AppKit) rather than a SwiftUI `List` -- `NSOutlineView` provides better performance for large file trees, standard disclosure triangle behavior, and native sidebar selection styling.

- **Framework:** AppKit (`NSSplitViewController`, `NSOutlineView`, `NSVisualEffectView`, `NSOpenPanel`). Directory scanning uses `FileManager`.
- **Pattern:** `MainSplitViewController` (NSSplitViewController subclass) has two split view items: the sidebar and the content area. The sidebar pane contains a `SidebarViewController` which hosts an `NSOutlineView`. The content pane contains the `ContentViewController` from US-004. When no folder is open, the split view hides the sidebar pane entirely (not just collapses it -- the sidebar split view item is removed or has `isCollapsed = true`).
- **Data flow:** Open Folder scans the directory and builds a tree model (`FolderNode` struct with name, URL, children). This model is the data source for the `NSOutlineView`. When the user clicks a file in the sidebar, the `SidebarViewController` delegates to the `DocumentController` to open (or switch to) that file.
- **Integration points:** The sidebar toggle button in the toolbar (US-003) calls `NSSplitViewController.toggleSidebar(_:)`. The sidebar interacts with the document/tab system (US-005, US-006) by opening files. The sidebar should highlight the file corresponding to the currently active tab.

**Acceptance Criteria:**
- [ ] Cmd+Shift+O opens `NSOpenPanel` in directory-selection mode
- [ ] The selected folder's file tree appears in a sidebar on the left side of the window
- [ ] The sidebar uses `NSSplitViewController` with `NSVisualEffectView` sidebar material
- [ ] Default sidebar width is 220pt; it is resizable and collapsible via toolbar button or Cmd+1 (using Ctrl+1 to avoid heading shortcut conflict -- see dependency notes)
- [ ] The sidebar shows only `.md`, `.markdown`, `.txt`, `.text` files by default; a preference can toggle "show all files"
- [ ] Files display their name only (no `.md` extension; other extensions shown)
- [ ] Folders are collapsible with disclosure triangles
- [ ] Single click on a file opens it in a tab (or switches to existing tab if already open)
- [ ] The currently-open file is highlighted with system accent color at low opacity
- [ ] Hidden files/directories (starting with `.`) are skipped
- [ ] Excluded directories are skipped: `node_modules`, `.git`, `build`, `dist`, `.venv`, `__pycache__`
- [ ] If the folder contains more than 50 markdown files, a confirmation dialog appears before opening
- [ ] If the folder contains zero markdown files, an informational alert is shown
- [ ] When no folder is open, the sidebar does not exist (no empty sidebar panel)

**Tasks:**

| Task ID  | Description | Agent | Depends On | Status |
|----------|-------------|-------|------------|--------|
| T-007.1  | Build the sidebar using `NSSplitViewController` with the main content as one pane and the sidebar as the other. The sidebar pane uses `NSVisualEffectView` with `.sidebar` material. Default width: 220pt. The sidebar is collapsible/expandable via the toolbar sidebar toggle button and a keyboard shortcut. When no folder is loaded, the sidebar does not appear (the split view controller shows only the content pane). Reference: Design Direction section 7. | principal-frontend-engineer | T-001.2, T-003.1 | TODO |
| T-007.2  | Implement Open Folder (Cmd+Shift+O). Present `NSOpenPanel` in directory mode (`canChooseDirectories = true`, `canChooseFiles = false`). Recursively scan the selected directory for files with extensions `.md`, `.markdown`, `.mdown`, `.mkd` (not `.txt` in folder scan). Skip hidden files/directories (those starting with `.`). Skip excluded directories: `node_modules`, `.git`, `build`, `dist`, `.venv`, `__pycache__`. If zero markdown files found, show informational alert. If more than 50 files found, show confirmation dialog ("Open All" / "Cancel"). Build a tree model of the folder structure and populate the sidebar. Files are sorted alphabetically by relative path. Reference: FEATURE_SPEC section 6.3, edge cases. | principal-frontend-engineer | T-007.1 | TODO |
| T-007.3  | Implement the sidebar file tree view. Use `NSOutlineView` (or SwiftUI `List` with disclosure groups if wrapping in SwiftUI) to display the folder tree. Files show name only (hide `.md` extension; show other extensions). Folders show disclosure triangles and are collapsible. Single-click a file to open it in a tab (or switch to existing tab if already open -- check by resolved file URL). The currently open file is highlighted with system accent color at low opacity, matching native sidebar selection. Reference: Design Direction section 7, FEATURE_SPEC section 6.3. | principal-frontend-engineer | T-007.2 | TODO |

#### T-007.1 Architectural Hints

- **Module placement:** `WindowChrome/MainSplitViewController.swift`. This replaces the direct content view controller assignment from T-001.2. The `MainWindowController.contentViewController` is now the `MainSplitViewController`, which in turn contains the sidebar pane and the content pane.
- **Pattern:** Subclass `NSSplitViewController`. Create two `NSSplitViewItem` instances: one with `behavior = .sidebar` for the sidebar pane, and one with `behavior = .default` for the content pane. The sidebar item has `minimumThickness = 180`, `maximumThickness = 400`, `preferredThicknessFraction = 0.2`, `canCollapse = true`, and `isCollapsed = true` initially (sidebar hidden until a folder is opened). The sidebar pane's view controller wraps an `NSVisualEffectView` with `material = .sidebar` and `blendingMode = .behindWindow`.
- **Toggle mechanism:** Wire the toolbar sidebar toggle button (from T-003.1) to `NSSplitViewController.toggleSidebar(_:)`. This is a built-in action that animates the sidebar open/closed. For the keyboard shortcut, add a menu item in the View menu with key equivalent. The Design Direction suggests Cmd+1, but that conflicts with Heading 1. Use Cmd+Shift+1 or Cmd+\ (backslash), which is a common sidebar toggle in macOS apps. The exact shortcut should be decided in coordination with the heading shortcuts.
- **Watch out for:** The `NSSplitViewController` must be the `contentViewController` of the window. But each document has its own window controller. This means each document window gets its own split view controller instance. The sidebar state (folder tree, expanded/collapsed nodes) is per-window, not shared across windows. This is correct behavior -- each window is independent. Also: when the sidebar is collapsed (no folder open), the split view divider should not be visible. Set `splitViewItem.isCollapsed = true` and verify that the divider line disappears completely.
- **NOT in scope:** File tree content (T-007.2, T-007.3). This task builds the split view shell only.

#### T-007.2 Architectural Hints

- **Module placement:** `Sidebar/FolderScanner.swift` for the directory scanning logic. `App/DocumentController.swift` or `WindowChrome/MainSplitViewController.swift` for the Open Folder action.
- **Pattern:** The folder scanning is a pure function: `static func scanFolder(at url: URL) -> FolderNode`. It returns a tree structure representing the folder hierarchy. Define a `FolderNode` struct: `struct FolderNode { let name: String; let url: URL; let isFolder: Bool; let children: [FolderNode] }`. The scan function uses `FileManager.default.contentsOfDirectory(at:includingPropertiesForKeys:options:)` recursively.
- **Filtering logic:** Skip entries where `url.lastPathComponent.hasPrefix(".")` (hidden files/folders). Skip folder names in the exclusion set: `["node_modules", ".git", "build", "dist", ".venv", "__pycache__"]`. Include only files with extensions in `["md", "markdown", "mdown", "mkd"]`. Sort children alphabetically with folders first, then files.
- **Async scanning:** For large directories, the recursive scan could take noticeable time. Run it on a background thread using `Task { ... }` and update the UI on the main thread. Show a progress indicator in the sidebar while scanning. For most documentation projects (< 1000 files), the scan will complete in under 100ms and no indicator is needed.
- **50-file threshold:** After scanning, count the total markdown files in the tree. If > 50, show an `NSAlert` with `"This folder contains N Markdown files. Opening all of them may use significant memory. Continue?"` with "Open All" and "Cancel" buttons. Note: the Design Direction says the sidebar shows the file tree -- it does NOT open all files as tabs. Only the sidebar tree is populated. Individual files are opened as tabs when clicked in the sidebar. So the 50-file warning from the FEATURE_SPEC (which was about opening all files as tabs) may be less relevant here. Clarify: the warning should fire if the folder contains > 50 markdown files, as a heads-up about the sidebar size, but the files are NOT automatically opened as tabs.
- **Watch out for:** Symlink loops. Use `FileManager.default.contentsOfDirectory(at:includingPropertiesForKeys:[.isSymbolicLinkKey, .isDirectoryKey])` and skip symlinks that point to ancestor directories to avoid infinite recursion. Also: large repositories (e.g., a monorepo with thousands of `.md` files scattered across nested directories) could produce an extremely large tree. Consider a depth limit (e.g., 10 levels) or lazy loading of deep subdirectories.
- **NOT in scope:** The outline view rendering (T-007.3). This task produces the data model; the view is next.

#### T-007.3 Architectural Hints

- **Module placement:** `Sidebar/SidebarViewController.swift` (hosts the NSOutlineView). `Sidebar/FileTreeDataSource.swift` (conforms to `NSOutlineViewDataSource` and `NSOutlineViewDelegate`).
- **Pattern:** `NSOutlineView` with `style = .sourceList` (provides the standard sidebar appearance on macOS). The `FileTreeDataSource` implements `outlineView(_:numberOfChildrenOfItem:)`, `outlineView(_:child:ofItem:)`, `outlineView(_:isItemExpandable:)`, and `outlineView(_:viewFor:item:)`. Each item is a `FolderNode`. The cell view shows the file/folder name using `NSTextField` with appropriate icon (folder icon from `NSImage(named: NSImage.folderName)` for folders, document icon for files).
- **File name display:** For `.md` files, hide the extension: show `README` instead of `README.md`. For other supported extensions (`.markdown`, `.txt`), show the extension. Use `url.deletingPathExtension().lastPathComponent` for `.md` files.
- **Single-click to open:** Set `outlineView.action = #selector(outlineViewClicked(_:))`. In the action handler, get the clicked row, get the corresponding `FolderNode`, and if it is a file (not a folder), open it via `NSDocumentController.shared.openDocument(withContentsOf: node.url, display: true)`. Check first if the file is already open (`NSDocumentController.shared.document(for: node.url)`) and if so, activate that document's window/tab instead.
- **Current file highlighting:** Observe which document is currently active (via `NSWindow.didBecomeMainNotification` or `NSDocument.didChangeCurrentDocumentNotification`). When the active document changes, find its URL in the sidebar tree and select the corresponding row in the outline view. Use `outlineView.selectRowIndexes(...)` with the native selection styling.
- **Watch out for:** `NSOutlineView` with `style = .sourceList` provides its own selection highlighting using the system accent color. Do NOT add custom selection drawing -- the source list style handles it. Also: the sidebar must update when files are opened or closed via other means (Cmd+O, Cmd+N) -- the active file highlight needs to track the active tab. This requires observing document focus changes globally.
- **NOT in scope:** File operations from the sidebar (delete, rename, create new file). These are not in the v1 spec.

---

### US-008: Menu Bar

**As a** writer, **I want** a complete macOS menu bar with all app actions, **so that** I can discover and access every feature through standard Mac conventions.

**Architectural Guidance:**

The menu bar is the canonical location for all app actions and keyboard shortcuts on macOS. Every formatting action, file operation, and view toggle must have a corresponding menu item. This is not optional -- it is how macOS discovers and validates keyboard shortcuts. Menu items participate in the responder chain, which means they automatically find the correct target (the active document, the active text view, etc.) without manual wiring.

- **Framework:** AppKit (`NSMenu`, `NSMenuItem`). The menu can be built programmatically in `AppDelegate` or via a `MainMenu.xib` / `Main.storyboard` file. For this project, a `MainMenu.xib` is recommended because it provides a visual overview of the complete menu structure and is easier to maintain than programmatic menu construction.
- **Pattern:** Each menu item has an `action` selector and a `keyEquivalent`. The actions are sent through the responder chain. For formatting actions, the responder is the `NSTextView` (via `FormattingCommands` methods exposed as `@objc` actions on the text view or its delegate). For document actions (save, close), the responder is the `NSDocument` or `NSDocumentController`. For view actions (toggle mode, sidebar), the responder is the appropriate view controller.
- **Menu validation:** Implement `validateMenuItem(_:)` (or the modern `validateUserInterfaceItem(_:)`) on the appropriate responder chain objects. Formatting menu items should be disabled when in Preview mode. Save should be disabled when the document is not dirty. Reveal in Finder should be disabled for untitled documents. The responder chain handles this naturally -- each object validates the menu items it owns.
- **Integration points:** The menu bar wires together ALL previous stories. Every action implemented in US-002 through US-007 gets a menu item here. This is the integration story.

**Acceptance Criteria:**
- [ ] All menus from the spec are implemented: App (MdEditor), File, Edit, Format, View, Window, Help
- [ ] File menu includes: New, Open, Open Folder, Open Recent, Close Tab, Close All, Save, Save As, Save All, Export as HTML, Export as PDF
- [ ] Edit menu includes: Undo, Redo, Cut, Copy, Paste, Paste and Match Style, Select All, Find submenu
- [ ] Format menu includes all formatting actions with their keyboard shortcuts
- [ ] View menu includes: Editing Mode, Preview Mode, Show Line Numbers (toggle), Toggle Word Wrap, font size controls, Full Screen
- [ ] Window menu includes: Minimize, Zoom, tab navigation, Move Tab to New Window, Merge All Windows
- [ ] Help menu includes: MdEditor Help and Markdown Syntax Guide
- [ ] All menu items show their keyboard shortcuts
- [ ] Menu items are enabled/disabled appropriately (e.g., formatting disabled in Preview mode, Save disabled for clean documents)

**Tasks:**

| Task ID  | Description | Agent | Depends On | Status |
|----------|-------------|-------|------------|--------|
| T-008.1  | Build the complete menu bar structure. Implement all menus as specified in FEATURE_SPEC section 5 (sections 5.1 through 5.7). Each menu item should be wired to its corresponding action (many will be wired to existing actions from earlier tasks). Keyboard shortcuts must be assigned per FEATURE_SPEC section 9. Menu items must be enabled/disabled contextually: formatting items disabled in Preview mode; Save dimmed when document is clean; Close Tab dimmed when no document is open (though this should not happen per Design Direction); Reveal in Finder / Copy File Path only for saved documents. Reference: FEATURE_SPEC section 5 (all subsections), section 9. | principal-frontend-engineer | T-003.2, T-003.3, T-004.1, T-005.1, T-005.2, T-005.3, T-005.4 | TODO |
| T-008.2  | Implement the Find submenu. Wire Cmd+F to open the standard macOS find bar (NSTextView's built-in find bar via `performFindPanelAction`). Wire Cmd+Option+F for find and replace. Cmd+G for find next, Cmd+Shift+G for find previous, Cmd+E for "Use Selection for Find." These should leverage the native NSTextView find panel capabilities. Reference: FEATURE_SPEC section 5.3. | principal-frontend-engineer | T-002.1 | TODO |
| T-008.3  | Implement the View menu font size controls. Cmd+= increases editor font size, Cmd+- decreases it, Cmd+0 resets to the default (14pt). The font size change should apply immediately to the active editor and persist as the current session preference. Wire these to the same font size preference used in Preferences. Reference: FEATURE_SPEC section 5.5, section 8.1. | principal-frontend-engineer | T-002.1 | TODO |
| T-008.4  | Implement the Markdown Syntax Guide in the Help menu. When selected, open a bundled `.md` reference file (include a comprehensive markdown syntax guide as a bundled resource) in a new tab rendered in Preview mode. This lets the user reference markdown syntax without leaving the app. Reference: FEATURE_SPEC section 5.7. | principal-frontend-engineer | T-004.2, T-005.1 | TODO |

#### T-008.1 Architectural Hints

- **Module placement:** `Menus/MenuBuilder.swift` if building programmatically, or `Resources/MainMenu.xib` if using Interface Builder. If using XIB, create actions and outlets in `AppDelegate` or in a dedicated `MenuController` class. A hybrid approach works well: define the menu structure in XIB for visual clarity, but wire complex actions programmatically in `applicationDidFinishLaunching(_:)`.
- **Pattern:** Standard macOS menu bar architecture. The `NSApplication.mainMenu` is set from the XIB or built programmatically. Each `NSMenuItem` has an `action` selector and optional `target`. For responder-chain actions (most of them), set `target = nil` -- this lets the system find the first responder that handles the selector. For app-level actions (Preferences, Quit), set `target = NSApp` or the `AppDelegate`.
- **Key menu structure:** (a) MdEditor menu: About, Preferences (Cmd+,), Quit. These are standard and mostly automatic. (b) File menu: New (Cmd+N, action `newDocument:`), Open (Cmd+O, action `openDocument:`), Save (Cmd+S, action `saveDocument:`), Save As (Cmd+Shift+S, action `saveDocumentAs:`). These are standard NSDocument actions. (c) Edit menu: standard cut/copy/paste/undo are provided by the system. (d) Format menu: custom actions calling `FormattingCommands` methods. (e) View menu: mode toggle, sidebar toggle, font size, line numbers, full screen. (f) Window menu: standard items plus tab navigation. (g) Help menu.
- **Menu validation:** Implement `validateMenuItem(_:)` on: `EditorViewController` (for formatting items -- disabled in preview mode), `MarkdownDocument` (for save/close items), and `MainSplitViewController` (for sidebar toggle). Return `false` to disable, `true` to enable. For toggle items (line numbers, word wrap), also set `menuItem.state = .on` or `.off`.
- **Watch out for:** Cmd+E conflicts between "Inline Code" (FEATURE_SPEC) and "Use Selection for Find" (standard macOS). The spec assigns Cmd+E to Inline Code. The "Use Selection for Find" must be reassigned or removed. Reassign it to Cmd+Shift+E -- but that conflicts with "Editing Mode". This chain of conflicts needs resolution. Recommendation: keep Cmd+E for "Use Selection for Find" (standard macOS behavior) and use Cmd+Shift+` for Inline Code instead. Flag this for product owner decision.
- **NOT in scope:** The actual action implementations (those are in prior stories). This task builds the menu structure and wires it to existing actions.

#### T-008.2 Architectural Hints

- **Module placement:** No new files needed. The find functionality is built into `NSTextView`.
- **Pattern:** NSTextView has built-in find bar support. To enable it: set `textView.isIncrementalSearchingEnabled = true` and `textView.usesFindBar = true`. Menu items with the standard find actions (`performFindPanelAction:` with tags for Find, Find and Replace, Find Next, Find Previous, Use Selection for Find) are handled automatically by the text view's responder chain. Create menu items with `action = #selector(NSTextView.performFindPanelAction(_:))` and set the `tag` property to the appropriate `NSTextFinder.Action` raw value.
- **Watch out for:** The find bar appears INSIDE the scroll view, pushing the text content down. This is standard macOS behavior. Ensure the top padding calculation (T-002.3) does not break when the find bar appears. Also: in Preview mode, Cmd+F should invoke the WKWebView's find functionality, not the NSTextView's. Implement `performFindPanelAction(_:)` on the `ContentViewController` or `PreviewViewController` to handle this case by calling `webView.evaluateJavaScript("window.find('...')")` or using WKWebView's `WKFindInteraction` (macOS 14+).
- **NOT in scope:** Custom find UI. Use the system-provided find bar.

#### T-008.3 Architectural Hints

- **Module placement:** `Preferences/AppPreferences.swift` (extend with font size property). Action handlers in `EditorViewController` or `AppDelegate`.
- **Pattern:** The font size is stored in `AppPreferences.editorFontSize` (backed by `UserDefaults`). Cmd+= increments it by 1pt, Cmd+- decrements by 1pt (clamped to 10-32pt range), Cmd+0 resets to 14pt. When the font size changes, all open editor views must update. Observe `AppPreferences.editorFontSize` in each `EditorViewController` and re-apply the font to the text view when it changes.
- **Data flow:** Menu item action -> update `AppPreferences.editorFontSize` -> observation triggers all open editors to update their font. This is a broadcast pattern: one source (preferences) pushes to many consumers (editor views).
- **Watch out for:** Changing the font size requires updating the `NSTextStorage` attributes for the entire document (because heading sizes are relative to the base font size). After changing the font size, trigger a full re-highlighting pass (T-002.2) to recompute all heading sizes. Also: Cmd+= and Cmd+- may conflict with standard macOS zoom shortcuts. In a text editor, these are conventionally font size, not window zoom. Verify no conflict with the system.
- **NOT in scope:** Full preferences window (US-010). This task only implements the three font size menu actions.

#### T-008.4 Architectural Hints

- **Module placement:** `Resources/MarkdownSyntaxGuide.md` (bundled resource). Action handler in `AppDelegate` or a Help menu controller.
- **Pattern:** When the menu item is selected, load the bundled markdown file from `Bundle.main.url(forResource: "MarkdownSyntaxGuide", withExtension: "md")`. Create a new `MarkdownDocument` with this file's content, set its `viewMode = .preview`, and present it in a new tab. The document should be read-only (or rather, the user can edit it, but it reverts on next open since it is a bundled resource). Alternatively, open it with a temporary file URL so it cannot be saved over the bundle resource.
- **Watch out for:** The bundled `.md` file is inside the app bundle, which is read-only. If the user edits the syntax guide and tries to save, `NSDocument.save()` will fail because it cannot write to the bundle. Handle this gracefully: either open it as an untitled document (copy of the content, not linked to the bundle file) or set it as read-only. The cleanest approach is to open it as a new untitled document pre-populated with the guide content and set to preview mode.
- **NOT in scope:** Writing the content of the Markdown Syntax Guide itself. A comprehensive guide should cover headings, emphasis, links, images, lists, code, blockquotes, tables, task lists, and horizontal rules. This is a content task, not an engineering task -- but the engineer will need to create the file.

---

### US-009: Status Bar

**As a** writer, **I want** to see my cursor position, word count, and character count at a glance, **so that** I can track my progress and navigate my document.

**Architectural Guidance:**

The status bar is a thin strip at the bottom of the content area. It is a good candidate for SwiftUI because it is a simple, declarative, data-driven view with no complex AppKit interactions. Host a SwiftUI `StatusBarView` inside the content area using `NSHostingView`.

- **Framework:** SwiftUI hosted in AppKit via `NSHostingView`. This is the first place in the app where SwiftUI makes sense for new UI construction.
- **Pattern:** `StatusBarView` is a SwiftUI `View` that displays document metrics. It receives its data via an `@Observable` `DocumentMetrics` object that is updated by the `EditorViewController` whenever the cursor moves or text changes.
- **Data flow:** `EditorViewController` observes cursor movement (`NSTextView.didChangeSelectionNotification`) and text changes (`NSTextStorageDelegate`). On each event, it computes line number, column number, word count, and character count, and updates the `DocumentMetrics` object. The SwiftUI `StatusBarView` reacts to these changes automatically via observation.
- **Integration points:** The status bar changes its display based on `viewMode` (editing shows all four fields; preview shows only word/character count). It is placed at the bottom of the `ContentViewController`'s view, below the editor/preview area.

**Acceptance Criteria:**
- [ ] A slim status bar appears at the bottom of the window
- [ ] In editing mode, it shows: "Line X, Col Y", "N words", "N characters", "UTF-8"
- [ ] In preview mode, it shows only: "N words", "N characters"
- [ ] Counts update as the user types
- [ ] The status bar is visually subtle and does not compete with the content area

**Tasks:**

| Task ID  | Description | Agent | Depends On | Status |
|----------|-------------|-------|------------|--------|
| T-009.1  | Build the status bar view. A thin bar at the bottom of the window showing cursor position ("Line X, Col Y"), word count ("N words"), character count ("N characters"), and encoding ("UTF-8"). Use `NSColor.secondaryLabelColor` for text, small system font. In editing mode, show all four fields. In preview mode, show only word count and character count. Update cursor position on every cursor movement. Update word/character counts on every text change (debounce if needed for performance with large documents). Reference: FEATURE_SPEC section 4.6. | principal-frontend-engineer | T-002.1, T-004.1 | TODO |

#### T-009.1 Architectural Hints

- **Module placement:** `StatusBar/StatusBarView.swift` (SwiftUI view). `StatusBar/DocumentMetrics.swift` (`@Observable` class holding the computed metrics).
- **Pattern:** `DocumentMetrics` is an `@Observable` class with properties: `var line: Int = 1`, `var column: Int = 1`, `var wordCount: Int = 0`, `var characterCount: Int = 0`, `var isEditingMode: Bool = true`. The `StatusBarView` reads these properties and displays them in an `HStack` with `Spacer`s between the fields. Use `Font.system(size: 11)` and `Color(.secondaryLabelColor)` for styling.
- **View hierarchy:** The `StatusBarView` is embedded at the bottom of the `ContentViewController`'s view using `NSHostingView`. The content view controller's layout has the editor/preview filling the available space above, and the status bar pinned to the bottom with a fixed height of approximately 22pt. Use Auto Layout constraints: `statusBarHostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)`, `editorScrollView.bottomAnchor.constraint(equalTo: statusBarHostingView.topAnchor)`.
- **Data flow:** The `EditorViewController` owns the `DocumentMetrics` instance and updates it. Cursor position: in the `NSTextView.didChangeSelectionNotification` handler, compute line and column from the selection range. Word count and character count: update on text changes. For line/column computation, count newlines before the cursor position. For word count, use `NSString.enumerateSubstrings(in:options:.byWords)` or simply split by whitespace.
- **Debouncing:** For very large documents, word counting on every keystroke could be expensive. Debounce the word/character count update with a 100-200ms delay using `DispatchWorkItem` cancellation. Cursor position updates should NOT be debounced -- they must be instant.
- **Watch out for:** When switching between edit and preview mode, the `DocumentMetrics.isEditingMode` must update so the status bar hides cursor position in preview mode. Also: the status bar should not steal vertical space from the editor. Keep it as thin as possible (22pt max including top separator). Add a subtle `Divider()` at the top of the status bar to separate it from the content area.
- **NOT in scope:** Clicking on status bar fields to navigate (e.g., clicking "Line X" to jump to a line number). That is not in the v1 spec.

---

### US-010: Preferences

**As a** writer, **I want** to customize editor settings like font, font size, tab width, and preview appearance, **so that** the app fits my personal workflow.

**Architectural Guidance:**

The Preferences window is a standard macOS preferences panel. On macOS 14+, it can be built as a SwiftUI `Settings` scene if the app uses SwiftUI lifecycle, or as a standalone `NSWindowController` with `NSHostingView` content. Since this app uses AppKit lifecycle (`AppDelegate`), the preferences window is an `NSWindowController` hosting SwiftUI views for each tab.

- **Framework:** SwiftUI for the preferences UI (simple forms, toggles, steppers, pickers -- SwiftUI excels here). AppKit for the window management (`NSWindowController` or `NSWindow` with toolbar-style tabs).
- **Pattern:** `AppPreferences` is a singleton `@Observable` class that wraps `UserDefaults` via `@AppStorage` (or manual `UserDefaults.standard.register/observe`). All editor and preview views observe this object and react to changes immediately. The preferences window UI is three SwiftUI views (one per tab) that bind to `AppPreferences` properties.
- **Data flow:** Preferences UI -> `AppPreferences` properties -> `UserDefaults` (persistence) AND -> all open editors/previews (immediate update via observation). This is a one-to-many broadcast pattern. `AppPreferences` is the single source of truth for all configurable values.
- **Integration points:** `EditorViewController` reads font family, font size, tab width, line numbers, word wrap, spell check, and list continuation from `AppPreferences`. `PreviewViewController` reads preview font size and code block theme. `DocumentController` reads restore-tabs-on-launch and new-window-behavior. Changes to any preference take effect immediately in all open documents.

**Acceptance Criteria:**
- [ ] Preferences are accessible via Cmd+, or the MdEditor menu
- [ ] Editor tab: Font Family (dropdown: SF Mono, Menlo, Fira Code, Source Code Pro, System Monospaced), Font Size (stepper: 10-32pt, default 14), Tab Width (stepper: 2/4/8, default 4), Show Line Numbers (toggle, default off), Word Wrap (toggle, default on), Spell Check (toggle, default on), Auto-continue Lists (toggle, default on)
- [ ] Preview tab: Preview Font Size (stepper: 12-28pt, default 16), Code Block Theme (dropdown: Light/Dark/Auto, default Auto)
- [ ] General tab: Restore tabs on launch (toggle, default on), Auto-save interval (dropdown: Off/30s/1min/5min, default Off -- note: NSDocument auto-save is always active regardless; this controls additional periodic force-saves), Default file extension (dropdown: .md/.markdown, default .md), New window behavior (dropdown: New Tab/New Window, default New Tab)
- [ ] All preferences persist across launches via UserDefaults
- [ ] Changes take effect immediately in all open editors/previews

**Tasks:**

| Task ID  | Description | Agent | Depends On | Status |
|----------|-------------|-------|------------|--------|
| T-010.1  | Build the Preferences window with three tabs (Editor, Preview, General). Use a standard macOS preferences window style (toolbar with tab icons, or `NSTabView`). Implement all settings as specified in FEATURE_SPEC section 8. Persist all values to UserDefaults. Changes must take effect immediately: when the user changes the font, all open editor views update. When they change the preview font size, all open previews update. The Preferences window is opened via Cmd+, or the app menu. Reference: FEATURE_SPEC section 8 (all subsections), Design Direction Principle 5 (Preferences under app menu). | principal-frontend-engineer | T-002.1, T-004.2 | TODO |

#### T-010.1 Architectural Hints

- **Module placement:** `Preferences/AppPreferences.swift` for the observable preferences model. `Preferences/PreferencesWindowController.swift` for the window. `Preferences/EditorPreferencesView.swift`, `Preferences/PreviewPreferencesView.swift`, `Preferences/GeneralPreferencesView.swift` for the three SwiftUI tab views.
- **Pattern:** `AppPreferences` is a singleton class marked `@Observable` (using the Observation framework from macOS 14+). Each property has a getter/setter that reads from / writes to `UserDefaults.standard`. Register defaults in `AppDelegate.applicationWillFinishLaunching(_:)` via `UserDefaults.standard.register(defaults:)` with all default values (font family: "SF Mono", font size: 14, tab width: 4, etc.).
- **Preferences window style:** On macOS 14+, use an `NSWindow` with `NSToolbar` having segmented tab icons (a gear icon for Editor, an eye icon for Preview, a slider icon for General). Each toolbar tab switches the window's content view to the corresponding SwiftUI `NSHostingView`. The window should have `styleMask = [.titled, .closable]` (no resize, no minimize). Fixed width appropriate for the content, height adjusts per tab.
- **SwiftUI preference views:** Use `Form` with `Section` groupings. Each control binds directly to `AppPreferences.shared` properties. Example: `Picker("Font Family", selection: $preferences.editorFontFamily) { ... }`, `Stepper("Font Size: \(preferences.editorFontSize)", value: $preferences.editorFontSize, in: 10...32)`, `Toggle("Show Line Numbers", isOn: $preferences.showLineNumbers)`.
- **Immediate application of changes:** Since `AppPreferences` is `@Observable`, SwiftUI views observing it will update automatically. For AppKit views (`EditorViewController`, `PreviewViewController`), use a Combine publisher (via `NotificationCenter` observing `UserDefaults.didChangeNotification`) or manual KVO observation on the `UserDefaults` keys. When a preference changes, each open editor should reconfigure itself: update font, re-apply syntax highlighting (for font size changes), toggle line numbers, etc.
- **Watch out for:** Changing the font family requires re-creating the `NSFont` object and re-applying it to the text view's typing attributes AND re-running the syntax highlighter to update heading fonts. This can cause a visible flash as the text re-renders. Wrap the update in `NSAnimationContext.beginGrouping()` to suppress animation if needed. Also: the "Restore tabs on launch" preference interacts with `NSDocumentController`'s state restoration. When this is OFF, override `restoreWindow(withIdentifier:state:completionHandler:)` to return `false`.
- **NOT in scope:** Implementing the preferences-driven behavior changes (those are in prior stories -- font size in T-008.3, line numbers in T-002.4, etc.). This task builds the Preferences UI and the `AppPreferences` model. The earlier tasks should already be reading from `AppPreferences` when they are implemented.

---

### US-011: Export (HTML and PDF)

**As a** writer, **I want** to export my document as a standalone HTML file or PDF, **so that** I can share my writing in formats others can view without a markdown editor.

**Architectural Guidance:**

Export functionality reuses the markdown-to-HTML pipeline from the preview (T-004.2). The HTML exporter wraps the rendered HTML in a complete standalone document with CSS inlined. The PDF exporter loads the HTML into an offscreen `WKWebView` and uses its PDF generation API. Both present `NSSavePanel` for output file selection.

- **Framework:** AppKit (`NSSavePanel`) and WebKit (`WKWebView.createPDF`). Reuses `MarkdownRenderer` from US-004.
- **Pattern:** `HTMLExporter` and `PDFExporter` are utility classes in the `Export/` folder. They are stateless -- each export is a one-shot operation. They take a markdown `String` and a suggested filename, render the HTML, optionally generate PDF, present the save panel, and write the file.
- **Data flow:** Document content -> `MarkdownRenderer.renderHTML()` -> HTML string -> (for PDF: load into offscreen WKWebView -> `createPDF()` -> PDF data) -> `NSSavePanel` -> write to disk.
- **Integration points:** Export actions are triggered from the File menu (US-008). They operate on the active document's content. The CSS used for export is the same CSS used for preview (T-004.2), ensuring visual consistency.

**Acceptance Criteria:**
- [ ] File > Export as HTML renders the current markdown to a full standalone HTML document with inline CSS, presents `NSSavePanel` with default name `[document-name].html`, and writes the file
- [ ] File > Export as PDF renders the markdown to HTML, uses `WKWebView` PDF export to generate a PDF, presents `NSSavePanel` with default name `[document-name].pdf`, and writes the file
- [ ] Exported HTML uses the same styling as the preview view (same CSS, same code highlighting)
- [ ] Exported PDF is properly formatted and readable

**Tasks:**

| Task ID  | Description | Agent | Depends On | Status |
|----------|-------------|-------|------------|--------|
| T-011.1  | Implement Export as HTML. Render the active document's markdown content using the same markdown-to-HTML pipeline used for Preview (T-004.2). Wrap the HTML body in a full standalone HTML document including the preview CSS inlined in a `<style>` tag so the file is self-contained. Present `NSSavePanel` with default filename `[document-name].html`. Write the complete HTML file. Reference: FEATURE_SPEC section 6.7. | principal-frontend-engineer | T-004.2 | TODO |
| T-011.2  | Implement Export as PDF. Render the markdown to HTML (same pipeline as T-011.1). Load the HTML into a `WKWebView` (can be offscreen). Use `WKWebView`'s `createPDF(configuration:)` method to generate the PDF data. Present `NSSavePanel` with default filename `[document-name].pdf`. Write the PDF file. Reference: FEATURE_SPEC section 6.8. | principal-frontend-engineer | T-004.2 | TODO |

#### T-011.1 Architectural Hints

- **Module placement:** `Export/HTMLExporter.swift`.
- **Pattern:** `HTMLExporter` has a single method: `static func exportHTML(from markdownContent: String, documentName: String, in window: NSWindow)`. It calls `MarkdownRenderer.renderHTML(from: markdownContent)` to get the HTML body. It wraps this in a full HTML5 document: `<!DOCTYPE html><html><head><meta charset="utf-8"><title>...</title><style>...</style></head><body>...</body></html>`. The CSS is read from the bundled `preview.css` file and inlined in the `<style>` tag. The highlight.js code (if used for code blocks) is also inlined in a `<script>` tag so the exported file is fully self-contained.
- **Save panel:** Present `NSSavePanel` with `allowedContentTypes = [.html]` and `nameFieldStringValue = "\(documentName).html"`. On confirmation, write the HTML string as UTF-8 data to the selected URL.
- **Watch out for:** The exported HTML must look identical to the preview. This means using the same CSS. However, the preview CSS may reference system fonts via `-apple-system`, which will not work on non-Apple platforms. Consider adding fallback fonts in the exported CSS: `font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif`. Also: if the preview uses `@media (prefers-color-scheme: dark)` for dark mode, the exported HTML will respect the reader's system preference. This is correct behavior.
- **NOT in scope:** PDF export (T-011.2). They are independent.

#### T-011.2 Architectural Hints

- **Module placement:** `Export/PDFExporter.swift`.
- **Pattern:** `PDFExporter` creates an offscreen `WKWebView` (not added to any view hierarchy), loads the HTML string into it (using the same pipeline as T-011.1), waits for the `didFinish` navigation callback, then calls `webView.createPDF(configuration:completionHandler:)` to generate the PDF data. Present `NSSavePanel` with `allowedContentTypes = [.pdf]` and `nameFieldStringValue = "\(documentName).pdf"`. Write the PDF data to the selected URL.
- **Offscreen WKWebView:** Create it with a reasonable frame size (e.g., 800x1200) to approximate a printed page. The `WKPDFConfiguration` allows setting page margins (`rect` property). Set appropriate margins (e.g., 72pt = 1 inch on all sides) for a well-formatted PDF.
- **Async flow:** The entire export operation is asynchronous: load HTML -> wait for render -> generate PDF -> present save panel -> write file. Use Swift concurrency (`async/await`) with a continuation to bridge the WKWebView callback. The save panel also blocks with `panel.beginSheetModal(for:completionHandler:)` or use `await panel.begin()` on macOS 14+.
- **Watch out for:** The offscreen WKWebView must be retained for the duration of the export. Store it as a property on the `PDFExporter` or capture it strongly in the completion closure. If it is deallocated before `createPDF` completes, the callback will never fire. Also: dark mode. The exported PDF should use light-mode colors regardless of the system appearance, so that the PDF is readable when printed. Force light mode on the offscreen WKWebView by setting `appearance = NSAppearance(named: .aqua)` on the WKWebView or its hosting view, or inject CSS that forces light colors.
- **NOT in scope:** HTML export (T-011.1). Print support (explicitly deferred in Design Direction).

---

## Architectural Standards and Deviations

### Decision: AppKit-Primary, Not SwiftUI-Primary

The FEATURE_SPEC (section 3.1) lists SwiftUI as the "primary" UI framework with AppKit integration where needed. The architectural guidance reverses this: **AppKit is primary, SwiftUI is used where appropriate.** This is not a contradiction of the spec -- it is a refinement. The spec's intent is correct (use both), but the weight falls on AppKit because the core features (`NSTextView`, `NSToolbar`, `NSSplitViewController`, `NSWindow` document tabs, `NSDocument`) are all AppKit APIs with no SwiftUI equivalents of sufficient quality. SwiftUI is used for: the status bar (US-009), the preferences window (US-010), and potentially the sidebar file tree (US-007).

### Decision: TextKit 1 Over TextKit 2

TextKit 2 (`NSTextContentStorage` + `NSTextLayoutManager`) is Apple's recommended text layout system going forward. However, for this project, TextKit 1 (`NSTextStorage` + `NSLayoutManager`) is the correct choice. TextKit 2 has known limitations with custom attribute rendering across paragraph boundaries, performance regressions for documents with many attribute runs (syntax highlighting creates many), and incomplete API for custom background drawing (current line highlight) and gutter integration (line numbers). TextKit 1 is stable, well-documented, and provides everything needed.

### Decision: cmark-gfm Over swift-markdown for HTML Rendering

The FEATURE_SPEC suggests `swift-markdown` (Apple's parser). For the preview rendering pipeline (markdown -> HTML), `cmark-gfm` is recommended instead. `swift-markdown` produces a typed AST that requires manual walking to generate HTML -- this is more work and more bugs for no benefit in the preview use case. `cmark-gfm` provides `cmark_gfm_render_html()` which handles all GFM extensions (tables, strikethrough, task lists, autolinks) in a single C function call. For the editor syntax highlighting, a lightweight line-by-line regex scanner is used instead of any full parser -- full AST parsing is too expensive for per-keystroke highlighting.

### Shortcut Conflict: Cmd+E

The FEATURE_SPEC assigns Cmd+E to "Inline Code." Standard macOS assigns Cmd+E to "Use Selection for Find." These cannot both use the same shortcut. This requires a product owner decision:

- **Option A:** Keep Cmd+E for Inline Code (as the spec says), reassign "Use Selection for Find" to a different shortcut or remove it. This breaks standard macOS convention.
- **Option B:** Keep Cmd+E for "Use Selection for Find" (standard macOS), reassign Inline Code to another shortcut (e.g., Cmd+Shift+E, but that conflicts with "Editing Mode"; or Cmd+` (backtick), which is thematic).

**Recommendation:** Option B. Standard macOS shortcuts should not be overridden. Assign Inline Code to Cmd+` (backtick). Flag this for product owner review.

### Shortcut Conflict: Sidebar Toggle

The Design Direction suggests Cmd+1 for sidebar toggle, but Cmd+1 is assigned to Heading 1 in the FEATURE_SPEC. The implementation plan already notes this. The sidebar toggle should use a non-conflicting shortcut. Options: Cmd+\ (used by Xcode for sidebar), Cmd+Shift+L, or Ctrl+Cmd+S. **Recommendation:** Cmd+\ (backslash) -- this is the established Xcode convention for sidebar toggle and will feel natural to developers.

---

## Dependency Map

The stories and tasks follow a layered dependency structure. Here is the high-level order:

```
US-001 (App Shell)
  |
  +---> US-002 (Editing Canvas)
  |       |
  |       +---> US-003 (Toolbar + Formatting)
  |       |       |
  |       |       +---> US-004 (Edit/Preview Toggle)
  |       |       |       |
  |       |       |       +---> US-009 (Status Bar)
  |       |       |       +---> US-011 (Export)
  |       |       |
  |       |       +---> US-008 (Menu Bar)
  |       |
  |       +---> US-005 (File Operations)
  |       |       |
  |       |       +---> US-006 (Tab Management)
  |       |
  |       +---> US-010 (Preferences)
  |
  +---> US-007 (Sidebar + Open Folder)  [can begin after US-001; sidebar structure is independent of editor]
```

### Parallel-Safe Work

The following tasks/stories can be worked on in parallel once their dependencies are met:

- **T-002.2** (syntax highlighting), **T-002.3** (canvas layout), **T-002.4** (line numbers), **T-002.5** (auto-continue lists), **T-002.6** (drag-and-drop) are all independent of each other; they all depend only on T-002.1.
- **US-007** (Sidebar) depends on US-001 but is independent of US-002 through US-006. It can be developed in parallel with the editor and toolbar work.
- **T-004.2** (preview WKWebView) depends on T-001.1 only. It can be built in parallel with the editing canvas work (US-002).
- **US-009** (Status Bar) and **US-011** (Export) are independent of each other; both depend on the preview pipeline.
- **T-008.2** (Find), **T-008.3** (Font size), **T-008.4** (Help/Syntax Guide) are independent of each other.

### Task-Level Dependency Summary

| Task | Depends On |
|------|-----------|
| T-001.1 | -- |
| T-001.2 | T-001.1 |
| T-001.3 | T-001.1 |
| T-001.4 | T-001.2 |
| T-002.1 | T-001.1 |
| T-002.2 | T-002.1 |
| T-002.3 | T-002.1 |
| T-002.4 | T-002.1 |
| T-002.5 | T-002.1 |
| T-002.6 | T-002.1, T-001.3 |
| T-003.1 | T-001.2, T-002.1 |
| T-003.2 | T-003.1, T-002.1 |
| T-003.3 | T-003.1, T-002.1 |
| T-003.4 | T-003.1 |
| T-004.1 | T-001.1, T-003.1 |
| T-004.2 | T-001.1 |
| T-004.3 | T-004.1, T-004.2, T-002.1 |
| T-004.4 | T-004.2 |
| T-005.1 | T-001.3 |
| T-005.2 | T-001.3, T-001.1 |
| T-005.3 | T-001.1 |
| T-005.4 | T-001.3, T-005.3 |
| T-006.1 | T-001.2, T-001.3 |
| T-006.2 | T-002.1, T-004.1 |
| T-006.3 | T-006.1 |
| T-007.1 | T-001.2, T-003.1 |
| T-007.2 | T-007.1 |
| T-007.3 | T-007.2 |
| T-008.1 | T-003.2, T-003.3, T-004.1, T-005.1, T-005.2, T-005.3, T-005.4 |
| T-008.2 | T-002.1 |
| T-008.3 | T-002.1 |
| T-008.4 | T-004.2, T-005.1 |
| T-009.1 | T-002.1, T-004.1 |
| T-010.1 | T-002.1, T-004.2 |
| T-011.1 | T-004.2 |
| T-011.2 | T-004.2 |

---

## Recommended Implementation Order

For a single engineer working sequentially, the recommended order is:

1. **US-001** -- App shell, NSDocument, window chrome, tabs basic setup
2. **US-002** -- Editing canvas (the heart of the app)
3. **US-005** -- File operations (New, Open, Save -- core file I/O)
4. **US-003** -- Toolbar and formatting actions
5. **US-004** -- Edit/Preview toggle with WKWebView preview
6. **US-006** -- Tab management refinements
7. **US-009** -- Status bar
8. **US-008** -- Menu bar (wiring everything together)
9. **US-007** -- Sidebar and Open Folder
10. **US-010** -- Preferences
11. **US-011** -- Export (lowest priority, can be deferred)

---

## Definition of Done

- [ ] All 11 user stories have status DONE
- [ ] All acceptance criteria in every user story are verified and passing
- [ ] The app builds and runs on macOS 14 Sonoma and later
- [ ] Light mode and dark mode work correctly throughout the app
- [ ] All keyboard shortcuts from FEATURE_SPEC section 9 function correctly
- [ ] The app handles all edge cases documented in FEATURE_SPEC section 11
- [ ] All business rules from FEATURE_SPEC section 10 are enforced
- [ ] Performance criteria are met: 1MB file opens in <1 second, 50 tabs without lag, zero typing lag, 60fps scrolling, edit/preview toggle <200ms
- [ ] The app follows all Design Direction specifications: no welcome screen, 6-button toolbar with overflow, native tabs, native sidebar, auto-save, capped content width, recessive chrome, correct typography
- [ ] No hardcoded colors -- all colors use semantic system colors per Design Direction section 2
- [ ] APP_CONTEXT.md updated with final architecture decisions and component inventory
