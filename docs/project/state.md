---
lifecycle: build
updated_on: 2026-09-25
---

# Current State

## Material Reality

- The baseline is upstream Touchward 1.0.0. This fork starts from
  `e648c2093c964d94b387bf195f114d5fa07b9e50`; the baseline suite has 96 passing tests.
- Edward confirmed two-finger scrolling on the LG CreateBoard connected to his M1 Max
  Mac Studio running macOS 26.3. USB identifies its controller as CVTE `1ff7:0f27`.
- [PDF-163](https://grandrapidscitygym.atlassian.net/browse/PDF-163) implements three-finger
  desktop navigation and an on-screen keyboard preference. The custom build is installed;
  its Accessibility grant and physical acceptance remain pending.
- `/Applications/Touchward Custom.app` is bundle `com.edward.touchward`, version
  1.0.1/build 2. Its installed executable matches the build, with SHA-256
  `5a5af5a774935b2a3f24e3b34aae3e4bb5dc703c98ce73619f2eaba0c74cf99e`.
  Its ad-hoc signature passes `codesign --verify --deep --strict`.
- The custom app's user preference is `OnScreenKeyboardEnabled=false`. The existing
  `com.edward.touchward` user LaunchAgent now launches only the custom app with
  `TOUCHWARD_DISPLAY_ID=1`; `/Applications/Touchward.app` is retained for rollback.
- The original LaunchAgent is backed up at
  `/Users/edwardvasquez/Documents/Codex/2026-09-25/i-h/work/touch-setup/com.edward.touchward.original.plist`.
- The full suite passes 119 tests with zero failures, and the release build succeeds.
  The installed app's log still reports Accessibility not granted; those build and test
  results do not prove touchscreen operation.
- The [current architecture](architecture/README.md) is checked against custom code commit
  `db07e1179be5a3a81b0bf7c24e4d2df9bcf1bffb`, including the optional keyboard and desktop
  shortcuts in the existing app process. It does not claim physical acceptance.

## Decisions in Force

- Use free software without a trial or later licence requirement.
- Three fingers left means next desktop/full-screen app; three fingers right means
  previous. Keep two-finger scrolling and three-finger pinch/spread.
- Disable automatic keyboard presentation for Edward's Bluetooth keyboard setup through
  the custom app's preference; leave upstream defaults available for other users.
- Preserve `/Applications/Touchward.app`. Rollback stops the custom app and restores the
  existing LaunchAgent to the original app path; never run both against the same panel.

## Active Risks

- macOS Accessibility permission is tied to app identity. A custom identity can require a
  separate grant before it can read touch input or post events. The installed custom app
  is currently waiting for this grant.
- Desktop changes require the corresponding macOS Mission Control shortcuts. Hardware
  testing must confirm swipe direction, one change per gesture, preserved scrolling and
  pinch, and no automatic keyboard when focusing a text field.
- Automated gesture tests cannot establish physical usability. Edward's test remains the
  acceptance gate; Jira is the live work queue.
- Existing host checks are separate from this app's checks: context-rule parity passes,
  while context drift reports zero host hook counts and installed Project Standard 1.3.1
  versus the global 1.1.0 pin. This task has not changed that pre-existing host drift.
