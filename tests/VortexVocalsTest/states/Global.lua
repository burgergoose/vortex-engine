function onCreatePost()
	if getStateName() == 'AudioRunner' then return end
	if not getGlobalVar('at_started', false) then
		setGlobalVar('at_started', true)
		local f = io.open('vortex_audiotest.txt', 'w'); f:write('Vortex Engine pause/resume vocals test\n'); f:close()
		switchState('AudioRunner')
	end
end
