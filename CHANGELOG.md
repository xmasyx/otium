# Changelog

Otium is a break enforcer: it counts your real screen time and locks the screen until you
move. This file records what changed between released versions, newest first.

## [Unreleased]

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
