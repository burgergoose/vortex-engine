# Vortex Engine — Phase 1

This is a complete copy of Psych Engine (cloned fresh from `ShadowMario/FNF-PsychEngine`,
everything except `.git` — same as GitHub's own "Download ZIP" button) with the edits
below already applied directly to the source. Nothing to merge or install into an
existing Psych Engine copy — just open this folder as your project.

**I could not compile or run this** — this environment doesn't have a Haxe/HaxeFlixel/Lime
toolchain (or the internet access to install one), so this is careful source-level work,
cross-checked line-by-line against the real engine files, but not compiler-verified. Build
it locally the normal way (`lime test windows` / your usual target) and paste me any errors
— given the size of this change, I'd genuinely expect a couple of small fixes.

## Quick start
1. Open `assets/shared/data/vortexConfig.json` and, at minimum, set your own Discord
   Application ID (see below). `engineName` already defaults to "Vortex Engine".
2. Build normally.
3. In-game: F3 toggles the new Developer Mode overlay; F6/F7/F8 are its actions (only
   while it's open, and only mid-song).

## What's done

### 1. Centralized branding
Everything that used to hardcode "Psych Engine" in UI-facing text now reads from
`backend/VortexConfig.hx`, which loads `assets/shared/data/vortexConfig.json` at startup
(safe hardcoded fallbacks if that file's ever missing). Edit that JSON and the name changes
everywhere — no recompile needed for in-game text. The window title, exe filename, and
package id in `Project.xml` are the one part that's genuinely compile-time (Lime/OpenFL
bakes those in) — `Main.hx` re-applies the configured name to the live window title at
runtime, so day-to-day rebranding still only touches the JSON.

Touched for this: `Main.hx`, `MainMenuState.hx`, `Project.xml`, `CoolUtil.hx`,
`OutdatedSubState.hx`, `TitleState.hx`, `PreloadListSubState.hx`, `StageEditorState.hx`,
`VSlice.hx`.

Left alone on purpose:
- **`CreditsState.hx`** — that's genuine attribution to the people who actually built
  Psych Engine (ShadowMario, Riveren, and the rest of the team). Renaming/removing that
  would be misattributing their work, not rebranding. Add your own name/team to it
  whenever you're ready — I didn't want to guess at how you'd want to present that.
- **Chart-format messages in `ChartingState.hx`** (e.g. "not a Psych Engine chart") —
  those describe the *chart file format*, which Vortex still uses as-is, not engine
  branding. Changing them would make them less accurate, not more on-brand.
- The title-screen credit flash still says "Shadow Mario" / "Riveren" after "Vortex
  Engine by" — that's still true (they built what this is forked from), so I left it
  rather than invent placeholder text for you.

### 2. Discord Rich Presence
Turns out Psych already has this (`backend/Discord.hx`, `hxdiscord_rpc`) — so this extends
it rather than building it from scratch:
- The Application ID is now `VortexConfig.discordAppId` instead of hardcoded to
  ShadowMario's own app. **You need your own**: create one free at
  https://discord.com/developers/applications, upload an icon/name there if you want
  Vortex's own branding to show up in Discord, and paste the numeric ID into
  `vortexConfig.json`. Leave it as `"0"` and RPC just stays off.
- The enable/disable checkbox already existed in Settings (Visuals & UI) but didn't
  actually apply until next launch — it's now wired to the existing `DiscordClient.check()`
  so toggling it takes effect immediately.
- Freeplay and Story Mode both used to show the exact same generic "In the Menus" as the
  main menu. They now say "In Freeplay" and "In Story Mode" (+ the actual week name).
  PlayState's per-song presence was already detailed and is untouched.

### 3. Song profile system (score / accuracy / rank / combo / misses / completion)
`backend/Highscore.hx` already tracked best score + accuracy per song/difficulty — extended
it with three new parallel save maps (max combo, misses, completed), same pattern as the
existing ones, same save keys, **fully backward-compatible** — an old save file just won't
have these three yet, and every getter treats "not there" as "no data," so nothing breaks
or resets. `Highscore.saveStats(...)` wraps the original `saveScore(...)` completely
unchanged and additionally records the new fields for whichever run has the best score.
`PlayState` gained one new field (`highestCombo`, updated at the single spot combo already
increments) and its one save call site now calls `saveStats` instead of `saveScore`.

**Important, please read:** you asked to use "the existing Psych Engine accuracy/rating
system (A, B, S, P, etc.)" — vanilla Psych doesn't actually have that. What it has is a
raw accuracy percentage, plus a *word* rating ("Sick"/"Good"/"Bad"/"Shit") and a separate
clear-type tag ("FC"/"GFC"/"SFC"/"SDCB"). No single letter grade anywhere. So
`backend/SongRank.hx` is new — a small, clearly-commented, editable threshold table that
turns Psych's existing accuracy number into P/S/A/B/C/D/F. It's a pure function of the
accuracy Psych already computes, so it can't disagree with the game's own numbers, but I
wanted to flag clearly that this is an addition, not something I found already there.

Freeplay's personal-best text now appends the rank (e.g. `PERSONAL BEST: 12,345 (95.32%)
[S]`) as a taste of this wired end-to-end — the full card-based redesign is Phase 2.

### 4. Difficulty selector removed (Freeplay + Story Mode)
Both screens now resolve straight to whichever difficulty means "Normal" for the current
week (falling back sensibly if a heavily modded week doesn't have one), with no arrows, no
key handling, no selection UI. This also let me delete some genuinely dead code: a
per-song "remember last difficulty" system that no longer serves any purpose (and, as a
bonus, a pre-existing dead/contradictory `if` branch in the original difficulty-restore
logic — harmless, but it's gone too).

One thing to know: removing the difficulty badge in Story Mode leaves an empty gap in the
current (pre-remaster) layout — cosmetic only, and it goes away when the cosmic redesign
replaces that whole screen in Phase 2.

### 5. Developer Mode overlay
`debug/DebugOverlay.hx` — new, lives at the same always-present level as the existing FPS
counter (`debug/FPSCounter.hx`, which is untouched and still does its own separate job).

- **F3** — show/hide the overlay
- Shows: FPS, memory, song position, BPM, section, current BF/Dad/GF animations, camera
  zoom + position (game cam and HUD cam), plus score/combo/misses as a bonus since the
  data was already there
- **F6** — restart the song
- **F7** — reload Lua/HScript + stage + characters
- **F8** — back to the main menu

Worth knowing about F7: Psych has no mechanism anywhere to hot-swap a script/stage/character
without recreating the whole PlayState — there's nothing in-place to extend. So, to stay
stable, F7 currently does the exact same full restart as F6 (clearly commented in the code
as such, not hidden). A true hot-reload that keeps the song playing would be a real,
separate feature worth its own pass if you want it later — I didn't want to rush something
that touches song stability just to make two buttons feel different.

I also widened `curSection`/`curStep`/`curBeat` (+decimal versions) in `MusicBeatState.hx`
from `private` to `public` so the overlay (and Lua/HScript mods, for free) can read them
directly instead of needing `@:privateAccess`.

## Everything touched
**New:** `source/backend/VortexConfig.hx`, `source/backend/SongRank.hx`,
`source/debug/DebugOverlay.hx`, `assets/shared/data/vortexConfig.json`

**Modified:** `Project.xml`, `source/Main.hx`, `source/backend/CoolUtil.hx`,
`source/backend/Discord.hx`, `source/backend/Highscore.hx`, `source/backend/MusicBeatState.hx`,
`source/debug/FPSCounter.hx`, `source/objects/MusicPlayer.hx`,
`source/options/VisualsSettingsSubState.hx`, `source/states/FreeplayState.hx`,
`source/states/MainMenuState.hx`, `source/states/PlayState.hx`, `source/states/StoryMenuState.hx`,
`source/states/TitleState.hx`, `source/states/editors/StageEditorState.hx`,
`source/states/editors/content/PreloadListSubState.hx`, `source/states/editors/content/VSlice.hx`,
`source/substates/OutdatedSubState.hx`

## Not started yet
- **Chart Editor remaster** — skipped per your request. Not touched at all.

Say the word if you want anything else changed.

---

# Phase 2 — Freeplay + Story Mode cosmic remaster

Both screens now share a reusable cosmic background (`objects/CosmicBackground.hx`) and
the same glass-panel visual language, but the actual list rendering was rebuilt
differently for each screen, for reasons explained below.

## `objects/CosmicBackground.hx` (new)
A gradient sky + a few soft procedural nebula clouds (perlin noise used as an alpha mask
over a flat tint, not a new image asset) + a baked starfield + ~20 individually-twinkling
accent stars + ~16 slow-drifting dust particles. The sky/nebula/stars are baked into ONE
bitmap once at construction, so the ongoing per-frame cost is just animating a couple
dozen small sprites — nothing pixel- or resolution-heavy. Also holds the shared color
palette as public static constants (`PANEL_FILL`, `PANEL_BORDER_BRIGHT`, `TEXT_DIM`, etc.)
so every panel across both screens pulls from the same values. Wrapped in a try/catch with
a flat-color fallback in case procedural generation ever misbehaves on some target.

Deliberately went with sharp-cornered panels everywhere (not rounded) — a solid-color
sprite scaled up, tinted via `.color` (the exact "make a 1x1 white graphic, then set
`.color`" trick `PsychUIBox` already uses elsewhere in this engine) is simple, cheap, and
proven; drawing a rounded gradient-bordered panel "properly" means a BitmapData per panel,
which isn't worth the extra risk for something built potentially hundreds of times over
(one SongCard per song). The one place this project draws into a BitmapData is
CosmicBackground, and that only happens twice total (once per screen), not once per item.

## Freeplay (`objects/SongCard.hx` + `states/FreeplayState.hx`)
The old Alphabet-scrolling-text list is gone, replaced with `SongCard` — a self-contained
card (background panel, the opponent's `HealthIcon`, song name, a secondary "Best
12,345 | 95.32%" line, and a rank badge on the far right, colored per tier). Cards scroll
as a vertical carousel: closer to the selection = brighter; farther = dimmer. Clicking a
visible card selects it (playing still needs ENTER, same as keyboard nav, so nothing about
that flow changed). Same virtualization strategy as before (only cards near the selection
are active each frame) and the exact same input handling for everything else — arrows,
hold-to-scroll, HOME/END, mouse wheel, SPACE preview, RESET, BACK, ENTER — none of that was
touched.

The old per-song background color tint (`bg.color = songs[curSelected].color`, tinting a
desaturated `menuDesat` image) is gone — replaced by the unified cosmic background. Kept
that behind for now rather than fighting the new theme with per-song retinting; flagging
it clearly since it's a real, deliberate simplification, not an oversight.

The corner "PERSONAL BEST" readout is gone too, since that same info is on every card now
via `refreshStats()`. `scoreText`/`scoreBG` are still real fields with those exact names
(so `objects/MusicPlayer.hx`'s existing visibility-toggle code — hides them while an
instrumental preview plays — didn't need touching), just repurposed into a static
"VORTEX ENGINE — FREEPLAY" title instead of a live readout.

## Story Mode (`objects/WeekCard.hx` + `states/StoryMenuState.hx`)
`WeekCard` wraps the existing `objects.MenuItem` (which loads each week's own
`storymenu/WeekName.png` banner art) inside the same glass-panel framing, instead of
replacing that banner art with something generated — mods that ship custom week banners
keep working exactly as before, just inside a nicer frame. The lock icon is a child of the
card now (so it moves with it automatically) instead of a separate parallel `grpLocks`
group manually kept in sync by matching indices, which was both a simplification and one
less place for the two lists to drift out of sync.

Deliberately did NOT confine the three character portraits (`MenuCharacter`) to a narrow
column next to the week list. Each character's size comes from that character's own JSON
file (`scale`, `position`, per mod), not anything this engine controls — cramming
arbitrarily-sized portraits into a narrow panel risked overlap or clipping that I couldn't
verify without visual testing. So they keep roughly the original full-width spread; only
the week list (now a left-side vertical `WeekCard` carousel, reusing the exact scroll-lerp
formula the original used, just retargeted to the new spacing) and the tracklist (now its
own glass panel on the right, replacing the old `Menu_Tracks` decorative image — purely
cosmetic, no data/compat impact) moved to make room. Clicking a card selects that week the
same way clicking a Freeplay card selects a song.

The per-week custom background image (`bgSprite`, loaded via `leWeek.weekBackground`) is
still loaded — kept for mod compatibility — but shown as a faint (22% alpha) backdrop
layer instead of a full-opacity full-screen image, so it adds a bit of per-week texture
without fighting the cosmic theme.

Everything else — locking, `selectWeek()`'s chart-loading/stage-forcing/Discord-RPC flow,
`changeWeek()`'s difficulty resolution, the confirm-animation on select, BACK/CONTROL/RESET
handling — is untouched.

## Design notes
- Palette is deliberately violet/indigo-forward with cyan/magenta/teal nebula accents
  (`CosmicBackground.hx`'s constants), not a generic navy gradient — easy to retune by
  editing those constants in one place.
- `backend/SongRank.hx` (from Phase 1) now has a `colorFor(rank)` helper too, so the rank
  badge color and the rank letter itself both come from the same source.
- Font is `vcr.ttf` throughout, matching the rest of the engine — no new font assets.

