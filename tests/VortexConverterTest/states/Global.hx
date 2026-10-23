import Sys;
import sys.io.File;
import sys.FileSystem;
import tjson.TJSON;
import haxe.zip.Reader;
import haxe.crypto.Crc32;
import backend.WeekData;
import backend.compat.VSliceExport;
import backend.compat.CompatUtil;
import backend.compat.LuaToHScript;
import states.editors.VSliceConverterState;
import backend.MusicBeatState;

// V-Slice Converter test: converts the bundled example mod and the translated Codename test mod, then checks the
// output files. Needs Vortex-Example-Mod and (for part 2) the CompatCodename fixture in mods/.
var out = [];
var st = {t: 0.0, phase: 0};
function check(name, ok, ?info) { out.push((ok ? 'PASS ' : 'FAIL ') + name + (info != null ? ' -- ' + info : '')); }
function flush() { var f = File.append('vortex_convtest.txt', false); f.writeString(out.join('\n') + '\n'); f.close(); out.splice(0, out.length); }
function json(p) { return FileSystem.exists(p) ? TJSON.parse(File.getContent(p)) : null; }
function has(text, part) { return text != null && text.indexOf(part) > -1; }
function stamp(dir) { var a = []; for (f in CompatUtil.walk(dir)) a.push(f + '=' + CompatUtil.stamp(dir + f)); return a.join(';'); }

