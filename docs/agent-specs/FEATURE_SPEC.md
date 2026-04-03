# Feature Spec: MdEditor -- macOS Native Markdown Editor

**Status:** APPROVED  
**Created:** 2026-04-01  
**Platform:** macOS (native Swift / SwiftUI + AppKit)  
**Minimum deployment target:** macOS 14 Sonoma  

---

## 1. Goal

Build a clean, focused, native macOS application for creating and editing Markdown files. The app targets writers, developers, and anyone who works with Markdown daily. It provides a distraction-free editing experience with a formatting toolbar, a rendered preview mode for copy/paste interoperability with other systems, tabbed multi-document editing, and standard macOS file operations. The app should feel like a first-class Mac citizen -- fast, native, and visually polished -- while remaining simple and focused on the core task of Markdown editing.

---

## 2. User Stories

### Editing
- As a user, I want to type and edit Markdown text in a monospaced editor field, so that I can author Markdown content efficiently.
- As a user, I want a toolbar of formatting buttons above the editor, so that I can apply Markdown syntax without memorizing it.
- As a user, I want the toolbar to insert the correct Markdown syntax around my selected text (or at the cursor), so that formatting is fast and accurate.
- As a user, I want keyboard shortcuts for all common formatting actions, so that I can work without leaving the keyboard.

### Preview
- As a user, I want to toggle between an "Editing" view and a "Markdown" (rendered preview) view, so that I can see how the final output looks.
- As a user, I want the rendered preview to display styled HTML from my Markdown, so that I can verify formatting before sharing.
- As a user, I want to copy rich text from the preview view and paste it into other applications (Slack, Notion, email, etc.), so that I can transfer formatted content easily.

### File Operations
- As a user, I want to create a new blank Markdown document, so that I can start writing from scratch.
- As a user, I want to open an existing `.md` file from disk, so that I can continue editing previous work.
- As a user, I want to save my current document to disk, so that my work is persisted.
- As a user, I want "Save As" to save a copy under a new name or location.
- As a user, I want the app to track unsaved changes and warn me before closing a modified document, so that I do not lose work.

### Tabs
- As a user, I want to open multiple Markdown files simultaneously in tabs, so that I can work across documents without switching windows.
- As a user, I want to close individual tabs, so that I can manage my workspace.
- As a user, I want to reorder tabs by dragging, so that I can organize my workspace.
- As a user, I want a visual indicator on tabs that have unsaved changes, so that I know which documents need saving.

### Open Folder
- As a user, I want an "Open Folder" action that finds all Markdown files in a selected folder and opens each one as a tab, so that I can quickly load an entire documentation set or project.

### General
- As a user, I want the app to remember window size and position between launches, so that my workspace is consistent.
- As a user, I want the app to reopen previously open documents on launch (state restoration), so that I can pick up where I left off.

---

## 3. Application Architecture

### 3.1 Technology Stack

