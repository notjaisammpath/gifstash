# GifStash

An iMessage app for searching and bookmarking GIFs. Search GIPHY (or Tenor)
straight from a conversation, tap to drop a GIF into the message field, and
bookmark the ones worth keeping so they are one tap away next time.

- **GIPHY-first**, with Tenor behind the same `GifProvider` protocol and
  switchable at runtime from Settings.
- **Bookmarks shared** between the host app and the extension via an App Group.
- **No third-party dependencies.** GIF playback uses ImageIO
  (`CGAnimateImageDataWithBlock`); networking is plain `URLSession`.
- **Keys stay out of git.** They are injected from a gitignored xcconfig into
  each target's Info.plist at build time.

## Requirements

iMessage app extensions can only be built and run with Xcode on macOS.

- macOS with Xcode 15 or newer
- iOS 17.0+ target (simulator is fine; a real device needs an Apple Developer team)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- A free [GIPHY API key](https://developers.giphy.com/dashboard/)

## Setup

```bash
git clone <this repo>
cd gifstash

cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
# edit Config/Secrets.xcconfig: add GIPHY_API_KEY and your BUNDLE_ID_PREFIX

./scripts/bootstrap.sh     # runs xcodegen and opens the project
```

Then pick the **GifStash** scheme and run. To try it in the simulator, launch
Messages, open any conversation, tap the **+** next to the text field, choose
**More**, and enable GifStash.

### Without XcodeGen

The project file is generated rather than committed, so there is nothing to
open until you run `xcodegen generate`. If you would rather not install it:
create a new Xcode project from the **iMessage Application** template, then add
the files under `Sources/Shared` to *both* targets, `Sources/App` to the app,
and `Sources/MessagesExtension` to the extension. Set the same App Group on
both targets and point `INFOPLIST_FILE` at the plists in this repo.

## Configuration

Everything configurable lives in `Config/Secrets.xcconfig`:

| Setting | What it does |
| --- | --- |
| `GIPHY_API_KEY` | GIPHY key. Without it the app shows a "No API key" state. |
| `TENOR_API_KEY` | Optional. Leave blank and Tenor is greyed out in Settings. |
| `BUNDLE_ID_PREFIX` | Reverse-DNS prefix you control. Also derives the App Group. |
| `DEVELOPMENT_TEAM` | 10-character Apple Developer team ID, for device builds. |

`Config/Shared.xcconfig` holds the defaults and `#include?`s the secrets file
last, so your values win. An unset key expands to an empty string, which
`AppConfig` treats as absent.

## Layout

```
Sources/
  Shared/              compiled into both targets
    Models/            GifItem - one normalized GIF
    Providers/         GifProvider protocol, GIPHY, Tenor, GifCatalog
    Store/             BookmarkStore, Preferences (App Group backed)
    Net/               GifLoader - caching downloader
    UI/                GifBrowserView and friends - the whole picker
    AppConfig.swift    reads injected keys out of Info.plist
  App/                 host app: browse, share, setup instructions
  MessagesExtension/   MessagesViewController - hosts the picker, inserts GIFs
Config/                xcconfig defaults and the secrets template
Resources/             app asset catalog
```

`GifBrowserView` is used verbatim by both targets. The only difference is the
`onSelect` closure: the extension inserts into the conversation, the host app
opens a share sheet.

## How a few things work

**Sending.** Tapping a GIF downloads the full rendition to a temp file and
calls `insertAttachment`, which puts it in the message *input field* instead of
sending it immediately — so you can add text or back out. The extension then
collapses from expanded back to compact.

**Layout.** GIFs have wildly varying aspect ratios, and `LazyVGrid` leaves
ragged gaps because each row sizes to its tallest cell. `WaterfallGrid` packs
each item into whichever column is currently shortest. It is deterministic, so
appending a page never reshuffles what is already on screen.

**Paging.** Cursors are opaque strings defined per provider — GIPHY uses a
numeric offset, Tenor a `pos` token. The model requests the next page when the
last cell appears and de-dupes by id, since providers occasionally repeat an
item across pages.

**Bookmarks across processes.** App Group `UserDefaults` writes are not
observable from the other process, so `BookmarkStore.reload()` runs on
`willBecomeActive` in the extension and `onAppear` in the browser.

**Icons are generated.** `swift scripts/make-icons.swift` draws the app icon
and every iMessage App Icon size from one drawing, as opaque PNGs (App Store
Connect rejects alpha). Edit the script and re-run it rather than editing the
PNGs.

## Not done yet

- No tests. The provider decoders are the obvious first place for them.
- Bookmarks are local only; no iCloud sync.
- Bookmark reordering exists in `BookmarkStore.move` but is not wired to a UI.

## Attribution

GIF content comes from GIPHY or Tenor and their attribution is shown in the
picker footer, as both APIs require. Check their terms before shipping:
[GIPHY](https://support.giphy.com/hc/en-us/articles/360020027752-GIPHY-API-Terms-of-Service),
[Tenor](https://developers.google.com/tenor/guides/attribution).

## License

MIT — see [LICENSE](LICENSE).
