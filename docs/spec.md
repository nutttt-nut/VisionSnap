# spec.md — VisionSnap

> Consolidated spec หลังพบช่องโหว่ในเอกสารเดิม (`architecture.md`, `technical-suggest.md`, `implementation-plan.md`) — ไฟล์นี้เป็น source of truth ตัวใหม่ ไฟล์เดิม 3 ไฟล์เก็บไว้เป็น reference/ประวัติความคิด ไม่ต้องอัปเดตต่อ

## Decisions (ยืนยันกับ Nut แล้ว 2026-07-22)

| หัวข้อ | ตัดสินใจ | ผลต่อ design |
|---|---|---|
| เป้าหมายโปรเจกต์ | **Portfolio/showcase project** | โฟกัส polish ของ demo path (pinch+drag ต้องลื่นมาก) มากกว่า coverage ของทุก edge case |
| Target user | **General productivity — เสริม ไม่ใช่ทดแทน** | ไม่แข่งกับ [[Rectangle]] ตรงๆ ด้วยความเร็ว — ขายที่ "เท่/demo ได้" ท่าทางที่ natural |
| Camera privacy model | **Toggle ผ่าน menu bar/shortcut** — กล้องเปิดเฉพาะตอน gesture mode ON | ต้องมี explicit ON/OFF state, ไม่ auto-start ตอนเปิดเครื่อง |
| Conflict กับ window manager อื่น | **Detect + เตือนอย่างน้อย** (ไม่ใช่ full resolution) | เพิ่ม module ตรวจ process/bundle ID ตอน launch, แสดง one-time warning ไม่ block |

## Scope Update (2026-07-22, สั่งตรงกับ Oasis ระหว่าง implement)

Nut สั่ง Oasis เพิ่ม scope เองระหว่างเริ่มงานจริง — เอกสารนี้ตามหลังโค้ดอยู่ ณ ตอนบันทึก:

- **Gaze-select** — เพิ่ม eye-tracking เป็น input mode คู่กับ hand tracking (รายละเอียด design/API ยังไม่ระบุในเอกสารนี้ — ดู session/mailbox ฝั่ง Oasis สำหรับ implementation จริง)
- **Pause eye tracking ตอน pinch** — กัน gaze กับ hand gesture ชนกัน (ป้องกัน false trigger ระหว่าง 2 input mode)
- **Relative palm drag** — ปรับวิธีคำนวณ drag จาก absolute cursor position เป็น relative ต่อตำแหน่งเริ่ม pinch
- **3x3 snap grid** — ขยายจาก snap 4 โซนเดิม (ซ้าย/ขวา/บน/ล่าง) เป็น grid 3x3
- **Held AX element** — เก็บ reference `AXUIElement` ค้างไว้ระหว่าง drag แทนการ query ใหม่ทุก frame (performance)
- **Diagnostics module** — เพิ่มเข้ามาไม่มีในแผนเดิม

**ผลต่อ Non-Goals เดิม**: spec เดิมไม่เคยพูดถึง eye-tracking เลย (ทั้ง Goals และ Architecture) — ต้องถือว่า **gaze-select เป็น scope ใหม่ที่เพิ่มนอกแผนเดิม ไม่ใช่ implicit อยู่แล้ว** ใครอ่าน spec.md ต่อจากนี้ควรรู้ว่า Architecture section ด้านล่างยังไม่ได้อัปเดตให้มี `GazeTrackingService`/`EyeTrackingService` — เป็น known gap ของเอกสารนี้ ให้เช็คโค้ดจริงเป็นหลักแทนจนกว่าจะ sync กลับมา

**สถานะเดิมก่อน implementation commit**: unit tests + build + diff check ผ่าน แต่ physical E2E ยัง unverified และ grab/release ยังเป็น blocker.

**สถานะปัจจุบัน**: gaze-select/eye tracking มีโค้ดจริงใน `GazeEstimator`, `GazeCalibrator`, `HandTrackingService` และ `GestureEngine`. Physical log บนจอหลักยืนยัน `enteredGRAB=y`, AX element ไม่เป็น `nil`, target delta ไม่เป็นศูนย์ และ `axSetPosResult=0`; Nut ยืนยันว่า interaction ใช้งานได้แล้ว. Multi-monitor ยัง **UNVERIFIED** และอยู่นอก MVP.

---

## Goals

- แสดง gesture-based window control ที่ demo ได้จริง: ชี้นิ้ว → cursor เคลื่อน, pinch → หยิบหน้าต่าง, ลาก → ย้าย, ปล่อย → วาง
- Snap layout พื้นฐาน (ซ้าย/ขวา/เต็มจอ) ด้วยท่ามือ
- Latency รู้สึก "real-time" (เป้า <50ms จาก hand movement ถึง cursor update)
- Codebase สะอาดพอจะโชว์เป็น portfolio (architecture ชัด, มี test coverage ส่วน gesture logic)

