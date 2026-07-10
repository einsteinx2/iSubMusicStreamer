# UI (XCUI) Testing

The `iSubUITests` bundle drives the iSub Beta app end-to-end. The app has a launch-argument
test mode (implemented in `Classes/Main/UITestSupport.swift`) that makes UI tests fast,
deterministic, and fully offline.

## Launch argument contract

| Argument | Effect |
| --- | --- |
| `-UITEST` | Enables test mode: routes **all** app networking (API loaders, stream handlers, jukebox) through an in-app `URLProtocol` that serves canned fixture XML from the app bundle, seeds a pre-configured server (id 1, `http://uitest.local`) so tests skip first-run setup, and suppresses the local-notification permission prompt so no system alert can block tests. |
| `-RESET_STATE` | Wipes persisted state before setup: the GRDB database, downloaded songs, temp downloads, and the app's `UserDefaults` persistent domain. Combine with `-UITEST` for a clean deterministic launch (also usable alone for first-run flows). |
| `-MODE <mode>` | `online` (default), `offline` (sets force-offline + offline mode before the UI loads), or `jukebox` (enables jukebox mode). |
| `-FIXTURES <name>` | Selects a named fixture response set. `default` maps every supported Subsonic action to the captured Airsonic responses in `Tests/iSubTests/Fixtures/XML/` (bundled into beta builds). `badauth` overrides `ping` with the wrong-credentials error for failed-auth flows. Add new sets in `UITestFixtures.fixtureSets`. |
| `-FIRSTRUN` | Skips the `-UITEST` server seeding while keeping the network stub, so the app routes through the real first-run server setup flow (`SceneDelegate.showSettings`). Used by `FirstRunUITests` (E2E-01); combine with `-FIXTURES badauth` for the failed-auth flow. |
| `-MOCKSERVER` | Instead of the in-process `URLProtocol` stub, starts an embedded GCDWebServer-backed mock Subsonic server (`Classes/Main/MockSubsonicHTTPServer.swift`) on an OS-assigned loopback port and points the seeded server at it. Requests travel over real HTTP, so streaming, byte ranges, partial downloads, and seek-past-cache-point E2E flows behave like production. `stream`/`download` serve real audio from `Fixtures/Audio/`: song id `9001` is a FLAC tone (exercises BASS plugin loading, browsable via music directory id `900`), all other ids get a small MP3. Honors `-FIXTURES` for the XML responses. |

Example:

```swift
let app = XCUIApplication()
app.launchArguments += ["-UITEST", "-RESET_STATE", "-MODE", "offline", "-FIXTURES", "default"]
app.launch()
```

## Accessibility identifiers

UI tests address elements through the constants in `Classes/Main/AccessibilityIdentifiers.swift`
(compiled into both app targets and the UI test bundle — never match on display strings).
Currently applied to: the five tab bar items, `UniversalTableViewCell`, the server-edit
fields/buttons, the player transport controls and seek slider, and the equalizer controls.
Add new identifiers to that file as tests need them.

## Running

```sh
xcodebuild test -project iSub.xcodeproj -scheme "iSub Beta" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:iSubUITests
```

The shared `iSub Beta` scheme's TestAction runs both `iSubTests` (unit/integration) and
`iSubUITests`; use `-only-testing:` to run one bundle.

## Notes

- The `-UITEST` URLProtocol stub covers API XML. Full streaming/download E2E flows use the
  embedded mock HTTP server from TEST-07 instead, which serves real audio bytes.
- Fixture XML is shared with the unit-test suite; see `Tests/iSubTests/Fixtures/README.md`
  for provenance.
