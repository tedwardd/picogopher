' gopher.bas - PicoGopher Client for PicoMite
' ================================================
' A Gopher protocol browser for Raspberry Pi Pico with WiFi
' Version: 1.3.1
' Author: Claude
' Last Modified: 2026-02-12
'
' Dependencies:
'   - PicoMite firmware with WebMite support
'   - Graphics LCD display (~320x320)
'   - QWERTY keyboard input
'   - WiFi connectivity

' ================================================
' CONFIGURATION & CONSTANTS
' ================================================

CONST VERSION$ = "1.3.1"
CONST DEFAULT_HOST$ = "gopher.floodgap.com"
CONST DEFAULT_PORT = 70

' Display settings (adjust for your LCD)
CONST SCREEN_WIDTH = 320
CONST SCREEN_HEIGHT = 320
CONST LINE_HEIGHT = 12
CONST CHARS_PER_LINE = 40
CONST LINES_PER_PAGE = 21

' Memory limits (tuned for Pico 2W ~100-160KB heap)
' mmBASIC allocates 256 bytes per string element by default.
' Use DIM array$(n) LENGTH m to limit to m+1 bytes per element.
' See memory budget below at DIM statements.
CONST TCP_TIMEOUT = 10000  ' 10 seconds
CONST MAX_MENU_ITEMS = 80
CONST MAX_TEXT_LINES = 400
CONST MAX_HISTORY = 10
CONST MAX_BOOKMARKS = 30
CONST MAX_SEARCH_HIST = 5
CONST MAX_RECENT = 10

' String constants
CONST CRLF$ = CHR$(13) + CHR$(10)
CONST TAB$ = CHR$(9)

' ================================================
' GLOBAL VARIABLES
' ================================================

' ---- Memory Budget (Pico 2W) ----
' Menu arrays:   80 x (2+81+129+65) + 80x8 = ~22.8 KB
' Text viewer:  400 x 41                    = ~16.0 KB
' History:       10 x (65+129) + 10x8       =  ~2.0 KB
' TCP buffer:  1000 x 8                     =  ~8.0 KB
' Search hist:   5 x (129+65) + 5x8         =  ~1.0 KB
' Recent list:  10 x (41+65+129) + 10x8     =  ~2.4 KB
' Estimated total:                           ~52.2 KB
' ----------------------------------

' Menu display arrays
DIM menuType$(MAX_MENU_ITEMS) LENGTH 1        '  80 x   2 =    160 bytes
DIM menuDisp$(MAX_MENU_ITEMS) LENGTH 80       '  80 x  81 =  6,480 bytes
DIM menuSel$(MAX_MENU_ITEMS) LENGTH 128       '  80 x 129 = 10,320 bytes
DIM menuHost$(MAX_MENU_ITEMS) LENGTH 64       '  80 x  65 =  5,200 bytes
DIM menuPort(MAX_MENU_ITEMS)                  '  80 x   8 =    640 bytes
DIM menuCount AS INTEGER

' TCP response buffer (LONGSTRING: 1000 ints = ~8KB of text data)
DIM tcpResponseBuffer%(1000)
DIM tcpResponsePos AS INTEGER

' Current menu state
DIM selectedIndex AS INTEGER
DIM currentHost$ LENGTH 64
DIM currentSelector$ LENGTH 128
DIM currentPort = DEFAULT_PORT
DIM pageStart AS INTEGER
DIM pageEnd AS INTEGER
DIM menuScrollX AS INTEGER
DIM firstSelectable AS INTEGER
DIM lastSelectable AS INTEGER

' History stack
DIM histHost$(MAX_HISTORY) LENGTH 64          '  10 x  65 =    650 bytes
DIM histSelector$(MAX_HISTORY) LENGTH 128     '  10 x 129 =  1,290 bytes
DIM histPort(MAX_HISTORY)                     '  10 x   8 =     80 bytes
DIM histIndex AS INTEGER

' Global state
DIM running AS INTEGER
DIM tcpConnected AS INTEGER
DIM errorMsg$ LENGTH 80
DIM statusMsg$ LENGTH 80
DIM statusTimeout AS INTEGER
DIM menuDirty AS INTEGER
DIM textDirty AS INTEGER
DIM bookmarkDirty AS INTEGER
DIM lastError$ LENGTH 80

' Text viewer state (word-wrapped at load time, so lines fit CHARS_PER_LINE)
DIM textLines$(MAX_TEXT_LINES) LENGTH 40      ' 400 x  41 = 16,400 bytes
DIM textLineCount AS INTEGER
DIM scrollPos AS INTEGER

' Search history (ring buffer of recent search queries)
DIM searchHistQuery$(MAX_SEARCH_HIST) LENGTH 128  '  5 x 129 =    645 bytes
DIM searchHistHost$(MAX_SEARCH_HIST) LENGTH 64    '  5 x  65 =    325 bytes
DIM searchHistPort(MAX_SEARCH_HIST)               '  5 x   8 =     40 bytes
DIM searchHistCount AS INTEGER

' Recently visited pages (viewable list, not destructively popped)
DIM recentDisp$(MAX_RECENT) LENGTH 40     ' 10 x  41 =    410 bytes
DIM recentHost$(MAX_RECENT) LENGTH 64     ' 10 x  65 =    650 bytes
DIM recentSel$(MAX_RECENT) LENGTH 128     ' 10 x 129 =  1,290 bytes
DIM recentPort(MAX_RECENT)                ' 10 x   8 =     80 bytes
DIM recentCount AS INTEGER

' Display optimization: pre-built blank line for padding (avoids CLS flicker)
DIM blankLine$ LENGTH 42
blankLine$ = SPACE$(42)

' ================================================
' PHASE 1: NETWORK & PROTOCOL
' ================================================

SUB InitWiFi()
  ' Check WiFi connectivity
  ' Note: WiFi must be configured first from the PicoMite console:
  '   OPTION WIFI your_ssid, your_password
  ' This only needs to be done once as it persists in flash.

  PRINT "Checking WiFi..."
  PAUSE 2000

  ' Check if WiFi is connected by checking IP address
  IF MM.INFO$(IP ADDRESS) = "0.0.0.0" THEN
    PRINT "WiFi not connected!"
    PRINT "Run from console first:"
    PRINT "  OPTION WIFI ssid, password"
    PAUSE 5000
  ELSE
    PRINT "WiFi connected: " + MM.INFO$(IP ADDRESS)
  ENDIF
END SUB

SUB GopherConnect(host$, port)
  ' Connect to Gopher server
  ' Sets tcpConnected and lastError$ for caller to check

  ON ERROR IGNORE
  WEB OPEN TCP CLIENT host$, port
  ON ERROR ABORT

  IF MM.ERRNO <> 0 THEN
    tcpConnected = 0
    lastError$ = "Could not connect to " + LEFT$(host$, 40)
  ELSE
    tcpConnected = 1
    lastError$ = ""
  ENDIF
