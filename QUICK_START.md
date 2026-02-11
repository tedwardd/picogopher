# PicoGopher - Quick Start Guide

Get your Gopher browser up and running in 5 minutes!

## Prerequisites

- Raspberry Pi Pico 2W with PicoMite firmware
- Graphics LCD display connected
- QWERTY keyboard with arrow keys
- WiFi network access

## Setup (5 minutes)

### 1. Configure WiFi

WiFi credentials are stored in PicoMite's flash memory. Run this once from the PicoMite console:

```basic
OPTION WIFI MyWiFiNetwork, SuperSecretPassword123
```

Replace with your actual SSID and password. This persists across reboots.

### 2. Upload Files to PicoMite

Transfer these files to your device:
- `gopher.bas` (main program)
- `bookmarks.txt` (bookmark storage)

### 3. Run the Program

In PicoMite BASIC:

```basic
RUN "gopher.bas"
```

That's it! You should see "PicoGopher v1.0" and start connecting to the default Gopher server.

---

## Using PicoGopher

### Navigation Keys

| Key | What It Does |
|-----|--------------|
| **↑** | Move up in menu |
| **↓** | Move down in menu |
| **Enter** | Select highlighted item |
| **B** | Go back to previous menu |
| **A** | Save current item as bookmark |
| **ESC** | View your bookmarks |
| **Q** | Quit program |

### In Text Viewer

| Key | What It Does |
|-----|--------------|
| **↑/↓** | Scroll one line up/down |
| **Page Up/Down** | Jump to previous/next page |
| **Q** | Exit and go back to menu |

---

## Try These

### 1. Browse a Menu

1. Program starts at `gopher.floodgap.com`
2. Use ↑↓ to move around
3. Press Enter to select an item

### 2. Read a Text File

1. Find an item (usually marked at the start)
2. Press Enter
3. Text file opens with scrolling
4. Press Q to go back

### 3. Go Back

1. Press B to return to previous menu
2. Press B again to go further back
3. Can go back up to 10 menus

### 4. Save a Bookmark

1. Find something you like (a menu or file)
2. Press A to add bookmark
3. See "Bookmark saved!" message

### 5. Use a Bookmark

1. Press ESC to open bookmarks
2. Use ↑↓ to select one
3. Press Enter to go there
4. Press ESC to cancel without selecting

---

## Recommended First Servers

The program starts at Floodgap Systems, which is great! But here are other good ones:

**Add to bookmarks.txt:**

```
Floodgap	/	gopher.floodgap.com	70
Quux	/	gopher.quux.org	70
SDF	/	sdf.org	70
```

Then press ESC to view and select them!

---

## Troubleshooting

### "WiFi not connecting"

1. Verify your credentials: run `OPTION WIFI ssid, password` from the console
2. Make sure device is in WiFi range
3. Try restarting the device

### "Can't connect to server"

1. Check WiFi is actually connected (try other program)
2. Try a different server (use a bookmark)
3. Server might be down - try `gopher.floodgap.com`

### "Menu is empty"

1. Server might be having issues
2. Try going back and selecting again
3. Try a different server

### "Text viewer won't scroll"

1. Try pressing arrow keys (↑ and ↓)
2. Text file might be empty
3. Try a different text file

### "Keyboard not working"

1. Check keyboard is connected properly
2. Try pressing keys slowly (not rapidly)
3. Make sure you're not holding keys down

---

## What You Can Do

✅ Browse Gopher menu hierarchies
✅ View text files with scrolling
✅ Navigate between servers
✅ Save and use bookmarks
✅ Go back to previous locations
✅ Search Gopher servers (type 7)

❌ Not yet: Download files
❌ Not yet: View images

---

## Menu Item Types (What You'll See)

When browsing, items have symbols showing what they are:

- **0** = Text file - Press Enter to read
- **1** = Menu/Folder - Press Enter to open
- **i** = Information - Can't select, just read
- **3** = Error - Shows error messages
- **7** = Search - Enter to search

---

## Tips & Tricks

### Tip 1: Create Bookmarks Folder

Create bookmarks for frequently visited locations:
```
Home	/	gopher.floodgap.com	70
SDF	/	sdf.org	70
Quux	/	gopher.quux.org	70
```

Press ESC anytime to jump to them!

### Tip 2: Deep Dive

You can navigate as deep as you want:
- Browse → Directory → Subdirectory → File
- Keep pressing Enter to go deeper
- Keep pressing B to come back

### Tip 3: Different Servers

Many items point to different servers. You can:
- Browse menu on server A
- Select item pointing to server B
- Press B to return to server A
- Works across servers!

### Tip 4: Long Text Files

For long text files, use keyboard:
- ↑↓ for line-by-line scrolling
- Page Up/Down for faster jumping
- Can read hundreds of lines

---

## Common Gopher Servers

These are reliable public Gopher servers you can try:

```
gopher.floodgap.com - Most reliable, good for starting
gopher.quux.org - Many Quux-related items
sdf.org - Large SDF public access server
gopherns.com - Modern Gopher content
```

---

## Next Steps

Once you're comfortable with basics:

1. **Read the full README.md** - More detailed features and options
2. **Check TESTING.md** - To verify your installation
3. **See DEVELOPMENT.md** - If you want to modify the code

---

## Keyboard Shortcut Cheat Sheet

```
Navigation
──────────
↑         Up one item
↓         Down one item
Enter     Select item

Menu Navigation
───────────────
B         Back to previous menu
Q         Quit program

Bookmarks
─────────
A         Add bookmark
ESC       View bookmarks

Text Viewer
───────────
↑↓        Scroll line by line
PgUp/PgDn Jump full page
Q         Exit viewer
```

---

## Frequently Asked Questions

**Q: Can I browse while offline?**
A: No, Gopher servers are accessed over the network.

**Q: How many bookmarks can I save?**
A: Up to 30 bookmarks in the bookmark system.

**Q: Can I edit bookmarks while running?**
A: Press A to add new ones. To remove, edit `bookmarks.txt` in a text editor.

**Q: What happens if a server is down?**
A: You'll get an error message. Try another server!

**Q: Can I search Gopher servers?**
A: Some servers support search (type 7). Select them and enter a search query.

**Q: How deep can I browse?**
A: Up to 10 levels of history for back button navigation.

---

## Getting Help

- **README.md** - Full feature documentation
- **TESTING.md** - Testing procedures and troubleshooting
- **DEVELOPMENT.md** - Technical details for advanced users

---

**Happy Gopher browsing!** 🚀

Remember: Gopher is a simple, elegant protocol for sharing information. Enjoy the experience!

---

**Version**: 1.0
**Last Updated**: February 10, 2025
