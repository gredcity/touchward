# Architecture Evidence

The current views document the custom runtime at
`58f5137f4d0cd27c018859c0825c03e07ecf3e5d`. The PDF-163 customization retains one owned app
process, uses desktop shortcuts and the native Mission Control app, and makes keyboard
construction optional.
Installation and physical acceptance are tracked separately in
[current state](../state.md).

The installed 1.0.2/build 3 assigns scrolling and desktop gestures to Magic Mouse finger
counts and opens Mission Control on a two-finger double-tap. Its 140 tests, release build,
and signature verification pass. The replacement binary is waiting for renewed
Accessibility permission and physical acceptance.

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
