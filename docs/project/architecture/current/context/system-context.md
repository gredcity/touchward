---
key: system-context
type: c4-context
status: current
scope: Touchward on the operator's Mac
audience: [operator, engineering]
environment: Local macOS desktop
owner: Edward Vasquez
reviewed_on: 2026-09-26
question: How does a USB touch panel control macOS through Touchward?
verified_commit: 58f5137f4d0cd27c018859c0825c03e07ecf3e5d
scope_paths: [Package.swift, Sources/]
satisfies: [ARCH-SCOPE-001, ARCH-VIEW-001, ARCH-REL-001]
elements:
  - {id: operator, name: Operator, type: person, technology: Human, responsibility: Uses the touchscreen and physical keyboard.}
  - {id: panel, name: USB touch panel, type: external-system, technology: USB HID digitizer and display, responsibility: Reports finger contacts and displays the Mac desktop.}
  - {id: touchward, name: Touchward, type: software-system, technology: Swift macOS app, responsibility: Translates touch contacts into macOS input events.}
  - {id: macos, name: macOS desktop, type: external-system, technology: macOS input and display services and Mission Control, responsibility: Routes input and presents windows and desktop navigation.}
relationships:
  - {id: operator-panel, source: operator, destination: panel, purpose: Touches visible controls., protocol: Physical touch}
  - {id: panel-touchward, source: panel, destination: touchward, purpose: Supplies contact reports., protocol: USB HID through IOKit}
  - {id: touchward-macos, source: touchward, destination: macos, purpose: Posts input and opens Mission Control., protocol: CoreGraphics and NSWorkspace}
  - {id: macos-panel, source: macos, destination: panel, purpose: Presents the desktop picture., protocol: Display connection}
  - {id: operator-macos, source: operator, destination: macos, purpose: Types and uses physical input devices directly., protocol: Native macOS input}
boundaries:
  - {id: touchward-system, name: Touchward system, type: system, members: [touchward]}
review:
  reviewer: Codex author check
  reviewed_on: 2026-09-26
  result: pass
  checks: [ARCH-SCOPE-001, ARCH-VIEW-001, ARCH-REL-001]
---

# Touchward System Context

```mermaid
C4Context
    title Touchward - Local System Context
    Person(operator, "Operator", "Uses touch and a physical keyboard")
    System_Ext(panel, "USB touch panel", "Reports finger contacts and displays the desktop")
    System_Boundary(touchward_system, "Touchward system") {
        System(touchward, "Touchward", "Translates contacts into macOS input")
    }
    System_Ext(macos, "macOS desktop", "Routes input and presents windows and Mission Control")
    Rel(operator, panel, "Touches controls", "Physical touch")
    Rel(panel, touchward, "Supplies contacts", "USB HID / IOKit")
    Rel(touchward, macos, "Posts input and opens Mission Control", "CoreGraphics / NSWorkspace")
    Rel(macos, panel, "Presents picture", "Display connection")
    Rel(operator, macos, "Uses physical input", "Native macOS input")
```

## Scope

The custom Touchward system and its direct interactions. Internal Swift types belong
below this level. The author check uses the package definition, application entry point,
event synthesizer, and upstream documentation. Two-finger desktop navigation posts
Control-arrow shortcuts through the input path. Two-finger double-tap opens the native
Mission Control app through `NSWorkspace`.

## Legend

The boundary encloses the software under review. External systems and the operator sit
outside it. Arrows name the purpose and mechanism of each interaction.

## Assumptions

macOS already presents a picture on the panel. The app has the required Accessibility and
HID access. The physical mouse and keyboard retain their native input path.

## Open Questions

The runtime topology is established. Physical acceptance of PDF-163's new gesture and
keyboard behavior is pending and is not certified by this view.

## Accessible Description

The operator touches the panel. Its HID digitizer sends contacts to Touchward, which posts
macOS input events or opens Mission Control. macOS displays the resulting windows on the
panel. The operator's physical keyboard and mouse reach macOS directly.