## Non-Goals (ตัดออกจาก scope อย่างชัดเจน — ของเดิมไม่เคยเขียนส่วนนี้)

- **ไม่ทดแทน Rectangle/keyboard shortcut** — ไม่ต้อง optimize ให้เร็วกว่าคีย์ลัด
- **ไม่ทำ true multi-monitor gesture tracking** — กล้องมีตัวเดียวติดกับจอหลัก, mapping cursor ไปจอนอกที่ไม่อยู่ในมุมกล้องเป็นปัญหาที่ยังไม่มีคำตอบทางเทคนิคที่ดี (ดู Known Limitations) → MVP ทำงานกับจอหลักเท่านั้น จอรองแค่ "เห็น" ผ่าน cursor ที่ข้ามไปได้แต่ไม่ trigger การเลือกหน้าต่างด้วยมือขณะกล้องมองไม่เห็นจุดนั้น
- **ไม่ทำ full conflict resolution** กับ window manager อื่น — แค่ detect + เตือน ไม่ auto-disable ของคนอื่น
- **ไม่ทำ Mac App Store distribution** — ไม่ sandbox (ดู Distribution)
- **ไม่ทำ accessibility-first design** (คนละ scope กับที่ user เคยถามตอนแรก — ตัดสินใจแล้วว่าเป็น general productivity)
- **ไม่ทำ AI layout suggestion** ใน MVP/Phase 2 (เดิมอยู่ Phase 3 อยู่แล้ว — ยืนยันว่ายังอยู่ future ไม่ใช่ portfolio scope นี้)

## Distribution & Permissions

- **Direct download เท่านั้น** (เหมือน Rectangle) — ไม่ sandbox เพราะ Accessibility API (`AXUIElement`) ใช้ควบคุมหน้าต่างแอปอื่นไม่ได้ในแอปที่ sandbox (นี่คือ blocker จริงที่เอกสารเดิมไม่เคยพูดถึง)
- ต้อง notarize ผ่าน Apple ให้ Gatekeeper ไม่บล็อก
- Permission ที่ต้องขอตอน first launch, แยก 2 ปุ่มชัดเจนในหน้า onboarding:
  1. **Camera** — `NSCameraUsageDescription` ต้องอธิบายชัดว่าใช้จับท่ามือเท่านั้น ไม่บันทึก/ส่งภาพไปไหน
  2. **Accessibility** — สำหรับย้าย/ปรับขนาดหน้าต่าง (poll `AXIsProcessTrusted()` แบบ Rectangle ทำ)
- ไม่ต้องขอ Screen Recording ใน MVP (ตัด ScreenCaptureKit preview ออกจาก scope — ของเดิมมาร์คเป็น "optional" อยู่แล้ว ยืนยันตัดจริง)

## Camera / Privacy Model

- **Default: OFF.** แอปเปิดมาไม่เปิดกล้องอัตโนมัติ
- เปิด/ปิด gesture mode ผ่าน **menu bar icon click** หรือ **global hotkey** (กำหนดได้ใน settings)
- Indicator ชัดเจนใน menu bar ว่าตอนนี้กล้อง ON/OFF (ไอคอนเปลี่ยนสี) — ไม่พึ่งแค่ไฟเขียวของ macOS
- Auto-timeout: ถ้าไม่มี hand detected ต่อเนื่อง N วินาที (ตั้งค่าได้ default 5 นาที) → auto-off กล้อง กัน battery drain ตอนลืมปิด
- ไม่มี recording/storage/network transmission ของภาพหรือ landmark data ใดๆ — ทุกอย่าง in-memory, real-time เท่านั้น (ต้องระบุใน README ให้ชัดเพราะเป็น portfolio ที่คนอื่นอาจอ่านโค้ด)

## Conflict Detection (window manager อื่น)

โมดูลใหม่ที่เอกสารเดิมไม่มี: **`ConflictDetector`**

- ตอน launch แรก (และ optionally ทุกครั้งที่เปิดแอป) เช็ค running processes / installed apps ผ่าน bundle identifier ที่รู้จัก:
  - `com.knollsoft.Rectangle`, `com.knollsoft.Rectangle-Pro`
  - `com.crowdcafe.windowmagnet` (Magnet)
  - `koekeishiya/yabai` (เช็คผ่าน process name เพราะไม่ใช่ .app bundle ทั่วไป)
  - `com.hegenberg.BetterTouchTool` (มัก conflict เพราะจับ gesture เหมือนกัน)
- ถ้าเจอ → แสดง one-time non-blocking alert: "พบ [ชื่อแอป] ที่อาจแย่งควบคุมหน้าต่างพร้อมกับ VisionSnap — แนะนำปิด shortcut ที่ทับซ้อนกันฝั่ง [ชื่อแอป] เอง" — ไม่ auto-disable อะไรทั้งสิ้น (ตามที่ Nut ยืนยัน — เตือนอย่างเดียวพอ)
- เก็บ "dismissed" state ไว้ใน UserDefaults กันเตือนซ้ำทุกครั้งที่เปิด

