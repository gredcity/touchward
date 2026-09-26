---
key: primary-journey
type: journey
status: current
scope: Operator starts Touchward and controls a visible Mac window
audience: [operator, engineering]
environment: Local macOS desktop
owner: Edward Vasquez
reviewed_on: 2026-09-26
question: What must happen before a touch produces input in the intended window?
verified_commit: 58f5137f4d0cd27c018859c0825c03e07ecf3e5d
scope_paths: [Sources/touchward/main.swift, Sources/touchward/EventSynthesizer.swift]
satisfies: [ARCH-SCOPE-JOURNEY-001, ARCH-VIEW-001, ARCH-REL-001]
elements:
  - {id: operator, name: Operator, type: person, technology: Human, responsibility: Launches the app and grants access and touches the board.}
  - {id: application, name: Touchward app, type: application, technology: Swift macOS app, responsibility: Waits for access and a usable display before processing touch.}
  - {id: macos, name: macOS desktop, type: external-system, technology: Accessibility and input services, responsibility: Enforces permission and routes input to application windows.}
relationships:
  - {id: operator-application, source: operator, destination: application, purpose: Starts touch control and supplies gestures., protocol: App launch and USB touch}
  - {id: operator-macos, source: operator, destination: macos, purpose: Grants access and observes window response., protocol: System Settings and display}
  - {id: application-macos, source: application, destination: macos, purpose: Posts input or opens Mission Control after readiness checks., protocol: CGEvent and NSWorkspace}
boundaries:
  - {id: touchward-system, name: Touchward system, type: system, members: [application]}
review:
  reviewer: Codex author check
  reviewed_on: 2026-09-26
  result: pass
  checks: [ARCH-SCOPE-JOURNEY-001, ARCH-VIEW-001, ARCH-REL-001]
---

# Touchward Primary Journey

```mermaid
flowchart TD
    launch[Operator starts Touchward] --> permission{macOS access granted?}
    permission -->|No| settings[Operator grants Accessibility access]
    settings --> relaunch[App relaunches to refresh HID access]
    relaunch --> permission
    permission -->|Yes| display{Touch display and digitizer usable?}
    display -->|No| wait[App waits for display or device activation]
    wait --> display
    display -->|Yes| touch[Operator touches the intended window]
    touch --> input[App posts input or opens Mission Control]
    input --> result[Operator observes the window response]
    result --> touch
```

## Scope

The custom app's activation and interaction path, checked against `main.swift` and
`EventSynthesizer.swift`. With the keyboard preference disabled, focusing a text field
does not construct or show the panel; the physical keyboard remains available. Desktop
swipes use macOS Control-arrow shortcuts; two-finger double-tap opens the native Mission
Control app. This is a user journey, not a detailed gesture algorithm or a claim of
hardware acceptance.

## Legend

Rectangles are operator or app actions; diamonds are readiness checks. Arrow labels name
the branch taken. A return arrow means the app continues waiting or processing.

## Assumptions

The Mac already displays the intended window on the panel. The app has selected the
correct display. The operator can use the physical keyboard while touch is being set up.

## Open Questions

Edward confirmed baseline upstream two-finger scrolling. The installed 1.0.2 mapping now
uses one-finger scrolling, two-finger desktop navigation, and double-tap Mission Control.
Its replacement binary is waiting for renewed Accessibility permission, despite the
earlier 1.0.1 grant. The complete interaction path and disabled-keyboard behavior still
require physical acceptance after access is restored.

## Accessible Description

The operator starts the app. If permission is missing, macOS settings and an app relaunch
establish access. The app then waits for a usable display and digitizer. Touches produce
input in macOS, and the operator verifies the visible response. A working process alone
does not establish that the desired gesture feels or behaves correctly.
