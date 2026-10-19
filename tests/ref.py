#!/usr/bin/env python3
"""ตัวอ้างอิงตรรกะของ ThaiFix เป็น Python — ใช้จูนเร็ว ๆ แล้วพอร์ตไป main.swift / Converter.cs
ใช้: ref.py inputs.txt outputs.txt   (รูปแบบเดียวกับ --eval ของแอป)
"""
import gzip, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
E = "`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:\"ZXCVBNM<>?"
T = "_ๅ/-ภถุึคตจขชๆไำพะัีรนยบลฃฟหกดเ้่าสวงผปแอิืทมใฝ%+๑๒๓๔ู฿๕๖๗๘๙๐\"ฎฑธํ๊ณฯญฐ,ฅฤฆฏโฌ็๋ษศซ.()ฉฮฺ์?ฒฬฦ"
E2T, T2E = dict(zip(E, T)), dict(zip(T, E))

KEEP = set("""repo git api app ui ux url pr ok okay login logout email wifi line fb ig dev prod config json css
html js ts sql db npm ai admin server update deploy bug fix test build code file link online
plugin plugins bluetooth spotify canva capcut elevenlabs youtube tiktok facebook instagram google gmail
chatgpt claude notion slack zoom netflix shopee lazada grab iphone ipad macbook android github gitlab
docker python javascript typescript react figma photoshop excel powerpoint wordpress shopify
backend frontend dev devops startup app apps blog vlog podcast emoji hashtag selfie
""".split())
with gzip.open(os.path.join(HERE, "..", "windows", "words.txt.gz"), "rt", encoding="utf-8") as f:
    DICT = set(w.strip() for w in f)

with gzip.open(os.path.join(HERE, "..", "windows", "thai.txt.gz"), "rt", encoding="utf-8") as f:
    THAI = set(w.strip() for w in f if w.strip())
MAXW = max(map(len, THAI))

CONS = set("กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ")
LEAD = set("เแโใไ")
MARKS = set("ัิีึืฺุู็่้๊๋์ํ")
TONES = set("่้๊๋")
NOSTART = set("ะาำๅฯๆ") | MARKS
SENT_PUNCT = ".,!?:;"


def is_thai(c): return "฀" <= c <= "๿"
def is_latin(c): return ("a" <= c <= "z") or ("A" <= c <= "Z")


def script(t):
    th = sum(map(is_thai, t)); la = sum(map(is_latin, t))
    if th == 0 and la == 0: return "n"
    return "th" if th >= la else "en"


def convert(t):
    to_thai = script(t) != "th"
    tb = E2T if to_thai else T2E
    return "".join(c if c in " \t\n" else tb.get(c, c) for c in t), to_thai


def conv(t): return convert(t)[0]


def valid_thai(t):
    sc = [c for c in t if is_thai(c)]
    if not sc: return False
    if sc[0] in NOSTART or sc[-1] in LEAD: return False
    for i, c in enumerate(sc):
        p = sc[i - 1] if i else None
        if c in MARKS or c in "ำะ":
            if c == "ะ" and p == "า": continue                     # เกาะ เคราะห์
            if p is None or not (p in CONS or p in MARKS): return False
            if c in TONES and p in TONES: return False
            if c in MARKS and c == p: return False
        if c in LEAD and i + 1 < len(sc) and sc[i + 1] not in CONS: return False
    return all(is_thai(c) or c in " .,!?\"'()-" for c in t)


def segmentable(t):
    """ตัดคำได้ครบด้วยคำ/พยางค์ไทยในพจนานุกรม (ข้ามช่องว่างและเครื่องหมาย)"""
    runs, cur = [], ""
    for c in t:
        if is_thai(c) and c != "ๆ": cur += c
        else:
            if cur: runs.append(cur); cur = ""
    if cur: runs.append(cur)
    for r in runs:
        n = len(r); ok = [False] * (n + 1); ok[0] = True
        for i in range(n):
            if not ok[i]: continue
            for j in range(i + 1, min(n, i + MAXW) + 1):
                if r[i:j] in THAI: ok[j] = True
        if not ok[n]: return False
    return True


def likely_thai(t):
    """ใช้ตรวจ 'ผลที่แปลงออกมา' ว่าเป็นไทยจริง — เข้มกว่า valid_thai"""
    return valid_thai(t) and segmentable(t)


def is_eng(w):
    w = w.lower()
    return w in KEEP or w in DICT


def strip_sent_punct(t):
    while t and t[-1] in SENT_PUNCT: t = t[:-1]
    return t


def plain_english(tok):
    """คำอังกฤษธรรมดา (ตัวอักษรล้วน อาจมีเครื่องหมายวรรคตอนท้าย หรือ contraction แบบ don't)"""
    core = strip_sent_punct(tok)
    if core and all(map(is_latin, core)): return core
    if core.count("'") == 1:
        a, b = core.split("'")
        if a and b and all(map(is_latin, a + b)) and len(b) <= 2: return core
    return None


def latin_mistyped(tok):
    if "://" in tok or "@" in tok or "#" in tok: return False
    thai = conv(tok)
    core = plain_english(tok)
    if core is None:
        # มีเครื่องหมาย/ตัวเลขปนกับตัวอักษร เช่น l;ylfu, -v, ]v'
        return any(map(is_latin, tok)) and likely_thai(thai)
    if "'" in core: return False
    if is_eng(core): return False
    return likely_thai(thai)          # iPhone/GitHub แปลงแล้วไม่ใช่ไทยจริง จึงไม่โดนแปลง


