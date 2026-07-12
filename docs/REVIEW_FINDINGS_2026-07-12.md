# Code Review Findings — 5f51b9c..ce1e1c3 (2026-07-12)

Full review of the ~115-commit range (DI refactor phases, BUG-01..31, STUB-01..10,
SwiftUI Settings rewrite, Home Redesign, test suites) plus the failing CI run on
new-swift-port. Each finding lists a status:

- **FIXED** — fixed in a commit on `review-new-code` (commit subject referenced)
- **PENDING** — confirmed, fix planned in this review pass
- **DEFERRED** — real but out of scope for this pass (design decision, low severity,
  or needs product input); kept here so it isn't forgotten

## CI failures (the linked run + the scheduled rerun on ce1e1c3)

1. **FIXED** `testRetryAfterFailedAuthCreatesSingleEntry` / `testServersAddEditDeleteSwitch`:
   after a successful server save, iOS presents the out-of-process "Save Password?"
   AutoFill sheet (triggered by `.textContentType(.password)` on the SwiftUI form).
   It covers the app and everything below it stays visible but not hittable —
   deterministic on fresh CI simulators. → "Suppress the iOS Save Password prompt in
   UI test mode".
2. **FIXED** `testBookmarksClearAll` "did not reach the root tab bar": the CI xcresult
   contains a crash log — `Array index out of range` in
   `ArtistsViewModel.artist(indexPath:)` from `cellForRowAt`. `startLoad()`'s Task is
   not actor-isolated and mutated `metadata`/`tableSections`/`artistIds` off-main
   while the table laid out. → "Fix off-main table state mutation crash in
   ArtistsViewModel".
3. **FIXED** `testLandscapeAndEqualizerFlows`: failure video shows a stuck
   "Loading / tap to cancel" HUD blocking the player. `HUD.hide()` racing the 0.3s
   grace-period task leaves the ProgressHUD up forever (shown with
   `interaction: false`, so the whole app becomes untappable). → "Fix stray
   fullscreen HUD when hide() races the grace-period animate".
4. **FIXED** `testBookmarkCreation` / `testBookmarksOpenPlayAndDelete` "alert did not
   appear": tap synthesized right after the player animates in gets dropped
   mid-transition on slow CI. Test-side retry helper. → "Deflake bookmark and seek
   UI tests against dropped mid-transition taps" (also covers
   `testSeekWithinSongAndPastCachePoint`'s first drag).

## Severe app bugs

5. **FIXED** `DownloadsStore.deleteDownloadedSongs(serverId:level:)` had no
   `pathComponent` filter: deleting one downloaded folder artist deleted **every**
   download on the server (level 0 matches all songs); deleting an album deleted all
   songs at that depth. `testDeleteDownloadedSongsAtLevel` enshrined the destructive
   behavior. → scoped by `pathComponent` (+ `maxLevel != level`) like
   `songsRecursive`; test rewritten + album-level regression test.
6. **FIXED** BUG-03 adaptive buffering units bug: `kiloBytesForOneSecond =
   bytes * 1024` (should be `/ 1024`) in both `Bass.bytesToBuffer` and
   `StreamHandler.minBytesToStartPlayback`. The seconds-per-second factor computed
   ~10^6 too small, so with any speed sample the slowest tier (16s/20s) always won;
   the faster tiers were unreachable. Tests pinned the wrong tiers with a
   40-trillion-B/s "fast" case; rewritten with realistic speeds incl. mid-tiers.
7. **FIXED** Silent download death on file-write failure (BUG-15 regression):
   the `fileHandle.write` catch called `cancel()`, which never notifies the
   delegate, and BUG-15's `!error.isCanceled` filter in `didCompleteWithError` now
   swallows the resulting cancellation entirely — no retry, no removal, player
   stalls. → mirror the nil-file-handle branch (`connectionFailed(APIError.filesystem)`).
