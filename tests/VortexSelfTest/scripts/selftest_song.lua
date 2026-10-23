local lines = {}
local function check(name, ok, info)
	lines[#lines + 1] = (ok and 'PASS ' or 'FAIL ') .. name .. (info ~= nil and (' -- ' .. tostring(info)) or '')
end
local function flush()
	local f = io.open('vortex_selftest.txt', 'a')
	for _, l in ipairs(lines) do f:write(l .. '\n') end
	f:close()
	lines = {}
end

local spawnAt = nil
local hits = 0
function onCreatePost()
	check('global vars survive into the song', getGlobalVar('st_started') == true)
	check('chart build time recorded', getProperty('chartBuildMs') ~= nil, tostring(getProperty('chartBuildMs')) .. 'ms')
	setProperty('cpuControlled', true)
	createScripted('SelfTestThing', 'thing2', 0, 0)
	flush()
end

function onSongStart()
	spawnAt = getSongPosition()
	check('spawnNote (normal)', spawnNote(spawnAt + 1500, 1, true, 'SelfTestNote', 0))
	check('spawnNote (hold)', spawnNote(spawnAt + 1900, 2, true, '', 300))
	check('spawnNote (opponent)', spawnNote(spawnAt + 2400, 0, false))
	local f = io.open('vortex_selftest_song.txt', 'w'); f:write('1'); f:close()
	check('spawnNote loads its note type script', getGlobalVar('st_typeLoaded') == true)
	flush()
end

function goodNoteHit(id, dir, ntype, sus)
	hits = hits + 1
	if ntype == 'SelfTestNote' then setGlobalVar('st_hitSpawned', true) end
end

local done = false
local keyHits = 0
local rawHits = 0
local acceptHits = 0
function onUpdate(elapsed)
	if keyJustPressed('selftest_special') then keyHits = keyHits + 1 end
	if keyboardJustPressed('SPACE') then rawHits = rawHits + 1 end
	if keyJustPressed('accept') then acceptHits = acceptHits + 1 end
	if spawnAt ~= nil and not done and getSongPosition() > spawnAt + 6000 then
		done = true
		check('spawned note reached the player and was hit (botplay)', getGlobalVar('st_hitSpawned') == true, hits .. ' hits')
		check('note type script got goodNoteHit', getGlobalVar('st_typeHit') == true)
		check('scripted classes get song callbacks (onBeatHit)', getGlobalVar('st_classBeat', 0) > 0, getGlobalVar('st_classBeat', 0))
		check('mod keybind sees real key presses (SPACE sent by Windows)', keyHits > 0, keyHits .. ' presses (raw SPACE: ' .. rawHits .. ', accept bind: ' .. acceptHits .. ')')
		check('classes see current curBeat', getGlobalVar('st_classCurBeat', 0) > 0 and math.abs(getGlobalVar('st_classCurBeat', 0) - curBeat) <= 1, tostring(getGlobalVar('st_classCurBeat', 0)) .. ' vs ' .. curBeat)
		check('no new script errors in the song', getScriptErrorCount() == 1, getScriptErrorCount())
		lines[#lines + 1] = 'DONE'
		flush()
		os.exit(0)
	end
end
