# iSub Swift Port — Completion Checklist (Independent Audit v2)

**Audit date:** 2026-07-09
**Audited trees:** `new-swift-port` branch (at commit `d0bb5f7`, "Upgrade dependencies") vs `main` branch (commit `31471ba`, "build 413" — the shipped App Store version).
**Method:** Fresh code-level investigation of both branches (TODO/stub sweep, screen-by-screen and subsystem-by-subsystem parity comparison, persistence/migration analysis, test-infrastructure inventory). The prior audit documents (`SWIFT_PORT_COMPLETION_CHECKLIST.md`, `audit-findings.json`) were deliberately **not** read.

**Goal:** Feature parity with the App Store version, plus the new features the Swift branch introduced, releasable as a direct upgrade with automatic data migration, with comprehensive unit/integration test coverage and UI (E2E) test coverage.

**How to use this document:** Each item has a checkbox, an ID, priority, file references, and a short *Prompt* you can paste into a new session to do the work.

**Priorities:**
- **P0** — Release blocker (broken/stubbed core functionality, data migration)
- **P1** — Required for parity or product quality
- **P2** — Important (tests, CI, robustness)
- **P3** — Cleanup / nice-to-have

---

## 1. Critical playback & download bugs (P0)

These are correctness bugs in the core audio/streaming path — the app plays music, but streaming behavior regresses badly vs the App Store version.

- [ ] **[BUG-01] Buffering/underrun handling is a no-op — streaming songs can run dry.** `Classes/Audio Engine/BassPlayer.swift:533` — `pauseIfUnderrun(bassStream:)` immediately `return`s; the entire wait-for-data implementation is commented out below it. The old app (`BassGaplessPlayer.m` `keepRingBufferFilledInternal`) paused output and waited when playback outran the download; the Swift port will hit silence/premature song-end when a song plays faster than it downloads. Related: the old `EX2RingBuffer` decode-ahead architecture was not ported, and `Bass.bytesToBuffer(kiloBitrate:bytesPerSec:)` is defined but never called.
  > **Prompt:** In BassPlayer.swift, `pauseIfUnderrun(bassStream:)` (line ~533) is a stub that returns immediately with the old Obj-C implementation commented out. Implement underrun handling for partially-downloaded streaming songs: when the decode position approaches the downloaded byte count and the stream isn't fully cached, pause output, wait for enough data (see the commented code and `BassGaplessPlayer.m` in the `main` branch for reference behavior, incl. `shouldBreakWaitLoop`), then resume. Ensure the wait loop can be broken on seek/stop/song-change, and add unit tests for the threshold math.

- [ ] **[BUG-02] Download bandwidth throttling is never applied.** `Classes/Models/Stream Handlers/StreamHandler.swift:431-456` — the throttle helpers (`maxBytesPerInterval(kiloBitrate:isCell:)`, `maxBytesPerIntervalCell/Wifi`) exist but nothing calls them; `urlSession(_:dataTask:didReceive:)` does no rate limiting. The old app throttled downloads (500 kbps cell / 8000 kbps wifi baseline scaled by bitrate) so background caching wouldn't starve the network.
  > **Prompt:** In StreamHandler.swift the download throttling helpers (lines ~431-456) are defined but never invoked from `urlSession(_:dataTask:didReceive:)`. Port the old throttling behavior from `ISMSNSURLSessionStreamHandler.m` (main branch): track bytes per interval and delay reads when over `maxBytesPerInterval` for the current network type (wifi vs cellular). Decide whether to throttle only when a song is actively playing (as the old app did). Add tests for the interval math.

- [ ] **[BUG-03] Playback starts after ~60 s of buffer instead of ~10 s.** `Classes/Models/Stream Handlers/StreamHandler.swift:315` — the "notify delegate to start playback" check uses `minBytesToStartLimiting(kiloBitrate:)` (60 seconds of audio) as the start threshold. The intended helpers `minimumBytesToStartPlayback(kiloBitrate:)` (~10 s) and the adaptive `minBytesToStartPlayback(kiloBitrate:bytesPerSec:)` (lines 424, 460) are defined but unused. Result: ~6× longer time-to-first-audio on streamed songs.
  > **Prompt:** In StreamHandler.swift line ~315, playback start is gated on `minBytesToStartLimiting` (60 s of audio) instead of the ~10 s `minimumBytesToStartPlayback`/adaptive `minBytesToStartPlayback(kiloBitrate:bytesPerSec:)` helpers defined at lines ~424/460. Fix the start threshold to match the old app's `ISMSMinBytesToStartPlayback` behavior (start at ~10 s of buffered audio, adaptive to download speed), keep the 60 s value only for its throttling purpose, and add unit tests covering both thresholds.

- [ ] **[BUG-04] `DownloadQueue.stop()` has an inverted guard — can't stop an active download.** `Classes/Models/Stream Handlers/DownloadQueue.swift:122` — `guard !isDownloading else { return }` returns exactly when a download IS in progress, making `stop()` a no-op when it matters (offline-mode entry, background task expiration). The old `ISMSCacheQueueManager.stopDownloadQueue` correctly returned only when *not* downloading.
  > **Prompt:** In DownloadQueue.swift `stop()` (line ~122), the guard `guard !isDownloading else { return }` is inverted — it returns when a download is in progress, so stop() never stops anything. Fix the guard (return early when NOT downloading), audit callers (offline mode entry, background expiration handler, removeCurrentSong/clear) for reliance on the broken behavior, and add a unit test for the stop() state transition.

- [ ] **[BUG-05] `PlayQueue.index(offset:fromIndex:)` returns negative indices.** `Classes/Models/Singletons/PlayQueue.swift:180-188` — marked `TODO: Fix this logic and write unit tests`. In the `.none` repeat-mode case, the comment says "If we're less than 0, return 0" but the code `return newIndex` returns the negative value. Affects prev-song navigation and any offset math.
  > **Prompt:** In PlayQueue.swift, `index(offset:fromIndex:)` (line ~180, marked TODO) returns a negative `newIndex` in the `.none` repeat case where the comment says it should return 0. Fix the logic for all three repeat modes (none/one/all), verify prevSong/nextSong behavior at playlist boundaries, and write comprehensive unit tests for the index math (negative offsets, wrap-around with repeat-all, boundary conditions).

- [ ] **[BUG-06] Stream prefetch on track change is explicitly wrong.** `Classes/Models/Stream Handlers/StreamManager.swift:351-352` — `currentPlaylistIndexChanged` is marked `TODO: implement this` / `TODO: Fix this logic, it's wrong`; it only removes the previous song's stream and doesn't correctly manage the stream queue when the play queue index changes. Related uncertainty at `StreamManager.swift:139` (`removeStreamWithoutSavingStack` guard condition looks dead/contradictory).
  > **Prompt:** In StreamManager.swift, `currentPlaylistIndexChanged` (lines ~345-355) is marked "Fix this logic, it's wrong" — it only removes the previous song's stream handler. Compare with `ISMSStreamManager.m` in the main branch and implement correct behavior on playlist index change (remove stale handlers, trigger fillStreamQueue for the new next songs). Also review the suspicious guard at line ~139 in `removeStreamWithoutSavingStack` (the inner condition re-tests what the outer guard guarantees, making the delete branch dead). Add unit tests.

