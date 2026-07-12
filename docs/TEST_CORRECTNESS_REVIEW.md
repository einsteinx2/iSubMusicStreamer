# Test-Correctness Review — 5f51b9c..ce1e1c3 (HEAD ce1e1c3)

Review of the unit/integration test commits ([TEST-02..08], [COV-01..13], fixture
replacement f83d762, stabilization commits 046a7d2 / 4efe7ff / cb5e5fa / 6278c63,
and SandboxedTestCase), focused on test correctness: tautologies, golden-masters of
buggy behavior, revert-survivable tests, races/flakiness, harness isolation, and
fixture fidelity. Six areas were reviewed against production code at HEAD; the four
most severe claims were independently re-verified by reading the production source.

## Task checklist

Work items in rough priority order. Check off as completed (multi-session tracking).
IDs match the numbered findings below.

### Severe — tests that pin bugs or cannot fail

- [ ] **R-01** Fix `Bass.bytesToBuffer` / `minBytesToStartPlayback` units bug (`* 1024.0` should be `/ 1024.0`) and rewrite the three buffering-tier tests with realistic speeds
- [ ] **R-02** Fix always-true Next-button assertion in `OnlinePlayerUITests` (assert song title changes)
- [ ] **R-03** Restore a real recovery assertion in the seek-past-cache-point UI test (progress must advance past the landed value)
- [ ] **R-04** Fix `DownloadEngine` give-up path (`isDownloading` never reset → queue stalls) and add the missing failure-path test
- [ ] **R-05** Fix `deleteDownloadedSongs(downloadedFolderArtist:/Album:)` ignoring the folder name (deletes ALL artists) and add the scoped-delete test
- [ ] **R-06** Rewrite tautological add-server lifecycle test to drive the production save path (ServersViewModel), not inline reimplementation

### High — reverting the paired feature would pass

- [ ] **R-07** Make loader cancellation tests deterministic (stalling stub, cancel mid-flight) and actually assert the store is untouched
- [ ] **R-08** Add a positive alert-presentation control test and deterministic completion signal for the BUG-30 no-alert test
- [ ] **R-09** Restore determinism to the jukebox sync-index test (delayed stub instead of matching `currentIndex="3"`)
- [ ] **R-10** Add a ScrobbleService timer-plumbing test (`songPlaybackStarted` → `tick()` → submission)
- [ ] **R-11** Make the shuffle-refresh UI test assert row order changed, not just the count label
- [ ] **R-12** Replace "non-empty" assertions defeated by the `"nil"` placeholder with exact fixture values (FolderArtist, MediaFolder, ChatMessage, NowPlayingSong)

### Harness — isolation and mock-server defects

- [ ] **R-13** Interpose `ModelServices.store/settings/playbackCoordinator` in `SandboxedTestCase.setUp` (currently leaks to the real app DB)
- [ ] **R-14** Make `MockSubsonicServer` validate host + core auth params instead of matching by action name only
- [ ] **R-15a** `invalidateAndCancel()` the replaced URLSession in `MockSubsonicServer.install()/uninstall()`
- [ ] **R-15b** Invoke stub handlers outside the NSLock (deadlock trap)
- [ ] **R-15c** Fix param decoding: split on first `=` only; decode `+` as space in bodies
- [ ] **R-15d** Defensive `MockSubsonicServer.uninstall()` in `SandboxedTestCase.tearDown`
- [ ] **R-15e** Record calls in `FakePlayer.streamReadyToStartPlayback` and `FakeStreamManager.streamHandlerStartPlayback` (currently silent no-ops)
- [ ] **R-15f** Constructor-inject `DownloadsManager.downloadQueue` (remove `@LazyInjected` fake-capture hazard)
- [ ] **R-15g** Skip `AppBootstrap.launch()` in the test host when XCTest is present
- [ ] **R-15h** Fix CLAUDE.md drift: `SocialScrobbling` seam no longer exists (ScrobbleService is concrete)
- [ ] **R-16** Make `HLSReverseProxyServer` port injectable; use ephemeral port in tests (fixed 8080 collides across checkouts)

### Medium — flakiness and weak assertions

