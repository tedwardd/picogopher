# PicoGopher - Development Guide

This document provides guidance for developers extending or modifying the PicoGopher Gopher client.

## Architecture Overview

### Program Structure

```
gopher.bas (Main Program)
├── Configuration & Constants (Lines 1-43)
├── Global Variables (Lines 45-119)
├── Phase 1: Network & Protocol (Lines 121-332)
│   ├── InitWiFi()
│   ├── GopherConnect/Send/Close()
│   ├── ReadGopherLine()
│   ├── ShowError$()
│   └── ParseMenuLine()
├── Phase 2: Display & Navigation (Lines 334-768)
│   ├── DisplayMenu()
│   ├── UpdateMenuCursor()
│   ├── DisplayTextPage()
│   ├── HandleInput()
│   ├── PushHistory()
│   └── NavigateBack()
├── Phase 3: Text Viewer (Lines 770-928)
│   ├── WrapAndStoreLine()
│   └── ViewTextFile()
├── Phase 4: Bookmarks (Lines 930-1050)
│   ├── SaveBookmark()
│   └── ShowBookmarks()
├── Phase 4B: Recently Visited (Lines 1052-1147)
│   ├── PushRecent()
│   └── ShowRecent()
├── Phase 4C: Help (Lines 1149-1184)
│   └── ShowHelp()
├── Phase 5: Menu Fetcher (Lines 1186-1368)
│   ├── FetchAndDisplayMenu()
│   └── NavigateToItem()
├── Phase 6: Search & Address Bar (Lines 1370-1499)
│   ├── PushSearchHistory()
│   ├── SearchGopher()
│   └── GotoCustomAddress()
└── Main Program & Entry (Lines 1501-1564)
    ├── Main()
    └── FILE_EXISTS()
```

## Module Dependencies

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

## Code Style & Conventions

### Naming Conventions

```basic
' Variables
CONST CONSTANT_NAME          ' All caps with underscores
LOCAL localVariable           ' camelCase for locals
globalVariable                ' camelCase for globals (avoid)

' Functions and Subroutines
FUNCTION GetValue$()         ' Return type suffix: $=string, no suffix=numeric
SUB InitializeSystem()       ' Verb + Noun pattern

' Arrays
DIM menuType$(100)           ' Array suffix: $ for string arrays
DIM menuCount AS INTEGER     ' Explicit type declaration where possible
```

### Code Organization

```basic
' Comments for major sections
' ================================================
' SECTION NAME
' ================================================

' Subsection comments
' ------- Subsection -------

SUB FunctionName()
  ' Function description

  ' Comments for complex logic
  LOCAL var1, var2

  ' Implementation
END SUB
```

### mmBASIC Specifics

**String Constants:**
```basic
' Define at top of program
CONST CRLF$ = CHR$(13) + CHR$(10)
CONST TAB$ = CHR$(9)

' Use in code
PRINT #1, data$ + CRLF$
```

**Array Sizes:**
```basic
' Define as constants for easy modification
CONST MAX_MENU_ITEMS = 100
DIM menuType$(MAX_MENU_ITEMS)

' Use constants in bounds checking
IF menuCount >= MAX_MENU_ITEMS THEN EXIT DO
```

**Error Handling:**
```basic
' Wrap risky operations
ON ERROR IGNORE
OPEN "file.txt" FOR INPUT AS #1
CLOSE #1
ON ERROR ABORT

' Check for errors after operations
IF ERRNUM <> 0 THEN
  PRINT "Error: " + ERRMSG$
ENDIF
```

## Common Development Tasks

### Adding a New Menu Item Type

1. **Add to ParseMenuLine()** - Ensure correct parsing
2. **Add to NavigateToItem()** - Handle selection
3. **Implement handler SUB** - e.g., HandleType8()
4. **Update display** - Show type indicator if needed
5. **Add test cases** - In TESTING.md

**Example: Add type 8 (Telnet) support**

```basic
' In NavigateToItem():
CASE "8"  ' Telnet
  PushHistory(currentHost$, currentSelector$, currentPort)
  TelnetToHost(menuHost$(index), menuPort(index))

' New subroutine:
SUB TelnetToHost(host$, port)
  CLS
  PRINT @(10, 100) "Telnet to " + host$ + ":" + STR$(port)

  ' Implementation would require serial/network passthrough
  ' For now, show message
  PRINT @(10, 120) "Telnet support not yet implemented"
  PAUSE 2000
END SUB
```

