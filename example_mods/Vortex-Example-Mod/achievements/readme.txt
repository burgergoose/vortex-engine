ACHIEVEMENTS (Vortex Engine)

Easiest way: Main Menu > press 7 > Achievement Editor (pick your mod folder with Left/Right first).

Every achievement is a file here, named after its ID (lowercase letters, numbers, - and _):
  <id>.json   name, description, unlock condition (made by the editor)
  <id>.png    its icon (optional, 150x150 looks best)
  <id>.lua    a script that runs in every song while it's locked (optional, or <id>.hx)

"unlock" -> "type":
  manual         only scripts unlock it: unlockAchievement(achievementId)
  song_complete  finish "song" (empty = any song)
  week_complete  finish the last song of "week" (week file name) in Story Mode
Optional: maxMisses (-1 = any), minAccuracy (0-100), minScore, allowPractice.
"maxScore": 3 turns it into a progress goal: each qualifying finish adds 1.
Botplay and the Chart Editor never unlock achievements.

Psych Engine's data/achievements.json + images/achievements/<save>.png still work too.