| Component        | Technology                                              |
|------------------|---------------------------------------------------------|
| UI framework     | SwiftUI (primary) with AppKit integration where needed  |
| Text editing     | NSTextView wrapped in SwiftUI (for rich text editing capabilities) |
| Markdown parsing | swift-markdown (Apple's open-source parser) or cmark    |
| HTML rendering   | WKWebView for preview rendering                         |
| File access      | Standard NSOpenPanel / NSSavePanel + FileManager        |
| State management | SwiftUI @Observable / @Environment patterns             |
| Persistence      | UserDefaults for preferences; file system for documents |

### 3.2 Core Data Model

There is no database. The app operates directly on the file system. The in-memory model is:

#### Document (class, ObservableObject)

| Property         | Type             | Description                                              |
|------------------|------------------|----------------------------------------------------------|
| id               | UUID             | Unique identifier for the tab/document instance          |
| fileURL          | URL?             | Path on disk; nil for unsaved new documents              |
| content          | String           | The raw Markdown text                                    |
| lastSavedContent | String           | Snapshot of content at last save; used for dirty tracking |
| isDirty          | Bool (computed)  | True when `content != lastSavedContent`                  |
| displayName      | String (computed)| Filename if saved, "Untitled" (with incrementing number) if not |
| createdAt        | Date             | When the document was created in this session             |

#### AppState (class, ObservableObject)

| Property          | Type             | Description                                  |
|-------------------|------------------|----------------------------------------------|
| openDocuments     | [Document]       | Ordered list of all open documents (tabs)    |
| activeDocumentID  | UUID?            | ID of the currently focused tab              |
| viewMode          | ViewMode enum    | .editing or .preview (per-document)          |
| recentFiles       | [URL]            | Recently opened file URLs for the File menu  |

#### ViewMode (enum)

| Case      | Description                          |
|-----------|--------------------------------------|
| .editing  | Show the text editor with toolbar    |
| .preview  | Show the rendered Markdown preview   |

**Design decision:** `viewMode` is stored per-document on the Document model (not globally) so that each tab can independently be in editing or preview mode.

---

## 4. UI Specification

### 4.1 Window Layout (top to bottom)

```
+------------------------------------------------------------+
| [ macOS Title Bar / Traffic Lights ]                        |
+------------------------------------------------------------+
| [ Tab Bar: Tab1  Tab2*  Tab3  ...  [+] ]                   |
+------------------------------------------------------------+
| [ Toolbar: B  I  S  H1 H2 H3  |  UL OL Task  |  Link     |
|   Image  Code  CodeBlock  Quote  HR  |  Table  |           |
|   Editing / Preview toggle ]                                |
+------------------------------------------------------------+
|                                                             |
|                                                             |
|              Editor Area  /  Preview Area                   |
|            (fills remaining vertical space)                 |
|                                                             |
|                                                             |
+------------------------------------------------------------+
| [ Status Bar: Line X, Col Y  |  Word Count  |  chars ]     |
+------------------------------------------------------------+
```

### 4.2 Tab Bar

- Displayed directly below the title bar using native macOS tab style.
- Each tab shows:
  - The document's display name (filename without extension, or "Untitled", "Untitled 2", etc.).
  - A dot or modified indicator (filled circle) when the document has unsaved changes.
  - A close button (x) on hover.
- A "+" button at the trailing edge creates a new untitled document.
- Tabs are reorderable via drag and drop.
- If tabs overflow the available width, they scroll horizontally with arrow indicators.
- Middle-click on a tab closes it.
- Right-click context menu on a tab:
  - Close Tab
  - Close Other Tabs
  - Close Tabs to the Right
  - Reveal in Finder (if saved to disk)
  - Copy File Path (if saved to disk)

### 4.3 Toolbar

The toolbar sits below the tab bar. It contains icon buttons (with SF Symbols) grouped by function. Buttons should have tooltips showing the action name and keyboard shortcut.

#### Toolbar Button Groups

**Text Formatting**

| Button          | Icon (SF Symbol)           | Markdown Syntax Inserted           | Shortcut      | Behavior                                                                 |
|-----------------|----------------------------|------------------------------------|---------------|--------------------------------------------------------------------------|
| Bold            | bold                       | `**text**`                         | Cmd+B         | Wraps selection; if no selection, inserts `**bold**` with "bold" selected |
| Italic          | italic                     | `*text*`                           | Cmd+I         | Wraps selection; same empty-cursor behavior                              |
| Strikethrough   | strikethrough              | `~~text~~`                         | Cmd+Shift+X   | Wraps selection                                                          |
| Inline Code     | chevron.left.forwardslash.chevron.right | `` `code` ``               | Cmd+E         | Wraps selection                                                          |

**Headings**

| Button     | Icon / Label      | Markdown Syntax         | Shortcut         | Behavior                                                    |
|------------|-------------------|-------------------------|------------------|-------------------------------------------------------------|
| Heading 1  | "H1" text label   | `# ` at line start      | Cmd+1            | Replaces any existing heading prefix on the current line     |
| Heading 2  | "H2" text label   | `## ` at line start     | Cmd+2            | Same                                                        |
| Heading 3  | "H3" text label   | `### ` at line start    | Cmd+3            | Same                                                        |
| Heading 4  | "H4" text label   | `#### ` at line start   | Cmd+4            | Same                                                        |
| Heading 5  | "H5" text label   | `##### ` at line start  | Cmd+5            | Same                                                        |
| Heading 6  | "H6" text label   | `###### ` at line start | Cmd+6            | Same                                                        |

**Lists**

| Button          | Icon (SF Symbol)           | Markdown Syntax             | Shortcut         | Behavior                                                  |
|-----------------|----------------------------|-----------------------------|------------------|-----------------------------------------------------------|
| Bullet List     | list.bullet                | `- ` at line start          | Cmd+Shift+8      | Toggles bullet prefix on selected lines                   |
| Numbered List   | list.number                | `1. ` at line start         | Cmd+Shift+7      | Adds sequential numbering to selected lines               |
| Task List       | checklist                  | `- [ ] ` at line start      | Cmd+Shift+9      | Toggles task list prefix; clicking again toggles checkmark |

**Insert Elements**

| Button          | Icon (SF Symbol)           | Markdown Syntax                           | Shortcut         | Behavior                                                      |
|-----------------|----------------------------|-------------------------------------------|------------------|---------------------------------------------------------------|
| Link            | link                       | `[text](url)`                             | Cmd+K            | If text selected, wraps as link text; opens small popover for URL input |
| Image           | photo                      | `![alt](url)`                             | Cmd+Shift+I      | Opens popover for alt text + URL/file path                    |
| Code Block      | curlybraces                | ```` ```\n...\n``` ````                   | Cmd+Shift+C      | Wraps selection in fenced code block; if empty, inserts template with cursor inside |
| Blockquote      | text.quote                 | `> ` at line start                        | Cmd+Shift+.      | Prepends `> ` to each selected line; toggles off if already quoted |
| Horizontal Rule | minus                      | `\n---\n`                                 | Cmd+Shift+-      | Inserts horizontal rule on a new line                         |
| Table           | tablecells                 | Inserts a 3x3 table template              | Cmd+Option+T     | Inserts a formatted Markdown table skeleton                   |

**View Toggle**

| Button          | Icon (SF Symbol)           | Shortcut         | Behavior                                              |
|-----------------|----------------------------|------------------|-------------------------------------------------------|
| Editing Mode    | square.and.pencil          | Cmd+Shift+E      | Switches active document to editing mode              |
| Preview Mode    | eye                        | Cmd+Shift+P      | Switches active document to rendered preview mode     |

The toggle is presented as a segmented control with two options: "Editing" and "Preview". The currently active mode is visually highlighted.

**Assumption:** Headings 4-6 are accessible via a dropdown/overflow menu from a "Heading" button group to keep the toolbar uncluttered. Headings 1-3 are shown directly. All six are accessible via keyboard shortcuts.

### 4.4 Editor View (Editing Mode)

- The editor is a monospaced-font text view (default: SF Mono or Menlo, 14pt).
- Syntax highlighting for Markdown elements:
  - Headings: larger/bolder text, distinct color.
  - Bold text: rendered bold in the editor.
  - Italic text: rendered italic in the editor.
  - Code spans and code blocks: background-tinted, monospaced (distinct from the surrounding monospaced body).
  - Links: colored, underlined.
  - List markers: dimmed/colored.
  - Blockquote markers: colored vertical rule or colored text.
- Line numbers displayed in a gutter on the left side (toggleable via View menu, default: off).
- Soft word wrap enabled by default (no horizontal scrolling for long lines).
- Standard macOS text editing behaviors: undo/redo (Cmd+Z / Cmd+Shift+Z), cut/copy/paste, find/replace (Cmd+F / Cmd+Option+F), spell check.
- Drag-and-drop: dropping an image file onto the editor inserts `![filename](file-path)` at the drop position.
- Drag-and-drop: dropping a `.md` file onto the editor opens it as a new tab (does not insert text).
- Tab key inserts 4 spaces (not a hard tab character). This is configurable in preferences.
- Auto-pairs for Markdown syntax: typing `**` then text then `**` is manual; no automatic closing of Markdown delimiters (to avoid interfering with intentional syntax).
- Auto-continue lists: pressing Enter at the end of a list item line (`- item`) auto-inserts `- ` on the next line. Pressing Enter on an empty list item removes the prefix (exits list mode). Same for numbered lists and task lists.

### 4.5 Preview View (Preview / Markdown Mode)

- Renders the Markdown content as styled HTML inside a WKWebView.
- The preview is read-only (no editing).
- Styling:
  - Clean, readable typography (system sans-serif font, ~16px body).
  - Proper heading hierarchy with sizes.
  - Styled code blocks with syntax highlighting (using a lightweight JS library like highlight.js bundled in the app, or Prism.js).
  - Styled tables with borders and alternating row shading.
  - Proper blockquote styling with left border.
  - Checkbox rendering for task lists (visual only, not interactive in preview).
  - Image rendering (if the image URL is accessible).
  - Link rendering (clickable; opens in default browser).
  - Horizontal rules rendered as styled dividers.
- Light and dark mode support: the preview CSS adapts to the system appearance.
- The preview scrolls to approximately the same position as the editor cursor was at when switching modes.
- Users can select and copy text from the preview. Copied text retains rich formatting (HTML) on the pasteboard so it can be pasted as formatted text into Slack, email, Google Docs, Notion, etc. Plain text fallback is also placed on the pasteboard.

**Assumption:** The preview uses a bundled CSS stylesheet and optional syntax-highlighting JS. No external network requests are made for rendering.

### 4.6 Status Bar

A slim bar at the bottom of the window showing:
- Cursor position: "Line X, Col Y"
- Word count: "N words"
- Character count: "N characters"
- File encoding: "UTF-8" (always UTF-8; shown for reference)

The status bar is visible in editing mode. In preview mode, only word count and character count are shown.

### 4.7 States

**Loading state:** When opening a large file, a brief indeterminate progress indicator appears in the tab. Files under 1MB should load instantly; the indicator is a safeguard.

**Empty state (no documents open):** The main area shows a centered welcome view:
- App icon
- "Welcome to MdEditor"
- Three action buttons:
  - "New Document" (Cmd+N)
  - "Open File..." (Cmd+O)
  - "Open Folder..." (Cmd+Shift+O)
- List of recently opened files (up to 10), each clickable to reopen.

**Error states:**
- File not found (moved/deleted since last open): Alert dialog: "The file [name] could not be found at its original location. It may have been moved or deleted. Would you like to save it to a new location?" Options: "Save As..." / "Close Tab".
- Permission denied: Alert dialog: "MdEditor does not have permission to read [path]. Please check file permissions." Option: "OK".
- File too large (>10MB): Alert dialog: "The file [name] is very large (X MB). Opening large files may affect performance. Open anyway?" Options: "Open" / "Cancel".

---

## 5. Menu Bar

### 5.1 MdEditor (App Menu)
- About MdEditor
- ---
- Preferences... (Cmd+,)
- ---
- Hide MdEditor (Cmd+H)
- Hide Others (Cmd+Option+H)
- Show All
- ---
- Quit MdEditor (Cmd+Q)

### 5.2 File Menu
- New (Cmd+N) -- creates a new untitled document in a new tab
- Open... (Cmd+O) -- opens an NSOpenPanel filtered to `.md`, `.markdown`, `.mdown`, `.txt` files
- Open Folder... (Cmd+Shift+O) -- opens an NSOpenPanel in directory selection mode
- Open Recent > -- submenu with up to 15 recent files; "Clear Menu" at bottom
- ---
- Close Tab (Cmd+W) -- closes the active tab (prompts to save if dirty)
- Close All Tabs (Cmd+Option+W) -- closes all tabs (prompts for each dirty document)
- ---
- Save (Cmd+S) -- saves the active document; if untitled, behaves as Save As
- Save As... (Cmd+Shift+S) -- opens NSSavePanel for the active document
- Save All (Cmd+Option+S) -- saves all dirty documents; prompts for untitled ones
- ---
- Export as HTML... -- exports the rendered Markdown as a standalone HTML file
- Export as PDF... -- exports the rendered Markdown as a PDF document

### 5.3 Edit Menu
- Undo (Cmd+Z)
- Redo (Cmd+Shift+Z)
- ---
- Cut (Cmd+X)
- Copy (Cmd+C)
- Paste (Cmd+V)
- Paste and Match Style (Cmd+Option+Shift+V)
- Select All (Cmd+A)
- ---
- Find > (submenu)
  - Find... (Cmd+F)
  - Find and Replace... (Cmd+Option+F)
  - Find Next (Cmd+G)
  - Find Previous (Cmd+Shift+G)
  - Use Selection for Find (Cmd+E)

### 5.4 Format Menu
- Bold (Cmd+B)
- Italic (Cmd+I)
- Strikethrough (Cmd+Shift+X)
- Inline Code (Cmd+E)
- ---
- Heading 1 (Cmd+1)
- Heading 2 (Cmd+2)
- Heading 3 (Cmd+3)
- Heading 4 (Cmd+4)
- Heading 5 (Cmd+5)
- Heading 6 (Cmd+6)
- ---
- Bullet List (Cmd+Shift+8)
- Numbered List (Cmd+Shift+7)
- Task List (Cmd+Shift+9)
- ---
- Blockquote (Cmd+Shift+.)
- Code Block (Cmd+Shift+C)
- ---
- Insert Link... (Cmd+K)
- Insert Image... (Cmd+Shift+I)
- Insert Table (Cmd+Option+T)
- Insert Horizontal Rule (Cmd+Shift+-)

### 5.5 View Menu
- Editing Mode (Cmd+Shift+E)
- Preview Mode (Cmd+Shift+P)
- ---
- Show Line Numbers (toggle, persisted in preferences)
- Toggle Word Wrap (toggle, persisted in preferences)
- ---
- Increase Font Size (Cmd+=)
- Decrease Font Size (Cmd+-)
- Reset Font Size (Cmd+0)
- ---
- Enter Full Screen (Cmd+Ctrl+F) -- standard macOS full screen

### 5.6 Window Menu
- Minimize (Cmd+M)
- Zoom
- ---
- Show Next Tab (Ctrl+Tab)
- Show Previous Tab (Ctrl+Shift+Tab)
- Move Tab to New Window
- Merge All Windows
- ---
- Bring All to Front

### 5.7 Help Menu
- MdEditor Help
- Markdown Syntax Guide -- opens a built-in reference document (a bundled .md file rendered in a new tab or sheet)

---

## 6. File Operations -- Detailed Behavior

### 6.1 New Document
- Creates a new Document with `fileURL = nil`, `content = ""`, display name "Untitled" (incrementing: "Untitled 2", "Untitled 3", etc., based on existing untitled tabs).
- The new tab becomes the active tab.
- The editor is focused and ready for input.

### 6.2 Open File
- Presents NSOpenPanel allowing selection of one or more files.
- Allowed file types: `.md`, `.markdown`, `.mdown`, `.mkd`, `.txt`.
- For each selected file:
  - If the file is already open in a tab, switch to that tab instead of opening a duplicate.
  - Otherwise, read the file contents, create a Document with the file URL and content, and open it in a new tab.
- The last opened file's tab becomes active.
- The file is added to the recent files list.

### 6.3 Open Folder
- Presents NSOpenPanel in directory-selection mode (canChooseDirectories = true, canChooseFiles = false).
- Recursively scans the selected directory for files with extensions: `.md`, `.markdown`, `.mdown`, `.mkd`.
- Does NOT include `.txt` files in folder scan (assumption: `.txt` in a folder are likely not all Markdown).
- Skips hidden files and directories (those starting with `.`).
- Skips common non-content directories: `node_modules`, `.git`, `build`, `dist`, `.venv`, `__pycache__`.
- Opens each found file as a tab (skipping duplicates already open).
- Files are opened in alphabetical order by relative path.
- If the folder contains more than 50 Markdown files, shows a confirmation dialog: "This folder contains N Markdown files. Opening all of them may use significant memory. Continue?" Options: "Open All" / "Cancel".
- The first file (alphabetically) becomes the active tab.

### 6.4 Save
- If the document has a `fileURL`, writes `content` to that URL as UTF-8 text, updates `lastSavedContent`.
- If the document has no `fileURL` (untitled), behaves as Save As.
- On write failure (permissions, disk full), shows an alert: "Could not save [name]. [system error description]." Option: "OK".

### 6.5 Save As
- Presents NSSavePanel with the current filename as default (or "Untitled.md" for new documents).
- Default extension: `.md`.
- Allowed extensions: `.md`, `.markdown`, `.txt`.
- On confirm, writes the file, updates `fileURL` and `lastSavedContent`, and updates the tab display name.

### 6.6 Close Tab
- If the document is dirty, shows a save prompt: "Do you want to save the changes you made to [name]?" Options: "Save" / "Don't Save" / "Cancel".
  - Save: performs Save (may trigger Save As for untitled docs). If save succeeds, closes the tab. If save is cancelled, tab stays open.
  - Don't Save: discards changes and closes the tab.
  - Cancel: tab stays open.
- If the document is clean, closes immediately.
- After closing, the next tab to the right becomes active. If there is no tab to the right, the tab to the left becomes active. If no tabs remain, the welcome/empty state is shown.

### 6.7 Export as HTML
- Renders the current document's Markdown to a full standalone HTML document (including inline CSS for styling).
- Presents NSSavePanel with default name `[document-name].html`.
- Writes the HTML file.

### 6.8 Export as PDF
- Renders the current document's Markdown to HTML, then uses WKWebView's PDF export capability to generate a PDF.
- Presents NSSavePanel with default name `[document-name].pdf`.
- Writes the PDF file.

---

## 7. Toolbar Formatting -- Detailed Insertion Behavior

All formatting actions follow these general rules:

### 7.1 Wrap-style formatting (Bold, Italic, Strikethrough, Inline Code)

- **Text is selected:** Wrap the selected text with the syntax markers. Example: selecting "hello" and pressing Bold produces `**hello**`. The selection after the action covers the entire formatted span including markers.
- **No selection (cursor in empty space):** Insert the markers with placeholder text between them. Example: pressing Bold with cursor produces `**bold text**` with "bold text" selected so the user can immediately type to replace it.
- **Toggle behavior:** If the selected text is already wrapped with the formatting markers, remove them. Example: selecting `**hello**` (including the markers) and pressing Bold produces `hello`.

### 7.2 Line-prefix formatting (Headings, Lists, Blockquotes)

- **Single line / cursor on a line:** Add or replace the prefix at the start of the current line.
- **Multiple lines selected:** Apply the prefix to each selected line.
- **Toggle behavior:** If the line already has the exact prefix, remove it. For headings, applying a different heading level replaces the existing one.
- **Numbered lists:** Auto-increment numbers for each selected line (1., 2., 3., ...).

### 7.3 Block insertion (Code Block, Horizontal Rule, Table)

- **Code Block with selection:** Wrap the selected text in a fenced code block. The opening fence includes a language placeholder that the user can fill in.
- **Code Block without selection:** Insert an empty fenced code block template with the cursor positioned inside.
- **Horizontal Rule:** Insert `---` on a new line. If the cursor is not at the beginning of a line, insert a newline first.
- **Table:** Insert the following template:
  ```
  | Column 1 | Column 2 | Column 3 |
  |----------|----------|----------|
  |          |          |          |
  |          |          |          |
  ```
  The cursor is placed in the first data cell.

### 7.4 Link Insertion

- **Text selected:** Opens a small popover/sheet with a URL input field. On confirm, wraps the selected text: `[selected text](entered-url)`.
- **No selection:** Opens a popover with fields for both "Link Text" and "URL". On confirm, inserts `[link text](url)`.
- **URL on clipboard:** If the system clipboard contains a URL when the link action is triggered, auto-populate the URL field in the popover.

### 7.5 Image Insertion

- **Opens a popover** with fields for "Alt Text" and "Image URL or Path".
- A "Choose File..." button in the popover opens a file picker for local images.
- For local images, inserts a relative path if the image is in the same directory tree as the document, otherwise an absolute path.
- If the document is untitled (not yet saved), uses the absolute path and shows a note: "Save the document first for relative image paths."

---

## 8. Preferences

Accessible via Cmd+, or the app menu. A simple preferences window with the following settings:

### 8.1 Editor Tab

| Setting              | Type         | Default            | Options / Range                         |
|----------------------|--------------|--------------------|-----------------------------------------|
| Font Family          | Dropdown     | SF Mono            | SF Mono, Menlo, Fira Code, Source Code Pro, System Monospaced |
| Font Size            | Stepper      | 14                 | 10 -- 32 pt                              |
| Tab Width            | Stepper      | 4                  | 2, 4, 8 spaces                          |
| Show Line Numbers    | Toggle       | Off                |                                         |
| Word Wrap            | Toggle       | On                 |                                         |
| Spell Check          | Toggle       | On                 |                                         |
| Auto-continue Lists  | Toggle       | On                 |                                         |

### 8.2 Preview Tab

| Setting              | Type         | Default            | Options / Range                         |
|----------------------|--------------|--------------------|-----------------------------------------|
| Preview Font Size    | Stepper      | 16                 | 12 -- 28 pt                              |
| Code Block Theme     | Dropdown     | Auto (match system)| Light, Dark, Auto                       |

### 8.3 General Tab

| Setting                      | Type    | Default | Description                                     |
|------------------------------|---------|---------|------------------------------------------------|
| Restore tabs on launch       | Toggle  | On      | Reopen previously open documents on app launch  |
| Auto-save interval           | Dropdown| Off     | Off, 30s, 1min, 5min -- auto-saves dirty files   |
| Default file extension       | Dropdown| .md     | .md, .markdown                                  |
| New window behavior          | Dropdown| New Tab | New Tab, New Window                             |

---

## 9. Keyboard Shortcuts -- Complete Reference

### File Operations
| Action             | Shortcut          |
|--------------------|-------------------|
| New Document       | Cmd+N             |
| Open File          | Cmd+O             |
| Open Folder        | Cmd+Shift+O       |
| Save               | Cmd+S             |
| Save As            | Cmd+Shift+S       |
| Save All           | Cmd+Option+S      |
| Close Tab          | Cmd+W             |
| Close All Tabs     | Cmd+Option+W      |

### Editing
| Action             | Shortcut          |
|--------------------|-------------------|
| Undo               | Cmd+Z             |
| Redo               | Cmd+Shift+Z       |
| Find               | Cmd+F             |
| Find and Replace   | Cmd+Option+F      |
| Find Next          | Cmd+G             |
| Find Previous      | Cmd+Shift+G       |

### Formatting
| Action             | Shortcut          |
|--------------------|-------------------|
| Bold               | Cmd+B             |
| Italic             | Cmd+I             |
| Strikethrough      | Cmd+Shift+X       |
| Inline Code        | Cmd+E             |
| Heading 1          | Cmd+1             |
| Heading 2          | Cmd+2             |
| Heading 3          | Cmd+3             |
| Heading 4          | Cmd+4             |
| Heading 5          | Cmd+5             |
| Heading 6          | Cmd+6             |
| Bullet List        | Cmd+Shift+8       |
| Numbered List      | Cmd+Shift+7       |
| Task List          | Cmd+Shift+9       |
| Blockquote         | Cmd+Shift+.       |
| Code Block         | Cmd+Shift+C       |
| Insert Link        | Cmd+K             |
| Insert Image       | Cmd+Shift+I       |
| Insert Table       | Cmd+Option+T      |
| Horizontal Rule    | Cmd+Shift+-       |

### View
| Action             | Shortcut          |
|--------------------|-------------------|
| Editing Mode       | Cmd+Shift+E       |
| Preview Mode       | Cmd+Shift+P       |
| Increase Font Size | Cmd+=             |
| Decrease Font Size | Cmd+-             |
| Reset Font Size    | Cmd+0             |
| Toggle Full Screen | Cmd+Ctrl+F        |

### Tabs
| Action             | Shortcut          |
|--------------------|-------------------|
| Next Tab           | Ctrl+Tab          |
| Previous Tab       | Ctrl+Shift+Tab    |
| Go to Tab 1-9      | Cmd+1 through Cmd+9 |

**Shortcut conflict resolution:** Cmd+1 through Cmd+6 are assigned to headings. Cmd+1 through Cmd+9 for tab switching is the macOS default. Resolution: Cmd+1 through Cmd+6 trigger heading formatting when the editor is focused. Tab switching via number uses Ctrl+1 through Ctrl+9 instead (non-standard but avoids conflict). This is documented in the Help menu.

---

## 10. Business Rules

1. **File encoding:** All files are read and written as UTF-8. If a file cannot be decoded as UTF-8, show an error: "This file does not appear to be a UTF-8 text file and cannot be opened."
2. **File watching:** The app does NOT watch for external file changes in v1. If a file is modified externally while open, the user's in-memory version takes precedence on save. (External file watching is out of scope.)
3. **Unsaved changes on quit:** When the user quits the app (Cmd+Q) with dirty documents open, macOS will trigger the standard save prompt for each dirty document (via NSDocument-style behavior or manual implementation).
4. **Tab limit:** No hard limit on open tabs. Performance is the practical limit. The app should handle 50+ tabs without noticeable lag.
5. **Untitled document naming:** Untitled documents are numbered sequentially within a session: "Untitled", "Untitled 2", "Untitled 3". Closing "Untitled 2" does not free up that number within the session. Numbers reset on app restart.
6. **Maximum file size:** The app can open files up to 10MB. Files larger than 10MB trigger a warning dialog (see section 4.7). Files larger than 50MB are refused with an error.
7. **Supported Markdown features in preview:** The preview renderer must support all CommonMark features plus these extensions:
   - GitHub Flavored Markdown (GFM) tables
   - Task lists (checkboxes)
   - Strikethrough
   - Fenced code blocks with language-specific syntax highlighting
   - Autolinks (bare URLs rendered as clickable links)
8. **Image paths in preview:** Relative image paths in the Markdown are resolved relative to the document's `fileURL`. If the document is untitled, relative paths will not resolve (expected behavior; images will show broken-image indicators).

---

## 11. Edge Cases and Error Handling

| Edge Case | Expected Behavior |
|-----------|-------------------|
| Open a file that is already open in a tab | Switch to the existing tab; do not open a duplicate |
| Open a file that was deleted since it was last in "recent files" | Show alert: "File not found." Remove from recent files list |
| Paste very large text (>1MB) into the editor | Accept the paste; no truncation. Performance may degrade for extremely large documents; this is acceptable |
| Open a folder with zero Markdown files | Show an informational alert: "No Markdown files were found in [folder name]." |
| Open a folder with nested subfolders | Recursively scan all subfolders (respecting the exclusion list in section 6.3) |
| Save to a read-only location | Show error dialog with the system error message |
| System appearance changes (light/dark mode) while app is running | Editor and preview update immediately to match the new appearance |
| Drag a non-image, non-markdown file onto the editor | No action; ignore the drop |
| Drag an image file onto the editor while document is in preview mode | Switch to editing mode, then insert the image reference |
| User presses Cmd+S on a clean (non-dirty) document | No-op; no error, no feedback needed |
| User tries to close last tab when it's the only tab and it's clean | Close the tab, show the welcome/empty state |
| Extremely long filename (>255 chars) | Truncate the displayed tab name with ellipsis; full name shown in tooltip |
| File with no extension | Can be opened via Open File dialog (if user selects "All Files"); treated as Markdown |
| Multiple windows | Each window has its own tab bar and set of open documents. A file can be open in multiple windows simultaneously; changes are independent (no cross-window sync in v1) |
| Opening the same file from "Open Folder" that is already open | Skip it (same as the duplicate-tab rule for Open File) |
| User applies Bold formatting to text that is already bold | Remove the bold markers (toggle off) |
| User applies Heading 2 to a line that is already Heading 3 | Replace `### ` with `## ` (change heading level) |
| User applies Bullet List to lines that are already a numbered list | Replace numbered list prefixes with bullet prefixes |

---

## 12. Out of Scope (v1)

The following features are explicitly NOT included in the initial version:

1. **Split view / side-by-side editing and preview** -- only toggle between the two modes.
2. **Real-time file watching** for external changes to open files.
3. **Collaborative editing** or any multi-user functionality.
4. **Plugin / extension system.**
5. **Custom themes or user-defined color schemes** beyond light/dark mode.
6. **Git integration** (diff, commit, branch, etc.).
7. **Vim / Emacs keybindings** or modal editing.
8. **iCloud sync** or any cloud storage integration.
9. **iOS / iPadOS version.**
10. **Markdown extensions** beyond GFM (no math/LaTeX, no Mermaid diagrams, no footnotes).
11. **Outline / table of contents sidebar.**
12. **Global search across all open documents.**
13. **Auto-update mechanism.** Updates are distributed manually or via the Mac App Store.
14. **File tree / project sidebar.** Open Folder opens files as flat tabs, not in a tree view.
15. **Terminal integration or command palette.**
16. **Printing** (use Export as PDF, then print the PDF).

---

## 13. Acceptance Criteria

### Core Editing
- [ ] User can create a new blank document and begin typing Markdown immediately.
- [ ] All toolbar buttons insert the correct Markdown syntax at the cursor or around the selected text.
- [ ] Toggle behavior works: applying Bold to already-bold text removes the bold markers.
- [ ] Heading buttons replace existing heading prefixes rather than adding duplicate markers.
- [ ] List auto-continuation works: pressing Enter after a list item continues the list; pressing Enter on an empty list item exits list mode.
- [ ] Undo/redo works correctly after toolbar formatting actions (each action is a single undoable unit).
- [ ] Markdown syntax highlighting appears in the editor (headings, bold, italic, code, links are visually distinct).

### Preview
- [ ] Toggling to Preview mode renders the current Markdown content as styled HTML.
- [ ] Preview supports all GFM features: headings, bold, italic, strikethrough, links, images, code blocks (with syntax highlighting), tables, task lists, blockquotes, horizontal rules, and autolinks.
- [ ] Copying text from the preview places rich (HTML) formatted text on the clipboard.
- [ ] Pasting preview-copied text into an external app (e.g., Apple Notes, Google Docs) preserves formatting.
- [ ] Preview respects system light/dark mode.
- [ ] Toggling back to Editing mode preserves all content exactly as it was.

### File Operations
- [ ] Open File opens a file picker filtered to Markdown file types and loads the selected file into a new tab.
- [ ] Save writes the file to disk and clears the dirty indicator.
- [ ] Save As presents a save dialog and writes to the chosen location.
- [ ] Save All saves every dirty document (prompting Save As for untitled docs).
- [ ] Export as HTML produces a valid standalone HTML file.
- [ ] Export as PDF produces a properly formatted PDF.
- [ ] Closing a dirty document prompts to save with Save / Don't Save / Cancel options.
- [ ] Quitting the app with dirty documents prompts for each one.

### Tabs
- [ ] Multiple documents can be open simultaneously, each in its own tab.
- [ ] Tabs display the filename (or "Untitled") and a dirty indicator.
- [ ] Tabs can be closed individually via the close button or Cmd+W.
- [ ] Tabs can be reordered by dragging.
- [ ] The "+" button in the tab bar creates a new document.
- [ ] Switching tabs preserves cursor position and scroll position in each document.
- [ ] Opening a file that is already open switches to the existing tab.

### Open Folder
- [ ] Open Folder recursively scans the selected directory for Markdown files.
- [ ] Hidden directories and excluded directories (node_modules, .git, etc.) are skipped.
- [ ] Each found file opens as a new tab (duplicates skipped).
- [ ] A confirmation dialog appears when more than 50 files would be opened.
- [ ] An informational message appears when no Markdown files are found.

### Preferences
- [ ] Font family, font size, tab width, and other editor settings are configurable and persist across launches.
- [ ] Changes to preferences take effect immediately in all open editors.

### Window and State
- [ ] Window size and position are restored on relaunch.
- [ ] Previously open tabs are restored on relaunch (when the preference is enabled).
- [ ] The app correctly handles light and dark mode, including dynamic switching.
- [ ] The welcome/empty state is shown when no tabs are open.
- [ ] Status bar displays accurate line, column, word count, and character count.

### Keyboard Shortcuts
- [ ] All documented keyboard shortcuts function correctly.
- [ ] Shortcuts do not conflict with standard macOS system shortcuts.

### Performance
- [ ] Opening a 1MB Markdown file completes in under 1 second.
- [ ] The app remains responsive with 50 tabs open simultaneously.
- [ ] Typing in the editor has no perceptible input lag.

---

## 14. Assumptions and Design Decisions Log

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | View mode is per-document, not global | Users often want to edit one file while referencing the preview of another |
| 2 | No split view in v1 | Keeps the UI simple and focused; can be added later |
| 3 | No file tree sidebar | The app is a focused editor, not an IDE; tabs provide sufficient multi-file support |
| 4 | Folder scan excludes .txt files | In a folder context, .txt files are usually not Markdown; avoids noise |
| 5 | SF Mono as default font | Ships with macOS, excellent readability for code/Markdown |
| 6 | macOS 14+ minimum | Enables use of latest SwiftUI features (Observable macro, etc.) |
| 7 | NSTextView for the editor | SwiftUI's TextEditor lacks the customization needed for syntax highlighting and gutter; NSTextView provides full control |
| 8 | WKWebView for preview | Best HTML rendering on macOS; supports copy-as-rich-text natively |
| 9 | No auto-save by default | Respects user control; available as opt-in in preferences |
| 10 | Cmd+1-6 for headings, Ctrl+1-9 for tab switching | Heading shortcuts are more frequently used than numbered tab switching; documented in Help |
| 11 | No external network requests | The app is fully offline-capable; all rendering resources are bundled |
| 12 | 50-file threshold for folder open warning | Balances convenience (no warning for small projects) with protection against accidentally opening hundreds of files |
| 13 | Preview copy produces rich text + plain text on pasteboard | Maximizes compatibility with paste targets; the user's stated use case is copy/paste to other systems |
| 14 | GFM extensions but no LaTeX/Mermaid | Covers 95% of common Markdown usage; advanced extensions can be added in v2 |
