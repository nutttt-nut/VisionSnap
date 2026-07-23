# VisionSnap

Gesture-based macOS window manager — move, snap, and switch windows with your bare hands, tracked through the built-in camera. No extra hardware. Built with Apple's Vision Framework (hand + face landmarks) and the Accessibility API (window control).

Portfolio / showcase project. The goal is a demo that feels genuinely real-time and natural, not a replacement for keyboard-driven tools like Rectangle.

> **Status:** Phase 1 MVP working and physically verified on the primary display — pinch-to-drag moves real windows end to end (`enteredGRAB → held AX element → non-zero motion → AX set-position OK`). Multi-monitor support and the 9/10 demo-reliability target are **not yet verified**. See [Roadmap](#roadmap).

## Demo

<!-- TODO: add a screen recording (pinch-drag + 3x3 snap) here — the demo GIF is the single most important asset for a gesture project. -->

_Recording coming soon._

## Features

- **Pointer tracking** — an index-finger point moves a virtual cursor; motion is stabilized against the palm so the pointer doesn't jitter with finger flex.
- **Pinch to grab & drag** — pinch to pick up the window under the cursor, move your hand to drag it, release to drop. A confidence threshold and a minimum hold time gate the pinch so accidental touches don't grab.
- **3×3 snap grid** — while dragging, the screen shows an 8-zone grid (the eight outer cells of a 3×3); drop into a zone to snap the window there.
- **Gaze-guided selection** — face-based gaze estimation highlights the window you're looking at (dwell hit-test with smoothing and a dead-zone). Gaze selection pauses automatically while dragging so it never fights the hand.
- **Workspace gestures** — a four-finger horizontal swipe switches Desktops; a five-finger upward swipe opens Mission Control (mapped to the system `Control+Arrow` shortcuts).
- **Safety net** — make a fist while dragging to cancel and return the window to its original spot; `Escape` is a universal cancel. A confidence floor and hold-time debounce guard against false pinches in poor lighting.
- **Camera Monitor** — a live view of the tracked hand landmarks and pinch diagnostics, useful for tuning and for understanding what the model sees.

## How it works

```text
CameraService (off by default, toggle-controlled)
      │
      ▼
HandTrackingService (Vision hand + face landmarks)
      │
      ▼
GestureEngine ── confidence threshold + hold-time debounce
      │
      ├── pointer mapping (primary display)
      ├── PinchDetector ────────► grab / drag / release
      ├── gaze selection (dwell hit-test)
      ├── snap grid (3×3, 8 zones)
      └── WorkspaceGestureDetector
              │
              ▼
WindowControlService (AXUIElement — moves/resizes real windows)

Supporting features:
  MenuBarController        — camera toggle + status indicator
  PermissionsOnboarding    — first-launch Camera + Accessibility flow
  ConflictDetector         — warns if Rectangle/Magnet/yabai/BTT is running
  CameraMonitor / Overlay  — live diagnostics + on-screen cursor/highlight
```

Full design rationale, non-goals, and success metrics: [`docs/spec.md`](docs/spec.md). Phased roadmap: [`docs/plan.md`](docs/plan.md).

## Requirements

- macOS 13 or later
- A built-in (or front-facing) camera on the primary display
- Two permissions, requested separately at first launch:
  - **Camera** — to see your hand. Frames are processed in memory only.
  - **Accessibility** — to move and resize other apps' windows (`AXUIElement`).

## Build & run

Open `VisionSnap.xcodeproj` in Xcode and run. The app:

- targets macOS 13+ and is written in Swift + SwiftUI,
- signs with automatic code signing (set your own `DEVELOPMENT_TEAM` if the bundled one isn't yours),
- **intentionally does not enable App Sandbox** — the Accessibility API cannot control other apps' windows from a sandboxed app, so, like Rectangle, VisionSnap ships as a direct download and would be notarized (not Mac App Store) for real distribution.

> **Note on permissions:** Accessibility trust is tied to the app's code signature. A stable signing identity (a real Development Team, not ad-hoc signing) is required so macOS remembers the grant across rebuilds — otherwise every rebuild silently resets Accessibility trust.

## Privacy

The camera is **off by default** and is toggled explicitly from the menu bar or a hotkey; the menu-bar icon shows the on/off state. When enabled, camera frames and hand/face landmarks are processed **in memory only** — nothing is ever recorded, stored, or sent over the network. There is no telemetry.

## Known limitations

Honesty about scope is part of the portfolio:

- **Primary display only.** Gesture-native control targets the built-in-camera display; multi-monitor gesture tracking is unsolved for a single camera and is out of scope.
- **Needs adequate lighting.** Vision hand-pose accuracy degrades in the dark.
- **Finger occlusion** can drop tracking — there's no IR/depth sensor to recover it.
- **Clamshell mode is unsupported** (no camera when the lid is closed).
- Desktop / Mission Control gestures rely on the macOS `Control+Arrow` shortcuts being enabled.

## Roadmap

- **Phase 0 — Foundation:** onboarding, menu-bar toggle, conflict detection _(implemented; evidence/checklist being finalized)_
- **Phase 1 — MVP:** hand tracking, pinch-drag, snap, workspace gestures, cancel safety net _(working; physically verified on primary display)_
- **Phase 2:** two-hand resize, cursor smoothing, per-user calibration
- **Phase 3:** workspace presets, custom layouts, physics animations

## License

[MIT](LICENSE)
