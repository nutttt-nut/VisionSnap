# architecture.md

# Gesture Window Manager Architecture

## High-level Modules

``` text
CameraService
    │
    ▼
HandTrackingService (Vision)
    │
    ▼
GestureEngine
    │
    ├── CursorMapper
    ├── WindowSelector
    ├── SnapEngine
    └── ResizeEngine
            │
            ▼
AccessibilityController
            │
            ▼
macOS Windows

OverlayUI (SwiftUI)
```

## Module Responsibilities

### CameraService

-   Capture frames from AVFoundation
-   Normalize orientation
-   Mirror correction
-   60 FPS target

### HandTrackingService

-   Vision Framework
-   Track left/right hands
-   Publish joint locations

### GestureEngine

-   Detect Point, Hover, Pinch, Release, Two-hand Resize
-   Apply smoothing, debounce and hysteresis

### CursorMapper

-   Convert normalized camera coordinates to screen coordinates
-   Multi-monitor aware

### WindowSelector

-   Enumerate windows through Accessibility API
-   Determine hovered window
-   Lock selected window while dragging

### AccessibilityController

-   Move windows
-   Resize windows
-   Focus windows

### SnapEngine

-   Detect snap zones
-   Render preview
-   Apply layout on release

### OverlayUI

-   Cursor
-   Window highlight
-   Snap previews
-   Debug overlay

## Data Flow

Frame -\> Vision -\> Gesture -\> Cursor -\> Window -\> Accessibility -\>
UI
