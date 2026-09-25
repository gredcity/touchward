# Architecture Evidence

The current views document the single-process custom runtime at
`db07e1179be5a3a81b0bf7c24e4d2df9bcf1bffb`. The PDF-163 customization retains the upstream
process boundary, adds desktop shortcuts, and makes keyboard construction optional.
Installation and physical acceptance are tracked separately in
[current state](../state.md).

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