END SUB

SUB GopherSend(selector$)
  ' Send Gopher request and read response into buffer
  ' Format: selector\r\n
  ' Sets lastError$ for caller to check (empty = success)

  tcpResponsePos = 0  ' Reset response position

  ON ERROR IGNORE
  WEB TCP CLIENT REQUEST selector$ + CRLF$, tcpResponseBuffer%(), 10000
  ON ERROR ABORT

  IF MM.ERRNO <> 0 THEN
    lastError$ = "Request failed (error " + STR$(MM.ERRNO) + ")"
  ELSE
    lastError$ = ""
  ENDIF
END SUB

SUB ReadGopherLine(result$)
  ' Read a line from the TCP response LONGSTRING buffer
  ' Uses LLEN, LINSTR, LGETSTR$ to parse LONGSTRING data
  ' Returns CHR$(0) as sentinel when no more data is available

  LOCAL bufLen, lfPos, lineLen

  result$ = ""
  bufLen = LLEN(tcpResponseBuffer%())

  ' No more data - return sentinel
  IF tcpResponsePos >= bufLen THEN
    result$ = CHR$(0)
    EXIT SUB
  ENDIF

  ' Search for LF (Chr$(10)) starting from current position
  lfPos = LINSTR(tcpResponseBuffer%(), CHR$(10), tcpResponsePos + 1)

  IF lfPos = 0 THEN
    ' No more line endings - return rest of buffer (up to 255 chars)
    lineLen = bufLen - tcpResponsePos
    IF lineLen > 255 THEN lineLen = 255
    IF lineLen > 0 THEN
      result$ = LGETSTR$(tcpResponseBuffer%(), tcpResponsePos + 1, lineLen)
    ENDIF
    tcpResponsePos = bufLen
  ELSE
    ' Extract line from current position to LF
    lineLen = lfPos - tcpResponsePos - 1
    IF lineLen > 255 THEN lineLen = 255
    IF lineLen > 0 THEN
      result$ = LGETSTR$(tcpResponseBuffer%(), tcpResponsePos + 1, lineLen)
    ENDIF
    tcpResponsePos = lfPos  ' Move past the LF

    ' Strip trailing CR if present
    IF LEN(result$) > 0 THEN
      IF RIGHT$(result$, 1) = CHR$(13) THEN
        result$ = LEFT$(result$, LEN(result$) - 1)
      ENDIF
    ENDIF
  ENDIF
END SUB

SUB GopherClose()
  ' Close Gopher connection
  ON ERROR IGNORE
  WEB CLOSE TCP CLIENT
  tcpConnected = 0
  ON ERROR ABORT
END SUB

FUNCTION ShowError$(title$, detail$)
  ' Display an error screen with recovery options.
  ' Returns "R" (retry), "B" (back), "^" (home), or "G" (go to address).

  LOCAL key$

  CLS
  PRINT @(10, 60) "--- Error ---"
  PRINT @(10, 80) LEFT$(title$, 38)
  IF LEN(detail$) > 0 THEN
    PRINT @(10, 100) LEFT$(detail$, 38)
  ENDIF
  PRINT @(10, 140) "R = Retry"
  PRINT @(10, 155) "B = Go Back"
  PRINT @(10, 170) "^ = Go Home"
  PRINT @(10, 185) "G = Go to address"

  DO
    key$ = INKEY$
    IF key$ = "R" OR key$ = "r" THEN
      ShowError$ = "R"
      EXIT FUNCTION
    ELSEIF key$ = "B" OR key$ = "b" THEN
      ShowError$ = "B"
      EXIT FUNCTION
    ELSEIF key$ = "^" THEN
      ShowError$ = "^"
      EXIT FUNCTION
    ELSEIF key$ = "G" OR key$ = "g" THEN
      ShowError$ = "G"
      EXIT FUNCTION
    ENDIF
    PAUSE 20
  LOOP
END FUNCTION

' ================================================
' PHASE 1: MENU PARSER
' ================================================

SUB ParseMenuLine(line$, itemType$, display$, selector$, host$, port)
  ' Parse Gopher menu line
  ' Format: <type><display>\t<selector>\t<host>\t<port>

  LOCAL tabPos1, tabPos2, tabPos3
  LOCAL remainder$

  ' Extract item type (first character)
  IF LEN(line$) > 0 THEN
    itemType$ = LEFT$(line$, 1)
  ELSE
    itemType$ = "i"
    display$ = ""
    selector$ = ""
    host$ = ""
    port = 70
    EXIT SUB
  ENDIF

  ' Find tab positions
  tabPos1 = INSTR(line$, TAB$)

  IF tabPos1 = 0 THEN
    ' Malformed line - no tabs
    display$ = MID$(line$, 2)
    selector$ = ""
    host$ = ""
    port = 70
    EXIT SUB
  ENDIF

  ' Extract display name (between type and first tab)
  display$ = MID$(line$, 2, tabPos1 - 2)

  ' Parse remainder for selector, host, port
  remainder$ = MID$(line$, tabPos1 + 1)

  tabPos2 = INSTR(remainder$, TAB$)
  IF tabPos2 = 0 THEN
    ' Only selector, no host/port
    selector$ = remainder$
    host$ = ""
    port = 70
    EXIT SUB
  ENDIF

  selector$ = LEFT$(remainder$, tabPos2 - 1)
  remainder$ = MID$(remainder$, tabPos2 + 1)

  tabPos3 = INSTR(remainder$, TAB$)
  IF tabPos3 = 0 THEN
    ' No port specified
    host$ = remainder$
    port = 70
  ELSE
    host$ = LEFT$(remainder$, tabPos3 - 1)
    port = VAL(MID$(remainder$, tabPos3 + 1))
    IF port = 0 THEN port = 70
  ENDIF
END SUB

' ================================================
' PHASE 2: DISPLAY & NAVIGATION
' ================================================

