# Design Direction: MdEditor -- macOS Markdown Editor
# Created: 2026-04-01

---

## Design Intent

MdEditor should feel like a sheet of paper that happens to understand markdown. The app recedes until you need it, then responds with quiet competence. The experience is one of writing -- not of operating software. Every pixel that is not serving the writer's current thought is a pixel that should not be there. The emotional target is the feeling of opening a fresh notebook: calm anticipation, zero friction, total focus. The app earns its place on the dock by being the thing you reach for when you want to think in text.

---

## 1. Visual Philosophy

**The guiding word is "recessive."** The app never competes with the writer's content. It is a frame, not a participant.

Three principles govern every visual decision:

**Paper, not software.** The editing surface should feel like a material -- warm, slightly textured in its typography, generous in its whitespace. The chrome around it (toolbar, tabs, sidebar) should feel like the edge of a desk: present, structural, ignorable.

**Quiet until spoken to.** Toolbar buttons have no visible borders until hovered. Tab close buttons appear only on hover. The sidebar reveals depth only on interaction. Nothing shouts.

**Native and inevitable.** This is a Mac app. It should feel like Apple made it on a thoughtful day. Use NSVisualEffectView materials where appropriate. Respect the system accent color. Follow the platform's spatial model (toolbar at top, content below, sidebar optional at left). Do not invent new interaction paradigms when AppKit provides good ones.

---

## 2. Color and Typography

### Color Palette

Do NOT design a custom color system. Lean hard on semantic system colors.

- **Background (editing canvas):** `NSColor.textBackgroundColor` -- pure white in light mode, true dark in dark mode. This is the paper. It must be the brightest/darkest surface in the app. No grey tinting, no off-whites. The canvas is sacred.
- **Chrome (toolbar, tab bar, sidebar):** `NSVisualEffectView` with `.sidebar` or `.titlebar` material. Let the system handle vibrancy and transparency. This creates natural visual separation without drawing hard lines.
- **Text:** `NSColor.textColor` for body. `NSColor.secondaryLabelColor` for metadata, line numbers, or markdown syntax characters. `NSColor.tertiaryLabelColor` for placeholder text.
- **Accent:** System accent color only. Use it for: the active tab indicator, the active mode toggle state, and text selection. Nowhere else. If everything is blue, nothing is.
- **Syntax hints in editing mode:** Extremely restrained. Headings get `NSColor.labelColor` at heavier weight. Bold gets weight, not color. Italic gets slant, not color. Links get system accent but at reduced opacity (0.7). Code spans get a barely-visible background tint using `NSColor.quaternaryLabelColor`. The principle: markdown syntax characters (the `#`, `**`, `*`, backticks) render in `NSColor.tertiaryLabelColor` so they visually recede while the content they modify takes prominence.

### Typography

**Editing mode (the default, primary experience):**

- **Font:** Use the system monospaced font (`NSFont.monospacedSystemFont`) as the default, but offer a preference for proportional. Why monospaced as default: markdown writers think in structure. Alignment matters. Monospace communicates "this is a working surface" which is honest about what editing mode is.
- **Size:** 14pt as default. This is the Mac. People sit at arm's length. 14pt monospaced is comfortable for sustained writing.
- **Line height:** 1.6x the font size. This is non-negotiable for readability in a writing tool. Cramped line height is the single fastest way to make an editor feel oppressive.
- **Heading rendering in edit mode:** Headings should be visually distinct even in editing mode. H1 at 1.5x base size, semibold. H2 at 1.3x, semibold. H3 at 1.15x, semibold. H4-H6 at base size, semibold. The `#` characters themselves render in tertiaryLabelColor. This creates a document outline feel even in raw editing.

**Preview mode:**

- **Font:** System serif or the system default proportional font (San Francisco). I lean toward San Francisco (the system font) because it is what Mac users read in every quality app. Serif feels affected unless the user is writing prose specifically -- and we do not know that.
- **Size:** 15pt body, with standard typographic scale for headings (H1 at 2em, H2 at 1.5em, H3 at 1.25em).
- **Line height:** 1.7x for body text. Preview is for reading, and reading demands more air than editing.
- **Content width in preview:** Max 680px (approximately 70 characters). Center it. Long lines destroy readability. This is not a suggestion.

---

## 3. Toolbar Design

### The Problem with Formatting Toolbars

Most markdown editors present a row of 15-20 formatting buttons that create two problems simultaneously: they overwhelm new users with options, and they insult experienced users who use keyboard shortcuts. The toolbar becomes dead space -- always visible, rarely used.

### Our Approach

**A single-row contextual toolbar that breathes.**

The toolbar lives in the native `NSToolbar` area, integrated with the title bar (unified title/toolbar style). It contains:

