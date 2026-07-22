# implementation-plan.md

# Roadmap

## Phase 1 - MVP (1-2 weeks)

-   [ ] SwiftUI menu bar app
-   [ ] Camera capture (AVFoundation)
-   [ ] Vision hand tracking
-   [ ] Virtual cursor
-   [ ] Pinch detection
-   [ ] Highlight hovered window
-   [ ] Drag window
-   [ ] Basic settings panel

Success Criteria: - Window can be moved reliably with one hand.

------------------------------------------------------------------------

## Phase 2

-   [ ] Snap left/right/top/full
-   [ ] Two-hand resize
-   [ ] Multi-monitor
-   [ ] Cursor smoothing
-   [ ] Gesture calibration

Success Criteria: - Stable enough for daily use.

------------------------------------------------------------------------

## Phase 3

-   [ ] Workspace presets
-   [ ] Custom layouts
-   [ ] Gesture customization
-   [ ] Physics animations
-   [ ] AI layout suggestions

------------------------------------------------------------------------

## Risks

-   Accessibility permissions
-   Gesture jitter
-   Camera latency
-   Occluded fingers

Mitigations: - Exponential smoothing - State machine - Confidence
threshold - Window locking

------------------------------------------------------------------------

## Suggested Folder Structure

``` text
Sources/
 ├── App/
 ├── Camera/
 ├── Vision/
 ├── Gesture/
 ├── Cursor/
 ├── WindowManager/
 ├── Accessibility/
 ├── Overlay/
 ├── Settings/
 └── Utilities/
```

## Testing

-   Unit tests for gesture recognition
-   UI tests for window movement
-   Manual latency benchmark (\<50ms target)
-   Test with different lighting conditions
