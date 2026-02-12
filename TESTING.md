# PicoGopher - Testing & Verification Plan

This document outlines the comprehensive testing strategy for the PicoGopher Gopher client.

## Test Phases Overview

| Phase | Focus | Duration | Status |
|-------|-------|----------|--------|
| Phase 1 | Network & Protocol | 30 min | Not Started |
| Phase 2 | Parser & Display | 30 min | Not Started |
| Phase 3 | Navigation & UI | 30 min | Not Started |
| Phase 4 | Text Viewer | 20 min | Not Started |
| Phase 5 | Bookmarks | 20 min | Not Started |
| Phase 6 | End-to-End | 30 min | Not Started |
| Phase 7 | Stress & Edge Cases | 30 min | Not Started |

**Total Estimated Time**: ~3 hours

---

## Phase 1: Network & Protocol Testing

### 1.1 WiFi Connection Setup

**Objective**: Verify WiFi initialization and connection

**Prerequisites**:
- PicoMite device with WiFi capability
- SSID and password configured in `config.txt`
- Device within WiFi range

**Test Cases**:

```
TEST 1.1.1: WiFi Connection Success
  Steps:
    1. Edit config.txt with valid SSID and password
    2. Run: RUN "gopher.bas"
    3. Wait for "Connecting to WiFi..." message
    4. Wait for "Connected!" message
  Expected: Device connects without errors
  Pass Criteria: "Connected!" appears on screen

TEST 1.1.2: WiFi Configuration Error Handling
  Steps:
    1. Edit config.txt with invalid SSID/password
    2. Run program
    3. Observe error message
  Expected: Error message or timeout handling
  Pass Criteria: Program doesn't crash, displays error message

TEST 1.1.3: WiFi Default Fallback
  Steps:
    1. Delete or corrupt config.txt
    2. Run program
  Expected: Program uses default credentials or prompts user
  Pass Criteria: Graceful handling (either connects or displays usage)
```

### 1.2 TCP Connection Handler

**Objective**: Verify TCP client connection to Gopher servers

**Prerequisites**:
- Device is WiFi connected
- gopher.floodgap.com is accessible (port 70)

**Test Cases**:

```
TEST 1.2.1: TCP Connection Success
  Steps:
    1. Run program
    2. Observe initial menu fetch from DEFAULT_HOST$
    3. Check that TCP connection completes
  Expected: Menu appears on screen
  Pass Criteria: Menu displays without timeout

TEST 1.2.2: TCP Connection Timeout
  Steps:
    1. Configure invalid server (e.g., 192.0.2.1:70 - test-net address)
    2. Run program
    3. Observe timeout behavior
  Expected: Program handles timeout gracefully
  Pass Criteria: "Timeout" or "Could not connect" message after ~10 seconds
             Program remains responsive after timeout

TEST 1.2.3: TCP Connection Refused
  Steps:
    1. Use valid IP but non-Gopher port (e.g., 8080)
    2. Attempt connection
  Expected: Connection refused error
  Pass Criteria: Error message displays, program recovers

TEST 1.2.4: Multiple Connections (Sequential)
  Steps:
    1. Navigate from gopher.floodgap.com
    2. Select item that points to gopher.quux.org
    3. Verify new connection to different host
    4. Go back (navigate to first server again)
  Expected: Multiple TCP connections work correctly
  Pass Criteria: Can connect to multiple servers sequentially
```

### 1.3 TCP Send & Receive

**Objective**: Verify Gopher request/response protocol

**Test Cases**:

```
TEST 1.3.1: Root Menu Request
  Steps:
    1. Connect to gopher.floodgap.com
    2. Send empty selector ""
    3. Receive menu response
  Expected: Valid Gopher menu appears
  Pass Criteria: Menu items display with types and selectors

TEST 1.3.2: Selector Request
  Steps:
    1. From Floodgap root, select item with selector "/info"
    2. Observe new menu or text display
  Expected: Correct content for selected selector
  Pass Criteria: Content matches expected selector path

TEST 1.3.3: Lastline Detection
  Steps:
    1. Receive complete Gopher response
    2. Check for "." (period) lastline terminator
  Expected: Menu stops reading at lastline
  Pass Criteria: Menu ends at "." character, no extra items
```

