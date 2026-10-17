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

function onCreate()
	local f = io.open('vortex_selftest.txt', 'w'); f:write('Vortex Engine self test\n'); f:close()
	check('custom state opened', getStateName() == 'SelfTestMenu', getStateName())
	check('states/Global.lua ran in the first state', getGlobalVar('st_globalRuns', 0) >= 1, getGlobalVar('st_globalRuns', 0))

	local ok, m = pcall(require, 'stmath')
	check('require() finds mods/<mod>/lib/', ok and m.double(21) == 42, ok and nil or m)

	check('getGlobalVar default', getGlobalVar('st_missing', 'dflt') == 'dflt')
	check('globalVarExists', globalVarExists('st_started') and not globalVarExists('st_missing'))

	check('keybind from data/keybinds.json', keybindExists('selftest_special'), table.concat(getKeybind('selftest_special'), ','))
	check('keyJustPressed works in menus', keyJustPressed('selftest_special') == false and keyPressed('accept') == false)
	check('addKeybind at runtime', addKeybind('selftest_taunt', 'Taunt', {'T'}) and getKeybind('selftest_taunt')[1] == 'T')
	check('addKeybind refuses built-in ids', addKeybind('note_left', 'Hijack', {'Q'}) == false and getKeybind('note_left')[1] ~= 'Q')

	local rs = getRunningScripts()
	check('getRunningScripts in menus', type(rs) == 'table' and #rs >= 2, #rs)

	createScripted('SelfTestThing', 'thing1', 10, 10, 30)
	check('scripted class instance', scriptedExists('thing1') and getProperty('thing1.width') == 30, getProperty('thing1.width'))
	callOnScripts('stPing', {5})
	check('callOnScripts in menus reaches other state scripts', getGlobalVar('st_pingGlobal') == 5, getGlobalVar('st_pingGlobal'))
	check('callOnScripts reaches scripted classes', getGlobalVar('st_pingClass') == 'thing1:5', getGlobalVar('st_pingClass'))
	setOnScripts('st_shared', 99)
	check('setOnScripts in menus (no crash)', true)
	check('isRunning in menus', isRunning('mods/VortexSelfTest/states/Global.lua'))

	flush()
end

local subFrames = 0
function onCustomSubstateCreate(name)
	setGlobalVar('st_subCreated', name)
	makeLuaText('infoText', 'Press ENTER to close', 600, 340, 340)
	addLuaText('infoText')
	setGlobalVar('st_subInsert', insertToCustomSubstate('infoText'))
end
function onCustomSubstateUpdate(name, elapsed)
	subFrames = subFrames + 1
	if subFrames == 3 then closeCustomSubstate() end
end
function onCustomSubstateDestroy(name) setGlobalVar('st_subDestroyed', name) end

local frame = 0
local erred = false
function onUpdate(elapsed)
	frame = frame + 1
	if frame == 2 then openCustomSubstate('stSub') end
	if frame == 5 and not erred then
		erred = true
		local broken = nil
		broken.field = 1 -- intentional runtime error: must be logged once with a traceback
	end
	if frame == 30 then
		check('custom substate in a menu', getGlobalVar('st_subCreated') == 'stSub' and getGlobalVar('st_subDestroyed') == 'stSub',
			tostring(getGlobalVar('st_subCreated', 'nil')) .. '/' .. tostring(getGlobalVar('st_subDestroyed', 'nil')))
		check('insertToCustomSubstate in a menu', getGlobalVar('st_subInsert') == true)
		check('runtime errors are counted once (not every frame)', getScriptErrorCount() == 1, getScriptErrorCount())
		local f = io.open('vortex_script_log.txt', 'r')
		local log = f and f:read('*a') or ''
		if f then f:close() end
		check('error log has file:line', string.find(log, 'SelfTestMenu.lua:%d+') ~= nil)
		check('error log has stack traceback', string.find(log, 'stack traceback') ~= nil)
		writeToScriptLog('self test reached the song step')
		flush()
		callOnHScript('stStartSong', {})
	end
	if frame == 600 then -- song never started
		check('song started from HScript', false)
		flush()
		os.exit(1)
	end
end
