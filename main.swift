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

// MARK: - ตัดสินทีละคำ ว่าคำไหนพิมพ์ผิดภาษา (ตรรกะเดียวกับ tests/ref.py และ windows/Converter.cs)

/// คำอังกฤษ/ศัพท์เทคนิค/ชื่อแบรนด์ที่ไม่ต้องแปลง
let keepWords: Set<String> = Set("""
repo git api app ui ux url pr ok okay login logout email wifi line fb ig dev prod config json css
html js ts sql db npm ai admin server update deploy bug fix test build code file link online
plugin plugins bluetooth spotify canva capcut elevenlabs youtube tiktok facebook instagram google gmail
chatgpt claude notion slack zoom netflix shopee lazada grab iphone ipad macbook android github gitlab
docker python javascript typescript react figma photoshop excel powerpoint wordpress shopify
backend frontend dev devops startup app apps blog vlog podcast emoji hashtag selfie
""".split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init))

let shortEnglish: Set<String> = Set("in on at to up my we us it is go do no of by or an be ok ai ui pr".split(separator: " ").map(String.init))

/// โหลดรายการคำจาก Resources ของแอป หรือจากโฟลเดอร์ใน THAIFIX_DATA (ใช้ตอนรันทดสอบใน CI)
func loadWordSet(_ name: String) -> Set<String> {
    var paths: [String] = []
    if let p = Bundle.main.path(forResource: name, ofType: "txt") { paths.append(p) }
    if let d = ProcessInfo.processInfo.environment["THAIFIX_DATA"] { paths.append(d + "/" + name + ".txt") }
    for p in paths {
        if let s = try? String(contentsOfFile: p, encoding: .utf8) {
            var set = Set<String>()
            for line in s.split(separator: "\n") {
                let w = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !w.isEmpty { set.insert(w) }
            }
            return set
        }
    }
    return []
}

let englishDict = loadWordSet("words")
let thaiDict = loadWordSet("thai")
let thaiMaxLen = thaiDict.map { $0.unicodeScalars.count }.max() ?? 1

typealias Scalars = [Unicode.Scalar]
func scalars(_ s: String) -> Scalars { Array(s.unicodeScalars) }
func str(_ a: ArraySlice<Unicode.Scalar>) -> String { var v = String.UnicodeScalarView(); v.append(contentsOf: a); return String(v) }
func str(_ a: Scalars) -> String { str(a[...]) }

let thaiConsonants = Set("กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ".unicodeScalars)
let thaiLeadVowels = Set("เแโใไ".unicodeScalars)
let thaiMarks = Set("ัิีึืฺุู็่้๊๋์ํ".unicodeScalars)
let thaiTones = Set("่้๊๋".unicodeScalars)
let thaiNoStart = Set("ะาำๅฯๆ".unicodeScalars).union(thaiMarks)
let thaiAllowedPunct = Set(" .,!?\"'()-".unicodeScalars)
let sentPunct = Set(".,!?:;".unicodeScalars)
let punctThai = Set("[]\;'".unicodeScalars)

func allLatin(_ s: String) -> Bool { !s.isEmpty && s.unicodeScalars.allSatisfy(isLatinLetter) }

/// กฎการสะกดไทยแบบคร่าว ๆ
func validThai(_ t: String) -> Bool {
    let sc = t.unicodeScalars.filter(isThai)
    guard let first = sc.first, let last = sc.last else { return false }
    if thaiNoStart.contains(first) || thaiLeadVowels.contains(last) { return false }
    for i in 0..<sc.count {
        let c = sc[i]
        let p: Unicode.Scalar? = i > 0 ? sc[i - 1] : nil
        if thaiMarks.contains(c) || c == "ำ" || c == "ะ" {
            if c == "ะ" && p == "า" { continue }                       // เกาะ เคราะห์
            guard let pp = p, thaiConsonants.contains(pp) || thaiMarks.contains(pp) else { return false }
            if thaiTones.contains(c) && thaiTones.contains(pp) { return false }
            if thaiMarks.contains(c) && c == pp { return false }
        }
        if thaiLeadVowels.contains(c), i + 1 < sc.count, !thaiConsonants.contains(sc[i + 1]) { return false }
    }
    return t.unicodeScalars.allSatisfy { isThai($0) || thaiAllowedPunct.contains($0) }
}

