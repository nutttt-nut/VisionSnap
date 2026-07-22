# plan.md — VisionSnap Roadmap (revised)

> แทนที่ `implementation-plan.md` เดิม — เพิ่ม Phase 0 ที่หายไป และย้ายของที่เป็น "must-have ตั้งแต่ MVP" เข้ามาให้ตรงกับ `spec.md`

## Phase 0 — Foundation (ก่อน Phase 1 เดิม, ของใหม่ทั้งหมด)

เอกสารเดิมกระโดดตรงไปทำ camera+vision เลย แต่สิ่งที่ user เจอก่อนสุดคือ onboarding/permission ถ้าทำตอนหลังจะต้อง refactor ทับ flow ที่มีอยู่

- [ ] Xcode project scaffold (SwiftUI, macOS 13+ target — ดู Open Questions ใน spec.md)
- [ ] `PermissionsOnboarding` — ขอ Camera + Accessibility แยกหน้า อธิบายเหตุผลแต่ละอย่าง
- [ ] `MenuBarController` — ไอคอน + toggle ON/OFF, สถานะกล้อง visible ชัดเจน
- [ ] `ConflictDetector` — เช็ค bundle ID ของ Rectangle/Magnet/yabai/BTT ตอน launch, แสดง one-time alert

Success Criteria: เปิดแอปครั้งแรก → ขอ permission ครบ → เห็น menu bar icon → toggle เปิดกล้องได้ (ยังไม่ต้อง track มือจริง)

---

## Phase 1 — MVP (1-2 สัปดาห์ ตามเดิม แต่ scope เปลี่ยน)

- [x] Camera capture (AVFoundation) — **เปิดเฉพาะตอน toggle ON เท่านั้น** (เดิมไม่ระบุจุดนี้)
- [x] Vision hand tracking
- [x] Virtual cursor (primary display only — ตัด "multi-monitor aware" ออกจาก Phase 1 เดิม ย้ายไป Non-Goals ถาวร)
- [x] Pinch detection **พร้อม confidence threshold (0.6) + hold-time debounce (150ms)** — เดิมไม่มีค่าตัวเลข ทำให้ implement มั่วได้
- [x] Highlight hovered window
- [x] Drag window
- [x] **Cancel gesture (กำหมัด) + Escape key cancel** — ย้ายมาจาก Phase 3/technical-suggest เข้า MVP เพราะเป็น safety net ที่ต้องมีตั้งแต่ demo แรก ไม่งั้น false positive จะทำลาย trust ทันที
- [x] 4-finger horizontal Desktop switch + 5-finger upward Mission Control
- [ ] Basic settings panel (รวม hotkey config + auto-timeout กล้อง)
- [ ] Auto-off กล้องถ้าไม่มีมือใน frame >5 นาที (default, ปรับได้)

Success Criteria: ย้ายหน้าต่างด้วยมือเดียวได้เสถียร **และ** ยกเลิกได้ทันทีถ้าจับผิด **และ** กล้องไม่ค้างเปิดตอนไม่ได้ใช้

---

## Phase 2

- [ ] Snap left/right/top/full
- [ ] Two-hand resize
- [ ] Cursor smoothing (exponential)
- [ ] Gesture calibration (ต่อผู้ใช้ ชดเชยขนาดมือ/มุมกล้องต่างกัน)
- [ ] ~~Multi-monitor~~ **ตัดออก** — ดู Non-Goals ใน spec.md, ยังไม่มีทางแก้ทางเทคนิคที่ดีพอสำหรับกล้องตัวเดียว

Success Criteria: เสถียรพอใช้ทุกวันได้ **บนจอหลักจอเดียว**

---

## Phase 3

- [ ] Workspace presets
- [ ] Custom layouts
- [ ] Gesture customization
- [ ] Physics animations
- [ ] AI layout suggestions

(ไม่เปลี่ยนจากเดิม — ยัง future ตามที่ยืนยัน)

---

## Risks (อัปเดตจากเดิม — เพิ่มของที่ discovery รอบนี้เจอ)

| ความเสี่ยง | เดิมมีไหม | Mitigation |
|---|---|---|
| Accessibility permissions | มีอยู่แล้ว | poll `AXIsProcessTrusted()` แบบ Rectangle |
| Gesture jitter | มีอยู่แล้ว | exponential smoothing + confidence threshold |
| Camera latency | มีอยู่แล้ว | benchmark <50ms ตาม spec.md |
| Occluded fingers | มีอยู่แล้ว | ไม่มีทางแก้เต็มที่ — บันทึกเป็น Known Limitation แทนที่จะพยายามแก้ทั้งหมด |
| **Sandboxing บล็อก AX API** | **ใหม่** | ตัดสินใจ direct-download distribution ตั้งแต่ spec — ไม่ sandbox |
| **Privacy/กล้องค้างเปิด** | **ใหม่** | menu bar toggle + auto-timeout (Phase 0/1) |
| **ชนกับ window manager อื่น** | **ใหม่** | ConflictDetector (Phase 0), ไม่ auto-resolve |
| **False positive ทำลาย trust ตอน demo** | **ใหม่** | cancel gesture + confidence threshold ย้ายเข้า MVP |

## Testing (เพิ่มจากเดิม)

- Unit tests สำหรับ gesture recognition (เดิมมี)
- UI tests สำหรับ window movement (เดิมมี)
- Manual latency benchmark <50ms (เดิมมี)
- Test กับสภาพแสงต่างกัน (เดิมมี)
- **ใหม่**: Unit test สำหรับ confidence-threshold + hold-time debounce logic โดยเฉพาะ (เป็น core safety net ต้องมี coverage)
- **ใหม่**: Manual test ConflictDetector กับ Rectangle ติดตั้งจริงบนเครื่อง dev (เครื่องนี้มี Rectangle อยู่แล้วจาก `/learn` ที่เพิ่งทำ — ใช้เป็น test case ได้เลย)