SUB DisplayMenu()
  ' Display current menu page (only if dirty flag is set)
  ' Uses in-place overwriting with padded lines to avoid CLS flicker

  IF menuDirty = 0 THEN EXIT SUB
  menuDirty = 0

  ' Calculate page range
  IF selectedIndex < pageStart OR selectedIndex > pageStart + LINES_PER_PAGE - 1 THEN
    pageStart = MAX(0, selectedIndex - LINES_PER_PAGE / 2)
  ENDIF
  pageEnd = MIN(menuCount - 1, pageStart + LINES_PER_PAGE - 1)

  IF pageEnd < pageStart + LINES_PER_PAGE - 1 THEN
    pageStart = MAX(0, pageEnd - LINES_PER_PAGE + 1)
  ENDIF

  ' Title bar (padded to full width to overwrite old content)
  PRINT @(0, 10) LEFT$("PicoGopher - " + currentHost$ + SPACE$(40), 40);
  PRINT @(0, 22) STRING$(40, "-");

  ' Display menu items (with horizontal scroll support)
  LOCAL i, y, slot, displayStr$, typePrefix$, fullStr$, lineOut$, visibleChars
  visibleChars = CHARS_PER_LINE - 2  ' Reserve 2 chars for cursor prefix

  FOR slot = 0 TO LINES_PER_PAGE - 1
    y = slot * LINE_HEIGHT + 34
    i = pageStart + slot

    IF i <= pageEnd THEN
      IF menuType$(i) = "i" THEN
        ' Info items: no prefix, use full line width for ASCII art/text
        IF menuScrollX < LEN(menuDisp$(i)) THEN
          lineOut$ = MID$(menuDisp$(i), menuScrollX + 1, CHARS_PER_LINE)
        ELSE
          lineOut$ = ""
        ENDIF
      ELSE
        ' Selectable items: type indicator prefix + cursor
        SELECT CASE menuType$(i)
          CASE "0"
            typePrefix$ = "[TXT] "
          CASE "1"
            typePrefix$ = "[DIR] "
          CASE "7"
            typePrefix$ = "[?]   "
          CASE "3"
            typePrefix$ = "[ERR] "
          CASE ELSE
            typePrefix$ = "[" + menuType$(i) + "]   "
        END SELECT

        ' Build full content string, then apply horizontal scroll offset
        fullStr$ = typePrefix$ + menuDisp$(i)
        IF menuScrollX < LEN(fullStr$) THEN
          displayStr$ = MID$(fullStr$, menuScrollX + 1, visibleChars)
        ELSE
          displayStr$ = ""
        ENDIF

        IF i = selectedIndex THEN
          lineOut$ = "> " + displayStr$
        ELSE
          lineOut$ = "  " + displayStr$
        ENDIF
      ENDIF

      ' Pad to full width and print (overwrites previous content)
      PRINT @(0, y) LEFT$(lineOut$ + blankLine$, CHARS_PER_LINE);
    ELSE
      ' Blank unused line slots (overwrite leftover content from previous page)
      PRINT @(0, y) LEFT$(blankLine$, CHARS_PER_LINE);
    ENDIF
  NEXT slot

  ' Status bar (padded to overwrite old content)
  LOCAL statusText$ = ""
  IF LEN(statusMsg$) > 0 THEN
    statusText$ = statusMsg$
  ELSE
    statusText$ = "^=Home B=Back G=Go Q=Quit ?=Help"
  ENDIF

  PRINT @(0, SCREEN_HEIGHT - 28) LEFT$(statusText$ + blankLine$, CHARS_PER_LINE);

  ' Show item count (padded)
  LOCAL countStr$
  countStr$ = "Item " + STR$(selectedIndex + 1) + "/" + STR$(menuCount)
  PRINT @(0, SCREEN_HEIGHT - 14) LEFT$(countStr$ + blankLine$, CHARS_PER_LINE);
END SUB

SUB UpdateMenuCursor(oldIdx, newIdx)
  ' Lightweight 2-line update: repaint only the old and new selected lines.
  ' Used when the cursor moves within the already-visible page range,
  ' avoiding a full DisplayMenu() redraw for smoother scrolling.

  LOCAL y, displayStr$, typePrefix$, fullStr$, lineOut$, visibleChars
  visibleChars = CHARS_PER_LINE - 2

  ' --- Repaint old selection (remove cursor) ---
  IF oldIdx >= pageStart THEN
    IF oldIdx <= pageEnd THEN
      y = (oldIdx - pageStart) * LINE_HEIGHT + 34

      SELECT CASE menuType$(oldIdx)
        CASE "0"
          typePrefix$ = "[TXT] "
        CASE "1"
          typePrefix$ = "[DIR] "
        CASE "7"
          typePrefix$ = "[?]   "
        CASE "3"
          typePrefix$ = "[ERR] "
        CASE "i"
          typePrefix$ = "      "
        CASE ELSE
          typePrefix$ = "[" + menuType$(oldIdx) + "]   "
      END SELECT

      fullStr$ = typePrefix$ + menuDisp$(oldIdx)
      IF menuScrollX < LEN(fullStr$) THEN
        displayStr$ = MID$(fullStr$, menuScrollX + 1, visibleChars)
      ELSE
        displayStr$ = ""
      ENDIF

      lineOut$ = "  " + displayStr$
      PRINT @(0, y) LEFT$(lineOut$ + blankLine$, CHARS_PER_LINE);
    ENDIF
  ENDIF

  ' --- Repaint new selection (add cursor) ---
  IF newIdx >= pageStart THEN
    IF newIdx <= pageEnd THEN
      y = (newIdx - pageStart) * LINE_HEIGHT + 34

      SELECT CASE menuType$(newIdx)
        CASE "0"
          typePrefix$ = "[TXT] "
        CASE "1"
          typePrefix$ = "[DIR] "
        CASE "7"
          typePrefix$ = "[?]   "
        CASE "3"
          typePrefix$ = "[ERR] "
        CASE "i"
          typePrefix$ = "      "
        CASE ELSE
          typePrefix$ = "[" + menuType$(newIdx) + "]   "
      END SELECT

      fullStr$ = typePrefix$ + menuDisp$(newIdx)
      IF menuScrollX < LEN(fullStr$) THEN
        displayStr$ = MID$(fullStr$, menuScrollX + 1, visibleChars)
      ELSE
        displayStr$ = ""
      ENDIF

      IF menuType$(newIdx) = "i" THEN
        lineOut$ = "  " + displayStr$
      ELSE
        lineOut$ = "> " + displayStr$
      ENDIF

      PRINT @(0, y) LEFT$(lineOut$ + blankLine$, CHARS_PER_LINE);
    ENDIF
  ENDIF

  ' Update item count footer
  LOCAL countStr$
  countStr$ = "Item " + STR$(newIdx + 1) + "/" + STR$(menuCount)
  PRINT @(0, SCREEN_HEIGHT - 14) LEFT$(countStr$ + blankLine$, CHARS_PER_LINE);
END SUB

SUB DisplayTextPage(scrollPos)
  ' Display text file page (only if dirty flag is set)
  ' Uses in-place overwriting with padded lines to avoid CLS flicker

  IF textDirty = 0 THEN EXIT SUB
  textDirty = 0

  ' Title bar (padded to overwrite old content)
  PRINT @(0, 10) LEFT$("Text Viewer - ^v to scroll, Q to exit" + SPACE$(40), 40);
  PRINT @(0, 22) STRING$(40, "-");

  LOCAL i, lineNum, y, lineStr$
  FOR i = 0 TO LINES_PER_PAGE - 1
    y = i * LINE_HEIGHT + 34
    lineNum = scrollPos + i

    IF lineNum < textLineCount THEN
      ' Lines are already word-wrapped at load time to fit CHARS_PER_LINE
      ' Pad to full width to overwrite previous content
      PRINT @(0, y) LEFT$(textLines$(lineNum) + blankLine$, CHARS_PER_LINE);
    ELSE
      ' Blank unused line slots
      PRINT @(0, y) LEFT$(blankLine$, CHARS_PER_LINE);
    ENDIF
  NEXT i

  ' Line count footer (padded)
  LOCAL countStr$
  countStr$ = "Line " + STR$(scrollPos + 1) + "/" + STR$(textLineCount)
  PRINT @(0, SCREEN_HEIGHT - 14) LEFT$(countStr$ + blankLine$, CHARS_PER_LINE);
