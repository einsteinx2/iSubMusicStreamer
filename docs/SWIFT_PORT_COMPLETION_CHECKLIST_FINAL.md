# iSub Swift Port — Completion Checklist (Final, Merged)

**Date:** 2026-07-09
**Sources:** Merged from the two independent audits `SWIFT_PORT_COMPLETION_CHECKLIST.md` (v1, exhaustive subsystem sweep) and `SWIFT_PORT_COMPLETION_CHECKLIST_V2.md` (v2, curated re-audit). This document supersedes both; the originals are kept for reference and per-item `_Evidence:_` file/line detail (v1 is especially rich in exact line references).
**Audited trees:** `new-swift-port` branch vs `main` branch (build 413, the shipped App Store version).

**Goal:** Feature parity with the App Store version (minus intentionally deprecated features — see the last section), plus the new features the Swift branch introduced, releasable as a direct upgrade with automatic data migration, with comprehensive unit/integration test coverage and UI (E2E) test coverage.

**How to use this document:** Each item has a checkbox, an ID, a priority, file references, and a short *Prompt* that can be pasted into a new session to do the work. Check a box only when the change is merged **with tests**.

**Ordering:** Sections are in execution order. **All test infrastructure and baseline coverage (Sections 1–3) comes first** so that a mock Subsonic backend and regression suite exist before feature/bug work begins, tests can be added alongside every subsequent change, and CI continually catches regressions.

**Priorities:**
- **P0** — Release blocker (crashes, broken/stubbed core functionality, data migration)
- **P1** — Required for parity or product quality
- **P2** — Important (robustness, secondary parity)
- **P3** — Cleanup / nice-to-have

---

## 1. Test infrastructure (do this first)

Current state: zero automated tests. No XCTest or XCUITest target exists in `iSub.xcodeproj` (only the two app targets), the shared `iSub Beta` scheme's TestAction is empty, and `Testing/` contains only the manual QA script `Integration Tests.txt` (which is the behavioral spec for most suites below). Key testability blockers: `Store.setup()` hardcodes the DB file path, `AsyncAPILoader` uses a file-private shared URLSession, `SavedSettings` hardcodes `UserDefaults.standard`, and Resolver registers concrete types.

- [x] **[TEST-01] P0 — Create unit + integration test targets and shared test infrastructure.** Add hosted XCTest bundle target(s) to `iSub.xcodeproj`, wire them into the shared scheme's TestAction (ENABLE_TESTABILITY is already on), link the SPM packages (GRDB, Resolver, CocoaLumberjack), and create the shared harness: a Fixtures folder for canned Subsonic XML/audio/legacy-DB resources, a temp-sandbox helper that redirects `FileSystem.databaseDirectory`/`downloadsDirectory` and settings paths per test, and a Resolver test-container helper that re-registers the DI singletons with fakes.
  > **Prompt:** Add an XCTest unit/integration test bundle ("iSubTests") to iSub.xcodeproj, hosted on the iSub Beta app target, wired into the shared iSub Beta scheme's TestAction (currently empty), linking GRDB/Resolver/CocoaLumberjack. Build the shared harness: a Fixtures folder structure for test resources, a temp-sandbox helper redirecting FileSystem.databaseDirectory/downloadsDirectory (Classes/Models/FileSystem.swift) to per-test temp directories with cleanup, and a Resolver test-container helper that re-registers the singletons in Classes/Models/DependencyInjection.swift with test doubles. Add one smoke test per concern and confirm `xcodebuild test` passes.

- [x] **[TEST-02] P0 — Add in-memory/temp database support to the Store layer.** `Store.swift:23-44` hardcodes a `DatabasePool` at `ApplicationSupport/iSub/database/iSub.db`.
  > **Prompt:** Refactor Store.setup() (Classes/Models/Data Store/Store.swift ~lines 23-44) to accept a configuration so tests can run against an in-memory GRDB DatabaseQueue or a temp-file DatabasePool while production keeps the current path. Keep the Resolver registration working. Prove it with a first StoreTests case that runs migrate() and asserts the schema exists.

- [ ] **[TEST-03] P0 — Add a network seam and URLProtocol-based mock Subsonic server.** `AsyncAPILoader.swift:41-49` uses a fileprivate module-global ephemeral URLSession. Every loader, StreamHandler, and Jukebox needs to run against canned responses.
  > **Prompt:** Make the network layer testable: inject the URLSession into AsyncAPILoader (Classes/Models/Async Loaders/AsyncAPILoader.swift ~lines 41-49) or register a URLProtocol-based stub into its session configuration, so all ~22 Async*Loader classes, StreamHandler, and Jukebox can be tested against canned Subsonic XML responses and stub audio bytes without network. Build a small mock-Subsonic-server helper mapping SubsonicAction → fixture response (success, `<error>` bodies, malformed XML), capture realistic fixture XML for ping/getIndexes/getMusicDirectory/getArtists/getArtist/getAlbum/getPlaylists/getNowPlaying/getChatMessages/getLyrics/search/jukeboxControl, and write a first loader test (AsyncStatusLoader ping success + Subsonic error response).

- [ ] **[TEST-04] P1 — Protocol-based dependency injection for core singletons.** `DependencyInjection.swift` registers 10 concrete singletons (Store, SavedSettings, BassPlayer, DownloadsManager, DownloadQueue, StreamManager, Jukebox, PlayQueue, Social, Analytics); nothing is protocol-abstracted, so consumers can't get fakes.
  > **Prompt:** Introduce protocol seams for the Resolver-registered singletons that tests need to fake — start with Store consumers, SavedSettings, BassPlayer (a PlayerControlling protocol), and StreamManager/DownloadQueue — updating registrations in DependencyInjection.swift and @Injected sites. Do it incrementally (one protocol per PR-sized change) so the app keeps building; the goal is unit-testing PlayQueue, ArtistsViewModel, and the download state machines with fakes.

- [ ] **[TEST-05] P1 — Make SavedSettings testable via injected UserDefaults.** `SavedSettings.swift:25` hardcodes `UserDefaults.standard`, including the `@UserDefault` property wrapper.
  > **Prompt:** Refactor SavedSettings (Classes/Models/Singletons/SavedSettings.swift) and its @UserDefault property wrapper to accept an injected UserDefaults (suiteName-based) so tests run against an isolated suite. No behavior change in production; add a first test asserting a wrapper default + persist round-trip.

- [ ] **[TEST-06] P0 — Create the XCUITest target, launch-argument test mode, and accessibility identifiers.** No UI-test target exists, no launch-argument handling anywhere, and no view sets an `accessibilityIdentifier`, so UI tests can't force a known state or address elements reliably.
  > **Prompt:** Add an XCUITest bundle target ("iSubUITests") to iSub.xcodeproj wired into the shared scheme. Add launch-argument/environment handling early in AppDelegate/SceneDelegate for: -UITEST (test mode), -RESET_STATE (wipe DB, caches, UserDefaults), -MODE online|offline|jukebox, and -FIXTURES <name> (select a recorded response set); in test mode register the TEST-03 URLProtocol stub into AsyncAPILoader's session and seed a pre-configured server so tests can skip first-run. Add a shared AccessibilityIdentifiers constants file and apply stable identifiers to: tab bar items, nav-bar buttons (edit/reload/select-all/delete/save), table views and UniversalTableViewCell (incl. swipe actions), server-edit fields, player transport controls and seek slider, and equalizer controls. Write one smoke XCUITest per mode asserting the app reaches its root UI, and document the launch-argument contract.

- [ ] **[TEST-07] P1 — Embedded mock Subsonic HTTP server for E2E streaming.** The URLProtocol stub covers API calls; full E2E playback/download flows also need real HTTP byte-serving. The repo already vendors GCDWebServer (`Frameworks/GCDWebServer`).
  > **Prompt:** Build a UI-test harness that can run the app against a local in-process mock Subsonic server: use the vendored GCDWebServer (or an embedded HTTP server in the UI-test runner) serving fixture XML plus small real audio files (include at least one non-MP3 format — FLAC/OGG/Opus — to exercise BASS plugin loading) for stream/download endpoints, selected via the -FIXTURES launch argument. This unblocks seekable/partial-download E2E scenarios that a URLProtocol stub can't model well.

- [ ] **[TEST-08] P1 — Continuous integration.** No `.github/workflows`, no fastlane, nothing. Land this as soon as TEST-01 exists so every subsequent change runs the growing suite.
  > **Prompt:** Set up GitHub Actions CI for the iSub Xcode project: a workflow on push/PR that resolves SPM packages, builds the shared scheme for iOS Simulator, and runs the unit/integration test suite (plus, once E2E exists, the UI tests as a separate/nightly job). Cache SPM/DerivedData, pin an Xcode version compatible with the project settings, fail on compile errors or test failures, and add a build-status badge to README.

---

## 2. Baseline test coverage of existing functionality

Write these suites against the code **as it behaves today** (asserting *intended* behavior where a known bug exists, so the bug fixes in Sections 4–5 flip the tests green). Every fix later in this document should land with its tests; these suites are the safety net that catches regressions while that work happens.

- [ ] **[COV-01] P1 — API model XML parsing + string-helper tests (no refactor needed).** Every API model has `init(serverId:element:)`; the `String+Clean` XML helpers back them all.
  > **Prompt:** Write unit tests for the XML helpers in Classes/Extensions/Foundation/String+Clean.swift (stringXML/intXML/boolXML/dateXML and optional variants: trimming, empty-vs-nil, defaults, malformed input) and for each API model's init(serverId:element:) — Song, TagArtist, TagAlbum, FolderArtist, FolderAlbum, MediaFolder, ChatMessage, Lyrics, NowPlayingSong, ServerPlaylist — using fixture Subsonic XML. Cover field mapping, missing-attribute defaults, special characters, video entries, and Song equality/hashing (serverId+id only). Include a regression case asserting FolderAlbum.tagAlbumName is the album title, not the artist (see BUG-20).

- [ ] **[COV-02] P1 — Pure utility & math tests (no refactor needed).** Foundation extensions, formatters, audio math, stream thresholds, error mapping.
  > **Prompt:** Add unit tests for the pure logic layer: all Classes/Extensions/Foundation string/URL extensions, the byte/time formatters in Defines.swift, Bass.bytesForSeconds/bytesToBuffer/estimateKiloBitrate, StreamHandler's threshold/throttle helpers (minimumBytesToStartPlayback, minBytesToStartLimiting, maxBytesPerInterval cell/wifi — make them internal if needed for @testable access), Song.localPath/localTempPath construction, and SubsonicError(element:)/APIError case mapping (including .trialExpired) from constructed <error> elements.

