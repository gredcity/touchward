---
lifecycle: build
updated_on: 2026-09-26
---

# Current State

## Material Reality

- The baseline is upstream Touchward 1.0.0. This fork starts from
  `e648c2093c964d94b387bf195f114d5fa07b9e50`; the baseline suite has 96 passing tests.
- Edward confirmed two-finger scrolling on the LG CreateBoard connected to his M1 Max
  Mac Studio running macOS 26.3. USB identifies its controller as CVTE `1ff7:0f27`.
- [PDF-163](https://grandrapidscitygym.atlassian.net/browse/PDF-163) now follows Edward's
  explicit choice to copy Magic Mouse finger counts. Version 1.0.2/build 3 is installed
  with the approved mapping below. Its renewed permission and physical acceptance remain
  pending.
- `/Applications/Touchward Custom.app` is bundle `com.edward.touchward`, version
  1.0.2/build 3 at the latest recorded installation check. Its installed executable
  matches the build, with SHA-256
  `2a87afb3e144d57cc837823e91981a52edf8b57789809b3b0a6ff628bd2ee671`.
  Its ad-hoc signature passes `codesign --verify --deep --strict`.
- The custom app's user preference is `OnScreenKeyboardEnabled=false`. The existing
  `com.edward.touchward` user LaunchAgent now launches only the custom app with
  `TOUCHWARD_DISPLAY_ID=1`; `/Applications/Touchward.app` is retained for rollback.
- The original LaunchAgent is backed up at
  `/Users/edwardvasquez/Documents/Codex/2026-09-25/i-h/work/touch-setup/com.edward.touchward.original.plist`.
- Version 1.0.2 passes all 140 tests and the release build. Its startup log at
  `2026-09-26T18:10:06Z` records Accessibility not granted and Input Monitoring denied;
  it still waits at `18:12:36Z`. The permission toggle request is already pending with
  Edward. Version 1.0.1 had access at `17:55:30Z`, but that does not establish the
  replacement binary's access.
- Exactly two desktops exist (IDs `3` and `22`), and opening the native Mission Control
  app has been verified. The new double-tap output opens `com.apple.exposelauncher` through
  `NSWorkspace`. The touch pipeline now forwards session-end events to reset scroll
  residuals. Recognizer logs, automated tests, and direct app opening do not prove the
  full physical gesture path; human acceptance remains unverified.
- The [current architecture](architecture/README.md) is checked against custom code commit
  `58f5137f4d0cd27c018859c0825c03e07ecf3e5d`, including the optional keyboard, desktop
  shortcuts, native Mission Control launch, and session-end forwarding. It does not
  claim physical acceptance.

## Decisions in Force

- Use free software without a trial or later licence requirement.
- One finger scrolls naturally in both axes, and a one-finger tap clicks. Hold at least
  0.6 seconds, then move to drag; hold then lift to right-click.
- Exactly two fingers swiping left means next desktop/full-screen app; right means
  previous. Fire once until every finger lifts. A two-finger double-tap opens Mission
  Control. Three or more fingers retain pinch/spread zoom.
- One-finger horizontal movement scrolls content. No browser page-back or page-forward
  shortcuts are added. These decisions supersede the prior two-finger scroll and
  three-finger desktop-navigation mapping.
- Disable automatic keyboard presentation for Edward's Bluetooth keyboard setup through
  the custom app's preference; leave upstream defaults available for other users.
- Preserve `/Applications/Touchward.app`. Rollback stops the custom app and restores the
  existing LaunchAgent to the original app path; never run both against the same panel.

## Active Risks

- macOS Accessibility permission is tied to app identity. The installed 1.0.2 replacement
  reports access denied despite 1.0.1's earlier grant. Renew the permission and verify the
  live startup state before accepting touchscreen behavior.
- Desktop changes require the corresponding macOS Mission Control shortcuts. Hardware
  testing must confirm one-finger scroll in both axes, tap and hold behaviors, two-finger
  swipe direction and one change per full lift, double-tap Mission Control, pinch, and no
  automatic keyboard when focusing a text field.
- Automated gesture tests cannot establish physical usability. Edward's test remains the
  acceptance gate; Jira is the live work queue.
- Existing host checks are separate from this app's checks: context-rule parity passes,
  while context drift reports zero host hook counts and installed Project Standard 1.3.1
  versus the global 1.1.0 pin. This task has not changed that pre-existing host drift.