### Modifying Display Layout

Display constants:
```basic
CONST SCREEN_WIDTH = 320       ' Change for different LCD
CONST SCREEN_HEIGHT = 320
CONST LINE_HEIGHT = 12         ' Pixel height per text line
CONST CHARS_PER_LINE = 40      ' Characters visible per line
CONST LINES_PER_PAGE = 21      ' Menu items per screen
```

**Recalculate if changing screen size:**

```
CHARS_PER_LINE = SCREEN_WIDTH / (FONT_WIDTH_IN_PIXELS)
LINES_PER_PAGE = (SCREEN_HEIGHT - HEADER - FOOTER) / LINE_HEIGHT
```

### Adding Configuration Options

WiFi is configured via `OPTION WIFI ssid, password` from the PicoMite console (persists in flash).

To add app-level configuration (e.g., default host, display settings), create a `settings.txt` file:
```
default_host
default_port
screen_width
screen_height
```

Read it during initialization:
```basic
SUB LoadSettings()
  IF FILE_EXISTS("settings.txt") THEN
    OPEN "settings.txt" FOR INPUT AS #98
    LINE INPUT #98, DEFAULT_HOST$
    LINE INPUT #98, p$
    DEFAULT_PORT = VAL(p$)
    CLOSE #98
  ENDIF
END SUB
```

### Extending Bookmark Features

**Current bookmark format:**
```
Display Name[TAB]selector[TAB]host[TAB]port
```

**To add categories:**
```
Display Name[TAB]selector[TAB]host[TAB]port[TAB]category
```

**To add last-visited date:**
```
Display Name[TAB]selector[TAB]host[TAB]port[TAB]2025-02-10
```

**Update ParseMenuLine():**
```basic
' Add more parameters to function signature
SUB ParseMenuLine(line$, itemType$, display$, selector$, host$, port, category$)
  ' ... existing parsing ...
  ' Add parsing for additional fields
END SUB
```

## Performance Optimization

### Memory Usage

**Current allocation (using LENGTH to minimize heap):**
```
menuType$(80) LENGTH 1      =    160 bytes
menuDisp$(80) LENGTH 80     =  6,480 bytes
menuSel$(80) LENGTH 128     = 10,320 bytes
menuHost$(80) LENGTH 64     =  5,200 bytes
menuPort(80)                =    640 bytes
textLines$(400) LENGTH 40   = 16,400 bytes
histHost$(10) LENGTH 64     =    650 bytes
histSelector$(10) LENGTH 128=  1,290 bytes
histPort(10)                =     80 bytes
tcpResponseBuffer%(1000)    =  8,000 bytes
searchHistQuery$(5) LEN 128 =    645 bytes
searchHistHost$(5) LEN 64   =    325 bytes
searchHistPort(5)           =     40 bytes
recentDisp$(10) LENGTH 40   =    410 bytes
recentHost$(10) LENGTH 64   =    650 bytes
recentSel$(10) LENGTH 128   =  1,290 bytes
recentPort(10)              =     80 bytes
Total ≈ 52 KB (of ~100-160 KB available)
```

**CRITICAL**: Always use `DIM array$(n) LENGTH m` for string arrays.
Default `DIM array$(n)` allocates 256 bytes per element, which will
quickly exhaust the Pico 2W's ~100-160 KB heap.

**Optimization strategies:**

1. **Reduce array sizes** if not needed:
```basic
CONST MAX_MENU_ITEMS = 50  ' Instead of 80
```

2. **Reduce LENGTH** if content allows:
```basic
DIM menuDisp$(80) LENGTH 30  ' Shorter display names
```

3. **Compress strings** - Remove leading/trailing spaces:
```basic
display$ = TRIM$(display$)
```

### Network Performance

**Current approach - Fetch entire menu:**
```basic
DO
  line$ = ReadGopherLine$()
  IF line$ = "." THEN EXIT DO
  ' Parse and store
LOOP
```

**Optimization - Stream display:**
```basic
DO
  line$ = ReadGopherLine$()
  IF line$ = "." THEN EXIT DO

  ' Parse and display immediately
  DisplayMenuLine(line$, lineNum)
  lineNum = lineNum + 1
LOOP
```

### String Operations

**Optimize ParseMenuLine():**

