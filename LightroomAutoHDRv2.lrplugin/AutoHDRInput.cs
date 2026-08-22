using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Threading;

internal static class AutoHDRInput
{
    private const uint INPUT_KEYBOARD = 1;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    private const ushort VK_CONTROL = 0x11;
    private const ushort VK_SHIFT = 0x10;
    private const ushort VK_H = 0x48;

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public InputUnion data;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public KEYBDINPUT keyboard;
        [FieldOffset(0)] public MOUSEINPUT mouse;
        [FieldOffset(0)] public HARDWAREINPUT hardware;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort virtualKey;
        public ushort scanCode;
        public uint flags;
        public uint time;
        public UIntPtr extraInfo;
    }

    // INPUT contains a native union. On 64-bit Windows MOUSEINPUT is the
    // largest member (32 bytes), even when the event being sent is a keyboard
    // event. Including every native union member makes Marshal.SizeOf(INPUT)
    // match Win32's required 40-byte layout instead of the invalid 32 bytes.
    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint flags;
        public uint time;
        public UIntPtr extraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct HARDWAREINPUT
    {
        public uint message;
        public ushort parameterLow;
        public ushort parameterHigh;
    }

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, INPUT[] inputs, int size);

    private static string _logPath = Path.Combine(
        AppDomain.CurrentDomain.BaseDirectory,
        "AutoHDRInput.log");

    private static void Log(string message)
    {
        var identity = "<unavailable>";
        var session = -1;
        try { identity = WindowsIdentity.GetCurrent().Name; } catch { }
        try { session = Process.GetCurrentProcess().SessionId; } catch { }
        var line = string.Format(
            "{0:o} helperPid={1} user={2} session={3} {4}{5}",
            DateTime.Now,
            Process.GetCurrentProcess().Id,
            identity,
            session,
            message,
            Environment.NewLine);
        try
        {
            File.AppendAllText(_logPath, line);
            return;
        }
        catch (Exception primaryError)
        {
            try
            {
                var fallback = Path.Combine(Path.GetTempPath(), "AutoHDRInput.log");
                var fallbackLine = line.TrimEnd() + " primaryLogError=" + primaryError + Environment.NewLine;
                File.AppendAllText(fallback, fallbackLine);
            }
            catch
            {
                // Diagnostics must never prevent the actual keyboard operation.
            }
        }
    }

    private static INPUT Key(ushort key, bool up)
    {
        return new INPUT
        {
            type = INPUT_KEYBOARD,
            data = new InputUnion
            {
                keyboard = new KEYBDINPUT
                {
                    virtualKey = key,
                    scanCode = 0,
                    flags = up ? KEYEVENTF_KEYUP : 0,
                    time = 0,
                    extraInfo = UIntPtr.Zero
                }
            }
        };
    }

    public static int Main(string[] args)
    {
        if (args.Length > 0 && !string.IsNullOrWhiteSpace(args[0]))
            _logPath = args[0];
        var probeOnly = args.Length > 1 && args[1] == "--probe";

        try
        {
            var helper = Process.GetCurrentProcess();
            Log(string.Format(
                "START pointerSize={0} inputSize={1} keyboardSize={2} mouseSize={3}",
                IntPtr.Size,
                Marshal.SizeOf(typeof(INPUT)),
                Marshal.SizeOf(typeof(KEYBDINPUT)),
                Marshal.SizeOf(typeof(MOUSEINPUT))));

            var lightroom = Process.GetProcessesByName("Lightroom");
            if (lightroom.Length == 0)
            {
                Log("EXIT 20 Lightroom process not found");
                return 20;
            }

            var foreground = GetForegroundWindow();
            uint foregroundPid;
            GetWindowThreadProcessId(foreground, out foregroundPid);
            Process foregroundProcess = null;
            try { foregroundProcess = Process.GetProcessById((int)foregroundPid); } catch { }

            Log(string.Format(
                "foregroundHandle={0} foregroundPid={1} foregroundName={2} LightroomPids={3}",
                foreground.ToInt64(),
                foregroundPid,
                foregroundProcess == null ? "<unknown>" : foregroundProcess.ProcessName,
                string.Join(",", Array.ConvertAll(lightroom, p => p.Id.ToString()))));

            var isLightroom = false;
            foreach (var process in lightroom)
                if (process.Id == foregroundPid) isLightroom = true;

            if (!isLightroom)
            {
                Log("EXIT 22 foreground process is not Lightroom");
                return 22;
            }

            if (probeOnly)
            {
                Log("EXIT 0 probe complete; no keys sent");
                return 0;
            }

            Thread.Sleep(150);
            var inputs = new[]
            {
                Key(VK_CONTROL, false),
                Key(VK_SHIFT, false),
                Key(VK_H, false),
                Key(VK_H, true),
                Key(VK_SHIFT, true),
                Key(VK_CONTROL, true)
            };
            var inputSize = Marshal.SizeOf(typeof(INPUT));
            var sent = SendInput((uint)inputs.Length, inputs, inputSize);
            var error = Marshal.GetLastWin32Error();
            Log(string.Format(
                "SendInput requested={0} sent={1} inputSize={2} win32Error={3}",
                inputs.Length,
                sent,
                inputSize,
                error));
            if (sent != inputs.Length)
            {
                Log("EXIT 23 SendInput incomplete");
                return 23;
            }

            Thread.Sleep(250);
            Log("EXIT 0 keys sent");
            return 0;
        }
        catch (Exception ex)
        {
            try { Log("EXIT 1 exception=" + ex); } catch { }
            return 1;
        }
    }
}
