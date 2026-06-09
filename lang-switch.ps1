# Tellarion.dev — Apple Keyboard Lang Switch
# Переключение языка по Win+Space (Command+Space на Apple-клавиатуре)

Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public static class LangSwitchHook {
    public const int WH_KEYBOARD_LL = 13;
    public const int WM_KEYDOWN = 0x0100;
    public const int WM_KEYUP = 0x0101;
    public const int WM_SYSKEYDOWN = 0x0104;
    public const int WM_SYSKEYUP = 0x0105;
    public const int VK_SPACE = 0x20;
    public const int VK_LWIN = 0x5B;
    public const int VK_RWIN = 0x5C;
    public const uint WM_INPUTLANGCHANGEREQUEST = 0x0050;
    public const uint LLKHF_INJECTED = 0x10;

    public delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct KBDLLHOOKSTRUCT {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    public static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr processId);

    [DllImport("user32.dll")]
    public static extern IntPtr GetKeyboardLayout(uint idThread);

    [DllImport("user32.dll")]
    public static extern int GetKeyboardLayoutList(int nBuff, IntPtr[] list);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool GetKeyboardState(byte[] lpKeyState);

    [DllImport("user32.dll")]
    public static extern bool SetKeyboardState(byte[] lpKeyState);

    private static LowLevelKeyboardProc _proc = HookCallback;
    private static IntPtr _hookId = IntPtr.Zero;
    private static int _lastSwitchTick;
    private static bool _lWinHeld;
    private static bool _rWinHeld;
    private static bool _comboActive;
    private static bool _blockWinUp;
    private static int _blockWinUpTick;

    public static void Run() {
        _hookId = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName), 0);
        if (_hookId == IntPtr.Zero) {
            throw new InvalidOperationException("Tellarion.dev: Ne udalos ustanovit perehvat klaviatury.");
        }

        var done = new ManualResetEvent(false);
        Console.CancelKeyPress += (_, e) => { e.Cancel = true; done.Set(); };
        AppDomain.CurrentDomain.ProcessExit += (_, __) => done.Set();
        done.WaitOne();
        UnhookWindowsHookEx(_hookId);
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            var data = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);
            if ((data.flags & LLKHF_INJECTED) != 0) {
                return CallNextHookEx(_hookId, nCode, wParam, lParam);
            }

            bool isKeyDown = wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN;
            bool isKeyUp = wParam == (IntPtr)WM_KEYUP || wParam == (IntPtr)WM_SYSKEYUP;
            uint vk = data.vkCode;

            ResetStaleBlock();

            if (isKeyDown && vk == VK_LWIN) {
                _lWinHeld = true;
            } else if (isKeyDown && vk == VK_RWIN) {
                _rWinHeld = true;
            } else if (isKeyDown && vk == VK_SPACE && (_lWinHeld || _rWinHeld)) {
                _comboActive = true;
                _blockWinUp = true;
                _blockWinUpTick = Environment.TickCount;

                int now = Environment.TickCount;
                if (now - _lastSwitchTick > 250) {
                    _lastSwitchTick = now;
                    SwitchToNextLayout();
                }
                return (IntPtr)1;
            } else if (isKeyUp && vk == VK_SPACE && _comboActive) {
                _comboActive = false;
                return (IntPtr)1;
            } else if (isKeyUp && (vk == VK_LWIN || vk == VK_RWIN)) {
                if (vk == VK_LWIN) _lWinHeld = false;
                if (vk == VK_RWIN) _rWinHeld = false;

                if (_blockWinUp) {
                    _blockWinUp = false;
                    _comboActive = false;
                    ClearWinKeyState();
                    return (IntPtr)1;
                }
            }
        }
        return CallNextHookEx(_hookId, nCode, wParam, lParam);
    }

    private static void ResetStaleBlock() {
        if (!_blockWinUp) return;
        if (Environment.TickCount - _blockWinUpTick > 800) {
            _blockWinUp = false;
            _comboActive = false;
            ClearWinKeyState();
        }
    }

    private static void ClearWinKeyState() {
        byte[] state = new byte[256];
        if (!GetKeyboardState(state)) return;
        state[VK_LWIN] = 0;
        state[VK_RWIN] = 0;
        SetKeyboardState(state);
    }

    private static void SwitchToNextLayout() {
        IntPtr hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return;

        uint threadId = GetWindowThreadProcessId(hwnd, IntPtr.Zero);
        IntPtr current = GetKeyboardLayout(threadId);

        int count = GetKeyboardLayoutList(0, null);
        if (count < 2) return;

        IntPtr[] layouts = new IntPtr[count];
        GetKeyboardLayoutList(count, layouts);

        IntPtr next = layouts[0];
        for (int i = 0; i < count; i++) {
            if (layouts[i] == current) {
                next = layouts[(i + 1) % count];
                break;
            }
        }

        PostMessage(hwnd, WM_INPUTLANGCHANGEREQUEST, IntPtr.Zero, next);
    }
}
"@

[LangSwitchHook]::Run()