- [ ] **R-17a** Size StreamHandler cancel test window past the 1.5s retry delay (currently 1s)
- [ ] **R-17b** Replace OfflineUITests fixed-sleep + wrong-tab `isHittable` negatives with positive invariants (queue still empty)
- [ ] **R-17c** Widen/replace the 0.2s negative windows in SingletonLifecycleTests
- [ ] **R-18a** Convert ampersand-in-query and Zulu-date golden-master pins to `XCTExpectFailure` (or fix the underlying bugs)
- [ ] **R-18b** Add a basic-auth test with special characters (pins RFC 7617 violation in the Authorization header)
- [ ] **R-19a** Replace `> 0` count assertions with exact fixture counts in AsyncLoaderTests
- [ ] **R-19b** Assert specific `SubsonicError.dataNotFound` in playlist create/delete loader tests; add them to the shared error-spec loop
- [ ] **R-20a** Add `Store.queueNext` coverage (insert-after-current, offset accumulation, shuffle dual-write)
- [ ] **R-20b** Add duplicate-song `remove(songsAtPositions:)` test (repack by songId corrupts queues; pair with rowid-repack fix)
- [ ] **R-20c** Round-trip `playCount`/`year`/`genre` in `testSongRoundTripAllFields` (add params to `TestData.song`)
- [ ] **R-20d** Fix vacuous BUG-19 assertion in `testGetSongPosition` (seed a song with id `"0042"`)
- [ ] **R-21a** Fix Fixtures/README.md: list synthetic `*_formats`/`_videos` fixtures as hand-crafted; delete or wire up the three unused fixtures
- [ ] **R-21b** Use `getMusicDirectory_album.xml` for the FolderAlbum fixture test (current fixture is degenerate for BUG-20-class bugs)
- [ ] **R-22** Route `BassEffectDAO` through `SavedSettings.defaults` instead of `UserDefaults.standard`; drop manual scrubbing in tests

### Missing coverage (highest value only)

