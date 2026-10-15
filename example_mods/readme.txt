Psych's mods/ folder.

If you're a beginner, we recommend you extract modTemplate.zip to get started on developing your mod.
Read the Psych GitHub wiki here:
https://github.com/ShadowMario/FNF-PsychEngine/wiki
Read the Lua Script API here:
https://shadowmario.github.io/psychengine.lua/

You can also add or edit specific files without the mod template, you just have to re-create the path to said file.

ABOUT EDITING:
If you want to change something, for example, within assets/shared/images or assets/base_game/images,
said edited files *must* be put in mods/images, the engine will handle the rest.

VORTEX ENGINE NOTES
- Put each mod in its own folder here, e.g. mods/My-Mod/ (see Vortex-Example-Mod for a working one).
- Song audio goes in mods/My-Mod/songs/<song-name>/ :
    Inst.ogg                 the instrumental (required)
    Voices.ogg               one combined voices track, OR
    Voices-Player.ogg + Voices-Opponent.ogg   separate voices
  (.wav also works, .mp3 does not)
- The chart goes in mods/My-Mod/data/<song-name>/<song-name>.json (a -hard / -easy chart alone is fine).
- A week file in mods/My-Mod/weeks/ is optional: songs without one are still listed in Freeplay and Story Mode.
- Every start the game writes vortex_mods_log.txt next to the .exe listing every mod it found and what is inside.
