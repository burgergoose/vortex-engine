-- Attached to the achievement "combo-starter" (same file name as combo-starter.json).
-- It runs in every song while the achievement is still locked; achievementId is "combo-starter".

function goodNoteHit(id, direction, noteType, isSustain)
	if botPlay then return end -- botplay shouldn't earn achievements
	if getProperty('combo') >= 20 then
		unlockAchievement(achievementId)
	end
end