---

## Phase 2: Parser & Display Testing

### 2.1 Menu Line Parsing

**Objective**: Verify Gopher menu line parsing (RFC 1436)

**Test Menu Lines**:

```
Standard Gopher Menu Line Formats:

TYPE 0 (Text File):
0About this server	/about.txt	gopher.floodgap.com	70

TYPE 1 (Menu):
1Subdirectories	/subdir	gopher.floodgap.com	70

TYPE 3 (Error):
3Error message	fake	fake	0

TYPE i (Info):
iWelcome to our server!	fake	fake	0

TYPE 7 (Search):
7Search our files	/search	gopher.example.com	70

Edge Cases:

Very Long Display Name (255 chars):
0This is a very long display name that will test string truncation and parsing of extremely long menu item descriptions which should still be handled correctly by the parser	/long	gopher.example.com	70

Missing Fields:
0Malformed line	(no tabs)

Missing Port:
0File	/select	gopher.example.com

Extra Spaces:
1  Spaces in name  	/select	gopher.example.com	70
```

**Test Cases**:

```
TEST 2.1.1: Type 0 (Text File) Parsing
  Input: 0About this server	/about.txt	gopher.floodgap.com	70
  Expected Parse:
    itemType$ = "0"
    display$ = "About this server"
    selector$ = "/about.txt"
    host$ = "gopher.floodgap.com"
    port = 70

TEST 2.1.2: Type 1 (Menu) Parsing
  Input: 1Subdirectories	/subdir	gopher.floodgap.com	70
  Expected Parse:
    itemType$ = "1"
    display$ = "Subdirectories"
    selector$ = "/subdir"
    host$ = "gopher.floodgap.com"
    port = 70

TEST 2.1.3: Type i (Info) Parsing
  Input: iWelcome to our server!	fake	fake	0
  Expected Parse:
    itemType$ = "i"
    display$ = "Welcome to our server!"
    (selector, host, port ignored for type i)

TEST 2.1.4: Missing Port
  Input: 0File	/select	gopher.example.com
  Expected: Port defaults to 70
  Pass Criteria: port = 70 after parsing

TEST 2.1.5: Malformed Line (No Tabs)
  Input: 0Just a name without tabs
  Expected: Graceful handling
  Pass Criteria: selector$ and host$ set to defaults
                No parser crash

TEST 2.1.6: Long Display Name
  Input: 0[255-char string]	/long	gopher.example.com	70
  Expected: String truncated or displayed as "..."
  Pass Criteria: Parser doesn't crash on long strings
```

### 2.2 Menu Display Rendering

**Objective**: Verify menu renders correctly on screen

**Test Cases**:

```
TEST 2.2.1: Empty Menu Display
  Steps:
    1. Initialize menu with 0 items
    2. Call DisplayMenu()
  Expected: Title bar and status bar visible
  Pass Criteria: Screen shows "PicoGopher - [host]" without errors

TEST 2.2.2: Single Item Menu
  Steps:
    1. Add one item to menu
    2. Display menu
  Expected: One item displayed with selection highlight
  Pass Criteria: Item visible with correct indentation

TEST 2.2.3: Multi-Item Menu (10 items)
  Steps:
    1. Add 10 items to menu array
    2. Call DisplayMenu()
    3. Verify all items visible
  Expected: All 10 items visible on screen
  Pass Criteria: No scrolling needed for 10 items
             selectedIndex=0 highlighted at top

TEST 2.2.4: Large Menu (50 items)
  Steps:
    1. Add 50 items to menu
    2. Display starting from item 0
    3. Move selection down
    4. Verify pagination/scrolling
  Expected: Only visible items displayed
             Page scrolls as selection moves
  Pass Criteria: Display updates correctly for large menus
             No screen artifacts

TEST 2.2.5: Menu with Long Item Names
  Steps:
    1. Add item with 80+ character display name
    2. Display menu
  Expected: Long name truncated with "..."
  Pass Criteria: Text doesn't overflow screen width
             Truncation shows "..." indicator

TEST 2.2.6: Menu Item Types Display
  Steps:
    1. Add mixed item types (0, 1, 3, i, 7)
    2. Display menu
  Expected: All types display correctly
  Pass Criteria: Types visible (prefixed or color-coded)
             Info items non-highlighted/non-selectable
```

