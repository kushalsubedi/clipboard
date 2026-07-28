# ClipboardMini

A menu bar clipboard manager for macOS. No Dock icon, no separate windows —
click (or just hover over) the clipboard icon in the menu bar and a single
popover panel opens with your clipboard history, grouped into sessions,
backed by SQLite.

## Features

- **Persistent history** — every copy is written to a SQLite database
  at `~/Library/Application Support/ClipboardMini/clipboard.sqlite3`, so
  history survives restarts.
- **Text, rich text, and images** — plain text, RTF (formatting preserved),
  and images (stored as PNG) are all captured. Copying a clip back puts the
  original format on the pasteboard; rich text also carries a plain-text
  fallback for apps that only accept plain text.
- **Open on hover** — optional (gear menu in the footer): the panel opens
  when the mouse hovers over the menu bar icon and closes when the mouse
  leaves the icon/panel. With it off, the icon works click-to-toggle.
- **Sessions** — group clips into named contexts (e.g. "Work", "Research").
  Switch between them from the header menu; each keeps its own history.
- **Preview + expand** — text rows show a 3-line preview, images a small
  thumbnail; click to expand for the full clip, formatted rich text, or a
  larger image.
- **Edit in place** — expand a plain-text clip and hit Edit to change its
  text before copying it back out.
- **Pin** — pin important clips so "Clear Unpinned" and future trimming
  never touch them.
- **Search** — filter the current session's clips as you type (images are
  searchable by their "Image W×H" label).
- **Copy / Delete** — one click each, from the expanded row or a right-click
  context menu.

## Project layout

```
ClipboardMini/
├── Package.swift
├── scripts/
│   └── build-pkg.sh           builds a distributable .pkg installer
└── Sources/ClipboardMini/
    ├── main.swift             entry point
    ├── AppDelegate.swift      status item + popover + hover open/close
    ├── ContentView.swift      header, session picker, search, list, settings
    ├── ClipRow.swift          single clip: preview / expand / edit / image
    ├── ClipboardStore.swift   pasteboard polling (text/RTF/image) + app state
    ├── Database.swift         SQLite3 wrapper (with schema migration)
    └── Models.swift           Clip / ClipKind / Session structs
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
Spotlight). Quit from the power icon in the footer. Enable **Open on
Hover** from the gear menu in the footer to make the panel appear on
mouse-over instead.

## Build a .pkg installer (share across devices)

```bash
./scripts/build-pkg.sh          # → dist/ClipboardMini-1.0.0.pkg
./scripts/build-pkg.sh 1.2.0    # optional version argument
```

The script builds a release binary, wraps it in a proper `ClipboardMini.app`
bundle (`LSUIElement` set, ad-hoc signed), and produces a `.pkg` that
installs to `/Applications`. Copy the `.pkg` to any Mac and double-click to
install, then add the app to **System Settings → General → Login Items** to
have it start automatically.

> The package is ad-hoc signed (no Apple Developer ID), so on another Mac,
> Gatekeeper may require right-click → Open on first launch, or approval
> under **System Settings → Privacy & Security**. For friction-free
> distribution, sign with a Developer ID certificate and notarize.

## Notes / things you might want next

- File copies aren't captured (a Finder file copy is deliberately skipped so
  the file's icon isn't stored as an image clip). `.fileURL` handling could
  be added in `ClipboardStore.capture(from:)`.
- No global keyboard shortcut to open the panel — only the menu bar
  click/hover. Adding one needs either the older Carbon hotkey API or a
  small dependency like HotKey; say the word if you want it wired in.
- Clip history per session isn't capped yet — it'll grow indefinitely
  (image blobs make this more noticeable). Easy to add a trim (e.g. keep the
  last 500 unpinned rows per session) in `Database.insertClip`.
- Sessions are just a grouping label, not time-windowed — you choose which
  session is "active" and everything you copy goes there until you switch.
