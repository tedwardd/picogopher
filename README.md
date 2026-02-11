# PicoGopher - Gopher Client for PicoMite

A lightweight Gopher protocol browser for the Raspberry Pi Pico 2W running PicoMite firmware. Browse Gopher menu hierarchies, view text files, manage bookmarks, and explore the vintage Gopher network on a resource-constrained microcontroller.

## Features

- **Gopher Protocol Support**: Full RFC 1436 compatible text-based menu browsing
- **Menu Navigation**: Arrow keys to navigate, left/right to horizontal scroll, Enter to select items
- **Text Viewer**: Word-wrapped text with page up/down scrolling
- **Bookmark Management**: Save, load, and manage bookmarks (press 'A' to add, ESC to view)
- **History Stack**: Back button to return to previous menus
- **Recently Visited**: Viewable list of recently visited pages (press 'R')
- **Search History**: Recall previous search queries when using Gopher search
- **Error Recovery**: Interactive retry/back/home options on connection failures
- **Help Menu**: Press '?' for a full list of key bindings
- **Simple Display**: Works with graphics LCD displays (~320x320 pixels)
- **WiFi Connectivity**: Browse public Gopher servers over WiFi

## Hardware Requirements

- **Microcontroller**: Raspberry Pi Pico 2W with PicoMite firmware
- **Display**: Graphics LCD (320x320 recommended, adjustable in code)
- **Input**: QWERTY keyboard with arrow keys
- **Network**: WiFi connectivity (built-in to Pico 2W)

## Installation

### 1. Prepare Hardware

1. Flash PicoMite firmware to Raspberry Pi Pico 2W
2. Connect graphics LCD display to GPIO pins
3. Connect keyboard input (USB or GPIO-based)
4. Verify WiFi connectivity

### 2. Upload Files

Transfer to your PicoMite device:

```
gopher.bas          - Main program
bookmarks.txt       - Bookmark storage (created empty)
```

### 3. Configure WiFi

WiFi credentials are stored in PicoMite's flash memory. Run this once from the PicoMite console:

```basic
OPTION WIFI your_ssid, your_password
```

Replace with your actual WiFi network credentials. This only needs to be done once; the setting persists across reboots.

### 4. Run Program

In PicoMite BASIC:

```basic
RUN "gopher.bas"
```

## Usage Guide

### Navigation

| Key | Action |
|-----|--------|
| **↑/↓** | Navigate menu items |
| **←/→** | Horizontal scroll (view long lines) |
| **Enter** | Select highlighted item |
| **B** | Back to previous menu |
| **A** | Add current item as bookmark |
| **ESC** | View bookmarks |
| **R** | Recently visited pages |
| **G** | Go to custom Gopher address |
| **?** | Help menu (all key bindings) |
| **Q** | Quit program |

### Text Viewer Controls

| Key | Action |
|-----|--------|
| **↑/↓** | Scroll up/down one line |
| **Page Up/Down** | Scroll one page |
| **Q** | Exit viewer and return to menu |

### Bookmark Management

1. **Save Bookmark**: Press 'A' on any menu item (type 0 or 1)
2. **View Bookmarks**: Press 'ESC' to open bookmark list
3. **Use Bookmark**: Select with arrow keys, press Enter to navigate
4. **Edit Manually**: Edit `bookmarks.txt` with text editor

**Bookmark Format** (tab-delimited):
```
Display Name[TAB]selector[TAB]host[TAB]port
```

Example:
```
Floodgap Systems	/	gopher.floodgap.com	70
```

## Gopher Item Types

The client supports the following Gopher item types:

| Type | Description | Action |
|------|-------------|--------|
| **0** | Text file | Display with scrolling text viewer |
| **1** | Menu/Directory | Fetch and display as menu |
| **3** | Error message | Display error text |
| **7** | Search server | Prompt for query, display results |
| **i** | Informational | Display as text (non-clickable) |

**Not Supported** (future enhancement):
- Type 5, 9: Binary files (would need file save)
- Type g, I: Image files (no image viewer)
- Type 8: Telnet service (network complexity)
- Type e, w, M: Other media types

## Recommended Test Servers

### Public Gopher Servers

```
gopher.floodgap.com:70     - Floodgap Systems (most reliable)
gopher.quux.org:70         - Quux.org
sdf.org:70                 - SDF Public Access Unix
gopherns.com:70            - Gopherns (modern Gopher)
```

### Test Bookmarks

Add these to `bookmarks.txt` for quick testing:

```
Floodgap	/	gopher.floodgap.com	70
Quux	/	gopher.quux.org	70
SDF	/	sdf.org	70
Gopherns	/	gopherns.com	70
```

## Configuration

### Display Settings

Edit `gopher.bas` to adjust for your display:

```basic
CONST SCREEN_WIDTH = 320       ' Width in pixels
CONST SCREEN_HEIGHT = 320      ' Height in pixels
CONST LINE_HEIGHT = 10         ' Pixels per line
CONST CHARS_PER_LINE = 40      ' Characters visible per line
CONST LINES_PER_PAGE = 25      ' Menu items per page
```

### Memory Limits

```basic
CONST MAX_MENU_ITEMS = 80      ' Max items in single menu
CONST MAX_TEXT_LINES = 200     ' Max lines in text file
CONST MAX_HISTORY = 10         ' Max back history depth
CONST MAX_BOOKMARKS = 30      ' Max bookmarks
```

