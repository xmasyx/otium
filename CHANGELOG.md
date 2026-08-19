# Changelog

Otium is a break enforcer: it counts your real screen time and locks the screen until you
move. This file records what changed between released versions, newest first.

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
