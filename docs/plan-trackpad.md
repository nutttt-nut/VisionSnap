# plan-trackpad.md — Trackpad input mode (VisionSnap)

> **SUPERSEDED:** เอกสารนี้เกิดจากการตีความ scope ผิด VisionSnap ใช้มือหน้ากล้องสำหรับ workspace gestures; native trackpad ทำงานนี้ได้อยู่แล้วและไม่ใช่ input ของแอป เก็บเนื้อหาด้านล่างไว้เป็นประวัติการตัดสินใจเท่านั้น

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

## ✅ RESOLVED (2026-07-23, Nut) — option (d) auto-toggle native

**ปัญหาแกน**: macOS native มี "Swipe between full-screen apps" (4 นิ้ว) เปิด default. MultitouchSupport อ่าน contact แบบ **passive — suppress event ระบบไม่ได้** (ไม่มี stable API ให้ third-party กิน system multi-finger swipe). ผลคือ 4-finger ปัด → **ยิงซ้อน 2 ที**: native switch desktop + VisionSnap Control+arrow = desktop เด้ง 2 ครั้ง

**ตัวเลือกที่พิจารณาแล้ว (historical):**
- (a) ให้ผู้ใช้ปิด native เอง ผ่าน ConflictDetector/onboarding — ได้ 4+5 ครบ แต่ผู้ใช้ต้องตั้งเอง
- (b) 5-finger only — สะอาดสุด ไม่แตะ settings แต่ vocabulary ไม่ครบ
- (c) accept double-fire — ❌ ตัดทิ้ง (พังชัดเจน)

**Nut เลือก (d): VisionSnap จัดการ native setting ให้เอง (lifecycle-managed)**
> ปิด native ตอน VisionSnap **activate**, คืนค่า (restore) ตอน **quit/deactivate** — ผู้ใช้ไม่ต้องแตะ System Settings เอง = UX ดีสุด, ได้ 4+5 finger ครบ, ท่าเดียวยิงครั้งเดียว

**Mechanism (Oasis pin ตอน implement):** toggle key ของ "Swipe between full-screen apps" ผ่าน `defaults` domain `com.apple.AppleMultitouchTrackpad` / `com.apple.driver.AppleBluetoothMultitouch.trackpad` (key ตระกูล `...FourFingerHorizSwipeGesture`, ค่า 2=on / 0=off) — บันทึกค่าเดิมก่อนปิด เพื่อ restore ให้ตรงที่ผู้ใช้ตั้งไว้ (ไม่ hardcode คืนเป็น on)

### 🚦 Verification gate (Oasis ต้องพิสูจน์ก่อน ship option d — ห้าม assume)

option (d) พึ่งสมมติฐาน 2 ข้อที่ **ยังไม่ verified** — ถ้าข้อ 1 fail ต้อง fall back ไป (a) อัตโนมัติ ไม่ใช่ปล่อย native ปิดค้าง:

1. 🟡 **Live-apply ได้จริงไหม (ไม่ต้อง logout)?** — `defaults write` เขียนค่าได้แน่ แต่ trackpad driver อาจอ่านค่าตอน login เท่านั้น. Oasis ต้องทดสอบบนเครื่องจริง: เขียนค่า → ปัด 4 นิ้วทันที → native หยุดตอบสนองจริงหรือไม่ (อาจต้อง trigger `distributed notification` เช่น `com.apple.MultitouchSupport...` หรือ re-post ให้ driver reload). **ถ้า live-apply ไม่ได้ → option (d) ใช้ไม่ได้ → fall back (a):** surface ให้ผู้ใช้ปิดเองผ่าน ConflictDetector เดิม
2. 🟡 **Crash-safe restore** — ถ้า VisionSnap crash / force-quit / power loss จะไม่ทัน restore → ผู้ใช้เหลือ native ปิดค้าง (regression เงียบ). ต้องมี: (i) restore-on-next-launch — เช็ค marker file ตอน launch ถ้าเจอค่าเดิมที่ยังไม่ restore ให้คืนก่อน, (ii) signal handler (SIGTERM/SIGINT) restore ก่อนตาย

**Consent (repo public):** อย่าเปลี่ยน system setting เงียบๆ — onboarding ต้องบอกผู้ใช้ครั้งแรกว่า "VisionSnap จะปิด native 4-finger swipe ชั่วคราวตอนเปิด และคืนค่าให้ตอนปิด" (ใช้ ConflictDetector/onboarding pattern เดิม)

## Risks

| ความเสี่ยง | Mitigation |
|---|---|
| **Private API (MultitouchSupport undocumented)** | Oasis pin exact API จาก Touch-Tab/BTT source; อาจกระทบ notarization → เขียน README known-limitation 1 บรรทัด |
| 4-finger double-fire | RESOLVED → option (d) auto-toggle native (ปิดตอน activate, restore ตอน quit) |
| **native live-apply fail** (setting ต้อง logout ถึงมีผล) | Verification gate #1 — Oasis ทดสอบก่อน; ถ้า fail → fall back (a) surface ให้ผู้ใช้ปิดเอง |
| **native ปิดค้างหลัง crash** | Verification gate #2 — restore-on-next-launch (marker file) + signal handler |
| camera + trackpad ยิงซ้อน | action-level cooldown ร่วม (ไม่ใช่ per-source) |
| Apple ถอด/เปลี่ยน private framework | รับเป็น known risk ของ portfolio; fallback = ปิด trackpad mode, camera ยังทำงาน |

## Success Criteria

- ปัด 4 นิ้ว + 5 นิ้วขึ้นบน trackpad → สลับ desktop / เปิด Mission Control ได้เสถียร (4-finger ไม่ยิงซ้อน native)
- **activate VisionSnap → native 4-finger swipe หยุดตอบสนองทันที (live, ไม่ต้อง logout)** — ถ้าทำไม่ได้ = gate #1 fail, fall back (a)
- **quit VisionSnap → native 4-finger swipe กลับมาทำงานเป็นค่าเดิมที่ผู้ใช้ตั้งไว้** (ไม่ hardcode on)
- **kill -9 VisionSnap แล้ว launch ใหม่ → native ถูก restore ให้ตอน launch** (crash-safe, ไม่ปิดค้าง)
- เปิดทั้ง camera + trackpad พร้อมกัน → ท่า workspace เดียว trigger ครั้งเดียว ไม่ซ้อน
- ปิด trackpad mode → ไม่กระทบ camera path เดิม
- ไม่ต้องขอ permission เพิ่มนอกจาก Accessibility ที่มีอยู่

## Placement

Phase 2 (workspace/input enhancement) — หลัง Phase 0/1 ปิดแล้ว. ไม่ block งาน multi-monitor/demo ที่ยัง unverified
