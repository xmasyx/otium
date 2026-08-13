# How it works, in detail

The parts that did not fit in the [README](../README.md) without turning it into a manual: why each
signal has the cap it has, how video is detected, and every command-line flag.

*[Leggi questa pagina in italiano](come-funziona.md).*

---

## Why the terminal gets the shortest leash

Otium believes four different signals that say "somebody is sitting here", and each is believed only
for so long without a single keystroke:

| What you are doing | How it knows | Counts as sitting for up to |
|---|---|---|
| **reading a terminal or an editor** | the frontmost app is a terminal or a code editor: iTerm2, Terminal, Ghostty, Warp, Alacritty, kitty, WezTerm, Hyper, VS Code, Cursor, Xcode, Zed, IntelliJ, Sublime | **5 minutes** |
| reading a document | the frontmost app is a reader, and `lsof` says which `.pdf`/`.docx`/`.md` it holds open | **15 minutes** |
| watching a video | a player **on a fixed list** is producing audio, attributed to the process (nested helpers included) | **45 minutes** |
| on a call | a microphone is in use, or a camera is capturing | **no cap** |
| you left | no signal, no input | not sitting |

A terminal sits in the foreground on its own for hours: an agent grinding away, a build, a log. A
PDF in front of you at least implies somebody opened it to read. "Terminal on, desk empty" is the
easiest of the four false positives to trigger, so it pays the shortest cap.

Past the cap the clock stops, and coming back does not gift you a break you never took: the absence
only counts from the moment the signal expired.

## The call is the one exception, and it never expires

A two-hour meeting without touching the trackpad is the longest sit of the day. If the signal
expired, those two hours would stop counting halfway. Instead of a cap there is a nudge: after
**4 hours** of an open microphone without a single touch, the app says something is holding it open.
It says, it does not block.

## An overdue break arrives bigger

If sitting time has passed **twice** the interval, because you were in a meeting or because you
postponed, what fires is the 5-minute full break rather than the 90-second snack. A whole skipped
cycle is not repaid with ninety seconds.

## Video detection, and the design that cost a field test

The player list is deliberately closed: only browsers and video players count, never any process
that happens to be making noise. Spotify and Music are out, because background music while you are
in the kitchen is not "being at the screen".

The first design read the system assertion *"don't sleep the display"*, the one players raise during
a video. **Chromium browsers don't raise it at all**: with YouTube playing in Brave, the full
assertion list contained only `caffeinate`, `powerd` and WindowServer.

Audio, on the other hand, is always visible. And the thing making the sound is not the browser, it is
a helper nested inside its bundle, which the system does not consider an application, so the
executable path has to be walked up to the outermost `.app`.

To see what it recognises right now:

```bash
/Applications/Otium.app/Contents/MacOS/Otium --presence
```

## Start at login

```bash
/Applications/Otium.app/Contents/MacOS/Otium --install-agent   # registers start at login
/Applications/Otium.app/Contents/MacOS/Otium --agent-status
/Applications/Otium.app/Contents/MacOS/Otium --remove-agent
```

Start at login goes through **`SMAppService`**, the modern route: Otium shows up under *System
Settings → General → Login Items & Extensions → Open at Login*, with its own switch. If you turn it
off there, the app does **not** put it back: it walks you to the switch and stops.

> **Changed on 2026-08-03.** Start at login used to be a hand-written LaunchAgent in
> `~/Library/LaunchAgents`, with `KeepAlive` to restart Otium after a `kill -9`. macOS files that as
> a *legacy agent*: it ended up under "Allow in the Background" instead of among the "Open at Login"
> apps, attributed to "Unknown Developer", and it made the "Background App Activity" notice reappear
> every time the bundle was rebuilt. `KeepAlive` went with it, and the choice is declared: it barred
> the back window while leaving the door open, because "Quit Otium" is a clean exit that triggered
> nothing. The net that remains is warm restore — reopened within the grace window, the app picks the
> count up where it was.
>
> Anyone on the previous version has nothing to do: the old agent is removed on first launch. By
> hand, if needed: `--remove-legacy-agent`. `--doctor` reports it if it survived.

## Seeing the break screen without waiting half an hour

```bash
dist/Otium.app/Contents/MacOS/Otium --demo-break=20        # closes itself after 20 s
dist/Otium.app/Contents/MacOS/Otium --snapshot=out.png     # draws it offscreen
```

The self-close is not a convenience: during the block the app disables Force Quit, so a demo relying
on someone closing it by hand would be the perfect way to leave a Mac nailed shut.

## The block probe

```bash
swift Scripts/probe-blocker.swift    # with the app blocking
```

It calibrates itself by building a window of known size, because `kCGWindowBounds` does not live in
the same coordinate space as `NSScreen.frame`: on a scaled display a 1512×982-point window is listed
as 1362×884, and comparing the raw numbers declares a healthy app broken.

## Diagnostics

`Otium --doctor` runs 12 checks: the data folder, the ledger and its integrity, settings, rotation,
phrase decks, progression, single instance, start at login, leftovers from the old LaunchAgent,
first-run state, and whether the ⌃S shortcut can be registered.

The same report is in the app under **Preferences → Advanced → "Open diagnostics…"**, and it is
attached automatically by **"Report a problem…"** next to it. Paths are shortened to `~` before the
report leaves the app.
