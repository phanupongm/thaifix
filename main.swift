// ThaiFix — แก้ข้อความที่พิมพ์ผิดภาษา (ลืมสลับ ไทย/อังกฤษ)
// กด ⌥⌘L : ถ้าลากเลือกข้อความไว้ จะแปลงข้อความนั้น
//          ถ้าไม่ได้เลือก จะแปลงคำท้ายบรรทัดที่พิมพ์ผิดภาษาให้เอง
// แล้วสลับภาษาคีย์บอร์ดให้ตรงกับภาษาที่ตั้งใจพิมพ์

import Cocoa
import Carbon

// MARK: - ตารางแป้น เกษมณี <-> QWERTY (ใช้ unicodeScalars เพราะสระ/วรรณยุกต์ไทยเป็นตัวประกอบ)

let engKeys = Array((
    "`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./" +
    "~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:\"ZXCVBNM<>?"
    ).unicodeScalars)
let thaiKeys = Array((
    "_ๅ/-ภถุึคตจขชๆไำพะัีรนยบลฃฟหกดเ้่าสวงผปแอิืทมใฝ" +
    "%+๑๒๓๔ู฿๕๖๗๘๙๐\"ฎฑธํ๊ณฯญฐ,ฅฤฆฏโฌ็๋ษศซ.()ฉฮฺ์?ฒฬฦ"
    ).unicodeScalars)

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

// MARK: - ตัดสินทีละคำ ว่าคำไหนพิมพ์ผิดภาษา

/// คำอังกฤษ/ศัพท์เทคนิคที่ไม่ต้องแปลงแน่ ๆ (เพิ่มได้)
let keepWords: Set<String> = [
    "repo","git","api","app","ui","ux","url","pr","ok","okay","login","logout","email","wifi",
    "line","fb","ig","dev","prod","config","json","css","html","js","ts","sql","db","npm","ai",
    "admin","server","update","deploy","bug","fix","test","build","code","file","link","online",
]

let thaiConsonants = Set("กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ".unicodeScalars)
let thaiLeadVowels = Set("เแโใไ".unicodeScalars)
let thaiMarks = Set("ัิีึืฺุู็่้๊๋์ํ".unicodeScalars)   // ต้องตามหลังพยัญชนะ
let thaiTones = Set("่้๊๋".unicodeScalars)
let thaiNoStart = Set("ะาำๅฯๆ".unicodeScalars).union(thaiMarks)

/// ข้อความไทยนี้ "เป็นไทยที่เป็นไปได้" ไหม (เช็กกฎการเขียนแบบหยาบ ๆ)
func looksLikeValidThai(_ t: String) -> Bool {
    let sc = Array(t.unicodeScalars).filter { isThai($0) }
    guard let first = sc.first else { return false }
    if thaiNoStart.contains(first) { return false }
    if let last = sc.last, thaiLeadVowels.contains(last) { return false }
    for i in 0..<sc.count {
        let c = sc[i]
        let prev: Unicode.Scalar? = i > 0 ? sc[i-1] : nil
        if thaiMarks.contains(c) || c == "ำ" || c == "ะ" {
            guard let p = prev, thaiConsonants.contains(p) || thaiMarks.contains(p) else { return false }
            if thaiTones.contains(c) && thaiTones.contains(p) { return false }
            if thaiMarks.contains(c) && c == p { return false }
        }
        if thaiLeadVowels.contains(c), i + 1 < sc.count, !thaiConsonants.contains(sc[i+1]) { return false }
    }
    // ข้อความไทยที่มีอักษรแปลก ๆ ปน (ไม่ใช่ไทย/ช่องว่าง) ถือว่าไม่น่าใช่
    return t.unicodeScalars.allSatisfy { isThai($0) || " .,!?\"'()-".unicodeScalars.contains($0) }
}