END SUB

SUB HandleInput()
  ' Handle keyboard input

  LOCAL key$
  key$ = INKEY$

  IF key$ = "" THEN EXIT SUB

  SELECT CASE key$
    ' Home menu
    CASE "^"
      menuScrollX = 0
      PushHistory(currentHost$, currentSelector$, currentPort)
      currentHost$ = DEFAULT_HOST$
      currentSelector$ = "/"
      currentPort = DEFAULT_PORT
      FetchAndDisplayMenu()

    ' Arrow keys for navigation (skip non-selectable info items)
    CASE CHR$(128)  ' Up arrow
      LOCAL newIdx, oldIdx
      oldIdx = selectedIndex
      newIdx = selectedIndex - 1
      ' Note: mmBASIC does not short-circuit AND, so bounds check
      ' must be separate from array access to avoid Dimensions error
      DO WHILE newIdx >= 0
        IF menuType$(newIdx) <> "i" THEN EXIT DO
        newIdx = newIdx - 1
      LOOP
      IF newIdx >= 0 THEN
        ' If new index is within visible page, do fast 2-line update
        IF newIdx >= pageStart THEN
          IF newIdx <= pageEnd THEN
            UpdateMenuCursor(oldIdx, newIdx)
            selectedIndex = newIdx
            statusMsg$ = ""
          ELSE
            selectedIndex = newIdx
            statusMsg$ = ""
            menuDirty = 1
          ENDIF
        ELSE
          selectedIndex = newIdx
          statusMsg$ = ""
          ' At first selectable, use minimum-scroll (item at top) so
          ' header info stays hidden and edge-scroll can reveal it
          IF newIdx = firstSelectable THEN
            pageStart = newIdx
          ENDIF
          menuDirty = 1
        ENDIF
      ELSE
        ' No selectable above - scroll to show leading info text
        LOCAL minStart
        minStart = MAX(0, selectedIndex - LINES_PER_PAGE + 1)
        IF pageStart > minStart THEN
          pageStart = minStart
          menuDirty = 1
        ENDIF
      ENDIF

    CASE CHR$(129)  ' Down arrow
      oldIdx = selectedIndex
      newIdx = selectedIndex + 1
      DO WHILE newIdx < menuCount
        IF menuType$(newIdx) <> "i" THEN EXIT DO
        newIdx = newIdx + 1
      LOOP
      IF newIdx < menuCount THEN
        ' If new index is within visible page, do fast 2-line update
        IF newIdx >= pageStart THEN
          IF newIdx <= pageEnd THEN
            UpdateMenuCursor(oldIdx, newIdx)
            selectedIndex = newIdx
            statusMsg$ = ""
          ELSE
            selectedIndex = newIdx
            statusMsg$ = ""
            ' At last selectable, use minimum-scroll (item at bottom) so
            ' footer info stays hidden and edge-scroll can reveal it
            IF newIdx = lastSelectable THEN
              pageStart = MAX(0, newIdx - LINES_PER_PAGE + 1)
            ENDIF
            menuDirty = 1
          ENDIF
        ELSE
          selectedIndex = newIdx
          statusMsg$ = ""
          menuDirty = 1
        ENDIF
      ELSE
        ' No selectable below - scroll to show trailing info text
        LOCAL maxStart
        maxStart = MIN(selectedIndex, MAX(0, menuCount - LINES_PER_PAGE))
        IF pageStart < maxStart THEN
          pageStart = maxStart
          menuDirty = 1
        ENDIF
      ENDIF

    ' Horizontal scroll for viewing long menu lines
    CASE CHR$(130)  ' Left arrow
      IF menuScrollX > 0 THEN
        menuScrollX = menuScrollX - 4
        IF menuScrollX < 0 THEN menuScrollX = 0
        menuDirty = 1
      ENDIF

    CASE CHR$(131)  ' Right arrow
      menuScrollX = menuScrollX + 4
      menuDirty = 1

    ' Enter to select
    CASE CHR$(13)
      IF menuCount > 0 THEN
        menuScrollX = 0
        NavigateToItem(selectedIndex)
      ENDIF

    ' Back button
    CASE "b"
      menuScrollX = 0
      NavigateBack()

    CASE "B"
      menuScrollX = 0
      NavigateBack()

    ' Add bookmark
    CASE "a"
      IF menuCount > 0 THEN
        SaveBookmark(menuDisp$(selectedIndex), menuSel$(selectedIndex), menuHost$(selectedIndex), menuPort(selectedIndex))
      ENDIF

    CASE "A"
      IF menuCount > 0 THEN
        SaveBookmark(menuDisp$(selectedIndex), menuSel$(selectedIndex), menuHost$(selectedIndex), menuPort(selectedIndex))
      ENDIF

    ' Bookmarks
    CASE CHR$(27)
      menuScrollX = 0
      ShowBookmarks()
      menuDirty = 1  ' Redraw menu after bookmarks view

    ' Go to custom address
    CASE "g"
      menuScrollX = 0
      GotoCustomAddress()
      menuDirty = 1

    CASE "G"
      menuScrollX = 0
      GotoCustomAddress()
      menuDirty = 1

    ' Recently visited
    CASE "r"
      menuScrollX = 0
      ShowRecent()
      menuDirty = 1

    CASE "R"
      menuScrollX = 0
      ShowRecent()
      menuDirty = 1

    ' Help menu
    CASE "?"
      ShowHelp()
      menuDirty = 1

    ' Quit
    CASE "q"
      running = 0

    CASE "Q"
      running = 0
  END SELECT
END SUB

' ================================================
' PHASE 2: HISTORY NAVIGATION
' ================================================

SUB PushHistory(host$, selector$, port)
  ' Add current location to history stack
  ' If stack is full, shift entries down to make room (oldest entry is lost)

  LOCAL i

  IF histIndex >= MAX_HISTORY - 1 THEN
    ' Shift all entries down by one, dropping the oldest
    FOR i = 1 TO MAX_HISTORY - 1
      histHost$(i) = histHost$(i + 1)
      histSelector$(i) = histSelector$(i + 1)
      histPort(i) = histPort(i + 1)
    NEXT i
    ' histIndex stays at MAX_HISTORY - 1
  ELSE
    histIndex = histIndex + 1
  ENDIF

  histHost$(histIndex) = host$
  histSelector$(histIndex) = selector$
  histPort(histIndex) = port