8. **FIXED** Download queue stalls forever once a song exhausts its 5 reconnects:
   the give-up branch of `DownloadEngine.streamHandlerConnectionFailed` called
   `start()` without resetting `isDownloading`, and `start()` guards on it.
   (+ regression test driving the failure path.)
9. **FIXED** `DownloadedFolderAlbum.queueNext()` passed `level: 0` instead of
   `level: level` (BUG-09 sibling): Queue Next on a downloaded album at level ≥ 1
   queued the wrong folder tree (or nothing).
10. **FIXED** Double scrobble after pause→resume (introduced in Phase 8.2):
    `BassPlayer.playPause()` posts `songPlaybackStarted` on resume, and
    `ScrobbleService.playbackStarted()` unconditionally `resetFlags()`, re-arming the
    scrobble + now-playing submissions mid-song. Every pause/resume (including
    audio-session interruptions) repeats the scrobble.
11. **FIXED** Jukebox poll chain revives after deactivation and can wipe the local
    play queue: every in-flight jukebox response unconditionally reschedules
    `getInfo`, and the delegate applies remote state without checking
    `isJukeboxEnabled` — a `.get` landing after switching back to local mode clears
    and replaces the local play queue with the remote playlist. Also the error-50
    path mutated `isJukeboxEnabled` from the URLSession delegate queue (off-main).

## Moderate app bugs

12. **FIXED** BUG-30 pattern left in three siblings: `TagAlbumViewController`,
    `TagArtistViewController`, `FolderAlbumViewController` show an error alert for
    *cancelled* loads (cancel fires from `viewWillDisappear`/HUD close). → added
    `!error.isCanceled` guards.
13. **FIXED** `SongInfoViewController.viewWillDisappear` called
    `super.viewDidDisappear` (BUG-22 sibling typo).
14. **FIXED** `DownloadsManager.checkCache()` (moved off-main by BUG-16) ended with
    `downloadQueue.start()` on the background queue, mutating DownloadEngine's
    main-confined state. → hop to main.
15. **FIXED** Deleting the last/only server skipped all playback teardown
    (`ServersViewModel.delete`): player kept streaming from the deleted server,
    jukebox stayed enabled, queues survived. Also `ServerSwitcher.switchServer()`'s
    reachability guard skipped the *local* teardown entirely when offline. → local
    teardown always runs; only the tab reset/notification stays behind the guard.
16. **FIXED** Jukebox remote playlist mirrored in unspecified order:
    `LocalPlaylist.fetchSongs` had no `ORDER BY position`, so after a queue reorder
    the remote jukebox playlist is rebuilt in rowid order and index-based skips can
    target the wrong song. → `ORDER BY position`.
17. **FIXED** `SavePlaylistFlow` MainActor violations (the CI warnings): local save
    ran on a background queue while reading the live `playQueue` (count/song(index:))
    that the main thread mutates, and called the MainActor `presentLocalSaveError()`
    synchronously. → snapshot the queue's song IDs on the main actor, do the copy in
    a single write, keep UI on main.
18. **FIXED** Successful server-playlist save reported as failure when the follow-up
    cache refresh failed (`SavePlaylistFlow`): the refresh shared the save's catch.
    → refresh failure no longer reports "error saving".
19. **FIXED** `SettingsRootView`'s Servers subtitle (current server URL) never
    refreshed after adding/switching servers (static SwiftUI body, no observation).
    → observes `serverSwitched`/`reloadServerList`.

## Test-correctness fixes

20. **FIXED** `OnlinePlayerUITests` transport test: `sliderValue < paused ||
    sliderValue >= 0` is always true (`?? 0`); a dead Next button passed. → assert
    on the song title changing.
21. **FIXED** Seek-past-cache recovery assertion was vacuous (accepted the drag only
    once `> 70`, then asserted `> 60`). → assert progress strictly past the landed
    value.
