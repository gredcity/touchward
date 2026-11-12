---
lifecycle: build
updated_on: 2026-11-12
---

# Current State

## November 12 one-finger drag

- Edward could not drag windows: one-finger movement scrolled (moving the pointer with
  the finger) unless he first held still 0.6 s. He chose mouse-style drag.
- Version 1.0.9/build 12: one-finger movement past 10 pt presses the left button and
  drags immediately; the one-finger scroll state is removed, so scrolling is two fingers
  only. Tap click, hold-and-lift right-click, and all multi-finger gestures are unchanged.
  A replaced contact ID before movement ends the gesture without pressing.
- 182 Swift tests pass; the new drag tests failed before the fix. Installed 09:37 UTC with
  both permissions granted and device seized; installed and built CDHash match
  `b95a480f4f757fdac973e8b8fe6dcde7f4c3f067`. Prior 1.0.8 bundle and LaunchAgent are in
  `~/Projects/touchward/backups/touchward-1.0.8-before-one-finger-drag/`.
  Physical acceptance pending.

## November 12 cursor recentring repair

- Edward reported the mouse repeatedly jumping to screen centre. Root cause: the
  CreateBoard is display 1 and the only, main display, but `CursorReturn` warped the
  pointer to the main display's centre ~0.5–1.5 s after every touch lift. It was built
  for a secondary touch panel and had no single-display guard.
- Version 1.0.8/build 11: `TouchPipeline.cursorReturnTarget` returns nil when the touch
  display is the main display, so no return is armed; a display change into that layout
  cancels any queued return. Secondary-panel behaviour is unchanged.
- 183 Swift tests pass; the new `CursorReturnTargetTests` failed before the fix.
  Installed 09:21 UTC with both permissions still granted and device seized; installed
  and built executable SHA-256 match:
  `4b1df61b09cb1cf1abf10dfb6e13765c1863fa40435bf48a9a6f0d36f63ec7e1`.
  Prior 1.0.7 bundle and LaunchAgent are in
  `~/Projects/touchward/backups/touchward-1.0.7-before-recentre-fix/`.
  Physical acceptance pending. Committed on `hotfix/no-recentre-single-display`.

## October 25 pinch stability repair

- Edward initially confirmed both zoom directions on 1.0.6, then reported unstable
  in/out oscillation and difficulty stopping. Stable pinch acceptance is withdrawn.
  Tests reproduced alternating zoom from small reversals and extreme ratios when
  fingertips nearly merge. These are code-level reproductions, not a captured physical
  trace of Edward's failing gesture.
- Version 1.0.7/build 10 filters small spread changes and requires a larger movement to
  reverse a committed pinch. Contact ID/count changes and nearly merged fingertips
  stop the pinch until all fingers lift. Intent detection retains close-finger scrolling
  and three-finger desktop swipes.
- `ZoomStepper` emits at most one Command zoom shortcut per 120 ms and drops excess
  whole steps rather than queuing them. Full lift clears the accumulated partial step.
  Bounded diagnostics record contact changes, pinch ratios and shortcut directions.
- All 181 Swift tests pass. Jitter, nearly merged contacts, contact loss, shortcut bursts
  and close-finger pan regression tests were observed failing before their fixes.
  Release build and strict signing pass; the candidate designated requirement matches
  the installed app. Physical stability acceptance remains pending.
- Installed at 00:03:01 UTC October 26 (October 25 local). Both permissions remain
  granted; fresh startup confirms Input Mode 2, ten slots and exclusive device seizure.
  One Custom process runs under the KeepAlive login job. Original app remains absent.
  Strict signature verification passes and installed/release executable SHA-256 matches:
  `57fd8f2c74badb5c5e9024783cb50f45d6a7d2969129f2733799f19e95ace1ff`.
  Scoped independent review has no remaining findings; Project Standard fast check passes.
  The prior 1.0.6/build 8 bundle is preserved in this chat's
  `work/touchward-before-zoom-repair/`. All source changes remain local and uncommitted.

## October 25 two-finger zoom (initial release)

- Edward requested pinch-in and spread-out zoom. Version 1.0.6/build 8 adds standard
  two-finger zoom alongside two-finger scrolling; the first clear motion selects one
  intent for the touch session. Pinch cancels Mission Control taps. Lost/replaced contacts
  and zero separation initially reanchored without a zoom jump; lifting fingers did not
  click. The stability repair above supersedes committed-pinch reanchoring.
