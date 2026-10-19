#!/usr/bin/env python3
"""ให้คะแนนผลจากแอป

ใช้: score.py PLATFORM outputs.txt
  outputs.txt — หนึ่งบรรทัดต่อเคส: <smart>\t<final>
    smart = ผลจาก smartFix (หรือ <NONE> ถ้าไม่แก้)
    final = ผลที่แอปจะวางจริงในโหมดไม่ได้เลือกข้อความ (smartFix ?? lastWordFix, หรือ <NONE>)
เกณฑ์ผ่าน/ไม่ผ่านอยู่ใน tests/thresholds.json
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
NONE = "<NONE>"


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    platform, out_path = sys.argv[1], sys.argv[2]
    cases_file = sys.argv[3] if len(sys.argv) > 3 else "cases.tsv"
    cases = [l.rstrip("\n").split("\t") for l in open(os.path.join(HERE, cases_file), encoding="utf-8")]
    outs = [l.rstrip("\n").split("\t") for l in open(out_path, encoding="utf-8-sig")]
    if len(outs) != len(cases):
        print(f"::error::{platform}: got {len(outs)} outputs for {len(cases)} cases")
        sys.exit(1)

    stats, fails = {}, []
    for (cid, kind, inp, exp), (smart, final) in zip(cases, outs):
        ok = (smart == NONE) if kind == "clean" else (final == exp)
        s = stats.setdefault(kind, [0, 0])
        s[0] += ok
        s[1] += 1
        if not ok:
            got = smart if kind == "clean" else final
            fails.append((kind, inp, exp, got))

    fix_ok = sum(v[0] for k, v in stats.items() if k != "clean")
    fix_n = sum(v[1] for k, v in stats.items() if k != "clean")
    clean_ok, clean_n = stats.get("clean", [0, 0])
    fix_acc = 100.0 * fix_ok / max(fix_n, 1)
    fp_rate = 100.0 * (clean_n - clean_ok) / max(clean_n, 1)

    th = json.load(open(os.path.join(HERE, "thresholds.json")))[cases_file]
    passed = fix_acc >= th["min_fix_accuracy"] and fp_rate <= th["max_false_positive"]

    lines = [f"## ThaiFix accuracy — {platform}", "",
             f"**Fix accuracy: {fix_acc:.1f}%** ({fix_ok}/{fix_n}) · "
             f"**False positives: {fp_rate:.1f}%** ({clean_n - clean_ok}/{clean_n}) · "
             f"{'✅ pass' if passed else '❌ below threshold'}", "",
             "| kind | pass | total | % |", "|---|---|---|---|"]
    for k in ["clean", "tail1", "tail2", "glued", "middle", "first"]:
        if k in stats:
            a, n = stats[k]
            lines.append(f"| {k} | {a} | {n} | {100.0 * a / n:.0f}% |")
    lines += ["", f"### Failures ({len(fails)})", "", "| kind | input | expected | got |", "|---|---|---|---|"]
    for kind, inp, exp, got in fails:
        lines.append(f"| {kind} | `{inp}` | `{exp}` | `{got}` |")
    report = "\n".join(lines)

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(report + "\n")
    with open(os.path.join(HERE, f"report-{platform}.md"), "w", encoding="utf-8") as f:
        f.write(report + "\n")

    # annotation หนึ่งอันต่อแพลตฟอร์ม (อ่านผ่าน API ได้)
    per = " ".join(f"{k}={stats[k][0]}/{stats[k][1]}" for k in stats)
    sample = " || ".join(f"[{k}] {i} => {g} (want {e})" for k, i, e, g in fails[:25])
    print(f"::notice::ACC {platform} fix={fix_acc:.1f}% fp={fp_rate:.1f}% {per} || {sample}")
    if not passed:
        print(f"::error::{platform}: fix accuracy {fix_acc:.1f}% (min {th['min_fix_accuracy']}) / "
              f"false positives {fp_rate:.1f}% (max {th['max_false_positive']})")
        sys.exit(1)


if __name__ == "__main__":
    main()
