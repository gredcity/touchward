# Touchward runtime recovery

Owner: Edward Vasquez. Updated October 25, 2026.

The installed custom app is `/Applications/Touchward Custom.app` (`com.edward.touchward`).
The original app was removed October 25 at Edward's request; recovery ZIP is in
`/Users/edwardvasquez/Documents/Codex/2026-10-25/why-does-touch-word-continue-to/work/touchward-original-retired-2026-10-25`.
Do not reinstall the original without a new request. Never run both against the board.
Two fingers scroll or pinch/spread to zoom out/in; three fingers switch desktops.
Zoom uses the focused app’s Command + `=` / Command + `-` shortcuts; tap that window
first. Zoom is stepped and rate limited. A committed pinch ends if a contact changes
or fingertips nearly merge; lift every finger before starting another gesture.
On-screen keyboard is disabled.

`com.edward.touchward` launches via LaunchServices and waits for the app. KeepAlive
restarts it after exit with a ten-second minimum launch interval. It also starts at login.
The app retries absent devices, reopens after Mac sleep, and requires verified multitouch
mode when the descriptor declares Input Mode. The controller can fall back to plain mouse
input if Touchward is absent, so one-finger movement does not prove Touchward is working.

## Verify

- `launchctl print gui/$(id -u)/com.edward.touchward` should show the waiting launcher running.
- `pgrep -x 'Touchward Custom'` should return one PID; `pgrep -x Touchward` should return none.
- `tail -60 "$HOME/Library/Logs/Touchward Custom.log"` should show Accessibility and Input
  Monitoring granted, mode 2 confirmed, ten finger slots for this board, and device seizure.
- Test two-finger scrolling, two-finger pinch/spread zoom, and three-finger desktop
  switching physically. For zoom, spread slowly, hold still, pinch inward, then lift one
  finger: zoom should stop with no continued commands. Lift every finger and verify a
  fresh scroll. After a board reconnect or Mac sleep/wake, confirm those gestures again.
  A unit test is not physical proof.

## Update without recurring permission churn

Run `bash scripts/build-app.sh`, then `bash scripts/install.sh` from the repository.
The build must use the configured certificate and fail if it is missing. Do not replace
it with an ad-hoc build. The installer suspends supervision, replaces the bundle, and
reinstalls the supervised login job. Its display mapping remains `TOUCHWARD_DISPLAY_ID=1`.
An expired/replaced signing identity must be reviewed deliberately; current certificate
expiry is June 18, 2027. Confirm the designated requirement before installing.

The October 25 transition from ad-hoc to certificate signing needs one Accessibility
entry refresh. In System Settings → Privacy & Security → Accessibility, remove the old
Touchward Custom entry and add the installed app again, then enable it. Merely toggling
an old entry can retain its stale signature. macOS may require Edward to authenticate.
The app observes the grant and relaunches automatically; verify fresh live log entries.

## Stop or roll back

Boot out the job before quitting/replacing the app:

```sh
launchctl bootout gui/$(id -u)/com.edward.touchward
pkill -TERM -x 'Touchward Custom'
```

Restore the needed preserved bundle and LaunchAgent, then bootstrap the restored plist.
A change back to an older signing requirement can need another permission refresh.
The October 25 backup is in that chat's `work/touchward-backup/`; preserve it until
physical acceptance. Do not reset permissions for unrelated applications.
