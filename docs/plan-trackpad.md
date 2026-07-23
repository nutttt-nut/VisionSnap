# plan-trackpad.md — Trackpad input mode (VisionSnap)

> Feature addition สำหรับ workspace gestures ผ่าน Magic Trackpad / built-in trackpad — เป็น **input mode ที่ 2 คู่กับกล้อง** (ยืนยันกับ Nut 2026-07-23) ใช้ gesture vocabulary เดียวกัน: 4 นิ้วปัดแนวนอน = สลับ Desktop, 5 นิ้วปัดขึ้น = Mission Control

## เป้าหมาย

- เพิ่ม trackpad เป็นแหล่ง input ที่สองสำหรับ **workspace gestures เท่านั้น** (ไม่รวม pinch-drag ซึ่งยังเป็นของกล้อง)
- vocabulary เดียวกับ camera mode: `4-finger horizontal → Control+Left/Right`, `5-finger up → Control+Up` (Mission Control)
- ผู้ใช้ทำท่าเดียวกันได้ทั้งชูมือหน้ากล้องหรือปัดบน trackpad

## ทำไมต้องมี trackpad ทั้งที่มี camera แล้ว (honest scope)

- **ใช้ตอนแสงน้อย** — Vision hand-pose เสื่อมในที่มืด, trackpad ไม่พึ่งแสง
- **ไม่ต้องชูมือ** — workspace switch บ่อยๆ การยกมือหน้ากล้องล้า, ปัด trackpad เร็วกว่า
- ⚠️ **ไม่ได้แก้ Known Limitation "clamshell"** — clamshell ปิดฝา = built-in trackpad ก็ใช้ไม่ได้เช่นกัน. trackpad mode ช่วย clamshell **เฉพาะกรณีต่อ external Magic Trackpad** เท่านั้น อย่าเคลมเกินจริง (repo นี้ public แล้ว, ความซื่อสัตย์เรื่อง scope = ส่วนหนึ่งของ portfolio)

## Architecture (reuse-first — ตาม Ladder)

```text
MultitouchSupport (private framework)
      │  raw contacts (finger count + positions)
      ▼
TrackpadInputService (ใหม่)  ── แปลง contact stream → discrete swipe event
      │  SwipeEvent{fingerCount, direction}
      ▼
WorkspaceGestureDetector (เดิม — ไม่ reimplement vocabulary)
      │
      ▼
system shortcut (Control+Arrow / Control+Up)
```

- **ห้าม reimplement 4/5-finger logic** — `WorkspaceGestureDetector` เดิมมี resolve + cooldown + one-shot-per-lift อยู่แล้ว. TrackpadInputService แค่ผลิต swipe event ป้อนเข้า detector ตัวเดิม = unified vocabulary จริง ไม่ใช่โค้ดคู่ขนาน
- **Permission**: reuse Accessibility grant ที่ VisionSnap มีอยู่แล้ว (Touch-Tab ยืนยันว่า background trackpad ต้องแค่ Accessibility) — Oasis ต้อง verify ว่า MultitouchSupport ไม่ต้อง permission เพิ่มนอกจากนี้
- **Double-fire guard (camera + trackpad ทำงานพร้อมกัน)**: ถ้าเปิดทั้งสอง input พร้อมกัน ท่า workspace เดียวต้อง trigger action **ครั้งเดียว** — debounce ที่ระดับ action ไม่ใช่ per-source (ใช้ cooldown ร่วมของ WorkspaceGestureDetector)

## 🔴 OPEN DECISION (นัทต้องเลือกก่อน implement) — 4-finger ชน native

**ปัญหาแกน**: macOS native มี "Swipe between full-screen apps" (4 นิ้ว) เปิด default. MultitouchSupport อ่าน contact แบบ **passive — suppress event ระบบไม่ได้** (ไม่มี stable API ให้ third-party กิน system multi-finger swipe). ผลคือ 4-finger ปัด → **ยิงซ้อน 2 ที**: native switch desktop + VisionSnap Control+arrow = desktop เด้ง 2 ครั้ง

ตัวเลือก (เลือก 1):
- **(a) ปิด native ก่อนใช้** — ให้ผู้ใช้ปิด "Swipe between full-screen apps" ใน System Settings, surface ผ่าน ConflictDetector/onboarding pattern เดิม (VisionSnap มี ConflictDetector อยู่แล้ว) — ได้ 4+5 finger ครบตามที่ขอ แต่ผู้ใช้ต้องตั้งค่าเอง
- **(b) 5-finger only** — ทำเฉพาะ 5 นิ้ว (native ไม่ผูก 5-finger = ไม่ชนเลย), ปล่อย 4-finger desktop switch ให้ native ทำไป (ซึ่งมันก็ทำได้ดีอยู่แล้ว). สะอาดสุด, ไม่ต้องแตะ settings ผู้ใช้ แต่ vocabulary ไม่ครบเท่ากล้อง
- **(c) accept double-fire** — ❌ ไม่เอา (พังชัดเจน)

> 5-finger half สะอาดในทุกกรณี — native ไม่ผูก 5 นิ้ว. ความยุ่งอยู่ที่ 4-finger เท่านั้น

### ⚠️ UNRESOLVED (2026-07-23) — ต้อง clarify ก่อน implement

Nut ตอบ "(a) but keep native active" — **ขัดกันเอง**: (a) ทั้งอันคือ *ปิด native* เพื่อเลี่ยง double-fire. ถ้าเก็บ native ไว้ + VisionSnap ทำ 4-finger ด้วย = desktop เด้ง 2 ที (= option c ที่ตัดทิ้งแล้ว). API อ่าน passive suppress native ไม่ได้ → 4-finger + native-on พร้อมกัน **เป็นไปไม่ได้ทางเทคนิค**. ต้องถาม Nut ให้เลือกจริง: (a) ยอมปิด native แลกกับ 4+5 finger ครบ **หรือ** (b) เก็บ native ไว้แล้ว VisionSnap ทำ 5-finger อย่างเดียว. **อย่า implement 4-finger จนกว่าจะ resolve.**

## Risks

| ความเสี่ยง | Mitigation |
|---|---|
| **Private API (MultitouchSupport undocumented)** | Oasis pin exact API จาก Touch-Tab/BTT source; อาจกระทบ notarization → เขียน README known-limitation 1 บรรทัด |
| 4-finger double-fire | OPEN DECISION ด้านบน — ต้อง resolve ก่อน implement |
| camera + trackpad ยิงซ้อน | action-level cooldown ร่วม (ไม่ใช่ per-source) |
| Apple ถอด/เปลี่ยน private framework | รับเป็น known risk ของ portfolio; fallback = ปิด trackpad mode, camera ยังทำงาน |

## Success Criteria

- ปัด 4 นิ้ว (ตาม decision) + 5 นิ้วขึ้นบน trackpad → สลับ desktop / เปิด Mission Control ได้เสถียร
- เปิดทั้ง camera + trackpad พร้อมกัน → ท่า workspace เดียว trigger ครั้งเดียว ไม่ซ้อน
- ปิด trackpad mode → ไม่กระทบ camera path เดิม
- ไม่ต้องขอ permission เพิ่มนอกจาก Accessibility ที่มีอยู่

## Placement

Phase 2 (workspace/input enhancement) — หลัง Phase 0/1 ปิดแล้ว. ไม่ block งาน multi-monitor/demo ที่ยัง unverified