- [ ] **[BUG-07] HTTP 5xx during streaming may not propagate as a failure.** `Classes/Models/Stream Handlers/StreamHandler.swift:283` — the `didFailWithError` call for HTTP error status codes is commented out with "does this case even need to be handled here? This needs to be tested." Server errors can silently stall a stream.
  > **Prompt:** In StreamHandler.swift (~line 283), the error propagation for HTTP 5xx responses in the URLSession delegate is commented out with a TODO questioning whether it's needed. Determine the correct behavior (compare with the old ISMSNSURLSessionStreamHandler.m), re-enable failure propagation so a server error surfaces to the delegate instead of silently stalling, and add a test with a stubbed 500 response.

- [ ] **[BUG-08] Potential infinite loop in cache eviction.** `Classes/Models/Singletons/DownloadsManager.swift:132` — `removeOldestCachedSongs` (marked `TODO: Refactor this to improve the logic`) loops while free space is below the minimum but has no break when no more songs can be deleted; if the disk is full of non-song data the loop never exits. Also runs on the main thread (class-level TODO at lines 13-15).
  > **Prompt:** In DownloadsManager.swift, `removeOldestCachedSongs` (~line 132) can loop forever when free space stays below `minFreeSpace` but there are no more downloaded songs to delete — add a termination condition. Also move the cache-scan/eviction work off the main thread per the class-level TODO (lines 13-15). Add unit tests for the eviction loop termination.

- [ ] **[BUG-09] Adding a server with a wrong password creates a duplicate entry.** `Classes/View Controllers/Settings/ServerEditViewController.swift:13` — known bug noted in the file header: after an incorrect password on first server addition, the entry is still added, resulting in two entries once corrected.
  > **Prompt:** Fix the bug documented at the top of ServerEditViewController.swift: adding a server with an incorrect password on first launch still persists the server entry, so correcting the password creates a duplicate. Only persist the server after a successful status check (or update the existing row on retry), and add a regression test around the server add/edit flow in ServerStore.

- [ ] **[BUG-10] Force unwrap crash risk in EQ view.** `Classes/View Controllers/Player/EQ and Visualizer/EqualizerView.swift:151` — marked `TODO: Remove force unwrapping`.
  > **Prompt:** In EqualizerView.swift line ~151 remove the force unwraps flagged by the TODO, handling the nil case gracefully so the EQ view can't crash the app.

---

## 2. Stubbed / unimplemented user-facing features (P0)

Functions that exist but do nothing — a user hitting these features today gets silent no-ops.

- [ ] **[STUB-01] Saving a playlist to the server is not implemented anywhere.** The `createPlaylist` Subsonic endpoint is missing from the `SubsonicAction` enum (`Classes/Models/Async Loaders/URLRequest+Subsonic.swift`), and all three call sites are stubs with commented-out Obj-C: `PlayQueueViewController.swift:217` (`uploadPlaylist(name:)`), `LocalPlaylistViewController.swift:51`, `LocalPlaylistsViewController.swift:87` and `:179` (save-playlist alert action, including the "playlist exists → overwrite" check).
  > **Prompt:** Implement server playlist upload end-to-end: add `createPlaylist` (and `updatePlaylist` if appropriate) to the SubsonicAction enum in URLRequest+Subsonic.swift, create an AsyncPlaylistCreateLoader following the pattern of the other async loaders, and wire up the three stubbed call sites: PlayQueueViewController.uploadPlaylist (line ~217), LocalPlaylistViewController.uploadPlaylist (line ~51), and LocalPlaylistsViewController (lines ~87 and ~179, including the overwrite-confirmation flow). Reference the old implementations in main branch PlaylistsViewController.m / CurrentPlaylistViewController.m. Include cancel support (LocalPlaylistsViewController.swift:169 TODO) and error handling, plus loader unit tests.

- [ ] **[STUB-02] Deleting server playlists does nothing.** `Classes/View Controllers/Tabs/Playlists/ServerPlaylistsViewController.swift:102` — `deleteServerPlaylists(indexPaths:)` is an empty stub; `deletePlaylist` is not in the `SubsonicAction` enum.
  > **Prompt:** Implement server playlist deletion: add `deletePlaylist` to SubsonicAction in URLRequest+Subsonic.swift, add an async loader for it, and implement `deleteServerPlaylists(indexPaths:)` in ServerPlaylistsViewController.swift (~line 102) including removing the row from the local serverPlaylist cache table and error handling (old reference: PlaylistsViewController.m:751 in main branch). Add loader tests.

- [ ] **[STUB-03] Deleting local playlists does nothing.** `Classes/View Controllers/Tabs/Playlists/LocalPlaylistsViewController.swift:142` — `deleteLocalPlaylists(indexPaths:)` is an empty stub.
  > **Prompt:** Implement `deleteLocalPlaylists(indexPaths:)` in LocalPlaylistsViewController.swift (~line 142): delete the selected playlists via LocalPlaylistStore (rows in localPlaylist + localPlaylistSong), update the table, and add a Store-level unit test for playlist deletion cascade.

- [ ] **[STUB-04] Tapping a song in a local playlist doesn't play it.** `Classes/View Controllers/Tabs/Playlists/LocalPlaylistViewController.swift:135` — `didSelectRowAt` shows/hides the HUD but the actual play + show-player calls are commented out.
  > **Prompt:** In LocalPlaylistViewController.swift `didSelectRowAt` (~line 135), the code to actually play the tapped song and show the player is commented out. Implement it using LocalPlaylistStore.playSong(position:localPlaylistId:) and showPlayer(), handling offline mode, and make sure the related jukebox/shuffle TODO in LocalPlaylistStore.swift:538 is honored.

- [ ] **[STUB-05] Bookmark batch delete (edit mode) does nothing.** `Classes/View Controllers/Tabs/Library/BookmarksViewController.swift:98` — `saveEditHeaderSaveDeleteAction` is fully commented out; only single swipe-delete works.
  > **Prompt:** Implement the edit-mode batch delete in BookmarksViewController.swift (~line 98, `saveEditHeaderSaveDeleteAction` is commented out): delete all selected bookmarks via BookmarkStore (including their snapshot localPlaylist rows), refresh the table and SaveEditHeader counts. Reference old behavior in main branch Tabs/Bookmarks/BookmarksViewController.m. Add a BookmarkStore deletion unit test.

- [ ] **[STUB-06] iCloud/iTunes backup exclusion for downloaded songs is a no-op.** `Classes/Models/Singletons/DownloadsManager.swift:204-214` — `setAllCachedSongsToBackup`/`setAllCachedSongsToNotBackup` are stubs (bodies commented out), so the `isBackupCacheEnabled` setting is inert and every downloaded song gets backed up to iCloud (or none do, depending on default file attributes) regardless of the toggle.
  > **Prompt:** Implement `setAllCachedSongsToBackup()` and `setAllCachedSongsToNotBackup()` in DownloadsManager.swift (~lines 204-214, currently stubbed): walk the Downloads directory and set/clear `URLResourceValues.isExcludedFromBackup` on all files (do it on a background queue; note the old app renamed files to hide extensions — the new layout uses real paths, so just set the resource values). Verify the `isBackupCacheEnabled` didSet in SavedSettings.swift triggers them, and set the attribute correctly on newly-completed downloads too.

- [ ] **[STUB-07] No user alert when downloads stop due to low disk space.** `Classes/Models/Stream Handlers/DownloadQueue.swift:55-58` — when free space ≤ 25 MB the queue silently returns; the `showNoFreeSpaceMessage` UI is commented-out Obj-C.
  > **Prompt:** In DownloadQueue.swift (~lines 55-58) the low-disk-space path silently returns with the old showNoFreeSpaceMessage alert commented out. Implement a user-facing alert/banner (respecting the "no free space" messaging from the old app in ISMSCacheQueueManager.m) when the download queue halts for insufficient space.

