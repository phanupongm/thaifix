// ThaiFix — แก้ข้อความที่พิมพ์ผิดภาษา (ลืมสลับ ไทย/อังกฤษ)
// กด ⌥⌘L : ถ้าลากเลือกข้อความไว้ จะแปลงข้อความนั้น
//          ถ้าไม่ได้เลือก จะแปลงคำท้ายบรรทัดที่พิมพ์ผิดภาษาให้เอง
// แล้วสลับภาษาคีย์บอร์ดให้ตรงกับภาษาที่ตั้งใจพิมพ์

import Cocoa
import Carbon

// MARK: - ตารางแป้น เกษมณี <-> QWERTY (ใช้ unicodeScalars เพราะสระ/วรรณยุกต์ไทยเป็นตัวประกอบ)

let engKeys = Array(
    "`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./" +
    "~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:\"ZXCVBNM<>?"
    .unicodeScalars)
let thaiKeys = Array(
    "_ๅ/-ภถุึคตจขชๆไำพะัีรนยบลฃฟหกดเ้่าสวงผปแอิืทมใฝ" +
    "%+๑๒๓๔ู฿๕๖๗๘๙๐\"ฎฑธํ๊ณฯญฐ,ฅฤฆฏโฌ็๋ษศซ.()ฉฮฺ์?ฒฬฦ"
    .unicodeScalars)

let eng2thai: [Unicode.Scalar: Unicode.Scalar] = Dictionary(uniqueKeysWithValues: zip(engKeys, thaiKeys))
let thai2eng: [Unicode.Scalar: Unicode.Scalar] = Dictionary(uniqueKeysWithValues: zip(thaiKeys, engKeys))

enum Script { case thai, latin, neutral }

func isThai(_ s: Unicode.Scalar) -> Bool { (0x0E00...0x0E7F).contains(s.value) }
func isLatinLetter(_ s: Unicode.Scalar) -> Bool {
    (0x41...0x5A).contains(s.value) || (0x61...0x7A).contains(s.value)
}

func script(of text: String) -> Script {
    var t = 0, l = 0
    for s in text.unicodeScalars { if isThai(s) { t += 1 } else if isLatinLetter(s) { l += 1 } }
    if t == 0 && l == 0 { return .neutral }
    return t >= l ? .thai : .latin
}

/// แปลงข้อความไปอีกฝั่งของแป้นพิมพ์ คืนค่า (ข้อความใหม่, ผลลัพธ์เป็นไทยไหม)
func convert(_ text: String) -> (String, Bool) {
    let toThai = script(of: text) != .thai
    let table = toThai ? eng2thai : thai2eng
    var out = String.UnicodeScalarView()
    for s in text.unicodeScalars {
        if s == " " || s == "\n" || s == "\t" { out.append(s); continue }
        out.append(table[s] ?? s)
    }
    return (String(out), toThai)
}

/// ใช้ตอนไม่ได้เลือกข้อความ: หา "ช่วงท้ายบรรทัด" ที่เป็นภาษาเดียวกับคำสุดท้าย แล้วแปลงเฉพาะช่วงนั้น
func convertTrailingRun(of line: String) -> (String, Bool)? {
    // แยกเป็นโทเค็น โดยเก็บช่องว่างไว้ด้วย
    var tokens: [String] = []
    var cur = ""
    var curIsSpace: Bool? = nil
    for ch in line {
        let sp = ch == " " || ch == "\t"
        if curIsSpace != nil && sp != curIsSpace! { tokens.append(cur); cur = "" }
        cur.append(ch); curIsSpace = sp
    }
    if !cur.isEmpty { tokens.append(cur) }

    var target: Script? = nil
    var start = tokens.count
    var i = tokens.count - 1
    while i >= 0 {
        let tok = tokens[i]
        let sc = tok.trimmingCharacters(in: .whitespaces).isEmpty ? Script.neutral : script(of: tok)
        if sc != .neutral {
            if target == nil { target = sc }
            else if sc != target { break }
        }
        start = i
        i -= 1
    }
    guard target != nil else { return nil }
    // ไม่เอาโทเค็นกลาง ๆ (ช่องว่าง/ตัวเลข) ที่หัวช่วง
    while start < tokens.count, script(of: tokens[start]) == .neutral { start += 1 }
    let prefix = tokens[..<start].joined()
    let suffix = tokens[start...].joined()
    let (conv, toThai) = convert(suffix)
    return (prefix + conv, toThai)
}

// MARK: - คีย์บอร์ด / คลิปบอร์ด