---

## Phase 3: Navigation & UI Testing

### 3.1 Keyboard Navigation

**Objective**: Verify arrow key navigation works correctly

**Test Cases**:

```
TEST 3.1.1: Arrow Up Navigation
  Steps:
    1. Display menu with 5 items
    2. Start with selectedIndex = 3
    3. Press Up arrow 3 times
  Expected: Selection moves to index 0
  Pass Criteria: Highlight moves with each key press
             selectedIndex = 0 at top

TEST 3.1.2: Arrow Down Navigation
  Steps:
    1. Display menu with 5 items
    2. Start with selectedIndex = 0
    3. Press Down arrow 5 times
  Expected: Selection reaches last item (index 4)
  Pass Criteria: Highlight moves down
             Doesn't go past last item

TEST 3.1.3: Boundary Conditions (Up)
  Steps:
    1. Start with selectedIndex = 0
    2. Press Up arrow repeatedly
  Expected: Selection stays at 0
  Pass Criteria: No negative index
             No screen artifacts

TEST 3.1.4: Boundary Conditions (Down)
  Steps:
    1. Start with selectedIndex = menuCount - 1
    2. Press Down arrow repeatedly
  Expected: Selection stays at last index
  Pass Criteria: Doesn't exceed menuCount
             Display remains stable

TEST 3.1.5: Page Scrolling (Large Menu)
  Steps:
    1. Load 50-item menu
    2. Navigate down past LINES_PER_PAGE items
  Expected: Display scrolls, keeping selected item visible
  Pass Criteria: Selected item always visible
             Smooth scrolling as navigation continues

TEST 3.1.6: Rapid Key Presses
  Steps:
    1. Quickly press down arrow 20 times
    2. Then press up arrow 10 times
  Expected: Navigation keeps up with input
  Pass Criteria: No missed key presses
             No display lag or artifacts
```

### 3.2 Edge Scrolling

**Objective**: Verify scrolling past first/last selectable link reveals info text

**Prerequisites**:
- A Gopher server with info text above and/or below selectable links (e.g., hngopher.com)

**Test Cases**:

```
TEST 3.2.1: Edge-Scroll Down Past Last Link
  Steps:
    1. Load a menu with info text (type i) after the last selectable link
    2. Navigate down to the last selectable link
    3. Press Down arrow again
  Expected: Page scrolls to reveal trailing info text
  Pass Criteria: Selected link stays on screen
             Info text below becomes visible
             Scroll jump is consistent with normal link-to-link navigation

TEST 3.2.2: Edge-Scroll Up Past First Link
  Steps:
    1. Load a menu with info text (type i) before the first selectable link
    2. Navigate up to the first selectable link
    3. Press Up arrow again
  Expected: Page scrolls to reveal leading info text (header)
  Pass Criteria: Selected link stays on screen
             Info text above becomes visible
             Scroll jump is consistent with normal link-to-link navigation

TEST 3.2.3: Edge-Scroll Stops at Menu Boundary
  Steps:
    1. Edge-scroll down until all trailing info text is visible
    2. Press Down arrow again
  Expected: No further scrolling (page already shows end of menu)
  Pass Criteria: Display remains stable
             No blank lines or artifacts

TEST 3.2.4: Edge-Scroll Does Not Affect Normal Navigation
  Steps:
    1. Navigate between selectable links on the same page
    2. Verify fast 2-line cursor update (no full redraw)
  Expected: Normal up/down between visible links uses fast cursor update
  Pass Criteria: Only old and new cursor lines repainted
             No flicker or full page redraw

TEST 3.2.5: New Menu Resets Page Position
  Steps:
    1. Edge-scroll to an offset position
    2. Select a link to navigate to a new menu
    3. Verify new menu starts at the top
  Expected: pageStart resets to 0 on new menu load
  Pass Criteria: First items visible at top of screen
             No stale scroll position from previous menu
```

