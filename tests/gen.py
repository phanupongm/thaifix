#!/usr/bin/env python3
"""สร้างเคสทดสอบ "ลืมสลับภาษา" จาก tests/corpus.txt

ผลลัพธ์: tests/cases.tsv  คอลัมน์ = id, kind, input, expected
  clean  : ประโยคที่ถูกอยู่แล้ว → ห้ามแก้ (วัด false positive)
  tail1  : คำสุดท้ายพิมพ์ผิดแป้น (มีเว้นวรรค)
  tail2  : สองคำสุดท้ายพิมพ์ผิดแป้น
  glued  : คำสุดท้ายพิมพ์ผิดแป้นและติดกับคำก่อนหน้า (ไม่มีเว้นวรรค)
  middle : คำกลางประโยคพิมพ์ผิดแป้น
  first  : คำแรกพิมพ์ผิดแป้น
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
E = "`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:\"ZXCVBNM<>?"
T = "_ๅ/-ภถุึคตจขชๆไำพะัีรนยบลฃฟหกดเ้่าสวงผปแอิืทมใฝ%+๑๒๓๔ู฿๕๖๗๘๙๐\"ฎฑธํ๊ณฯญฐ,ฅฤฆฏโฌ็๋ษศซ.()ฉฮฺ์?ฒฬฦ"
assert len(E) == len(T)
E2T = dict(zip(E, T))
T2E = dict(zip(T, E))


def is_thai(c): return "฀" <= c <= "๿"


def mistype(word):
    """พิมพ์คำนี้ด้วยแป้นอีกภาษา; None ถ้ามีตัวที่ไม่อยู่บนแป้น"""
    thai = any(is_thai(c) for c in word)
    table = T2E if thai else E2T
    out = []
    for c in word:
        if c not in table:
            return None
        out.append(table[c])
    return "".join(out)


def script(w):
    return "th" if any(is_thai(c) for c in w) else "en"


def main():
    sents = []
    with open(os.path.join(HERE, "corpus.txt"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                sents.append(line)

    cases = []

    def add(kind, inp, exp):
        if inp is None or "\t" in inp:
            return
        cases.append((f"{kind}-{len(cases)}", kind, inp, exp))

    for s in sents:
        w = s.split(" ")
        add("clean", s, s)
        if len(w) >= 2:
            m = mistype(w[-1])
            if m:
                add("tail1", " ".join(w[:-1] + [m]), s)
                # glued: เฉพาะตอนที่ภาษาเปลี่ยนระหว่างคำ (ไทยต่อไทยติดกันเป็นเรื่องปกติ)
                if script(w[-2]) != script(w[-1]):
                    add("glued", " ".join(w[:-2] + [w[-2] + m]), " ".join(w[:-2] + [w[-2] + w[-1]]))
            m0 = mistype(w[0])
            if m0:
                add("first", " ".join([m0] + w[1:]), s)
        if len(w) >= 3:
            m1, m2 = mistype(w[-2]), mistype(w[-1])
            if m1 and m2:
                add("tail2", " ".join(w[:-2] + [m1, m2]), s)
            mid = len(w) // 2
            if 0 < mid < len(w) - 1:
                mm = mistype(w[mid])
                if mm:
                    add("middle", " ".join(w[:mid] + [mm] + w[mid + 1:]), s)

    out = os.path.join(HERE, "cases.tsv")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        for c in cases:
            f.write("\t".join(c) + "\n")
    with open(os.path.join(HERE, "inputs.txt"), "w", encoding="utf-8", newline="\n") as f:
        for c in cases:
            f.write(c[2] + "\n")
    kinds = {}
    for c in cases:
        kinds[c[1]] = kinds.get(c[1], 0) + 1
    print(f"{len(sents)} sentences -> {len(cases)} cases {kinds}", file=sys.stderr)


if __name__ == "__main__":
    main()
