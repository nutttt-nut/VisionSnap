# VisionSnap

Gesture-based macOS window manager — control windows with hand gestures via the built-in camera (Vision Framework + Accessibility API). Portfolio/showcase project.

## Status

Phase 1 interaction is in progress: hand tracking, target-window feedback, pinch drag, and workspace gestures are implemented.

## Docs

- [`docs/spec.md`](docs/spec.md) — full spec: goals, non-goals, distribution model, privacy model, architecture, safety net, success metrics, known limitations
- [`docs/plan.md`](docs/plan.md) — phased roadmap (Phase 0 → 3)
- `docs/*-original.md` — first-draft planning docs, kept for history; superseded by `spec.md`/`plan.md`

## Quick facts

- Swift + SwiftUI, macOS 13+ target
- Distribution: direct download + notarization, **not sandboxed** (Accessibility API requires it — see spec.md Distribution section for why)
- Camera is off by default, toggled via menu bar / hotkey
- Camera Monitor shows live hand landmarks and pinch diagnostics
- A cyan cursor plus yellow border/name identifies the selected app window
- Four-finger horizontal swipe changes Desktop; five-finger upward swipe opens Mission Control
- MVP scope: one-hand pinch-drag-drop + cancel gesture + basic snap, single (primary) display only

## Privacy

The camera is off by default. When enabled, frames are processed in memory only and are never recorded, stored, or transmitted.

## Known limitations

- Gesture-native control targets the primary display only.
- Hand tracking needs adequate lighting and can fail when fingers occlude each other.
- Clamshell mode is unsupported without another camera.
- Desktop/Mission Control gestures use the macOS Control+Arrow shortcuts and require those shortcuts to remain enabled.

## Development

Open `VisionSnap.xcodeproj` in Xcode. The app targets macOS 13+, uses Accessibility APIs, and intentionally does not enable App Sandbox.
