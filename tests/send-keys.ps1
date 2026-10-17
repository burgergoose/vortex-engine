# Sends 6 real Space presses to the running game once the self-test song has started (see tests/README.md).
$m = Join-Path $PSScriptRoot '../export/release/windows/bin/vortex_selftest_song.txt'
for ($i = 0; $i -lt 240 -and -not (Test-Path $m); $i++) { Start-Sleep -Milliseconds 500 }
Add-Type @"
using System; using System.Runtime.InteropServices;
public class K {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
"@
Add-Type -AssemblyName Microsoft.VisualBasic
$p = Get-Process VortexEngine | Select-Object -First 1
# Alt tap lets a background process take the foreground
[K]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [K]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
[K]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
[K]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
try { [Microsoft.VisualBasic.Interaction]::AppActivate($p.Id) } catch {}
Start-Sleep -Milliseconds 300
"foreground is game: " + ([K]::GetForegroundWindow() -eq $p.MainWindowHandle)
for ($k = 0; $k -lt 6; $k++) {
  Start-Sleep -Milliseconds 450
  [K]::keybd_event(0x20, 0x39, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 60; [K]::keybd_event(0x20, 0x39, 2, [UIntPtr]::Zero)
}
"sent keys"