```basic
' Current approach: Find all tabs one by one
tabPos1 = INSTR(line$, TAB$)
tabPos2 = INSTR(remainder$, TAB$)
' ... inefficient for long strings

' Better: Use MID$ more efficiently
FUNCTION FindFieldStart(line$, fieldNum, TAB$)
  LOCAL pos = 1, field = 0
  DO
    pos = INSTR(pos, line$, TAB$)
    IF pos = 0 THEN RETURN -1
    field = field + 1
    IF field = fieldNum THEN RETURN pos
    pos = pos + 1
  LOOP
END FUNCTION
```

## Testing During Development

### Test Framework

Create a test subroutine:
```basic
SUB TestParseMenuLine()
  LOCAL line$, type$, disp$, sel$, host$, port

  ' Test 1: Standard type 0
  line$ = "0About	/about	gopher.example.com	70"
  ParseMenuLine(line$, type$, disp$, sel$, host$, port)

  ASSERT type$ = "0", "Type parsing failed"
  ASSERT disp$ = "About", "Display parsing failed"
  ASSERT sel$ = "/about", "Selector parsing failed"
  ASSERT host$ = "gopher.example.com", "Host parsing failed"
  ASSERT port = 70, "Port parsing failed"

  PRINT "TestParseMenuLine PASSED"
END SUB

' Simple assertion
SUB ASSERT(condition, message$)
  IF NOT condition THEN
    PRINT "ASSERTION FAILED: " + message$
    STOP
  ENDIF
END SUB
```

### Debug Output

Add debug mode constant:
```basic
CONST DEBUG = 1

' In code:
IF DEBUG THEN
  PRINT "DEBUG: menuCount = " + STR$(menuCount)
  PRINT "DEBUG: currentHost$ = " + currentHost$
ENDIF
```

### Logging

Create simple log file:
```basic
SUB LogDebug(message$)
  IF FILE_EXISTS("debug.log") THEN
    OPEN "debug.log" FOR APPEND AS #95
  ELSE
    OPEN "debug.log" FOR OUTPUT AS #95
  ENDIF
  PRINT #95, TIME$ + " " + message$
  CLOSE #95
END SUB
```

## Common Issues & Solutions

### Issue: Strings Longer than 255 Characters

**Symptom**: Menu item names cut off, selector truncated

**Solution**: Use chunked reading in ReadGopherLine$():
```basic
FUNCTION ReadGopherLine$()
  LOCAL buffer$ = "", chunk$ = ""

  DO
    ' Read in 200-char chunks
    chunk$ = INPUT$(200, #1)
    IF chunk$ = "" THEN EXIT DO

    buffer$ = buffer$ + chunk$

    ' Stop if we have CRLF
    IF RIGHT$(buffer$, 2) = CRLF$ THEN
      RETURN LEFT$(buffer$, LEN(buffer$) - 2)
    ENDIF

    ' Safety limit
    IF LEN(buffer$) >= 500 THEN
      RETURN LEFT$(buffer$, 500)
    ENDIF
  LOOP

  RETURN buffer$
END FUNCTION
```

### Issue: TCP Connection Timeouts

**Symptom**: "Loading menu..." appears indefinitely

**Solution**: Add timeout detection
```basic
SUB GopherConnect(host$, port)
  ON ERROR IGNORE

  LOCAL startTime = TIMER()
  WEB OPEN TCP CLIENT host$, port

  ' Check timeout
  IF (TIMER() - startTime) > TCP_TIMEOUT THEN
    PRINT "Connection timeout to " + host$
    EXIT SUB
  ENDIF

  tcpConnected = 1
  ON ERROR ABORT
END SUB
```

### Issue: Menu Display Artifacts

**Symptom**: Text overlapping, corrupted display

**Solution**: Always clear screen before redraw
```basic
SUB DisplayMenu()
  CLS  ' Critical: Clear before drawing

  ' Draw content
  ' ... rest of display code
END SUB
```

### Issue: Memory Exhaustion

**Symptom**: Program crashes with vague errors

**Solution**: Monitor array usage
```basic
IF menuCount >= MAX_MENU_ITEMS THEN
  PRINT "Menu too large (limit: " + STR$(MAX_MENU_ITEMS) + ")"
  ' Stop parsing additional items
  EXIT DO
ENDIF
```

## Extending to New Features

### Add Color Support

```basic
' If LCD supports color
CONST COLOR_SELECTED = RGB(255, 0, 0)    ' Red highlight
CONST COLOR_TEXT = RGB(0, 0, 0)          ' Black text
CONST COLOR_BACKGROUND = RGB(255, 255, 255)  ' White bg

SUB DisplayMenuWithColor()
  ' Use COLOUR or appropriate LCD commands
  ' SETCURSOR color_mode
  ' ... modify display code to use colors
END SUB
```

