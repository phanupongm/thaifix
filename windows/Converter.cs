// ตรรกะการแปลงแป้น เกษมณี <-> QWERTY และการตัดสินทีละคำ (พอร์ตจาก main.swift)
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Text;

namespace ThaiFix
{
    public static class Converter
    {
        const string EngKeys =
            "`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./" +
            "~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:\"ZXCVBNM<>?";
        const string ThaiKeys =
            "_ๅ/-ภถุึคตจขชๆไำพะัีรนยบลฃฟหกดเ้่าสวงผปแอิืทมใฝ" +
            "%+๑๒๓๔ู฿๕๖๗๘๙๐\"ฎฑธํ๊ณฯญฐ,ฅฤฆฏโฌ็๋ษศซ.()ฉฮฺ์?ฒฬฦ";

        static readonly Dictionary<char, char> E2T = new Dictionary<char, char>();
        static readonly Dictionary<char, char> T2E = new Dictionary<char, char>();

        static readonly HashSet<string> KeepWords = new HashSet<string>(new[] {
            "repo","git","api","app","ui","ux","url","pr","ok","okay","login","logout","email","wifi",
            "line","fb","ig","dev","prod","config","json","css","html","js","ts","sql","db","npm","ai",
            "admin","server","update","deploy","bug","fix","test","build","code","file","link","online",
        });

        static HashSet<string> dictionary;

        static readonly string ThaiConsonants = "กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ";
        static readonly string ThaiLeadVowels = "เแโใไ";
        static readonly string ThaiMarks = "ัิีึืฺุู็่้๊๋์ํ";
        static readonly string ThaiTones = "่้๊๋";
        static readonly string ThaiNoStart = "ะาำๅฯๆ" + "ัิีึืฺุู็่้๊๋์ํ";
        const string MappedPunct = ";'[],./\\`-=";

        static Converter()
        {
            for (int i = 0; i < EngKeys.Length; i++)
            {
                E2T[EngKeys[i]] = ThaiKeys[i];
                T2E[ThaiKeys[i]] = EngKeys[i];
            }
        }


        static HashSet<string> Dictionary
        {
            get
            {
                if (dictionary != null) return dictionary;
                var set = new HashSet<string>();
                var asm = Assembly.GetExecutingAssembly();
                var name = asm.GetManifestResourceNames().FirstOrDefault(n => n.EndsWith("words.txt.gz"));
                if (name != null)
                {
                    using (var s = asm.GetManifestResourceStream(name))
                    using (var gz = new GZipStream(s, CompressionMode.Decompress))
                    using (var r = new StreamReader(gz))
                    {
                        string line;
                        while ((line = r.ReadLine()) != null) set.Add(line.Trim());
                    }
                }
                dictionary = set;
                return set;
            }
        }

        public static void Warmup() { var _ = Dictionary.Count; }