END SUB

SUB NavigateBack()
  ' Pop from history and navigate

  IF histIndex <= 0 THEN
    statusMsg$ = "No previous page"
    statusTimeout = TIMER + 2000
    menuDirty = 1
    EXIT SUB
  ENDIF

  currentHost$ = histHost$(histIndex)
  currentSelector$ = histSelector$(histIndex)
  currentPort = histPort(histIndex)
  histIndex = histIndex - 1

  FetchAndDisplayMenu()
END SUB

' ================================================
' PHASE 3: TEXT FILE VIEWER
' ================================================

SUB WrapAndStoreLine(line$)
  ' Word-wrap a line and store segments into textLines$() array.
  ' Breaks at last space within CHARS_PER_LINE, or hard-breaks if no space.
  ' Modifies globals: textLines$(), textLineCount

  LOCAL remaining$, breakPos, i

  ' Empty lines stored as-is (preserves paragraph spacing)
  IF LEN(line$) = 0 THEN
    IF textLineCount < MAX_TEXT_LINES THEN
      textLines$(textLineCount) = ""
      textLineCount = textLineCount + 1
    ENDIF
    EXIT SUB
  ENDIF

  remaining$ = line$

  DO WHILE LEN(remaining$) > CHARS_PER_LINE
    IF textLineCount >= MAX_TEXT_LINES THEN EXIT SUB

    ' Scan backwards for a space to break at
    breakPos = 0
    FOR i = CHARS_PER_LINE TO 1 STEP -1
      IF MID$(remaining$, i, 1) = " " THEN
        breakPos = i
        EXIT FOR
      ENDIF
    NEXT i

    IF breakPos = 0 THEN
      ' No space found - hard break at CHARS_PER_LINE
      textLines$(textLineCount) = LEFT$(remaining$, CHARS_PER_LINE)
      textLineCount = textLineCount + 1
      remaining$ = MID$(remaining$, CHARS_PER_LINE + 1)
    ELSE
      ' Break at the space (space consumed, not carried to next line)
      textLines$(textLineCount) = LEFT$(remaining$, breakPos - 1)
      textLineCount = textLineCount + 1
      remaining$ = MID$(remaining$, breakPos + 1)
    ENDIF
  LOOP

  ' Store the remaining text (fits within CHARS_PER_LINE)
  IF textLineCount < MAX_TEXT_LINES THEN
    textLines$(textLineCount) = LEFT$(remaining$, CHARS_PER_LINE)
    textLineCount = textLineCount + 1
  ENDIF
END SUB

SUB ViewTextFile(host$, selector$, port)
  ' Display text file with scrolling
  ' Includes retry/back error recovery on connect or send failure
  LOCAL line$, key$, viewingText, endOfData, choice$

  ' Connection retry loop
  DO
    CLS
    PRINT @(10, 100) "Connecting to " + host$ + "..."

    GopherConnect(host$, port)

    IF tcpConnected = 0 THEN
      choice$ = ShowError$("Connection Failed", lastError$)
      IF choice$ = "R" THEN
        ' Retry - loop continues
      ELSE
        ' Back or Home - return to menu (caller sets menuDirty)
        EXIT SUB
      ENDIF
    ELSE
      EXIT DO
    ENDIF
  LOOP

  ' Send request with retry
  DO
    GopherSend(selector$)

    IF LEN(lastError$) > 0 THEN
      GopherClose()
      choice$ = ShowError$("Request Failed", lastError$)
      IF choice$ = "R" THEN
        GopherConnect(host$, port)
        IF tcpConnected = 0 THEN EXIT SUB
      ELSE
        EXIT SUB
      ENDIF
    ELSE
      EXIT DO
    ENDIF
  LOOP

  ' Read text lines from TCP response into array
  textLineCount = 0
  scrollPos = 0

  DO
    ReadGopherLine(line$)

    ' Check for end-of-data (sentinel from ReadGopherLine)
    IF line$ = CHR$(0) THEN EXIT DO

    ' Gopher text terminator
    IF line$ = "." THEN EXIT DO

    ' Dot-stuffing: lines starting with ".." become "."
    IF LEFT$(line$, 2) = ".." THEN line$ = MID$(line$, 2)

    WrapAndStoreLine(line$)
  LOOP

  GopherClose()

  ' Track this text file in recently visited list
  PushRecent(LEFT$(host$ + selector$, 40), host$, selector$, port)

  IF textLineCount = 0 THEN
    textLines$(0) = "(Empty document)"
    textLineCount = 1
  ENDIF

  ' Display text with scrolling
  viewingText = 1
  textDirty = 1  ' Initial display
  DO WHILE viewingText
    DisplayTextPage(scrollPos)

    key$ = INKEY$
    IF key$ = "" THEN
      PAUSE 10
    ELSE
      SELECT CASE key$
        CASE "q"
          viewingText = 0
        CASE "Q"
          viewingText = 0
        CASE CHR$(27)
          viewingText = 0
        CASE CHR$(128)  ' Up
          scrollPos = MAX(0, scrollPos - 1)
          textDirty = 1
        CASE CHR$(129)  ' Down
          scrollPos = MIN(MAX(0, textLineCount - LINES_PER_PAGE), scrollPos + 1)
          textDirty = 1
        CASE CHR$(133)  ' Page Up
          scrollPos = MAX(0, scrollPos - LINES_PER_PAGE)
          textDirty = 1
        CASE CHR$(134)  ' Page Down
          scrollPos = MIN(MAX(0, textLineCount - LINES_PER_PAGE), scrollPos + LINES_PER_PAGE)
          textDirty = 1
      END SELECT
    ENDIF
  LOOP
END SUB

' ================================================
' PHASE 4: BOOKMARK MANAGEMENT
' ================================================

SUB SaveBookmark(display$, selector$, host$, port)
  ' Save bookmark to file

  CLS
  PRINT @(10, 100) "Saving bookmark..."

  LOCAL newBookmark$ = display$ + TAB$ + selector$ + TAB$ + host$ + TAB$ + STR$(port)

  ON ERROR IGNORE
  OPEN "bookmarks.txt" FOR APPEND AS #2
  PRINT #2, newBookmark$
  CLOSE #2
  ON ERROR ABORT

  statusMsg$ = "Bookmark saved!"
  statusTimeout = TIMER + 2000
  menuDirty = 1
END SUB