func isEnglishWord(_ w: String) -> Bool {
    let lower = w.lowercased()
    if keepWords.contains(lower) { return true }
    #if canImport(AppKit)
    let r = NSSpellChecker.shared.checkSpelling(of: lower, startingAt: 0, language: "en",
                                                wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
    return r.location == NSNotFound
    #else
    return false
    #endif
}

let mappedPunct = Set(";'[],./\\`-=".unicodeScalars)

/// คำอังกฤษนี้จริง ๆ คือไทยที่ลืมสลับแป้นไหม
func latinIsMistyped(_ tok: String) -> Bool {
    if tok.contains("://") || tok.contains("@") || tok.contains("#") { return false }
    let sc = Array(tok.unicodeScalars)
    let thai = convert(tok).0
    // มีเครื่องหมาย/ตัวเลขแทรกกลางตัวอักษร เช่น l;ylfu, [kwfh, 9yh'
    let hasLetters = sc.contains { isLatinLetter($0) }
    if hasLetters && sc.count >= 2 {
        let inner = sc.dropFirst().dropLast()
        let odd = inner.contains { mappedPunct.contains($0) || (0x30...0x39).contains($0.value) }
            || (sc.first.map { "[;'`".unicodeScalars.contains($0) } ?? false)
        if odd && looksLikeValidThai(thai) { return true }
    }
    // ตัดเครื่องหมายหัวท้ายแล้วเหลือแต่ตัวอักษร
    let core = tok.trimmingCharacters(in: .punctuationCharacters)
    guard !core.isEmpty, core.unicodeScalars.allSatisfy(isLatinLetter) else { return false }
    if isEnglishWord(core) { return false }
    // ชื่อเฉพาะ/ตัวพิมพ์ใหญ่ผสม (iPhone, GitHub) ปล่อยไว้
    if core.dropFirst().contains(where: { $0.isUppercase }) && core.contains(where: { $0.isLowercase }) { return false }
    return looksLikeValidThai(thai)
}

/// คำไทยนี้จริง ๆ คืออังกฤษที่ลืมสลับแป้นไหม
func thaiIsMistyped(_ tok: String) -> Bool {
    let eng = convert(tok).0
    if !looksLikeValidThai(tok) { return true }
    let core = eng.trimmingCharacters(in: .punctuationCharacters)
    return core.count >= 3 && core.unicodeScalars.allSatisfy(isLatinLetter) && isEnglishWord(core)
}

/// คำไทยที่ส่วนท้ายพิมพ์ผิดติดกันโดยไม่มีช่องว่าง เช่น "เสียงในำสำอำืสฟิ" → ("เสียงใน", "ำสำอำืสฟิ")
/// หาจุดแบ่งที่ส่วนหน้าเป็นไทยที่ถูก ส่วนท้ายเป็นไทยที่ผิด และแปลงแล้วได้ตัวอักษรอังกฤษล้วน (เอาส่วนท้ายที่ยาวที่สุด)
func splitThaiTail(_ tok: String) -> (String, String)? {
    let sc = Array(tok.unicodeScalars)
    guard sc.count >= 2 else { return nil }
    for k in 1..<sc.count {
        var p = String.UnicodeScalarView(); p.append(contentsOf: sc[..<k])
        var q = String.UnicodeScalarView(); q.append(contentsOf: sc[k...])
        let prefix = String(p), suffix = String(q)
        guard looksLikeValidThai(prefix), !looksLikeValidThai(suffix) else { continue }
        var eng = convert(suffix).0     // ห้ามตัดเครื่องหมายด้านหน้า (ไม่งั้น "งใน..." → "'.o..." จะผ่าน)
        while let l = eng.last, l.isPunctuation { eng.removeLast() }
        if eng.count >= 2 && eng.unicodeScalars.allSatisfy(isLatinLetter) { return (prefix, suffix) }
    }
    return nil
}

func tokenize(_ line: String) -> [String] {
    var tokens: [String] = []
    var cur = ""
    var curIsSpace: Bool? = nil
    for ch in line {
        let sp = ch == " " || ch == "\t" || ch == "\n"
        if let c = curIsSpace, c != sp { tokens.append(cur); cur = "" }
        cur.append(ch); curIsSpace = sp
    }
    if !cur.isEmpty { tokens.append(cur) }
    return tokens
}

/// แก้เฉพาะคำที่พิมพ์ผิดภาษา คืนค่า (ข้อความใหม่, ภาษาที่ควรสลับไป: true=ไทย) หรือ nil ถ้าไม่มีอะไรต้องแก้
func smartFix(_ text: String) -> (String, Bool)? {
    var changed = false
    var lastLang: Bool? = nil
    let out = tokenize(text).map { tok -> String in
        switch script(of: tok) {
        case .latin:
            if latinIsMistyped(tok) { changed = true; lastLang = true; return convert(tok).0 }
            lastLang = false
        case .thai:
            if thaiIsMistyped(tok) {
                changed = true; lastLang = false
                if let (p, q) = splitThaiTail(tok) { return p + convert(q).0 }
                return convert(tok).0
            }
            lastLang = true
        case .neutral: break
        }
        return tok
    }.joined()
    guard changed, let lang = lastLang else { return nil }
    return (out, lang)
}

/// กดคีย์ลัดแล้วแต่ไม่เจอคำที่ผิดชัด ๆ → แปลงคำสุดท้ายให้ (ผู้ใช้ตั้งใจกดแล้ว ดีกว่าไม่ทำอะไร)
func lastWordFix(_ line: String) -> (String, Bool)? {
    var toks = tokenize(line)
    guard let i = toks.lastIndex(where: { script(of: $0) != .neutral }) else { return nil }
    let (c, toThai) = convert(toks[i])
    toks[i] = c
    return (toks.joined(), toThai)
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
            if pb.changeCount != before, let sel = pb.string(forType: .string), !sel.isEmpty,
               !sel.hasSuffix("\n") {   // บางแอป (VS Code) ⌘C ตอนไม่ได้เลือก = copy ทั้งบรรทัด
                let (out, toThai) = smartFix(sel) ?? convert(sel)
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
                              let result = smartFix(line) ?? lastWordFix(line) else {
                            postKey(kVK_RightArrow, [])           // ยกเลิกการเลือก
                            restorePasteboard(saved); self.busy = false; return
                        }
                        self.paste(result.0, toThai: result.1, saved: saved)
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
        if let img = Bundle.main.image(forResource: "MenuIcon") {
            img.isTemplate = true            // ให้เปลี่ยนสีตามโหมดมืด/สว่างเอง
            statusItem.button?.image = img
        } else {
            statusItem.button?.title = "ก/A"
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "แก้ข้อความที่พิมพ์ผิดภาษา  ⌥⌘L", action: #selector(fixNow), keyEquivalent: "")
        menu.addItem(withTitle: "เปิดหน้าต่าง ThaiFix", action: #selector(showWindow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "ออก", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        statusItem.menu = menu

        // ขอสิทธิ์ Accessibility (จำเป็นสำหรับการจำลองปุ่ม copy/paste)
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        // คีย์ลัด ⌥⌘L
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async {
                if AXIsProcessTrusted() { Fixer.shared.run() }
                else { (NSApp.delegate as? AppDelegate)?.showWindow() }
            }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x54484658), id: 1) // 'THFX'
        RegisterEventHotKey(UInt32(kVK_ANSI_L), UInt32(cmdKey | optionKey), id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)

        showWindow()
        // อัปเดตสถานะสิทธิ์ในหน้าต่างทุก 1 วินาที (หลังผู้ใช้ไปเปิดสวิตช์ใน System Settings)
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in self.refreshStatus() }
    }

    // เปิดแอปซ้ำ (ดับเบิลคลิกตอนที่ทำงานอยู่แล้ว) → โชว์หน้าต่าง
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow(); return true
    }

    @objc func fixNow() { Fixer.shared.run() }

    // MARK: หน้าต่างสถานะ
    var window: NSWindow?
    let statusLabel = NSTextField(labelWithString: "")
    let permButton = NSButton(title: "เปิดการตั้งค่า Accessibility", target: nil, action: nil)

    func refreshStatus() {
        let ok = AXIsProcessTrusted()
        statusLabel.stringValue = ok ? "✅  พร้อมใช้งาน — ThaiFix ทำงานอยู่เบื้องหลัง"
                                     : "⚠️  ยังไม่ได้รับสิทธิ์ Accessibility — คีย์ลัดจะยังไม่ทำงาน"
        statusLabel.textColor = ok ? .systemGreen : .systemOrange
        permButton.isHidden = ok
    }

    @objc func openAXSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc func showWindow() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "ThaiFix"
            w.isReleasedWhenClosed = false

            let icon = NSImageView(image: NSApp.applicationIconImage)
            icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 72).isActive = true

            let title = NSTextField(labelWithString: "ThaiFix")
            title.font = .systemFont(ofSize: 22, weight: .bold)

            let how = NSTextField(wrappingLabelWithString:
                "พิมพ์ผิดภาษาเมื่อไหร่ กด  ⌥ Option + ⌘ Command + L\n" +
                "แอปจะแก้เฉพาะคำที่ผิด และสลับแป้นภาษาให้\n\n" +
                "ปิดหน้าต่างนี้ได้เลย แอปยังทำงานต่อ\n" +
                "เปิดหน้าต่างนี้อีกครั้ง: ดับเบิลคลิก ThaiFix ในโฟลเดอร์ Applications")
            how.font = .systemFont(ofSize: 13)
            how.alignment = .center

            permButton.target = self; permButton.action = #selector(openAXSettings)
            permButton.bezelStyle = .rounded
            let quit = NSButton(title: "ปิดโปรแกรม ThaiFix", target: NSApp, action: #selector(NSApplication.terminate(_:)))
            quit.bezelStyle = .rounded

            let stack = NSStackView(views: [icon, title, statusLabel, how, permButton, quit])
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.spacing = 10
            stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
            w.contentView = stack
            window = w
        }
        refreshStatus()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// โหมดวัดความแม่นยำ: ThaiFix --eval inputs.txt outputs.txt  (ใช้ใน CI ร่วมกับ tests/score.py)
