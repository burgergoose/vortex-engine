function new(self, size)
	makeGraphic(self, size or 20, size or 20, 'FF00FF')
	addLuaSprite(self)
end
function stPing(self, v) setGlobalVar('st_pingClass', self .. ':' .. tostring(v)) end
function onBeatHit(self)
	setGlobalVar('st_classBeat', getGlobalVar('st_classBeat', 0) + 1)
	setGlobalVar('st_classCurBeat', curBeat)
	setProperty(self .. '.angle', curBeat * 15)
end
