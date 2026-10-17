# Vortex Engine self-test

`VortexSelfTest/` is a test mod that drives the real game and checks the scripting features end to end:
custom states, `states/Global.lua`, `require()` from `lib/`, global variables, mod key binds (`data/keybinds.json`),
script-to-script calls in menus, custom substates in menus, scripted classes receiving callbacks, the script error log
(one intentional error), and in a song: `spawnNote` (normal, hold, opponent, custom note type), note type script
loading, botplay hitting the spawned notes, and a real key press reaching a mod key bind.

It is **not** shipped with the game (only `example_mods/` is copied into builds).

## Running it

1. Build: `lime build windows -release`
2. Copy `tests/VortexSelfTest` into `export/release/windows/bin/mods/` (the bundled `Vortex-Example-Mod` must be
   there too: the test plays its `example-song`).
3. In PowerShell, start the key sender, then the game:
   ```
   Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File tests\send-keys.ps1'
   export\release\windows\bin\VortexEngine.exe
   ```
   The game opens a test screen, plays about 10 seconds of the example song in botplay and closes itself.
   Don't touch the window while it runs.
4. Read `export/release/windows/bin/vortex_selftest.txt`: every line should be `PASS`, ending with `DONE`.
   `vortex_script_log.txt` should contain exactly one error (the intentional one in `SelfTestMenu.lua`).
5. Delete `mods/VortexSelfTest`, `vortex_selftest*.txt` and `vortex_script_log.txt` before packaging a release.

Without `send-keys.ps1` everything passes except the "real key presses" line.
