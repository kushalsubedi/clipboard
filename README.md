# ClipboardMini

A menu bar clipboard manager for macOS. No Dock icon, no separate windows —
click the clipboard icon in the menu bar and a single popover panel opens
with your clipboard history, grouped into sessions, backed by SQLite.

## Features

- **Persistent history** — every text copy is written to a SQLite database
  at `~/Library/Application Support/ClipboardMini/clipboard.sqlite3`, so
  history survives restarts.
- **Sessions** — group clips into named contexts (e.g. "Work", "Research").
  Switch between them from the header menu; each keeps its own history.
- **Preview + expand** — rows show a 3-line preview; click to expand and
  read the full clip.
- **Edit in place** — expand a clip and hit Edit to change its text before
  copying it back out.
- **Pin** — pin important clips so "Clear Unpinned" and future trimming
  never touch them.
- **Search** — filter the current session's clips as you type.
- **Copy / Delete** — one click each, from the expanded row or a right-click
  context menu.

## Project layout

```
ClipboardMini/
├── Package.swift
└── Sources/ClipboardMini/
    ├── main.swift            entry point
    ├── AppDelegate.swift      status item + popover
    ├── ContentView.swift      header, session picker, search, list
    ├── ClipRow.swift          single clip: preview / expand / edit
    ├── ClipboardStore.swift   pasteboard polling + app state
    ├── Database.swift         SQLite3 wrapper
    └── Models.swift           Clip / Session structs
```

## Build & run

Requires Xcode Command Line Tools (`xcode-select --install` if needed).

```bash
cd ClipboardMini
swift build -c release
.build/release/ClipboardMini
```

The clipboard icon appears in the menu bar immediately. Click it to open
the panel; click outside to dismiss (it's a transient popover, like
Spotlight). Quit from the power icon in the footer.

## Package as a real .app (double-click / Login Items)

```bash
swift build -c release
mkdir -p ClipboardMini.app/Contents/MacOS
cp .build/release/ClipboardMini ClipboardMini.app/Contents/MacOS/
cat > ClipboardMini.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClipboardMini</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.clipboardmini</string>
    <key>CFBundleName</key>
    <string>ClipboardMini</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF
open ClipboardMini.app
```

Drag `ClipboardMini.app` into `/Applications`, then add it to
**System Settings → General → Login Items** to have it start automatically.

## Notes / things you might want next

- Only plain text is captured right now (no images/files). The pasteboard
  check in `ClipboardStore.checkPasteboard()` is the place to add
  `NSPasteboard.PasteboardType.tiff` / `.fileURL` handling.
- No global keyboard shortcut to open the panel — only the menu bar click.
  Adding one needs either the older Carbon hotkey API or a small
  dependency like HotKey; say the word if you want it wired in.
- Clip history per session isn't capped yet — it'll grow indefinitely.
  Easy to add a trim (e.g. keep the last 500 unpinned rows per session) in
  `Database.insertClip`.
- Sessions are just a grouping label, not time-windowed — you choose which
  session is "active" and everything you copy goes there until you switch.