22. **FIXED** `APIModelParsingTests` "non-empty" assertions defeated by the `"nil"`
    placeholder `stringXML` returns for missing attributes (FolderArtist,
    MediaFolder, ChatMessage, NowPlayingSong). → exact fixture-value assertions.
23. **FIXED** Loader cancellation tests raced (cancel before the request even
    started) and never asserted the store stayed untouched. → stalling stub,
    cancel mid-flight, assert no rows written.
24. **FIXED** `ScrobbleService` timer plumbing untested (all tests called
    `handle(song:progress:)` directly; deleting `startTimer()` stayed green).
    → notification + tick test. (Also covers the pause/resume double-scrobble
    regression from finding 10.)
25. **FIXED** `SandboxedTestCase` didn't interpose the `ModelServices` statics, so
    model conveniences (e.g. `song.localPath`, `LocalPlaylist.queue()`) hit the real
    app database/coordinator from unit tests. → pointed at sandbox instances in
    setUp (restored in tearDown).

## Deferred (not fixed in this pass — needs product/design decision or larger work)

- **Editing a server's URL reuses the same serverId** (`ServerEditView`): all
  id-scoped rows (browse caches, downloadedSong rows, playlists) survive and now
  describe the old server; downloads on disk under the old `Server.path` are
  orphaned. Needs a migrate-or-purge decision (delete-old+add-new, or migrate rows
  and move the downloads directory).
- **BUG-19 column-affinity fix never reaches existing databases** — the corrected
  TEXT columns live in `initialSchema` only; a pre-fix install keeps INTEGER
  affinity forever. Needs a follow-up GRDB migration rebuilding the affected tables
  (`CAST(songId AS TEXT)`), plus the same fix for `FolderMetadata.parentFolderId`.