function onCreatePost() {
	if (getGlobalVar('cv_started', false)) return;
	setGlobalVar('cv_started', true);
	File.saveContent('vortex_convtest.txt', 'Vortex Engine V-Slice converter test\n');
	WeekData.reloadWeekFiles(false); // runs the compatibility layer (the Codename mod gets translated)

	var src = 'mods/Vortex-Example-Mod/';
	var before = stamp(src);
	if (FileSystem.exists('vortex_converted/Vortex-Example-Mod-vslice')) CompatUtil.deleteTree('vortex_converted/Vortex-Example-Mod-vslice');
	var rep = VSliceExport.run('Vortex-Example-Mod');
	var o = VSliceExport.lastOutput;
	check('output folder', o == 'vortex_converted/Vortex-Example-Mod-vslice/', o);
	check('source mod not changed', stamp(src) == before);
	var meta = json(o + 'data/songs/example-song/example-song-metadata.json');
	var chart = json(o + 'data/songs/example-song/example-song-chart.json');
	check('metadata + chart written', meta != null && chart != null);
	if (meta != null && chart != null) {
		check('metadata: name, BPM, characters (bf renamed away from the base game id), stage', meta.songName == 'Example Song' && meta.timeChanges[0].bpm == 100 && meta.playData.characters.player == 'bf-vortex-example-mod'
			&& meta.playData.characters.opponent == 'example-dad' && meta.playData.stage == 'example-stage', meta.playData.stage);
		check('metadata: Normal difficulty listed', meta.playData.difficulties.join(',') == 'normal', meta.playData.difficulties.join(','));
		var notes = chart.notes.normal;
		check('chart: all 118 notes, lanes 0-7, sorted by time', notes.length == 118 && notes.filter(function(n) return n.d < 0 || n.d > 7).length == 0, notes.length);
		var sorted = true;
		for (i in 1...notes.length) if (notes[i].t < notes[i - 1].t) sorted = false;
		check('chart: notes in time order', sorted);
		check('chart: scroll speed for normal', chart.scrollSpeed.normal != null);
		var focus = chart.events.filter(function(e) return e.e == 'FocusCamera');
		check('chart: camera sections -> FocusCamera events', focus.length > 1, focus.length);
	}
	check('custom event reported (not silently dropped)', has(rep.toText(), 'Example Event'));
	var ch = json(o + 'data/characters/example-dad.json');
	check('character -> V-Slice character JSON', ch != null && ch.renderType == 'sparrow' && ch.animations.length > 0 && ch.assetPath == 'characters/example-dad', ch != null ? ch.assetPath : null);
	var sg = json(o + 'data/stages/example-stage.json');
	check('stage -> V-Slice stage JSON with props + characters', sg != null && sg.props != null && sg.characters.bf != null && sg.characters.dad != null);
	var lv = json(o + 'data/levels/example-week.json');
	check('week -> level', lv != null && lv.songs.indexOf('example-song') > -1);
	check('audio: Inst + per-character vocals', FileSystem.exists(o + 'songs/example-song/Inst.ogg') && FileSystem.exists(o + 'songs/example-song/Voices-bf-vortex-example-mod.ogg') && FileSystem.exists(o + 'songs/example-song/Voices-example-dad.ogg'));

	// 0.7: nothing replaces a V-Slice base-game id; base-game characters the mod uses are exported under their own id
	var bfc = json(o + 'data/characters/bf-vortex-example-mod.json');
	check('0.7 base-game ids not overwritten (no data/characters/bf.json, bf exported as bf-vortex-example-mod)', !FileSystem.exists(o + 'data/characters/bf.json') && bfc != null && bfc.name == 'bf-vortex-example-mod');
	check('0.7 base-game picture copied into the mod (V-Slice\'s own may differ)', bfc != null && StringTools.startsWith(bfc.assetPath, 'vortex-example-mod-base/') && FileSystem.exists(o + 'images/' + bfc.assetPath + '.png') && FileSystem.exists(o + 'images/' + bfc.assetPath + '.xml'), bfc != null ? bfc.assetPath : null);
	// 0.7: exact placement: stage feet = Psych positions, global offsets 0, the rest in the animation offsets
	check('0.7 stage: character spots are Psych\'s positions', sg != null && sg.characters.bf.position[0] == 770 && sg.characters.bf.position[1] == 100 && sg.characters.dad.position[0] == 100, sg != null ? sg.characters.bf.position : null);
	var idle = null;
	if (bfc != null) for (a in bfc.animations) if (a.name == 'idle') idle = a;
	check('0.7 character: global offsets 0, position folded into the animation offsets', bfc != null && bfc.offsets[0] == 0 && bfc.offsets[1] == 0 && idle != null && idle.offsets[1] < -300, idle != null ? idle.offsets : null);
	// 0.7: the Lua custom event becomes a V-Slice event class
	var ev = o + 'scripts/events/VortexExampleModEventExampleEvent.hxc';
	var evText = FileSystem.exists(ev) ? File.getContent(ev) : '';
	check('0.7 Lua custom event -> V-Slice event script', has(evText, 'class VortexExampleModEventExampleEvent extends SongEvent') && has(evText, "super('Example Event')") && has(evText, 'function lua_onEvent') && has(evText, "cat('Example Event: ', cat(value1, cat(' / ', value2)))"));
	check('0.7 chart keeps the event with its values', chart != null && chart.events.filter(function(e) return e.e == 'Example Event' && e.v.value1 != null).length > 0);
	check('0.7 phone-ready zip made automatically', FileSystem.exists('vortex_converted/Vortex-Example-Mod-vslice.zip'));

	// 0.7: Lua -> HScript translator on assorted Lua
	var tr = new LuaToHScript();
	var lua = "local count = 0\nfunction onEvent(n, v1, v2)\n  local d = tonumber(v1) or 1\n  if n == 'X' and not (d > 5) then\n    count = count + 1\n  elseif d ~= 2 then\n    debugPrint('x' .. count)\n  else\n    for i = 1, 3 do d = d * 2 end\n  end\n  local t = {a = 1}\n  t.a = 2\n  runTimer('t', d, 1)\n  someUnknownFunction()\nend\nfunction onTimerCompleted(tag) cameraFlash('game', 'FFFFFF', 0.5) end";
	var body = tr.translate(lua);
	check('0.7 Lua translator: if/elseif/else, for, locals, tables, and/or/not, .., ~=', body != null && has(body, 'tonumber(v1)') && has(body, 't.a = 2;') && has(body, 'else if') && has(body, '!=') && has(body, 'var count:Dynamic = null') && tr.functions.indexOf('onTimerCompleted') > -1, tr.error);
	check('0.7 Lua translator: unknown Psych functions listed, not fatal', tr.unsupported.indexOf('someUnknownFunction') > -1 && has(body, "unsupportedCall('someUnknownFunction')"));
	var bad = new LuaToHScript();
	check('0.7 Lua translator: broken Lua reported, not crashing', bad.translate('function onEvent( if then') == null && bad.error != null, bad.error);
	// 0.7.2: a Lua table named like a Haxe class, functions defined into a table, text / key / class functions
	var tr2 = new LuaToHScript();
	var body2 = tr2.translate("Std = {}\nfunction Std.int(x) return math.floor(x) end\nfunction onCreatePost()\n  makeLuaText('t', 'hi', 300, 0, 20)\n  setTextColor('t', 'FF0000')\n  addLuaText('t')\n  local w = Std.int(2.5)\n  if keyJustPressed('accept') then setPropertyFromClass('flixel.FlxG', 'sound.music.volume', 0.5) end\nend");
	check('0.7.2 Lua translator: "Std = {}" renamed (Haxe Std kept), function Std.int put into the table', body2 != null && has(body2, 'l_Std = {};') && has(body2, "luaSet(l_Std, 'int'") && has(body2, 'l_Std.int(') && !has(body2, 'var Std:'), tr2.error);
	check('0.7.2 Lua translator: text, key and class functions supported', tr2.unsupported.length == 0, tr2.unsupported.join(', '));
	check('pictures copied', FileSystem.exists(o + 'images/characters/example-dad.png'));
	check('_polymod_meta.json written', json(o + '_polymod_meta.json') != null);
	var text = File.getContent(o + 'REPORT.txt');
	check('report: validation passed, iOS not claimed, Lua event script reported', has(text, 'validation: every written JSON file reads back correctly') && has(text, 'iOS: NOT VERIFIED') && has(text, 'scripts/events/VortexExampleModEventExampleEvent.hxc') && rep.errors.length == 0, rep.summary());

	// converting again replaces the converter's own folder
	VSliceExport.run('Vortex-Example-Mod');
	check('second run replaces its own output', VSliceExport.lastOutput == o && !FileSystem.exists('vortex_converted/Vortex-Example-Mod-vslice-2'));
	check('report explains where the mod folder goes (one folder too deep is ignored)', has(File.getContent(o + 'REPORT.txt'), 'mods/Vortex-Example-Mod-vslice/_polymod_meta.json exists'));

	// 0.6: Z makes a zip with the mod folder at the top, ready to unzip into V-Slice's mods/ (also on phones)
	var zip = VSliceExport.makeZip(o);
	check('zip made next to the output', zip == 'vortex_converted/Vortex-Example-Mod-vslice.zip' && FileSystem.exists(zip), zip);
	if (zip != null && FileSystem.exists(zip)) {
		var input = File.read(zip, true);
		var entries = Reader.readZip(input);
		input.close();
		var names = [];
		var metaOk = false;
		var instOk = false;
		for (e in entries) {
			names.push(e.fileName);
			// the zip's CRC32 of each file must match the original file (checks the content without unzipping)
			if (e.fileName == 'Vortex-Example-Mod-vslice/_polymod_meta.json')
				metaOk = e.crc32 == Crc32.make(File.getBytes(o + '_polymod_meta.json')) && json(o + '_polymod_meta.json').api_version == '0.8.0';
			if (e.fileName == 'Vortex-Example-Mod-vslice/songs/example-song/Inst.ogg')
				instOk = e.fileSize == FileSystem.stat(o + 'songs/example-song/Inst.ogg').size && e.crc32 == Crc32.make(File.getBytes(o + 'songs/example-song/Inst.ogg'));
		}
		var top = names.filter(function(n) return n.indexOf('Vortex-Example-Mod-vslice/') != 0).length == 0;
		var marker = names.filter(function(n) return n.indexOf('.vortex_vslice_export') > -1).length > 0;
		check('zip: mod folder at the top, _polymod_meta.json one level down, readable', top && metaOk && !marker, names.length + ' files');
		check('zip: audio stored byte for byte', instOk);
		check('zip: every converted file is in it', names.length == CompatUtil.walk(o).length - 1, names.length + ' / ' + (CompatUtil.walk(o).length - 1));
	}

	// a folder the converter did not make is never deleted
	CompatUtil.makeDirs('vortex_converted/CompatCodename-vslice');
	File.saveContent('vortex_converted/CompatCodename-vslice/mine.txt', 'not the converter\'s');
	var rc = VSliceExport.run('CompatCodename');
	check('someone else\'s folder kept, output goes to -vslice-2', FileSystem.exists('vortex_converted/CompatCodename-vslice/mine.txt') && VSliceExport.lastOutput == 'vortex_converted/CompatCodename-vslice-2/', VSliceExport.lastOutput);
	var cm = json(VSliceExport.lastOutput + 'data/songs/cne-test/cne-test-chart.json');
	check('translated Codename mod converts (from the Psych translation)', cm != null && cm.notes.normal.length == 4, cm != null ? cm.notes.normal.length : null);
	check('extra strumline notes reported for manual work', has(rc.toText(), 'extra strumlines'));
	check('Codename song audio from song/ folder copied', FileSystem.exists(VSliceExport.lastOutput + 'songs/cne-test/Inst.ogg'));
	flush();
	MusicBeatState.switchState(new VSliceConverterState());
}

function onUpdate(elapsed) {
	if (getStateName() != 'VSliceConverterState') return;
	st.t += elapsed;
	if (st.t > 1.5 && st.phase == 0) { st.phase = 1; File.saveContent('shot_converter.txt', '1'); }
	if (st.t > 3 && st.phase == 1) { out.push('DONE'); flush(); Sys.exit(0); }
}