SUB ShowBookmarks()
  ' Display and manage bookmarks
  LOCAL bmDisp$(MAX_BOOKMARKS) LENGTH 80
  LOCAL bmSel$(MAX_BOOKMARKS) LENGTH 128
  LOCAL bmHost$(MAX_BOOKMARKS) LENGTH 64
  LOCAL bmPort(MAX_BOOKMARKS)
  LOCAL bmCount, i, y, line$, t$, selected, selectingBookmark, key$
  LOCAL tmpDisp$, tmpSel$, tmpHost$, tmpPort
  LOCAL lineOut$, slot, bmCountStr$

  CLS
  PRINT @(10, 100) "Loading bookmarks..."

  ' Load bookmarks
  IF FILE_EXISTS("bookmarks.txt") THEN
    ON ERROR IGNORE
    OPEN "bookmarks.txt" FOR INPUT AS #3

    DO WHILE NOT EOF(#3) AND bmCount < MAX_BOOKMARKS
      LINE INPUT #3, line$
      IF LEN(line$) > 0 AND LEFT$(line$, 1) <> "#" THEN
        ' Parse into temp vars, then truncate into LENGTH-constrained arrays
        ParseMenuLine("1" + line$, t$, tmpDisp$, tmpSel$, tmpHost$, tmpPort)
        bmDisp$(bmCount) = LEFT$(tmpDisp$, 80)
        bmSel$(bmCount) = LEFT$(tmpSel$, 128)
        bmHost$(bmCount) = LEFT$(tmpHost$, 64)
        bmPort(bmCount) = tmpPort
        bmCount = bmCount + 1
      ENDIF
    LOOP

    CLOSE #3
    ON ERROR ABORT
  ENDIF

  IF bmCount = 0 THEN
    CLS
    PRINT @(10, 100) "No bookmarks saved"
    PAUSE 2000
    EXIT SUB
  ENDIF

  ' Display bookmarks
  selected = 0
  selectingBookmark = 1
  bookmarkDirty = 1  ' Initial display

  DO WHILE selectingBookmark
    IF bookmarkDirty = 1 THEN
      bookmarkDirty = 0

      PRINT @(0, 10) LEFT$("Bookmarks - Enter=Select, ESC=Cancel" + SPACE$(40), 40);
      PRINT @(0, 22) STRING$(40, "-");

      FOR slot = 0 TO LINES_PER_PAGE - 1
        y = slot * LINE_HEIGHT + 34

        IF slot < bmCount THEN
          IF slot = selected THEN
            lineOut$ = "> " + bmDisp$(slot)
          ELSE
            lineOut$ = "  " + bmDisp$(slot)
          ENDIF
          PRINT @(0, y) LEFT$(lineOut$ + blankLine$, CHARS_PER_LINE);
        ELSE
          PRINT @(0, y) LEFT$(blankLine$, CHARS_PER_LINE);
        ENDIF
      NEXT slot

      bmCountStr$ = "Bookmark " + STR$(selected + 1) + "/" + STR$(bmCount)
      PRINT @(0, SCREEN_HEIGHT - 14) LEFT$(bmCountStr$ + blankLine$, CHARS_PER_LINE);
    ENDIF

    key$ = INKEY$
    IF key$ = "" THEN
      PAUSE 10
    ELSE
      SELECT CASE key$
        CASE CHR$(128)  ' Up
          selected = MAX(0, selected - 1)
          bookmarkDirty = 1
        CASE CHR$(129)  ' Down
          selected = MIN(bmCount - 1, selected + 1)
          bookmarkDirty = 1
        CASE CHR$(13)  ' Enter
          ' Navigate to bookmark
          PushHistory(currentHost$, currentSelector$, currentPort)
          currentHost$ = bmHost$(selected)
          currentSelector$ = bmSel$(selected)
          currentPort = bmPort(selected)
          FetchAndDisplayMenu()
          selectingBookmark = 0
        CASE CHR$(27)  ' Escape
          selectingBookmark = 0
      END SELECT
    ENDIF
  LOOP
END SUB

' ================================================
' PHASE 4B: RECENTLY VISITED LIST
' ================================================

SUB PushRecent(disp$, host$, selector$, port)
  ' Add a page to the recently visited list.
  ' Shifts oldest entry out if full. Same pattern as PushHistory.

  LOCAL i

  IF recentCount >= MAX_RECENT THEN
    ' Shift all entries down by one, dropping the oldest (index 0)
    FOR i = 0 TO MAX_RECENT - 2
      recentDisp$(i) = recentDisp$(i + 1)
      recentHost$(i) = recentHost$(i + 1)
      recentSel$(i) = recentSel$(i + 1)
      recentPort(i) = recentPort(i + 1)
    NEXT i
    recentCount = MAX_RECENT - 1
  ENDIF

  recentDisp$(recentCount) = LEFT$(disp$, 40)
  recentHost$(recentCount) = LEFT$(host$, 64)
  recentSel$(recentCount) = LEFT$(selector$, 128)
  recentPort(recentCount) = port
  recentCount = recentCount + 1
END SUB

SUB ShowRecent()
  ' Display the recently visited pages list.
  ' Similar UI to ShowBookmarks - Up/Down, Enter, ESC.

  LOCAL i, y, selected, selecting, key$, recentDirty
  LOCAL lineOut$, slot, rcCountStr$

  IF recentCount = 0 THEN
    CLS
    PRINT @(10, 100) "No recent pages"
    PAUSE 2000
    EXIT SUB
  ENDIF

  selected = recentCount - 1  ' Start at most recent
  selecting = 1
  recentDirty = 1

  DO WHILE selecting
    IF recentDirty = 1 THEN
      recentDirty = 0

      PRINT @(0, 10) LEFT$("Recent Pages - Enter=Go, ESC=Cancel" + SPACE$(40), 40);
      PRINT @(0, 22) STRING$(40, "-");

      FOR slot = 0 TO LINES_PER_PAGE - 1
        y = slot * LINE_HEIGHT + 34

        IF slot < recentCount THEN
          IF slot = selected THEN
            lineOut$ = "> " + recentDisp$(slot)
          ELSE
            lineOut$ = "  " + recentDisp$(slot)
          ENDIF
          PRINT @(0, y) LEFT$(lineOut$ + blankLine$, CHARS_PER_LINE);
        ELSE
          PRINT @(0, y) LEFT$(blankLine$, CHARS_PER_LINE);
        ENDIF
      NEXT slot

      rcCountStr$ = "Page " + STR$(selected + 1) + "/" + STR$(recentCount)
      PRINT @(0, SCREEN_HEIGHT - 14) LEFT$(rcCountStr$ + blankLine$, CHARS_PER_LINE);
    ENDIF

    key$ = INKEY$
    IF key$ = "" THEN
      PAUSE 10
    ELSE
      SELECT CASE key$
        CASE CHR$(128)  ' Up
          selected = MAX(0, selected - 1)
          recentDirty = 1
        CASE CHR$(129)  ' Down
          selected = MIN(recentCount - 1, selected + 1)
          recentDirty = 1
        CASE CHR$(13)  ' Enter
          PushHistory(currentHost$, currentSelector$, currentPort)
          currentHost$ = recentHost$(selected)
          currentSelector$ = recentSel$(selected)
          currentPort = recentPort(selected)
          FetchAndDisplayMenu()
          selecting = 0
        CASE CHR$(27)  ' Escape
          selecting = 0
      END SELECT
    ENDIF
  LOOP
END SUB

' ================================================
' PHASE 4C: HELP MENU
' ================================================

SUB ShowHelp()
  ' Display a full-screen help overlay with all key bindings.
  ' Waits for any key press to dismiss.

  LOCAL key$

  CLS
  PRINT @(0, 10) "PicoGopher v" + VERSION$ + " - Help";
  PRINT @(0, 22) STRING$(40, "-");
  PRINT @(10, 40) "Navigation:";
  PRINT @(10, 55) "Up/Down     Navigate menu items"
  PRINT @(10, 70) "Left/Right  Horizontal scroll"
  PRINT @(10, 85) "Enter       Select item"
  PRINT @(10, 100) "B           Go back"
  PRINT @(10, 115) "^           Go to home server"
  PRINT @(10, 135) "Features:";
  PRINT @(10, 150) "G           Go to address"
  PRINT @(10, 165) "A           Add bookmark"
  PRINT @(10, 180) "ESC         View bookmarks"
  PRINT @(10, 195) "R           Recently visited"
  PRINT @(10, 215) "Other:";
  PRINT @(10, 230) "Q           Quit"
  PRINT @(10, 245) "?           This help screen"
  PRINT @(0, SCREEN_HEIGHT - 28) "Press any key to close...";

  ' Wait for any key
  DO
    key$ = INKEY$
    IF key$ <> "" THEN EXIT DO
    PAUSE 20
  LOOP
END SUB

' ================================================
' PHASE 5: MAIN MENU FETCHER
' ================================================

SUB FetchAndDisplayMenu()
  ' Fetch and display menu from current host/selector/port
  ' Includes retry/back/home error recovery on connect or send failure

  LOCAL choice$

  menuCount = 0
  selectedIndex = 0
  menuScrollX = 0
  pageStart = 0

  ' Connection retry loop
  DO
    CLS
    PRINT @(10, 100) "Loading menu from " + currentHost$ + "..."

    GopherConnect(currentHost$, currentPort)

    IF tcpConnected = 0 THEN
      choice$ = ShowError$("Connection Failed", lastError$)
      IF choice$ = "R" THEN
        ' Retry - loop continues
      ELSEIF choice$ = "B" THEN
        NavigateBack()
        EXIT SUB
      ELSEIF choice$ = "G" THEN
        GotoCustomAddress()
        EXIT SUB
      ELSE
        ' Home
        currentHost$ = DEFAULT_HOST$
        currentSelector$ = "/"
        currentPort = DEFAULT_PORT
      ENDIF
    ELSE
      EXIT DO
    ENDIF
  LOOP

  ' Send request with retry
  DO
    GopherSend(currentSelector$)

    IF LEN(lastError$) > 0 THEN
      GopherClose()
      choice$ = ShowError$("Request Failed", lastError$)
      IF choice$ = "R" THEN
        ' Reconnect and retry
        GopherConnect(currentHost$, currentPort)
        IF tcpConnected = 0 THEN
          choice$ = ShowError$("Connection Failed", lastError$)
          IF choice$ = "B" THEN
            NavigateBack()
            EXIT SUB
          ELSEIF choice$ = "G" THEN
            GotoCustomAddress()
            EXIT SUB
          ELSEIF choice$ = "^" THEN
            currentHost$ = DEFAULT_HOST$
            currentSelector$ = "/"
            currentPort = DEFAULT_PORT
            GopherConnect(currentHost$, currentPort)
          ENDIF
        ENDIF
      ELSEIF choice$ = "B" THEN
        NavigateBack()
        EXIT SUB
      ELSEIF choice$ = "G" THEN
        GotoCustomAddress()
        EXIT SUB
      ELSE
        ' Home
        currentHost$ = DEFAULT_HOST$
        currentSelector$ = "/"
        currentPort = DEFAULT_PORT
        GopherConnect(currentHost$, currentPort)
      ENDIF
    ELSE
      EXIT DO
    ENDIF
  LOOP

  ' Read and parse menu lines from TCP response
  LOCAL line$, itemType$, display$, selector$, host$
  LOCAL port, i

  DO
    ReadGopherLine(line$)

    ' CHR$(0) sentinel means no more data in buffer
    IF line$ = CHR$(0) THEN EXIT DO
    IF line$ = "." THEN EXIT DO
    IF menuCount >= MAX_MENU_ITEMS THEN EXIT DO

    ParseMenuLine(line$, itemType$, display$, selector$, host$, port)
    menuType$(menuCount) = itemType$
    menuDisp$(menuCount) = LEFT$(display$, 80)
    menuSel$(menuCount) = LEFT$(selector$, 128)
    menuHost$(menuCount) = LEFT$(host$, 64)
    menuPort(menuCount) = port
    menuCount = menuCount + 1
  LOOP

  GopherClose()

  ' Find first and last selectable (non-info) items for edge-scrolling
  LOCAL si
  firstSelectable = -1
  lastSelectable = -1
  FOR si = 0 TO menuCount - 1
    IF menuType$(si) <> "i" THEN
      IF firstSelectable = -1 THEN firstSelectable = si
      lastSelectable = si
    ENDIF
  NEXT si

  ' Track this page in recently visited list
  LOCAL pageTitle$
  IF menuCount > 0 THEN
    pageTitle$ = currentHost$ + currentSelector$
  ELSE
    pageTitle$ = currentHost$
  ENDIF
  PushRecent(pageTitle$, currentHost$, currentSelector$, currentPort)

  menuDirty = 1  ' Mark menu for redraw
END SUB

' ================================================
' PHASE 5: NAVIGATION TO ITEMS
' ================================================

SUB NavigateToItem(index)
  ' Handle navigation based on menu item type
  LOCAL itemType$, host$, selector$, port

  IF index < 0 OR index >= menuCount THEN EXIT SUB

  itemType$ = menuType$(index)
  host$ = menuHost$(index)
  selector$ = menuSel$(index)
  port = menuPort(index)

  SELECT CASE itemType$
    ' Text file
    CASE "0"
      PushHistory(currentHost$, currentSelector$, currentPort)
      ViewTextFile(host$, selector$, port)
      menuDirty = 1  ' Redraw menu after returning from text viewer

    ' Menu/directory
    CASE "1"
      PushHistory(currentHost$, currentSelector$, currentPort)
      currentHost$ = host$
      currentSelector$ = selector$
      currentPort = port
      FetchAndDisplayMenu()

    ' Search server
    CASE "7"
      PushHistory(currentHost$, currentSelector$, currentPort)
      SearchGopher(selector$, host$, port)

    ' Error message
    CASE "3"
      statusMsg$ = "Error: " + menuDisp$(index)
      statusTimeout = TIMER + 3000
      menuDirty = 1

    ' Informational (non-clickable)
    CASE "i"
      ' Do nothing

    CASE ELSE
      statusMsg$ = "Type '" + itemType$ + "' not supported"
      statusTimeout = TIMER + 3000
      menuDirty = 1
  END SELECT
END SUB

' ================================================
' PHASE 6: SEARCH SUPPORT
' ================================================

SUB PushSearchHistory(query$, host$, port)
  ' Add a search query to the search history ring buffer.
  ' Shifts oldest entry out if full. Same pattern as PushHistory.

  LOCAL i

  IF searchHistCount >= MAX_SEARCH_HIST THEN
    ' Shift all entries down by one, dropping the oldest (index 0)
    FOR i = 0 TO MAX_SEARCH_HIST - 2
      searchHistQuery$(i) = searchHistQuery$(i + 1)
      searchHistHost$(i) = searchHistHost$(i + 1)
      searchHistPort(i) = searchHistPort(i + 1)
    NEXT i
    searchHistCount = MAX_SEARCH_HIST - 1
  ENDIF

  searchHistQuery$(searchHistCount) = LEFT$(query$, 128)
  searchHistHost$(searchHistCount) = LEFT$(host$, 64)
  searchHistPort(searchHistCount) = port
  searchHistCount = searchHistCount + 1
END SUB

SUB SearchGopher(selector$, host$, port)
  ' Handle Gopher search (type 7) with search history recall

  LOCAL query$, i, y

  CLS
  PRINT @(10, 30) "Enter search query:"

  ' Show recent search history if available
  IF searchHistCount > 0 THEN
    PRINT @(10, 50) "Recent searches:"
    FOR i = 0 TO searchHistCount - 1
      y = 65 + i * LINE_HEIGHT
      PRINT @(10, y) STR$(i + 1) + ") " + LEFT$(searchHistQuery$(i), 34)
    NEXT i
    PRINT @(10, y + 20) "Type number to reuse, or new query:"
  ENDIF

  LINE INPUT query$

  IF query$ = "" THEN
    EXIT SUB
  ENDIF

  ' Check if user typed a number to recall a search
  IF LEN(query$) = 1 THEN
    LOCAL idx
    idx = VAL(query$) - 1
    IF idx >= 0 THEN
      IF idx < searchHistCount THEN
        query$ = searchHistQuery$(idx)
      ENDIF
    ENDIF
  ENDIF

  ' Save to search history
  PushSearchHistory(query$, host$, port)

  ' Build search request: selector + TAB + query
  LOCAL searchSelector$ = selector$ + TAB$ + query$

  currentHost$ = LEFT$(host$, 64)
  currentSelector$ = LEFT$(searchSelector$, 128)
  currentPort = port

  FetchAndDisplayMenu()
END SUB

SUB GotoCustomAddress()
  ' Prompt for and navigate to a custom gopher address
  ' Format: host:port/selector (e.g., gopher.floodgap.com:70/gopher)

  CLS
  PRINT @(10, 50) "Enter Gopher address:"
  PRINT @(10, 65) "Format: host:port/selector"
  PRINT @(10, 85) "Example: gopher.floodgap.com:70/"
  PRINT @(10, 105) "Address:"

  LOCAL addressInput$, colonPos, slashPos, portStr$
  LOCAL newHost$, newSelector$, newPort

  ' Get input from user
  INPUT addressInput$

  IF LEN(addressInput$) = 0 THEN
    EXIT SUB
  ENDIF

  ' Parse the address: find colon for port
  colonPos = INSTR(addressInput$, ":")
  IF colonPos = 0 THEN
    ' No colon, assume default port 70
    slashPos = INSTR(addressInput$, "/")
    IF slashPos = 0 THEN
      newHost$ = addressInput$
      newSelector$ = "/"
    ELSE
      newHost$ = LEFT$(addressInput$, slashPos - 1)
      newSelector$ = MID$(addressInput$, slashPos)
    ENDIF
    newPort = 70
  ELSE
    ' Found colon, parse host and port
    newHost$ = LEFT$(addressInput$, colonPos - 1)
    slashPos = INSTR(addressInput$, "/")
    IF slashPos = 0 THEN
      portStr$ = MID$(addressInput$, colonPos + 1)
      newSelector$ = "/"
    ELSE
      portStr$ = MID$(addressInput$, colonPos + 1, slashPos - colonPos - 1)
      newSelector$ = MID$(addressInput$, slashPos)
    ENDIF
    newPort = VAL(portStr$)
    IF newPort = 0 THEN newPort = 70  ' Default if parsing failed
  ENDIF

  ' Save current location and navigate
  PushHistory(currentHost$, currentSelector$, currentPort)
  currentHost$ = LEFT$(newHost$, 64)
  currentSelector$ = LEFT$(newSelector$, 128)
  currentPort = newPort
  menuDirty = 1  ' Force menu redraw
  FetchAndDisplayMenu()
END SUB

' ================================================
' MAIN PROGRAM
' ================================================

SUB Main()
  ' Initialize
  CLS
  PRINT @(50, 100) "PicoGopher v" + VERSION$
  PRINT @(50, 120) "Initializing..."

  PAUSE 1000

  ' Setup WiFi
  InitWiFi()

  ' Initialize state
  running = 1
  histIndex = 0
  selectedIndex = 0
  currentHost$ = DEFAULT_HOST$
  currentSelector$ = ""
  currentPort = DEFAULT_PORT

  ' Fetch initial menu
  FetchAndDisplayMenu()

  ' Main loop
  DO WHILE running
    ' Clear status message after timeout
    IF LEN(statusMsg$) > 0 AND statusTimeout > 0 THEN
      IF TIMER >= statusTimeout THEN
        statusMsg$ = ""
        statusTimeout = 0
        menuDirty = 1
      ENDIF
    ENDIF

    DisplayMenu()
    HandleInput()
    PAUSE 20
  LOOP

  CLS
  PRINT @(50, 100) "Thank you for using PicoGopher!"
  PAUSE 1000
  CLS
END SUB

' ================================================
' HELPER FUNCTIONS
' ================================================

FUNCTION FILE_EXISTS(filename$) AS INTEGER
  ' Check if file exists by attempting to open it
  ON ERROR IGNORE
  OPEN filename$ FOR INPUT AS #4
  IF MM.ERRNO = 0 THEN
    CLOSE #4
    FILE_EXISTS = 1
  ELSE
    FILE_EXISTS = 0
  ENDIF
  ON ERROR ABORT
END FUNCTION

' ================================================
' PROGRAM ENTRY
' ================================================

' Start program
CALL Main()
END