/// ตัดคำได้ครบด้วยคำ/พยางค์ไทยในพจนานุกรม
func segmentable(_ t: String) -> Bool {
    var runs: [Scalars] = [], cur: Scalars = []
    for c in t.unicodeScalars {
        if isThai(c) && c != "ๆ" { cur.append(c) } else if !cur.isEmpty { runs.append(cur); cur = [] }
    }
    if !cur.isEmpty { runs.append(cur) }
    for r in runs {
        let n = r.count
        var ok = [Bool](repeating: false, count: n + 1); ok[0] = true
        for i in 0..<n where ok[i] {
            for j in (i + 1)...min(n, i + thaiMaxLen) where !ok[j] {
                if thaiDict.contains(str(r[i..<j])) { ok[j] = true }
            }
        }
        if !ok[n] { return false }
    }
    return true
}

func likelyThai(_ t: String) -> Bool { validThai(t) && segmentable(t) }
func okThai(_ t: String) -> Bool {
    validThai(t) || (segmentable(t) && t.unicodeScalars.allSatisfy { isThai($0) || thaiAllowedPunct.contains($0) })
}

func isEnglishWord(_ w: String) -> Bool {
    let l = w.lowercased()
    return keepWords.contains(l) || englishDict.contains(l)
}

func stripSentPunct(_ t: String) -> String {
    var sc = scalars(t)
    while let l = sc.last, sentPunct.contains(l) { sc.removeLast() }
    return str(sc)
}

/// คำอังกฤษธรรมดา (ตัวอักษรล้วน อาจมีวรรคตอนท้าย หรือ contraction แบบ don't)
func plainEnglish(_ tok: String) -> String? {
    let core = stripSentPunct(tok)
    if allLatin(core) { return core }
    let parts = core.split(separator: "'", omittingEmptySubsequences: false).map(String.init)
    if parts.count == 2, allLatin(parts[0]), allLatin(parts[1]), parts[1].count <= 2 { return core }
    return nil
}

func convToThai(_ t: String) -> String {
    var v = String.UnicodeScalarView()
    for c in t.unicodeScalars { v.append(eng2thai[c] ?? c) }
    return String(v)
}
func conv(_ t: String) -> String { convert(t).0 }

func firstWordLen(_ t: String) -> Int {
    let sc = scalars(t)
    var best = 0
    if sc.isEmpty { return 0 }
    for j in 1...min(sc.count, thaiMaxLen) where thaiDict.contains(str(sc[..<j])) { best = j }
    return best
}

/// คำอังกฤษนี้จริง ๆ คือไทยที่ลืมสลับแป้นไหม
func latinIsMistyped(_ tok: String) -> Bool {
    if tok.contains("://") || tok.contains("@") || tok.contains("#") { return false }
    let thai = conv(tok)
    guard let core = plainEnglish(tok) else {
        return tok.unicodeScalars.contains(where: isLatinLetter) && likelyThai(thai)
    }
    if core.contains("'") || isEnglishWord(core) { return false }
    return likelyThai(thai)
}

/// คำไทยนี้จริง ๆ คืออังกฤษที่ลืมสลับแป้นไหม
func thaiIsMistyped(_ tok: String) -> Bool {
    if !okThai(tok) { return true }
    let core = stripSentPunct(conv(tok))
    return core.unicodeScalars.count >= 3 && allLatin(core) && isEnglishWord(core)
}

/// ไทยถูก + ส่วนท้ายที่พิมพ์ผิด เช่น "เสียงในำสำอำืสฟิ" → ("เสียงใน", "ำสำอำืสฟิ")
func splitThaiTail(_ tok: String) -> (String, String)? {
    let whole = stripSentPunct(conv(tok))
    let sc = scalars(tok)
    if allLatin(whole) && (isEnglishWord(whole) || !okThai(str(sc[..<1]))) { return nil }
    var best: (String, String)? = nil
    var bestScore: (Int, Int, Int)? = nil
    for k in 1..<max(sc.count, 1) {
        let p = str(sc[..<k]), q = str(sc[k...])
        if !okThai(p) || okThai(q) { continue }
        let e = stripSentPunct(conv(q))
        if e.unicodeScalars.count < 2 || !allLatin(e) { continue }
        let score = (isEnglishWord(e) ? 1 : 0, segmentable(p) ? 1 : 0, e.unicodeScalars.count)
        if bestScore == nil || score > bestScore! { best = (p, q); bestScore = score }
    }
    return best
}