- [ ] **R-23** StreamManager: test `cancelStream` cancels its own pending retry; retry preserves `byteOffset`
- [ ] **R-24** VideoPlayer ↔ HLS proxy contract test (production `__hls_origin_url` assembly is asserted nowhere)
- [ ] **R-25** SearchSongsViewController cancelled-error load-more test (BUG-30's sibling path)
- [ ] **R-26** DownloadEngine online-mode / WWAN-setting notification transitions
- [ ] **R-27** StateRestorer full saveState → loadState round-trip at the unit level
- [ ] **R-28** SavedSettings: `currentVisualizerType` with garbage persisted rawValue (BUG-27 persistence half)

---

## Findings

### Severe — tests that pin bugs or cannot fail

#### R-01. Buffering-tier tests enshrine a units bug and will block the fix

- **Tests:** `Tests/iSubTests/UtilityAndMathTests.swift:158-169` and `:215-220`
- **Bug:** `Classes/Audio Engine/Bass.swift:216` — `kiloBytesForOneSecond = Double(bytesForOneSecond) * 1024.0` (should divide); same math in `Classes/Models/Stream Handlers/StreamHandler.swift:622`
- **Defect:** The factor is ~10^6 too small, so the adaptive 12/8/5/2-second buffer tiers are unreachable at any real download speed. The tests knowingly characterize this — reaching the fast tier requires **40 trillion bytes/sec**.
- **Regression scenario:** Inverted incentive — correcting the units (restoring adaptive buffering) fails `testBassBytesToBufferSlowDownloadBuffersTwentySeconds`, `testBassBytesToBufferVeryFastDownloadBuffersTwoSeconds`, and `testMinBytesToStartPlaybackAdaptiveTiers`, inviting "fixing the test" the wrong way.
- **Evidence:** `XCTAssertEqual(Bass.bytesToBuffer(kiloBitrate: 128, bytesPerSec: 40_000_000_000_000), expected)` with comment "Push the factor above 1.0 to reach the fastest tier". Verified by hand: at 128 kbps, `bytesForOneSecond` = 16384; ×1024 = 16.7 MB labeled "kiloBytes".
- **Confidence:** high (arithmetic verified).
- **Fix:** Correct the production math; rewrite the three tests with realistic speeds (e.g. 100 KB/s vs 16 KB/s of audio → factor ≈ 6 → 2-second tier).

#### R-02. Always-true assertion after "Next" — a dead Next button passes

- **File:** `Tests/iSubUITests/OnlinePlayerUITests.swift:109`
- **Defect:** `sliderValue < paused || sliderValue >= 0` is always true — `sliderValue()` parses "NN%" and returns `?? 0`, never negative (verified). Previous is only checked by "play/pause button still exists".
- **Regression scenario:** Next button doing nothing at all (queue never advances, `playSongAtPosition` broken) passes.
- **Evidence:**
  ```swift
  app.buttons[AccessibilityId.playerNext].tap()
  XCTAssertTrue(waitUntil(timeout: 20) { self.sliderValue(app) < paused || self.sliderValue(app) >= 0 })
  ```
- **Confidence:** high.
- **Fix:** Capture the song title before tapping Next and assert it changed; drop the `|| >= 0` escape hatch.

#### R-03. Seek-past-cache stabilization (6278c63) left the recovery assertion vacuous

- **File:** `Tests/iSubUITests/OnlinePlayerUITests.swift:146-155`
- **Defect:** The retry loop only accepts the drag once `sliderValue > 70`, so the "recovery" check `waitUntil { sliderValue > 60 }` passes on its very first poll — it cannot distinguish "stream restarted at the new offset" from "player silently stalled at the seek position".
- **Regression scenario:** Reverting BUG-02 (`pauseIfUnderrun`): if the player stalls dry at ~90% without crashing, every assertion passes. The only remaining real check is "the app didn't crash". (The drag retry itself is a legitimate stabilization; the old single drag was fail-direction flaky.)
- **Evidence:**
  ```swift
  seekLanded = sliderValue(app) > 70
  ...
  XCTAssertTrue(waitUntil(timeout: 30) { self.sliderValue(app) > 60 },
                "seek past the cache point did not recover")
  ```
- **Confidence:** high (assertion trivially true); medium (BUG-02 revert manifests as silent stall rather than crash).
- **Fix:** Record `landed = sliderValue(app)` after the drag lands and assert `waitUntil { sliderValue > landed + 2 }`, or assert the elapsed-time label increases.

#### R-04. DownloadEngine failure path: zero coverage, hiding a live queue-stall bug

- **Gap:** `Tests/iSubTests/DownloadQueueTests.swift` — no test drives `streamHandlerConnectionFailed`
- **Bug:** `Classes/Models/Stream Handlers/DownloadEngine.swift:256-277` — the give-up branch (after 5 retries) calls `start()` without resetting `isDownloading` (the finished branch at :252 does reset it), and `start()` opens with `guard !isDownloading else { return }` (:94). Verified: after a song exhausts retries the queue silently stalls forever instead of advancing. Carried verbatim from pre-merge `DownloadQueue.swift` (see `git show 906fdca^`).
- **Evidence:**
  ```swift
  NotificationCenter.postOnMainThread(name: Notifications.downloadQueueSongFailed)
  _ = store.removeFromDownloadQueue(song: handler.song)
  currentStreamHandler = nil
  start()   // no-ops: isDownloading is still true
  ```
- **Confidence:** high (both branches read; grep confirms no failure-path test).
- **Fix:** Add a test queuing two songs, drive 6 `streamHandlerConnectionFailed` calls, assert `downloadQueueSongFailed` fires and song 2 starts downloading (fails today); production fix: set `isDownloading = false` before the final `start()`.

#### R-05. Folder-scoped download delete is untested and deletes every artist's downloads

- **Gap:** `Tests/iSubTests/DownloadsStoreTests.swift:262-275` only tests `deleteDownloadedSongs(serverId:level: 0)`, where delete-everything is correct
- **Bug:** `Classes/Models/Data Store/DownloadsStore.swift:669-677` — the typed wrappers delete by `serverId` + `level` only, ignoring the folder name; the query at :634-666 has no `pathComponent`/`parentPathComponent` filter:
  ```swift
  func deleteDownloadedSongs(downloadedFolderArtist: DownloadedFolderArtist) -> Bool {
      return deleteDownloadedSongs(serverId: downloadedFolderArtist.serverId, level: 0)
  }
  ```
- **Regression scenario:** Deleting "Artist A"'s downloads deletes every artist's downloads on that server. This is BUG-09's shape (fixed on the read path, `songsRecursive`) recurring on the delete path — and the suite cannot see it.
- **Confidence:** high.
- **Fix:** Mirror `testSongsRecursiveIsScopedToParentPathComponent_BUG09` for the delete: two-artist library, delete Artist A, assert Artist B's songs survive (fails today; pair with store fix).

#### R-06. Tautological add-server "lifecycle" test

- **File:** `Tests/iSubTests/SingletonLifecycleTests.swift:439-474`
- **Defect:** `testAddServerFlowAllocatesIdPersistsCapabilitiesAndSelects` reimplements the production flow inline (loads status, computes `nextServerId`, builds the `Server`, persists, selects) then asserts on its own writes; the real add-server code path — where BUG-17's phantom/duplicate entries lived — is never executed. `testFailedVerificationDoesNotPersistServer`'s `XCTAssertEqual(store.servers().count, 0)` is vacuous: nothing in the test could have persisted anything.
- **Evidence:** the test's own comment: "The add flow only persists after a successful check (see BUG-17 for the phantom-entry investigation on the real ServerEditViewController path)" (line 470).
- **Confidence:** high.
- **Fix:** Drive the production save path (ServersViewModel / server-edit logic) with the loader stubbed.

### High — reverting the paired feature would pass

#### R-07. Loader cancellation tests are racy and never test "before writing"

- **Files:** `Tests/iSubTests/AsyncLoaderTests.swift:837-855` (`testCancellationThrowsBeforeWriting`), `Tests/iSubTests/AsyncStatusLoaderTests.swift:164-180`
- **Defect:** `let task = Task { try await load() }; task.cancel()` — (a) nondeterministic: the stub responds instantly, so under load the task can finish before `cancel()` lands and `XCTFail` fires spuriously; (b) cancel almost always wins at the first `Task.checkCancellation()` gate (`AsyncAPILoader.swift:82`) before any request, so the mid-flight gates that actually guarantee "throws before writing" are unreachable — and despite the name, **no store assertion exists**.
- **Regression scenario:** Delete the pre-`processResponse` cancellation gates so a cancelled load still persists rows — test still passes.
- **Confidence:** high.
- **Fix:** Use `MockSubsonicServer.stubStalling`, wait until `receivedRequests(action:).count == 1`, then cancel; afterwards assert the store is untouched (e.g. `store.folderArtistIds(...).isEmpty`).

#### R-08. BUG-30 no-alert test: fixed-window negative with no positive control

- **File:** `Tests/iSubTests/ViewControllerLogicTests.swift:167-185`
- **Defect:** The test does catch a straight revert of `!error.isCanceled` (`QuickAlbumsViewController.swift:70`) — the cancellation is deterministic via `stubConnectionError(.getAlbumList, code: .cancelled)`. But detection is `RunLoop.main.run(until: +0.5s)` then `XCTAssertNil(controller.presentedViewController)`: a slow alert presentation false-passes. Grep confirms this `XCTAssertNil` is the *only* alert assertion in the unit suite — if the alert-detection harness (window/hierarchy/popups) is broken, the test is vacuously green.
- **Confidence:** high (mechanism), medium (flake likelihood).
- **Fix:** Add a sibling test stubbing `.cannotConnectToHost` asserting the alert *does* present; replace the 0.5s spin with a deterministic completion signal (poll loader state).

#### R-09. 4efe7ff half-weakened the jukebox sync-index test

- **File:** `Tests/iSubTests/SingletonLifecycleTests.swift:94-111` (`testPlaySongSendsSkipAndUpdatesIndex`)
- **Defect:** To stop the race, the stub's status now reports `currentIndex="3"` — the same value the synchronous update writes — so the assertion can no longer distinguish "playSong updated the index synchronously" (`Jukebox.playSong`, `didReportCurrentIndex`) from "the background status parse set it". Signal degrades from deterministic to intermittent. Mitigations: `testStatusResponseUpdatesPlaybackState` independently covers the status path, and the same commit's scan-all-requests change is a pure strengthening.
- **Evidence:** test comment: "Stub a status whose currentIndex matches the skip target: … so the overwrite is a no-op".
- **Confidence:** medium.
- **Fix:** Stub a *delayed* response (mock supports stalling/chunked) and assert `currentIndex == 3` before the response can land.

#### R-10. ScrobbleService timer wiring is untested

- **Gap:** `Tests/iSubTests/ScrobbleServiceTests.swift` — all tests call `service.handle(song:progress:)` directly; production driver `startTimer()`/`tick()` at `Classes/Models/Singletons/ScrobbleService.swift:99-122` is never exercised.
- **Regression scenario:** Delete the `startTimer()` call in `playbackStarted()` (or break `tick()`'s player plumbing) — every test stays green while production never scrobbles again. (Threshold logic itself is well tested with injected progress — no real-time flakiness.)
- **Confidence:** high.
- **Fix:** One test: set `FakePlayer.progress = 15`, post `songPlaybackStarted`, call `service.tick()` directly, assert a submission; optionally inject the timer interval.

#### R-11. Shuffle-refresh UI test can't detect a broken refresh

- **File:** `Tests/iSubUITests/OnlinePlayerUITests.swift:174-191` (`testShuffleToggleRefreshesQueueView`)
- **Defect:** Both assertions check that a "10 song" count label exists; shuffle changes order, not count — a stale/unrefreshed queue view shows exactly the same label.
- **Regression scenario:** Reverting BUG-14 (`shuffleToggle` posting the refresh notification) passes the very test named for it.
- **Confidence:** medium-high.
- **Fix:** Record the first-row song text before shuffling; assert row order changed (retry once for the 1-in-10 identity shuffle) or the current-song row moved to index 0.

#### R-12. "Non-empty" fixture assertions defeated by the `"nil"` placeholder

- **Files:** `Tests/iSubTests/APIModelParsingTests.swift:269-270` (FolderArtist), `:348` (MediaFolder), `:376-377` (ChatMessage), `:434-435` (NowPlayingSong)
- **Defect:** `stringXML` returns the literal string `"nil"` for a missing/misnamed attribute (`Classes/Extensions/Foundation/String+Clean.swift:46`), which is non-empty — so `XCTAssertFalse(x.isEmpty)` passes with attribute mapping completely broken.
- **Regression scenario:** Typo the attribute key in `FolderArtist.init` (`element.attribute("Name")`) — test passes with `name == "nil"`.
- **Confidence:** high.
- **Fix:** Assert exact fixture values (`id == "221"`, `name == "ALAC"`; `username == "bbaron"`; `songId == "376"`, `playerId == 10`). For MediaFolder assert `id` using the *second* folder (`id="1"`) — the first folder's `id="0"` equals the missing-attribute default and can't discriminate.

### Harness — isolation and mock-server defects

#### R-13. `ModelServices` statics bypass the sandbox — model conveniences hit the real app database

- **Where:** `Tests/iSubTests/Support/TestSandbox.swift:46-65` (setUp never touches `ModelServices`) vs `Classes/Models/API Models/Song.swift:12`, `Classes/Models/DB Models/LocalPlaylist.swift:40,78`
- **Defect:** `SandboxedTestCase` sandboxes FileSystem/defaults/DI but leaves `ModelServices.store/settings/playbackCoordinator` pointing at the app instances set at launch (`DependencyInjection.swift:75-77`); the real `Store`'s `DatabasePool` opened at the real container path before any sandbox existed. Only `StoreTestCase` fixes `store`; `settings` and `playbackCoordinator` are never interposed.
- **Regression scenario:** Any non-`StoreTestCase` test touching `song.localPath`, `LocalPlaylist.queue()` (which also calls the **real** playbackCoordinator's `syncRemoteQueueIfNeeded()`), or `serverPlaylist` accessors silently reads/writes the persistent simulator DB — order-dependent green locally, different on fresh CI.
- **Confidence:** high (mechanism verified end-to-end).
- **Fix:** In `SandboxedTestCase.setUpWithError`, set `ModelServices.store` to a fresh in-memory store (or trapping stub), `ModelServices.settings` to a fresh `SavedSettings()`, `ModelServices.playbackCoordinator = nil`; `TestContainer.deactivate()` already restores in teardown.

#### R-14. MockSubsonicServer matches requests by action name only

- **File:** `Tests/iSubTests/Support/MockSubsonicServer.swift:146-148` and `:132-138`
- **Defect:** `action(from:)` is `lastPathComponent` minus extension; stubs are keyed solely on that string. Host, HTTP method, and every query parameter (auth `u/t/s/v/c`, `id`) are ignored — a wrong request gets the same canned success.
- **Regression scenario:** Breaking `SubsonicRequestBuilder`'s auth generation, dropping `id` from `getMusicDirectory`, or ignoring `currentServerRedirectUrlString` — every loader test still passes unless it explicitly asserts on `receivedRequests`.
- **Confidence:** high.
- **Fix:** Validate host/scheme against the test's `Server` URL; reject requests missing core auth params with a distinct error (opt-out flag for tests needing looseness).

#### R-15. Assorted mock-server / fake / host hazards

- **a. Session not invalidated** — `MockSubsonicServer.swift:67-77, 140-143`: `install()`/`uninstall()` drop the old `APIURLSession` without `invalidateAndCancel()`; its config still carries the stub protocol, so a stalled transfer or retry loop from test A records into test B's shared global `requests` array. Confidence: medium. Fix: invalidate the previous session in both.
- **b. Handler-under-lock deadlock** — `MockSubsonicServer.swift:132-138`: stub handlers run inside a non-recursive `NSLock`; a handler calling `receivedRequests`/`stub`/`reset` hangs the suite with no diagnostic. Confidence: high (path certain). Fix: copy handler out under the lock, unlock, invoke.
- **c. Param decoding truncation** — `MockSubsonicServer.swift:158-163`: `components(separatedBy: "=")` + `parts[1]` drops everything after a second `=` (base64 padding, `enc:` passwords); form-encoded `+` not decoded. An assertion against a truncated value can false-pass. Confidence: high (code), low (trigger). Fix: split on first `=`; `+` → space in bodies.
- **d. No defensive uninstall** — install state is process-global; every current class does clean up, but one early-throwing setUp between `install()` and teardown registration leaves stale stubs live for every later test. Confidence: medium. Fix: defensively `MockSubsonicServer.uninstall()` in `SandboxedTestCase.tearDownWithError`.
- **e. Silent no-op fakes** — `Tests/iSubTests/Support/Fakes.swift:87` (`FakePlayer.streamReadyToStartPlayback`), `:128` (`FakeStreamManager.streamHandlerStartPlayback`): unrecorded, so the play-start handoff is unassertable; production could stop calling it and no fake-based test notices. Confidence: high. Fix: record into `readyHandlers` arrays.
- **f. `@LazyInjected` fake capture** — `Classes/Models/Singletons/DownloadsManager.swift:18`: the real launch-time `DownloadsManager` resolves `downloadQueue` on first access; if that happens during a test it caches that test's `FakeDownloadQueue` forever. Confidence: medium. Fix: constructor-inject like its siblings.
- **g. Test host runs the full production launch** — `main.swift:12`, `Classes/Main/AppBootstrap.swift:24-87`: real `store.setup()` on the persistent simulator DB, `stateRestorer.setup()`, `downloadEngine.setup()`, `playbackCoordinator.resumeSong()`, Flurry — all before the first test; persistent state can start real network/audio work competing with tests. Confidence: high (mechanism), medium (impact). Fix: skip `bootstrap.launch()`/`sceneDidConnect()` when `NSClassFromString("XCTestCase") != nil` (keep `setupRegistrations()`).
- **h. CLAUDE.md drift** — it promises a default fake for `SocialScrobbling`, but no such protocol exists at HEAD (0f4436a replaced `Social` with concrete `ScrobbleService`, not a fakeable seam). Benign today; docs claim coverage that doesn't exist. Fix: update CLAUDE.md.
- **Residual noted, low priority:** `Resolver.root` swap race is bounded by `retiredRoots` (last 2) but not eliminated (`TestContainer.swift:24-47`); `tearDownWithError` force-unwraps `testDefaults` (`TestSandbox.swift:69`) masking earlier setup errors; `stubChunked`'s `Thread.sleep` (`MockSubsonicServer.swift:229`) may pace other loads on the session's protocol thread.

#### R-16. HLS proxy tests bind fixed port 8080

- **Files:** `Tests/iSubTests/HLSVideoTests.swift:26-27`; `Classes/Models/HLSReverseProxyServer.swift:19` (`static let port: Int = 8080`)
- **Defect:** With the documented multi-checkout parallel workflow, two concurrent runs (or any dev server on 8080) fail all three proxy tests spuriously in `setUpWithError`. Loud failure, not silent. The origin mock does this right (OS-assigned port).
- **Confidence:** medium.
- **Fix:** Make the port injectable (default 8080 in prod, ephemeral in tests) — `VideoPlayer` also hard-codes it, so a test-only fix isn't possible.

### Medium — flakiness and weak assertions

#### R-17. Fixed-window negative assertions

- **a.** `Tests/iSubTests/StreamHandlerTests.swift:289-290` — 1s spin, then "cancel must not trigger the failure path"; StreamManager's retry delay is **1.5s**, longer than the window. Fix: size window off the production constant, or use an inverted `XCTNSNotificationExpectation` as `testStopWhenIdleIsANoOp` (DownloadQueueTests.swift:244-247) already does.
- **b.** `Tests/iSubUITests/OfflineUITests.swift:106-110` (also `:301-305`) — "shuffle does nothing offline" proven by 2s sleep + `XCTAssertFalse(playPause.isHittable)`, but the button is on a *different tab* (non-hittable regardless); playback starting slower than 2s also passes. Fix: assert a positive invariant — play queue still empty after the tap.
- **c.** `Tests/iSubTests/SingletonLifecycleTests.swift:147-148, 359-360` — 0.2s windows for "no request sent" / "no auto-start after crash".
- **Minor:** `Tests/iSubUITests/Support/UITestHelpers.swift:165-168` — conditional 2s `waitForExistence` on the folder-picker sheet in the most shared helper; late sheet → 30s failure multiplied across suites. Fix: poll for either sheet or player button in one loop. `Tests/iSubUITests/FirstRunUITests.swift:111` — immediate `app.cells.count == 0` read; mitigated by the relaunch re-assert.

#### R-18. Golden-master pins of real bugs without `XCTExpectFailure`

- **a.** `Tests/iSubTests/URLRequestSubsonicTests.swift:209-216` — `testAmpersandInParameterValueIsNotEscaped` asserts `body.contains("query=a&b")`: a search for "Simon & Garfunkel" is sent as two bogus params (`.urlQueryAllowed` permits `&`/`=`, `String+URLEncode.swift:13`). `Tests/iSubTests/StringCleanXMLTests.swift:151-157` — asserts `"2024-02-24T15:31:22Z"` (legal ISO-8601, emitted by gonic-style servers) parses to `.distantPast`. Both are conscious pins ("Documents a limitation") but as positive assertions of wrong output — a correct fix breaks green tests. Fix: convert to `XCTExpectFailure` against desired behavior or reference tracking IDs.
- **b.** `Tests/iSubTests/URLRequestSubsonicTests.swift:142-152` — basic-auth test uses only URL-safe credentials, so it can't see that production builds the header from `URLQueryEncoded` strings (`URLRequest+Subsonic.swift:142`), violating RFC 7617: password "p ss" is sent as `p%20ss`. Fix: add a `"p@ss word"` case asserting the raw decoded header (fails today; pins correct behavior).
- **Related low:** `String.hexValue` uses `%X` not `%02X` (`String+Hex.swift:13`); both password-encoding tests use bytes ≥ 0x10 so unpadded low bytes are untested.

#### R-19. Weak loader assertions

- **a.** `Tests/iSubTests/AsyncLoaderTests.swift:261` (`albums.count > 0` — fixture has 20), `:430`, `:523` (fixture has 10 songs), `:564`, `:575-576`: a parse-only-the-first-element regression passes all of these; the adjacent store-vs-returned checks compare two outputs of the same parse (self-consistent, not independent). Fix: exact fixture counts.
- **b.** `:126, :149` — playlist create/delete loaders assert only `catch is SubsonicError` (fixture is code 70) and are excluded from the shared error-spec loop, so they'd pass if every error collapsed to `.generic`. Fix: `catch SubsonicError.dataNotFound` + two `LoaderSpec` entries.

#### R-20. Store coverage gaps (index math otherwise verified correct)

- **a.** `Store.queueNext` (`Classes/Models/Data Store/LocalPlaylistStore.swift:421-441`) has **zero callers in Tests/** (verified) — the trickiest queue math: `nextIndexIgnoringRepeatMode + offset` insert-after-current, offset accumulation for multi-song queue-next, shuffle dual-write. Same for `fillPlayQueue` (:566) and `clearAndQueue` (:533, :548). Fix: seed queue, set current index, `queueNext` → assert order via existing `orderedSongIds()`; one `offset: 1` case; one shuffle case.
- **b.** `remove(songsAtPositions:)` repacks positions by `(serverId, songId)` (`LocalPlaylistStore.swift:673-680`); with the same song queued twice (which `queue(song:)` permits) each UPDATE hits both rows → corrupted positions. Untested, already broken. Fix: queue song "1" twice + "2", remove position 0, assert `positions() == [0, 1]` (fails today; pair with rowid-repack fix).
- **c.** `Tests/iSubTests/GRDBRoundTripTests.swift:56-63` — `testSongRoundTripAllFields` compares `playCount`/`year`/`genre` as `nil == nil` forever: `TestData.song` hardcodes them nil, not even as parameters (`Support/StoreTestCase.swift:58-59`). A Codable-key typo that always NULLs those columns — exactly COV-10's target class — slips through. Fix: add the params and set them in the test.
- **d.** `Tests/iSubTests/LocalPlaylistQueueTests.swift:182-184` — the "documents BUG-19" assertion (`getSongPosition(songId: "abc")` is nil) passes identically whether the `Int(songId)` coercion bug (`LocalPlaylistStore.swift:277`) exists or is fixed — "abc" was never added to the playlist. The actual data-loss shape (song id `"0042"` in the playlist unfindable) is untested. Fix: seed `"0042"` and pin the current/correct behavior explicitly.
- **Trivial:** `DownloadsStoreTests.swift:14-15` header claims `XCTExpectFailure` markers that no longer exist — delete the sentence.

#### R-21. Fixture hygiene

- **a.** `Tests/iSubTests/Fixtures/README.md:15-30` claims everything except three named files was "captured from real servers", but the `*_formats`/`_videos` fixtures are synthetic (mock-catalog ids `9001`/`900B`/`9101`, exact-midnight `created` timestamps, hex-style ids Airsonic never emits). `getAlbum_formats.xml`, `getArtist_formats.xml`, `getMusicDirectory_videos.xml` are referenced by **no test** (verified by grep). Fix: correct the README; delete or wire up the dead fixtures (`getMusicDirectory_videos.xml` would give the only fixture-based `isVideo="true"` parse test).
- **b.** `Tests/iSubTests/APIModelParsingTests.swift:320-326` — the FolderAlbum "real fixture" test uses `getMusicDirectory_artist.xml` whose only child has `title == artist` and no `album` attribute, so it cannot detect name/tagArtistName/tagAlbumName cross-wiring (exactly BUG-20's class); the inline test at :295-303 compensates. Fix: use `getMusicDirectory_album.xml` (distinct `title`/`album`/`artist`) and assert all three name fields.
- **f83d762 audit: clean.** No fixture was edited to make a wrong parser pass; lost nonzero-position jukebox coverage was genuinely relocated (`SingletonLifecycleTests.swift:98-110`, inline `position="42"`).

#### R-22. BassEffectDAO bypasses the injected UserDefaults

- **Files:** `Classes/Audio Engine/BassEffectDAO.swift:47-59` (reads/writes `UserDefaults.standard` directly); symptoms at `Tests/iSubTests/ViewControllerLogicTests.swift:548-559` and `BassAudioEngineTests` (hand-scrubbing `"BassEffectSelectedPresetId"`/`"BassEffectUserPresets"` in setUp/tearDown)
- **Defect:** The one real gap in the SavedSettings injection story — `SandboxedTestCase`'s defaults swap doesn't isolate it; tests mutate the test host's persistent defaults, and any future EQ test that forgets the scrub inherits state (order-dependent flakes; a crash between setUp and tearDown leaks presets into later runs).
- **Confidence:** high.
- **Fix:** Route `BassEffectDAO` through `SavedSettings.defaults` (the existing swap point); drop the manual scrubbing.

### Missing coverage (highest value only)

- **R-23. StreamManager:** (a) `cancelStream(song: A)` must cancel A's own scheduled 1.5s retry (`cancelResume`, `StreamManager.swift:231-234`) — making it a no-op passes the whole suite; a user-cancelled download zombie-restarts. Test: fail A, cancel A, assert A never re-enters `isDownloading` over a >1.5s window. (b) Retry preserves `byteOffset` (resume continues, doesn't restart from 0); `numberOfReconnects` resets on successful finish. Also note `testConnectionFailedRetriesUntilCapThenRemoves` (`StreamManagerTests.swift:320`) asserts only the counter and queue membership — a manager that increments but never schedules the resume passes; the 1.5s delay is asserted nowhere.
- **R-24. VideoPlayer ↔ HLS proxy contract:** tests hand-build the `__hls_origin_url` the proxy expects (`HLSVideoTests.swift:45-49`); `VideoPlayer.swift:71-99`'s actual URL assembly (self-signed-HTTPS branch) is asserted nowhere — dropping the origin query item (which the proxy 400s on) stays green. Test: `isInvalidSSLCert = true` + https server, capture the URL handed to the player, fetch through a running proxy.
- **R-25. SearchSongsViewController** load-more has no cancelled-error test — BUG-30's missing `!error.isCanceled` guard was found in QuickAlbums; the sibling search pagination path can regress identically unnoticed.
- **R-26. DownloadEngine** `didEnterOnlineMode`/`manualCachingOnWWANSettingChanged` notification-driven start/stop transitions (`DownloadEngine.swift:198-214`) are untested.
- **R-27. StateRestorer** full `saveState` → new-instance `loadState` round-trip (repeatMode/byteOffset/seekTime into the player) would pin BUG-01's persistence contract at unit level instead of only the UI test's 5-second crash-watch.
- **R-28. SavedSettings** `currentVisualizerType` with a garbage persisted rawValue (persistence half of BUG-27; `SavedSettings.swift:138-141` falls back to `.none`) — one line in `SavedSettingsBehaviorTests` pins it.
- **PlayQueue/Coordinator minor:** the `progress == 10.0` boundary of `playPrevious` (`PlaybackCoordinator.swift:142` uses `>`), and `nextIndex` under repeat-all already past the end.

## Stabilization-commit verdicts

| Commit | Verdict |
|---|---|
| `80a076e` (StreamHandler resume missing file) | Genuine production fix, no test weakening — only `StreamHandler.swift` changed (`if !resume` → `if fileHandle == nil`); the flaky test's assertions untouched and now pass for the right reason. |
| `cb5e5fa` (jukebox index assertion) | Not weakened — same assertion moved before the async wait; still tests the synchronous update. |
| `4efe7ff` (jukebox request-timing) | Half clean: scan-all-requests is a strengthening; the `currentIndex="3"` stub is a mild weakening (R-09). One assertion added (`position == 42`), none deleted. |
| `046a7d2` (test-host crashes) | Not weakened — direct handler invocation still exercises the production `handleInterruption`/`handleRouteChange` bodies (userInfo parsing included); only the NotificationCenter hop is lost. The DI-seam fakes close a trivially-passing hazard rather than opening one. |
| `6278c63` (seek-past-cache UI test) | Drag retry legitimate; recovery assertion gutted (R-03). |

## Clean areas (verified, no action needed)

- **PlayQueue navigation:** every expectation independently recomputed (`(-12 mod 5) = 3`, repeat-none clamps, repeat-one pins); plausible off-by-one reverts (negative-modulo correction at `PlayQueue.swift:165`, BUG-10 clamp) each caught by a specific assertion. Not implementation echoes.
- **Queue-position math:** move/insert/shuffle expectations hand-verified against the production SQL; positions read back via raw `SELECT ... ORDER BY position`, so shift-direction/off-by-one mutations fail the contiguity asserts.
- **Multi-server scoping:** exceptionally covered — per-lookup scoping, BUG-07/08/09 regression tests, `testDeleteServerCascadesAllScopedDataAndFiles` checks 11 scoped tables drop server 1 *and keep* server 2, matching `ServerStore.swift:85-167` exactly.
- **DB/defaults/DI isolation:** per-test UUID temp roots and UserDefaults suites with cleanup, unnamed private in-memory GRDB queues (no shared-name collisions), `MockSubsonicHTTPServer` on an OS-assigned port — parallel processes can't collide. Unstubbed mock actions fail fast with a named error (best anti-vacuity property in the harness).
- **Loader error taxonomy:** `.badCredentials`/`.serverVersion`/`.dataNotFound` asserted per-loader, `responseNotXML` vs `serverUnsupported` distinguished, `responseMissingElement` asserts the exact missing tag — collapse-to-generic fails loudly. No `XCTestExpectation` in the loader files at all (pure async/await); all polling helpers have deadlines; mock records requests under lock *before* responding.
- **APIModelParsing expected values:** epoch math, duration/bitrate units, `coverArt` vs `parent` disambiguation, ChatMessage ms→s, entity decoding — all match fixtures and spec.
- **URLRequestSubsonicTests:** pins real wire values (per-action `v` verified against the production version tables, `p=enc:hex`, GET/POST split, Range header, repeated keys). Note: no salted-token path exists in production to test.
- **SavedSettings injection:** real and complete except BassEffectDAO (R-22) — all keys including per-server `rootFoldersSelectedFolder<id>`, `ServerSession`, `StateRestorer` resolve `SavedSettings.defaults` at access time; non-leak to `.standard` explicitly asserted.
- **ViewControllerLogic BUG regression tests:** BUG-21/22/26/27/28/29 all verified to fail on mental revert; pagination asserts recorded mock-server offsets with bounded polling.
- **SettingsRegistryTests:** pinned count (26) and section order match the `ui:`-carrying properties; `onChange` delivery is synchronous, no race.
- **JukeboxUITests:** strongest UI suite — per-test request logs asserting jukeboxControl action sequences present and `stream?`/`download?` requests absent, unique log path per test, attachment on failure.
- **Notification expectations** consistently created before the triggering call; no bare sleeps in unit suites; no test posts hand-crafted system notifications.
- **BUG-03 threshold test** discriminates under every branch of the speed-adaptive gate (worst-case 262,144 < 500,000 delivered < regressed 983,040).
- **`ProtocolSeamTests`** pins the seam identity: if app registrations stopped aliasing the concrete singletons, tests would catch it.
- **BassAudioEngineTests:** deadline-bounded polls throughout, direct handler invocation per 046a7d2 correctly avoids the BASS-observer crash while testing production bodies; real-hardware dependence is an accepted risk, well managed apart from the BassEffectDAO defaults issue (R-22).
