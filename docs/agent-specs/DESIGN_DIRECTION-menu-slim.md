# Design Direction: Menu Bar Simplification
# Companion to: MenuBuilder.swift
# Created: 2026-04-02

## Design Intent

The menu bar should feel like a safety net, not a control center. In a focused markdown editor, the toolbar and keyboard shortcuts handle the high-frequency work. The menu bar exists so users can discover shortcuts, access infrequent operations, and satisfy the macOS expectation that "everything has a menu path." It should never feel overwhelming -- a user who opens any menu should see a short, purposeful list, not a catalog of every possible action.

The current menu has 55+ items across 7 menus. The target is roughly 35 items across 6 menus. Every removal must pass one test: "Can the user still accomplish this task through another discoverable path?"

---

## Analysis: What To Cut and Why

### The Redundancy Principle

The toolbar already provides: Bold, Italic, Strikethrough, Heading Picker (H1-H6 + Paragraph), Bullet List, Numbered List, Link, Inline Code, Code Block, Blockquote, Edit/Markdown toggle, Export (HTML + PDF).

That is 14 toolbar actions. The Format menu currently duplicates all 14 and adds 5 more (Task List, Image, Table, Horizontal Rule, and 6 individual Heading items that the toolbar handles via picker). This duplication is the primary source of bloat.

### The Heading Problem

Six individual heading items (H1 through H6) occupy six lines of the Format menu, each with a keyboard shortcut. This is excessive for a menu. However, the keyboard shortcuts (Cmd+1 through Cmd+6) are genuinely useful for power users and cannot be discovered through the toolbar popup alone. The solution: collapse headings into a submenu. The shortcuts still work identically -- they are registered regardless of visual nesting. The submenu compresses six lines into one, and the heading picker in the toolbar remains the primary interaction path.

### The "Open Folder" Problem

`Open Folder...` dispatches to `documentController.openFolder()` but the sidebar has been removed (MainSplitViewController comment: "The sidebar has been removed"). The SidebarViewController class still exists in the codebase but is no longer wired into the split view. This menu item is a dead end. Remove it.

### The Task List Question

Task List (Cmd+Shift+9) is not in the toolbar. It has a keyboard shortcut. The question is whether it earns a top-level menu slot. My position: yes, but only because it sits alongside Bullet List and Numbered List -- removing it would create a "why is this one missing?" inconsistency that is worse than the extra line. However, it moves into the submenu with the other list types.

---

## Proposed Menu Structure

### Menu 1: Markdown Editor (App Menu) -- NO CHANGES

This is system-managed. Do not touch it.

```
About Markdown Editor
---
Preferences...                          Cmd+,
---
Services                               >
---
Hide Markdown Editor                    Cmd+H
Hide Others                             Cmd+Opt+H
Show All
---
Quit Markdown Editor                    Cmd+Q
```

**Reasoning**: macOS HIG mandates this structure. Users expect it. Zero changes.

---

### Menu 2: File -- 3 ITEMS REMOVED

```
New                                     Cmd+N
New Tab                                 Cmd+T
Open...                                 Cmd+O
Open Recent                             >
---
Close Tab                               Cmd+W
Close All Tabs                          Cmd+Opt+W
---
Save                                    Cmd+S
Save As...                              Cmd+Shift+S
Save All                                Cmd+Opt+S
---
Export as HTML...
Export as PDF...
```

**Removed**:
- **Open Folder... (Cmd+Shift+O)**: Dead feature. The sidebar is removed. Shipping a menu item that opens a folder picker but does nothing visible is worse than having no item at all. If/when folder support returns, the menu item returns with it. Reclaim the Cmd+Shift+O shortcut.
- Note: `Open Recent` stays -- it is an essential macOS document-model feature. The submenu with "Clear Menu" is standard and expected.

**Kept deliberately**:
- **Export as HTML / Export as PDF**: These stay at the File menu level rather than a submenu. Two items do not warrant a submenu. They are infrequent but important, and the flat list is faster to scan than Export > HTML / PDF.
- **New Tab**: Although Cmd+T is somewhat discoverable, removing the menu item would break the File menu convention for tabbed document apps. Keep it.
- **Save All**: Useful for multi-tab workflows. One line, clear purpose.

**Item count**: 12 (down from 15)

---

### Menu 3: Edit -- NO CHANGES

