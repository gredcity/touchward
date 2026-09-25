---
key: containers
type: c4-container
status: current
scope: Touchward local runtime
audience: [engineering, operations]
environment: Local macOS desktop
owner: Edward Vasquez
reviewed_on: 2026-09-25
question: What runs locally and which OS interfaces carry touch input?
verified_commit: db07e1179be5a3a81b0bf7c24e4d2df9bcf1bffb
scope_paths: [Package.swift, Sources/]
satisfies: [ARCH-SCOPE-002, ARCH-VIEW-001, ARCH-REL-001]
elements:
  - {id: panel, name: USB digitizer, type: external-system, technology: USB HID touchscreen, responsibility: Sends contacts described by the device's HID elements.}
  - {id: application, name: Touchward app, type: application, technology: Swift with AppKit and TouchwardCore, responsibility: Reads contacts and translates gestures into input events.}
  - {id: macos, name: macOS input and window services, type: external-system, technology: IOKit and CoreGraphics and Accessibility, responsibility: Supplies permissions and display state and routes synthetic input.}
  - {id: log, name: Local application log, type: data-store, technology: UTF-8 file in Library/Logs, responsibility: Records startup and device and interaction diagnostics.}
relationships:
  - {id: panel-application, source: panel, destination: application, purpose: Supplies decoded contact values., protocol: IOHID callbacks}
  - {id: macos-application, source: macos, destination: application, purpose: Supplies display and focus and permission state., protocol: AppKit and Accessibility and IOKit}
  - {id: application-macos, source: application, destination: macos, purpose: Posts pointer and keyboard input., protocol: CGEvent}
  - {id: application-log, source: application, destination: log, purpose: Appends operational diagnostics., protocol: Foundation file I/O}
boundaries:
  - {id: touchward-system, name: Touchward system, type: system, members: [application, log]}
review:
  reviewer: Codex author check
  reviewed_on: 2026-09-25
  result: pass
  checks: [ARCH-SCOPE-002, ARCH-VIEW-001, ARCH-REL-001]
---

# Touchward Containers

```mermaid
C4Container
    title Touchward - Local Containers
    System_Ext(panel, "USB digitizer", "HID touchscreen contact reports")
    System_Ext(macos, "macOS services", "Display, permissions, focus and input routing")
    System_Boundary(touchward_system, "Touchward system") {
        Container(application, "Touchward app", "Swift / AppKit", "Reads contacts and translates gestures")
        ContainerDb(log, "Application log", "Local UTF-8 file", "Records operational diagnostics")
    }
    Rel(panel, application, "Supplies contacts", "IOHID callbacks")
    Rel(macos, application, "Supplies OS state", "AppKit / Accessibility / IOKit")
    Rel(application, macos, "Posts input", "CGEvent")
    Rel(application, log, "Appends diagnostics", "Foundation file I/O")
```

## Scope

There is one app process and one diagnostic file, with no separately deployed service.
`TouchwardCore` is a library linked into that process, not another container. When enabled,
the app's keyboard panel is also part of that process. `main.swift` reads the local
`OnScreenKeyboardEnabled` UserDefaults preference and skips keyboard construction when
false. The package definition and `main.swift` establish these boundaries at the verified
commit. Desktop swipes post Control-arrow key events through the same event synthesizer.

## Legend

The system boundary encloses the app and its local log. The cylinder is a local file, not
a database service. External boxes are the touch hardware and macOS APIs. Directed arrows
name the exchanged information or action.

## Assumptions

One Touchward process owns the selected digitizer. Local UserDefaults supplies the
keyboard preference, whose default is true. App bundle identity and installation state
are recorded separately in current state.

## Open Questions

Custom-build signing, Accessibility grant, and physical acceptance must be verified during
installation. This view establishes the runtime boundary rather than those outcomes.

## Accessible Description

The digitizer streams touch values to one Swift app. macOS supplies display, permission,
and focus information. The app posts input events back to macOS and writes diagnostics to
a local log file. Pure gesture logic and the optional on-screen keyboard execute inside
the same app process; the disabled preference prevents keyboard construction.
