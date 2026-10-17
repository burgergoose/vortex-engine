# Vortex Engine — handoff notes for Claude Code

Vortex Engine is a private, non-commercial fork of **Psych Engine 1.0** (Friday Night Funkin'), built by editing the
source. These notes carry over everything from the earlier claude.ai session that built most of it. Read them before
changing anything.

## Ground rules (from the owner)
- **Don't rewrite unrelated parts of the engine.** Make targeted changes; keep Psych behaviour and Psych Lua/HScript
  mod compatibility unless a change is explicitly asked for.
- Prioritise correctness and backward compatibility over speed. Build after every change, fix your own errors, test
  the affected feature, then report what changed, what was tested and what wasn't.
- **Discord RPC App ID stays `"0"`** in `VortexConfig` (never invent an ID). Branding lives in `source/backend/VortexConfig.hx`.
- Only one difficulty (**Normal**). There is no difficulty selector anywhere; the pause menu only shows "Change
  Difficulty" if a song really has more than one chart file.
- Mark Vortex changes in code with a short `// Vortex Engine:` comment explaining why.
- The FPS Plus "little buddies" art (chart editor) is from ThatRozebudDude's FPS Plus — free for **non-commercial use
  only**; credit is in `assets/shared/images/editors/buddies/CREDITS.txt` and on screen.
- Repo: https://github.com/burgergoose/vortex-engine (branch `main`). Docs site source is `docs/index.html` +
  `docs/style.css` (GitHub Pages: Settings → Pages → branch `main`, folder `/docs`).

## Build
- Toolchain used so far: Haxe 4.3.x, HaxeFlixel 5.6.1, OpenFL 9.3.3, Lime 8.1.2, hxcpp 4.3.x, hscript-iris, linc_luajit.
  Library install scripts are in `setup/` (`windows.bat` installs the haxelibs); standard Psych build steps are in `docs/BUILDING.md`.
- On Windows: install Haxe + Visual Studio C++ build tools (see `docs/BUILDING.md`), install the libs, then
  `lime test windows` (debug) or `lime build windows -release`. Output: `export/release/windows/bin/`.
- The earlier session cross-compiled **32-bit Windows from Linux with MinGW** using locally patched haxelibs; that setup
  doesn't exist on a normal Windows PC and isn't needed there.
- Release package = the `bin` folder zipped as `VortexEngine/` (players extract and double-click `VortexEngine.exe`).
  Before zipping remove `crash/`, `vortex_boot_log.txt`, `vortex_mods_log.txt`, any test mods, and empty `modsList.txt`.

## What Vortex added (where to look)
| Area | Files |
|---|---|
| Branding / config | `backend/VortexConfig.hx` |
| Cosmic UI (main menu, Freeplay, Story, pause, chart editor theme) | `objects/CosmicBackground.hx` (palette + background, baked once and cached), `objects/MenuButton.hx`, `objects/SongCard.hx`, `objects/WeekCard.hx`, `states/MainMenuState.hx`, `states/FreeplayState.hx`, `states/StoryMenuState.hx`, `substates/PauseSubState.hx` |
| Developer overlay (F3; F6 restart, F7 reload, F8 menu) | `debug/DebugOverlay.hx` |
| Crash safety | `Main.hx` `onCrash` (≤2 crashes / 10 s → back to main menu + red `Main.showToast`), `crash/` logs |
| Mod loading | `backend/WeekData.hx` (`addUnlistedModSongs`: songs without a week get an automatic "<mod>-songs" week), `backend/Paths.hx` (`.wav` fallback, `instFile`), `backend/ModDiagnostics.hx` (writes `vortex_mods_log.txt`), `PlayState.missingInstState()` + `LoadingState.loadAndSwitchState` (clear "Inst not found" screen) |
| Robust loading | `backend/Song.hx` `sanitize` (charts missing fields), `backend/StageData.hx` `sanitize` + lenient `validateVisibility`, `objects/Character.hx` (defaults for missing json fields, BF fallback + error label when an image is missing), `GameOverSubstate` hardening, `PlayState.buildHardcodedStage` (vanilla week 2-7 stage code only runs if its pictures exist) |
| Change Stage event | `PlayState.changeStage` + `case 'Change Stage'` (Value 1 = current stage, Value 2 = new stage; custom json or built-in); listed in `ChartingState.defaultEvents` |
| Custom events fix | `PlayState.ensureEventScript` (event scripts load the first time a script fires them via `triggerEvent`); chart editor lists `.lua`/`.hx`-only events (`ChartingState.reloadNotesDropdowns`) |
| Chart editor | VORTEX theme (`ChartingState.changeTheme`), little buddies `objects/ChartBuddies.hx` |
| Scripting | Lua outside songs (`psychlua/FunkinLua.hx` registry `activeScripts`, `CallbackHandler.hx`, `LuaUtils.debugPrint/callOnLuas`); state scripts + custom states hosted in `backend/MusicBeatState.hx` (`loadStateScripts`, `callOnStateScripts`); `states/ScriptedState.hx` (`switchState`); `psychlua/ScriptedClasses.hx` (`createScripted`, `callScripted`, `destroyScripted`, …); `Mods.allModFoldersWith/findInAnyMod` (states/ and classes/ are searched in every enabled mod) |

Psych already has Lua functions named `createInstance` and `callMethod` (Haxe reflection) — never reuse those names.

## Testing notes
- There's a bundled example mod at `example_mods/Vortex-Example-Mod` (week, song with split vocals, character,
  stage, custom event) — good for quick checks.
- Things the earlier session could NOT test (no sound device in its Windows emulation): real audio playback, the
  buddies singing to notes while a song plays, clicking through the chart editor's event dropdown, FPS on real hardware.

## Open items / ideas
- Owner's own mod hasn't been tested directly; if a crash happens, ask for the newest file in `crash/`.
- Mods menu (`states/ModsMenuState.hx`) still has the stock Psych look.
- Docs site needs GitHub Pages switched on once (see above).
