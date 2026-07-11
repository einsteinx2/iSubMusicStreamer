# Rework Singleton Pattern

**Scope (user-confirmed):** implement Phases 0–7 on this branch — the full mechanical
untangling. Phase 8 (architectural reshaping) stays documented as the destination and gets its
own plan/approval later.

## Context

iSub has 10 application-scoped singletons (Store, SavedSettings, BassPlayer, DownloadsManager,
DownloadQueue, StreamManager, Jukebox, PlayQueue, Social, Analytics) registered via Resolver in
`Classes/Models/DependencyInjection.swift` and consumed through 164 `@Injected` + 38 `@LazyInjected`
sites. The DI container changed the *wiring mechanism* but not the *structure*: the singletons still
reach deep into each other's mutable state, `@LazyInjected` exists specifically to tolerate init
cycles, setup order in AppDelegate/SceneDelegate is fragile (the code itself says
`// TODO: Don't have so many singletons lol`, AppDelegate.swift:41), and state is hard to reason
about. The user asked whether groups of pure functions fit better now that we're in Swift, or what
pattern prevents the cross-access.

**Diagnosis:** the disease is not statefulness — it's *bidirectional references between stateful
objects*. Verified worst entanglements:

1. **PlayQueue ↔ Jukebox** — Jukebox writes `playQueue.currentIndex` and calls `playQueue.clear()`
   from a background URLSession callback (Jukebox.swift:138,150); PlayQueue calls
   `jukebox.replacePlaylistWithLocal()`/`playSong(index:)` (PlayQueue.swift:163-165,251-253,279).
2. **SavedSettings god object** — UserDefaults config + session flags + `loadState()` that WRITES
   playQueue/player state and `saveState()` polling both on a 3.3s Timer
   (SavedSettings.swift:282-380); property didSets fan into downloadsManager/downloadQueue;
   DownloadsManager/Jukebox write settings back.
3. **StreamManager ↔ DownloadQueue** — StreamHandler ownership handoff with delegate reassignment
   (`stealForDownloadQueue`, DownloadQueue.swift:93-101).
4. **BassPlayer ↔ PlayQueue** — `startSongAtOffsetsInternal()` orchestrates
   player+streamManager+downloadQueue internals (PlayQueue.swift:393-454); `songEnded()` mutates
   playQueue/store/social from the audio GCD queue.
5. **Model-layer leak** — Song/playlist value types resolve Store/PlayQueue/player via
   `Resolver.resolve()` (Song.swift:13-16): a Song can reach the audio engine.
6. **Model→UI back-reference** — SavedSettings and DownloadQueue read `SceneDelegate.shared.isWifi`.
7. **Threading races** — BASS render-callback thread runs `social.playerHandleSocial()` which does
   a GRDB query via `playQueue.currentSong` (BassPlayer.swift:473-474); Jukebox mutates playQueue
   off-main; the save-state timer races audio-thread writes to `startByteOffset`.

Existing assets to build on: Resolver composition + 3 protocol seams (PlayerControlling,
StreamManaging, DownloadQueueing), a working test harness (TestContainer child-container swap,
SandboxedTestCase, StoreTestCase, Fakes.swift), ~30 unit test files on CI, NotificationCenter
eventing (~60 names, `postOnMainThread` convention).

**Two facts that make this cheaper than it looks:**
- The whole graph is already constructed eagerly at launch (AppDelegate/SceneDelegate `@Injected`
  resolve everything in `didFinishLaunching`), so moving to eager construction in a composition
  root is a runtime non-change.
- Tests already construct services explicitly (`PlayQueue()` etc. in setUp), so constructor
  injection is mechanical there.

## Answer to the pure-functions question

Pure functions can't model a play queue, a BASS engine, or a handler stack — those stay stateful
services, fixed by **single ownership + one-way dependency direction**. But four responsibilities
trapped inside singletons ARE stateless and become pure static namespaces (repo precedent:
`SceneDelegate.launchOfflineAlertMessage(...)` is already this pattern):

