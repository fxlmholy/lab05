# lab05 — แบบฝึกหัดที่ 5: First 3D Game

เกม 3D Platformer ทำด้วย **Godot 4.7** (Compatibility renderer, export เป็น Web ได้)
ต่อยอดจาก [3D Platformer Starter Kit](https://store.godotengine.org/asset/the-silver-demons/platformer-3d-starter-kit/) ของ SD Studios

## วิธีเล่น

ผู้เล่นต้องหลบกับดักและสิ่งกีดขวาง และเก็บ **ดาวทุกดวง** ในด่านให้ครบ
พอเก็บครบแล้ว **ประตู** จะเปิด ให้เดินเข้าประตูเพื่อไปด่านต่อไป

| ปุ่ม | การกระทำ |
|---|---|
| W A S D | เดิน |
| Space | กระโดด (กดซ้ำกลางอากาศเพื่อตีลังกา / double jump) |
| เมาส์ หรือ ลูกศร | หมุนกล้อง |
| Esc / P | หยุดเกมชั่วคราว (Resume / Restart / Main Menu) |

- มี 5 ชีวิตต่อด่าน: โดนกับดักแล้วกระเด็นและเสีย 1 ชีวิต ถ้าตกจากฉากจะกลับไปเกิดที่ checkpoint ล่าสุด
- ชีวิตหมดแล้วจะเริ่มด่านนั้นใหม่

## ด่าน

| ด่าน | ธีม | กับดัก / กลไก | ดาว |
|---|---|---|---|
| 1 — Whispering Forest | เกาะลอยฟ้าในป่า | แพไม้เคลื่อนที่, กับดักหนามเด้ง, หลักไม้แหลม, ใบเลื่อยบนสะพาน, สปริงดีดตัว, ลูกตุ้มหนามหมุน, เกาะลับ | 12 |
| 2 — The Lava Keep | ปราสาทกลางทะเลลาวา | ทางเดินกับดักหนามแบบไล่จังหวะ, แท่นหินเคลื่อนที่เหนือลาวา, ห้องโถงลูกตุ้มหนามสองวงหมุนสวนทางกัน, บันไดมีใบเลื่อย, สะพานเสาหนามหมุน | 11 |

## สิ่งที่เปลี่ยนจาก Starter Kit

**ตัวละคร (Player)**
- เปลี่ยนจาก Gobot เป็นตัวละครของ Quaternius จาก Poly Pizza (low-poly ประมาณ 5.8k tris)
- สร้าง `Assets/Models/Characters/player_animations.tres` เพื่อ **map ท่าของตัวละครใหม่ให้ใช้ชื่อเดิมของ kit** ทำให้ `player.gd` ยังเรียก `animation.play("Idle" / "Run" / "Jump" / "Flip")` ได้เหมือนเดิม

| ชื่อใน kit | คลิปของตัวละครใหม่ | หมายเหตุ |
|---|---|---|
| Idle | Idle | loop |
| Run | Run | loop |
| Jump | Jump | |
| Flip | Jump + track หมุน `FlipPivot` 360° | ใช้กับ double jump แทน flip ของ Gobot |
| Fall *(เพิ่ม)* | Jump_Idle | loop ตอนกำลังตก |
| Hurt *(เพิ่ม)* | HitReact | ตอนโดนกับดัก |
| Death *(เพิ่ม)* | Death | ตอนชีวิตหมด |
| Victory *(เพิ่ม)* | Wave | ตอนเข้าประตู / หน้าชนะ |

**Gameplay ที่เพิ่ม**: ระบบชีวิต, checkpoint, ไอเท็มดาวที่นับจำนวนในด่านเอง, ประตูที่ล็อกจนกว่าจะเก็บครบ, กับดัก 6 แบบ, แท่นเคลื่อนที่ที่พาตัวละครไปด้วย (ย้ายการเคลื่อนที่ไปไว้ใน `_physics_process`), สปริง, เมนูหลัก, หน้าหยุดเกม, หน้าชนะพร้อมสถิติ

**ฉาก**: ทั้งสองด่านใช้โมเดล low-poly จาก Poly Pizza, ท้องฟ้าแบบ procedural, หมอก, เงา, shader ลาวาที่ขยับได้ และคบเพลิงที่มีแสง

## โครงสร้างโปรเจกต์

```
Scenes/
  UI/MainMenu.tscn, GameUI.tscn, WinScreen.tscn
  Levels/Level1.tscn, Level2.tscn
  Props/  Star, Door, Checkpoint, Spring, SawBlade, SpikeTrap, SpikyBallOrbit, SpikedPillar, Spikes, WoodenStakes, Torch
  Characters/CharacterModel.tscn
  player.tscn
Scripts/
  player.gd, CameraMovement.gd, GameManager.gd (autoload), AudioManager.gd (autoload)
  Block.gd (@tool พื้นแบบ low-poly: GRASS / STONE / WOOD), Mover.gd (เลื่อน/หมุน/แกว่ง)
  Collectible.gd, Hazard.gd, SpikeTrap.gd, Spring.gd, Checkpoint.gd, Door.gd, DeadZone.gd
  Level.gd, GameUI.gd, MainMenu.gd, WinScreen.gd
tools/
  build.gd / build.tscn   สคริปต์ที่สร้างฉากทั้งหมดในครั้งแรก (ถ้ารันซ้ำจะเขียนทับฉาก)
  shot.gd / shot.tscn     ตัวทดสอบอัตโนมัติ: รันฉาก, จำลองการกดปุ่ม, ถ่ายภาพหน้าจอ
```

ฉากทุกฉากเป็นไฟล์ `.tscn` ปกติ เปิดแก้ใน Godot Editor ได้เลย บล็อกพื้นปรับ `size` / `style` ได้ใน Inspector

## Export เป็นเว็บ

```bash
godot --headless --path . --export-release "Web" docs/index.html
```

ไฟล์เกมเว็บอยู่ในโฟลเดอร์ `docs/` (GitHub Pages เสิร์ฟจาก branch `main` โฟลเดอร์ `/docs`) preset "Web" ปิด thread support ไว้ จึงอัปขึ้น **GitHub Pages** หรือ static hosting ทั่วไปได้ทันที โดยไม่ต้องตั้ง COOP/COEP header

## เครดิต

- Starter kit: [3D Platformer Starter Kit](https://github.com/SilverDemons-PK/3D-Platformer-Kit) โดย SD Studios — CC0
- ตัวละคร, กับดัก, ของตกแต่งปราสาท, พืชพรรณ: **Quaternius** ผ่าน [Poly Pizza](https://poly.pizza) — CC0
- เกาะลอย, ต้นไม้, รั้ว, ป้าย, ดาว, หลักไม้แหลม: **J-Toastie** ผ่าน [Poly Pizza](https://poly.pizza) — CC-BY 3.0
- เสียง: จาก starter kit
