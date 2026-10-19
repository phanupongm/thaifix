// ตรรกะการแปลงแป้น เกษมณี <-> QWERTY และการตัดสินทีละคำ
// ต้องตรงกับ tests/ref.py และ main.swift (CI วัดผลทั้งสามตัวด้วยชุดทดสอบเดียวกัน)
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

        static readonly HashSet<string> KeepWords = new HashSet<string>((
            "repo git api app ui ux url pr ok okay login logout email wifi line fb ig dev prod config json css " +
            "html js ts sql db npm ai admin server update deploy bug fix test build code file link online " +
            "plugin plugins bluetooth spotify canva capcut elevenlabs youtube tiktok facebook instagram google gmail " +
            "chatgpt claude notion slack zoom netflix shopee lazada grab iphone ipad macbook android github gitlab " +
            "docker python javascript typescript react figma photoshop excel powerpoint wordpress shopify " +
            "backend frontend dev devops startup app apps blog vlog podcast emoji hashtag selfie")
            .Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries));

        static readonly HashSet<string> ShortEnglish = new HashSet<string>(
            "in on at to up my we us it is go do no of by or an be ok ai ui pr".Split(' '));

        const string ThaiConsonants = "กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ";
        const string ThaiLeadVowels = "เแโใไ";
        const string ThaiMarks = "ัิีึืฺุู็่้๊๋์ํ";
        const string ThaiTones = "่้๊๋";
        const string ThaiNoStart = "ะาำๅฯๆ" + ThaiMarks;
        const string ThaiAllowedPunct = " .,!?\"'()-";
        const string SentPunct = ".,!?:;";
        const string PunctThai = "[]\\;'";

        static HashSet<string> english, thai;
        static int thaiMaxLen = 1;

        static Converter()
        {
            for (int i = 0; i < EngKeys.Length; i++)
            {
                E2T[EngKeys[i]] = ThaiKeys[i];
                T2E[ThaiKeys[i]] = EngKeys[i];
            }
        }

        static HashSet<string> LoadGz(string suffix)
        {
            var set = new HashSet<string>();
            var asm = Assembly.GetExecutingAssembly();
            var name = asm.GetManifestResourceNames().FirstOrDefault(n => n.EndsWith(suffix));
            if (name == null) return set;
            using (var s = asm.GetManifestResourceStream(name))
            using (var gz = new GZipStream(s, CompressionMode.Decompress))
            using (var r = new StreamReader(gz, Encoding.UTF8))
            {
                string line;
                while ((line = r.ReadLine()) != null) { line = line.Trim(); if (line.Length > 0) set.Add(line); }
            }
            return set;
        }

        static HashSet<string> English { get { if (english == null) english = LoadGz("words.txt.gz"); return english; } }
        static HashSet<string> Thai
        {
            get
            {
                if (thai == null) { thai = LoadGz("thai.txt.gz"); thaiMaxLen = thai.Count == 0 ? 1 : thai.Max(w => w.Length); }
                return thai;
            }
        }

        public static void Warmup() { var a = English.Count; var b = Thai.Count; }

        static bool IsThai(char c) => c >= '฀' && c <= '๿';
        static bool IsLatin(char c) => (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
        static bool AllLatin(string s) => s.Length > 0 && s.All(IsLatin);

        enum Script { Thai, Latin, Neutral }

        static Script ScriptOf(string t)
        {
            int th = 0, la = 0;
            foreach (var c in t) { if (IsThai(c)) th++; else if (IsLatin(c)) la++; }
            if (th == 0 && la == 0) return Script.Neutral;
            return th >= la ? Script.Thai : Script.Latin;
        }

        /// แปลงข้อความไปอีกฝั่งของแป้น
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

        static string ConvToThai(string t)
        {
            var sb = new StringBuilder(t.Length);
            foreach (var c in t) { char m; sb.Append(E2T.TryGetValue(c, out m) ? m : c); }
            return sb.ToString();
        }

        static bool ValidThai(string t)
        {
            var sc = t.Where(IsThai).ToArray();
            if (sc.Length == 0) return false;
            if (ThaiNoStart.IndexOf(sc[0]) >= 0 || ThaiLeadVowels.IndexOf(sc[sc.Length - 1]) >= 0) return false;
            for (int i = 0; i < sc.Length; i++)
            {
                char c = sc[i];
                char p = i > 0 ? sc[i - 1] : '\0';
                bool isMark = ThaiMarks.IndexOf(c) >= 0;
                if (isMark || c == 'ำ' || c == 'ะ')
                {
                    if (c == 'ะ' && p == 'า') continue;                         // เกาะ เคราะห์
                    if (p == '\0' || (ThaiConsonants.IndexOf(p) < 0 && ThaiMarks.IndexOf(p) < 0)) return false;
                    if (ThaiTones.IndexOf(c) >= 0 && ThaiTones.IndexOf(p) >= 0) return false;
                    if (isMark && c == p) return false;
                }
                if (ThaiLeadVowels.IndexOf(c) >= 0 && i + 1 < sc.Length && ThaiConsonants.IndexOf(sc[i + 1]) < 0) return false;
            }
            return t.All(c => IsThai(c) || ThaiAllowedPunct.IndexOf(c) >= 0);
        }

        static bool Segmentable(string t)
        {
            var dict = Thai;
            var runs = new List<string>();
            var cur = new StringBuilder();
            foreach (var c in t)
            {
                if (IsThai(c) && c != 'ๆ') cur.Append(c);
                else if (cur.Length > 0) { runs.Add(cur.ToString()); cur.Clear(); }
            }
            if (cur.Length > 0) runs.Add(cur.ToString());
            foreach (var r in runs)
            {
                int n = r.Length;
                var ok = new bool[n + 1]; ok[0] = true;
                for (int i = 0; i < n; i++)
                {
                    if (!ok[i]) continue;
                    for (int j = i + 1; j <= Math.Min(n, i + thaiMaxLen); j++)
                        if (!ok[j] && dict.Contains(r.Substring(i, j - i))) ok[j] = true;
                }
                if (!ok[n]) return false;
            }
            return true;
        }

        static bool LikelyThai(string t) => ValidThai(t) && Segmentable(t);
        static bool OkThai(string t) =>
            ValidThai(t) || (Segmentable(t) && t.All(c => IsThai(c) || ThaiAllowedPunct.IndexOf(c) >= 0));

        static bool IsEnglishWord(string w)
        {
            var l = w.ToLowerInvariant();
            return KeepWords.Contains(l) || English.Contains(l);
        }

        static string StripSentPunct(string t)
        {
            int e = t.Length;
            while (e > 0 && SentPunct.IndexOf(t[e - 1]) >= 0) e--;
            return t.Substring(0, e);
        }

        static string PlainEnglish(string tok)
        {
            var core = StripSentPunct(tok);
            if (AllLatin(core)) return core;
            var parts = core.Split('\'');
            if (parts.Length == 2 && AllLatin(parts[0]) && AllLatin(parts[1]) && parts[1].Length <= 2) return core;
            return null;
        }

        static int FirstWordLen(string t)
        {
            var dict = Thai;
            int best = 0;
            for (int j = 1; j <= Math.Min(t.Length, thaiMaxLen); j++)
                if (dict.Contains(t.Substring(0, j))) best = j;
            return best;
        }

        static bool LatinIsMistyped(string tok)
        {
            if (tok.Contains("://") || tok.Contains("@") || tok.Contains("#")) return false;
            string thaiText = Conv(tok);
            string core = PlainEnglish(tok);
            if (core == null) return tok.Any(IsLatin) && LikelyThai(thaiText);
            if (core.Contains("'") || IsEnglishWord(core)) return false;
            return LikelyThai(thaiText);
        }

        static bool ThaiIsMistyped(string tok)
        {
            if (!OkThai(tok)) return true;
            string core = StripSentPunct(Conv(tok));
            return core.Length >= 3 && AllLatin(core) && IsEnglishWord(core);
        }

        static int Cmp(int[] a, int[] b)
        {
            for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return a[i].CompareTo(b[i]);
            return 0;
        }

        static bool SplitThaiTail(string tok, out string prefix, out string suffix)
        {
            prefix = suffix = null;
            string whole = StripSentPunct(Conv(tok));
            if (AllLatin(whole) && (IsEnglishWord(whole) || !OkThai(tok.Substring(0, 1)))) return false;
            int[] best = null;
            for (int k = 1; k < tok.Length; k++)
            {
                string p = tok.Substring(0, k), q = tok.Substring(k);
                if (!OkThai(p) || OkThai(q)) continue;
                string e = StripSentPunct(Conv(q));
                if (e.Length < 2 || !AllLatin(e)) continue;
                var score = new[] { IsEnglishWord(e) ? 1 : 0, Segmentable(p) ? 1 : 0, e.Length };
                if (best == null || Cmp(score, best) > 0) { best = score; prefix = p; suffix = q; }
            }
            return best != null;
        }

        static bool SplitThaiValidTail(string tok, out string prefix, out string suffix)
        {
            prefix = suffix = null;
            if (Segmentable(tok)) return false;
            int bestLen = 0;
            for (int k = 1; k < tok.Length - 2; k++)
            {
                string p = tok.Substring(0, k), q = tok.Substring(k);
                if (!Segmentable(p)) continue;
                string e = StripSentPunct(Conv(q));
                if (e.Length >= 3 && AllLatin(e) && (KeepWords.Contains(e.ToLowerInvariant()) || (e.Length >= 4 && IsEnglishWord(e)))
                    && e.Length > bestLen)
                { bestLen = e.Length; prefix = p; suffix = q; }
            }
            return bestLen > 0;
        }

        static bool SplitLatinTail(string tok, out string prefix, out string suffix)
        {
            prefix = suffix = null;
            int[] best = null;
            bool found = false;
            string whole = ConvToThai(tok);
            if (LikelyThai(whole)) best = new[] { FirstWordLen(whole), 0 };
            for (int k = tok.Length - 1; k >= 2; k--)
            {
                string p = tok.Substring(0, k), q = tok.Substring(k);
                if (!AllLatin(p)) continue;
                string pl = p.ToLowerInvariant();
                if (!(KeepWords.Contains(pl) || ShortEnglish.Contains(pl) || (k >= 3 && IsEnglishWord(p)))) continue;
                string pe = PlainEnglish(q);
                if (pe != null && IsEnglishWord(pe)) continue;
                string th = Conv(q);
                if (!LikelyThai(th)) continue;
                var score = new[] { FirstWordLen(th), k };
                if (best == null || Cmp(score, best) > 0) { best = score; prefix = p; suffix = q; found = true; }
            }
            return found;
        }

        static bool NeutralIsMistyped(string tok) =>
            tok.Length >= 2 && tok.Any(c => PunctThai.IndexOf(c) >= 0) && LikelyThai(ConvToThai(tok));

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
                string p, q;
                switch (ScriptOf(tok))
                {
                    case Script.Latin:
                        string pe = PlainEnglish(tok);
                        bool plainEng = pe != null && IsEnglishWord(pe);
                        if (!plainEng && SplitLatinTail(tok, out p, out q))
                        { changed = true; lastLang = true; outTokens.Add(p + Conv(q)); continue; }
                        if (LatinIsMistyped(tok)) { changed = true; lastLang = true; outTokens.Add(Conv(tok)); continue; }
                        lastLang = false;
                        break;
                    case Script.Thai:
                        if (ThaiIsMistyped(tok))
                        {
                            changed = true; lastLang = false;
                            outTokens.Add(SplitThaiTail(tok, out p, out q) ? p + Conv(q) : Conv(tok));
                            continue;
                        }
                        if (SplitThaiValidTail(tok, out p, out q))
                        { changed = true; lastLang = false; outTokens.Add(p + Conv(q)); continue; }
                        lastLang = true;
                        break;
                    default:
                        if (NeutralIsMistyped(tok)) { changed = true; lastLang = true; outTokens.Add(ConvToThai(tok)); continue; }
                        break;
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
