# VisionSnap

Gesture-based macOS window manager — control windows with hand gestures via the built-in camera (Vision Framework + Accessibility API). Portfolio/showcase project.

## Status

Spec + plan complete. Implementation not started.

## Docs

- [`docs/spec.md`](docs/spec.md) — full spec: goals, non-goals, distribution model, privacy model, architecture, safety net, success metrics, known limitations
- [`docs/plan.md`](docs/plan.md) — phased roadmap (Phase 0 → 3)
- `docs/*-original.md` — first-draft planning docs, kept for history; superseded by `spec.md`/`plan.md`

## Quick facts

- Swift + SwiftUI, macOS 13+ target
- Distribution: direct download + notarization, **not sandboxed** (Accessibility API requires it — see spec.md Distribution section for why)
- Camera is off by default, toggled via menu bar / hotkey
- MVP scope: one-hand pinch-drag-drop + cancel gesture + basic snap, single (primary) display only