### Add Serial Console Support

```basic
' For debugging via serial
SUB PrintDebug(message$)
  PRINT message$  ' Console
  PRINT #UART1, message$  ' Serial output (if available)
END SUB
```

### Add SD Card Bookmark Import

```basic
SUB ImportBookmarksFromSD()
  IF FILE_EXISTS("sd:/bookmarks.txt") THEN
    OPEN "sd:/bookmarks.txt" FOR INPUT AS #94

    DO WHILE NOT EOF(#94)
      LINE INPUT #94, line$
      OPEN "bookmarks.txt" FOR APPEND AS #97
      PRINT #97, line$
      CLOSE #97
    LOOP

    CLOSE #94
  ENDIF
END SUB
```

## Performance Profiling

### Measure Operation Time

```basic
SUB MeasurePerformance()
  LOCAL startTime = TIMER()

  ' Operation to measure
  FetchAndDisplayMenu()

  LOCAL elapsed = TIMER() - startTime
  PRINT "Time: " + STR$(elapsed) + "ms"
END SUB
```

### Identify Bottlenecks

Add timing to each phase:
```basic
SUB FetchAndDisplayMenu()
  LOCAL t1 = TIMER()
  GopherConnect(currentHost$, currentPort)
  PRINT "Connect: " + STR$(TIMER() - t1) + "ms"

  LOCAL t2 = TIMER()
  GopherSend(currentSelector$)
  PRINT "Send: " + STR$(TIMER() - t2) + "ms"

  ' ... parse lines ...

  LOCAL t3 = TIMER()
  GopherClose()
  PRINT "Close: " + STR$(TIMER() - t3) + "ms"
END SUB
```

## Version Control & Documentation

### Code Comments Best Practices

```basic
' Good comment: explains WHY, not WHAT
' We limit to 100 items because displaying more causes
' text to scroll off screen on 320x320 LCD
CONST MAX_MENU_ITEMS = 100

' Bad comment: restates the obvious code
' Increment menuCount
menuCount = menuCount + 1
```

### Function Documentation

```basic
' FetchAndDisplayMenu() - Retrieve and render Gopher menu
'
' Description:
'   Connects to the Gopher server at currentHost$:currentPort,
'   sends the currentSelector$, parses the response into menu
'   items, and displays them on screen.
'
' Depends On:
'   GopherConnect(), GopherSend(), ReadGopherLine(),
'   ParseMenuLine(), GopherClose()
'
' Modifies:
'   menuType$(), menuDisp$(), menuSel$(), menuHost$(),
'   menuPort(), menuCount, selectedIndex, pageStart, pageEnd
'
' Errors:
'   Returns gracefully on connection timeout or server error
'
' Example:
'   currentHost$ = "gopher.example.com"
'   currentSelector$ = "/menu"
'   currentPort = 70
'   FetchAndDisplayMenu()
'
SUB FetchAndDisplayMenu()
  ' Implementation...
END SUB
```

## Release Checklist

Before releasing a new version:

- [ ] All tests in TESTING.md pass
- [ ] No crashes or memory errors
- [ ] Error messages clear and helpful
- [ ] Code compiles without warnings
- [ ] Comments up-to-date
- [ ] README.md accurate
- [ ] bookmarks.txt format documented
- [ ] config.txt template provided
- [ ] Version number updated
- [ ] Changelog created (optional)

## Future Roadmap

### Short Term (v1.1) -- DONE
- [x] Better error messages with recovery options
- [x] Search history feature
- [x] Recently visited list

### Short Term (v1.2) -- DONE
- [x] Flicker-free scrolling (replace CLS with in-place overwriting)
- [x] Differential cursor updates for Up/Down navigation
- [x] Padded line rendering across all screens

### Short Term (v1.3/1.3.1) -- DONE
- [x] Edge-scrolling past first/last selectable link to reveal info text
- [x] Consistent multi-line scroll jumps for edge-scrolling and link navigation

### Medium Term (v1.4)
- [ ] Image file support (type g)
- [ ] Binary file download to SD
- [ ] Menu caching on SD card

### Long Term (v2.0)
- [ ] Multiple simultaneous connections
- [ ] Incremental menu loading
- [ ] Color UI support
- [ ] Configuration menu (no file edit needed)

---

**Last Updated**: February 12, 2026
**Maintained By**: Development Team
