# Test Fixtures

Canned resources for the iSubTests unit/integration test suite. This folder is added to
the Xcode project as a folder reference, so any file added here is automatically bundled
into the test target — no project file changes needed.

Load fixtures in tests via the `Fixtures` helper:

```swift
let xml = try Fixtures.data("XML/ping_success.xml")
```

## Layout

- `XML/` — canned Subsonic API responses captured from real servers, named
  `<action>_<variant>.xml`, e.g. `ping_success.xml`, `ping_error_wrong_credentials.xml`.
  Most were captured from an Airsonic-Advanced 1.15.0 server (root element carries
  `version="1.15.0" type="Airsonic-Advanced"`). Responses Airsonic-Advanced can't
  produce were captured from a real Subsonic 1.16.1 server instead (root element
  carries `version="1.16.1"` and no `type` attribute): `getChatMessages.xml` (chat is
  removed from Airsonic-Advanced, which answers HTTP 410 with the plain-text body in
  `getChatMessages_airsonic_410.txt`), `jukeboxControl_get.xml`/
  `jukeboxControl_status.xml` (real Subsonic jukebox responses; `position` is always 0
  because a headless server can't open an audio device — the Airsonic not-authorized
  error is `jukeboxControl_error_not_authorized.xml`), and `ping_success_subsonic.xml`/
  `ping_error_incompatible_version.xml` (Airsonic rejects clients announcing a newer
  API version with error code 30; Subsonic accepts them). One exception remains
  hand-crafted to the Subsonic API spec: the populated `getLyrics.xml` — no live server
  can return lyrics anymore (Subsonic's external lyrics provider is dead), so real
  responses are always the empty `getLyrics_empty.xml`. `malformed.xml`, `not_xml.txt`,
  and `not_xml.html` are synthetic bad-response fixtures.
- `Audio/` — small real audio files for streaming/player tests: `test_song.mp3` (a 32 kbps
  transcode captured from the Airsonic test server) and `tone.flac` (a synthesized 10 s
  two-tone chord; non-MP3 to exercise BASS plugin loading). Served by
  MockSubsonicHTTPServer for stream/download requests (song id 9001 = the FLAC).
- `LegacyDB/` — old FMDB-era SQLite databases and UserDefaults blobs for migration tests
