# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**PicoGopher** is a lightweight Gopher protocol browser written in mmBASIC for the Raspberry Pi Pico 2W running PicoMite firmware. It allows browsing vintage Gopher menus on a resource-constrained microcontroller with a graphics LCD display and WiFi connectivity.

- **Language**: mmBASIC (PicoMite dialect)
- **Target Hardware**: Raspberry Pi Pico 2W with graphics LCD display
- **Main File**: `gopher.bas` (~18KB)
- **Network**: RFC 1436 Gopher protocol over TCP/WiFi
- **Configuration**: WiFi via `OPTION WIFI` (persisted in flash), `bookmarks.txt` (user bookmarks)

## Running & Testing

### Development Environment

This is **firmware code** that runs directly on the Pico device - there's no traditional build system. To test:

1. **Upload Files to Device**: Transfer `gopher.bas` and `bookmarks.txt` to your PicoMite device
2. **Configure WiFi**: Run `OPTION WIFI ssid, password` from PicoMite console (persists in flash, only needed once)
3. **Run Program**: In PicoMite console: `RUN "gopher.bas"`

### Testing Strategy

Comprehensive testing plan in **TESTING.md** (3+ hours of tests). Key phases:

- **Phase 1**: Network & Protocol (TCP, WiFi, Gopher requests)
- **Phase 2**: Parser & Display (menu rendering, text display)
- **Phase 3**: Navigation & UI (keyboard input, back button)
- **Phase 4**: Text Viewer (file scrolling, pagination)
- **Phase 5**: Bookmarks (save/load, management)
- **Phase 6**: End-to-End (realistic user workflows)
- **Phase 7**: Stress & Edge Cases (large menus, slow servers, memory limits)

### Public Test Servers

Use these for testing:
```
gopher.floodgap.com:70   - Most reliable, good for basic testing
gopher.quux.org:70       - Alternative server
sdf.org:70               - Large menu with 50+ items (pagination testing)
gopherns.com:70          - Modern Gopher content
```

See **QUICK_START.md** for bookmark setup.

## Architecture & Code Organization

### Program Structure (6 Phases)

The single `gopher.bas` file is organized into logical phases (approximate line ranges):

**Phase 1: Network & Protocol (Lines ~84-260)**
- `InitWiFi()` - WiFi connection check (credentials via `OPTION WIFI`)
- `GopherConnect(host$, port)` - Open TCP client connection
- `GopherSend(selector$)` - Send Gopher request (selector + CRLF)
- `ReadGopherLine(result$)` - Read one line from TCP response buffer (CHR$(0) sentinel for end-of-data)
- `GopherClose()` - Close connection
- `ParseMenuLine()` - Parse RFC 1436 menu line format

**Phase 2: Display & Navigation (Lines ~262-495)**
- `DisplayMenu()` - Render menu to LCD with type indicators, highlights, and horizontal scroll offset
- `DisplayTextPage()` - Render word-wrapped text page to LCD
- `HandleInput()` - Process keyboard input (Up/Down skip info items, Left/Right horizontal scroll, Enter, B, A, ESC, G, Q)
- `PushHistory()` - Save current state to history stack (shifts on overflow)
- `NavigateBack()` - Restore previous menu from history

**Phase 3: Text Viewer (Lines ~515-650)**
- `WrapAndStoreLine(line$)` - Word-wrap a line and store segments into textLines$() array
- `ViewTextFile(host$, selector$, port)` - Fetch and display text file with word wrapping and scrolling

**Phase 4: Bookmarks (Lines ~582-685)**
- `SaveBookmark()` - Save current location to `bookmarks.txt`
- `ShowBookmarks()` - Load and display bookmark list

**Phase 5: Menu Fetcher (Lines ~687-790)**
- `FetchAndDisplayMenu()` - Connect, send request, parse, display all at once
- `NavigateToItem(index)` - Handle selection of menu item (dispatch to viewer/menu/search)

**Phase 6: Search & Address Bar (Lines ~792-870)**
- `SearchGopher()` - Type 7 (search) handler, prompt for query
- `GotoCustomAddress()` - Navigate to user-entered gopher address

**Main Program (Lines ~872-943)**
- `Main()` - Initialize WiFi, fetch default menu, enter main loop
- `FILE_EXISTS()` - Helper to check file existence

### Module Dependencies

```
Main()
  ├─> InitWiFi()
  ├─> FetchAndDisplayMenu()
  │    ├─> GopherConnect()
  │    ├─> GopherSend()
  │    ├─> ReadGopherLine()
  │    ├─> ParseMenuLine()
  │    └─> GopherClose()
  ├─> DisplayMenu()
  ├─> HandleInput()
  │    ├─> NavigateToItem()
  │    │    ├─> ViewTextFile() (Type 0)
  │    │    ├─> FetchAndDisplayMenu() (Type 1)
  │    │    └─> SearchGopher() (Type 7)
  │    ├─> NavigateBack()
  │    ├─> SaveBookmark()
  │    ├─> ShowBookmarks()
  │    └─> GotoCustomAddress()
  └─> [Loop: status timeout check + DisplayMenu + HandleInput]
```