| Pure namespace | Extracted from |
|---|---|
| `SubsonicRequest.build(action:server:params:byteOffset:)` taking a `ServerCredentials` value struct | `URLRequest+Subsonic.swift` (all of it except its 2 `Resolver.resolve()` calls) |
| `BitratePolicy.maxKiloBitrate(isWifi:wifiSetting:cellSetting:)` / `estimatedKiloBitrate(...)` | `SavedSettings.currentMaxBitrate/currentVideoBitrates`, `Song.estimatedKiloBitrate` |
| `CacheEvictionPolicy.evaluate(cacheSize:freeSpace:config:) -> Action` | decision half of `DownloadsManager.checkCache()` |
| `ScrobbleRules.scrobbleDelay(...)` / `actions(...)` | `Social` threshold logic |

## Target architecture

**Rule: references point DOWN only; information flows UP only via NotificationCenter posts or
narrow delegate protocols.**

```
L4 UI            AppDelegate, SceneDelegate, VCs        (keep @Injected — leaves)
L3 Coordinators  StateRestorer, [later: PlaybackCoordinator, DownloadArbiter,
                 ScrobbleService, NowPlayingService], Analytics
L2 Domain        PlayQueue, BassPlayer, Jukebox, StreamManager, DownloadQueue, DownloadsManager
L1 Session       [later: ServerSession, SubsonicRequestBuilder]
L0 Infra         Store, SavedSettings(config only), NetworkStatus, APIURLSession, FileSystem
                 + pure namespaces
```

**Wiring:** constructor injection for all services (the 38 `@LazyInjected` inside services die —
cycles become inexpressible). Resolver survives ONLY as (1) the composition root that builds the
graph eagerly and registers *instances*, and (2) VC-level `@Injected` (164 sites stay; VCs are
leaves and service-location at the edge is harmless). Rejected: hand-rolled AppDependencies struct
(discards the working TestContainer harness for zero gain); a new DI framework.

**Communication cycles that legitimately remain** (e.g. player→playQueue on song end) become
`weak` back-references wired via `attach(...)` calls in ONE visible place — the composition root.
Ownership stays acyclic; every back-edge is explicit and greppable.

**Eventing:** keep NotificationCenter + `postOnMainThread` for one-to-many signals. Narrow delegate
protocols only for 1:1 latency-sensitive paths (existing `StreamHandlerDelegate`; later
`PlayerDelegate`/`JukeboxDelegate`). No Combine migration, no typed event bus.

