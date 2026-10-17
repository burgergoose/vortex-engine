-- runs in every menu / custom state
function onCreatePost()
	setGlobalVar('st_globalRuns', getGlobalVar('st_globalRuns', 0) + 1)
	if not getGlobalVar('st_started', false) then
		setGlobalVar('st_started', true)
		switchState('SelfTestMenu')
	end
end

function stPing(v) setGlobalVar('st_pingGlobal', v) end