- [ ] **[COV-03] P1 — Data Store CRUD suite for all 15 store extensions.** Include regression assertions for the known SQL bugs (BUG-06…09) so the suite fails until they're fixed.
  > **Prompt:** Using the in-memory Store from TEST-02, write CRUD unit tests for every store extension in Classes/Models/Data Store: servers (nextServerId MAX+1 and empty-table cases), songs, downloads (downloadedSong + downloadQueue + path components incl. addDownloadedSongPathComponents decomposition and oldest-by-played/downloaded-date eviction queries), local playlists, server playlists, bookmarks (with snapshot playlists), cover art/artist art/lyrics blob round-trips, and the browse caches. Include multi-server isolation tests (serverId scoping), deletion cascades, ordering, and empty-result edges. Deliberately assert the intended behavior of downloadedSongs(serverId:), songsRecursive(parentPathComponent:), addToDownloadQueue(serverId:songIds:), and removeFromDownloadQueue for serverId != 1 — these currently fail (BUG-06…09) and gate those fixes.

- [ ] **[COV-04] P1 — LocalPlaylistStore queue-positioning tests.** The play/shuffle/jukebox queue tables back everything PlayQueue does.
  > **Prompt:** Add unit tests for Classes/Models/Data Store/LocalPlaylistStore.swift: contiguous positions on add, move(songAtPosition:toPosition:) forward/backward preserving relative order, remove(songsAtPositions:) closing gaps, getSongPosition, createShuffleQueue(currentPosition:) producing a permutation containing the current song, song(localPlaylistId:position:), and clearPlayQueue() only affecting the targeted playlist (fixed ids 1-4 in LocalPlaylist.swift).

- [ ] **[COV-05] P1 — PlayQueue navigation & state-persistence tests.** Index math (BUG-10), repeat modes, shuffle, save/restore.
  > **Prompt:** Write a unit-test suite for PlayQueue.swift covering index(offset:fromIndex:) across all repeat modes and boundaries (assert clamp-to-0 for .none with negative offsets — currently broken, BUG-10), nextIndex/prevIndex/nextIndexIgnoringRepeatMode, nextSong/prevSong including the 10-second restart-vs-previous rule, currentIndex get/set across the isShuffle branch, shuffleToggle queue swapping keeping the current song, moveSong index correction, removeSongs resetting the current index when the playing song is deleted, and SavedSettings saveState/loadState round-trips via a fake BassPlayer (uses TEST-04/TEST-05 seams).

- [ ] **[COV-06] P1 — URLRequest+Subsonic request-construction tests.** Version selection, auth, GET/POST, ranges, encoding — all directly affect server compatibility.
  > **Prompt:** Add unit tests for Classes/Models/Async Loaders/URLRequest+Subsonic.swift asserting for representative actions: the API version chosen per action, hls → /rest/hls.m3u8 vs others → /rest/<action>.view, enc:<hex> password wrapping, GET (ping, hls) vs POST body, Basic Auth header only when isBasicAuthEnabled, Range 'bytes=N-' when byteOffset>0, Cache-Control no-cache, per-action timeouts (getPlaylist 3600, ping 15, else 240), and createQueryString URL-encoding including multi-value array params.

- [ ] **[COV-07] P1 — Async loader integration tests (all ~22 loaders, incl. error paths).**
  > **Prompt:** Using the TEST-03 mock, add integration tests for every AsyncAPILoader subclass under Classes/Models/Async Loaders/ against a real in-memory GRDB Store: assert both the returned struct and the persisted rows/TableSections/metadata (e.g. AsyncRootFoldersLoader creates folderArtist rows and skips '.AppleDouble'). For each loader add negative cases: <subsonic-response><error> throws SubsonicError, non-XML bytes throw APIError.responseNotXML, missing element/attribute throws the matching APIError, and Task cancellation throws before writing. Include AsyncSearchLoader paging and AsyncRecursiveSongLoader/AsyncSongsHelper recursion producing the right song IDs.

