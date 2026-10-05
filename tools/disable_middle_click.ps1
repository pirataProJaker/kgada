# Script para anular el clic de la rueda del mouse (Middle Click / Boton Central)
# y evitar falsos clics por falla fisica del mouse en Windows.

param(
    [switch]$BlockScroll = $false
)

$source = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class MouseBlocker {
    private const int WH_MOUSE_LL = 14;
    private const int WM_MBUTTONDOWN = 0x0207;
    private const int WM_MBUTTONUP = 0x0208;
    private const int WM_MBUTTONDBLCLK = 0x0209;
    private const int WM_MOUSEWHEEL = 0x020A;
    private const int WM_MOUSEHWHEEL = 0x020E;

    public static bool FilterScroll = false;
    private static HookProc _proc = HookCallback;
    private static IntPtr _hookId = IntPtr.Zero;

    private delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

    public static void Start(bool blockScroll) {
        FilterScroll = blockScroll;
        _hookId = SetHook(_proc);
        Application.Run();
        UnhookWindowsHookEx(_hookId);
    }

    private static IntPtr SetHook(HookProc proc) {
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_MOUSE_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int msg = wParam.ToInt32();
            if (msg == WM_MBUTTONDOWN || msg == WM_MBUTTONUP || msg == WM_MBUTTONDBLCLK) {
                return (IntPtr)1; // Anular clic central de la rueda
            }
            if (FilterScroll && (msg == WM_MOUSEWHEEL || msg == WM_MOUSEHWHEEL)) {
                return (IntPtr)1; // Anular desplazamiento de la rueda si se pide
            }
        }
        return CallNextHookEx(_hookId, nCode, wParam, lParam);
    }

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Windows.Forms"
[MouseBlocker]::Start($BlockScroll)
