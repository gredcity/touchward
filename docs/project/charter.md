# Project Charter

## Purpose

Keep Edward's LG CreateBoard usable as a Mac touchscreen with free, open-source software
and his existing Bluetooth keyboard.

## Outcomes

- Preserve the two-finger scrolling Edward has confirmed on the upstream app.
- Add exactly-three-finger horizontal swipes: left advances to the next macOS desktop or
  full-screen app; right returns to the previous one.
- Prevent automatic on-screen keyboard presentation when the custom app's
  `OnScreenKeyboardEnabled` preference is false.
- Preserve tap, drag, two-finger scrolling, and three-finger pinch/spread behavior.
- Keep the original app available for rollback. Automated tests support, but do not
  replace, Edward's physical acceptance on the board.

## Scope

The scope is a local macOS user-space customization of
[Touchward](https://github.com/nguyenthienthanh/touchward), tracked by
[PDF-163](https://grandrapidscitygym.atlassian.net/browse/PDF-163). It does not include paid
drivers, trials, kernel extensions, reduced macOS security, a general gesture editor, or
certification of other hardware. Preserve upstream attribution and the Apache-2.0 license.
