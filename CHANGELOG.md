# Changelog

Otium is a break enforcer: it counts your real screen time and locks the screen until you
move. This file records what changed between released versions, newest first.

## [1.4.0] — 2026-09-06

### Added

- **Agentic mode.** A break no longer has to cover the screen. With the mode on (menu bar or
  Settings, next to Zen) the break appears as a single compact, draggable panel that never takes
  focus: the app in front keeps receiving keyboard and mouse, so agents driving a browser carry on
  while you do your reps. The panel shows the exercise, the count, the timer with its bar, the
  circuit strip and up to five alternatives; it remembers where you put it and comes back on
  screen if the display changed. The break itself is unchanged: it still ends only when the exercise
  is confirmed and the time is up, and the ledger marks these breaks `agentic`.

### Changed

- **The rest line speaks with Otium's own voice.** Once the exercise is confirmed, the line above
  the timer used to be the same sentence every time («Stand up and look far away…»); it now draws
  one of the app's own lines per break, never the quote already on screen.
- **Agentic panel: number, name, cue, alternatives and actions sit on one centred axis, and everything clickable lights up under
  the pointer** (measured: the hovered pill reads 59 against 32 for its neighbours).
- **Agentic panel: «Postpone 2 minutes» sits bottom-left, «Skip the break» bottom-right.** The
  skip has its own ledger reason (`agenticPanel`): the panel cannot take the escape phrase, and it
  is not an emergency.
### Changed

- **At most five alternatives per exercise.** Seven push-up variants in a 4+3 grid overflowed the
  text column; the ceiling now holds across the whole catalogue (eight exercises trimmed), and the
  push-up keeps the five closest by difficulty.
- **«That's enough, back to the single exercise» disappears once the circuit is complete.**

### Removed

- The «still, reading output: …» line in the break header. It stated a stillness the app could
  not know, and it added nothing to the break.

## [1.3.0] — 2026-09-06

### Changed

- **The break screen adapts to the screen it is on.** Column, type size, spacing, radii, stroke
  widths and the breathing halo were fixed numbers chosen on one 16" laptop, and nothing in the
  code ever read the display. Otium now reads it and derives a single scale from the narrower side,
  clamped between 0.62 and 1.45 — below that the type stops being comfortable to read, above it a
  line grows too long for the eye to find its way back. On the reference display the scale is
  exactly 1, so that page is unchanged, and a test asserts it value by value. The layout also
  follows an external display being plugged in or the resolution changing.
- **The break page distributes its air instead of pooling it.** The free space now belongs to the
  content, which is centred in it with a little breathing room below so it sits at the optical
  centre rather than the geometric one. Before, a fixed spring pinned the phrase near the top and
  left one large gap between the phrase and the timer — between the two things you actually look
  at. As a side effect the two faces of the break no longer shift during the crossfade, because
  both are now centred in the same band.

### Fixed

- **Five facts named something without saying what it is.** The 20-20-20 rule now states what it
  asks for; the fifty million mass-produced chairs now carry the seventy years they were made in
  (the English text already did, the Italian did not); "an independent pathway" says independent of
  what; "overload" and "the parasympathetic response" are glossed in plain words.
- On a small display the breathing halo drew the square of its own frame around the light, because
  the gradient radii stayed fixed while the frame scaled.

## [1.2.1] — 2026-08-31

### Changed

- **New signing identity.** The self-signed certificate Otium is built with was regenerated and the
  release workflow pins the new one. Otium asks for no system permissions, so nothing has to be
  granted again.
- `Scripts/make-signing-cert.sh` keeps the `.p12` it creates instead of deleting it, so the identity
  can be restored rather than recreated. `Scripts/build-app.sh` signs by certificate fingerprint
  instead of by name, which is ambiguous when two keychains hold a certificate with the same
  common name.

## [1.2.0] — 2026-08-30

### Added

- **Updates from the menu.** Otium checks GitHub once a day without blocking startup and can
  update a Homebrew installation on request, clear quarantine from its own new bundle and
  relaunch. Manual installations open the matching release page instead.

### Fixed

- **Intel Macs are refused before download.** The installer falsely promised that "an Intel Mac
  is fine" and checked only the macOS version, while the binary inside `Otium.zip` carried arm64
  only. An affected user got the app copied into `/Applications` and then an error blaming
  quarantine, which was the wrong cause. The installer now says up front that Otium needs Apple
  Silicon and installs nothing on an Intel Mac. It still asks the downloaded app to run **before**
  it copies anything, so a broken arm64 build also leaves `/Applications` untouched and says why.
- **The README claimed a stable certificate.** Releases are signed ad-hoc: `codesign -dvv`
  answers `Signature=adhoc` and `TeamIdentifier=not set`. The stable certificate exists only on
  the maintainer's Mac, and the runner that builds the release does not have it, so it takes the
  ad-hoc branch. The README now describes the file you actually download — and calls the project
  what its LICENSE says it is, noncommercial rather than MIT.
- **`Otium --doctor` answered in Italian on every Mac.** The report is bilingual now and picks
  its language the way the app does: the language you chose, otherwise the language of the Mac,
  which is English for anything that is not Italian. `--agent-status`, `--install-agent`,
  `--remove-agent` and `--remove-legacy-agent` follow the same rule.

## [1.1.0] — 2026-08-19

### Added

- **Six new exercises.** Cross-body mountain climbers (right knee to left elbow, and the
  obliques stop the hips from rotating), easy plank (the plank on straight arms: a shorter
  lever, so the same core holds longer), wall sit, wall angels, bird-dog, and chair step-ups.
  Two of them exist for situations rather than muscles: wall sit and wall angels are done
  standing against a wall, so the break survives being dressed up or in a public place, and
  chair step-ups are the only vigorous exercise that does not jump, which is what an evening
  in a flat allows.
- **Sound volume is adjustable**, separately from the system volume.

### Changed

- The break header shows **how long the break is** ("PAUSA 5'") instead of naming its internal
  category. The number comes from the plan, so it follows the length you chose.
- Inside the circuit, the alternative exercises sit on **a single row**: the stations already
  occupy a row of pills above them, and two stacked rows read as a grid.
- The evidence line under the break no longer cites **breathing studies during an exercise
  break**. It explains why you are being interrupted right now, and right now you are not
  being asked to breathe. The mirror rule for Zen mode already existed.

### Fixed

- The presence line no longer reports **a call that has already ended**. A break deferred
  because the microphone was in use opens exactly when the microphone is released, so the
  line used to say "on a call: microphone in use" at the one moment it was no longer true.
  The signal is now re-read during the deferral and the warning minute.
- The login item pointed at a copy of the app that had been deleted, and nothing said so.
- The quote column was 416 points wide as declared and 402 as drawn, so long lines wrapped
  one word early.

### Docs

- Both READMEs rewritten around the actual problem, and the manual moved out of the shop
  window into `docs/`.
- No home-directory paths anywhere in the repository.

## [1.0.0] — 2026-08-13

First public release.