/// ไทยที่ดูถูกทั้งคำ แต่ส่วนท้ายคือคำอังกฤษที่พิมพ์ผิด เช่น อยู่ในกพรอำ → อยู่ใน + drive
func splitThaiValidTail(_ tok: String) -> (String, String)? {
    if segmentable(tok) { return nil }
    let sc = scalars(tok)
    guard sc.count > 3 else { return nil }
    var best: (String, String)? = nil, bestLen = 0
    for k in 1..<(sc.count - 2) {
        let p = str(sc[..<k]), q = str(sc[k...])
        if !segmentable(p) { continue }
        let e = stripSentPunct(conv(q))
        let n = e.unicodeScalars.count
        if n >= 3 && allLatin(e) && (keepWords.contains(e.lowercased()) || (n >= 4 && isEnglishWord(e))) && n > bestLen {
            best = (p, q); bestLen = n
        }
    }
    return best
}

/// อังกฤษถูก + ส่วนท้ายที่เป็นไทยพิมพ์ผิด เช่น loginsojvp → login + หน่อย
func splitLatinTail(_ tok: String) -> (String, String)? {
    let sc = scalars(tok)
    var best: (String, String)? = nil
    var bestScore: (Int, Int)? = nil
    let whole = convToThai(tok)
    if likelyThai(whole) { bestScore = (firstWordLen(whole), 0) }
    guard sc.count >= 3 else { return nil }
    for k in stride(from: sc.count - 1, through: 2, by: -1) {
        let p = str(sc[..<k]), q = str(sc[k...])
        if !allLatin(p) { continue }
        let pl = p.lowercased()
        if !(keepWords.contains(pl) || shortEnglish.contains(pl) || (k >= 3 && isEnglishWord(p))) { continue }
        if let pe = plainEnglish(q), isEnglishWord(pe) { continue }
        let th = conv(q)
        if !likelyThai(th) { continue }
        let score = (firstWordLen(th), k)
        if bestScore == nil || score > bestScore! { best = (p, q); bestScore = score }
    }
    return best
}

/// คำที่มีแต่เครื่องหมาย เช่น ][ = ลบ
func neutralIsMistyped(_ tok: String) -> Bool {
    tok.unicodeScalars.count >= 2 && tok.unicodeScalars.contains(where: punctThai.contains) && likelyThai(convToThai(tok))
}

/// แยกคำด้วยช่องว่าง — ต้องวนทีละ scalar (ถ้าวนทีละ Character, " ำ" จะรวมเป็นตัวเดียว)
func tokenize(_ line: String) -> [String] {
    var tokens: [String] = []
    var cur = String.UnicodeScalarView()
    var curIsSpace: Bool? = nil
    for c in line.unicodeScalars {
        let sp = c == " " || c == "\t" || c == "\n"
        if let x = curIsSpace, x != sp { tokens.append(String(cur)); cur = String.UnicodeScalarView() }
        cur.append(c); curIsSpace = sp
    }
    if !cur.isEmpty { tokens.append(String(cur)) }
    return tokens
}

/// แก้เฉพาะคำที่พิมพ์ผิดภาษา คืนค่า (ข้อความใหม่, ภาษาที่ควรสลับไป: true=ไทย) หรือ nil ถ้าไม่มีอะไรต้องแก้
func smartFix(_ text: String) -> (String, Bool)? {
    var changed = false
    var lastLang: Bool? = nil
    var out: [String] = []
    for tok in tokenize(text) {
        switch script(of: tok) {
        case .latin:
            let isPlainEnglish = plainEnglish(tok).map(isEnglishWord) ?? false
            if !isPlainEnglish, let (p, q) = splitLatinTail(tok) {
                changed = true; lastLang = true; out.append(p + conv(q)); continue
            }
            if latinIsMistyped(tok) { changed = true; lastLang = true; out.append(conv(tok)); continue }
            lastLang = false
        case .thai:
            if thaiIsMistyped(tok) {
                changed = true; lastLang = false
                if let (p, q) = splitThaiTail(tok) { out.append(p + conv(q)) } else { out.append(conv(tok)) }
                continue
            }
            if let (p, q) = splitThaiValidTail(tok) {
                changed = true; lastLang = false; out.append(p + conv(q)); continue
            }
            lastLang = true
        case .neutral:
            if neutralIsMistyped(tok) { changed = true; lastLang = true; out.append(convToThai(tok)); continue }
        }
        out.append(tok)
    }
    guard changed, let lang = lastLang else { return nil }
    return (out.joined(), lang)
}

/// กดคีย์ลัดแล้วแต่ไม่เจอคำที่ผิดชัด ๆ → แปลงคำสุดท้ายให้
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