```
Undo                                    Cmd+Z
Redo                                    Cmd+Shift+Z
---
Cut                                     Cmd+X
Copy                                    Cmd+C
Paste                                   Cmd+V
Paste and Match Style                   Cmd+Opt+Shift+V
Select All                              Cmd+A
---
Find                                    >
    Find...                             Cmd+F
    Find and Replace...                 Cmd+Opt+F
    Find Next                           Cmd+G
    Find Previous                       Cmd+Shift+G
    Use Selection for Find              Cmd+E
```

**Reasoning**: This is the standard macOS Edit menu. Every item is expected by users. "Paste and Match Style" is genuinely useful when pasting from rich text sources into a markdown editor. The Find submenu is standard and well-structured. Changing this menu would violate user expectations for zero benefit.

**Item count**: 8 + 5 in submenu (unchanged)

---

### Menu 4: Format -- RESTRUCTURED, NET REDUCTION OF 8 TOP-LEVEL ITEMS

```
Bold                                    Cmd+B
Italic                                  Cmd+I
Strikethrough                           Cmd+Shift+X
Inline Code                             Cmd+`
---
Heading                                 >
    Heading 1                           Cmd+1
    Heading 2                           Cmd+2
    Heading 3                           Cmd+3
    Heading 4                           Cmd+4
    Heading 5                           Cmd+5
    Heading 6                           Cmd+6