**Threading:** no actor migration (BASS C callbacks can't be actors; timing-critical). Rules:
main-confined for Settings/PlayQueue/StreamManager/DownloadQueue state + Jukebox callbacks;
queue-confined BassPlayer internals with the existing `synchronized()` helper (newly guard
`startByteOffset`/`startSecondsOffset`); render thread does audio only. Enforce with debug
`dispatchPrecondition` where confinement is claimed.

## Progress

Check off each phase/sub-phase as it lands as a commit on this branch:

- [x] Phase 0 — Guardrails + characterization backfill
- [x] Phase 1 — NetworkStatus service
- [x] Phase 2 — SavedSettings decomposition
- [x] Phase 3 — Composition root + leaf constructor conversion
- [x] Phase 4 — StreamHandler transient conversion
- [x] Phase 5a — StreamManager + DownloadQueue
- [x] Phase 5b — Jukebox
- [x] Phase 5c — BassPlayer + PlayQueue + Social
- [x] Phase 6 — Models, request building, VC boilerplate
- [x] Phase 7 — Ambient stragglers + ratchet to zero
- [ ] Phase 8 — Architectural reshaping (follow-up program, approve separately)

## Implementation phases

Each phase — and each sub-phase (5a, 5b, 5c) — lands as its own separate commit on this branch;
build + `iSubTests` green at every boundary; the codebase is strictly better at every stopping
point.

### Phase 0 — Guardrails + characterization backfill (S, low risk)
- `Scripts/check-di-boundaries.sh` in CI unit-tests job: hard-ban `SceneDelegate.shared` /
  `AppDelegate.shared` under `Classes/Models` + `Classes/Audio Engine` (6 current violations
  cleared in Phase 1, then the ban holds); ratchet (checked-in baseline, count may only fall) for
  `Resolver.resolve|@Injected|@LazyInjected` in those same dirs.
- Backfill characterization tests for the three highest-risk behaviors: state-restoration quirks
  (jukebox-mode `isPlaying=false`, `isRecover` derivation, dirty-diff State cache),
  `PlayQueue.resumeSong()` matrix, `StreamManager.setup()` restart recovery, DownloadQueue steal
  handoff delegate reassignment.

### Phase 1 — NetworkStatus service (S/M, low-med risk)
- New `NetworkStatus` protocol (`isWifi`, `isNetworkReachable`); existing `NetworkMonitor`
  conforms; registered app-scoped. SceneDelegate keeps forwarder props for its own/VC use.
- Replace `SceneDelegate.shared.isWifi` reads in SavedSettings.swift:93,112,157,
  DownloadQueue.swift:47,149, StreamHandler.swift:387, OptionsViewController.swift:309-312.
- New `FakeNetworkStatus` in Fakes.swift; drop the "set both bitrate branches identically" test
  workaround; add DownloadQueue wifi-gating tests.

### Phase 2 — SavedSettings decomposition (M, med-high risk, highest payoff)
- Extract **`StateRestorer`** (new file): the `State` struct, `loadState()`, `saveState()`, 3.3s
  Timer (SavedSettings.swift:256-380) — bodies copied verbatim. Forward-only deps
  (settings/player/playQueue/defaults) → constructor-injectable immediately; nothing depends on it.
- Invert the two didSet fan-outs to notifications: `isBackupCacheEnabled` → DownloadsManager
  observes; `isManualCachingOnWWANEnabled` → DownloadQueue observes (it already observes
  online/offline in init).
- **Do NOT rename SavedSettings** (~40 VC files keep compiling untouched). Keep the
  `SavedSettings.defaults` static — it IS the test sandbox.
- Preserve the launch invariant: `loadState()` (writes playQueue indices + player offsets) runs in
  `didFinishLaunching` BEFORE SceneDelegate's `streamManager.setup()` → `playQueue.resumeSong()`.
- After this phase SavedSettings' only service dep is `store` in `setup()` → pass as `setup(store:)`.

### Phase 3 — Composition root + leaf constructor conversion (M, low risk)
- `DependencyInjection.setupRegistrations()` becomes: build an eager `AppServices`
  (construction order + `attach()` back-edge wiring in one function), then register the
  **instances**: `main.register { services.store }` … `main.register { services.player as
  PlayerControlling }`. Behaviorally identical (graph is already eager); `ProtocolSeamTests` is the
  canary and needs zero edits; TestContainer's child-container shadowing keeps working unchanged.
- Constructor-convert leaves: Store, Analytics, SavedSettings, NetworkMonitor(settings:),
  Social(settings:), DownloadsManager(settings:store:). Converted services keep `@LazyInjected`
  *bridges* only for not-yet-converted peers; each bridge dies when its peer converts (leaf-first
  order means no bridge ever points back at a converted service).

### Phase 4 — StreamHandler transient conversion (M, med risk)
- `StreamHandler` (dynamically created + Codable-persisted) gets a `Dependencies` struct passed to
  init; the decode path reads deps from `decoder.userInfo` set by `StreamManager.loadHandlerStack()`.
  Creation sites: StreamManager.swift:298, DownloadQueue.swift:105.
- Move `saveHandlerStack`/`loadHandlerStack` off raw `UserDefaults.standard`
  (StreamManager.swift:258-280) onto the injected defaults store (today it leaks past the test
  sandbox; StreamManagerTests scrubs the key manually).

### Phase 5 — The entangled core (L, high risk — three landable slices)
- **5a StreamManager + DownloadQueue:** DownloadQueue constructor-injects `StreamManaging` (real
  dependency: steal + playback forwarding). StreamManager's need of DownloadQueue is read-only →
  narrow `DownloadQueueStatus` protocol (`isDownloading`, `currentQueuedSong`, `isInQueue`)
  attached weakly at the composition root (`DownloadQueueing` can refine it so FakeDownloadQueue
  still works). Fix BassPlayer.swift:23 concrete `StreamManager` → `StreamManaging`.
- **5b Jukebox:** `init(settings:store:)`; `weak var playQueue` attached at composition root;
  **marshal the URLSession response-callback mutations onto main** (fixes a live cross-thread
  write; JukeboxTests + the BUG-31 queue-mirror comparison are the regression canaries).
- **5c BassPlayer + PlayQueue + Social:** PlayQueue converts fully
  (`init(store:settings:player:jukebox:streamManager:downloadQueue:)` — all edges forward by now).
  BassPlayer gets `attach(playQueue:)` weak. Social: change `playerHandleSocial()` to take
  `(song, progress)` from the caller — BassPlayer passes `currentStream.song`, which **deletes the
  GRDB query on the BASS render thread** (the worst threading bug) with zero timing change.
  Lock-guard `startByteOffset`/`startSecondsOffset` with the existing `synchronized()` helper.
  **Keep `songEnded`'s synchronous `playQueue.incrementIndex()` on the stream GCD queue** —
  gapless mixer splicing (`BASS_Mixer_StreamAddChannel`) depends on that timing; do not invert.

### Phase 6 — Models, request building, VC boilerplate (M/L, low-med risk)
- Song and the other ~9 model files lose `Resolver.resolve()`: bitrate math → pure `BitratePolicy`;
  the player/playQueue-dependent `downloadProgress` block → DownloadsManager helper;
  `download()/queue()` actions → UI call sites (VCs already inject Store); store-backed path/cached
  props take store params, or pragmatically a single `Song.store` static set at composition root +
  StoreTestCase. Convert type-by-type.
- `URLRequest+Subsonic` → `SubsonicRequestBuilder(store:settings:)` registered in the container;
  keep the existing `init?(serverId:...)` as a thin shim so the ~22 loaders don't churn in one
  commit.
- The 12 VC `var serverId { (Resolver.resolve() as SavedSettings).currentServerId }` →
  `@Injected settings` + direct access. `LockScreenAudioControls.setup()` takes services explicitly.

### Phase 7 — Ambient stragglers + ratchet to zero (S/M, low risk)
- `AsyncCoverArtLoaderManager.shared` and `APIURLSession.shared` into the container where feasible;
  guardrail flips from ratchet to hard-fail for `Classes/Models/**` + `Classes/Audio Engine/**`;
  delete the AppDelegate TODO.

### Phase 8 — Architectural reshaping (follow-up program, approve separately)
With ownership acyclic and construction explicit, the remaining *communication* cycles can be
dissolved. Documented here as the destination; not part of the initial implementation:
- **PlaybackCoordinator** (L3): playSong/playNext/resumeSong/startSongAtOffsetsInternal move out of
  PlayQueue; BassPlayer emits `PlayerDelegate.playerDidFinishSong`; coordinator pushes
  `player.prepareNext(song:)` for gapless. PlayQueue reduces to queue math + Store persistence.
- **PlaybackMode strategy**: `PlaybackMode` protocol (play/pause/stop/seek/queueDidChange/
  activate/deactivate); `LocalPlaybackMode` (BassPlayer+StreamManager) vs `JukeboxPlaybackMode`
  (Jukebox slimmed to a remote-control client with `JukeboxDelegate`). Do NOT force Jukebox behind
  `PlayerControlling` — that protocol is a BASS seam (currentStream/byteOffsets); jukebox needs
  queue-sync semantics it can't express. Collapses the ~38 `settings.isJukeboxEnabled` branches;
  UIAlertController presentation leaves Jukebox (post a notification the UI observes).
- **DownloadArbiter** mediating the StreamManager↔DownloadQueue handler steal; end-state option:
  merge both into one DownloadEngine with two priorities.
- **ScrobbleService** (timer-driven, off the audio path entirely) + **NowPlayingService** (absorbs
  LockScreenAudioControls + PlayQueue.updateLockScreenInfo). **ServerSession** (currentServer/
  isOfflineMode/redirect split out of SavedSettings) + `AppBootstrap.launch()/sceneDidConnect()`
  consolidating the remaining semantic setup order in one file.

## What NOT to do (agreed by both design passes)

- No actor/Sendable migration of the audio path; no event-inversion of `songEnded` (gapless timing).
- No Combine/typed-event-bus replacement of NotificationCenter (~60 names, pure churn).
- No constructor injection of the ~40 VCs; VC-level `@Injected` is explicitly retained.
- No new DI/architecture framework; no renaming SavedSettings during the split.
- Don't remove the `SavedSettings.defaults` static swap point (it is the test sandbox).
- Don't convert models first (their call sites live inside the Phase-5 core; you'd touch them twice).

