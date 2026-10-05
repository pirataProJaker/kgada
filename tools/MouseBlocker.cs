using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

class Program {
    private const int WH_MOUSE_LL = 14;
    private const int WM_MBUTTONDOWN = 0x0207;
    private const int WM_MBUTTONUP = 0x0208;
    private const int WM_MBUTTONDBLCLK = 0x0209;

    private static HookProc _proc = HookCallback;
    private static IntPtr _hookId = IntPtr.Zero;

    private delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

    [STAThread]
    static void Main() {
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
            // Bloquear UNICAMENTE el clic físico de la rueda (botón del medio)
            // El scroll (deslizar arriba/abajo) NO se toca y sigue funcionando normal
            if (msg == WM_MBUTTONDOWN || msg == WM_MBUTTONUP || msg == WM_MBUTTONDBLCLK) {
                return (IntPtr)1; // Anular clic
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