- Three-or-more-finger zoom and exactly-three-finger desktop swipes are retained.
  Zoom uses the existing stepped Command + `=` / Command + `-` shortcuts in the focused
  app, which must support those shortcuts. Tap that window before zooming.
- All 166 Swift tests pass, including 12 two-finger zoom tests. Missing pinch output,
  the stationary-finger case, and pinch-to-third-contact desktop switching were each
  observed failing before their fixes. The existing tap-cancellation test now expects
  zoom output while retaining its Mission Control assertions. Independent scoped review
  has no remaining material findings. Release build and strict signature checks pass.
- Installed 1.0.6/build 8 at 23:16:21 UTC with the same designated signing requirement.
  Both Accessibility and Input Monitoring remained granted without another approval;
  live startup confirms Input Mode 2, ten contacts and device seizure. One Custom process
  is supervised by the KeepAlive login job; no original app is installed or running.
  Installed/release executable SHA-256:
  `9ca2f17c1b58994b7de14d1d223502dfaf5816370d681eea4db6bdab31ea3567`.
- Edward initially confirmed both zoom directions on 1.0.6/build 8, then reported
  unstable in/out oscillation; this is not current stability acceptance.
  Prior 1.0.5/build 7 bundle and login plist are retained in this chat workspace under
  `work/touchward-before-two-finger-zoom/`. Source changes remain local and uncommitted.

## October 25 reliability repair

- The app was absent and `com.edward.touchward` had exited. Its LaunchAgent had
  `RunAtLoad` but no `KeepAlive`. The October 23 crash report records an unfair-lock
  abort in `__IOHIDManagerDeviceRemoved`; the app called `stop()` synchronously from
  the manager's removal callback. This is the identified disconnect crash path.
- Version 1.0.5/build 7 defers removal teardown until the callback returns and scopes it
  to the session generation. Startup failures release partial sessions and reconnects
  reset cached contact/descriptor/mode state. Sleep deactivates the device, wake opens
  it again, and an unverified declared Input Mode leaves activation dormant for its
  existing 3.2-second retry instead of accepting single-contact mode permanently.
- The installer now owns a `KeepAlive` LaunchAgent using LaunchServices `open --wait-apps`
  and a ten-second throttle. A controlled SIGTERM changed PID 74203 to 74757 without
  manual relaunch. Only the display selection is copied from previous launch arguments.
- Builds now use the existing `Apple Development: EDWARD VASQUEZ (DXNW232RR6)` identity
  (certificate expires June 18, 2027). Missing identity fails the build instead of
  silently falling back to ad-hoc signing. The designated requirement no longer includes
  a changing executable hash. This supersedes the ad-hoc signing risks below.
- 154 Swift tests pass, including two removal lifecycle tests each observed failing
  before its fix. Release build, strict code-signature validation, shell syntax,
  Project Standard fast checks, and scoped independent review pass. The installed
  executable and release artifact both have SHA-256
  `0556116640b47c4e1c7d9cd00488687418a5aecaa16af305d122079f1c44bf47`.
- The native authentication completed and the stale Accessibility entry was replaced
  with the installed app. At 23:09:58 UTC, the app automatically relaunched and reported
  both permissions granted, Input Mode 2, ten slots and exclusive seizure. A second
  replacement (build 6 → build 7, changed code-signature hash) at 23:10:20 UTC preserved
  the same designated requirement and both permissions without another approval. The
  installed build is running under supervision; no original Touchward process is running.
- Edward confirmed both two-finger scrolling and three-finger left/right desktop swipes
  work on 1.0.5. Sleep/wake and unplug/replug have not been physically reaccepted on
  1.0.5; do not infer those lifecycle outcomes from unit tests or startup logs.
- The prior 1.0.4 bundle and LaunchAgent are preserved in the October 25 chat workspace
  under `work/touchward-backup/`. Preexisting uncommitted gesture changes were retained.
- Edward then explicitly requested removal of the non-custom app. Original
  `/Applications/Touchward.app` was removed, its permissions revoked, and its LaunchServices
  registration removed. It had no running process or independent startup job. The verified
  recovery ZIP and original log are in `/Users/edwardvasquez/Documents/Codex/2026-10-25/why-does-touch-word-continue-to/work/touchward-original-retired-2026-10-25`. Custom remains installed and supervised.

## October 23 history

