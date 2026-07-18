# CarPlay Support

iSub is a CarPlay audio app: the car gets a template-based UI over the same
Store reads and `PlaybackCoordinator` calls the phone UI uses. Everything lives
in `Classes/CarPlay/`; the phone UI is untouched.

## Architecture

- **`CarPlaySceneDelegate`** — entry point for the `CPTemplateApplicationScene`
  ("CarPlay Configuration" in the Info.plists; role routed by
  `AppDelegate.configurationForConnecting`). Kicks the idempotent
  `AppBootstrap.sceneDidConnect()` (either scene may connect first) and hands
  the interface controller to a fresh `CarPlayManager`.
- **`CarPlayManager`** — owns one connection: builds the root
  `CPTabBarTemplate` (Library / Playlists / Downloads / Discover;
  Downloads-first when offline), pairs each screen with its `CPListTemplate`,
  routes row taps to `PlaybackCoordinator`, refreshes live templates on
  playback/queue/download notifications, rebuilds on `serverSwitched` and
  offline transitions, and auto-disables jukebox mode on connect (jukebox
  renders audio on the server — the car would be silent).
- **Screens** (`CarPlayListScreen` subclasses in `CarPlay*Screens.swift`) —
  CP-free section builders: synchronous Store reads now, async loader refresh
  (`ArtistsViewModel` cache-first pattern), offline row disabling via the
  models' `isAvailableOffline`, video songs filtered out. Unit tested in
  `CarPlayScreenTests` without a car session.
- **`CarPlayItemFactory`** — maps rows to `CPListItem`s. Owns the CarPlay
  invariants: every item handler calls its completion, lists clamp to the head
  unit's runtime limits (`CPListTemplate.maximumItemCount`/`maximumSectionCount`,
  plus a "Showing first N" note row), and art is re-rendered at the car
  display's scale from the cached small (80pt) variants.
- **`CarPlayInterfaceControlling`** — protocol seam over
  `CPInterfaceController` (no public initializer) so `CarPlayManagerTests` can
  drive the manager with a recording fake.
- **Now Playing** — `CPNowPlayingTemplate.shared` with repeat/shuffle buttons
  and an Up Next queue screen. All metadata/transport/art comes from the
  existing `NowPlayingService` surfaces (`MPNowPlayingInfoCenter` +
  `MPRemoteCommandCenter`); the CarPlay layer never writes the info center.
- **`OfflineModeCoordinator`** (`Classes/Main/`) — the launch offline check and
  goOnline/goOffline transitions, extracted from `SceneDelegate` so they run
  for whichever scene appears first (a CarPlay-only launch has no phone
  window). The phone scene presents the stashed launch alert when it appears.
- **`PlayMediaIntentHandler`** — in-app SiriKit media intents ("Hey Siri, play
  <song/album/artist/playlist> in iSub"), resolved against the server search
  APIs with a local fallback offline. Declared via `INIntentsSupported` in the
  Info.plists and surfaced in the car as the Library tab's assistant cell.

## Non-goals in the car

Jukebox control (auto-disabled on connect), server chat, "now playing on
server", video (filtered from lists), EQ/visualizer, settings/server
management, download-queue management, playlist editing, bookmark creation
(playback of existing bookmarks only).

## Development / testing

- **Simulator**: run the "iSub Beta" scheme, then Simulator menu → I/O →
  External Displays → CarPlay. The CarPlay window honors the entitlements file
  without CarPlay provisioning. Remember the per-checkout dedicated simulator
  rule in CLAUDE.md.
- **Device**: the `com.apple.developer.carplay-audio` (and Siri) capabilities
  must be enabled on the App IDs in the developer portal and included in the
  provisioning profiles. Both targets reference their entitlements files via
  `CODE_SIGN_ENTITLEMENTS`.
- **Tests**: `CarPlayScreenTests`, `CarPlayManagerTests`,
  `OfflineModeCoordinatorTests`, plus the now-playing info additions in
  `NowPlayingServiceTests`. CP list/tab templates construct fine in simulator
  unit tests; only `CPInterfaceController` needs the fake.

## Gotchas

- The scene manifest sets `UIApplicationSupportsMultipleScenes = true` — with
  `false`, iOS kills the phone scene when the car connects. In-app intent
  handling also requires it.
- Audio apps get at most 4 tabs and ~5 templates of stack depth; both are
  guarded centrally in `CarPlayManager` (deep folder trees replace the top
  template instead of failing).
- `NowPlayingService` reports `MPNowPlayingInfoPropertyPlaybackRate` 0 while
  paused; without that the car's progress bar keeps advancing when paused.