---
Bullet List                             Cmd+Shift+8
Numbered List                           Cmd+Shift+7
Task List                               Cmd+Shift+9
Blockquote                              Cmd+Shift+.
Code Block                              Cmd+Shift+C
---
Insert Link...                          Cmd+K
Insert Image...                         Cmd+Shift+I
Insert Table                            Cmd+Opt+T
Insert Horizontal Rule                  Cmd+Shift+-
```

**What changed**:
- **Headings 1-6 collapsed into "Heading" submenu**: This is the single biggest space savings. Six lines become one. The keyboard shortcuts (Cmd+1 through Cmd+6) continue to work -- they are registered on the submenu items and fire regardless of nesting depth. The toolbar heading picker remains the primary visual interaction. The menu is now purely for shortcut discovery and accessibility.

**What stayed and why**:
- **Insert Image, Insert Table, Insert Horizontal Rule**: These are NOT in the toolbar. The menu is their only discoverable path (besides memorizing shortcuts). Removing them would make these features invisible. They stay.
- **Task List**: Sits naturally with Bullet and Numbered list. Removing it creates an odd gap. It stays.
- **Blockquote and Code Block**: Both are in the toolbar, but they logically belong in the "block-level elements" group alongside lists. Keeping them maintains a clean mental model: inline formatting at the top, block-level in the middle, insertions at the bottom.

**Structural logic**: The Format menu now has three clear sections that map to how users think about markdown:
1. **Inline formatting** (wraps selected text): Bold, Italic, Strikethrough, Inline Code
2. **Block formatting** (changes line/paragraph type): Heading, Lists, Blockquote, Code Block
3. **Insertions** (adds new content): Link, Image, Table, Horizontal Rule

**Top-level item count**: 13 (down from 21). Submenu adds 6 heading items, but these are hidden behind one disclosure.

---

### Menu 5: View -- NO CHANGES

```
Editing Mode                            Cmd+Shift+E
Preview Mode                            Cmd+Shift+P
---
Show Line Numbers
Toggle Word Wrap
---
Increase Font Size                      Cmd+=
Decrease Font Size                      Cmd+-
Reset Font Size                         Cmd+0
---
Enter Full Screen                       Cmd+Ctrl+F
```

**Reasoning**: This menu is already lean and well-organized. Every item serves a distinct purpose:
- Mode switching is the top-priority action (placed first)
- Editor chrome toggles are useful preferences that do not warrant a trip to Preferences
- Font size controls are used frequently enough to justify top-level placement (confirmed by your note that they are "very useful")
- Full Screen is expected by macOS convention

Removing anything here would hide useful functionality without meaningful simplification. 8 items is not bloated.

**Item count**: 8 (unchanged)

---

### Menu 6: Window -- 9 TAB ITEMS REMOVED, 2 MANAGEMENT ITEMS REMOVED

```
Minimize                                Cmd+M
Zoom
---
Show Next Tab                           Ctrl+Tab
Show Previous Tab                       Ctrl+Shift+Tab
---
Bring All to Front
```

**Removed**:
- **Tab 1 through Tab 9 (Ctrl+1 through Ctrl+9)**: These nine items create massive visual noise for marginal utility. The shortcuts still work -- they are registered and functional. But listing "Tab 1" through "Tab 9" in the menu is not helping anyone discover these shortcuts because the items are not labeled with actual document names (they just say "Tab 1", "Tab 2", etc.). macOS also auto-populates the Window menu with open document windows, making these redundant with the system-provided window list.
- **Move Tab to New Window**: Niche operation available via right-clicking the tab itself. Does not earn a menu slot in a lean editor.
- **Merge All Windows**: Even more niche. Available via the Window menu that macOS auto-manages if needed. Power users who need this will find it.

**Kept deliberately**:
- **Show Next/Previous Tab**: These are the primary tab navigation shortcuts. They must be discoverable via the menu because Ctrl+Tab is not as universally known as Cmd+Tab.
- **Bring All to Front**: Standard macOS convention. One line, expected.

**Implementation note**: The keyboard shortcuts for Ctrl+1 through Ctrl+9 should still be registered even though the menu items are removed. Register them as key equivalents on hidden menu items (items with `isHidden = true`) or via `NSEvent.addLocalMonitorForEvents`. The shortcuts work; they just do not need menu real estate.

**Item count**: 5 (down from 16)

---

### Menu 7: Help -- NO CHANGES

```
Markdown Editor Help                    Cmd+?
Markdown Syntax Guide
```

**Reasoning**: Two items. Both useful. The Syntax Guide is a clever feature that opens a reference document inside the editor itself. This is exactly the kind of contextual help a markdown editor should provide. No changes.

**Item count**: 2 (unchanged)

---

## Summary of Changes

| Menu              | Before | After | Delta |
|-------------------|--------|-------|-------|
| App               | 9      | 9     | 0     |
| File              | 15     | 12    | -3    |
| Edit              | 8+5    | 8+5   | 0     |
| Format            | 21     | 13+6  | -8 top-level |
| View              | 8      | 8     | 0     |
| Window            | 16     | 5     | -11   |
| Help              | 2      | 2     | 0     |
| **Total top-level** | **79** | **57** | **-22** |

The perceived reduction is even greater because the two submenus (Heading, Find) tuck away 11 items that were previously occupying primary visual space.

---

## What We Are NOT Doing

### Not removing the Format menu entirely
Some might argue: "The toolbar handles formatting, so kill the Format menu." Wrong. The menu bar is the canonical place for shortcut discovery on macOS. A user who wants to learn the shortcut for blockquote should be able to find it in the menu. The menu is not for clicking -- it is for learning. It stays, but leaner.

### Not collapsing Export into a submenu
Two items (HTML, PDF) do not warrant a submenu. The overhead of "File > Export > HTML" is one extra interaction versus "File > Export as HTML..." -- and the visual cost of a submenu disclosure for just two items makes the menu feel bureaucratic.

### Not collapsing Lists into a submenu
Three list types (Bullet, Numbered, Task) do not warrant a submenu. A submenu would add interaction cost and hide items that are logically siblings of Blockquote and Code Block. They belong together as a visible group.

### Not adding a "Markdown" or "Insert" menu
Splitting Format into "Format" and "Insert" would add a menu bar item to save a few lines within one menu. Net result: more visual complexity at the top level for marginal benefit within a single menu. One menu with three clear sections is better than two menus with unclear boundaries.

### Not removing Paste and Match Style
In a markdown editor where users frequently paste from web pages, Cmd+Opt+Shift+V to strip formatting is essential. This is not bloat.

---

## Implementation Notes

1. **Heading submenu**: Create with `NSMenu(title: "Heading")` as a submenu of a single `NSMenuItem`. The six heading items move inside it with their existing selectors and key equivalents. Keyboard shortcuts work identically -- macOS resolves key equivalents from submenus automatically.

2. **Tab shortcut preservation**: Remove the nine Tab 1-9 `NSMenuItems` from `buildWindowMenu()`. To keep Ctrl+1 through Ctrl+9 functional, add them as hidden menu items (set `isHidden = true` on the `NSMenuItem`) in the Window menu, or handle them via `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` in the window controller. The hidden menu item approach is simpler and respects the responder chain.

3. **Open Folder removal**: Delete the `openFolderItem` block from `buildFileMenu()`. The `openFolder(_:)` method on AppDelegate and DocumentController can remain in code (dormant) for potential future use, but the menu item must go.

4. **Move Tab to New Window / Merge All Windows removal**: Simply remove these two `addItem` calls from `buildWindowMenu()`. The underlying `NSWindow` methods remain available programmatically if needed.

5. **No selector or protocol changes required**: All existing `FormattingResponder`, `ViewModeActions`, and system selectors remain unchanged. This is purely a menu structure change.
