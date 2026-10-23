local lines = {}
local function check(name, ok, info)
	lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. name .. (info ~= nil and (' -- ' .. tostring(info)) or '')
end

function onCreatePost()
	setProperty('practiceMode', true)    -- notes get missed, practice keeps you alive
	setProperty('cpuControlled', false)
end

function onSongStart()
	runTimer('achtest_end', 3)
end

function onTimerCompleted(tag)
	if tag == 'achtest_end' then endSong() end
end

local done = false
function onEndSong()
	if done then return Function_Stop end
	done = true
	check('achievement script ran with achievementId set', getGlobalVar('ach_scriptId', 'nil') == 'ach-test-script', getGlobalVar('ach_scriptId', 'nil'))
	check('achievement script unlocked its achievement', isAchievementUnlocked('ach-test-script') == true)
	check('real song end: allowPractice achievement unlocked in practice mode', isAchievementUnlocked('ach-test-practice') == true)
	check('real song end: normal achievement not unlocked in practice mode', isAchievementUnlocked('first-steps') == false)
	check('example combo script did not unlock without a 20 combo', isAchievementUnlocked('combo-starter') == false)
	local inf = getAchievementInfo('song-collector')
	check('getAchievementInfo', inf ~= nil and inf.name == 'Song Collector' and inf.maxScore == 3 and inf.unlocked == false, inf and (inf.name .. ' ' .. inf.maxScore) or 'nil')
	local f = io.open('vortex_achtest.txt', 'a')
	for _, l in ipairs(lines) do f:write(l .. '\n') end
	f:close()
	callOnHScript('cleanupAndExit', {})
	return Function_Stop
end
