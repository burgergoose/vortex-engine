VORTEX EXAMPLE MOD
A tiny working mod: one week, one song (Inst + Voices), one character, one stage and one event.
It is only here so you can see how a mod is laid out and that mods load. Copy this folder, rename it,
and swap the files for your own. To remove it, delete the folder (or turn it off in the Mods menu).

  weeks/        week file (shows the song in Story Mode + Freeplay)
  data/<song>/  chart: <song>.json
  songs/<song>/ Inst.ogg (and Voices.ogg or Voices-Player.ogg / Voices-Opponent.ogg)
  characters/   character .json  (image goes in images/characters/)
  stages/       stage .json
  custom_events/  Event Name.txt (+ .lua script)

Audio must be .ogg (or .wav). .mp3 is not supported.
Songs that have a chart in data/<song>/ but no week file are listed automatically too.
