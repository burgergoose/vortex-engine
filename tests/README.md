# Vortex Engine in-game tests

Three test mods drive the real game and write `PASS` / `FAIL` lines to a text file next to the exe.
None of them ship with the game (only `example_mods/` is copied into builds). Run them one at a time:
put only the one you're running in `export/release/windows/bin/mods/` (next to the bundled `Vortex-Example-Mod`,
which they all use), start the game, don't touch the window, and it closes itself when done.

| Test mod | Checks | Results file |
|---|---|---|
| `VortexSelfTest` | scripting API: custom states, `Global.lua`, `require`, global vars, mod key binds, script calls in menus, substates, scripted classes, error log, `spawnNote`, real key presses (32 checks) | `vortex_selftest.txt` |
| `VortexVocalsTest` | pause / resume vocals: 5 songs with different vocal setups, 4 pauses each (one rapid double pause) + Skip Time; every track must play when it should and stay within 80 ms of the instrumental (50 checks) | `vortex_audiotest.txt` |
| `VortexAchievementTest` | achievements: loading from `achievements/`, icons, scripts, unlock rules, progress goals, saving, the Achievement Editor (save / validate / load / create script) and a real song end in practice mode (34 checks) | `vortex_achtest.txt` |

## Running

1. Build: `lime build windows -release`
2. `VortexVocalsTest` needs its songs generated first: `python tests/make_vocals_test.py` (copies and cuts the example
   song's audio; the generated `data/` and `songs/` are git-ignored).
3. Copy the test mod folder into `export/release/windows/bin/mods/` and start `export/release/windows/bin/VortexEngine.exe`.
   For `VortexSelfTest`, start the key sender first so the "real key presses" check can pass:
   ```
   Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File tests\send-keys.ps1'
   ```
4. Read the results file: every line `PASS`, ending with `DONE`. `VortexSelfTest` also leaves exactly one error in
   `vortex_script_log.txt` (an intentional one in `SelfTestMenu.lua`); the other two leave none.
5. `VortexAchievementTest` unlocks test achievements in your save and re-locks them at the end.
6. Delete the test mod, the results files and `vortex_script_log.txt` before packaging a release.