**Left cluster -- Document actions (always visible):**
- Sidebar toggle (to show/hide the folder file tree)

**Center cluster -- Formatting (visible only in Editing mode):**
- Six buttons maximum, no labels, monochrome SF Symbols only: **Bold**, **Italic**, **Link**, **Code**, **List** (toggles between bullet and numbered on secondary click), **Heading** (cycles H1 through H3 on repeated clicks, H4-H6 available via long-press menu)
- These buttons have NO visible borders, NO background. Just the SF Symbol in `NSColor.secondaryLabelColor`. On hover, they gain a subtle rounded-rect background matching the system's standard toolbar button hover state. This means in their resting state, they are almost invisible -- just quiet glyphs sitting above the page.
- When text is selected and a format applies, the corresponding button fills to `NSColor.controlAccentColor`. This is the only state feedback needed.
- An overflow approach: a `...` button at the end opens a popover for less common formatting (blockquote, table, horizontal rule, image, strikethrough). This keeps the primary toolbar to six items. Six is the maximum a person can scan without grouping.

**Right cluster -- Mode and view:**
- The Edit/Preview toggle (see section 5)
- A share/export button (SF Symbol, same styling as formatting buttons)

**Why not a contextual toolbar that appears on text selection?** I considered this (a floating toolbar near selected text, like Medium). I reject it for a native Mac app. It breaks the spatial model -- Mac toolbars are at the top. It creates a moving target. It obscures content. It is clever, not good.

**Why not a slash-command palette (like Notion)?** Slash commands are a web-app pattern. They work when the content model is blocks. Markdown is a stream of text. A palette would interrupt the flow of typing. Keyboard shortcuts (Cmd+B, Cmd+I, Cmd+K) are the power-user path. The toolbar is the discovery path. Both already exist in the native Mac idiom.

**Toolbar in Preview mode:** The formatting buttons in the center cluster fade out and are replaced with nothing. The toolbar visually simplifies. The mode toggle remains. This reinforces the mental model: preview is for reading, not editing. The toolbar does not show formatting controls you cannot use.

---

## 4. The Editing Canvas

This is the most important surface in the app. Everything else exists to serve it.

### Spatial Design

- **Horizontal padding:** 48pt minimum on each side from the text to the window edge. On wider windows, the text column should NOT expand infinitely. Cap the text area at approximately 900px and center it within the available space. Writers should never have lines stretching 1400px across an ultrawide display. That is not generosity -- it is cruelty.
- **Top padding:** 24pt from the bottom of the toolbar/tab area to the first line of text. Enough breathing room that the content does not feel crushed against the chrome, but not so much that you feel you are wasting space.
- **Bottom padding:** The document should be scrollable such that the last line can reach the vertical center of the viewport. This prevents the writer from always staring at the bottom edge of the window. It is a small thing that transforms the writing feel.
- **Line numbers:** OFF by default. Available in preferences. If enabled, they render in `NSColor.quaternaryLabelColor` with a thin (1px, `NSColor.separatorColor`) vertical rule between numbers and content. Line numbers are for programmers editing config files, not for writers. Default to the writer.

### Cursor and Selection

- Use the system default text cursor (I-beam). Do not customize it.
- Text selection should use the system accent color at standard opacity.
- Current line highlighting: a barely perceptible background shift on the line containing the cursor. Use `NSColor.textColor` at 0.03 alpha. This is a whisper, not a highlight. It helps the eye locate the cursor after looking away and back. If it is noticeable, it is too strong.

### Scrolling

- Smooth, inertial, native `NSScrollView` behavior. Do not fight the system here.
- No minimap. A minimap is for code editors with thousands of lines. Markdown documents are prose. A document outline (extracted from headings) in the sidebar is the correct navigation tool.

### Empty State

When a new untitled document is created and the canvas is empty, show nothing. No placeholder text, no "Start writing..." prompt, no tutorial. The blinking cursor on a white page IS the invitation. Any text we put there is something the user has to delete before they can think. Respect the blank page.

---

## 5. Edit / Preview Mode Toggle

### The Conventional Approach (and Why It Is Mostly Right Here)

Most markdown editors use either a side-by-side split or a tab/segmented-control toggle. Side-by-side is wrong for this app: it halves the writing space and creates two things to look at when the user's job is one thing at a time. Our user is either writing or checking -- not both simultaneously.

### Our Approach: Segmented Control with a Spatial Transition

**The toggle control:**
A native `NSSegmentedControl` with two segments: "Edit" and "Preview", placed in the right area of the toolbar. Standard system styling. No custom rendering. Two words, two states, zero ambiguity.

