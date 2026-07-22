# technical-suggest.md

# Gesture Window Manager for macOS

## Goal

Build a native macOS application that allows users to manipulate
application windows using hand gestures captured from the built-in
MacBook camera.

Primary interactions:

-   Track a user's hand in real time
-   Use pinch gesture to grab a window
-   Drag the window with hand movement
-   Snap windows into layouts
-   Resize windows using two-hand gestures
-   Create an interaction similar to Vision Pro, but on macOS

------------------------------------------------------------------------

# Recommended Technology Stack

``` text
MacBook Camera
        │
        ▼
AVFoundation
        │
        ▼
Vision Framework
(Hand Pose Detection)
        │
        ▼
Gesture State Machine
        │
        ▼
Accessibility API
(Window Control)
        │
        ▼
Window Manager
```

## Core Components

### 1. Camera Capture

-   AVFoundation
-   60 FPS preferred
-   Front camera
-   Mirror correction

### 2. Hand Tracking

Apple Vision Framework

Recommended API:

-   VNDetectHumanHandPoseRequest

Tracks:

-   Thumb
-   Index
-   Middle
-   Ring
-   Little finger

Supports:

-   Left / Right hand
-   Joint confidence
-   Continuous tracking

------------------------------------------------------------------------

### 3. Gesture Recognition

Recommended gestures:

  Gesture            Action
  ------------------ -----------------------
  Point              Move virtual cursor
  Pinch              Grab window
  Release            Drop window
  Closed fist        Cancel
  Two-hand stretch   Resize
  Hold               Multi-select (future)

Implement a Gesture State Machine instead of frame-by-frame decisions.

Example states:

-   Idle
-   Hover
-   Pinching
-   Dragging
-   Resizing

Add:

-   debounce
-   cooldown
-   hysteresis
-   smoothing

------------------------------------------------------------------------

### 4. Virtual Cursor

Convert camera coordinates into screen coordinates.

Requirements:

-   Mirror correction
-   Screen scaling
-   Multi-monitor support
-   Motion smoothing

Use exponential smoothing to reduce jitter.

------------------------------------------------------------------------

### 5. Window Detection

Use Accessibility API (AXUIElement).

Capabilities:

-   Enumerate windows
-   Get window bounds
-   Get active application
-   Move window
-   Resize window
-   Focus window

Window selection flow:

1.  Virtual cursor enters window
2.  Highlight target window
3.  Pinch to lock
4.  Drag
5.  Release

------------------------------------------------------------------------

### 6. Window Movement

Recommended interaction:

Hover

↓

Highlight

↓

Pinch

↓

Shadow appears

↓

Move

↓

Snap preview

↓

Release

------------------------------------------------------------------------

### 7. Snap Layout

Support:

-   Left Half
-   Right Half
-   Fullscreen
-   Top Half
-   Bottom Half
-   Four Quadrants

Future:

-   Custom layouts
-   Saved workspaces
-   App groups

------------------------------------------------------------------------

### 8. Two-Hand Resize

Detect both hands.

Distance between hands controls:

-   Width
-   Height
-   Scale

Only active while pinching with both hands.

------------------------------------------------------------------------

### 9. Permissions

Required:

-   Camera
-   Accessibility

Optional:

-   Screen Recording (if using ScreenCaptureKit for previews)

------------------------------------------------------------------------

# Recommended Architecture

``` text
Camera

↓

Vision Hand Tracking

↓

Gesture Recognition

↓

Cursor Mapping

↓

Window Selection

↓

Accessibility API

↓

Window Manager

↓

UI Overlay
```

------------------------------------------------------------------------

# Future Features

## Workspace Presets

Examples:

-   Coding
-   Design
-   Meeting
-   Writing

Automatically restore window positions.

------------------------------------------------------------------------

## AI Assisted Layout

Use an LLM to arrange windows based on context.

Examples:

-   Coding
    -   VS Code
    -   Terminal
    -   Browser
-   Meeting
    -   Zoom
    -   Notes
    -   Slack

------------------------------------------------------------------------

## VisionOS-style Interaction

Possible additions:

-   Hover effects
-   Magnetic snapping
-   Physics animation
-   Spatial cursor
-   Window depth illusion

------------------------------------------------------------------------

# Recommended Tech Stack

Language

-   Swift

UI

-   SwiftUI

Camera

-   AVFoundation

Vision

-   Apple Vision Framework

Window Management

-   Accessibility API

Optional

-   ScreenCaptureKit
-   Core Animation
-   Metal

------------------------------------------------------------------------

# MVP Scope

Phase 1

-   Camera
-   Hand tracking
-   Cursor
-   Pinch
-   Drag window

Phase 2

-   Snap layouts
-   Resize
-   Multi-monitor

Phase 3

-   Workspace presets
-   AI layout assistant
-   Gesture customization

------------------------------------------------------------------------

# Notes

Prefer native Apple frameworks over OpenCV/MediaPipe for the initial
implementation.

Reasons:

-   Better integration with macOS
-   Lower latency
-   Easier permission management
-   Native Swift ecosystem
-   Simpler deployment
-   Better long-term maintainability

MediaPipe or YOLO can be introduced later if object detection or
advanced gesture recognition is required.