- [ ] **[STUB-08] Deleting a server leaves all its data and can strand the app.** `Classes/View Controllers/Settings/ServersViewController.swift:243-244` — TODOs: delete all server resources (songs, DB rows, metadata) and switch to another server or show the add-server screen after deleting the current one. Also `switchServer()` at `:105` is flagged "refactor this and make sure it actually works."
  > **Prompt:** In ServersViewController.swift implement the TODOs at lines ~243-244: when a server is deleted, remove all of its data (downloaded song files under Downloads/<server.path>, rows in all serverId-scoped tables via Store, cover art) and, if it was the current server, either switch to another server or present the add-server flow. Also verify/fix `switchServer()` (~line 105, flagged as possibly broken): it should reset caches, reload tabs, and re-check the server. Add Store-level tests for server-scoped data deletion.

- [ ] **[STUB-09] Jukebox mode not honored when playing from local playlists.** `Classes/Models/Data Store/LocalPlaylistStore.swift:102` and `:538` — `TODO: Handle Jukebox mode properly` / `handle Jukebox mode and shuffle`.
  > **Prompt:** In LocalPlaylistStore.swift (lines ~102 and ~538) jukebox mode (and shuffle at line 538) are not handled when queueing/playing songs from local playlists. Implement the jukebox paths (replace/add + start via the Jukebox singleton, matching how PlayQueue handles jukebox) and shuffle handling, mirroring the old PlaylistSingleton behavior, with unit tests.

---

## 3. Automatic data migration from the App Store version (P0 — release blocker)

**Current state: 0% implemented.** `Store.swift:73-80` has the entire `migrateOldData` GRDB migration commented out, and `SavedSettings.migrate()` (`SavedSettings.swift:244-246`) is an empty body. No code reads the old FMDB databases, unarchives the old server list, or moves cached song files. A user upgrading today would lose servers, downloads, playlists, bookmarks, and the play queue (files remain orphaned on disk).

**Old persistence (main branch):** FMDB SQLite files in `Documents/database/` — server-scoped files prefixed with `md5(serverUrlString)` (`<md5>currentPlaylist.db`, `<md5>localPlaylists.db`, `<md5>cacheQueue.db`, `<md5>bookmarks.db`, plus shared `songCache.db`, `lyrics.db`, `coverArtCache*.db`, offline variants). Song files in `Documents/songCache/` named `md5(song.path)` with **no extension**, flat. Settings and the server list (NSKeyedArchived `ISMSServer` array under key `servers`) in UserDefaults, plaintext.

**New persistence (Swift port):** Single GRDB `iSub.db` in `ApplicationSupport/iSub/database/`; all tables keyed by integer `serverId`; play/shuffle/jukebox queues are `localPlaylistSong` rows under fixed playlist ids 1-4; downloads live at `Documents/Downloads/<server.path>/<song.path>` (real directory tree + real filename) with records in `downloadedSong` + `downloadedSongPathComponent`; settings reuse mostly the same UserDefaults keys; server credentials now live in the `server` table.

**Key dependency:** every category below needs the `md5(serverUrlString) → new serverId` mapping produced by SERVER migration, so MIG-02 must run first.

- [ ] **[MIG-01] Build the migration framework & trigger.** Implement the `migrateOldData` GRDB migration scaffold (`Store.swift:73-80`) plus `SavedSettings.migrate()` (`SavedSettings.swift:244-246` with its `migrateIncrementor` scheme). Detect an old install (presence of `Documents/database/*.db` and/or old UserDefaults keys), run migration once with progress UI (this can take minutes for large caches), be crash-resumable, and never lose old data before the new data is verified.
  > **Prompt:** Implement the data-migration framework for upgrading from the Obj-C App Store version of iSub. In Store.swift (~lines 73-80) the `migrateOldData` migration is commented out and SavedSettings.migrate() is empty. Design: (1) detection of a legacy install (old FMDB files in Documents/database/, old `servers` UserDefaults key); (2) a resumable, idempotent migration pipeline that runs before the UI loads with a progress screen (file moves can take minutes); (3) ordering — servers first (see MIG-02) since everything else needs the md5(serverURL)→serverId map; (4) failure policy — keep old files until each category verifies. Use SQLite reads of the old FMDB files directly via GRDB (no FMDB dependency needed). Old schemas are documented in main-branch DatabaseSingleton.m. Set up the skeleton and the legacy-DB reader utilities, with unit tests using fixture copies of old-format databases.

