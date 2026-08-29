# Ledge v1 — Implementation Blueprint

## Goal

Build a lightweight, native macOS utility that stays completely invisible while
idle and reveals a polished bottom-edge shelf when the pointer or a Finder drag
approaches the bottom of the active display.

Ledge has two v1 tools:

1. A persistent file transit shelf.
2. A persistent, single-draft plain-text scratchpad.

The app runs as a menu-bar utility with no Dock icon. Clicking the menu-bar icon
opens Settings.

## Product decisions

- Product name: **Ledge**
- Runtime: macOS 13 or newer; distribute outside the App Store through DMG
- UI stack: native AppKit windowing and drag/drop, SwiftUI content
- Idle state: fully invisible
- Wake behavior: a narrow bottom-center zone slides in a compact confirmation
  tab whose bottom edge is flush with the screen; only clicking its visible
  rounded-top shape opens Note
- Multi-display default: follow the pointer/current display
- Files: move dropped files into an owner-only local Transit directory
- Batch drops: supported
- Successful drag-out: move the real file to the destination and remove metadata
- Legacy bookmarks: read-only compatibility; never auto-migrate at launch
- Draft: one untitled plain-text document, continuously persisted
- Menu bar: icon opens Settings
- Settings: launch at login, display behavior, and wake sensitivity

## Architecture

### Targets

- `LedgeCore`
  - Value models and immutable state transitions
  - Transit file storage plus legacy bookmark compatibility
  - Draft persistence
  - Settings persistence
  - No AppKit window dependencies
- `Ledge`
  - App lifecycle and menu-bar item
  - Bottom-edge pointer/drag monitor
  - Borderless floating panel
  - SwiftUI shelf, scratchpad, and settings views
  - Finder drag/drop bridge
- `LedgeCoreTests`
  - State, persistence, migration, invalid-reference, and removal-policy tests

### Runtime components

- `AppDelegate`: menu-bar lifecycle, status item, settings panel, service wiring
- `EdgeActivationController`: tracks pointer and left-drag location, chooses
  display, debounces reveal/hide, and never steals focus merely on hover
- `LedgePanelController`: owns a key-capable borderless panel; hover reveal uses
  `orderFrontRegardless`, while opening Note explicitly activates the app and
  assigns the text editor as first responder
- `FileDropReceiver`: accepts multiple file URLs with `.move` semantics and exports
  Transit URLs with `.move`
- `TransitStore`: validates, moves, rolls back, resolves, recovers, and finalizes
  files under UUID-isolated containers
- `AppModel`: main-thread observable state composed from immutable core values
- `LaunchAtLoginController`: wraps `SMAppService.mainApp`

### Persistence

Store local-only data under `~/Library/Application Support/Ledge/` with owner
read/write permissions:

- `shelf.json`: Transit relative paths plus legacy bookmark metadata
- `Transit/<UUID>/<original name>`: real staged files and folders
- `draft.txt`: UTF-8 plain text, atomically replaced
- `settings.json`: user-adjustable preferences

New drops are moved into Transit, so the source disappears from its old
location. Existing bookmark records from older versions remain compatible and
are never moved merely because the app launches. Ledge has no network client,
analytics, or telemetry. It never logs draft contents, bookmark bytes, full
paths, or pointer history.

## Interaction states

`hidden → prompt → note`

- `hidden`: no visible pixels and no active app window
- `prompt`: a 48×26 pt bottom-attached tab with rounded top corners, square
  bottom corners, and a green confirmation arrow
- `files`: the 720×224 expanded file-moving surface
- `note`: the same 720×224 frame with the scratchpad content

Transitions:

- pointer enters the narrow wake zone → the tab slides in from below screen
- only a click inside the visible tab shape → `note`
- Finder drag enters the bottom drag zone → `files` immediately
- click either half of the expanded toolbar → the selected surface
- pointer exits an unconfirmed prompt → delayed `hidden`
- Escape or outside click while unfocused → `hidden`

Every visible state stays at the macOS status-bar window level, across Spaces
and full-screen apps. The panel follows the pointer's display by default.
Settings can pin it to the main display.

## Visual direction

Inspired by the qualities of Grammarly's desktop surface, without copying its
assets or branding:

- compact edge-origin interaction
- adaptive translucent layered surfaces for light and dark appearances
- native SF typography with strong hierarchy
- restrained emerald accent
- 18–22 pt corner radii
- subtle border plus layered shadow
- 95 ms edge slide-in and a 103 ms overshoot/settle pop transition
- clear drag-target feedback and invalid-item state

The interface should feel quiet while empty and information-dense only when
content exists.

## TDD slices

1. Settings defaults and JSON round-trip.
2. Shelf item encoding, immutable transitions, and legacy bookmark decoding.
3. Transit move, rollback, collision isolation, traversal blocking, and recovery.
4. Successful `.move` export finalization.
5. Draft round-trip and atomic replacement behavior.
6. Edge activation geometry and display selection.

For each slice: write a failing test, implement the minimum behavior, refactor,
then run the full suite.

## Acceptance criteria

- Launching `Ledge.app` shows no Dock icon and provides a menu-bar icon.
- Ledge is fully invisible after the hide delay.
- Moving the pointer into the bottom-center wake zone reveals the bottom tab.
- Dragging one or many Finder files/folders toward the bottom reveals the shelf.
- Dropped files disappear from their source location and persist inside Transit.
- Dragging a Transit item into Finder reports `.move`, produces a normal file at
  the destination, and removes the internal source and shelf metadata.
- Same-name files use separate UUID containers and never overwrite one another.
- Invalid or failed batches do not partially disappear; rollback/recovery keeps
  every file discoverable.
- The scratchpad autosaves plain text and restores it after relaunch.
- Settings can control launch at login, display behavior, and wake sensitivity.
- Unit tests pass and core target coverage is at least 80%.
- A local `dist/Ledge.app` is produced and launches on this Mac.
- `plutil -lint` and `codesign --verify --deep --strict` pass for the bundle.
- Chinese IME, copy/paste, undo, Escape, and focus restoration work in Note.

## Risks and mitigations

- **False drag activation:** a global left-drag event alone is never sufficient.
  Reveal Files only when the system drag pasteboard can be decoded as file URLs
  and the pointer is inside the dedicated bottom drag zone.
- **Cross-volume moves:** fall back to copy-verify-delete and roll back if source
  removal fails.
- **Crash/persistence recovery:** scan UUID Transit containers and recover
  orphaned files without touching legacy bookmark sources.
- **Path traversal:** accept only validated UUID/name relative paths inside the
  owner-only Transit root.
- **Focus stealing:** reveal a key-capable borderless panel without activation
  for hover/drop; call `NSApp.activate` only for scratchpad or Settings.
- **Login item API requirements:** show an actionable settings error if the
  locally built app is not yet in a stable Applications location.
- **No full Xcode:** use SwiftPM plus deterministic app/DMG scripts. Local test
  builds use ad-hoc signing; public builds require Developer ID signing and
  Apple notarization.
- **Local private data:** Transit files, bookmarks, and drafts remain local.
  Never log their contents; expose Reveal Data for manual inspection.

## Delivery phases

1. Bootstrap Swift package and failing core tests.
2. Implement persistence and state transitions.
3. Add menu-bar lifecycle and panel controller.
4. Add shelf drag/drop and scratchpad UI.
5. Add settings and launch-at-login behavior.
6. Bundle with `Info.plist` (`LSUIElement=true`), sign, validate, launch,
   visually inspect, and review.