### 3.3 Menu Item Selection

**Objective**: Verify Enter key selects items correctly

**Test Cases**:

```
TEST 3.2.1: Select Text File (Type 0)
  Steps:
    1. Navigate to type 0 item
    2. Press Enter
  Expected: Text viewer opens
  Pass Criteria: ViewTextFile() called with correct selector
             Text displays with scrolling

TEST 3.2.2: Select Menu (Type 1)
  Steps:
    1. Navigate to type 1 item
    2. Press Enter
  Expected: New menu fetches and displays
  Pass Criteria: FetchAndDisplayMenu() called
             New host/selector loaded
             Previous menu saved to history

TEST 3.2.3: Select Info Item (Type i)
  Steps:
    1. Try to select informational item
    2. Press Enter
  Expected: Nothing happens (non-selectable)
  Pass Criteria: No navigation occurs
             Screen remains unchanged

TEST 3.2.4: Select Error Item (Type 3)
  Steps:
    1. Navigate to type 3 (error) item
    2. Press Enter
  Expected: Error message displays for 2 seconds
  Pass Criteria: Error text visible
             Auto-returns to menu after pause

TEST 3.2.5: Select Search Item (Type 7)
  Steps:
    1. Navigate to type 7 (search) item
    2. Press Enter
  Expected: Search prompt appears
  Pass Criteria: "Enter search query:" displayed
             Keyboard input accepted
```

### 3.4 History & Back Navigation

**Objective**: Verify back button and history stack

**Test Cases**:

```
TEST 3.3.1: Single Back (2 levels deep)
  Steps:
    1. Start at gopher.floodgap.com root
    2. Select directory → navigate (press Enter)
    3. Press 'B' for back
  Expected: Return to root menu
  Pass Criteria: currentHost$, currentSelector$, currentPort restored
             Previous menu redisplays

TEST 3.3.2: Multiple Back (5 levels deep)
  Steps:
    1. Navigate 5 levels deep into menu structure
    2. Press 'B' 5 times
  Expected: Return all the way to root
  Pass Criteria: Each back returns to previous level
             currentHost$ changes as expected

TEST 3.3.3: Back at Root (No History)
  Steps:
    1. Start at root menu
    2. Press 'B' immediately
  Expected: No action, message appears
  Pass Criteria: "No previous page" message displays
             Program doesn't crash

TEST 3.3.4: History Stack Limit (MAX_HISTORY=10)
  Steps:
    1. Navigate 15 levels deep
    2. Press back repeatedly
  Expected: Can only go back 10 levels
  Pass Criteria: Stops at oldest history entry
             No buffer overflow

TEST 3.3.5: Back After Cross-Server Navigation
  Steps:
    1. Navigate within gopher.floodgap.com
    2. Select item pointing to gopher.quux.org
    3. Press back
  Expected: Return to floodgap menu
  Pass Criteria: Correct host/selector restored
             Connection switches back
```

---

## Phase 4: Text Viewer Testing

### 4.1 Text File Display

**Objective**: Verify text file viewing with scrolling

**Test Cases**:

```
TEST 4.1.1: Simple Text File Display
  Steps:
    1. Select a simple text file (type 0)
    2. Observe content display
  Expected: Text displays line by line
  Pass Criteria: All lines visible (with scrolling)
             Text is readable

TEST 4.1.2: Long Text File (500+ lines)
  Steps:
    1. Select a long text file
    2. Scroll through entire file
  Expected: File loads and displays with pagination
  Pass Criteria: No crashes on large files
             Scrolling remains smooth

TEST 4.1.3: Long Lines in Text File
  Steps:
    1. Select file with lines > 80 characters
    2. View content
  Expected: Long lines truncated or wrapped
  Pass Criteria: Lines fit on screen
             No horizontal overflow

TEST 4.1.4: Empty Lines in Text
  Steps:
    1. View text file with blank lines
  Expected: Blank lines display as empty lines
  Pass Criteria: Formatting preserved
             Spacing correct

TEST 4.1.5: Special Characters
  Steps:
    1. View text with tabs, special chars
  Expected: Characters display correctly
  Pass Criteria: Tabs render (or as spaces)
             No garbage characters

TEST 4.1.6: Text with CR+LF Line Endings
  Steps:
    1. View Gopher text (uses CR+LF)
  Expected: Lines separate correctly
  Pass Criteria: No blank lines between content
             Proper line parsing
```