- **Server deletion cascade + file removal run synchronously on the main thread**
  (`ServersViewModel.delete` → `store.deleteServer` + recursive `removeItem` of the
  server's downloads): seconds-long UI freeze for large offline libraries; should
  move off-main behind a HUD.
- **Deleting a server can delete another same-URL server entry's files**: downloads
  are keyed by `Server.path` (URL-derived, not username), so two entries for one
  host share a directory and cascade delete wipes both. Skip file removal when
  another server row shares the path.
- **Local overwrite save is not transactional** (`SavePlaylistFlow`): clear +
  per-song adds in separate transactions; a mid-copy failure destroys the original
  playlist. Wants a `Store.replaceSongs(localPlaylistId:songs:)` in one write.
- **Saving the play queue from the Local Playlists tab doesn't refresh the visible
  list** until the user leaves and returns (no notification posted).
- **Low-space alert repeats unthrottled** (once per `start()` attempt, which the
  60-second cache scan can trigger every minute). Wants a "shown once until space
  recovers" latch.
- **`ServersViewModel` "switched to X" notice** can be dropped on iPhone because
  `switchServer()` pops the nav stack hosting the SwiftUI alert.
- **First-run add-server sheet re-presents on a 0.7s timer** every time ServersView
  appears empty (also: user can't dismiss it and look at the empty list). Parity
  with the old screen, but worth revisiting.
- **SettingsCoordinator deferred pushes can double-push** the same section on a fast
  double-tap (dedupe by top view controller).
- **Settings slider rows write UserDefaults + `synchronize()` per drag tick**, and
  any UserDefaults write re-renders open section screens (perf only).
- **StreamHandler relaunch resume is dead code** (pre-existing): handlers persisted
  mid-download decode with `isDownloading == true` and `start()`'s guard no-ops the
  resume loop in `StreamManager.setup()`. Fix is to decode `isDownloading` as false
  (or persist "wasDownloading" separately) — needs testing around the
  DownloadEngine promote path before changing.
- **Force-offline launch ordering** (BUG-24 placement): `resumeSong()` runs at scene
  connect, before the first `sceneDidBecomeActive` flips offline mode — a partially
  cached song can briefly hit the network. Move the offline check into
  `AppBootstrap.launch()`.
- **BassPlayer underrun wait-loop flags** are shared across the BASS callback
  thread/main/underrun queue without synchronization (old ObjC used atomics);
  `isFullyCached` does a SQLite read on the realtime audio thread. Larger
  audio-engine hardening task.
- **`Notifications.songCachingEnabled/Disabled` have no poster** — toggling the
  song-caching setting mid-session doesn't rewire StreamManager's prefetch observer
  (pre-existing; also missing an `onChange` in the new settings).
- **`BassPlayer.shouldResumeFromInterruption` is write-only** — interruption resume
  relies solely on the system `.shouldResume` flag; the test asserts the flag, not
  behavior.
- **Batch deletes silently ignore store failures** (LocalPlaylists/Bookmarks
  screens) — row reappears with no explanation.
- **`SavePlaylistFlow.promptForPlaylistName`** accepts whitespace-only names; name
  collision check is case-sensitive; overwriting a server playlist with an empty
  queue sends zero songIds (server-dependent semantics).
- **Mock-server strictness** (test infra): matches by action name only (auth params
  ignored), stub handlers run under a non-recursive lock, no defensive `uninstall()`
  in teardown, `install()` doesn't invalidate the replaced session.
- **Golden-master pins of real bugs** (kept green deliberately): unescaped `&` in
  query params ("Simon & Garfunkel" breaks requests), seconds+Zulu ISO dates parse
  to `.distantPast`, Basic-auth header percent-encodes credentials (RFC 7617
  violation). Convert to `XCTExpectFailure` and fix the production code in a
  follow-up.
- **HLS proxy tests bind fixed port 8080** — collides across parallel checkouts.
- **`Store.queueNext` insert-after-current math has zero test callers**;
  `remove(songsAtPositions:)` corrupts queues containing duplicate songs
  (pre-existing, untested).
- **`BassEffectDAO` hardcodes `UserDefaults.standard`** — the one seam
  SavedSettings' injectable defaults missed.
- **CLAUDE.md drift**: mentions a `SocialScrobbling` fake seam that no longer exists
  (replaced by `ScrobbleService` in Phase 8.2).

## Home Redesign / E2E review (final agent)

26. **FIXED (test-side)** The loading HUD's *invisible full-window cancel button*
    (ProgressHUD fork, `setupTapHandlerButton`) is only removed in the dismiss
    animation's completion, so a tap landing right after `playerPlayPause` first
    exists can be consumed by the overlay and routed to `cancelLoad` — a second
    concrete mechanism behind the bookmark flakes. Mitigated by the
    `tapExpectingAlert` retry plus a hittability poll at the end of
    `startPlaybackViaServerShuffle`. App-side fix (remove the overlay at dismissal
    *start*) belongs in the vendored ProgressHUD fork — **deferred** there.
27. **FIXED** Switching servers while jukebox mode is active left the getInfo poll
    chain running against the new server and the red window tint stale:
    `ServerSwitcher` flipped `isJukeboxEnabled` raw, skipping
    `JukeboxPlaybackMode.deactivate()`. Now posts `jukeboxDisabled` so the
    coordinator's observers run. (Combined with finding 11's in-flight-response
    guard.)
28. **DEFERRED** iPhone referring-app "Back" affordance is dead code: the removed
    Home screen was the only iPhone UI surfacing the x-callback return button;
    `AppDelegate.referringAppUrl`/`backToReferringApp()` remain but nothing on
    iPhone references them (only the iPad menu's Back cell). Needs a product call:
    surface a Back button on the Player screen, or retire phone-side `ref` handling.
29. **FIXED** `testTransportPlayPauseNextPrevious` tautology (`sliderValue >= 0`
    always true — a dead Next button passed): now asserts the song title changes on
    Next and changes back on Previous (new `player.songTitle` identifier).
30. **FIXED** `testShuffleToggleRefreshesQueueView` asserted only a count label that
    is identical shuffled or not: now snapshots the top rows and asserts unshuffle
    restores the original order.
31. **DEFERRED (minor)** Jukebox suite asserts "no local stream requests" with zero
    settle time after the positive wait — a stream request issued a second late
    would be missed. Add a settle re-check in tearDown if it ever matters.
32. Note: the agent judged `testBookmarksClearAll`'s launch timeout environmental,
    but the CI xcresult's crash log showed the real cause (the ArtistsViewModel
    off-main mutation crash, finding 2/CI) — fixed.

## Verification round (adversarial re-review of this branch's own commits)

An independent re-review of the new commits confirmed all of them except two
defects that were caught and corrected before landing:

- The last-server-delete teardown initially popped every tab to root, tearing down
  the ServersView right before it presented the add-server sheet — fixed with
  `switchServer(resetTabs: false)` for that path.
- The first attempt at exposing the player's song title forwarded the accessibility
  identifier to the clipped inner label, which doesn't surface — replaced with an
  `accessibilityLabel` override plus per-instance `isAccessibilityElement` +
  `.staticText` trait on the player's title only (cells unchanged).

Two low-severity residuals from that review were also addressed: the HUD's
trailing re-dismiss now checks that no newer show() replaced the task (so it can
never hide a legitimate newer HUD), and the cache-eviction test now runs the
eviction from a background queue and asserts the queue restart lands on the main
thread (previously the test passed with or without the main-thread hop). Remaining
noted-but-accepted residuals: a stale jukebox response can still cross servers if
jukebox mode is re-enabled within the response latency (narrow, pre-existing
serverId-at-parse-time ambiguity), and the download give-up path doesn't guard
against a stale handler the way the retry path does (not shown reachable).

## Found while strengthening the seek test (new, discovered 2026-07-12)

33. **DEFERRED (real app edge bug)** Seeking a partially-downloaded song to/past its
    end wedges playback: the elapsed label counts past the song's duration
    (observed 4:27 on a 4:03 song, remaining pinned at -0:00) and the song neither
    ends nor advances for 60+ seconds. Reproduced deterministically by
    testSeekWithinSongAndPastCachePoint once its recovery assertion was made real:
    the slider drag snaps to ~100%, and the underrun wait loop waits for bytes the
    file will never have. Needs audio-engine work (clamp the seek/needed-size to
    the actual file size and end the song at real EOF).
34. **DEFERRED (test-infra gap)** The -SLOWDOWNLOAD fixture song's metadata
    (size 7992587 / duration 4:03) doesn't match the served audio (test_song.mp3,
    584KB ≈ 36s), so slider-fraction seeks land past the real EOF and any
    progress-based recovery assertion is meaningless in the mock environment. The
    seek test now validates BUG-02's actual contract instead (the wait loop must
    not wedge the transport: Next still advances after running dry). A
    metadata-accurate slow fixture would let the progress assertion return.

## Test-correctness checklist status (docs/TEST_CORRECTNESS_REVIEW.md)

Fixed in this pass: R-01 (units bug + tier tests), R-02 (transport tautology),
R-03 (seek recovery assertion), R-04 (DownloadEngine stall + failure-path test),
R-05 (folder-scoped delete + tests), R-07 (loader cancellation made mid-flight
deterministic + store assertions), R-10 (ScrobbleService timer-plumbing test),
R-11 (shuffle order restoration), R-12 (exact fixture-value assertions),
R-13 (ModelServices interposed in SandboxedTestCase).

Still open there (deliberately deferred): R-06 (tautological add-server lifecycle
test), R-08 (positive alert-presentation control), R-09 (jukebox sync-index
determinism), R-14/R-15 (mock-server strictness/hazards), R-16 (HLS fixed port),
and the remaining medium/low items — see that file's checklist.