- "Edit" is the default and dominant mode. When the app opens, you are in Edit.
- Keyboard shortcut: Cmd+Shift+P toggles between modes. This matches the mental model of "show me the preview" as an action you take, then return from.

**The transition:**
When toggling from Edit to Preview:

1. The editing text fades out over 150ms (opacity 1 to 0) while simultaneously the preview fades in (opacity 0 to 1). Cross-dissolve.
2. The scroll position is PRESERVED. If the user was looking at line 84, the preview scrolls to the rendered position of that same content. This is critical. Losing scroll position makes the user re-orient, which breaks their train of thought.
3. The toolbar formatting buttons fade out during this same 150ms window, so the chrome simplifies in concert with the content change.
4. Total transition time: 200ms including any easing. Fast enough to feel instant, slow enough to not be jarring.

**Why cross-dissolve and not a slide or flip?** Because the two modes occupy the same conceptual space -- they are two views of the same document. A slide implies moving to a different place. A flip implies turning something over. A dissolve says "same thing, different lens." The motion communicates the truth.

**Why not a live preview that updates as you type?** This was considered. It creates three problems: it demands a split view (halving space), it divides attention, and it makes the editing side feel like the "ugly" version. The toggle model says: both modes are first-class. You are fully in one or fully in the other. One thing per moment.

---

## 6. Tab Bar Design

### The Problem

Multiple open documents need tabs. But tabs in text editors are a solved problem done poorly everywhere. Most implementations show too much information (full file paths), waste space on close buttons that are always visible, or create a visual weight that competes with the content.

### Our Approach

**Use the native macOS document tab bar** (`NSWindow.tabbingMode`). macOS provides a system-level tab bar for document-based apps. Use it. Here is why:

- It matches every other tabbed app on the user's system (Finder, Terminal, Safari). Zero learning curve.
- It handles tab overflow, drag-to-reorder, drag-to-new-window, and merge-all-windows automatically.
- It respects the system appearance (light/dark, accent color, transparency).
- It evolves with macOS updates without any maintenance.

**Customizations within the native system:**

- Each tab shows the filename only (not the path). If two files share a name, append the parent folder in parentheses: `README.md (project)` and `README.md (docs)`.
- The unsaved-changes indicator (the dot in the close button) is a native behavior. Use it. It is the established Mac convention.
- Tab width should be automatic (content-fitting), not fixed. Short filenames get narrow tabs, long ones get wider tabs. This is the native behavior -- do not override it.

**Why not a custom tab bar?** Custom tab bars in Mac apps almost always feel wrong. They sit at a different visual weight, they miss system animations, they break drag-and-drop expectations. The native tab bar is better than anything we would build. Humility is a design skill.

---

## 7. Sidebar (Folder Tree)

When a user opens a folder, a sidebar appears on the left showing the file tree.

**Behavior:**
- Uses `NSSplitViewController` with a sidebar style split. The sidebar gets the standard vibrancy/translucency treatment from `NSVisualEffectView`.
- Default width: 220pt. Resizable. Collapsible via toolbar button or Cmd+1.
- Shows only `.md`, `.markdown`, `.txt`, and `.text` files by default. Other files are hidden. A preference can toggle "show all files." This is a markdown editor, not Finder. Show what matters.
- Files show their name only (no extension for `.md` files since that is the assumed format; show extension for others).
- Folders are collapsible in the standard disclosure-triangle pattern.
- Single click opens a file. No double-click requirement. Speed of access matters.
- The currently-open file is highlighted with the system accent color at low opacity, matching native sidebar selection styling.

**Empty state (no folder open):** The sidebar is simply not visible. No empty sidebar with a "Open a folder" message. The toolbar sidebar-toggle button is the affordance. If no folder is open, the sidebar does not exist.

---

## 8. Interaction Principles for Engineers

These are the rules that should guide every micro-decision during implementation:

### Principle 1: Keyboard First, Mouse Supported
Every formatting action must have a keyboard shortcut. The toolbar is a visual reference for what shortcuts exist (show them in tooltips), not the primary input method. The user's hands are on the keyboard because they are writing. Do not make them reach for the mouse.

Standard shortcuts: Cmd+B (bold), Cmd+I (italic), Cmd+K (link), Cmd+Shift+C (code), Cmd+Shift+L (list), Cmd+1/2/3 (heading levels if these do not conflict with system tab shortcuts -- if they do, use Ctrl+1/2/3).

### Principle 2: Undo Everything, Confirm Nothing
No "Are you sure?" dialogs for destructive text operations. Cmd+Z undoes everything. If the user bolds a selection and does not like it, they undo. If they delete a paragraph, they undo. The app should maintain a deep undo stack (minimum 100 operations).