All string arrays use `LENGTH` to minimize heap usage (~45 KB total).
Adjust based on available PicoMite RAM (~100-160 KB heap on Pico 2W).

### TCP Settings

```basic
CONST TCP_TIMEOUT = 10000      ' Connection timeout (ms)
```

## Architecture

The program is organized into functional modules:

```
Main Program (gopher.bas)
├── Phase 1: Network & Protocol
│   ├── InitWiFi()              - WiFi connection check
│   ├── GopherConnect/Send/Close - TCP client
│   ├── ReadGopherLine()        - Buffered line reader
│   └── ParseMenuLine()         - Menu parsing
│
├── Phase 2: Display & Navigation
│   ├── DisplayMenu()           - Menu rendering with type indicators
│   ├── DisplayTextPage()       - Text page rendering
│   ├── HandleInput()           - Keyboard input (skips info items)
│   ├── PushHistory()           - Navigation history (shifts on overflow)
│   └── NavigateBack()          - Back functionality
│
├── Phase 3: Text Viewer
│   └── ViewTextFile()          - Fetch & display text with scrolling
│
├── Phase 4: Bookmarks
│   ├── SaveBookmark()          - Add bookmark
│   └── ShowBookmarks()         - Bookmark list
│
├── Phase 5: Main Logic
│   ├── FetchAndDisplayMenu()   - Menu fetcher (with connection guard)
│   └── NavigateToItem()        - Item navigation
│
└── Phase 6: Search & Address Bar
    ├── SearchGopher()          - Type 7 search
    └── GotoCustomAddress()     - Manual address entry
```

## Limitations & Known Issues

### Current Limitations

1. **String Length**: mmBASIC 255-char limit; arrays use `LENGTH` to save heap
2. **Memory**: ~45 KB heap usage; 80 menu items, 200 text lines, 30 bookmarks
3. **Media Types**: No image/binary file support yet
4. **Display**: Monochrome text only (color support possible with LCD driver)
5. **Network**: Single concurrent connection, basic error handling

### mmBASIC Constraints

| Constraint | Solution |
|-----------|----------|
| 255-char strings | Read TCP in chunks, accumulate into buffer |
| Limited arrays | Fixed-size arrays with LENGTH, 80 items per menu |
| No threading | Single-threaded main loop |
| No file handles in WebMite | Use WEB TCP CLIENT commands |

## Debugging

### Enable Debug Output

Add this to `Main()` after initialization:

```basic
PRINT "=== PicoGopher Debug ==="
PRINT "Host: " + currentHost$
PRINT "Port: " + IntToStr$(currentPort)
PRINT "Selector: " + currentSelector$
```

### Common Issues

**Problem**: "WiFi not connected"
- **Solution**: Run `OPTION WIFI ssid, password` from the PicoMite console

**Problem**: "Cannot connect to server"
- **Solution**: Check WiFi connection, verify server is online (try gopher.floodgap.com)

**Problem**: "Menu displays empty or truncated"
- **Solution**: Check MAX_MENU_ITEMS and menuCount limits

**Problem**: "Text viewer shows "Loading..." indefinitely**
- **Solution**: Server may be timing out - try different server or increase TCP_TIMEOUT

**Problem**: "Keyboard input not working"
- **Solution**: Verify INKEY$ function and arrow key codes for your PicoMite build

## Future Enhancements

### Phase 7: Media Support
- Binary file download to SD card
- Simple image display (GIF/PPM format)
- Audio file playback (.wav)

### Phase 8: Advanced Features
- Search history/suggestions
- Recently visited list
- Color themes and UI customization
- Configuration persistence

### Phase 9: Performance
- Menu caching on SD card
- Incremental line loading
- Parallel multiple connections
- Compression support

## Development Notes

### mmBASIC Specifics

The program uses PicoMite-specific features:

```basic
' Web/TCP client (not traditional file I/O)
WEB OPEN TCP CLIENT host$, port
WEB TCP CLIENT REQUEST data$
INPUT$(n, #1)                  ' Read n chars from TCP

' Keyboard input
INKEY$                         ' Non-blocking key read

' String operations
INSTR(str, substr)            ' Find substring
MID$(str, pos, len)           ' Extract substring
LEFT$(str, len)               ' Left substring
RIGHT$(str, len)              ' Right substring

' Screen control
CLS                           ' Clear screen
PRINT @(x, y) text$          ' Position print
```

### Testing Strategy

See TESTING.md for comprehensive test plans and procedures.

## License

This project is provided as-is for educational and hobbyist use. The Gopher protocol is in the public domain.

## References

- [RFC 1436 - The Internet Gopher Protocol](https://tools.ietf.org/html/rfc1436)
- [Gopher Ecosystem](https://en.wikipedia.org/wiki/Gopher_(protocol))
- [Floodgap's Gopher Guide](https://gopher.floodgap.com)
- [PicoMite Documentation](https://www.picomite.org)
- [Raspberry Pi Pico 2W](https://www.raspberrypi.org/products/raspberry-pi-pico-2-w/)

## Support

For issues or questions:

1. Check README.md and TESTING.md
2. Review gopher.bas comments for implementation details
3. Verify hardware connections and firmware version
4. Try a different Gopher server for testing

---

**Version**: 1.0
**Last Updated**: February 10, 2025
**Author**: Claude
**Platform**: PicoMite on Raspberry Pi Pico 2W