### 4.2 Text Viewer Navigation

**Objective**: Verify scrolling in text viewer

**Test Cases**:

```
TEST 4.2.1: Scroll Down (Single Line)
  Steps:
    1. Open text file
    2. Press Down arrow once
  Expected: Content scrolls down by 1 line
  Pass Criteria: Line counter increments
             New line visible at bottom

TEST 4.2.2: Scroll Up
  Steps:
    1. Scroll down 5 lines
    2. Press Up arrow 3 times
  Expected: Scroll position decreases
  Pass Criteria: Correct lines visible
             No negative scroll position

TEST 4.2.3: Page Down (Full Page Scroll)
  Steps:
    1. Open text file
    2. Press Page Down key
  Expected: Content jumps by LINES_PER_PAGE
  Pass Criteria: Large jump in content
             No scroll position < 0

TEST 4.2.4: Page Up (Jump Back)
  Steps:
    1. Page down several times
    2. Press Page Up
  Expected: Content jumps back
  Pass Criteria: Correct number of lines skipped
             Returns toward top

TEST 4.2.5: Scroll Boundaries (Top)
  Steps:
    1. Open text file
    2. Press Up/Page Up repeatedly
  Expected: Can't scroll above line 0
  Pass Criteria: scrollPos stays >= 0
             Display stable at top

TEST 4.2.6: Scroll Boundaries (Bottom)
  Steps:
    1. Scroll to end of text file
    2. Press Down/Page Down repeatedly
  Expected: Can't scroll below last line
  Pass Criteria: scrollPos + LINES_PER_PAGE <= totalLines
             Last line always visible

TEST 4.2.7: Exit Text Viewer
  Steps:
    1. View text file
    2. Press 'Q'
  Expected: Return to previous menu
  Pass Criteria: Menu redisplays
             Selection maintained at previous item
```

---

## Phase 5: Bookmark Testing

### 5.1 Saving Bookmarks

**Objective**: Verify bookmark save functionality

**Test Cases**:

```
TEST 5.1.1: Save Single Bookmark
  Steps:
    1. Navigate to menu with items
    2. Select item (e.g., "Floodgap Root")
    3. Press 'A' to add bookmark
    4. Check bookmarks.txt
  Expected: Bookmark added to file
  Pass Criteria: "Bookmark saved!" message shows
             bookmarks.txt contains new entry
             Format: name[TAB]selector[TAB]host[TAB]port

TEST 5.1.2: Save Multiple Bookmarks
  Steps:
    1. Add bookmark 1 (Floodgap root)
    2. Navigate and add bookmark 2 (Quux)
    3. Navigate and add bookmark 3 (SDF)
    4. Check bookmarks.txt
  Expected: All 3 bookmarks saved
  Pass Criteria: bookmarks.txt has 3 entries
             All entries formatted correctly

TEST 5.1.3: Duplicate Bookmark Save
  Steps:
    1. Save bookmark for "Floodgap Root"
    2. Navigate back to same location
    3. Save bookmark again
  Expected: Duplicate allowed (or warning)
  Pass Criteria: bookmarks.txt has 2 entries for same location
             OR user warning if duplicates disabled

TEST 5.1.4: Bookmark for Different Hosts
  Steps:
    1. Navigate within gopher.floodgap.com
    2. Select item on gopher.quux.org
    3. Add bookmark
    4. Return to floodgap
    5. Add bookmark
  Expected: Bookmarks from different hosts both saved
  Pass Criteria: Both hosts in bookmarks.txt
             Correct selectors for each
```

### 5.2 Loading & Managing Bookmarks

**Objective**: Verify bookmark loading and navigation

**Test Cases**:

```
TEST 5.2.1: Load Bookmarks (Empty File)
  Steps:
    1. Delete/clear bookmarks.txt
    2. Press ESC to view bookmarks
  Expected: "No bookmarks saved" message
  Pass Criteria: No crash, user friendly message

TEST 5.2.2: Load Bookmarks (Single Bookmark)
  Steps:
    1. bookmarks.txt contains 1 bookmark
    2. Press ESC
  Expected: Bookmark list displays with 1 item
  Pass Criteria: Correct name visible
             Can select with arrow keys

TEST 5.2.3: Load Bookmarks (Multiple)
  Steps:
    1. bookmarks.txt contains 5 bookmarks
    2. Press ESC
  Expected: All 5 bookmarks display in list
  Pass Criteria: Can navigate through all with arrows
             All names visible

TEST 5.2.4: Select Bookmark & Navigate
  Steps:
    1. Show bookmark list (5+ bookmarks)
    2. Select bookmark 3 (gopher.quux.org)
    3. Press Enter
  Expected: Navigate to selected bookmark
  Pass Criteria: currentHost$ = quux
             currentSelector$ matches bookmark
             currentPort = 70
             New menu fetches and displays

TEST 5.2.5: Cancel Bookmark Selection (ESC)
  Steps:
    1. Press ESC to show bookmarks
    2. Press ESC again to cancel
  Expected: Return to previous menu
  Pass Criteria: Menu still displayed
             No navigation occurs
             selectedIndex unchanged

TEST 5.2.6: Bookmark File Format Validation
  Steps:
    1. Edit bookmarks.txt with malformed entry
       Example: "Name with no tabs"
    2. Load bookmarks
  Expected: Graceful handling
  Pass Criteria: Parser doesn't crash
             Malformed entry skipped or handled

TEST 5.2.7: Comment Handling
  Steps:
    1. bookmarks.txt has comments (# lines)
    2. Load bookmarks
  Expected: Comments ignored, valid bookmarks loaded
  Pass Criteria: Only non-# lines processed
             Correct count of bookmarks
```

---

## Phase 6: End-to-End Testing

### 6.1 Complete Navigation Flow

**Objective**: Test realistic user scenarios

**Test Cases**:

```
TEST 6.1.1: Browse Menu Hierarchy (3 levels)
  Scenario: Complete browsing journey
  Steps:
    1. Start at gopher.floodgap.com root
    2. View menu (should see directories)
    3. Select "More Information" (type 1)
    4. Navigate into new menu
    5. Select text file (type 0)
    6. Read text with scrolling
    7. Press Q to exit viewer
    8. Verify back in previous menu
    9. Press B to go back again
    10. Verify at root
  Expected: Full navigation works smoothly
  Pass Criteria: All steps complete without errors
             Correct menus/content display
             Back button returns correctly

TEST 6.1.2: Bookmark Workflow
  Scenario: Save and use bookmarks
  Steps:
    1. Navigate to interesting location in Gopher
    2. Press A to save bookmark
    3. Navigate to different location
    4. Press ESC to show bookmarks
    5. Select saved bookmark
    6. Verify correct location loaded
  Expected: Bookmark saves and navigates correctly
  Pass Criteria: Location correct after bookmark selection
             History allows returning from bookmarked location

TEST 6.1.3: Search Query (Type 7)
  Scenario: Use Gopher search
  Steps:
    1. Find item with type 7 (search)
    2. Select with Enter
    3. Enter search query
    4. View results
  Expected: Search works end-to-end
  Pass Criteria: Query sent to server
             Results display as menu

TEST 6.1.4: Multiple Server Navigation
  Scenario: Jump between different Gopher servers
  Steps:
    1. Start at gopher.floodgap.com
    2. Find item pointing to gopher.quux.org
    3. Select it (navigate cross-server)
    4. Browse quux menu
    5. Go back to floodgap
  Expected: Can navigate between servers
  Pass Criteria: Host changes correctly
             Each server's content correct
```

### 6.2 Cross-Server Testing

**Objective**: Test with real public Gopher servers

**Test Servers & Selectors**:

```
Floodgap Systems (gopher.floodgap.com:70)
  / (root menu)
  /info.txt (text file)
  /macheads.txt (long text file)

Quux.org (gopher.quux.org:70)
  / (root menu)

SDF Public Access (sdf.org:70)
  / (root menu)
```

**Test Cases**:

```
TEST 6.2.1: Floodgap Root Menu
  Steps:
    1. Connect to gopher.floodgap.com:70
    2. Request selector ""
    3. Display menu
  Expected: Valid Gopher menu appears
  Pass Criteria: Multiple items visible
             Item types include 0, 1, i

TEST 6.2.2: Floodgap Text File
  Steps:
    1. From root, select text file item
    2. View content
  Expected: Text displays correctly
  Pass Criteria: File content visible
             Scrolling works

TEST 6.2.3: Quux Root Menu
  Steps:
    1. Connect to gopher.quux.org:70
    2. Request selector ""
  Expected: Quux menu appears
  Pass Criteria: Can connect to different host
             Menu displays correctly

TEST 6.2.4: SDF Root Menu
  Steps:
    1. Connect to sdf.org:70
    2. Request selector ""
  Expected: SDF large menu displays
  Pass Criteria: Handles 50+ items per menu
             Pagination/scrolling works with large menus
```

---

## Phase 7: Stress & Edge Case Testing

### 7.1 Network Stress

**Test Cases**:

```
TEST 7.1.1: Slow Server Response
  Setup: High-latency or slow server
  Steps:
    1. Connect to slow Gopher server
    2. Wait for menu to load
  Expected: No timeout, menu eventually loads
  Pass Criteria: Program waits patiently
             No crash or freeze

TEST 7.1.2: Connection Drop Mid-Transfer
  Setup: Disconnect WiFi during fetch
  Steps:
    1. Begin fetching large menu
    2. Disconnect WiFi after 2 seconds
  Expected: Graceful error handling
  Pass Criteria: Error message displays
             Program recovers (can retry or go back)

TEST 7.1.3: Server Sends Invalid Response
  Setup: Malformed Gopher response
  Expected: Parser handles gracefully
  Pass Criteria: No crash
             Some menu items display despite errors

TEST 7.1.4: Partial Lastline Reception
  Setup: "." lastline character arrives late
  Expected: Menu waits or times out appropriately
  Pass Criteria: Eventually ends menu parsing
```

### 7.2 Memory & Storage

**Test Cases**:

```
TEST 7.2.1: Large Menu (100 items at limit)
  Setup: Menu with MAX_MENU_ITEMS (100)
  Expected: All items load and navigate
  Pass Criteria: No array overflow
             Scrolling works for all 100 items

TEST 7.2.2: Large Text File (500 lines)
  Setup: Text file with MAX_TEXT_LINES (500)
  Expected: File loads completely
  Pass Criteria: Last line visible when scrolled to end
             No truncation

TEST 7.2.3: Bookmarks File Growth
  Setup: Add 50 bookmarks
  Expected: All bookmarks load and work
  Pass Criteria: Bookmark list complete
             Can select any bookmark

TEST 7.2.4: String Length Limit (255 chars)
  Setup: Menu items with 255+ character names
  Expected: Strings handled without overflow
  Pass Criteria: Truncation with "..." or chunked reading
             No crashes
```

### 7.3 Input Edge Cases

**Test Cases**:

```
TEST 7.3.1: Rapid Key Presses
  Steps:
    1. Press keys very quickly
  Expected: No missed inputs or crash
  Pass Criteria: All keystrokes register

TEST 7.3.2: Hold Key Down
  Steps:
    1. Hold arrow key for 2 seconds
  Expected: Smooth continuous navigation
  Pass Criteria: Key repeat handled correctly

TEST 7.3.3: Invalid Menu Index Selection
  Setup: Manually set selectedIndex out of range
  Expected: Boundary checking works
  Pass Criteria: Can't navigate past menu bounds

TEST 7.3.4: Search with Special Characters
  Setup: Type special chars in search query
  Expected: Query accepted and sent
  Pass Criteria: No crashes on special input
             Server response handled
```

---

## Test Summary Checklist

Use this checklist to track testing progress:

### Phase 1: Network & Protocol
- [ ] WiFi connection setup
- [ ] WiFi error handling
- [ ] TCP connection success
- [ ] TCP timeout handling
- [ ] Connection refused handling
- [ ] Multiple sequential connections
- [ ] Root menu request
- [ ] Selector request
- [ ] Lastline detection

### Phase 2: Parser & Display
- [ ] Type 0 parsing
- [ ] Type 1 parsing
- [ ] Type i parsing
- [ ] Missing port default
- [ ] Malformed line handling
- [ ] Long display name handling
- [ ] Empty menu display
- [ ] Single item display
- [ ] Multi-item menu display
- [ ] Large menu pagination
- [ ] Long item name truncation
- [ ] Mixed type display

### Phase 3: Navigation & UI
- [ ] Arrow up navigation
- [ ] Arrow down navigation
- [ ] Navigation boundaries (up/down)
- [ ] Page scrolling (large menu)
- [ ] Rapid key presses
- [ ] Edge-scroll down past last link
- [ ] Edge-scroll up past first link
- [ ] Edge-scroll stops at menu boundary
- [ ] Edge-scroll does not affect normal navigation
- [ ] New menu resets page position
- [ ] Type 0 selection (text viewer)
- [ ] Type 1 selection (new menu)
- [ ] Type i selection (no-op)
- [ ] Type 3 selection (error)
- [ ] Type 7 selection (search)
- [ ] Single back navigation
- [ ] Multiple back navigation
- [ ] Back at root (no history)
- [ ] History stack limit
- [ ] Cross-server back navigation

### Phase 4: Text Viewer
- [ ] Simple text file display
- [ ] Long text file (500+ lines)
- [ ] Long lines in text
- [ ] Empty lines handling
- [ ] Special characters
- [ ] CR+LF line endings
- [ ] Single line scroll down
- [ ] Scroll up
- [ ] Page down
- [ ] Page up
- [ ] Top boundary
- [ ] Bottom boundary
- [ ] Exit viewer with Q

### Phase 5: Bookmarks
- [ ] Save single bookmark
- [ ] Save multiple bookmarks
- [ ] Duplicate bookmark handling
- [ ] Cross-host bookmarks
- [ ] Load empty bookmark file
- [ ] Load single bookmark
- [ ] Load multiple bookmarks
- [ ] Select bookmark and navigate
- [ ] Cancel bookmark selection
- [ ] Malformed bookmark format
- [ ] Comment handling in bookmarks.txt

### Phase 6: End-to-End
- [ ] Browse 3-level hierarchy
- [ ] Bookmark save and use
- [ ] Search query (type 7)
- [ ] Multiple server navigation
- [ ] Floodgap root menu
- [ ] Floodgap text file
- [ ] Quux root menu
- [ ] SDF root menu

### Phase 7: Stress & Edge Cases
- [ ] Slow server response
- [ ] Connection drop mid-transfer
- [ ] Invalid server response
- [ ] Partial lastline reception
- [ ] Large menu (100 items)
- [ ] Large text file (500 lines)
- [ ] Bookmarks file growth
- [ ] String length limits
- [ ] Rapid key presses
- [ ] Hold key down
- [ ] Invalid menu index
- [ ] Search special characters

---

## Reporting Test Results

For each failed test, create a bug report:

```
TEST: [Test Case ID]
DESCRIPTION: [What was being tested]
STEPS: [Step-by-step reproduction]
EXPECTED: [Expected behavior]
ACTUAL: [What actually happened]
SEVERITY: [Critical/High/Medium/Low]
ERROR MESSAGE: [Any error text shown]
SCREENSHOT: [If applicable]
NOTES: [Additional observations]
SUGGESTED FIX: [If applicable]
```

---

## Final Sign-Off

When all tests pass:

1. [ ] All test cases completed
2. [ ] No critical bugs remaining
3. [ ] No crashes or data loss
4. [ ] Tested on multiple Gopher servers
5. [ ] Performance acceptable for use
6. [ ] Documentation complete and accurate

**Signed Off By**: ________________
**Date**: ________________
**Version**: 1.3.1

---

**Last Updated**: February 12, 2026
