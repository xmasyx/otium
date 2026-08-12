<div align="center">
  <img src="docs/icon.png" width="180" height="180" alt="Otium icon: the number 30 in sage green on night green, with otium cum dignitate beneath it">
  <h1>Otium</h1>
  <p><strong>A macOS app that counts your <em>active</em> time at the Mac and, at intervals the literature picked, covers the screen until you have done a bodyweight exercise.</strong></p>
</div>

<p align="center">
  <a href="https://github.com/xmasyx/otium/releases/latest"><img src="https://img.shields.io/github/v/release/xmasyx/otium?style=flat-square&color=2F5C8A" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2015%2B-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/permissions-none-2F5C8A?style=flat-square" alt="No system permissions">
  <img src="https://img.shields.io/badge/network-none-2F5C8A?style=flat-square" alt="No network">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial-green?style=flat-square" alt="PolyForm Noncommercial"></a>
</p>

No camera. No subscription. No network. No system permissions.

```
30 min of active work  →  90 s   ·  8-15 squats or push-ups
30 min                 →  90 s   ·  a different exercise
30 min                 →  5 min  ·  a vigorous bout + 3 minutes away from the screen
```

<div align="center">
  <img src="docs/break.png" width="820" alt="The break screen: 11 crunches, the cue, four alternatives, the countdown, and at the bottom the study the interval comes from">
</div>

The line at the bottom of that screenshot is the point of the whole app: every number shows the
study it comes from, **while** it interrupts you.

---

## Where the numbers come from

Competing apps call themselves *science-backed* without citing a single source. This one puts the
citation on the screen that is blocking you.

