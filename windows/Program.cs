// ThaiFix for Windows — แอปบนถาดระบบ (system tray)
// กด Ctrl+Alt+L : ถ้าเลือกข้อความไว้ จะแปลงข้อความนั้น
//                 ถ้าไม่ได้เลือก จะแก้คำที่พิมพ์ผิดภาษาในบรรทัดปัจจุบัน
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

namespace ThaiFix
{
    static class Native
    {
        [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint mods, uint vk);
        [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
        [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
        [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vk);
        [DllImport("user32.dll")] public static extern uint GetClipboardSequenceNumber();
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr w, IntPtr l);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr LoadKeyboardLayout(string id, uint flags);

        public const uint MOD_ALT = 1, MOD_CONTROL = 2, MOD_NOREPEAT = 0x4000;
        public const int WM_HOTKEY = 0x312;
        public const uint KEYUP = 2;
        public const byte VK_CONTROL = 0x11, VK_SHIFT = 0x10, VK_MENU = 0x12, VK_HOME = 0x24, VK_END = 0x23,
                          VK_C = 0x43, VK_V = 0x56, VK_LWIN = 0x5B, VK_RWIN = 0x5C;

        public static void Combo(params byte[] keys)
        {
            foreach (var k in keys) keybd_event(k, 0, IsExtended(k) ? 1u : 0u, UIntPtr.Zero);
            for (int i = keys.Length - 1; i >= 0; i--) keybd_event(keys[i], 0, (IsExtended(keys[i]) ? 1u : 0u) | KEYUP, UIntPtr.Zero);
        }
        static bool IsExtended(byte k) => k == VK_HOME || k == VK_END;

        public static bool AnyModifierDown()
        {
            foreach (var vk in new[] { VK_CONTROL, VK_SHIFT, VK_MENU, VK_LWIN, VK_RWIN })
                if ((GetAsyncKeyState(vk) & 0x8000) != 0) return true;
            return false;
        }

        public static void SwitchLayout(bool toThai)
        {
            var hkl = LoadKeyboardLayout(toThai ? "0000041E" : "00000409", 1 /*KLF_ACTIVATE*/);
            PostMessage(GetForegroundWindow(), 0x50 /*WM_INPUTLANGCHANGEREQUEST*/, IntPtr.Zero, hkl);
        }
    }

    class HotkeyWindow : NativeWindow, IDisposable
    {
        public event Action Pressed;
        public HotkeyWindow()
        {
            CreateHandle(new CreateParams());
            Ok = Native.RegisterHotKey(Handle, 1, Native.MOD_CONTROL | Native.MOD_ALT | Native.MOD_NOREPEAT, (uint)Keys.L);
        }
        public bool Ok { get; }
        protected override void WndProc(ref Message m)
        {
            if (m.Msg == Native.WM_HOTKEY) Pressed?.Invoke();
            base.WndProc(ref m);
        }
        public void Dispose() { Native.UnregisterHotKey(Handle, 1); DestroyHandle(); }
    }

    class TrayApp : ApplicationContext
    {
        readonly NotifyIcon tray;
        readonly HotkeyWindow hotkey;
        bool busy;
        const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

        public TrayApp()
        {
            var icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? SystemIcons.Application;
            var menu = new ContextMenuStrip();
            menu.Items.Add("แก้ข้อความที่พิมพ์ผิดภาษา  (Ctrl+Alt+L)", null, (s, e) => Fix());
            var startup = new ToolStripMenuItem("เปิดอัตโนมัติเมื่อเปิดเครื่อง") { Checked = IsStartup(), CheckOnClick = true };
            startup.CheckedChanged += (s, e) => SetStartup(startup.Checked);
            menu.Items.Add(startup);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("ปิดโปรแกรม ThaiFix", null, (s, e) => ExitThread());

            tray = new NotifyIcon { Icon = icon, Text = "ThaiFix — Ctrl+Alt+L", ContextMenuStrip = menu, Visible = true };
            tray.DoubleClick += (s, e) => ShowHelp();

            hotkey = new HotkeyWindow();
            hotkey.Pressed += Fix;

            if (hotkey.Ok)
                tray.ShowBalloonTip(4000, "ThaiFix พร้อมใช้งาน",
                    "พิมพ์ผิดภาษาเมื่อไหร่ กด Ctrl + Alt + L\nไอคอนอยู่ที่ถาดมุมขวาล่าง (อาจอยู่ในลูกศร ^)", ToolTipIcon.Info);
            else
                MessageBox.Show("คีย์ลัด Ctrl+Alt+L ถูกโปรแกรมอื่นใช้อยู่ ThaiFix จึงยังรับคีย์ลัดไม่ได้\n" +
                                "ยังใช้งานผ่านเมนูที่ไอคอนบนถาดได้", "ThaiFix", MessageBoxButtons.OK, MessageBoxIcon.Warning);

            Task.Run(() => Converter.Warmup());   // โหลดพจนานุกรมรอไว้
        }

        void ShowHelp() => MessageBox.Show(
            "พิมพ์ผิดภาษาเพราะลืมสลับแป้น? กด  Ctrl + Alt + L\n\n" +
            "• ลากเลือกข้อความไว้ → แปลงเฉพาะส่วนที่เลือก\n" +
            "• ไม่ได้เลือก → แก้เฉพาะคำที่ผิดในบรรทัดนั้น\n" +
            "• แปลงผิด กด Ctrl + Z เพื่อย้อนกลับ\n\n" +
            "ทำงานออฟไลน์ ไม่ส่งข้อมูลออกนอกเครื่อง",
            "ThaiFix", MessageBoxButtons.OK, MessageBoxIcon.Information);

