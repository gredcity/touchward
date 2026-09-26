# Project Charter

## Purpose

Keep Edward's LG CreateBoard usable as a Mac touchscreen with free, open-source software
and his existing Bluetooth keyboard.

## Outcomes

- Follow Edward's approved Magic Mouse finger counts: one finger scrolls naturally in
  both axes; exactly two fingers swipe left to the next macOS desktop/full-screen app or
  right to the previous one, once until every finger lifts.
- Keep one-finger tap to click. Holding at least 0.6 seconds before movement starts a
  drag; holding and lifting instead performs a right-click.
- Map a two-finger double-tap to Mission Control. Preserve zoom through three-or-more
  finger pinch/spread.
- Prevent automatic on-screen keyboard presentation when the custom app's
  `OnScreenKeyboardEnabled` preference is false.
- Keep one-finger horizontal motion as content scrolling; do not add browser page-back
  or page-forward shortcuts.
- Keep the original app available for rollback. Automated tests support, but do not
  replace, Edward's physical acceptance on the board.

## Scope

The scope is a local macOS user-space customization of
[Touchward](https://github.com/nguyenthienthanh/touchward), tracked by
[PDF-163](https://grandrapidscitygym.atlassian.net/browse/PDF-163). It does not include paid
drivers, trials, kernel extensions, reduced macOS security, a general gesture editor, or
certification of other hardware. Preserve upstream attribution and the Apache-2.0 license.