        static bool IsThai(char c) => c >= '฀' && c <= '๿';
        static bool IsLatin(char c) => (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');

        enum Script { Thai, Latin, Neutral }

        static Script ScriptOf(string t)
        {
            int th = 0, la = 0;
            foreach (var c in t) { if (IsThai(c)) th++; else if (IsLatin(c)) la++; }
            if (th == 0 && la == 0) return Script.Neutral;
            return th >= la ? Script.Thai : Script.Latin;
        }

        /// แปลงทั้งข้อความไปอีกฝั่งของแป้น คืนค่าข้อความใหม่ และ toThai
        public static string Convert(string text, out bool toThai)
        {
            toThai = ScriptOf(text) != Script.Thai;
            var table = toThai ? E2T : T2E;
            var sb = new StringBuilder(text.Length);
            foreach (var c in text)
            {
                if (c == ' ' || c == '\n' || c == '\r' || c == '\t') { sb.Append(c); continue; }
                char m;
                sb.Append(table.TryGetValue(c, out m) ? m : c);
            }
            return sb.ToString();
        }

        static string Conv(string t) { bool _; return Convert(t, out _); }

        static bool LooksLikeValidThai(string t)
        {
            var sc = t.Where(IsThai).ToArray();
            if (sc.Length == 0) return false;
            if (ThaiNoStart.IndexOf(sc[0]) >= 0) return false;
            if (ThaiLeadVowels.IndexOf(sc[sc.Length - 1]) >= 0) return false;
            for (int i = 0; i < sc.Length; i++)
            {
                char c = sc[i];
                char? prev = i > 0 ? sc[i - 1] : (char?)null;
                bool isMark = ThaiMarks.IndexOf(c) >= 0;
                if (isMark || c == 'ำ' || c == 'ะ')
                {
                    if (prev == null) return false;
                    char p = prev.Value;
                    if (ThaiConsonants.IndexOf(p) < 0 && ThaiMarks.IndexOf(p) < 0) return false;
                    if (ThaiTones.IndexOf(c) >= 0 && ThaiTones.IndexOf(p) >= 0) return false;
                    if (isMark && c == p) return false;
                }
                if (ThaiLeadVowels.IndexOf(c) >= 0 && i + 1 < sc.Length && ThaiConsonants.IndexOf(sc[i + 1]) < 0)
                    return false;
            }
            const string allowed = " .,!?\"'()-";
            return t.All(c => IsThai(c) || allowed.IndexOf(c) >= 0);
        }

        static bool IsEnglishWord(string w)
        {
            var lower = w.ToLowerInvariant();
            return KeepWords.Contains(lower) || Dictionary.Contains(lower);
        }

        static string TrimPunct(string s) => s.Trim().Trim(".,!?;:'\"()[]{}<>-_/\\`~".ToCharArray());

        static bool LatinIsMistyped(string tok)
        {
            if (tok.Contains("://") || tok.Contains("@") || tok.Contains("#")) return false;
            string thai = Conv(tok);
            bool hasLetters = tok.Any(IsLatin);
            if (hasLetters && tok.Length >= 2)
            {
                bool odd = false;
                for (int i = 1; i < tok.Length - 1; i++)
                    if (MappedPunct.IndexOf(tok[i]) >= 0 || char.IsDigit(tok[i])) odd = true;
                if ("[;'`".IndexOf(tok[0]) >= 0) odd = true;
                if (odd && LooksLikeValidThai(thai)) return true;
            }
            string core = TrimPunct(tok);
            if (core.Length == 0 || !core.All(IsLatin)) return false;
            if (IsEnglishWord(core)) return false;
            // iPhone, GitHub
            if (core.Skip(1).Any(char.IsUpper) && core.Any(char.IsLower)) return false;
            return LooksLikeValidThai(thai);
        }

        static bool ThaiIsMistyped(string tok)
        {
            if (!LooksLikeValidThai(tok)) return true;
            string core = TrimPunct(Conv(tok));
            return core.Length >= 3 && core.All(IsLatin) && IsEnglishWord(core);
        }

        /// คำไทยที่ส่วนท้ายพิมพ์ผิดติดกัน เช่น "เสียงในำสำอำืสฟิ" → แบ่งเป็น "เสียงใน" + "ำสำอำืสฟิ"
        static bool SplitThaiTail(string tok, out string prefix, out string suffix)
        {
            prefix = suffix = null;
            for (int k = 1; k < tok.Length; k++)
            {
                string p = tok.Substring(0, k), q = tok.Substring(k);
                if (!LooksLikeValidThai(p) || LooksLikeValidThai(q)) continue;
                string eng = Conv(q).TrimEnd(".,!?;:'\"()".ToCharArray());   // ตัดเฉพาะท้าย
                if (eng.Length >= 2 && eng.All(IsLatin)) { prefix = p; suffix = q; return true; }
            }
            return false;
        }

        static List<string> Tokenize(string line)
        {
            var tokens = new List<string>();
            var cur = new StringBuilder();
            bool? curSpace = null;
            foreach (var ch in line)
            {
                bool sp = ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
                if (curSpace.HasValue && curSpace.Value != sp) { tokens.Add(cur.ToString()); cur.Clear(); }
                cur.Append(ch); curSpace = sp;
            }
            if (cur.Length > 0) tokens.Add(cur.ToString());
            return tokens;
        }

        /// แก้เฉพาะคำที่พิมพ์ผิดภาษา; null ถ้าไม่มีอะไรต้องแก้
        public static string SmartFix(string text, out bool toThai)
        {
            bool changed = false;
            bool? lastLang = null;
            var outTokens = new List<string>();
            foreach (var tok in Tokenize(text))
            {
                var s = ScriptOf(tok);
                if (s == Script.Latin)
                {
                    if (LatinIsMistyped(tok)) { changed = true; lastLang = true; outTokens.Add(Conv(tok)); continue; }
                    lastLang = false;
                }
                else if (s == Script.Thai)
                {
                    if (ThaiIsMistyped(tok))
                    {
                        changed = true; lastLang = false;
                        string p, q;
                        outTokens.Add(SplitThaiTail(tok, out p, out q) ? p + Conv(q) : Conv(tok));
                        continue;
                    }
                    lastLang = true;
                }
                outTokens.Add(tok);
            }
            toThai = lastLang ?? false;
            return changed && lastLang.HasValue ? string.Concat(outTokens) : null;
        }

        /// ไม่เจอคำผิดชัด ๆ → แปลงคำสุดท้าย
        public static string LastWordFix(string line, out bool toThai)
        {
            toThai = false;
            var toks = Tokenize(line);
            for (int i = toks.Count - 1; i >= 0; i--)
            {
                if (ScriptOf(toks[i]) == Script.Neutral) continue;
                toks[i] = Convert(toks[i], out toThai);
                return string.Concat(toks);
            }
            return null;
        }
    }
}
