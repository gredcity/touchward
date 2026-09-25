# Touchward Project Control Panel

- Project ID: `touchward`
- Repository role: `primary`
- Primary repository: `gredcity/touchward`
- Owner: Edward Vasquez
- Jira authority: `PDF`
- Standard: `gredcity/project-repo-standard@1.3.1`
- Active work: [PDF-163](https://grandrapidscitygym.atlassian.net/browse/PDF-163)
- Upstream: [nguyenthienthanh/touchward](https://github.com/nguyenthienthanh/touchward), Apache-2.0

This fork keeps Edward's LG CreateBoard usable with free software on macOS. The current
change adds three-finger desktop navigation and a preference to disable the on-screen
keyboard. The original installation remains the rollback; custom-build physical
acceptance is recorded in [current state](docs/project/state.md).

## Reading Order

1. Read `project.yaml` for machine-enforced identity and risk declarations.
2. Read `docs/project/state.md` when this is the primary repository.
3. Read `docs/project/architecture/README.md` for authored architecture.
4. Use Jira for live work status.

## First Commands

```bash
project-standard doctor --root .
project-standard admission --root .
project-standard check --mode fast --root .
```