### Key Constants

**Display** (adjust for your LCD):
```basic
SCREEN_WIDTH = 320          ' LCD width in pixels
SCREEN_HEIGHT = 320         ' LCD height in pixels
LINE_HEIGHT = 10            ' Pixels per text line
CHARS_PER_LINE = 40         ' Characters visible per line
LINES_PER_PAGE = 25         ' Menu items displayed per screen
```

**Memory Limits** (tuned for Pico 2W ~100-160KB heap):
```basic
MAX_MENU_ITEMS = 80         ' Items in single menu
MAX_TEXT_LINES = 400        ' Lines in text file (word-wrapped)
MAX_HISTORY = 10            ' Back button depth (shifts on overflow)
MAX_BOOKMARKS = 30          ' Bookmarks in list
TCP_TIMEOUT = 10000         ' Connection timeout (ms)
```

All string arrays use `DIM array$(n) LENGTH m` to allocate only the needed bytes per element (total ~49KB heap).

### mmBASIC Quirks & Constraints

1. **255-Character String Limit**: `ReadGopherLine()` uses LONGSTRING buffer with `LGETSTR$` (lines capped at 255 chars)
2. **256 Bytes Per String Element**: Default `DIM` wastes memory; always use `DIM array$(n) LENGTH m` to limit allocation
3. **String LENGTH Overflow**: Assigning a string longer than the `LENGTH` limit causes a fatal `String too long` error. **Always wrap with `LEFT$(value$, limit)`** before assigning to any LENGTH-constrained variable or array element. This applies to data from network responses, user input, and parsed Gopher lines — any external source can exceed the limit.
4. **No Short-Circuit Boolean Evaluation**: `AND`/`OR` in `IF` or `DO WHILE` evaluate **both sides unconditionally**. Code like `DO WHILE idx >= 0 AND array$(idx) = "x"` will crash with `Error: Dimensions` when `idx` is -1. **Always separate bounds checks from array access** — use `DO WHILE idx >= 0` with `IF array$(idx) <> "x" THEN EXIT DO` inside the loop body.
5. **No File I/O for TCP**: Uses `WEB OPEN TCP CLIENT` / `WEB TCP CLIENT REQUEST` (PicoMite WebMite feature)
6. **No Threading**: Single-threaded main loop
7. **Fixed-Size Arrays**: Pre-declare all arrays at top with CONST sizes
8. **String Concatenation**: Uses `+` operator; watch memory usage for large strings
9. **INKEY$ Timing**: Non-blocking; may need polling in tight loops
10. **ELSE IF vs ELSEIF**: mmBASIC requires `ELSEIF` (one word) or nested `IF` blocks. `ELSE IF` (two words) is a syntax error. Prefer `SELECT CASE` for multi-branch logic.

## Common Development Tasks

### Adding a New Gopher Item Type

1. Update `ParseMenuLine()` to recognize the type character
2. Add case in `NavigateToItem()` to handle selection
3. Create handler subroutine (e.g., `HandleType8()`)
4. Test with TESTING.md Phase 2 & 3 test cases

Example (Type 8 - Telnet placeholder):
```basic
' In NavigateToItem():
CASE "8"  ' Telnet
  PRINT "Telnet support not yet implemented"

' New handler:
SUB HandleType8(selector$, host$, port)
  ' Implementation here
END SUB
```

### Modifying Display Layout

Recalculate constants if changing screen size:
```basic
CHARS_PER_LINE = SCREEN_WIDTH / (FONT_WIDTH_IN_PIXELS)  ' e.g., 320/8 = 40
LINES_PER_PAGE = (SCREEN_HEIGHT - HEADER - FOOTER) / LINE_HEIGHT
```

### Extending Bookmark Features

Current format (tab-delimited):
```
Display Name[TAB]selector[TAB]host[TAB]port
```

To add fields (e.g., category, timestamp), extend `ParseMenuLine()` signature and bookmark file parsing.

### Performance Optimization

**Memory Usage**:
- Reduce array sizes if not all capacity needed
- Trim whitespace from strings: `TRIM$(string$)`
- Consider string indices instead of storing full paths

**Network**:
- Current approach fetches entire menu before display
- Could optimize by streaming display during fetch (but more complex state management)

**String Operations**:
- `INSTR()` searches are O(n); precompute positions if repeated
- Batch `MID$()` operations when possible

