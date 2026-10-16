<p align="center">
  <img src="icon/icon_256.png" width="128" alt="ThaiFix icon">
</p>

<h1 align="center">ThaiFix</h1>

<p align="center">
  Typed in the wrong keyboard layout? Press one shortcut and it's fixed.<br>
  พิมพ์ผิดภาษาเพราะลืมสลับแป้น? กดปุ่มเดียว แก้ให้ทันที
</p>

<p align="center">
  <code>l;ylfu</code> &nbsp;→&nbsp; <b>สวัสดี</b> &nbsp;&nbsp;·&nbsp;&nbsp; <code>้ำสสน ไนพสก</code> &nbsp;→&nbsp; <b>hello world</b>
</p>

---

## What it does

ThaiFix is a tiny macOS menu-bar app. When you forget to switch between the Thai and English keyboard and end up with gibberish, press **⌥⌘L** (Option + Command + L):

- **Fixes only the wrong words.** Correct words in a mixed line are left alone —
  `อัพเดท repo มาให้หน่อย` stays exactly as typed, while `นัดกัน l;ylfu` becomes `นัดกัน สวัสดี`.
- **Works in any app** — LINE, Slack, Chrome, Notes, Word, VS Code…
- **Switches your keyboard** to the language you meant to type.
- **Works with a selection too.** Select any text and press ⌥⌘L to convert just that part.
- **Restores your clipboard** afterwards.
- **100% offline.** Nothing you type ever leaves your Mac.

Changed your mind? Press **⌘Z** to undo.

## Install

1. Open the latest successful run under [**Actions**](../../actions) and download **ThaiFix** from *Artifacts*.
2. Unzip it and drag **ThaiFix.app** into **Applications**.
3. Open it. If macOS blocks it, go to **System Settings → Privacy & Security** and click **Open Anyway**.
   If it says the app is *damaged*, run: `xattr -cr /Applications/ThaiFix.app`
4. Allow **Accessibility** access when asked (**System Settings → Privacy & Security → Accessibility → ThaiFix**), then quit and reopen the app.

You'll see the ThaiFix key icon in the menu bar. There is no window — that's normal.

> **Updating:** after replacing the app, remove ThaiFix from the Accessibility list and add it again — macOS treats each new build as a different app.

## How it decides what to fix

The Thai Kedmanee and US QWERTY layouts map one key to one character, so conversion is a simple lookup table — no AI or internet needed. For each word, ThaiFix checks:

| Word looks like | Converted when |
|---|---|
| English letters | it isn't a real English word (macOS dictionary + a list of tech terms like *repo, git, api*) **and** the Thai equivalent is plausible Thai — or it has symbols inside the word like `l;ylfu` |
| Thai letters | it breaks Thai spelling rules (e.g. starts with a vowel or tone mark, like `ำสำ`), or its English equivalent is a real word |

Proper nouns with mixed case (`iPhone`, `GitHub`), URLs, emails and hashtags are never touched.

## Why it needs Accessibility permission

To fix text, ThaiFix simulates **⌘C**, converts the text, and simulates **⌘V** — macOS requires Accessibility permission for any app that sends keystrokes. ThaiFix does not log keystrokes, does not run in the background except when you press the shortcut, and makes no network connections.

## Build from source

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
bash build.sh
open ThaiFix.app
```

Every push also builds a universal (Apple Silicon + Intel) app on GitHub Actions and runs the conversion self-test (`ThaiFix --test`).

## Roadmap

- [ ] Settings window: custom shortcut, launch at login
- [ ] Personal "never convert" word list
- [ ] Pattachote layout
- [ ] More languages (Russian, Hebrew, Arabic, Greek, Korean…)
- [ ] Signed & notarized release
- [ ] Windows version

---

## ภาษาไทย

**ThaiFix** คือแอปเล็ก ๆ บนแถบเมนูของ Mac สำหรับแก้ข้อความที่พิมพ์ผิดภาษาเพราะลืมสลับแป้น ไทย/อังกฤษ

**วิธีใช้:** พิมพ์ไปตามปกติ ถ้าเผลอพิมพ์ผิดภาษา ให้กด **Option + Command + L**
- แอปจะแก้เฉพาะคำที่ผิด คำอังกฤษที่ถูกอยู่แล้ว เช่น repo, update, GitHub จะไม่ถูกแตะ
- ถ้าลากเลือกข้อความไว้ จะแปลงเฉพาะส่วนที่เลือก
- แปลงเสร็จแล้วสลับแป้นภาษาให้ด้วย
- ไม่ต้องใช้อินเทอร์เน็ต ข้อความที่พิมพ์ไม่ถูกส่งออกจากเครื่อง
- ถ้าแปลงผิด กด Command + Z เพื่อย้อนกลับ

**ติดตั้ง:** ดาวน์โหลดจากหน้า [Actions](../../actions) → เลือกรอบล่าสุด → Artifacts → ThaiFix แล้วลากไฟล์ไปไว้ในโฟลเดอร์ Applications จากนั้นเปิดสิทธิ์ Accessibility ให้แอป (ดูรายละเอียดในหัวข้อ Install ด้านบน)

เจอคำที่แปลงผิด หรือคำที่ไม่ควรถูกแปลง? [เปิด issue](../../issues) บอกได้เลย