        static bool IsStartup()
        {
            using (var k = Registry.CurrentUser.OpenSubKey(RunKey))
                return k?.GetValue("ThaiFix") != null;
        }
        static void SetStartup(bool on)
        {
            using (var k = Registry.CurrentUser.OpenSubKey(RunKey, true))
            {
                if (on) k.SetValue("ThaiFix", "\"" + Application.ExecutablePath + "\"");
                else k.DeleteValue("ThaiFix", false);
            }
        }

        // ---------- คลิปบอร์ด ----------
        static IDataObject SaveClipboard()
        {
            try
            {
                var src = Clipboard.GetDataObject();
                if (src == null) return null;
                var copy = new DataObject();
                foreach (var f in src.GetFormats(false))
                {
                    try { var d = src.GetData(f, false); if (d != null) copy.SetData(f, d); } catch { }
                }
                return copy;
            }
            catch { return null; }
        }
        static void RestoreClipboard(IDataObject saved)
        {
            try { if (saved != null) Clipboard.SetDataObject(saved, true); else Clipboard.Clear(); } catch { }
        }
        static string ReadClipboardText()
        {
            for (int i = 0; i < 5; i++)
            {
                try { return Clipboard.ContainsText() ? Clipboard.GetText() : null; }
                catch { Thread.Sleep(30); }
            }
            return null;
        }
        static void SetClipboardText(string s)
        {
            for (int i = 0; i < 5; i++)
            {
                try { Clipboard.SetText(s); return; } catch { Thread.Sleep(30); }
            }
        }

        // ---------- ตัวทำงานหลัก ----------
        async void Fix()
        {
            if (busy) return;
            busy = true;
            try
            {
                // รอให้ผู้ใช้ปล่อย Ctrl/Alt ก่อน
                for (int i = 0; i < 40 && Native.AnyModifierDown(); i++) await Task.Delay(25);

                var saved = SaveClipboard();
                uint seq = Native.GetClipboardSequenceNumber();
                Native.Combo(Native.VK_CONTROL, Native.VK_C);
                await Task.Delay(120);

                string sel = Native.GetClipboardSequenceNumber() != seq ? ReadClipboardText() : null;
                string result; bool toThai = false;

                // บางแอป (VS Code) Ctrl+C ตอนไม่ได้เลือก = copy ทั้งบรรทัดพร้อม \n → ถือว่าไม่ได้เลือก
                if (!string.IsNullOrEmpty(sel) && !sel.EndsWith("\n"))
                {
                    result = Converter.SmartFix(sel, out toThai) ?? Converter.Convert(sel, out toThai);
                }
                else
                {
                    Native.Combo(Native.VK_SHIFT, Native.VK_HOME);          // เลือกจากเคอร์เซอร์ไปต้นบรรทัด
                    await Task.Delay(50);
                    seq = Native.GetClipboardSequenceNumber();
                    Native.Combo(Native.VK_CONTROL, Native.VK_C);
                    await Task.Delay(120);
                    string line = Native.GetClipboardSequenceNumber() != seq ? ReadClipboardText() : null;
                    result = line == null ? null
                           : (Converter.SmartFix(line, out toThai) ?? Converter.LastWordFix(line, out toThai));
                    if (result == null)
                    {
                        Native.Combo(Native.VK_END);                        // ยกเลิกการเลือก
                        RestoreClipboard(saved);
                        return;
                    }
                }

                SetClipboardText(result);
                Native.Combo(Native.VK_CONTROL, Native.VK_V);
                Native.SwitchLayout(toThai);
                await Task.Delay(300);
                RestoreClipboard(saved);
            }
            finally { busy = false; }
        }

        protected override void ExitThreadCore()
        {
            hotkey.Dispose();
            tray.Visible = false;
            tray.Dispose();
            base.ExitThreadCore();
        }
    }

    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            // โหมดทดสอบสำหรับ CI: ThaiFix.exe --test out.txt
            if (args.Length >= 2 && args[0] == "--test")
            {
                var cases = new[] { "l;ylfu", "อัพเดท repo มาให้หน่อย", "ำสำ", "นัดกัน l;ylfu", "hello world",
                                    "้ำสสน ไนพสก", "เปิด GitHub แล้ว push code", "ช่วย fix bug หน่อย", "iPhone ใหม่",
                                    "ช่วยออกแบบ charector เสียงในำสำอำืสฟิ", "ช่วยออกแบบ charector เสียงใน ำสำอำืสฟิ" };
                var lines = new List<string>();
                foreach (var t in cases)
                {
                    bool th;
                    lines.Add("TEST: " + t + " => " + (Converter.SmartFix(t, out th) ?? "(ไม่แก้)"));
                }
                File.WriteAllLines(args[1], lines, new System.Text.UTF8Encoding(false));
                return;
            }

            bool created;
            using (new Mutex(true, "ThaiFix.SingleInstance", out created))
            {
                if (!created)
                {
                    MessageBox.Show("ThaiFix ทำงานอยู่แล้ว ดูไอคอนที่ถาดมุมขวาล่าง (อาจอยู่ในลูกศร ^)\nกด Ctrl + Alt + L เพื่อใช้งาน",
                                    "ThaiFix", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new TrayApp());
            }
        }
    }
}