### Debugging

Add debug mode constant:
```basic
CONST DEBUG = 1

IF DEBUG THEN
  PRINT "DEBUG: currentHost$ = " + currentHost$
  PRINT "DEBUG: menuCount = " + STR$(menuCount)
ENDIF
```

For serial logging (if available):
```basic
SUB LogDebug(msg$)
  PRINT #UART1, TIME$ + " " + msg$
END SUB
```

## Supported Gopher Item Types

| Type | Name | Handling | Status |
|------|------|----------|--------|
| **0** | Text File | Fetch & display in text viewer with scrolling | ✅ Implemented |
| **1** | Menu/Directory | Fetch & display as menu | ✅ Implemented |
| **3** | Error Message | Display error text for 2 seconds | ✅ Implemented |
| **7** | Search Server | Prompt for query, fetch results as menu | ✅ Implemented |
| **i** | Informational | Display as non-selectable text | ✅ Implemented |
| **5, 9** | Binary Files | Not supported (would need save to SD) | ❌ Future |
| **g, I** | Image Files | Not supported (no image viewer) | ❌ Future |
| **8** | Telnet | Not supported (network complexity) | ❌ Future |

## File Formats

### WiFi Configuration

WiFi credentials are stored in PicoMite flash via `OPTION WIFI ssid, password` (run once from console).

### `bookmarks.txt` (tab-delimited)
```
Display Name[TAB]selector[TAB]host[TAB]port
Floodgap	/	gopher.floodgap.com	70
Quux	/	gopher.quux.org	70
```

### Gopher Menu Response (RFC 1436)
```
[TYPE][NAME][TAB][SELECTOR][TAB][HOST][TAB][PORT]
0About	/about.txt	gopher.example.com	70
1Subdirs	/subdir	gopher.example.com	70
i(info line)	fake	fake	0
.
```

Terminated by period (`.`) on its own line.

## Known Limitations

1. **String Length**: mmBASIC 255-char limit (mitigated by LONGSTRING buffer); arrays use `LENGTH` to save heap
2. **Memory**: ~49KB heap; limited to 80 menu items, 400 text lines (word-wrapped), 30 bookmarks
3. **Media Types**: No image/binary file support
4. **Display**: Monochrome text only with type indicators (no colors)
5. **Network**: Single concurrent connection, basic error handling

## Key Documentation

- **README.md** - Full feature list, usage guide, future enhancements
- **QUICK_START.md** - 5-minute setup guide
- **DEVELOPMENT.md** - Detailed architecture, performance tips, common issues
- **TESTING.md** - Comprehensive test plan (7 phases, 70+ test cases)

## Important Notes for Contributors

### Code Style

- Use `CONST` for all magic numbers
- Name arrays with descriptive plural names: `menuType$()`, `histHost$()`
- Prefix function names with verb: `InitWiFi()`, `FetchAndDisplayMenu()`
- Add comments explaining **WHY**, not **WHAT** the code does
- Use `LOCAL` for function variables to avoid polluting global scope

### Before Making Changes

1. Read the relevant phase in DEVELOPMENT.md
2. Check TESTING.md for related test cases
3. Verify the change doesn't exceed `MAX_*` constants
4. Test with at least one public Gopher server (gopher.floodgap.com recommended)
5. Use TESTING.md checklist to verify related functionality still works

### Error Handling

- Use `ON ERROR IGNORE` / `ON ERROR ABORT` for risky operations
- Check `ERRNUM <> 0` after operations
- Always close TCP connections even on error (use separate cleanup SUB)
- Display user-friendly error messages, not raw error codes

### TCP Connection Safety

- Always call `GopherClose()` to cleanly disconnect
- Implement timeout detection in `GopherConnect()`
- Handle partial responses gracefully in `ReadGopherLine$()`
- Test with slow/unreliable servers (use connection drop test)

## Quick Reference

| Task | File/Lines | Key Functions |
|------|-----------|----------------|
| WiFi Setup | `OPTION WIFI`, `InitWiFi()` | `MM.INFO$(IP ADDRESS)` |
| Fetch Menu | `FetchAndDisplayMenu()` | `GopherConnect/Send/Close` |
| Display Menu | `DisplayMenu()` | Position print `PRINT @(x,y)` |
| Handle Input | `HandleInput()` | `INKEY$` |
| Navigate Items | `NavigateToItem()` | Type dispatch |
| View Text | `ViewTextFile()` | `DisplayTextPage()` |
| Bookmarks | `SaveBookmark()`, `ShowBookmarks()` | File I/O via OPEN/PRINT |
| Go Back | `NavigateBack()` | History stack |

---

**Last Updated**: February 11, 2026
**Version**: 1.0
**Maintained By**: Development Team