- [ ] **[COV-08] P1 — Download/stream state-machine tests.** DownloadQueue, StreamManager, StreamHandler — this is where most self-flagged "logic is wrong" TODOs live.
  > **Prompt:** Write integration tests for the caching state machine using a temp Store, fake wifi flag, and controllable network (TEST-03): DownloadQueue start/stop/removeCurrentSong/clear, offline and wifi/manual-cellular gating, low-space halt, and handler stealing from StreamManager; StreamManager queueStream/fillStreamQueue (respecting isSongCachingEnabled/isNextSongCacheEnabled, skipping videos/cached/queued songs, no-op in jukebox/offline), removeAllStreams(except:), connectionFinished (mark finished, zero-byte and trial-expired-XML bodies delete the file and don't mark cached), connectionFailed retry cap, and saveHandlerStack/loadHandlerStack JSON round-trip (Codable fields: song, byteOffset, secondsOffset, isTempCache, numberOfReconnects, isDelegateNotifiedToStartPlayback); StreamHandler byte-threshold transitions (start-playback notification, content-length failure, resume with byte offset). Assert stop() actually cancels an in-flight download — currently broken (BUG-05).

- [ ] **[COV-09] P1 — SavedSettings behavior tests.** Bitrate mapping, wrapper semantics, per-server keys, state derivation.
  > **Prompt:** Using the injected UserDefaults from TEST-05, test SavedSettings: currentMaxBitrate for maxBitrateWifi/3G values 0-6 (0 for out-of-range), currentVideoBitrates arrays, @UserDefault default/persist behavior, currentServer didSet clearing currentServerRedirectUrlString and writing currentServerId, rootFoldersSelectedFolderId/rootArtistsSelectedFolderId keyed per server, and isRecover derivation. Include a test that createDirectoryIfNotExists(path:) creates a missing directory — the current guard is inverted (BUG-26) so this fails until fixed.

- [ ] **[COV-10] P2 — GRDB Codable persistence round-trips.** A schema/Codable mismatch silently loses persisted state.
  > **Prompt:** For every GRDB record in Classes/Models/DB Models/ and persistable API models (DownloadedSong, Downloaded* hierarchy, Bookmark, LocalPlaylist, ServerPlaylist, CoverArt, ArtistArt, FolderMetadata, RootListMetadata, TableSection, Song), insert into a temp database, fetch back, and assert equality so any Codable/column mismatch is caught.

- [ ] **[COV-11] P2 — Audio-engine integration tests against real BASS.** Drive Bass/BassPlayer/BassEqualizer with bundled fixture audio.
  > **Prompt:** Add integration tests driving the real BASS boundary with short bundled audio files: startSong/startNewSong creating a stream, progress advancing, playPause/stop, seekToPosition(bytes:/seconds:), prepareNextStream + gapless transition via songEnded, and BassEqualizer applyEqualizerValues/deactivateEqualizer plus BassEffectDAO.selectPreset applying expected EQ points. Assert observable state, not audio output. Include one non-MP3 format to exercise plugin loading, and audio-session interruption/route-change handling (construct AVAudioSession notifications with the relevant userInfo keys and assert isPlaying/shouldResumeFromInterruption transitions).

- [ ] **[COV-12] P2 — Singleton/lifecycle integration tests.** Jukebox parsing, online/offline transitions, ServerChecker.
  > **Prompt:** Add integration tests for: Jukebox — feed canned jukeboxControl XML through the mock and assert current index, gain, playing state, and the jukebox local playlist update, plus an <error> body surfacing as an error; the online/offline transition chain NetworkMonitor → SceneDelegate.enterOfflineMode/enterOnlineMode → ServerChecker.checkServer; and the server lifecycle (add allocates nextServerId + sets currentServer + persists isVideoSupported/isNewSearchSupported from the status loader; select re-verifies; delete removes the row — extend for cascade once STUB-08 lands).

- [ ] **[COV-13] P2 — View-controller logic unit tests (batch).** Pure-ish logic currently buried in VCs.
  > **Prompt:** Add unit tests (extracting logic from the VCs where necessary, without behavior change) for: search/quick-albums pagination in SearchSongsViewController and HomeAlbumViewController (isMoreResults seeding, offset stepping, count+1 loading row, flip-to-false on empty page); ArtistsViewModel (folders-vs-tags branching, isCached, section/index mapping, mediaFolderIndex fallback, incremental search with searchLimit); Play Queue edit-mode logic (reorder normal+shuffle, delete single/multiple/currently-playing, 1-based numbering); EqualizerPointView frequency/gain ↔ position round-trips and EqualizerView visualizer-type cycling with persistence; BassEffectDAO preset select/save/delete/temp-custom flows; and ServerEditViewController.checkURL/checkUsername/checkPassword plus OptionsViewController cache-size slider math and quickSkip seconds↔segment mapping.

---

## 3. UI / E2E baseline coverage

The manual QA script `Testing/Integration Tests.txt` (Online / Offline / Jukebox sections) is the behavioral spec, adapted to the new 5-tab layout (Home / Library / Player / Playlists / Downloads). All suites use the TEST-06 harness and TEST-07 mock server; several will (correctly) fail against today's stubs — they define done for Sections 4–5.

- [ ] **[E2E-01] P1 — Launch + first-run server setup.**
  > **Prompt:** Write XCUITests for first run: launch with -RESET_STATE, assert routing to server setup (SceneDelegate.showSettings), drive ServerEditViewController fields, assert a valid credential (stubbed ping success) lands on the main tab bar, and add a regression test that a failed auth persists NO server entry (BUG-17). Keep fully offline/deterministic.

- [ ] **[E2E-02] P1 — Online-mode regression suite (per tab).**
  > **Prompt:** Implement the online-mode XCUITest suite from Testing/Integration Tests.txt adapted to the new tabs, one test class per area: Home (quick albums + load-more, server shuffle all/specific folder, search all + per-section + paging + result playback, chat post/reload, now playing tap-to-play/swipe-to-queue, jukebox toggle UI state); Library (media-folder dropdown, folders/artists drill-down, play-all/shuffle at artist and album level, swipe-to-queue/cache, bookmarks open/play/delete); Player (transport, ±30 skip, seek incl. past cache point, repeat cycling, shuffle toggle refreshing the queue view, bookmark creation, page control paging, EQ open/toggle/preset switch/point drag-save-delete, landscape, lock-screen remote commands); Playlists (queue edit/reorder incl. shuffle mode/delete single-multiple-currently-playing/select-all, save local + overwrite, save to server, local playlist open/play/delete, server playlist open/delete, bookmarks clear-all); Downloads (browse all sub-tabs, play cached content, queue management incl. deleting the active download, deletion flows); Settings (toggle each option + persistence across relaunch, servers add/edit/delete/switch/reorder); plus tab navigation and every player-open affordance.

- [ ] **[E2E-03] P1 — Offline-mode suite.**
  > **Prompt:** Implement offline-mode XCUITests: seed downloaded songs via the mock server, then force offline (-MODE offline / kill the mock), and verify per the OFFLINE MODE spec: tab behavior, browsing/playing downloads at every level, offline playlists (current/local edit/reorder/save), offline bookmarks, player, reachability transitions online↔offline (indicator banner, controls disabling), and that settings/server-list remain reachable offline.

- [ ] **[E2E-04] P2 — Jukebox-mode suite.**
  > **Prompt:** Implement JUKEBOX MODE XCUITests: launch with jukebox enabled and a stub recording jukebox control calls; assert the jukebox UI styling, that Home server-shuffle and play-from-search issue jukebox control requests instead of local streams, Folders queue/play-all/shuffle produce the right calls, and playlists queue correctly under jukebox mode.

- [ ] **[E2E-05] P3 — iPad split-view / menu suite.**
  > **Prompt:** Add an iPad-destination XCUITest suite for PadRootViewController/PadMenuViewController: selecting each menu item swaps the detail controller, drill-down and the custom back button work, offline mode shows correct content, and the player opens. Wire into the test scheme on an iPad simulator destination.

- [ ] **[E2E-06] P3 — Video (HLS) playback coverage.**
  > **Prompt:** Add coverage for the video path: integration tests for HLSReverseProxyServer URL/origin rewriting and VideoPlayer bitrate/audio-session setup against a stubbed HLS endpoint, plus an XCUITest that tapping an isVideo song presents the video player and that video rows are excluded from swipe-to-cache/queue.

*(The upgrade-migration E2E test lives with the migration work: see MIG-12.)*

---

## 4. Critical & correctness bugs

Verified defects. The P0s are crash- or core-functionality-level; fix order within the section is roughly the listed order. Each fix must land with tests (most already have a failing test defined in Section 2).

### Crashes & data-integrity (P0)

- [ ] **[BUG-01] P0 — RepeatMode enum written raw to UserDefaults crashes the app.** `SavedSettings.swift:336` — `saveState()` calls `defaults.set(state.repeatMode, ...)` with a Swift enum (not a plist type), raising `NSInvalidArgumentException`. saveState runs on a 3.3 s timer and on backgrounding, so toggling repeat one/all crashes within seconds. `loadState` already reads it as an integer.
  > **Prompt:** In Classes/Models/Singletons/SavedSettings.swift saveState() (~line 336), persist state.repeatMode.rawValue instead of the enum (loadState at ~289 already reads defaults.integer). Audit the file for any other non-plist UserDefaults writes. Add a unit test that sets each RepeatMode, runs saveState, and round-trips through loadState without throwing.

- [ ] **[BUG-02] P0 — Buffering/underrun handling is a no-op — streaming songs can run dry.** `BassPlayer.swift:533` — `pauseIfUnderrun(bassStream:)` immediately returns; the old `keepRingBufferFilledInternal` (BassGaplessPlayer.m) paused output and waited when playback outran the download. `BassStream` already carries the dormant `isWaiting`/`shouldBreakWaitLoop`/`shouldBreakWaitLoopForever` fields and `bassGetOutputData` already calls it on short reads.
  > **Prompt:** In BassPlayer.swift, implement pauseIfUnderrun(bassStream:) (~line 533, currently a stub with the Obj-C version commented out): when the current song isn't fully cached, compute the needed size via Bass.bytesToBuffer(kiloBitrate:bytesPerSec:) with the StreamHandler's recent download speed, then wait (checking ~1×/sec, honoring shouldBreakWaitLoop/shouldBreakWaitLoopForever, breakable on seek/stop/song-change) until enough data arrives, the song fully caches, or it's the last temp-cached song; in offline mode call moveToNextSong(). Reference keepRingBufferFilledInternal in main-branch BassGaplessPlayer.m. Run off the audio callback thread. Add unit tests for the threshold math and an integration test streaming a partially-available file that pauses then resumes.

- [ ] **[BUG-03] P0 — Playback starts after ~60 s of buffer instead of ~10 s.** `StreamHandler.swift:315` — the start-playback gate uses `minBytesToStartLimiting` (60 s of audio); the intended `minimumBytesToStartPlayback` (~10 s) and adaptive `minBytesToStartPlayback(kiloBitrate:bytesPerSec:)` helpers (lines ~424/460) are defined but unused. ~6× longer time-to-first-audio.
  > **Prompt:** In StreamHandler.swift (~line 315), change the start-playback gate from minBytesToStartLimiting (60 s) to the ~10 s minimumBytesToStartPlayback / adaptive minBytesToStartPlayback(kiloBitrate:bytesPerSec:), matching the old ISMSMinBytesToStartPlayback behavior; keep the 60 s value only for throttling. Add unit tests covering both thresholds.

- [ ] **[BUG-04] P0 — Download bandwidth throttling is never applied.** `StreamHandler.swift:431-456` — the throttle helpers exist but nothing calls them; `urlSession(_:dataTask:didReceive:)` only updates a `throttlingDate` that is never used. Background caching competes with the playing stream and cellular limits.
  > **Prompt:** In StreamHandler.swift, port the throttling from main-branch ISMSNSURLSessionStreamHandler.m into urlSession(_:dataTask:didReceive:): after the start-limiting threshold, track bytes per ISMSThrottleTimeInterval and delay reads when over maxBytesPerInterval for the current network type (SceneDelegate wifi flag), gated like the old isEnableRateLimiting behavior (decide whether to throttle only while a song plays, as the old app did). Runs on the background delegate queue. Add tests for the interval math and a capped-throughput integration test.

- [ ] **[BUG-05] P0 — `DownloadQueue.stop()` has an inverted guard — can't stop an active download.** `DownloadQueue.swift:121` — `guard !isDownloading else { return }` returns exactly when a download IS in progress. `removeCurrentSong()`, `clear()`, and offline-mode entry all fail to cancel the in-flight handler.
  > **Prompt:** In DownloadQueue.swift stop() (~line 121), fix the inverted guard to return early only when NOT downloading (old ISMSCacheQueueManager.stopDownloadQueue semantics), verify removeCurrentSong()/clear()/didEnterOfflineMode() now genuinely cancel the active stream handler, and add a test that starts a download, calls stop(), and asserts cancellation and isDownloading == false.

- [ ] **[BUG-06] P0 — Malformed batch download-queue insert SQL — multi-song Download actions silently fail.** `DownloadsStore.swift:~831` — `addToDownloadQueue(serverId:songIds:)` builds `VALUES (\(serverId), \(songId)` with a missing closing paren and omits the NOT NULL `queuedDate` column; every call throws. Used by AsyncRecursiveSongLoader and AsyncSongsHelper.
  > **Prompt:** In DownloadsStore.swift addToDownloadQueue(serverId:songIds:) (~line 831), fix the SQL to insert (serverId, songId, queuedDate) with balanced parentheses and a Date() value, mirroring the working single-song variant, and post downloadQueueSongAdded. Add a unit test enqueuing several songIds and asserting downloadQueueCount increases.

- [ ] **[BUG-07] P0 — Download-queue delete SQL only matches serverId == 1.** `DownloadsStore.swift:~864` — `removeFromDownloadQueue` builds `WHERE serverId = (\(serverId) AND songId = \(songId))`; the parens make the RHS a boolean, so deletes silently no-op for any other server. Backs every queue-delete path in DownloadQueueViewController.
  > **Prompt:** In DownloadsStore.swift removeFromDownloadQueue(serverId:songId:) (~line 864), fix the WHERE clause to `WHERE serverId = \(serverId) AND songId = \(songId)`. Add a unit test with a serverId != 1 asserting the correct row is removed and others remain.

- [ ] **[BUG-08] P0 — `downloadedSongs(serverId:)` ignores its serverId — cross-server data bleed.** `DownloadsStore.swift:~534` — the SQL has no WHERE clause; with multiple servers the Downloads songs list shows merged/wrong data.
  > **Prompt:** In DownloadsStore.swift downloadedSongs(serverId:) (~line 534), add `WHERE serverId = \(serverId)` (keeping the ORDER BY downloadedDate DESC). Add a unit test inserting DownloadedSong rows for two serverIds and asserting only the requested server's rows return.

- [ ] **[BUG-09] P0 — `songsRecursive` never uses `parentPathComponent` — folder actions operate on the whole library.** `DownloadsStore.swift:~353` — only filters serverId and `level >= level`, so "Download/Queue/Play/Shuffle folder" on any offline folder hits the entire server's downloads.
  > **Prompt:** In DownloadsStore.swift songsRecursive(serverId:level:parentPathComponent:) (~line 353), rewrite the query to restrict to songs under the given parentPathComponent at the appropriate level via DownloadedSongPathComponent, matching the callers in DownloadedFolderArtist/DownloadedFolderAlbum. Add unit tests over a small folder tree asserting a subfolder recursion excludes siblings.

### Playback & UI correctness (P1)

- [ ] **[BUG-10] P1 — `PlayQueue.index(offset:fromIndex:)` returns negative indices.** `PlayQueue.swift:180-188` — marked TODO; the `.none` repeat case returns the negative value where the comment says clamp to 0. Feeds prev-song navigation and StreamManager prefetch.
  > **Prompt:** In PlayQueue.swift index(offset:fromIndex:) (~line 180), fix the logic for all three repeat modes to match the Obj-C indexForOffset:fromIndex: (clamp to 0 for .none negatives, preserve first-index-past-the-end for prefetch), verify prevSong/nextSong at boundaries, and enable the COV-05 tests.

- [ ] **[BUG-11] P1 — Inverted bounds guard in `BassEqualizer.removeEqualizerValue` — deleting an EQ band is a no-op (or crash).** `BassEqualizer.swift:148` — `guard value.arrayIndex >= eqValues.count else { return }` returns for every valid index and proceeds (to an out-of-bounds `remove(at:)`) only for invalid ones.
  > **Prompt:** In BassEqualizer.swift removeEqualizerValue(value:) (~line 148), fix the inverted guard, remove the value and its FX handle (BASS_ChannelRemoveFX when active), and re-sequence remaining arrayIndex values under the lock, per the Obj-C BassEqualizer.m. Add a unit test adding several values, removing a middle one, and asserting count/ordering with no crash.

- [ ] **[BUG-12] P1 — Landscape visualizer swipe gestures target the class, not the instance.** `EqualizerViewController.swift:43-44` — recognizers are created with `target: EqualizerViewController.self`, so fullscreen-landscape swipes to change visualizer type never fire.
  > **Prompt:** In EqualizerViewController.swift, recreate swipeDetectorLeft/swipeDetectorRight with target: self (e.g. in viewDidLoad) so left/right swipes call equalizerView?.nextType()/prevType() in fullscreen landscape. Add a UI test rotating to landscape and asserting swipes cycle the visualizer.

- [ ] **[BUG-13] P1 — Debug leftover auto-prompts "save preset" every time the EQ opens.** `EqualizerViewController.swift:241-243` — `viewDidAppear` unconditionally schedules `promptToSaveCustomPreset()` after 2 s; no counterpart in the shipping app.
  > **Prompt:** In EqualizerViewController.swift viewDidAppear, remove the asyncAfter block that unconditionally calls promptToSaveCustomPreset() 2 s after appearing (debug leftover; the Obj-C original only shows the one-time instructions alert). Add a UI test asserting no save dialog appears on opening the EQ.

- [ ] **[BUG-14] P1 — `PlayQueue.shuffleToggle()` drops the notification and Jukebox handling.** `PlayQueue.swift:233` — never posts `currentPlaylistShuffleToggled` (observed by PlayQueueViewController and PlayerViewController, so they don't refresh), doesn't drive the Jukebox queue, and doesn't update MPRemoteCommandCenter shuffle state.
  > **Prompt:** In PlayQueue.swift shuffleToggle(), match the Obj-C PlaylistSingleton.shuffleToggle: post Notifications.currentPlaylistShuffleToggled on both enable and disable branches, in Jukebox mode call jukebox.replacePlaylistWithLocal() + jukebox.playSong(index:), and update MPRemoteCommandCenter.changeShuffleModeCommand. Add unit tests for both transitions in normal and Jukebox modes.

- [ ] **[BUG-15] P1 — HTTP 5xx during streaming may not propagate as a failure.** `StreamHandler.swift:283` — the 5xx branch cancels the task but the `didFailWithError` call is commented out with a TODO; a 500 may be treated as a silent normal completion.
  > **Prompt:** In StreamHandler.swift (~line 283), re-enable failure propagation for HTTP error status codes: verify whether didCompleteWithError fires after the cancel, and if not, explicitly route 5xx to connectionFailed (compare ISMSNSURLSessionStreamHandler.m). Add a test with a stubbed 500 asserting the failure delegate path.

- [ ] **[BUG-16] P1 — Cache eviction can loop forever, and runs on the main thread.** `DownloadsManager.swift:132` — `removeOldestCachedSongs` has no break when nothing more can be deleted; `checkCache`/`findCacheSize` (full recursive FS walk) run on the main queue every 60 s.
  > **Prompt:** In DownloadsManager.swift, add a termination condition to removeOldestCachedSongs (~line 132) when no more songs can be deleted, and move the periodic cache-scan/eviction work off the main thread per the class-level TODO (marshal back only for alerts/notifications). Consider deriving size from stored per-song sizes like the old CacheSingleton. Add unit tests for eviction ordering (both caching types and autoDelete types) and loop termination.

- [ ] **[BUG-17] P1 — Wrong password on first server add leaves a phantom/duplicate entry.** `ServerEditViewController.swift:13` — file-header bug note; the code only calls `store.add` on success, so the extra entry comes from somewhere latent (legacy `servers` UserDefaults key, seed row, or nextServerId logic).
  > **Prompt:** Investigate and fix the bug documented at the top of ServerEditViewController.swift: after an incorrect password on first-ever server add, a server entry is still persisted (two entries after correcting). checkServer() only calls store.add on success — check the legacy UserDefaults "servers" key handling, any seeded default server, and ServerStore.nextServerId. Only persist after a successful status check (or update the existing row on retry). Add the E2E-01 regression test.

- [ ] **[BUG-18] P1 — GRDB reentrancy: nested pool access inside write transactions.** `BookmarkStore.addBookmark` calls `nextLocalPlaylistId`/`nextBookmarkId` (each opens `pool.read`) inside `pool.write`; `DownloadsStore.deleteDownloadedSongs(serverId:level:/downloadedTagArtist:/downloadedTagAlbum:)` call `self.song(...)` inside their writes. DatabasePool access is not reentrant — deadlock/throw risk.
  > **Prompt:** Fix GRDB reentrancy in BookmarkStore.swift (~line 68) and DownloadsStore.swift (~lines 641/673/695): refactor the nested lookups into helpers that take the in-transaction `db` handle (MAX(id) computation, Song fetch) so no pool.read/write nests inside pool.write. Add tests exercising addBookmark and each delete path.

- [ ] **[BUG-19] P1 — Wrong column affinities for text songId/path columns.** `DownloadedSong.path`, `DownloadedSongPathComponent.songId`, `serverPlaylistSong.songId`, and `tagSongList.songId` are declared `.integer` but hold text; non-numeric Subsonic IDs risk lossy coercion and broken joins against the text `song.id`.
  > **Prompt:** Change the mistyped columns to .text: DownloadedSong.path (DownloadsStore.swift ~29), DownloadedSongPathComponent.songId (~108), serverPlaylistSong.songId (ServerPlaylistStore.swift ~47), tagSongList.songId (TagAlbumStore.swift ~325). Coordinate with the migration work since this alters the initial schema. Add a test inserting a song with a non-numeric id and asserting join-based fetches return it.

- [ ] **[BUG-20] P2 — `FolderAlbum.tagAlbumName` parses the artist attribute.** `FolderAlbum.swift:35` — copy-paste of the `tagArtistName` line above; any consumer gets the artist string.
  > **Prompt:** In FolderAlbum.swift (~line 35), fix tagAlbumName to read the album's own name attribute (title) instead of artist, or remove the field if unused. Covered by the COV-01 regression case.

- [ ] **[BUG-21] P2 — Artists sub-tab reads/writes the Folders tab's media-folder setting.** `ArtistsViewController.swift` serves both sub-tabs but hardcodes `rootFoldersSelectedFolderId` in refresh (~67), viewWillAppear (~84), reloadAction (~193), and the dropdown save (~479); the tabs cross-contaminate.
  > **Prompt:** In ArtistsViewController.swift, introduce a computed accessor that picks rootFoldersSelectedFolderId vs rootArtistsSelectedFolderId based on dataModel.type (.folders vs .tags) and use it at every read/write site (lines ~67/84/193/479), resolving the class TODO. Add a test that the two tabs persist media-folder selection independently.

- [ ] **[BUG-22] P2 — `DownloadQueueViewController.viewWillAppear` never calls super.** The base `AbstractDownloadsViewController.viewWillAppear` performs `registerForNotifications()` and `reloadTable()`, so the queue tab doesn't refresh on appear.
  > **Prompt:** In DownloadQueueViewController.swift viewWillAppear (~line 31), call super.viewWillAppear(animated), and add a matching viewWillDisappear (calling super) that removes the two extra observers to avoid duplicate registration. Verify the queue tab reloads and shows its edit header on appear.

- [ ] **[BUG-23] P2 — Lock-screen next/prev report `.commandFailed` on success; jukebox seek ignored.** `LockScreenAudioControls.swift` — nextTrack/previousTrack handlers return `.commandFailed` after succeeding; changePlaybackPositionCommand only drives the local player, so lock-screen scrubbing in Jukebox mode does nothing.
  > **Prompt:** In LockScreenAudioControls.swift, return .success from the next/previous handlers after calling playQueue.playNextSong()/playPrevSong(), and make changePlaybackPositionCommand call jukebox.seek(seconds:) when isJukeboxEnabled instead of only player.seekToPosition. Add handler tests for normal and Jukebox modes.

- [ ] **[BUG-24] P2 — Force-offline / cellular-disabled settings ignored at launch.** `SceneDelegate.sceneDidBecomeActive` only checks reachability; the old app also entered offline mode for `isForceOfflineMode` and cellular+`isDisableUsageOver3G`, with explanatory alerts.
  > **Prompt:** In SceneDelegate.swift, reproduce the Obj-C launch behavior (iSubAppDelegate.m): enter offline mode at launch when isForceOfflineMode is on, no network, or cellular with isDisableUsageOver3G, presenting the matching alert when isPopupsEnabled, and only call serverChecker.checkServer() otherwise. Add integration tests per condition.

- [ ] **[BUG-25] P2 — Stream-queue maintenance logic is wrong/duplicated.** `StreamManager.currentPlaylistIndexChanged` is marked "Fix this logic, it's wrong"; `removeStreamWithoutSavingStack` (~line 139) has a self-contradictory guard making its delete branch dead; retry scheduling uses a single shared `resumeHandlerWorkItem` so overlapping retries can cancel the wrong handler; `streamHandlerConnectionFinished` is copy-pasted between StreamManager and DownloadQueue.
  > **Prompt:** In StreamManager.swift and DownloadQueue.swift, using main-branch ISMSStreamManager.m/ISMSCacheQueueManager.m as reference: fix currentPlaylistIndexChanged (~line 351) to correctly remove stale handlers and refill the stream queue on index change; fix the contradictory guard in removeStreamWithoutSavingStack (~139); make reconnect-retry scheduling per-handler so cancelResume(handler:) targets the right one; and extract the duplicated streamHandlerConnectionFinished/Failed logic into a shared helper. Extend the COV-08 tests to cover each.

- [ ] **[BUG-26] P2 — `createDirectoryIfNotExists` guard is inverted.** `SavedSettings.swift:~571` — only enters the create branch when the path already exists.
  > **Prompt:** Fix the inverted guard in SavedSettings.createDirectoryIfNotExists(path:) so a missing directory is actually created, and enable the COV-09 test for it.

- [ ] **[BUG-27] P2 — Force-unwrap crash risks in the EQ view.** `EqualizerView.swift:151` (TODO'd), plus `nextType()`/`prevType()` force-unwrap `VisualizerType(rawValue:)` — a bad persisted `currentVisualizerType` crashes.
  > **Prompt:** In EqualizerView.swift, remove the VisualizerType force unwraps in setup()/nextType()/prevType(), falling back to .none for out-of-range persisted values and normalizing wraparound. Add a unit test cycling past boundaries.

- [ ] **[BUG-28] P3 — Media-folder dropdown off-by-one blank row.** `ArtistsViewController.dropdownMenuNumberOfItems` returns `count + 1` but title/selection handlers no-op for the extra index (the "All Media Folders" entry is already prepended by the loader).
  > **Prompt:** In ArtistsViewController.swift (~lines 465-479), determine whether the +1 in dropdownMenuNumberOfItems produces a stray blank row (AsyncMediaFoldersLoader already prepends the All Media Folders entry); fix the count or implement the extra slot. Add a test asserting item count equals selectable folders.

- [ ] **[BUG-29] P3 — Download Status page shows minFreeSpace for "Max Download Space".** `DownloadStatusViewController.startUpdatingStats` sets the same `minFreeSpace` value in both cachingType branches.
  > **Prompt:** In DownloadStatusViewController.swift startUpdatingStats, make the maxSpace branch display the configured max download size instead of settings.minFreeSpace. Add a unit test per cachingType asserting the title/value pairing.

- [ ] **[BUG-30] P3 — Spurious error alert on cancelled quick-albums load-more.** `HomeAlbumViewController.loadMoreResults` catch lacks the `!error.isCanceled` guard its siblings have.
  > **Prompt:** In HomeAlbumViewController.swift loadMoreResults, add !error.isCanceled to the alert guard, matching SearchSongsViewController/NowPlayingViewController. Add a test that a cancelled load presents no alert.

---

## 5. Stubbed / unimplemented user-facing features (P0/P1)

Functions that exist but do nothing — a user hitting these today gets silent no-ops.

- [ ] **[STUB-01] P0 — Saving a playlist to the server is not implemented anywhere.** `createPlaylist` is missing from the `SubsonicAction` enum; all three call sites are stubs: `PlayQueueViewController.uploadPlaylist` (~217), `LocalPlaylistViewController.uploadPlaylist` (~51), `LocalPlaylistsViewController` (~87/~179 incl. the exists→overwrite check and cancel support).
  > **Prompt:** Implement server playlist upload end-to-end: add createPlaylist (and updatePlaylist if appropriate) to SubsonicAction in URLRequest+Subsonic.swift, create an AsyncServerPlaylistCreateLoader following the existing loader pattern (POST name + ordered songId array, validate response), and wire the three stubbed call sites — Play Queue save (honoring isShuffle and jukebox mode), local playlist save-to-server, and LocalPlaylistsViewController incl. the overwrite-confirmation flow and cancelLoad. Reference main-branch CurrentPlaylistViewController.m/PlaylistsViewController.m. Refresh server playlists on success, alert on error, and add loader request/parse tests plus the E2E-02 flows.

- [ ] **[STUB-02] P0 — Deleting server playlists does nothing.** `ServerPlaylistsViewController.deleteServerPlaylists` (~102) is empty; `deletePlaylist` is not in `SubsonicAction`. Handles both swipe-delete and the edit-header delete.
  > **Prompt:** Implement server playlist deletion: add deletePlaylist to SubsonicAction, add an async loader sending `id`, and implement deleteServerPlaylists(indexPaths:) in ServerPlaylistsViewController.swift (~102): call the loader per selection, remove Store rows on success, HUD + error alerts, and make saveEditHeaderSaveDeleteAction select-all when nothing is selected (mirror PlayQueueViewController). Old reference: PlaylistsViewController.m:751. Add loader tests and the E2E swipe/multi/select-all cases.

- [ ] **[STUB-03] P0 — Deleting local playlists does nothing.** `LocalPlaylistsViewController.deleteLocalPlaylists` (~142) is an empty stub used by both swipe-delete and the edit header; select-all-then-delete is also missing.
  > **Prompt:** Implement deleteLocalPlaylists(indexPaths:) in LocalPlaylistsViewController.swift (~142): delete via LocalPlaylistStore (localPlaylist + localPlaylistSong cascade), update the table/array/header, and fix saveEditHeaderSaveDeleteAction to select-all when nothing is selected. Add a Store-level cascade test.

- [ ] **[STUB-04] P0 — Tapping a song in a local playlist doesn't play it.** `LocalPlaylistViewController.didSelectRowAt` (~135) only toggles the HUD.
  > **Prompt:** Implement didSelectRowAt in LocalPlaylistViewController.swift (~135) mirroring the working ServerPlaylistViewController: call LocalPlaylistStore.playSong(position:localPlaylistId:) on a background queue, post showPlayer for non-video songs, handle offline mode. Add an integration test for the store path and a UI test that tapping plays.

- [ ] **[STUB-05] P0 — Bookmark batch delete (edit mode) does nothing.** `BookmarksViewController.saveEditHeaderSaveDeleteAction` (~98) is fully commented out (and references the wrong method); only single swipe-delete works.
  > **Prompt:** Implement saveEditHeaderSaveDeleteAction in BookmarksViewController.swift (~98): delete selected bookmarks via BookmarkStore (incl. snapshot localPlaylist rows), select-all when none selected (clear-all flow), refresh table/header. Reference main-branch Bookmarks/BookmarksViewController.m. Add store deletion tests and the E2E clear-all case.

- [ ] **[STUB-06] P0 — iCloud/iTunes backup exclusion for downloads is a no-op.** `DownloadsManager.swift:204-214` — both setAllCachedSongsTo(Not)Backup bodies are commented out, so the `isBackupCacheEnabled` toggle is inert; StreamHandler also never sets the flag on new files.
  > **Prompt:** Implement setAllCachedSongsToBackup()/setAllCachedSongsToNotBackup() in DownloadsManager.swift (~204-214): enumerate FileSystem.downloadsDirectory on a background queue setting URLResourceValues.isExcludedFromBackup per file (the flag doesn't propagate — set it per file), verify the isBackupCacheEnabled didSet triggers them, and also set the attribute on newly-completed downloads in StreamHandler.start(). Add a unit test toggling the setting and asserting per-file values.

- [ ] **[STUB-07] P1 — No user alert when downloads stop for low disk space.** `DownloadQueue.swift:55-58` — silent return at ≤25 MB free; the old showNoFreeSpaceMessage UI is commented out.
  > **Prompt:** In DownloadQueue.swift (~55-58), present a user-facing alert/banner (main thread, once per queue-start attempt) when the download queue halts for insufficient space, matching the old ISMSCacheQueueManager messaging. Add a test stubbing low freeSpace.

- [ ] **[STUB-08] P1 — Deleting a server leaves all its data; switching servers is unverified.** `ServersViewController.swift:243-244` TODOs (delete all server resources; switch/show-add after deleting current), `ServerStore.deleteServer` only deletes the row, and `switchServer()` (~105) is flagged "make sure it actually works".
  > **Prompt:** Implement cascading server deletion: remove all serverId-scoped rows across every table via the Store, delete downloaded files under Downloads/<server.path> and cover art, and when the deleted server was current, auto-select another server or present add-server. Separately verify/fix switchServer() (~105): cancel streams, stop the player, clear queues, exit offline mode, reset tab stacks, post serverSwitched (compare main-branch ServerListViewController.m switchServer:). Add integration tests for cascade-delete and switch on iPhone and iPad.

- [ ] **[STUB-09] P1 — Jukebox mode (and shuffle) not honored when playing from local playlists.** `LocalPlaylistStore.swift:102` and `:538` TODOs.
  > **Prompt:** In LocalPlaylistStore.swift (~102, ~538), implement the jukebox paths (replace/add + start via the Jukebox singleton, matching PlayQueue's handling) and shuffle handling when queueing/playing from local playlists, mirroring the old PlaylistSingleton behavior. Add unit tests.

- [ ] **[STUB-10] P1 — Play Queue local save lacks the overwrite check and error handling.** `PlayQueueViewController.showSavePlaylistAlert` always creates a new playlist (never detects an existing name → no "Overwrite?" flow) and carries an error-handling TODO.
  > **Prompt:** In PlayQueueViewController.swift showSavePlaylistAlert(isLocal:) (~172-186), detect an existing local playlist with the entered name and present an Overwrite? confirmation that clears/replaces its songs (old showOverwritePlaylistAlert: in PlaylistsViewController.m), and surface store-add failures as alerts. Add unit tests for collision detection and the E2E save-then-overwrite case.

---

## 6. Automatic data migration from the App Store version (P0 — release blocker)

**Current state: 0% implemented.** `Store.swift:73-80` has the entire `migrateOldData` GRDB migration commented out, and `SavedSettings.migrate()` (`SavedSettings.swift:244-246`) is empty. A user upgrading today loses servers, downloads, playlists, bookmarks, and the play queue (files remain orphaned on disk).

**Old persistence (main branch):** FMDB SQLite files in `Documents/database/` — server-scoped files prefixed with `md5(serverUrlString)` (`<md5>currentPlaylist.db`, `<md5>localPlaylists.db`, `<md5>cacheQueue.db`, `<md5>bookmarks.db`, plus shared `songCache.db`, `lyrics.db`, `coverArtCache60/320/540.db`, offline variants). Song files at `Documents/songCache/<md5(song.path)>`, flat, no extension. Settings and the server list (NSKeyedArchived `ISMSServer` array under key `servers`) in UserDefaults. **Very old installs** may still have songCache.db/cacheQueue.db and the songCache media folder under `Library/Caches` (the Obj-C app had its own relocation logic).

**New persistence (Swift port):** Single GRDB `iSub.db`; all tables keyed by integer `serverId`; queues are `localPlaylistSong` rows under fixed playlist ids 1-4; downloads at `Documents/Downloads/<server.path>/<song.path>` with `downloadedSong` + `downloadedSongPathComponent` records; settings reuse mostly the same UserDefaults keys; keychain access group must stay `3CZTA9E3ZN.com.einsteinx2.isub` so saved passwords remain readable.

**Key dependency:** every category needs the `md5(serverUrlString) → new serverId` map produced by MIG-02, so it runs first.

- [ ] **[MIG-01] P0 — Migration framework, trigger, crash-safety, and launch execution.** Detection, ordering, transactionality, resumability, and a progress UI — the heavy work must not run synchronously at launch (watchdog risk).
  > **Prompt:** Implement the data-migration framework for upgrading from the Obj-C App Store version. In Store.swift (~73-80) the migrateOldData migration is commented out and SavedSettings.migrate() is empty (with its migrateIncrementor scheme). Design: (1) fast synchronous detection of a legacy install (Documents/database/*.db, the `servers` UserDefaults key, plus Library/Caches fallbacks for very old installs); (2) a resumable, idempotent pipeline running on a background queue behind a modal "Upgrading your library" progress screen (file moves can take minutes; synchronous launch work risks a 0x8badf00d watchdog kill); (3) DB imports inside a single GRDB write transaction so a crash rolls back, with media moves sequenced after commit and skip-if-already-moved resumability; (4) a persisted success flag so cleanup never triggers re-import, and any error aborts cleanly leaving legacy files intact for retry; (5) ordering — servers first (MIG-02). Read the old FMDB files directly via GRDB (no FMDB dependency); schemas are in main-branch DatabaseSingleton.m. Build the legacy-DB reader utilities and fixture-based tests, including a simulated mid-migration crash asserting no partial/duplicated rows and successful completion on re-run.

- [ ] **[MIG-02] P0 — Migrate servers & credentials.** Old: UserDefaults `servers` = NSKeyedArchived `ISMSServer[]` (url/username/password/type/uuid) + loose active-server keys; per-server capability flags `isVideoSupported<md5>`/`isNewSearchAPI<md5>`. New: `server` table + `currentServerId`. Produces the md5→serverId map.
  > **Prompt:** Implement legacy server migration: unarchive the `servers` UserDefaults blob (NSKeyedUnarchiver with a compatibility mapping class for ISMSServer — see main-branch ISMSServer.m/SavedSettings.m:860), insert each into the `server` table via ServerStore (path via Server.generatePathFromURL, old serverType string → ServerType), carry the per-server `isVideoSupported<md5>`/`isNewSearchAPI<md5>` flags into isVideoSupported/isNewSearchSupported, set currentServerId to the server matching the old active url+username, handle isBasicAuthEnabled, and persist the md5(urlString)→serverId map for the later steps. Verify keychain-stored passwords remain readable (access group unchanged). Gate on migrateIncrementor. Unit-test with a fixture archived blob.

- [ ] **[MIG-03] P0 — Migrate downloaded song files (the long pole).** Old: flat `Documents/songCache/<md5(song.path)>` (check `Library/Caches` fallback too). New: `Documents/Downloads/<server.path>/<song.path>`. Requires old `songCache.db` `cachedSongs` rows for real paths. `DownloadsManager.swift:30-31` carries the TODO.
  > **Prompt:** Implement relocation of downloaded songs: read old songCache.db `cachedSongs` (md5, finished, cachedDate, playedDate + full song columns per [ISMSSong standardSongColumnSchema] — DatabaseSingleton.m:274-325); for each finished row move (not copy) Documents/songCache/<md5(path)> (probing the Library/Caches legacy location too) to Documents/Downloads/<server.path>/<song.path>, creating directories, tolerating missing files, reporting progress, reapplying the backup-exclusion attribute per isBackupCacheEnabled, and recording real file size. Resumable/idempotent; discard Documents/tempCache; delete the old songCache directory only after all moves verify. Integration-test with a fixture old-layout tree, incl. odd characters in paths.

- [ ] **[MIG-04] P0 — Migrate downloaded song DB records.** For each migrated file: a `song` row, a `DownloadedSong` (isFinished, size from `sizesSongs` or the file, unix-epoch dates), and `DownloadedSongPathComponent.addDownloadedSongPathComponents` so folder browsing works.
  > **Prompt:** Populate the new download records during migration: for each old cachedSongs row, insert the song row from the embedded columns, a DownloadedSong with mapped dates/size (old sizesSongs table has sizes; skip rows whose file no longer exists), and downloadedSongPathComponent rows via addDownloadedSongPathComponents (DownloadsStore.swift:117). Decide whether tag-metadata (getArtist/getAlbum) backfill for the tag-browse views happens lazily post-migration (see PAR-03). Unit-test with fixture rows.

- [ ] **[MIG-05] P1 — Migrate the download queue.** Old: `<md5>cacheQueue.db` `cacheQueue` (FIFO by rowid). New: `downloadQueue` (serverId, songId, queuedDate).
  > **Prompt:** Migrate the legacy download queue: read each `<md5>cacheQueue.db` cacheQueue table, insert song rows + downloadQueue rows preserving FIFO order (cachedDate → queuedDate), skipping songs already fully downloaded. Unit test with a fixture DB.

- [ ] **[MIG-06] P0 — Migrate play queue / shuffle / jukebox queues + resume state.** Old: `<md5>currentPlaylist.db` tables `currentPlaylist`/`shufflePlaylist`/`jukeboxCurrentPlaylist`/`jukeboxShufflePlaylist` (+ offline variant), ordered by rowid. New: `localPlaylistSong` under fixed ids 1-4.
  > **Prompt:** Migrate the play queues: copy the four old tables to localPlaylistId 1/2/3/4 respectively as song + localPlaylistSong rows preserving order (fixed ids in LocalPlaylist.swift:13-18), including the offlineCurrentPlaylist.db variant. Verify the resume UserDefaults keys carry over (normalPlaylistIndex, shufflePlaylistIndex, seekTime, byteOffset, repeatMode, isShuffle, isJukeboxEnabled, recover) and map bitRate → kiloBitrate in SavedSettings.migrate(). Test that relaunch after migration resumes the same song at the same position.

- [ ] **[MIG-07] P1 — Migrate local playlists.** Old: `<md5>localPlaylists.db` with index table `localPlaylists(playlist, md5)` + one `playlist<md5>` table each (skip `splaylist*` server-playlist caches); offline variant exists. New: `localPlaylist` (id ≥ 5) + `localPlaylistSong`.
  > **Prompt:** Migrate user local playlists: for each localPlaylists entry create a LocalPlaylist (ids above the reserved 1-4, respecting nextLocalPlaylistId) and insert song + ordered localPlaylistSong rows from its playlist<md5> table; include offlineLocalPlaylists.db; skip splaylist* tables (refetchable). Unit-test with a two-playlist fixture asserting names/membership/order.

- [ ] **[MIG-08] P1 — Migrate bookmarks.** Old: `<md5>bookmarks.db` `bookmarks(bookmarkId, playlistIndex, name, position, <song schema>, bytes)` (+ unprefixed offline variant). New: `bookmark` + a single-song snapshot localPlaylist. The old `name` column has no destination — decide whether to extend the schema or document its loss.
  > **Prompt:** Migrate bookmarks: for each old row insert the song, a snapshot localPlaylist (isBookmark=true), and a Bookmark (position→offsetInSeconds, bytes→offsetInBytes, playlistIndex→songIndex) via BookmarkStore. Decide the fate of the old `name` column (extend the Bookmark schema or document the drop). Include the offline variant. Unit-test with fixture rows.

- [ ] **[MIG-09] P2 — Migrate lyrics; decide cover art.** Lyrics: straight column-rename copy (`lyrics(artist,title,lyrics)` → `lyrics(tagArtistName,songTitle,lyricsText)`). Cover art (`coverArtCache60/320/540.db` BLOBs → `coverArt(serverId,id,isLarge)`) re-downloads, so migrating is optional; browse caches (albumListCache, allAlbums/allSongs/genres DBs) are skipped outright.
  > **Prompt:** Migrate the lyrics cache into the new lyrics table via LyricsStore. Make an explicit keep/skip decision on cover-art migration (60/320 → isLarge=false, 540 → isLarge=true, serverId from the map) vs letting art re-download, and document it. Explicitly skip the browse caches (albumListCache.db, allAlbums/allSongs/genres DBs) — pure re-fetchable caches. Quick unit tests either way.

- [ ] **[MIG-10] P0 — Settings fix-ups + post-migration cleanup.** Most keys carry over by name; known mismatches: `bitRate`→`kiloBitrate`, `cacheSongCellColorSetting`→`downloadedSongCellColorType`, `disablePopupsSetting` is **inverted** vs `isPopupsEnabled`, per-server `<urlString>rootFoldersSelectedFolder`/`rootFoldersReloadTime` keys must be rebuilt under serverId-based names, and old-only keys (lyricsEnabled/autoPlayerInfo/enableSongsTab/isTapAndHold/isSwipe/isPartialCacheNextSong) need a home or an explicit drop. Then delete legacy files and stale path constants.
  > **Prompt:** Finish the settings migration and cleanup: (1) audit every old SavedSettings.m UserDefaults key against the new Key enum in SavedSettings.migrate(), handling the renames above, inverting disablePopupsSetting into isPopupsEnabled, rebuilding the per-server rootFolders keys under serverId-based names, and explicitly dropping the deprecated-feature keys (documenting each); bump migrateIncrementor on success. (2) Implement the final cleanup step — delete old .db files, Documents/songCache and tempCache, and the archived `servers`/loose credential keys — gated on the success flag and safe to re-run. (3) Remove or correct the stale path constants in SavedSettings.swift (~399-425: songCachePath, tempCachePath, databasePath, updatedDatabasePath). Unit-test with a seeded UserDefaults suite.

- [ ] **[MIG-11] P3 — Verify EQ preset persistence compatibility.** BassEffectDAO reads the same UserDefaults keys as the shipped app (BassEffectUserPresets/BassEffectSelectedPresetId, CGPoint-string values), but the Swift decode path (NSCoder.cgPoint) vs the Obj-C encode format needs proof; a mismatch silently drops saved presets.
  > **Prompt:** Write a test seeding UserDefaults with the exact old Obj-C BassEffectDAO format (dictionary keyed by effect type, 'values' arrays of NSStringFromCGPoint strings, unsigned selectedPresetId) and assert the Swift DAO reads presets and selection correctly; fix any decode mismatch. Then remove the now-unneeded @objc/NSObject interop flagged by the file's TODO.

- [ ] **[MIG-12] P0 — End-to-end upgrade verification.** Prove the whole path with real old-format data, automated where feasible (pairs with the E2E harness).
  > **Prompt:** Create an end-to-end upgrade test: pre-seed the app container with fixture old-format data (old DBs incl. corrupt/partial variants, md5-named song files, archived servers blob, legacy UserDefaults) via a launch-argument hook or simctl container injection, launch, wait for migration, and assert every category lands correctly (UI checks + direct iSub.db queries). Cover: huge cache, missing files, corrupted old DB, interrupted (killed) migration resuming, and idempotent re-run. Also document a manual device checklist for TestFlight upgrade testing from the real build 413.

---

## 7. Feature parity gaps vs the App Store version

Screens/behaviors the shipped app has that the port lacks. Genres / All Albums / All Songs are **intentionally excluded** (see the deprecated-features section). "Decide" items need an explicit keep/drop decision recorded.

- [ ] **[PAR-01] P1 — Offline-mode UX audit.** The per-screen `didEnterOfflineMode` model is fine, but every screen needs verification against the OFFLINE MODE spec. Also: the old app confirmed before switching modes and debounced reachability ~6 s; the port switches instantly and automatically — mode-thrash risk on flapping networks.
  > **Prompt:** Audit offline mode: walk every tab/screen against Testing/Integration Tests.txt OFFLINE MODE and fix screens that break or expose online-only actions; add a reachability debounce (~6 s) in NetworkMonitor/SceneDelegate before acting on changes; decide whether automatic switching without confirmation alerts is the desired UX; and ensure the server list/settings remain reachable while offline (the old offline-folders screen had a gear button).

- [ ] **[PAR-02] P1 — Downloads tab: no Play All / Shuffle and no cache-size display.** The old Cache tab had a PlayAllAndShuffleHeader at every browse level plus a total-size/free-space label; the Swift Downloads screens have neither.
  > **Prompt:** Add PlayAllAndShuffleHeader (already in Custom UI) to the Downloads browse screens (whole cache, artist, album scopes — DownloadedFolderArtists/DownloadedFolderAlbum/DownloadedSongs/DownloadedTag* view controllers), honoring jukebox mode like the old loadPlayAllPlaylist:, with the needed Store enqueue-all queries. Also surface total downloaded size (DownloadsManager cacheSize) in the Downloads header. Add store tests and E2E play-all/shuffle cases.

- [ ] **[PAR-03] P1 — Downloaded tag (ID3) browsing shows nothing without metadata backfill.** All four `DownloadedTag*ViewController` files carry the TODO: downloaded songs only appear if their tagArtist/tagAlbum rows exist locally.
  > **Prompt:** Ensure that when a song is downloaded the app fetches and persists its getArtist/getAlbum metadata (AsyncSongsHelper.downloadMetadata is the likely hook), plus a one-time backfill for already-downloaded songs, so the Downloads Artists/Albums sub-tabs populate. Add an integration test that a download makes the song appear in both tag views.

- [ ] **[PAR-04] P2 — Download queue rows lack progress detail, and deleting the active download doesn't stop it.** Old rows showed "Added <time> — Progress: <bytes> / Waiting… / Need Wifi" on a refresh timer; old delete stopped the queue first when removing the currently-downloading song.
  > **Prompt:** In DownloadQueueViewController: (1) reproduce the old per-row subtitles — queued date, live byte progress for the active download, Waiting…, and Need Wifi when gated by network settings — with a lightweight refresh timer while downloading; (2) in deleteItems, when a deleted song equals DownloadQueue.currentQueuedSong, stop the active download before restarting the queue. Add a formatting unit test and an integration test for delete-active-download.

- [ ] **[PAR-05] P3 — Empty-state overlays missing.** Old screens showed "No Cached Songs" / "No Chat Messages on the Server" / "Nothing Playing on the Server"; the Swift Downloads/Chat/NowPlaying screens show blank tables.
  > **Prompt:** Build one reusable empty-state component and apply it to the Downloads sub-tabs (per-subclass text incl. the queue), ChatViewController, and NowPlayingViewController, appearing when the data source is empty and clearing when content loads. Add UI tests.

- [ ] **[PAR-06] P2 — Now-playing music-note nav button missing on Chat / Now Playing / Search Songs.** The old screens installed a right bar button (gated on `showPlayerIcon`) pushing the player; the Swift ports never set it and the setting is unused.
  > **Prompt:** Add the conditional music-note right bar button (SavedSettings.showPlayerIcon) to ChatViewController, NowPlayingViewController, and SearchSongsViewController, navigating to the player, re-installed after sending a chat message like the Obj-C original. Add a UI test.

- [ ] **[PAR-07] P1 — Partial pre-cache of the next song was dropped (decide + restore or remove remnants).** Old StreamHandler pre-cached ~N bytes of the next song then paused the transfer (`isPartialCacheNextSong` setting, partialPrecacheSleep loop, pause/unpause delegate flow); the port has only full-next-song caching, the setting is gone, and dead constants remain.
  > **Prompt:** Decide whether to restore partial pre-cache (ISMSNSURLSessionStreamHandler.m: download the first seconds of the next track, pause the URLSession task, resume when the song becomes current). If restoring: implement in StreamHandler/StreamManager without blocking threads, re-add the isPartialCacheNextSong setting and its Options toggle, with tests that the download pauses at the threshold and resumes. If not: delete the dead helper constants and record the decision.

- [ ] **[PAR-08] P2 — Dropped settings toggles (decide each).** Missing from OptionsViewController vs the old settings screen: "Enable Swipe", "Enable Tap and Hold", "Partial cache next song" (PAR-07). ("Enable Songs tab" is moot — deprecated features.)
  > **Prompt:** For each of enable-swipe and enable-tap-and-hold (long-press/context menus are arguably always-on now) plus the PAR-07 toggle, decide keep/drop; implement kept toggles end-to-end in OptionsViewController + SavedSettings and delete dead keys for dropped ones, documenting decisions.

- [ ] **[PAR-09] P2 — Lock-screen artwork/metadata can lag.** `PlayQueue.updateLockScreenInfo` isn't triggered when large cover art finishes downloading or the playlist index changes; updates wait for the 30 s timer.
  > **Prompt:** In PlayQueue.swift, add observers so updateLockScreenInfo() fires immediately when the current song's large cover art finishes (AsyncCoverArtLoader completion) and on play-queue index change, matching the old MusicSingleton behavior.

- [ ] **[PAR-10] P2 — Gapless-boundary progress reporting.** The new mixer-position `BassPlayer.progress` dropped the old sample-rate-ratio + `previousSongForProgress` handling; elapsed time can jump/misreport right after an automatic track change.
  > **Prompt:** Verify BassPlayer.swift progress across gapless transitions (especially differing sample rates) against the old BassGaplessPlayer ring-buffer-drain computation, and fix if it jumps or misreports. Add a COV-11 case for the boundary.

- [ ] **[PAR-11] P2 — Next-song stream-creation failure at song end silently stalls.** The old player set `isNextSongStreamFailed` and retried via the delegate once the download caught up; Swift `songEnded`/`prepareNextStream` do nothing on failure (the hook survives commented-out in BassCallbacks.swift).
  > **Prompt:** In BassPlayer.swift, detect when prepareStream for the next song fails at a gapless boundary and retry that index through PlayQueue when its StreamHandler signals ready (old bassFailedToCreateNextStreamForIndex: flow), so playback advances instead of stalling. Add an integration test where the next song becomes streamable slightly after the current ends.

- [ ] **[PAR-12] P2 — End-of-playlist stop/cleanup safety net missing.** The old `bassGetOutputData` detected the drained/inactive end state and stopped cleanly (isPlaying=false, songEnded, notifications, session deactivation); Swift relies solely on the BASS_SYNC_END callback and can leave the player "playing" at queue end.
  > **Prompt:** In BassPlayer.swift bassGetOutputData, add the end-of-playback handling from the Obj-C original: when no current stream / channel inactive with zero bytes and the song fully cached, set isPlaying=false, ensure songEnded ran, post songPlaybackEnded, run cleanup on main, and stop cleanly at the end of the queue (deactivating the audio session). Add an integration test playing the last queued song to completion.

- [ ] **[PAR-13] P3 — Now-playing submissions ignore the scrobbling toggle.** `Social.swift` sends the now-playing scrobble whenever online; the old app gated on `isScrobbleEnabled` (and submitted immediately rather than after a 10 s delay).
  > **Prompt:** In Social.swift, gate scrobbleSongAsPlaying() on settings.isScrobbleEnabled (or document a deliberate always-send decision), and review the 10 s nowPlayingDelay vs the old immediate submission. Add a test asserting no submission when disabled.

- [ ] **[PAR-14] P3 — Analytics decision.** `Analytics.swift` is a no-op stub (Flurry commented out, event enum preserved).
  > **Prompt:** Decide the analytics strategy: remove analytics cleanly (delete the stub calls or leave the no-op, remove Flurry leftovers) or wire a modern privacy-respecting backend. Implement the decision App Store-privacy-compliantly.

- [ ] **[PAR-15] P3 — Minor parity nits (batch).** (a) Servers list lost the per-server type icon; (b) player lacks bitrate/format labels (`PlayerViewController.swift:22` TODO); (c) chat lost the styled input; (d) iPad menu lost direct Chat/Now Playing entries — verify intended; (e) tab order is fixed (old app allowed reordering via More) — decide; (f) A-Z section index missing on downloaded artists/albums lists; (g) jukebox input-blocking overlay on Downloads screens — decide if still wanted; (h) server-list row reordering dropped; (i) marquee (auto-scrolling) song-title labels in table cells disabled (AutoScrollingLabel exists and is used elsewhere); (j) Downloads long-press context menus can't run the custom delete/queue handlers the swipe actions use.
  > **Prompt:** Sweep the small parity nits vs the App Store version listed in PAR-15 (a)–(j) of docs/SWIFT_PORT_COMPLETION_CHECKLIST_FINAL.md: fix or make/record an explicit product decision on each, with a test where behavior changes. File references: ServersViewController.cellForRowAt; PlayerViewController.swift:22; ChatViewController; PadMenuViewController; CustomUITabBarController; Downloaded* list VCs (section index); AbstractDownloadsViewController (jukebox blocker); ServersViewController (reorder); UniversalTableViewCell (marquee, commented-out plumbing); DownloadedSongsViewController.swift:83 / DownloadedFolderAlbumViewController.swift:156 (context-menu handlers).

---

## 8. Robustness & error-handling hardening (P2)

- [ ] **[ROB-01] P2 — Check store return values and surface errors across the download/playlist paths.** Ignored results at `StreamHandler.swift:219`, `StreamManager.swift:428`, `DownloadQueue.swift:39`; swallowed load failure at `ServerPlaylistsViewController.swift:135` ("Show error message"); missing save-error feedback in PlayQueueViewController.
  > **Prompt:** Harden error handling: audit every ignored Store return flagged by TODOs (StreamHandler.swift:219, StreamManager.swift:428, DownloadQueue.swift:39-100) and handle failures (log + user feedback + rollback where needed); replace the empty catch in ServerPlaylistsViewController.loadServerPlaylists (~135) with a real error alert (non-cancelled + isPopupsEnabled, mirroring ServerPlaylistViewController); surface save errors in PlayQueueViewController (~172-182).

- [ ] **[ROB-02] P2 — Verify Subsonic API compatibility details.** `URLRequest+Subsonic.swift:96` ("test on different Subsonic versions"); `StreamHandler.swift:193` (`estimateContentLength` sent as Bool vs the old string "true").
  > **Prompt:** Verify request building against real Subsonic/Navidrome/Airsonic servers: the per-action lowest-version strategy (URLRequest+Subsonic.swift ~96) and whether estimateContentLength works as a Bool param (StreamHandler.swift:193; old app sent "true" — send the string form if not). Extend COV-06 with exact-parameter assertions and fix incompatibilities.

- [ ] **[ROB-03] P2 — Background & lifecycle verification.** `SceneDelegate.swift:202` (untested 30 s background-download warning notification), `:211` (expiration-handler question), `AppDelegate.swift:80` (untested alert), multi-scene TODOs (`AppDelegate.swift:13`, `SceneDelegate.swift:13,79`).
  > **Prompt:** Verify the lifecycle edges: exercise the background-download expiration flow (30 s warning local notification + expiration handler), the notification-permission-denied alert, and make an explicit single-scene decision (assert/document it) or implement multi-scene support, removing the TODOs.

- [ ] **[ROB-04] P2 — DB performance: add the deferred indexes and evaluate query plans.** `DownloadsStore.swift:110` ("Implement correct indexes" — all commented out; recursive folder queries full-scan), "check query plan" TODOs (`DownloadsStore.swift:160,277,302,561`), `Store.swift:14` (views for complex joins), `ServerPlaylistStore` "Optimize this".
  > **Prompt:** Do a query-performance pass: add composite indexes on DownloadedSongPathComponent covering the recursive-folder predicates (at minimum (serverId, songId), (serverId, level, parentPathComponent), (serverId, level, pathComponent)), evaluate the flagged queries with EXPLAIN QUERY PLAN against a 10k+ song fixture, consider the views suggested in Store.swift:14, and measure before/after. Keep results identical (assert with tests).

- [ ] **[ROB-05] P2 — Complete or remove the dead ArtistArt caching path.** The `artistArt` table exists and a settings reset button is wired, but `add(artistArt:)` takes a `CoverArt` (writes to the wrong table) and is never called — artist header images are never persisted.
  > **Prompt:** In CoverArtStore.swift (~128), decide whether artist header art should be cached: if yes, fix the parameter type to ArtistArt, persist to the artistArt table, and call it from artist-info image loading; if not, remove the ArtistArt model, schema registration, and reset hook. Add a round-trip or reset test.

- [ ] **[ROB-06] P3 — HLS reverse proxy: add segment caching, remove debug print.** `HLSReverseProxyServer` dropped the caching layer of the class it was adapted from — seeking/replaying video re-downloads every segment — and has a leftover `print`.
  > **Prompt:** In HLSReverseProxyServer.swift, add a bounded cache keyed by origin URL for .ts segments (and optionally rewritten playlists) so scrubbing doesn't re-download, remove the print("addPlaylistHandler ...") line, and add a test asserting a repeated segment request hits the origin once.

- [ ] **[ROB-07] P3 — Misc verified-behavior batch.** VideoPlayer audio-session deactivation error (`VideoPlayer.swift:150`); ServerChecker settings questions (`ServerChecker.swift:52,64`); `DownloadQueue.resume(byteOffset:)` ignores its parameter (`:115`); RTL flip in UniversalTableViewCell (`:114`); BlurredSectionHeader gray-on-black (`:20`); LyricsStore isCached semantics (`:29`).
  > **Prompt:** Work through the small correctness batch: fix the audio-session deactivation error spam in VideoPlayer.swift:150; resolve ServerChecker.swift:52/64; make DownloadQueue.resume(byteOffset:) use or drop its parameter; add the RTL flip in UniversalTableViewCell:114; fix BlurredSectionHeader on black; settle the LyricsStore.swift:29 semantics TODO.

---

## 9. Cleanup / refactor debt (P3)

- [ ] **[CLEAN-01] P3 — Stream layer refactors.** StreamHandler file-header refactor + better error messages (`StreamHandler.swift:25,112,339,376,459`); temp-file removal error decisions (`StreamManager.swift:402,417`, `DownloadQueue.swift:181,196`); redundant saveHandlerStack question (`StreamManager.swift:387`). (The duplicated connectionFinished logic and broken guards are BUG-25.)
  > **Prompt:** Cleanup pass on the stream/download layer TODOs: refactor StreamHandler per its header TODO (error paths, better error messages/codes, simplify minSecondsToStartPlayback), and resolve the minor "do we care if this fails" temp-file TODOs and the saveHandlerStack question. No behavior changes without tests.

- [ ] **[CLEAN-02] P3 — Audio engine verification + dead code.** BASS init constants (`Bass.swift:14,18,22` — device number hardcoded 1, 500 ms vs old ~900 ms buffer, 44.1 vs 48 kHz), `BassPlayer.swift:17,135`, `BassCallbacks.swift:11` (autoreleasepool) and its commented-out old proc blocks, `BassEqualizer.swift:37`, `BassStream.swift:38`; the BassPluginLoad.c shim loads MPC (the shipped app deliberately didn't) and uses different extern symbol names (BASSAPEplugin vs BASS_APEplugin) — silent plugin-load failure risk.
  > **Prompt:** Work through the audio-engine TODOs: validate/settle the BASS init constants (device number, buffer sizes, sample rate) and document choices; remove dead commented code in BassPlayer.cleanup/BassCallbacks/Bass.testStream; verify each BASS plugin actually loads (check BASS_PluginLoad returns, reconcile extern symbol names) and make an intentional MusePack decision; resolve the BassEqualizer/BassStream notes. Test EQ presets end-to-end while there.

- [ ] **[CLEAN-03] P3 — Dead code & debug leftovers (batch).** Three `print()` calls in `AsyncRecursiveSongLoader.loadNextFolder`; `print("BEN ...")` in `EqualizerPointView.init`; dead `folderAlbums` property in `AsyncQuickAlbumsLoader`; commented-out legacy SearchLoader remnants in `SearchSongsViewController`; empty `FolderAlbumViewController.addSectionIndex()`; dead/unreachable save/upload stubs in `LocalPlaylistsViewController` (~86/168/173 — superseded by STUB-01); orphan header `Classes/Models/Loaders/SUSQueueAllLoader.h`; Apple's unused Obj-C Reachability sample app under `Frameworks/Reachability`; stale pdf-filter and SSL-flag TODOs in the loader layer.
  > **Prompt:** Sweep the dead-code batch in CLEAN-03 of docs/SWIFT_PORT_COMPLETION_CHECKLIST_FINAL.md: remove the debug prints (or convert to DDLog), dead properties/stubs/commented remnants, the orphan SUSQueueAllLoader.h, and the unused Frameworks/Reachability sample sources (grep first to confirm unreferenced; do NOT touch BassPluginLoad.h/.c — live code); resolve the AsyncSubfolderLoader/AsyncTagAlbumLoader pdf-filter and AsyncStatusLoader SSL-flag TODOs. Verify the app builds after each removal.

- [ ] **[CLEAN-04] P3 — Architecture/debt batch.** SavedSettings state-saving → Codable store (`SavedSettings.swift:250`); "don't have so many singletons" (`AppDelegate.swift:35`); legacy `ArtistsViewModelDelegate` removal (`ArtistsViewModel.swift:17`); Defines Obj-C sharing (`Defines.swift:18,62`); struct placement in loaders; ServerPlaylist allowed-users field decision (`ServerPlaylist.swift:25`); DropdownMenu resizing (`:193`); iPad hack verification (`PadMenuViewController.swift:110,119`); EQ preset default names (`EqualizerViewController.swift:362,399,681`); Home icon tint (`HomeViewController.swift:197`); HUD defer question (`ServerPlaylistViewController.swift:68`); stale iOS-4-era loadedTime workaround in OptionsViewController (~169).
  > **Prompt:** Sweep the low-priority cleanup batch in CLEAN-04 of docs/SWIFT_PORT_COMPLETION_CHECKLIST_FINAL.md: fix the trivial ones, convert any that reveal real work into checklist items, and remove stale TODO comments as resolved. For the state-saving refactor, replace the manual per-key diffing with a Codable-backed store preserving current behavior (with round-trip tests).

- [ ] **[CLEAN-05] P3 — Accessibility: VoiceOver labels and Dynamic Type.** Essentially no `accessibilityLabel`/traits on custom controls and no Dynamic Type anywhere (fixed point sizes). Not a parity regression, but worth tracking for release. (TEST-06's `accessibilityIdentifier` pass is separate — identifiers aren't user-facing labels.)
  > **Prompt:** Add descriptive accessibilityLabel/traits to all interactive/image-only controls (player transport, EQ, dropdown, swipe actions, cells) and migrate fixed fonts to Dynamic Type where layout allows. Verify with the Accessibility Inspector and add a UI test asserting key controls expose non-empty labels.

---

## 10. Build, project config & release (P1/P2)

*(CI itself is TEST-08 and lands with the first tests.)*

- [ ] **[REL-01] P1 — Add a shared scheme for the App Store "iSub Release" target.** Only the `iSub Beta` scheme exists (bundle id com.einsteinx2.isubbetarewrite); nothing can reproducibly archive the real upgrade binary (com.einsteinx2.isub).
  > **Prompt:** Create a shared "iSub Release" scheme in iSub.xcodeproj/xcshareddata/xcschemes/ whose Build/Run/Profile/Archive actions reference the iSub Release target with Archive on the Release configuration. Verify xcodebuild -list shows both schemes and archiving yields bundle id com.einsteinx2.isub.

- [ ] **[REL-02] P1 — Deployment-target and version decisions.** The port targets iOS 14.0; the shipped app targets 13.0 (upgrade would exclude iOS 13 users). The marketing version must exceed the live App Store version, continuing from build 413.
  > **Prompt:** Confirm whether dropping iOS 13 is intended; if not, lower IPHONEOS_DEPLOYMENT_TARGET to 13.0 and fix 14.0-only API usage. Verify BUILD_VERSION in buildnumber.xcconfig is strictly greater than the live App Store version and build numbering continues from 413. Record both decisions.

- [ ] **[REL-03] P2 — Pin the ProgressHUD dependency.** It's the only SPM dependency on a moving branch (`branch = einsteinx2` of a personal fork) — a reproducibility/supply-chain risk.
  > **Prompt:** In project.pbxproj, change the ProgressHUD package requirement from branch to an exact revision (the commit in Package.resolved) or a version tag, update Package.resolved, and confirm the build. Verify no other dependency uses a branch requirement.

- [ ] **[REL-04] P2 — Release hygiene pass.** Both app targets must build on current iOS; audit vendored frameworks for the Swift target (RaptureXML is used; verify ZipKit, GCDWebServer); review Info.plists/entitlements — the root `iSub Beta.entitlements`/`iSub Release.entitlements` are empty and unreferenced (keychain access comes from `Other/KeychainAccessGroups.plist`, whose group value must NOT change or existing users' saved passwords become unreadable); confirm background-audio and file-sharing flags match the old app.
  > **Prompt:** Do a release-readiness pass: build/run both targets on current iOS; remove or justify unused vendored frameworks; delete (or properly wire) the empty unreferenced entitlements files WITHOUT touching the KeychainAccessGroups.plist group value; confirm background-audio/file-sharing plist flags match main; document the App Store submission checklist for the upgrade release.

---

## 11. New Swift-branch features to preserve (reference — no action)

Net-new vs the App Store version; must not be lost while closing parity gaps:

- Dedicated **Player tab** in the tab bar.
- **Long-press context menus** on ~16 screens (`ContextMenu.swift`) incl. Queue Next and jump-to-Artist/Album.
- **ID3 tag-based browsing** (getArtists/getArtist/getAlbum/getSong loaders, Artists Library sub-tab, tag-based Downloads browsing).
- Unified **search loader** covering `search`, `search2`, `search3`.
- **GRDB data layer** with typed per-entity stores; single-DB architecture with serverId scoping.
- **Async/await loader architecture** (AsyncAPILoader + ~22 loaders); structured error types.
- **Jukebox enhancements:** seek, gain/position reporting, 30 s getInfo polling, error-50 auto-disable.
- **Crash-on-last-launch detection** (`appTerminatedCleanly`) gating download-queue auto-start.
- **Dependency injection** via Resolver.
- Smarter **video playback** (HLS proxy only for self-signed HTTPS; AirPlay allowed otherwise).
- Modern infra: SnapKit, Tabman/Pageboy, ProgressHUD banners, swift-log/CocoaLumberjack with granular `Debug` flags.

---

## 12. Intentionally excluded deprecated features (decision record)

The following Obj-C-era features predate the Subsonic API's tag-based browsing and are **deliberately not ported**. All audit items relating to them are excluded from this checklist:

- **Genres browsing** (GenresViewController + drill-downs, GenreStore/genre tables, offline genre browsing).
- **All Albums / All Songs library tabs** (AllAlbums/AllSongsViewController, SUSAllSongsLoader whole-server crawl, SUSAllAlbumsDAO/SUSAllSongsDAO).
- **"Enable Albums, Songs, and Genres tabs" setting** (`isSongsTabEnabled` / `enableSongsTabSetting`).

Follow-up cleanup implied by the decision (fold into MIG-10 / CLEAN passes):
- Explicitly drop the legacy `enableSongsTabSetting` UserDefaults key during settings migration (documented, not carried over).
- Skip the old `allAlbums`/`allSongs`/`genres`/`albumListCache` cache DBs during migration and delete them in post-migration cleanup (already covered by MIG-09/MIG-10).
- Remove or leave-with-comment the commented-out `tagAlbumIds(mediaFolderId:orderBy:)` query in `TagAlbumStore.swift` (~393), which existed to back an all-albums browse; keep only if a future tag-based "all albums" view is planned.
- The offline-mode E2E suite (E2E-03) and offline audit (PAR-01) should verify the Downloads tab's tag/folder browsing adequately covers the offline browsing role the Genres tab used to fill.

---

## Suggested execution order

1. **Sections 1–2** — test targets, seams, mock Subsonic backend, CI, then the baseline coverage suites (write them against intended behavior; several deliberately fail on known bugs).
2. **Section 3** — E2E harness + online/offline suites (they define done for the stub work).
3. **Section 4 P0 bugs** (BUG-01…09 — the crash, streaming, and SQL fixes) and **Section 5 stubs**, each flipping its pre-written tests green.
4. **Section 6 migration** (MIG-01/02 unblock the rest; MIG-03 is the long pole; MIG-12 verifies).
5. **Section 4 P1/P2 remainder and Section 7 parity** (record keep/drop decisions first, then implement keepers).
6. **Sections 8–10** in parallel as features stabilize; REL items before the release candidate.
7. **MIG-12 / upgrade E2E** re-run on release-candidate builds from the real build-413 baseline.
