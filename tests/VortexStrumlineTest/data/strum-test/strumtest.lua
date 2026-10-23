local lines = {}
local function check(name, ok, info)
	lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. name .. (info ~= nil and (' -- ' .. tostring(info)) or '')
end
local function flush()
	local f = io.open('vortex_strumtest.txt', 'a')
	for _, l in ipairs(lines) do f:write(l .. '\n') end
	f:close()
	lines = {}
end

function onSongStart()
	check('Lua getStrumLineCount', getStrumLineCount() == 4, getStrumLineCount())
	local info = getStrumLineInfo(2)
	check('Lua getStrumLineInfo', info ~= nil and info.type == 'player' and info.name == 'Duet' and info.names[1] == 'gf', info and (info.name .. ' ' .. info.type) or 'nil')
	local tags = getStrumLineCharacters(0)
	check('Lua getStrumLineCharacters', tags[1] == 'boyfriend' and tags[2] == 'strumLine0_char1', table.concat(tags, ','))
	check('Lua: singer tags work with getProperty', getProperty('strumLine0_char1.curCharacter') == 'dad')
	local tag = addStrumLineCharacter(3, 'gf', 'dad', -800, 0)
	check('Lua addStrumLineCharacter', tag ~= nil and #getStrumLineCharacters(3) == 3, tag)
	check('Lua removeStrumLineCharacter', removeStrumLineCharacter(3, 2) == true and #getStrumLineCharacters(3) == 2)
	check('Lua removeStrumLineCharacter refuses boyfriend', removeStrumLineCharacter(0, 0) == false)
	setStrumLinePosition(2, 100, 300)
	check('Lua setStrumLinePosition', getPropertyFromGroup('strumLineNotes', 8, 'x') == 100 and getPropertyFromGroup('strumLineNotes', 8, 'y') == 300)
	setStrumLineVisible(3, false)
	check('Lua setStrumLineVisible', getPropertyFromGroup('strumLineNotes', 12, 'visible') == false)
	setStrumLineVisible(3, true)
	check('Lua strumLineSing', strumLineSing(3, 2) == true and getProperty('strumLine3_char0.animation.curAnim.name') == 'singUP')
	check('Lua: notes know their strumline / singer', getPropertyFromGroup('unspawnNotes', 0, 'strumLine') ~= nil)
	check('Psych opponentStrums / playerStrums still 4 each', getProperty('opponentStrums.length') == 4 and getProperty('playerStrums.length') == 4)
	flush()
end