| Parameter | Where it comes from |
|---|---|
| **A break every 30 minutes** | [Duran et al. 2023](https://www.cuimc.columbia.edu/news/rx-prolonged-sitting-five-minute-stroll-every-half-hour) — a randomised crossover of four doses: only "5 minutes every 30" flattened the glucose spikes (−58%). Smaller doses lower blood pressure but not glucose. |
| **Strength work, not a walk** | [Gao, Li, Finni & Pesola 2024](https://onlinelibrary.wiley.com/doi/abs/10.1111/sms.14628) — 3 minutes of squats every 45' beat a single 30' walk, with roughly twice the glycaemic benefit. What counts is muscle activation, not steps. |
| **The 5-minute full break** | [Galinsky et al. 2000](https://pubmed.ncbi.nlm.nih.gov/10877480/) (plus the 2007 follow-up) — 5 extra minutes of break per hour reduce musculoskeletal discomfort and eye strain **with no measured loss of productivity**. |
| **90 seconds for the micro-snack** | [Albulescu et al. 2022](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0272460) — a meta-analysis of 22 studies: micro-breaks of ≤10 min reduce fatigue and raise vigour. The authors warn that after heavy cognitive work 10 minutes are not enough, which is why every 90 minutes the break is a full one. |
| **The vigorous bout, and the target of 3 a day** | [Stamatakis et al. 2022, *Nature Medicine*](https://www.wcrf.org/about-us/news-and-blogs/vigorous-exercise-and-the-science-behind-exercise-snacking/) — 25,241 non-exercising adults: three daily bouts of 1-2 minutes of vigorous activity are associated with ~40% lower mortality over 7 years. |

### And one feature Otium does NOT implement

The **20-20-20 rule** (every 20 minutes look 6 metres away for 20 seconds) is in nearly every break
app. In a [2023 trial](https://www.optometryadvisor.com/features/digital-eye-strain-may-not-be-solved-by-the-20-20-20-rule/)
comparing 20-second breaks at 5, 10 and 20 minute intervals, no difference emerged in symptoms,
reading speed or accuracy. The three "20"s were chosen because they are memorable, not because they
were optimised.

Otium does not build an eye timer. The movement break rests your eyes anyway.

---

## How it works

**It counts active time, never the wall clock.** Stop for more than a minute and the counter stops;
come back sooner and it resumes where it was. This is the most cited complaint in reviews of the
alternatives: they unlock on clock time, so a moment away is enough to find the screen in your face.

**A break you take yourself counts.** Get up on your own for more than 90 seconds and the
micro-break is considered done. Over 5 minutes counts as a full break. Getting up by yourself is the
desired behaviour, not a way to cheat.

**But sitting still is not getting up.** Watching a film or reading a PDF is perfect stillness,
which is exactly the sedentary bout the studies measure. Otium tells the two apart:

| What you are doing | How it knows | What it does |
|---|---|---|
| watching a video | a player **on a fixed list** is producing audio, attributed to the process (nested helpers included) | counts as sitting time → the break fires |
| reading a document | the frontmost app is a reader, and `lsof` says which `.pdf`/`.docx`/`.md` it holds open | counts as sitting time → the break fires |
| on a call | a microphone is in use, or a camera is capturing | counts as sitting time → **but the break does not fire** while the call lasts |
| you left | no signal, no input | a natural break, no exercise |

Every signal **expires**, or leaving a PDF open and going to lunch would make lunch count as work:
**45 minutes** for a video, **15** for a document, without a single input. Past the cap the clock
stops, and coming back does not gift you a break you never took: the absence only counts from the
moment the signal expired.

**The call is the one exception, and it never expires.** A two-hour meeting without touching the
trackpad is the longest sit of the day: if the signal expired, those two hours would stop counting
halfway. Instead of a cap there is a nudge — after **4 hours** of an open microphone without a
single touch the app says something is holding it open. It says, it does not block.

**And an overdue break arrives bigger.** If sitting time has passed **twice** the interval, because
you were in a meeting or because you postponed, what fires is the 5-minute full break rather than
the 90-second snack. A whole skipped cycle is not repaid with ninety seconds.

The player list is deliberately closed: only browsers and video players count, never any process
that happens to be making noise. Spotify and Music are **out** — background music while you are in
the kitchen is not "being at the screen".

One technical note that cost a field test: the first design read the system assertion *"don't sleep
the display"*, the one players raise during a video. **Chromium browsers don't raise it at all** —
with YouTube playing in Brave, the full assertion list contained only `caffeinate`, `powerd` and
WindowServer. Audio, on the other hand, is always visible. And the thing making the sound is not the
browser: it is a helper nested inside its bundle, which the system does not consider an application,
so the executable path has to be walked up to the outermost `.app`.

To see what it recognises right now:

```bash
/Applications/Otium.app/Contents/MacOS/Otium --presence
```

**The "done" button has a gate.** It unlocks only after the minimum plausible time for those reps
(reps × seconds per rep). Without a camera this is an honour system, but honour with a stopwatch in
front of it costs more effort than the truth.

**Sixteen exercises, and variants inside the break.** The rotation offers whatever is next — squats,
push-ups, lunges, calf raises, glute bridges, bench dips — and never the same muscle group twice in
a row. If the break is push-ups you can switch with one click to **diamond**, **archer**, **bench
dips**, **pike** or **incline**: the reps adjust to the difficulty, and the "done" stopwatch
restarts on the switch, so picking the shortest variant at the last second gets you nothing.

**Progression, in both directions.** Reps start at 55% of the volume and reach 100% over four weeks:
starting full on day one is the fastest way to hurt yourself and uninstall the app. After that,
turning on growth beyond 100% raises them by 5% after two full confirmations in a row and steps them
back after two shortfalls — the ACSM's 2-for-2 rule — and once the number no longer fits in the
break, the app offers a harder movement instead of a bigger number.

**It never blocks you during a call.** While a microphone is in use the break is postponed and says
so, with no limit on postponements and no limit on duration: a three-hour meeting does not end with
the screen covered halfway. Time keeps counting, though, and when the call ends you get the
one-minute warning rather than the screen in your face.

**It does not lock you out.** There is always a way out: typing an exact phrase in full. Every skip
goes in the log — not a judgement, a data point. And if nobody is at the Mac, the block drops by
itself.

| What you did | What you decided |
|---|---|
| <img src="docs/stats.png" alt="The statistics page: reps, days, vigorous bouts, then each exercise with prescribed versus done, and reps by muscle chain"> | <img src="docs/preferences.png" alt="The Cadence panel: preset, interval, break lengths, how often a full break, warning, manual postponements"> |
| Every bar is one break. The percentage is what you did against what was prescribed, so an honest 55% shows up as 55%. | Every number here has a default that comes from a study, and changing one tells you which preset you just left. |

### Honest about what the block is, and what it is not

Since macOS High Sierra no window can sit above the system lock screen, and any process can be
killed from a terminal. Otium is not a padlock: it is **strong friction**. It covers every screen at
shielding level, hides the Dock and menu bar, disables ⌘-Tab, Exposé, Force Quit and log-out.
Anyone who wants to get around it will — and that is fine: the point is to put the choice in front
of your eyes, not to take it away.

---

## Privacy and permissions

Otium **does not appear** in Settings → Privacy & Security, because it uses nothing that would
require it:

- idle time is read from `CGEventSource`, which needs neither Accessibility nor Input Monitoring;
- call detection reads `kAudioDevicePropertyDeviceIsRunningSomewhere` and its video twin
  `kCMIODevicePropertyDeviceIsRunningSomewhere`, that is *whether* a device is in use — no stream
  opened, not one byte of audio or image, no microphone or camera permission;
- the warning is a panel drawn by the app, not a system notification (which would need a permission);
- no screen recording, no network.

Everything stays in `~/Library/Application Support/Otium/`: `settings.json` and `ledger.jsonl`, an
append-only JSON Lines log you can read with anything.

---

## Install

One line, no Xcode, no build. It downloads the latest release, puts the app in `/Applications`,
clears the quarantine flag (builds are unsigned) and launches it:

```bash
curl -fsSL https://raw.githubusercontent.com/xmasyx/otium/main/Scripts/install.sh | bash
```

Read [that script](Scripts/install.sh) before you pipe it to a shell. It is short, and the one step
worth confirming yourself is the `xattr` line that clears the quarantine flag.

Or build it from source — macOS 15+ and Xcode (or the Command Line Tools):

```bash
git clone https://github.com/xmasyx/otium.git && cd otium
Scripts/build-app.sh          # produces dist/Otium.app, ad-hoc signed
open dist/Otium.app
```

Only **one runs at a time**: launching it again from Spotlight wakes the one already there and tells
you how long until the next break, instead of starting a second timer alongside the first.

The app lives in the menu bar: the number is how many minutes of active work remain until the next
break. From there: today's totals, preferences, the sources, the log. The interface is in English
and Italian, switchable in Preferences.

To start it at login, use Preferences → *Start at login*, or:

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

### Seeing the break screen without waiting half an hour

```bash
dist/Otium.app/Contents/MacOS/Otium --demo-break=20        # closes itself after 20 s
dist/Otium.app/Contents/MacOS/Otium --snapshot=out.png     # draws it offscreen
```

The self-close is not a convenience: during the block the app disables Force Quit, so a demo relying
on someone closing it by hand would be the perfect way to leave a Mac nailed shut.

---

## What already exists, and what doesn't

| | Otium | [Stretchly](https://github.com/hovancik/stretchly) | Time Out | [Workrave](https://workrave.org) | "unlock with push-ups" apps |
|---|---|---|---|---|---|
| native macOS | ✅ ~5 MB | Electron | ✅ | ❌ (port stalled) | iPhone only |
| counts **active** time | ✅ | pauses on idle | ✅ *natural breaks* | ✅ | ❌ wall clock |
| really blocks the screen | ✅ | partial | ❌ | ✅ | ✅ |
| exercises with reps | ✅ | text ideas | ❌ | ✅ guided | ✅ |
| counts the reps | ❌ (honour + stopwatch) | ❌ | ❌ | ❌ | ✅ camera |
| shows its sources | ✅ | ❌ | ❌ | ❌ | ❌ |
| price | free, source-available | free | free | free | $15/month |

## Planned

- Real rep verification **without a camera**: head motion from AirPods
  (`CMHeadphoneMotionManager`) or Apple Watch.
- Notarisation, so the download opens without clearing quarantine by hand.
- A weekly report: reps, breaks kept, time at the Mac.

## Tests

```bash
swift test                           # 423 tests: clock, engine, ramp, rotation, ledger, wording
swift Scripts/probe-blocker.swift    # checks the block covers every screen (with the app blocking)
```

The block probe calibrates itself by building a window of known size, because `kCGWindowBounds` does
not live in the same coordinate space as `NSScreen.frame`: on a scaled display a 1512×982-point
window is listed as 1362×884, and comparing the raw numbers declares a healthy app broken.

## Licence

**PolyForm Noncommercial 1.0.0**, full text in [`LICENSE`](LICENSE).

The code is **source-available, not open source**, and the difference is stated here rather than
left to be inferred: you may read it, build it, modify it and use it freely for yourself, for study
and for research, and the same goes for schools, public bodies and non-profits. Using it
commercially needs my permission. I don't call the project open source because it isn't, by the OSI
definition, and using that word loosely would be unfair to the people who respect it.

**Why.** Otium could become a product, and this licence keeps that door open without closing the
only thing that matters to whoever installs it: the code stays readable, so the promise of "no
network, no system permissions" can be verified instead of believed.

No third-party dependencies: only Swift and the macOS system frameworks.

The 338 quotations and 73 lines the app shows during a break come from public-domain authors
(Seneca, Marcus Aurelius, Epictetus, Nietzsche, Montaigne, Pascal, Spinoza, Leopardi, Sun Tzu, Tao
Te Ching, the Analects, the Dhammapada, the Gita). The English renderings are historical
translations, also public domain, in 313 cases out of 338: Gummere, Long, Common, Zimmern, Legge,
Max Müller, Arnold, Cotton, Trotter, Elwes, Giles, Edwardes. The remaining 25 are this project's own
translations and fall under the same licence as the code.

---

*[Leggi questo README in italiano](README-it.md).*
