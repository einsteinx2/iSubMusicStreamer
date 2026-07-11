# iSub Development Notes

## Running tests: ALWAYS use a dedicated simulator for this checkout

Multiple Claude sessions often run at once in sibling checkouts of this repo
(iSubMusicStreamer, iSubMusicStreamer-refactor-singletons, ...). If two sessions
run tests against the same simulator, installing the app mid-run SIGKILLs the
other session's test host. The symptoms are "Test crashed with signal kill"
(with no .ips crash report), "Restarting after unexpected exit", or
"Early unexpected exit, operation never finished bootstrapping" — these are
simulator collisions, not code bugs, and they preferentially get blamed on
long-running tests (e.g. the BassAudioEngineTests underrun tests).

Before running any tests, create/boot a simulator dedicated to this checkout and
pass it by UDID. Never use `-destination "platform=iOS Simulator,name=iPhone 17 Pro"`
locally:

```sh
SIM_NAME="iPhone 17 Pro - $(basename "$PWD")"
UDID=$(xcrun simctl list devices | grep -F "$SIM_NAME (" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F-]{27}')
if [ -z "$UDID" ]; then
  RUNTIME=$(xcrun simctl list runtimes | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+' | tail -1)
  UDID=$(xcrun simctl create "$SIM_NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "$RUNTIME")
fi
xcrun simctl bootstatus "$UDID" -b

xcodebuild build-for-testing -project iSub.xcodeproj -scheme "iSub Beta" \
  -destination "platform=iOS Simulator,id=$UDID" -quiet
xcodebuild test-without-building -project iSub.xcodeproj -scheme "iSub Beta" \
  -destination "platform=iOS Simulator,id=$UDID" -only-testing:iSubTests
```

CI (.github/workflows/ci.yml) keeps using the plain "iPhone 17 Pro" device name;
its runners are isolated so collisions cannot happen there.

## Git worktrees: never use bare `git stash`

The sibling checkouts are linked worktrees of one repo, and the stash stack
(refs/stash) is SHARED across all of them. A bare `git stash` / `git stash pop`
in one worktree can pop another session's stash into the wrong worktree (this
has happened). Prefer, in order:

1. A WIP commit instead of a stash — it lives on your branch and other
   worktrees can't touch it:

   ```sh
   git commit -am "WIP: <what and why>"   # ...do the other thing...
   git reset --soft HEAD^                 # restore the working state
   ```

2. If you must stash, always push with this worktree's name in the message and
   only ever pop your own entry by index — never bare `git stash pop`:

   ```sh
   git stash push -m "$(basename "$PWD"): <what>"
   IDX=$(git stash list | grep -F "$(basename "$PWD"):" | head -1 | cut -d: -f1)
   [ -n "$IDX" ] && git stash pop "$IDX"
   ```

Never pop or drop a stash entry whose message names a different checkout.

Notes:

- When piping xcodebuild through grep/tail, check `${pipestatus[1]}` (zsh) for
  the real exit code.
- If tests fail with "Failed to install or launch the test runner …
  Launchd job spawn failed" while the build succeeds, get the real error from
  the simulator log:

  ```sh
  xcrun simctl spawn "$UDID" log show --last 10m \
    --predicate 'eventMessage CONTAINS "spawn"' --style compact
  ```

  `error=163: Security policy issue` means the built app bundle is unsigned —
  confirm with `codesign --verify --deep ".../iSub Beta.app"`. This is stale
  incremental-build state (seen after rewriting project.pbxproj with the ruby
  `xcodeproj` gem, which re-serializes object UUIDs): the build reports success
  but skips the codesign step. Delete this checkout's DerivedData directory
  (each checkout has its own `DerivedData/iSub-<hash>`; match it via
  `info.plist` → `WorkspacePath`) and rebuild. Rebooting or erasing the
  simulator does NOT help, and it is not the shared-simulator collision above.
- Before diagnosing any "signal kill" test failure, check
  `ps aux | grep xcodebuild` for a concurrent run from another checkout, and
  look in `~/Library/Logs/DiagnosticReports/` for real .ips crash reports — a
  genuine crash leaves one; a simulator collision does not.
- Tests must never post hand-crafted system notifications (e.g.
  AVAudioSession.interruptionNotification) to the global NotificationCenter:
  the BASS library's own observers crash on them. Invoke the handler methods
  directly instead (see BassAudioEngineTests).
- SandboxedTestCase registers default fakes for the DI protocol seams
  (PlayerControlling, StreamManaging, DownloadQueueing, SongMetadataDownloading,
  SocialScrobbling) so tests don't reach the app's real singletons through the
  main-container fallback and leak background network work across tests.
  Register a real instance over the fake when a test needs one.