def ok_thai(t):
    """ไทยที่ผู้ใช้พิมพ์ 'ดูถูก' ไหม — ผ่อนปรน: ผ่านกฎ หรือ ตัดคำได้"""
    return valid_thai(t) or (segmentable(t) and all(is_thai(c) or c in " .,!?\"'()-" for c in t))


def first_word_len(t):
    """ความยาวคำไทยที่ยาวที่สุดที่ขึ้นต้นข้อความ (ใช้เลือกจุดแบ่งที่ดีที่สุด)"""
    best = 0
    for j in range(1, min(len(t), MAXW) + 1):
        if t[:j] in THAI: best = j
    return best


def thai_mistyped(tok):
    if not ok_thai(tok): return True
    core = strip_sent_punct(conv(tok))
    return len(core) >= 3 and all(map(is_latin, core)) and is_eng(core)


def split_thai_tail(tok):
    """ไทยถูก + ส่วนท้ายที่พิมพ์ผิด (แปลงแล้วเป็นอังกฤษล้วน) → (prefix, suffix) ที่ดีที่สุด"""
    whole = strip_sent_punct(conv(tok))
    if whole and all(map(is_latin, whole)) and (is_eng(whole) or not ok_thai(tok[:1])): return None
    best, best_score = None, None
    for k in range(1, len(tok)):
        p, q = tok[:k], tok[k:]
        if not ok_thai(p) or ok_thai(q): continue
        e = strip_sent_punct(conv(q))
        if len(e) < 2 or not all(map(is_latin, e)): continue
        score = (is_eng(e), segmentable(p), len(e))
        if best_score is None or score > best_score: best, best_score = (p, q), score
    return best


def split_thai_valid_tail(tok):
    """ไทยที่ดูถูกทั้งคำ แต่ส่วนท้ายคือคำอังกฤษที่พิมพ์ผิด เช่น อยู่ในกพรอำ → อยู่ใน + drive"""
    if segmentable(tok): return None
    best, best_len = None, 0
    for k in range(1, len(tok) - 2):
        p, q = tok[:k], tok[k:]
        if not segmentable(p): continue
        e = strip_sent_punct(conv(q))
        if len(e) >= 3 and all(map(is_latin, e)) and (e.lower() in KEEP or (len(e) >= 4 and is_eng(e))):
            if len(e) > best_len: best, best_len = (p, q), len(e)
    return best


SHORT_EN = set("in on at to up my we us it is go do no of by or an be ok ai ui pr".split())


def split_latin_tail(tok):
    """คำอังกฤษถูก + ส่วนท้ายที่เป็นไทยพิมพ์ผิด เช่น loginsojvp → login + หน่อย
    เลือกจุดที่ทำให้คำไทยคำแรกยาวที่สุด (storm|หนักมาก ดีกว่า storms|นักมาก)"""
    best, best_score = None, None
    whole = conv_to_thai(tok)
    if likely_thai(whole): best_score = (first_word_len(whole), 0)      # แปลงทั้งคำก็เป็นตัวเลือก
    for k in range(len(tok) - 1, 1, -1):
        p, q = tok[:k], tok[k:]
        if not all(map(is_latin, p)): continue
        pl = p.lower()
        if not (pl in KEEP or pl in SHORT_EN or (len(p) >= 3 and is_eng(p))): continue
        if plain_english(q) and is_eng(plain_english(q)): continue
        th = conv(q)
        if not likely_thai(th): continue
        score = (first_word_len(th), len(p))
        if best_score is None or score > best_score: best, best_score = (p, q), score
    return best


PUNCT_THAI = set("[]\\;'")


def neutral_mistyped(tok):
    """คำที่มีแต่เครื่องหมาย เช่น ][ = ลบ, ]' = ลง"""
    return len(tok) >= 2 and any(c in PUNCT_THAI for c in tok) and likely_thai(conv_to_thai(tok))


def conv_to_thai(t): return "".join(E2T.get(c, c) for c in t)


def tokenize(line):
    toks, cur, sp = [], "", None
    for ch in line:
        s = ch in " \t\n"
        if sp is not None and s != sp: toks.append(cur); cur = ""
        cur += ch; sp = s
    if cur: toks.append(cur)
    return toks


def smart_fix(text):
    changed, last = False, None
    out = []
    for tok in tokenize(text):
        s = script(tok)
        if s == "en":
            sp = split_latin_tail(tok) if not (plain_english(tok) and is_eng(plain_english(tok))) else None
            if sp:
                changed, last = True, True
                out.append(sp[0] + conv(sp[1])); continue
            if latin_mistyped(tok):
                changed, last = True, True
                out.append(conv(tok)); continue
            last = False
        elif s == "th":
            if thai_mistyped(tok):
                changed, last = True, False
                sp = split_thai_tail(tok)
                out.append(sp[0] + conv(sp[1]) if sp else conv(tok)); continue
            sp = split_thai_valid_tail(tok)
            if sp:
                changed, last = True, False
                out.append(sp[0] + conv(sp[1])); continue
            last = True
        elif neutral_mistyped(tok):
            changed, last = True, True
            out.append(conv_to_thai(tok)); continue
        out.append(tok)
    if not changed or last is None: return None
    return "".join(out)


def last_word_fix(line):
    toks = tokenize(line)
    for i in range(len(toks) - 1, -1, -1):
        if script(toks[i]) != "n":
            toks[i] = conv(toks[i]); return "".join(toks)
    return None


if __name__ == "__main__":
    lines = open(sys.argv[1], encoding="utf-8").read().split("\n")[:-1]
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        for l in lines:
            s = smart_fix(l)
            fin = s if s is not None else last_word_fix(l)
            f.write(f"{s if s is not None else '<NONE>'}\t{fin if fin is not None else '<NONE>'}\n")
