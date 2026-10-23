function onCreate() setGlobalVar('st_typeLoaded', true) end
function goodNoteHit(id, dir, ntype, sus)
	if ntype == 'SelfTestNote' then setGlobalVar('st_typeHit', true) end
end
