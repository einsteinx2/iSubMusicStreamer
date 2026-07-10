# Test Fixtures

Canned resources for the iSubTests unit/integration test suite. This folder is added to
the Xcode project as a folder reference, so any file added here is automatically bundled
into the test target — no project file changes needed.

Load fixtures in tests via the `Fixtures` helper:

```swift
let xml = try Fixtures.data("XML/ping_success.xml")
```

## Layout

- `XML/` — canned Subsonic API responses (captured from a real Airsonic-Advanced 1.15.0
  server), named `<action>_<variant>.xml`, e.g. `ping_success.xml`,
  `ping_error_wrong_credentials.xml`. Exceptions hand-crafted to the Subsonic API spec
  because the capture server doesn't support them: `getChatMessages.xml` (chat removed
  from Airsonic-Advanced), `jukeboxControl_get.xml`/`jukeboxControl_status.xml` (test
  account lacks the jukebox role — the real not-authorized error is
  `jukeboxControl_error_not_authorized.xml`), and `getLyrics.xml` (server returned empty
  lyrics — the real empty response is `getLyrics_empty.xml`). `malformed.xml`,
  `not_xml.txt`, and `not_xml.html` are synthetic bad-response fixtures.
- `Audio/` — small real audio files for streaming/player tests (MP3 plus at least one
  non-MP3 format to exercise BASS plugin loading)
- `LegacyDB/` — old FMDB-era SQLite databases and UserDefaults blobs for migration tests
