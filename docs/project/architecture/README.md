# Architecture Evidence

The current views document the custom runtime at
`58f5137f4d0cd27c018859c0825c03e07ecf3e5d`. The PDF-163 customization retains one owned app
process, uses desktop shortcuts and the native Mission Control app, and makes keyboard
construction optional.
Installation and physical acceptance are tracked separately in
[current state](../state.md).

The October 23 working-tree update changes the recognizer to two-finger scrolling and
exactly-three-finger desktop swipes and Mission Control double-tap. The November 12
1.0.9 update removes the one-finger scroll fallback: one-finger movement drags. The October 25 1.0.5/build 7 repair adds safe deferred
HID removal, wake/reconnect recovery, verified multitouch readiness, stable certificate
signing and login supervision. It passes 154 tests, the release build, and signature
verification; installation, permission persistence and physical acceptance are tracked
in current state. The diagrams' recorded baseline commit remains the historical reference;
the one-process architecture and OS boundaries are unchanged.

The October 25 1.0.6/build 8 update adds two-finger pinch/spread recognition alongside
scrolling, with intent locking and contact reanchoring before commitment. It uses the existing stepped
Command + `=` / Command + `-` zoom transport to the focused app. Three-or-more-finger
pinch and desktop navigation retain their prior mapping.

The 1.0.7/build 10 repair filters small spread changes and requires a larger movement
to reverse zoom. A committed pinch stops on any contact ID/count change or nearly merged
fingertips and remains consumed until full lift. `ZoomStepper` caps transport at one
shortcut per 120 ms, discarding excess whole steps; it schedules no delayed output.
Close-finger scrolling and desktop swipes still work. Physical stability acceptance
is tracked separately in current state.

- [System context](current/context/system-context.md): operator, touch panel, and macOS.
- [Containers](current/structure/containers.md): one app process, local log, and OS APIs.
- [Primary journey](current/journey/primary-journey.md): permission, panel activation, and
  touch interaction.

These are compact Mermaid views with an author check against the repository entry point,
event synthesizer, package definition, and upstream documentation. They are not an independent visual or
hardware acceptance review.

- `current/` records implemented reality verified against a commit.
- `target/` records accepted Jira-scoped destination designs.
- `proposals/` holds unaccepted design options and is never current authority.
- `archive/` holds promoted release snapshots and promotion records.

## Effective Set

Each target explicitly inherits unchanged current views, replaces current views, and introduces new views. The effective target set is the declared inheritance plus its replacement and introduced views.

## Reading Order

Read `index.yaml`, select current or one target effective set, then open only the registered views needed for the question.
