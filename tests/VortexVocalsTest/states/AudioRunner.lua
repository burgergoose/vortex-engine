local songs = {
	{'at-single', 'VortexVocalsTest'}, {'at-split', 'VortexVocalsTest'}, {'at-opponly', 'VortexVocalsTest'},
	{'at-shortplayer', 'VortexVocalsTest'}, {'example-song', 'Vortex-Example-Mod'}
}
local frame = 0
function onUpdate(elapsed)
	frame = frame + 1
	if frame ~= 3 then return end
	local i = getGlobalVar('at_index', 1)
	if i > #songs then
		local f = io.open('vortex_audiotest.txt', 'a'); f:write('DONE\n'); f:close()
		os.exit(0)
	end
	callOnHScript('startSong', {songs[i][1], songs[i][2]})
end