For file operations (delete file from sidebar), use the system Trash. The file is not gone -- it is in the Trash. Say "Move to Trash" not "Delete." The safety net is always there.

### Principle 3: Save Is Not an Event
Auto-save continuously using the native macOS document model (`NSDocument` auto-save). The user should never think about saving. The document is always saved. The title bar shows the standard macOS edited-document indicator (dot in close button) for the brief moment between typing and auto-save completing, but the user should never need to Cmd+S. (Still support Cmd+S for muscle memory -- it just forces an immediate save.)

### Principle 4: Launch into Action
When the app launches:
- If there were previously open documents, restore them exactly (this is native `NSDocument` restoration behavior).
- If no previous state, open a new untitled document immediately. The cursor is blinking and ready. Time from launch to first keystroke: zero decisions.
- Never show a "Welcome" screen, a "What's New" dialog, or a template chooser. The user opened a text editor. Let them edit text.

### Principle 5: Respect the Platform
- Support system Dark Mode automatically.
- Support system accent color.
- Support Full Screen mode natively.
- Support Split View (two MdEditor windows, or MdEditor alongside Safari for reference).
- Support the Touch Bar if present (show formatting shortcuts).
- Support the standard Mac Services menu for text.
- Respond to system text size accessibility settings.
- Place Preferences under the app menu (Cmd+comma), not in a toolbar.

### Principle 6: The Window IS the App
The window chrome, toolbar, tab bar, and content area should feel like one unified surface, not layers stacked on top of each other. Use the unified titlebar/toolbar style. Let the toolbar blend into the title bar. The window is a single pane of glass with the document behind it.

### Principle 7: Performance Is a Design Decision
Switching between Edit and Preview must take under 200ms for any document under 10,000 words. Typing must never lag -- not by a single frame. Scrolling must be 60fps. If rendering markdown preview is slow, show the transition animation while rendering completes in the background. Never let the user feel the machine working. The app should feel like it is made of light.

---

## What We Are NOT Doing

### Split-pane live preview
Rejected. It halves the workspace, creates a "draft vs. real" hierarchy that diminishes the editing experience, and divides attention. One thing per moment.

### WYSIWYG editing (like Typora)
Rejected. WYSIWYG markdown editors hide the syntax, which means the user cannot learn markdown, cannot debug formatting issues, and loses the sense of control that comes from seeing the raw text. Our editing mode shows the markdown with tasteful syntax hinting. The user always knows exactly what their document contains.

### Plugin or extension system
Rejected for v1. This is a focused tool. Extensibility adds complexity to every surface it touches. Ship the right defaults. Consider extensibility only after the core experience is perfect.

### Themes or custom color schemes
Rejected for v1. Offer light mode and dark mode (following the system). Custom themes are a rabbit hole that fragments the experience and creates maintenance burden. The one right appearance in each system mode is better than thirty mediocre options.

### Vim or Emacs keybindings
Rejected. The standard macOS text system keybindings are the correct default. Users who want Vim bindings have Vim. This app is for people who want a Mac app.

### Export to PDF/Word/HTML from within the app
Considered. Defer to v2. For v1, the system Print dialog (which includes "Save as PDF") covers the PDF case. The focus is editing, not publishing. Do not clutter the interface with export options before the editing experience is flawless.

### Syntax highlighting for code blocks
Include it, but keep it minimal. Use four colors maximum for code syntax within fenced code blocks: keyword, string, comment, and default. This is not an IDE. The code block just needs to be readable, not a full development environment.

---

## Summary of Key Specifications for Engineers

| Element | Specification |
|---|---|
| Window style | Unified titlebar/toolbar (`NSWindow.StyleMask.unifiedTitleAndToolbar`) |
| Sidebar material | `NSVisualEffectView`, sidebar style |
| Editing font | `NSFont.monospacedSystemFont`, 14pt |
| Editing line height | 1.6x font size |
| Preview font | System font (San Francisco), 15pt |
| Preview line height | 1.7x |
| Preview max width | 680px, centered |
| Canvas horizontal padding | 48pt minimum each side, max content width ~900px |
| Canvas bottom overscroll | Last line can scroll to vertical center |
| Toolbar formatting buttons | 6 max, SF Symbols, no borders, no labels |
| Mode toggle | `NSSegmentedControl`, two segments |
| Mode transition | Cross-dissolve, 150-200ms, scroll position preserved |
| Tab bar | Native `NSWindow` document tabs |
| Auto-save | Native `NSDocument` auto-saving |
| Launch behavior | Restore previous state, or new blank document |
| Min undo depth | 100 operations |
| Current line highlight | `NSColor.textColor` at 0.03 alpha |
| Markdown syntax chars | `NSColor.tertiaryLabelColor` |