if let i = CommandLine.arguments.firstIndex(of: "--eval"), CommandLine.arguments.count > i + 2 {
    let inPath = CommandLine.arguments[i + 1], outPath = CommandLine.arguments[i + 2]
    let text = (try? String(contentsOfFile: inPath, encoding: .utf8)) ?? ""
    var out = ""
    for line in text.split(separator: "\n", omittingEmptySubsequences: false).dropLast() {
        let l = String(line)
        let smart = smartFix(l)
        let final = smart ?? lastWordFix(l)
        out += (smart?.0 ?? "<NONE>") + "\t" + (final?.0 ?? "<NONE>") + "\n"
    }
    try? out.write(toFile: outPath, atomically: true, encoding: .utf8)
    exit(0)
}

if CommandLine.arguments.contains("--test") {
    for t in ["l;ylfu", "อัพเดท repo มาให้หน่อย", "อัพเดท repo ทาให้หน่อย", "ำสำ", "นัดกัน l;ylfu",
              "hello world", "้ำสสน ไนพสก", "เปิด GitHub แล้ว push code", "ช่วย fix bug หน่อย", "iPhone ใหม่",
              "ช่วยออกแบบ charector เสียงในำสำอำืสฟิ", "ช่วยออกแบบ charector เสียงใน ำสำอำืสฟิ"] {
        print("TEST: \(t) => \(smartFix(t).map { $0.0 } ?? "(ไม่แก้)")")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