## Gesture Safety Net (เอกสารเดิมไม่มี — สำคัญเพราะ AI detection ผิดพลาดได้)

- **Cancel gesture**: กำหมัดขณะ dragging = ยกเลิกทันที คืนหน้าต่างตำแหน่งเดิม (มีอยู่แล้วใน technical-suggest.md แต่ implementation-plan ไม่เคยระบุว่าต้องทำใน MVP — ย้ายเข้า Phase 1)
- **Escape key เป็น universal cancel** — ทางออกฉุกเฉินถ้า gesture ใช้ไม่ได้ (fallback ที่เอกสารเดิมไม่มีเลย)
- **Confidence threshold**: ไม่ trigger pinch action ถ้า joint confidence < 0.6 (ค่าจาก Vision Framework) — กัน false positive ตอนแสงไม่ดี
- **Minimum hold time**: pinch ต้องค้าง ≥150ms ก่อนนับเป็น "grab" จริง กัน jitter สั่นเป็น pinch หลอก

## Workspace Gestures

- **4 นิ้วปัดแนวนอน**: สลับ Desktop ตามทิศทางมือ โดย trigger shortcut `Control+Left/Right` หลังเคลื่อนเกิน threshold
- **5 นิ้วปัดขึ้น**: เปิด Mission Control ผ่าน `Control+Up`
- ทั้งสอง gesture trigger ครั้งเดียวต่อการยกมือหนึ่งครั้งและมี cooldown กันยิงซ้ำ
- เป็น discrete system shortcut ไม่ใช่ continuous trackpad animation เพราะ macOS ไม่มี public API สำหรับสร้าง trackpad gesture ปลอม

## Architecture (อัปเดตจาก architecture.md เดิม)

```text
CameraService (idle by default, toggle-controlled)
    │
    ▼
HandTrackingService (Vision)
    │
    ▼
GestureEngine ── confidence threshold + hold-time debounce
    │
    ├── CursorMapper (primary display only — see Non-Goals)
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
MenuBarController ── camera toggle, status indicator, settings
ConflictDetector ── runs once at launch, checks known window-manager bundle IDs
PermissionsOnboarding ── first-launch flow, explains Camera + Accessibility separately
```

**โมดูลใหม่ที่เพิ่มจากเดิม**: `MenuBarController`, `ConflictDetector`, `PermissionsOnboarding` — ทั้ง 3 ตัวถูกมองข้ามในเอกสารเดิมทั้งที่เป็นส่วนที่ user เจอก่อนสุด (onboarding) และเป็นตัวตัดสินว่า user จะไว้ใจแอปนี้ไหม (privacy toggle)

## Success Metrics (เอกสารเดิมมีแค่ "latency <50ms" ตัวเดียว)

| Metric | เป้า | วิธีวัด |
|---|---|---|
| Cursor latency | <50ms จาก hand move ถึง on-screen update | manual benchmark ด้วย high-speed video ตามที่ implementation-plan เดิมระบุ |
| Pinch false-positive rate | <5% ใน 10 นาทีใช้งานปกติ | manual log จำนวน accidental grab ต่อ session ทดสอบ |
| Pinch detection latency | <150ms จาก physical pinch ถึง app state = Pinching | เทียบ timestamp video กับ log |
| Demo reliability | ลากหน้าต่างสำเร็จ ≥9/10 ครั้งติด ในสภาพแสงห้องทำงานปกติ | manual test scripted ก่อน record demo video |

## Known Limitations (ต้องเขียนลง README ตรงๆ — ส่วนหนึ่งของ portfolio คือความซื่อสัตย์เรื่อง scope)

- ใช้ได้กับจอหลัก (built-in camera side) เท่านั้น — multi-monitor แบบ gesture-native ยังไม่รองรับ
- ต้องมีแสงเพียงพอ — Vision Framework hand pose เสื่อมความแม่นยำในที่มืด
- นิ้วบังกันเอง (occlusion) ยังทำให้ tracking หลุดได้ — ไม่มี IR/depth sensor ช่วยเหมือน Face ID
- Clamshell mode (ปิดจอโน้ตบุ๊ก ใช้จอนอกอย่างเดียว) = ใช้งานไม่ได้เพราะไม่มีกล้อง

## Open Questions ที่ยังไม่ตอบ (ต้องถามรอบหน้าก่อนเริ่ม code)

- ชื่อ hotkey เปิด/ปิด gesture mode default เป็นอะไร (ต้องไม่ชนกับ shortcut ระบบ/แอปทั่วไป)
- Minimum macOS version ที่ support (Vision hand-pose API ต้องการ macOS 11+ / ควรกำหนด baseline ให้ชัด เช่น macOS 13+ เพื่อใช้ ServiceManagement API ใหม่ด้วย)
- จะ open-source ไหม (ถ้าใช่ ต้องเลือก license ตั้งแต่ repo init)