- [ ] **[MIG-02] Migrate servers & credentials.** Old: UserDefaults key `servers` = NSKeyedArchived `ISMSServer[]` (url, username, password, type, uuid — see main branch `ISMSServer.m:17-38`, `SavedSettings.m:860-864`) plus current-server keys `url`/`username`/`password`. New: `server` table + `currentServerId` UserDefault. Must produce the `md5(urlString) → serverId` map used by every other step.
  > **Prompt:** Implement legacy server migration: unarchive the old `servers` UserDefaults value (NSKeyedArchiver array of ISMSServer with url/username/password/type/uuid — see main branch ISMSServer.m; use NSKeyedUnarchiver with a compatibility mapping class since the Obj-C class doesn't exist in the Swift target), insert each into the new `server` table via ServerStore (computing `path` via Server.generatePathFromURL), set `currentServerId` to the server matching the old `url` key, and build and persist an md5(urlString)→serverId map for the later migration steps. Handle the isBasicAuthEnabled flag. Add unit tests with fixture archived data.

- [ ] **[MIG-03] Migrate downloaded song files (the big one).** Old: `Documents/songCache/<md5(song.path)>` flat, no extension. New: `Documents/Downloads/<server.path>/<song.path>`. Requires reading old `songCache.db` `cachedSongs` rows (schema: `md5, finished, cachedDate, playedDate, + full song columns` — see main `DatabaseSingleton.m:274-325`) to know each file's real path, then move+rename potentially many GB of files with directory creation. Note `DownloadsManager.swift:30-31` also has a TODO "Move old cached songs to new location."
  > **Prompt:** Implement migration of downloaded song files from the old App Store version: read old `Documents/database/songCache.db` table `cachedSongs` (columns include md5, finished, cachedDate, playedDate and the full song schema incl. path/suffix — see main-branch DatabaseSingleton.m:274-325); for each finished row, move `Documents/songCache/<md5(path)>` to `Documents/Downloads/<server.path>/<song.path>` creating intermediate directories (serverId/server.path from the MIG-02 map). Must be resumable (crash mid-move safe), tolerate missing files, report progress, respect the backup-exclusion attribute, and clean up `Documents/songCache` and `tempCache` when done. Write integration tests with a fixture old-layout directory tree.

- [ ] **[MIG-04] Migrate downloaded song DB records.** For each migrated file, insert a `song` row plus `DownloadedSong` (serverId, songId, path, isFinished, size, downloadedDate, playedDate) and call `DownloadedSongPathComponent.addDownloadedSongPathComponents` (`DownloadsStore.swift:117`) so the Downloads tab folder browsing works. Old dates are unix epochs; `sizesSongs` table has sizes.
  > **Prompt:** As part of legacy migration, populate the new download records: for each old `cachedSongs` row (songCache.db), create the `song` row from the embedded song columns, insert a DownloadedSong with mapped dates/size (old `sizesSongs` table has file sizes), and generate `downloadedSongPathComponent` rows via DownloadedSongPathComponent.addDownloadedSongPathComponents (DownloadsStore.swift:117) so downloaded folder browsing works. Note the TODO at the top of the four DownloadedTag*ViewController files: tag-based browsing needs getArtist/getAlbum metadata — decide whether to fetch it lazily post-migration. Unit-test with fixture rows.

- [ ] **[MIG-05] Migrate the download queue.** Old: `<md5>cacheQueue.db` table `cacheQueue`. New: `downloadQueue` table (`DownloadsStore.swift:38-44`).
  > **Prompt:** Migrate the legacy download queue: read each old `<md5(serverURL)>cacheQueue.db` `cacheQueue` table (same song schema as cachedSongs) and insert `song` rows + `downloadQueue` rows (serverId, songId, queuedDate) preserving order. Small, straightforward step after MIG-02/MIG-04 utilities exist; include a unit test.

- [ ] **[MIG-06] Migrate play queue / shuffle / jukebox queues.** Old: `<md5>currentPlaylist.db` tables `currentPlaylist`, `shufflePlaylist`, `jukeboxCurrentPlaylist`, `jukeboxShufflePlaylist` (+ `offlineCurrentPlaylist.db`). New: `localPlaylistSong` rows under fixed `localPlaylistId` 1-4 (`LocalPlaylist.swift:13-18`). Playback-resume UserDefaults keys (`normalPlaylistIndex`, `seekTime`, `byteOffset`, `repeatMode`, etc.) mostly carry over by key name — verify `bitRate` → `kiloBitrate` rename.
  > **Prompt:** Migrate the legacy play queues: from `<md5(serverURL)>currentPlaylist.db`, copy `currentPlaylist`→localPlaylistId 1, `shufflePlaylist`→2, `jukeboxCurrentPlaylist`→3, `jukeboxShufflePlaylist`→4 as `song` + `localPlaylistSong` rows preserving positions (fixed ids defined in LocalPlaylist.swift:13-18). Verify the playback-resume UserDefaults keys carry over (`normalPlaylistIndex`, `shufflePlaylistIndex`, `seekTime`, `byteOffset`, `repeatMode`, `isShuffle`, `recover`) and map the old `bitRate` key to the new `kiloBitrate` key in SavedSettings.migrate(). Test that relaunching after migration resumes the same song at the same position.

- [ ] **[MIG-07] Migrate local playlists.** Old: `<md5>localPlaylists.db` with a `localPlaylists(playlist, md5)` index table and one table per playlist named `playlist<md5>` (server playlists cached as `splaylist<md5>`). New: `localPlaylist` rows (id ≥ 5) + `localPlaylistSong`.
  > **Prompt:** Migrate legacy local playlists: read `<md5(serverURL)>localPlaylists.db` — the `localPlaylists(playlist, md5)` table lists playlist names, each with its own table `playlist<md5>` containing the song schema. For each, create a LocalPlaylist via LocalPlaylistStore (ids ≥ 5, respecting nextLocalPlaylistId) and insert song + localPlaylistSong rows preserving order. Skip `splaylist*` tables (server playlist caches — refetchable). Include the offline-mode variant DB. Unit-test with a fixture DB.

- [ ] **[MIG-08] Migrate bookmarks.** Old: `<md5>bookmarks.db` `bookmarks(bookmarkId, playlistIndex, name, position, <song schema>, bytes)`. New: `bookmark` table referencing a `song` row + a snapshot localPlaylist (`BookmarkStore.swift:19-30`) — the old model bookmarked a single song, so create a single-song snapshot playlist per bookmark.
  > **Prompt:** Migrate legacy bookmarks: read `<md5(serverURL)>bookmarks.db` (and offline `bookmarks.db`) rows — each has position (seconds), bytes offset, and full embedded song columns. For each, insert the `song` row, create a single-song snapshot localPlaylist (isBookmark=true) and a Bookmark row (offsetInSeconds=position, offsetInBytes=bytes) via BookmarkStore. Unit-test with fixture rows.

- [ ] **[MIG-09] Migrate lyrics cache (optional/cheap).** Old: `lyrics.db` `lyrics(artist, title, lyrics)`. New: `lyrics(tagArtistName, songTitle, lyricsText)` — straight column-rename copy. Cover art caches (`coverArtCache*.db`) and browse caches (`albumListCache.db`, `<md5>allAlbums/allSongs/genres.db`) should be **skipped** — pure re-fetchable caches.
  > **Prompt:** Migrate the legacy lyrics cache: copy rows from old Documents/database/lyrics.db table `lyrics(artist,title,lyrics)` into the new `lyrics` table (tagArtistName, songTitle, lyricsText) via LyricsStore. Explicitly skip cover-art and browse caches (coverArtCache*.db, albumListCache.db, allAlbums/allSongs/genres DBs) — document that they re-fetch. Quick unit test.

- [ ] **[MIG-10] Settings semantic fix-ups + post-migration cleanup.** Most scalar settings carry over automatically because the UserDefaults key strings are unchanged, but verify each (renames spotted: `bitRate`→`kiloBitrate`, `cacheSongCellColorSetting`→`downloadedSongCellColorType`). After all categories verify: delete old `.db` files, `Documents/songCache/`, `Documents/tempCache/`. Also remove/repair the stale path constants in `SavedSettings.swift:399-425` (`songCachePath`, `databasePath`, `updatedDatabasePath` point at locations nothing uses).
  > **Prompt:** Finish the legacy migration: (1) audit every old SavedSettings.m UserDefaults key against the new SavedSettings.swift Key enum and add fix-ups in SavedSettings.migrate() for renames/semantic changes (known: bitRate→kiloBitrate, cacheSongCellColorSetting→downloadedSongCellColorType); (2) implement the final cleanup step that deletes old database files and the old songCache/tempCache directories only after successful verification; (3) remove or correct the stale unused path properties in SavedSettings.swift (~lines 399-425: songCachePath, tempCachePath, databasePath, updatedDatabasePath).

- [ ] **[MIG-11] End-to-end upgrade verification.** Prove the whole path: install/build the `main`-branch app (build 413), populate it (servers, downloads, playlists, queue, bookmarks, settings), then upgrade-install the Swift build and verify everything survives.
  > **Prompt:** Create an end-to-end upgrade test procedure and automate what's feasible: script a simulator flow that installs the main-branch (Obj-C) build, seeds realistic data (2 servers, downloaded songs incl. odd characters in paths, local playlists, play queue with position, bookmarks, custom settings), then installs the new-swift-port build over it and verifies every category migrated (UI checks + direct iSub.db queries). Document a manual device checklist for TestFlight upgrade testing too. Cover edge cases: huge cache (many GB), missing files, corrupted old DB, interrupted (killed) migration resuming.

---

## 4. Feature parity gaps vs the App Store version (P1)

Screens or behaviors the shipped app has that the Swift port lacks. Some are candidates for intentional dropping — each "decide" item should get an explicit keep/drop decision recorded.

### Removed screens

- [ ] **[PAR-01] Genres browsing is gone (decide + implement or drop).** Old: `Tabs/Genre/GenresViewController.m` + artist/album drill-down, present in online AND offline tab bars (offline genre browsing of the cache was a first-class feature; the old test plan has a whole "Genres tab" offline section). New: no genre screens at all; only the `song.genre` string in SongInfoViewController.
  > **Prompt:** Decide whether to restore Genres browsing (it existed online and, importantly, offline over downloaded songs in the App Store version). If keeping: add a genre browse UI (likely a Library or Downloads sub-tab) backed by the new data model — the `song` table already stores genre; add store queries (genres list, artists/albums/songs per genre, scoped to downloaded songs for offline) and optionally the `getGenres` endpoint for server-side browsing. If dropping, record the decision in the checklist doc.

- [ ] **[PAR-02] "All Albums" / "All Songs" library tabs are gone (decide + implement or drop).** Old: `Tabs/Albums/AllAlbumsViewController` and `Tabs/Songs/AllSongsViewController` — flat alphabetical browse of the entire library, built by `SUSAllSongsLoader` recursively crawling every folder into cache DBs, gated by the "Enable Songs tab" setting. New: nothing equivalent; tag-based Artists browsing partially covers the use case; `AsyncRecursiveSongLoader` exists but only for play/queue/download-all actions.
  > **Prompt:** Decide whether to restore flat "All Albums"/"All Songs" alphabetical library browsing (the old app built these via a long-running recursive crawl — SUSAllSongsLoader — into cache tables, toggled by an "Enable Songs tab" setting). Modern Subsonic servers support ID3 getArtists/getAlbum which the Swift port already uses, so a lighter equivalent could page through getAlbumList2/search3. If keeping, design the store tables + loader + a Library sub-tab; if dropping, record the decision and remove the dead `isSongsTabEnabled`-related settings keys.

- [ ] **[PAR-03] Offline-mode UX audit.** Old: a dedicated offline tab bar (Folders/Genres/Playlists/Bookmarks over the cache) swapped in when connectivity dropped. New: same 5 tabs with per-screen disabling via `didEnterOfflineMode` notifications. The model is fine, but every screen needs verification that it behaves sensibly offline (the old offline test plan in `Testing/Integration Tests.txt` is the spec). Also: the old app asked the user before switching modes; the new one switches automatically (decide if that UX is acceptable), and the old 6-second reachability debounce was dropped (`Main/NetworkMonitor.swift`) — rapid network flapping will thrash online/offline transitions.
  > **Prompt:** Audit offline mode in the Swift port: walk every tab/screen in offline mode against the OFFLINE MODE section of Testing/Integration Tests.txt (browse downloads, genres note, playlists, bookmarks, player) and fix screens that break or show online-only actions. Additionally: (1) consider restoring a debounce (old app waited ~6 s) in NetworkMonitor/SceneDelegate before acting on reachability changes to avoid mode-thrash; (2) decide whether automatic online/offline switching without the old confirmation alerts is the desired UX.

### Feature-level gaps inside ported screens

- [ ] **[PAR-04] Downloads tab: no "Play All / Shuffle" header and no cache-size display.** Old `CacheViewController` had a PlayAllAndShuffleHeader over cached songs plus a cache size / free space label. New `DownloadedSongsViewController.swift` has only the SaveEditHeader; no size info anywhere in Downloads.
  > **Prompt:** In the Downloads tab, add the missing parity features from the old Cache tab: a PlayAllAndShuffleHeader on DownloadedSongsViewController (play/shuffle the whole downloaded library — the component already exists in Custom UI and is used elsewhere), and a header/footer showing total downloaded size and free space (DownloadsManager already computes cacheSize/freeSpace).

- [ ] **[PAR-05] Download queue rows lack progress details.** Old showed "Added <time> — Progress: <bytes> / Waiting… / Need Wifi" per queued item; new `DownloadQueueViewController` shows only "Downloading!"/"Waiting…".
  > **Prompt:** Improve DownloadQueueViewController row subtitles to match the old Cache "Downloading" section: show queued date, live byte progress for the active download (observe StreamHandler progress), and distinct states like "Waiting for Wi-Fi" when downloads are gated by network settings.

- [ ] **[PAR-06] Empty-state overlays missing.** Old screens showed friendly overlays: "No Cached Songs", "No Chat Messages on the Server", "Nothing Playing on the Server" (plus the old full-screen LoadingScreen). New Downloads/Chat/NowPlaying screens show blank tables.
  > **Prompt:** Add empty-state views to the Swift port where the old app had them: Downloads screens ("No Downloaded Songs" with a hint), ChatViewController ("No Chat Messages on the Server"), NowPlayingViewController ("Nothing Playing on the Server"). Build one reusable empty-state component and apply it to these tables when their data source is empty.

- [ ] **[PAR-07] Dropped settings toggles (decide each).** `OptionsViewController.swift` lost four old settings: "Enable Songs tab" (moot unless PAR-02 restores those tabs), "Enable Swipe", "Enable Tap and Hold", and "Partial cache next song" (`isPartialCacheNextSong` — the whole partial-precache feature was dropped from StreamHandler, see PAR-08).
  > **Prompt:** Review the four settings toggles present in the old SettingsTabViewController but missing from OptionsViewController.swift: enable-songs-tab, enable-swipe, enable-tap-and-hold, and partial-cache-next-song. For each, decide keep/drop (swipe and long-press context menus are arguably always-on now); implement any kept toggles end-to-end and delete dead SavedSettings keys for dropped ones, documenting decisions.

- [ ] **[PAR-08] Partial pre-cache of the next song was dropped (decide + restore or remove remnants).** Old StreamHandler pre-cached the first ~N bytes of the next song then paused (`ISMSNumBytesToPartialPreCache`, `partialPrecacheSleep`, pause/unpause delegate flow); the Swift port has no equivalent and the related setting is gone, but leftover unused constants remain.
  > **Prompt:** Decide whether to restore the "partial pre-cache next song" feature from the old app (ISMSNSURLSessionStreamHandler.m: pre-download ~5-10 s of the next track then pause the transfer, so track changes start instantly without fully caching). If restoring, implement it in StreamHandler/StreamManager with its setting; if not, delete the dead helper constants in StreamHandler.swift and note the decision.

- [ ] **[PAR-09] Lock screen artwork can lag.** New `PlayQueue.updateLockScreenInfo` isn't triggered when large cover art finishes downloading or when the playlist index changes (old app observed `ISMSNotification_AlbumArtLargeDownloaded` and `CurrentPlaylistIndexChanged`); art updates wait for the 30 s timer.
  > **Prompt:** In PlayQueue.swift, updateLockScreenInfo() is only refreshed on explicit calls and a 30 s repeat. Add notification observers so lock-screen artwork/metadata update immediately when the current song's large cover art finishes downloading (AsyncCoverArtLoader completion) and when the play queue index changes, matching the old MusicSingleton behavior.

- [ ] **[PAR-10] Gapless-boundary progress reporting.** New `BassPlayer.progress` reads the mixer position directly and dropped the old sample-rate-ratio + `previousSongForProgress` handling, so the progress display around the gapless track transition is less accurate.
  > **Prompt:** Review BassPlayer.swift progress reporting across gapless song transitions: the old BassGaplessPlayer computed progress from ring-buffer drain with sample-rate ratio and had previousSongForProgress handling at song boundaries. Verify the new mixer-position approach reports correct elapsed time right after an automatic track change (especially with differing sample rates) and fix if it jumps/misreports.

- [ ] **[PAR-11] Now-playing submissions ignore the scrobbling toggle.** `Singletons/Social.swift` sends the Subsonic now-playing scrobble (`submission=false`) whenever online; the old `SocialSingleton` gated it on `isScrobbleEnabled`.
  > **Prompt:** In Social.swift, the now-playing notification (scrobble with submission=false) is sent even when the user disabled scrobbling; the old SocialSingleton checked isScrobbleEnabled for both. Gate now-playing submissions on the scrobbling setting (or make a deliberate, documented decision to always send them).

- [ ] **[PAR-12] Analytics decision.** `Singletons/Analytics.swift` is a stub — all Flurry code commented out, event enum preserved. Decide: drop analytics entirely (delete stub + Flurry framework leftovers) or adopt a modern replacement.
  > **Prompt:** Decide the analytics strategy: Analytics.swift is a no-op stub with the old Flurry taxonomy preserved as an enum. Either remove analytics cleanly (delete the stub calls sprinkled through the app or leave the no-op) or wire a modern privacy-respecting backend. Implement the decision.

- [ ] **[PAR-13] Minor parity nits (batch).** (a) Servers list no longer shows the per-server type icon (`ServersViewController.cellForRowAt`); (b) player screen lacks bitrate/format labels (`PlayerViewController.swift:22` TODO); (c) chat screen lost the styled input (old CustomUITextView) and nav now-playing button; (d) iPad menu lost direct Chat/Now Playing entries (they're Home buttons now — verify intended); (e) tab order is fixed (old app allowed user reordering via the More tab — decide).
  > **Prompt:** Sweep the small UI parity nits vs the App Store version: add the server-type icon back to ServersViewController cells; add bitrate/file-type labels to the player (TODO at PlayerViewController.swift:22); review the chat input styling and missing now-playing nav buttons on Chat/NowPlaying screens; confirm the iPad menu contents and fixed tab order are intentional product decisions. Fix or document each.

- [ ] **[PAR-14] Downloaded tag browsing may show incomplete data.** All four `DownloadedTag*ViewController.swift` files carry the TODO: "Make sure to call the getArtist/getAlbum API for all downloaded songs or they won't show up here."
  > **Prompt:** Downloaded songs only appear in the Downloads tab's Artists/Albums (tag) views if their tagArtist/tagAlbum metadata rows exist locally (TODO at the top of the DownloadedTag*ViewController files). Ensure that when a song is downloaded, the app fetches and stores getArtist/getAlbum metadata (AsyncSongsHelper.downloadMetadata is the likely hook), and backfill for already-downloaded songs missing metadata.

---

## 5. Robustness & error-handling hardening (P2)

Concentrated mostly in the download/store paths where return values are ignored and errors are swallowed.

- [ ] **[ROB-01] Check store return values across the download pipeline.** Ignored DB results at `StreamHandler.swift:219`, `StreamManager.swift:428`, `DownloadQueue.swift:39`; silently-swallowed load failure at `ServerPlaylistsViewController.swift:135` ("Show error message"); missing save-playlist error handling at `PlayQueueViewController.swift:172,181-182`.
  > **Prompt:** Harden error handling in the download/playlist paths: audit every ignored Store return value flagged by TODOs (StreamHandler.swift:219 add(downloadedSong:), StreamManager.swift:428, DownloadQueue.swift:39-100) and handle failures (log + user feedback + state rollback where needed); surface load errors in ServerPlaylistsViewController (~line 135) and save errors in PlayQueueViewController (~lines 172-182) to the user.

- [ ] **[ROB-02] Verify Subsonic API compatibility details.** `URLRequest+Subsonic.swift:96` — "Actually test this on different Subsonic versions"; `StreamHandler.swift:193` — `estimateContentLength` sent as bool instead of string needs verification; the old app's server-version gating should be compared.
  > **Prompt:** Verify Subsonic API request building against real servers/versions: URLRequest+Subsonic.swift (TODO at line ~96) needs testing across Subsonic/Navidrome/Airsonic API versions, and StreamHandler.swift:193 questions whether `estimateContentLength` works as a bool param (old app sent "true"). Write request-construction unit tests asserting exact query parameters, and fix any incompatibilities.

- [ ] **[ROB-03] Background & lifecycle verification.** `SceneDelegate.swift:202` — the "return to app within 30 s" background-download local notification is marked untested; `SceneDelegate.swift:211` expiration-handler question; `AppDelegate.swift:80` untested alert; multi-scene TODOs (`AppDelegate.swift:13`, `SceneDelegate.swift:13,79`) — decide single-scene is fine and document, or support multi-scene.
  > **Prompt:** Verify and finish the app-lifecycle edges: test the background-download expiration flow in SceneDelegate (30 s warning local notification, TODO at line ~202, and the expiration handler question at ~211); test the alert at AppDelegate.swift:80; and make an explicit decision on multi-scene/multi-window support (TODOs in AppDelegate/SceneDelegate) — if single-scene, assert/document it rather than leaving TODOs.

- [ ] **[ROB-04] DB performance: add proper indexes.** `DownloadsStore.swift:110` — "Implement correct indexes"; several "check query plan" TODOs (`DownloadsStore.swift:160,277,302,561`); `Store.swift:14` suggests views for complex joins.
  > **Prompt:** Do a query-performance pass on the GRDB layer: add the missing indexes flagged in DownloadsStore.swift (~line 110) and evaluate the "check query plan" TODOs (lines 160, 277, 302, 561) with EXPLAIN QUERY PLAN against a large fixture DB (10k+ songs); consider the views suggested in Store.swift:14. Measure before/after.

- [ ] **[ROB-05] Misc verified-behavior items (batch).** VideoPlayer audio-session deactivation error (`VideoPlayer.swift:150`); ServerChecker settings-update questions (`ServerChecker.swift:52,64`); DownloadQueue `resume(byteOffset:)` ignores its parameter (`DownloadQueue.swift:115`); RTL layout in UniversalTableViewCell (`:114`); BlurredSectionHeader gray-on-black (`:20`); LyricsStore semantics question (`:29`).
  > **Prompt:** Work through the small correctness TODO batch: fix the audio-session deactivation error spam in VideoPlayer.swift:150; resolve the setting-update questions in ServerChecker.swift (lines 52/64); make DownloadQueue.resume(byteOffset:) actually use or drop its parameter (line ~115); add RTL flipping in UniversalTableViewCell (line ~114); fix BlurredSectionHeader appearance on black backgrounds; resolve the isLyricsCached semantics TODO in LyricsStore.swift:29.

---

## 6. Cleanup / refactor debt (P3)

Low-risk debt; batch these by subsystem when convenient. Not release blockers.

- [ ] **[CLEAN-01] Stream layer refactors.** StreamHandler general refactor + error-message polish (`StreamHandler.swift:25,112,339,376,459`); share connection-finished/failed logic between DownloadQueue and StreamManager (`DownloadQueue.swift:170,231`); temp-file removal error decisions (`StreamManager.swift:402,417`, `DownloadQueue.swift:181,196`); redundant saveHandlerStack question (`StreamManager.swift:387`).
  > **Prompt:** Do a cleanup pass on the stream/download layer TODOs: refactor StreamHandler per its file-header TODO (error handling paths, better error messages/codes at lines 339/376, simplify minSecondsToStartPlayback at 459), deduplicate the streamHandlerConnectionFinished/Failed logic shared by DownloadQueue and StreamManager, and resolve the minor "do we care if this fails" temp-file TODOs. No behavior changes without tests.

- [ ] **[CLEAN-02] Audio engine verification notes.** `Bass.swift:14,18,22` (device/sample-rate questions), `BassPlayer.swift:17,135`, `BassCallbacks.swift:11` (autoreleasepool), `BassEqualizer.swift:37`, `BassStream.swift:38`, `BassEffectDAO.swift:17` (finish testing + remove ObjC interop).
  > **Prompt:** Work through the audio-engine verification TODOs: BassEffectDAO.swift (finish testing, remove unneeded @objc interop), Bass.swift device/sample-rate questions, BassPlayer BASS_SetDevice repetition, BassCallbacks autoreleasepool question, BassEqualizer array-copy note, BassStream stat-vs-URL-attributes. Test EQ presets end-to-end (create/edit/save/delete) while in there.

- [ ] **[CLEAN-03] Architecture/debt batch.** SavedSettings state-saving refactor to Codable (`SavedSettings.swift:250`); "don't have so many singletons" (`AppDelegate.swift:35`); legacy protocol removal (`ArtistsViewModel.swift:17`); Defines Obj-C sharing + negative values (`Defines.swift:18,62`); struct placement in loaders (`AsyncSubfolderLoader.swift:11,65`, `AsyncTagAlbumLoader.swift:60`, `AsyncStatusLoader.swift:11`); ServerPlaylist allowed-users field (`ServerPlaylist.swift:25`); DropdownMenu resizing (`DropdownMenu.swift:193`); iPad hack verification (`PadMenuViewController.swift:110,119`); EQ preset default names (`EqualizerViewController.swift:362,399,681`); Home icon colors (`HomeViewController.swift:197`); HUD defer question (`ServerPlaylistViewController.swift:68`); multi-server serverId handling in artists load (`ArtistsViewController.swift:15`).
  > **Prompt:** Sweep the low-priority cleanup TODO batch listed in section 6 CLEAN-03 of docs/SWIFT_PORT_COMPLETION_CHECKLIST_V2.md (misc small TODOs across SavedSettings, Defines, loaders, iPad menu, EQ naming, etc.). Fix the trivial ones, convert any that reveal real work into checklist items, and remove stale TODO comments as they're resolved.

---

## 7. Unit & integration test coverage (P1)

**Current state:** zero automated tests. No test target exists in `iSub.xcodeproj` (only the two app targets), the shared `iSub Beta` scheme's TestAction is empty, and `Testing/` contains only a manual QA text file. Dependencies already include a DI container (Resolver) and GRDB, and `CwlCatchException` is already resolved in SPM. Key blockers to testability: `Store.setup()` hardcodes the DB file path (no in-memory mode), `AsyncAPILoader` uses a file-private shared URLSession (no injection), and Resolver registrations are concrete types.

Suggested order: TEST-01 → TEST-02/03 → the rest in any order; TEST-05/06 need no refactoring at all.

- [ ] **[TEST-01] Create the unit-test target and wire it up.**
  > **Prompt:** Add an XCTest unit-test bundle target ("iSubTests") to iSub.xcodeproj, host it on the iSub Beta app, wire it into the shared iSub Beta scheme's TestAction (currently empty), enable @testable import (ENABLE_TESTABILITY already on), and add one smoke test to prove `xcodebuild test` runs. Also create a Fixtures folder structure for test resources.

- [ ] **[TEST-02] Add in-memory database support to the Store layer.** `Store.swift:23-44` hardcodes `DatabasePool` at `ApplicationSupport/iSub/database/iSub.db`.
  > **Prompt:** Refactor Store.setup() (Store.swift lines ~23-44) to accept a configuration so tests can run against an in-memory GRDB DatabaseQueue (":memory:") while production keeps the DatabasePool file path. Keep the Resolver registration working. Prove it with a first StoreTests case that runs migrate() and asserts the schema exists.

- [ ] **[TEST-03] Add a network seam to the async loaders.** `AsyncAPILoader.swift:41-49` uses a fileprivate module-global ephemeral URLSession.
  > **Prompt:** Make AsyncAPILoader testable: inject the URLSession (init parameter defaulting to the current shared one) or register a URLProtocol-based stub, so all 22 Async*Loader classes can be tested against canned Subsonic XML responses without network. Add a test helper that serves fixture XML and write a first loader test (e.g. AsyncStatusLoader ping success + Subsonic error response).

- [ ] **[TEST-04] Protocol-based dependency injection for core singletons.** `DependencyInjection.swift` registers 10 concrete singletons (Store, SavedSettings, BassPlayer, DownloadsManager, DownloadQueue, StreamManager, Jukebox, PlayQueue, Social, Analytics); nothing is protocol-abstracted, so consumers can't get fakes.
  > **Prompt:** Introduce protocol seams for the Resolver-registered singletons that tests need to fake — start with Store-consumers, SavedSettings, BassPlayer (a PlayerControlling protocol), and StreamManager/DownloadQueue — updating registrations in DependencyInjection.swift and @Injected sites. Do it incrementally (one protocol per PR-sized change) so the app keeps building; the goal is unit-testing PlayQueue, ArtistsViewModel and the download state machines with fakes.

- [ ] **[TEST-05] API model XML parsing tests (no refactor needed).** Every API model has `init(serverId:element: RXMLElement)` (Song, TagArtist, TagAlbum, FolderArtist, FolderAlbum, MediaFolder, ChatMessage, Lyrics, NowPlayingSong, ServerPlaylist…).
  > **Prompt:** Write unit tests for all API model XML parsing: author fixture Subsonic XML responses (ping, getIndexes, getMusicDirectory, getArtists/getArtist/getAlbum, getPlaylists, getNowPlaying, getChatMessages, getLyrics, search results — capture realistic samples from Subsonic API docs), and test each model's init(serverId:element:) for correct field mapping, missing-attribute defaults, and edge cases (special characters, missing durations, video entries).

- [ ] **[TEST-06] Foundation/utility extension tests (no refactor needed).** `Classes/Extensions/Foundation/*` (String+Clean/Hex/URLEncode, URL+QueryParameters/FileSystemAttributes, etc.) plus pure helpers like `Bass.bytesForSeconds`/`estimateKiloBitrate` and `Defines` formatters.
  > **Prompt:** Add unit tests for the pure utility layer: all Classes/Extensions/Foundation string/URL extensions, the byte/time formatting helpers in Defines.swift, and the pure audio math in Bass.swift (bytesForSeconds, estimateKiloBitrate) and StreamHandler's threshold/throttle functions (make them internal if needed for @testable access).

- [ ] **[TEST-07] Data Store CRUD test suite.** 15 store extensions (ServerStore, SongStore, DownloadsStore, LocalPlaylistStore, ServerPlaylistStore, BookmarkStore, CoverArtStore, LyricsStore, MediaFolderStore, FolderArtist/FolderAlbum/TagArtist/TagAlbum stores, plus Store itself).
  > **Prompt:** Using the in-memory Store from TEST-02, write CRUD unit tests for every store extension in Classes/Models/Data Store: servers, songs, downloads (downloadedSong + downloadQueue + path components incl. addDownloadedSongPathComponents folder decomposition), local playlists (create/add/move/remove songs, the fixed queue playlists 1-4, nextLocalPlaylistId), server playlists, bookmarks (with snapshot playlists), cover art, lyrics, and the browse caches. Include multi-server isolation tests (serverId scoping) and deletion cascades.

- [ ] **[TEST-08] Play queue & playback-logic tests.** PlayQueue index math (BUG-05), next/prev with repeat modes, shuffle toggle, `startSongAtOffsetsInternal` cache-state ladder, resume/recover behavior.
  > **Prompt:** Write a unit-test suite for PlayQueue.swift covering: index(offset:fromIndex:) across all repeat modes and boundaries (fix per BUG-05 first), nextSong/prevSong including the 10-second restart-vs-previous rule, shuffle toggle queue swapping, and state save/restore via SavedSettings (use a UserDefaults test suite). Requires the DI seams from TEST-04 to fake BassPlayer/Jukebox/Store.

- [ ] **[TEST-09] Download/stream state-machine tests.** DownloadQueue start/stop/advance (incl. the BUG-04 fix), StreamManager queue/steal/fill/reconnect logic, StreamHandler byte-threshold transitions.
  > **Prompt:** Write unit/integration tests for the download and streaming state machines: DownloadQueue (start/stop/removeCurrentSong/clear, wifi-gating, low-space halt), StreamManager (queueStream/fillStreamQueue/stealForDownloadQueue/handler-stack save-load, reconnect retry counting), and StreamHandler threshold logic (start-playback notification, content-length failures, resume with byte offset) using a fake network layer (TEST-03) and fake store. These are integration tests crossing StreamManager↔StreamHandler↔Store boundaries within XCTest.

- [ ] **[TEST-10] Settings & SavedSettings tests.** Backed by hardcoded `UserDefaults.standard` (`SavedSettings.swift:25`).
  > **Prompt:** Make SavedSettings testable by injecting a UserDefaults instance (suiteName-based) and write tests for: property-wrapper defaults, currentMaxBitrate wifi/cellular selection, state-save/restore round-trip, and (once MIG-10 exists) the migrate() key fix-ups.

- [ ] **[TEST-11] Migration test suite (pairs with section 3).** Fixture copies of real old-format FMDB databases + old-layout file trees.
  > **Prompt:** Build the migration test suite: create fixture old-format databases (songCache.db, currentPlaylist.db, localPlaylists.db, bookmarks.db, lyrics.db with the schemas from main-branch DatabaseSingleton.m) and an old-layout songCache file tree, plus an NSKeyedArchived servers blob; write integration tests that run the full migrateOldData pipeline and assert every category lands correctly in iSub.db and the Downloads directory. Include corruption, partial-file, and re-run (idempotency) cases.

---

## 8. UI / E2E test coverage (P2)

Nothing exists. The old manual QA script at `Testing/Integration Tests.txt` (Online / Offline / Jukebox sections, per-tab step lists) is the behavioral spec to automate — adapted to the new 5-tab layout.

- [ ] **[E2E-01] Create the UI-test target + accessibility identifiers.**
  > **Prompt:** Add an XCUITest target ("iSubUITests") to iSub.xcodeproj wired into the shared scheme, and do an accessibility-identifier pass over the main screens (tab bar items, table cells, player controls, settings fields) so UI tests can address elements reliably. Add one smoke test: app launches, shows the server-setup screen on first run.

- [ ] **[E2E-02] Build a mock Subsonic server harness for UI tests.** The repo already vendors GCDWebServer (`Frameworks/GCDWebServer`) which can serve canned Subsonic XML + audio bytes in-process; select it via launch arguments.
  > **Prompt:** Build a UI-test harness that runs the app against a local mock Subsonic server: use the vendored GCDWebServer (or an equivalent embedded HTTP server in the UI-test runner) serving fixture XML for ping/getIndexes/getMusicDirectory/getArtists/getPlaylists/search plus small real audio files for stream endpoints. Add launch-argument plumbing so the app under test auto-configures a server pointing at the mock and skips onboarding. This unblocks all E2E scenarios.

- [ ] **[E2E-03] Automate the online-mode regression suite.** Convert the ONLINE MODE sections of `Testing/Integration Tests.txt` to XCUITests against the new UI: Home (quick albums, server shuffle, search incl. paging, chat, now playing, settings), Library (folders/artists browse, dropdown, search, play/shuffle/queue/download actions, bookmarks), Player (transport, seek, repeat, shuffle, bookmarks creation, EQ open), Playlists (play queue edit/reorder/delete/save, local + server playlists), Downloads (browse all sub-tabs, queue management, deletion).
  > **Prompt:** Using the mock-server harness, implement the online-mode XCUITest suite based on Testing/Integration Tests.txt adapted to the new tab structure (Home/Library/Player/Playlists/Downloads): cover browsing + playing from each tab, play-queue editing (reorder/delete/save as playlist), download queueing, search, chat, now-playing, bookmarks create/open, and settings toggles. Prioritize the flows that exercise the most code; group into separate test classes per tab.

- [ ] **[E2E-04] Offline-mode E2E suite.**
  > **Prompt:** Implement offline-mode XCUITests: seed downloaded songs via the mock server, then simulate connectivity loss (kill the mock server / use a launch argument forcing offline), and verify per Testing/Integration Tests.txt OFFLINE MODE: tab behavior, browsing/playing downloads, playlists, bookmarks, player, and clean transitions online↔offline (banner, controls disabling).

- [ ] **[E2E-05] Upgrade-migration E2E test.** (Pairs with MIG-11.)
  > **Prompt:** Add an automated upgrade E2E test: a UI test (or scripted xcodebuild flow) that pre-seeds the app container with old-format data (fixture old DBs + md5-named song files + old UserDefaults, installed via a launch-argument test hook or simctl container injection), launches the app, waits for migration, and asserts servers/downloads/playlists/queue/bookmarks appear correctly in the UI.

---

## 9. CI & project infrastructure (P2)

- [ ] **[CI-01] Continuous integration.** No `.github/workflows`, no fastlane, nothing.
  > **Prompt:** Set up GitHub Actions CI for the iSub Xcode project: a workflow on push/PR that resolves SPM packages, builds the iSub Beta scheme for iOS Simulator, runs the unit-test suite, and (as a separate/nightly job, once E2E exists) the UI tests. Cache SPM/DerivedData, pin an Xcode version compatible with the project settings, and add a build-status badge to README.

- [ ] **[CI-02] Release hygiene.** Beta entitlements/plists exist; verify build settings, bump deployment story, and confirm the two app targets (Release/Beta) both still build; decide fate of vendored-but-possibly-unused frameworks (RaptureXML is used; verify ZipKit, GCDWebServer usage in the Swift target).
  > **Prompt:** Do a release-readiness pass on the Xcode project: verify both iSub Release and iSub Beta targets build and run on current iOS, audit the vendored Frameworks folder for anything no longer linked/needed by the Swift target (ZipKit? GCDWebServer usage?), review Info.plist/entitlements for both targets, confirm background-audio mode and file-sharing flags match the old app, and document the App Store submission checklist for the upgrade release (version/build numbering continuing from build 413).

---

## 10. New Swift-branch features to preserve (reference — no action)

For the merge session: these are net-new vs the App Store version and must not be lost while closing parity gaps.

- Dedicated **Player tab** in the tab bar (old app had no player tab).
- **Long-press context menus** on ~16 screens (`Table Cells/ContextMenu.swift`) incl. **Queue Next** and jump-to-Artist/Album — none of this existed in the old app.
- **ID3 tag-based browsing** (getArtists/getArtist/getAlbum/getSong loaders, Artists Library sub-tab, tag-based Downloads browsing).
- Unified **search loader** covering legacy `search`, `search2`, `search3`.
- **GRDB data layer** with typed per-entity stores; single-DB architecture with serverId scoping.
- **Async/await loader architecture** (AsyncAPILoader + 22 loaders).
- **Jukebox enhancements:** seek, gain/position reporting, 30 s getInfo polling, error-50 auto-disable.
- **Crash-on-last-launch detection** (`appTerminatedCleanly`) gating auto-start of the download queue.
- **Dependency injection** via Resolver; structured error types (`Models/Errors`).
- Smarter **video playback** (HLS proxy only for self-signed HTTPS; AirPlay allowed otherwise).
- Modern infra: SnapKit layout, Tabman/Pageboy paged tabs, ProgressHUD banners, swift-log/CocoaLumberjack logging with granular `Debug` flags.

---

## Suggested execution order

1. **Section 1** (BUG-01…04 first — streaming is the product) and **Section 2** stubs.
2. **Section 3** migration (MIG-01/02 unblock the rest; MIG-03 is the long pole).
3. **TEST-01…03** early — they make everything after cheaper; write tests alongside each bug/stub fix.
4. **Section 4** parity decisions (get keep/drop decisions recorded, then implement keepers).
5. **Sections 5, 7 remainder, 8** in parallel as features stabilize.
6. **Section 9** CI as soon as the first tests exist (CI-01 can land right after TEST-01).
7. **MIG-11 / E2E-05** upgrade verification last, on release-candidate builds.