- On October 23, the installed 1.0.2/build 3 app was running but blocked: its Accessibility
  entry authorized an older executable signature. Removing the stale entry and adding
  `/Applications/Touchward Custom.app` restored Accessibility and Input Monitoring.
  Live logs confirmed multitouch, ten contact slots, and device seizure. Edward confirmed
  one-finger scrolling worked. The original Touchward app was stopped throughout.
- Edward then requested two-finger scrolling and three-finger desktop switching.
  Version 1.0.3/build 4 implements that mapping and preserves the existing one-finger
  scroll fallback, tap/hold controls, two-finger double-tap Mission Control, and pinch.
- Edward confirmed two-finger scrolling on 1.0.3/build 4, but desktop switching did not
  work despite left/right recognition in the log. macOS shortcuts were enabled and
  Edward confirmed physical Control-arrows switch desktops. The generated private-source
  key events were the remaining failure path.
- Version 1.0.4/build 5 keeps the mapping and corrects desktop transport: HID system-state
  source, Control plus secondary-Fn on both arrow edges, posted at the HID tap. Ordinary
  zoom shortcuts retain their existing private source. A construction-only system test
  checks both directions, event edges, source, flags, and event markers without posting.
- The candidate passes 152 Swift tests (zero failures), the release build, strict
  signature verification, and Project Standard checks. An independent code review found
  no remaining defect. The update is installed at `/Applications/Touchward Custom.app`;
  Accessibility was renewed, both permissions are granted, and live logs confirm ten
  contact slots and touch-device seizure. Edward then confirmed both two-finger scrolling
  and three-finger left/right desktop switching work on the physical board.
  Its installed executable matches the release build with SHA-256
  `52d6508166c507cab9d71c898e63af6b7969eada048365ebfa63e4d7a526d775`.
  The 1.0.2 and 1.0.3 bundles are preserved under this chat workspace at
  `work/touchward-rollback/`.
- The custom app remains `com.edward.touchward`; its preference is
  `OnScreenKeyboardEnabled=false`. The login LaunchAgent launches only Custom with
  `TOUCHWARD_DISPLAY_ID=1`. The wrapper was reattached after permission relaunch; exactly
  one Custom executable and no original executable are running. The original
  `/Applications/Touchward.app` remains a fallback.
- Builds use ad-hoc signatures, so replacing the executable changes the designated
  requirement. Refresh Accessibility by removing the old Custom entry and re-adding the
  installed app; an off/on toggle alone can retain the old signature.
- No Jira status change or physical desktop-switching acceptance is implied by automated
  tests. [PDF-163](https://grandrapidscitygym.atlassian.net/browse/PDF-163) is the live queue.

## Decisions in Force

- Use free software without a trial or later licence requirement.
- Two fingers scroll naturally in both axes; a two-finger horizontal pan never switches
  desktops. One finger never scrolls (November 12). One-finger tap clicks, movement
  drags immediately, and holding at least 0.6 seconds then lifting right-clicks.
- Exactly three fingers swiping left means next desktop/full-screen app; right means
  previous. Fire once until every finger lifts. A two-finger double-tap opens Mission
  Control. Two or more fingers support pinch/spread zoom, separated from scrolling or horizontal pan
  by gesture intent. A fourth contact prevents desktop switching until full lift.
- Reanchor undecided gestures when contact IDs change or a finger drops out. A committed
  pinch stops until full lift on contact changes or nearly merged fingertips. Trailing
  fingers never turn a completed swipe into scrolling or a stray click.
- Disable automatic keyboard presentation for Edward's physical-keyboard setup.
- As requested October 25, keep only Custom installed. The original is retired to its
  recovery ZIP; do not restore it or its old startup configuration without a new request.

## Remaining verification

- Physical pinch stability on 1.0.7/build 10: hold still without oscillation, stop on
  finger lift, and start a fresh scroll after full lift.
- A sleep/wake or board power/reconnect cycle remains for physical lifecycle acceptance.
  Edward confirmed both gesture types on 1.0.5; live startup, automatic restart, and
  permission persistence across replacement are verified.

## October 23 risks (historical)

- Each replacement ad-hoc-signed build needs renewed Accessibility permission; verify
  granted Accessibility/Input Monitoring and touch activation in the live app log.
- Desktop changes require macOS Control-arrow shortcuts and at least two Spaces.
- Edward accepted two-finger scrolling and three-finger left/right desktop switching on
  1.0.4. Automated tests cover the other gesture invariants, but pinch, double-tap Mission
  Control, tap/hold controls, and no automatic keyboard were not reaccepted physically
  during this mapping change.
