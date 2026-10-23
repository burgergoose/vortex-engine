# Vortex Engine in-game tests

Test mods drive the real game and write `PASS` / `FAIL` lines to a text file next to the exe.
None of them ship with the game (only `example_mods/` is copied into builds). Run them one at a time:
put only the one you're running in `export/release/windows/bin/mods/` (next to the bundled `Vortex-Example-Mod`,
which they all use), start the game, don't touch the window, and it closes itself when done.

| Test mod | Checks | Results file |
|---|---|---|
| `VortexSelfTest` | scripting API: custom states, `Global.lua`, `require`, global vars, mod key binds, script calls in menus, substates, scripted classes, error log, `spawnNote`, real key presses (32 checks) | `vortex_selftest.txt` |
| `VortexVocalsTest` | pause / resume vocals: 5 songs with different vocal setups, 4 pauses each (one rapid double pause) + Skip Time; every track must play when it should and stay within 80 ms of the instrumental (50 checks) | `vortex_audiotest.txt` |
| `VortexAchievementTest` | achievements: loading from `achievements/`, icons, scripts, unlock rules, progress goals, saving, the Achievement Editor (save / validate / load / create script) and a real song end in practice mode (34 checks) | `vortex_achtest.txt` |
| `VortexStrumlineTest` | strumlines: a 4-strumline chart (2 player lines, extra singers, per-note singers, an additional line, simultaneous notes and holds, a note on an undefined line), the Lua/HScript strumline API, a plain Psych chart afterwards, and the Chart Editor (Strumlines menu, Add / Remove Line, Sung by, saving) (48 checks; "dad sings" is written a few times) | `vortex_strumtest.txt` |
| `VortexCompatTest` | mods from other engines: detection, translation and play of V-Slice, Codename Engine, Psych 0.6-style (old chart + old Lua class names), FPS Plus and Forever Engine test mods, plus (0.6) a V-Slice mod laid out like real GameBanana mods (library folders, odd file names, Mac junk, .astc art, a stage built by its script), a mod one folder too deep and `hideBaseGameWeeks` (105 checks). Make them with `python tests/make_compat_test.py`, then copy every folder in `tests/VortexCompatTest/fixtures/` and `tests/VortexCompatTest/harness/VortexCompatTest` into mods/ | `vortex_compattest.txt` |
| `VortexConverterTest` | the V-Slice Converter on the bundled example mod and on the translated Codename test mod, plus its phone-ready zip, (0.7) base-game id renaming, exact placement, Lua custom events and the Lua -> HScript translator, (0.7.2) Lua tables named like Haxe classes and Lua text / key functions (39 checks). Needs `CompatCodename` from the compat fixtures in mods/ too | `vortex_convtest.txt` |
| `VortexThemeTest` | menu themes: Psych Classic and the example custom menu on every themed screen, a broken menu.json falling back, reset (13 checks, writes `shot_<step>.txt` markers for screenshots). Sets the theme back to Vortex at the end | `vortex_themetest.txt` |

## Running

1. Build: `lime build windows -release`
2. `VortexVocalsTest` needs its songs generated first: `python tests/make_vocals_test.py` (copies and cuts the example
   song's audio; the generated `data/` and `songs/` are git-ignored).
   `VortexStrumlineTest` too: `python tests/make_strumline_test.py`.
3. Copy the test mod folder into `export/release/windows/bin/mods/` and start `export/release/windows/bin/VortexEngine.exe`.
   For `VortexSelfTest`, start the key sender first so the "real key presses" check can pass:
   ```
   Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File tests\send-keys.ps1'
   ```
4. Read the results file: every line `PASS`, ending with `DONE`. `VortexSelfTest` also leaves exactly one error in
   `vortex_script_log.txt` (an intentional one in `SelfTestMenu.lua`); the other two leave none.
5. `VortexAchievementTest` unlocks test achievements in your save and re-locks them at the end.
6. Delete the test mod, the results files and `vortex_script_log.txt` before packaging a release.