## Test-harness evolution

- `SandboxedTestCase`/`TestSandbox`/`StoreTestCase`: unchanged throughout (defaults static +
  FileSystem override are orthogonal to DI shape).
- Per-phase churn is setUp-only: `X()` → `X(deps...)` + `attach(...)`; fakes pass straight into
  inits. `TestContainer.register { fresh }` lines stay while any production code still resolves X
  ambiently, then get deleted. `ProtocolSeamTests` passes unmodified at every phase.

## Verification

- Per phase: `xcodebuild build-for-testing` + `test-without-building -only-testing:iSubTests` on
  the `iSub Beta` scheme (same as CI); guardrail script passes with lowered baseline.
- Phase 0 characterization tests must pass with unmodified assertions through Phases 2, 4, 5.
- After 5b: run `JukeboxTests` repeatedly (known timing sensitivity) + `JukeboxUITests` locally.
- Manual smoke on the riskiest behaviors after each core slice: gapless track transition,
  resume-where-I-left-off after force-kill, kill-app-mid-download recovery, jukebox mode
  end-to-end (UI tests cover these; OnlinePlayerUITests + OfflineUITests + JukeboxUITests).

## Estimate

~80–95 file-touches across the phase/sub-phase commits (Phase 5c may need two), ~6 new production
files, ~2–3 new test files. Highest regression risk: state restoration semantics (Phase 2), jukebox mode (5b),
stream-handler recovery after restart (Phase 4/5a).

## Critical files

- `Classes/Models/DependencyInjection.swift` — becomes the composition root
- `Classes/Models/Singletons/SavedSettings.swift` — split (Phase 2)
- `Classes/Models/Singletons/PlayQueue.swift`, `Classes/Models/Singletons/Jukebox.swift` — Phase 5
- `Classes/Audio Engine/BassPlayer.swift` — Phase 5c
- `Classes/Models/Stream Handlers/StreamManager.swift`, `DownloadQueue.swift`, `StreamHandler.swift`
  — Phases 4/5a
- `Classes/Main/AppDelegate.swift`, `SceneDelegate.swift` — setup ordering, NetworkStatus
- `Classes/Models/Async Loaders/URLRequest+Subsonic.swift` — Phase 6
- `Tests/iSubTests/Support/{TestContainer,TestSandbox,StoreTestCase,Fakes}.swift` — extend, not replace