func postKey(_ key: Int, _ flags: CGEventFlags) {
    let src = CGEventSource(stateID: .combinedSessionState)
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(key), keyDown: down)
        e?.flags = flags
        e?.post(tap: .cghidEventTap)
    }
}

func savePasteboard() -> [[NSPasteboard.PasteboardType: Data]] {
    (NSPasteboard.general.pasteboardItems ?? []).map { item in
        var d: [NSPasteboard.PasteboardType: Data] = [:]
        for t in item.types { if let data = item.data(forType: t) { d[t] = data } }
        return d
    }
}

func restorePasteboard(_ saved: [[NSPasteboard.PasteboardType: Data]]) {
    let pb = NSPasteboard.general
    pb.clearContents()
    let items: [NSPasteboardItem] = saved.map { d in
        let item = NSPasteboardItem()
        for (t, data) in d { item.setData(data, forType: t) }
        return item
    }
    if !items.isEmpty { pb.writeObjects(items) }
}

func switchInputSource(toThai: Bool) {
    let filter: [String: Any] = [
        kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
        kTISPropertyInputSourceIsSelectCapable as String: true,
    ]
    guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?
            .takeRetainedValue() as? [TISInputSource] else { return }
    for src in list {
        guard let p = TISGetInputSourceProperty(src, kTISPropertyInputSourceLanguages) else { continue }
        let langs = Unmanaged<CFArray>.fromOpaque(p).takeUnretainedValue() as? [String] ?? []
        if toThai ? langs.contains("th") : langs.first == "en" {
            TISSelectInputSource(src); return
        }
    }
}

// MARK: - ตัวทำงานหลัก

final class Fixer {
    static let shared = Fixer()
    private var busy = false

    func run() {
        guard !busy else { return }
        busy = true
        waitForModifiersReleased { self.step1() }
    }

    // รอให้ผู้ใช้ปล่อย ⌥⌘ ก่อน ไม่งั้นปุ่มที่เราจำลองจะปนกัน
    private func waitForModifiersReleased(tries: Int = 0, then: @escaping () -> Void) {
        let f = CGEventSource.flagsState(.combinedSessionState)
        if tries > 40 || !(f.contains(.maskCommand) || f.contains(.maskAlternate)
                            || f.contains(.maskShift) || f.contains(.maskControl)) {
            then(); return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
            self.waitForModifiersReleased(tries: tries + 1, then: then)
        }
    }

    private func step1() {
        let saved = savePasteboard()
        let pb = NSPasteboard.general
        let before = pb.changeCount
        postKey(kVK_ANSI_C, .maskCommand)                       // copy ส่วนที่เลือก

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if pb.changeCount != before, let sel = pb.string(forType: .string), !sel.isEmpty {
                let (out, toThai) = convert(sel)
                self.paste(out, toThai: toThai, saved: saved)
            } else {
                // ไม่ได้เลือกอะไร → เลือกจากเคอร์เซอร์ไปต้นบรรทัด
                postKey(kVK_LeftArrow, [.maskCommand, .maskShift])
                let before2 = pb.changeCount
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    postKey(kVK_ANSI_C, .maskCommand)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        guard pb.changeCount != before2,
                              let line = pb.string(forType: .string),
                              let (out, toThai) = convertTrailingRun(of: line) else {
                            postKey(kVK_RightArrow, [])           // ยกเลิกการเลือก
                            restorePasteboard(saved); self.busy = false; return
                        }
                        self.paste(out, toThai: toThai, saved: saved)
                    }
                }
            }
        }
    }

    private func paste(_ text: String, toThai: Bool, saved: [[NSPasteboard.PasteboardType: Data]]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        postKey(kVK_ANSI_V, .maskCommand)
        switchInputSource(toThai: toThai)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            restorePasteboard(saved)
            self.busy = false
        }
    }
}

// MARK: - แอป menu bar + คีย์ลัด

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "ก/A"
        let menu = NSMenu()
        menu.addItem(withTitle: "แก้ข้อความที่พิมพ์ผิดภาษา  ⌥⌘L", action: #selector(fixNow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "ออก", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action == #selector(fixNow) { item.target = self }
        statusItem.menu = menu

        // ขอสิทธิ์ Accessibility (จำเป็นสำหรับการจำลองปุ่ม copy/paste)
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        // คีย์ลัด ⌥⌘L
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { Fixer.shared.run() }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x54484658), id: 1) // 'THFX'
        RegisterEventHotKey(UInt32(kVK_ANSI_L), UInt32(cmdKey | optionKey), id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    @objc func fixNow() { Fixer.shared.run() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
