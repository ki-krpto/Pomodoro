# Corkboard — Pomodoro MVP

A calm, minimalist Pomodoro timer. Finish a focus session, get a sticky
note pinned to a corkboard. That's the entire reward loop.

## Getting it running

Drop this into a fresh Flutter project (matches your existing setup —
same `C:\flutter` SDK, no extra tooling needed):

```
flutter create pomodoro_app
```

Then replace the generated `lib/` folder and `pubspec.yaml` with the
ones here, and run:

```
cd pomodoro_app
flutter pub get
flutter run
```

It'll run on the same Pixel 7 emulator you're already using for Roomie —
just remember `wsl --shutdown` first if the emulator's being flaky.

## How the brief maps to the code

```
lib/
 ├── main.dart                    → App entry, theme, Provider setup
 ├── models/session.dart          → PomodoroSession (the one thing that gets stored)
 ├── services/
 │    ├── session_manager.dart    → SessionManager (owns the list, notifies UI)
 │    └── local_storage.dart      → LocalStorage (shared_preferences, isolated)
 ├── utils/note_placement.dart    → Generates a note's permanent jitter/rotation/color, once
 ├── widgets/
 │    ├── timer_view.dart         → Timer (duration picker + countdown)
 │    ├── cork_board.dart         → CorkBoard (frame, texture, note layout)
 │    ├── sticky_note.dart        → StickyNote (duration + time, nothing else)
 │    └── cork_texture_painter.dart → Hand-painted cork speckle + wood grain (no image assets)
 └── screens/home_screen.dart     → Wires Timer + CorkBoard together
```

**Why no image assets for the board texture:** `CustomPainter` with a
fixed random seed draws the cork speckle and wood grain directly. It
avoids shipping asset files for v1 and keeps the whole visual self-
contained in code — easy to retheme later without touching layout.

**Why placement is generated once, in `SessionManager.completeSession`:**
The brief is explicit that notes should never move. Storing `dx`, `dy`,
`rotationDeg`, and `colorIndex` directly on the session (rather than
deriving them at render time) is what guarantees that — a note's
position is a fact about that session, not a function of the current
render.

**Why `CorkBoard` still uses a loose grid:** matches your "very
productive" example (dense, mostly regular, but clearly not a rigid
table). Each note's grid cell is fixed by its index (append-only list,
so order never changes); the jitter inside that cell is what gives it
personality.

## What's intentionally not here

No accounts, streaks, XP, or shop — matches the brief. Statistics,
project boards, and themes are noted as v2 ideas but the architecture
(separate `SessionManager` / `LocalStorage` / presentation widgets)
should absorb them later without a rewrite — e.g. a "project" would
just be another field on `PomodoroSession` and a filter in
`SessionManager`, not a new architecture.

## One thing worth deciding before you build on this

The "pin" sound currently uses `SystemSound.click` — a platform system
sound, not a custom audio asset. It's genuinely subtle, which fits the
brief, but if you want a specific tactile "pin" sound, that's a small
swap (add `audioplayers` or similar and a short `.wav`).
