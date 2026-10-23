package backend.compat;

import backend.compat.ChartBuilder;

/**
 * VORTEX ENGINE ADDITION - reads a Codename Engine mod and writes Psych-format copies into the compatibility cache.
 *
 * Codename layout handled here:
 *   songs/<song>/charts/<difficulty>.json  (strumLines [{characters, type 0 opponent / 1 player / 2 additional,
 *                                           notes [{time, id, sLen, type}], position, visible}], events [{time, name, params}],
 *                                           noteTypes, scrollSpeed, stage)
 *   songs/<song>/meta.json                  (bpm, displayName, icon, color, needsVoices)
 *   songs/<song>/song/Inst.ogg, Voices.ogg (Vortex finds audio in this sub-folder)
 *   data/characters/<id>.xml   data/stages/<id>.xml   data/weeks/weeks/<id>.xml (+ data/weeks/weeks.txt)
 * Codename strumlines map straight onto Vortex strumlines (first player line = strumline 1, first opponent line =
 * strumline 2, the rest become extra strumlines). Scripts (.hx) use Codename's own classes and are listed for porting.
 */
class CodenameImport
{
	static final DIFF_ORDER:Array<String> = ['normal', 'hard', 'easy'];

	public static function run(root:String, out:String, report:CompatReport):Void
	{
		var chars:Map<String, String> = []; // id -> health icon
		for (file in CompatUtil.list(root + 'data/characters/'))
		{
			if (!file.toLowerCase().endsWith('.xml')) continue;
			var id:String = CompatUtil.baseName(file);
			var err:Array<String> = [];
			var xml:Xml = CompatUtil.readXml(root + 'data/characters/' + file, err);
			if (xml == null) { report.error('character $id: not valid XML (${err.join('')})'); continue; }
			try
			{
				var psych:Dynamic = characterToPsych(xml, id, root, report);
				CompatUtil.writeJson(out + 'characters/$id.json', psych);
				chars.set(id, psych.healthicon);
				report.ok('character $id');
			}
			catch (e:Dynamic) report.error('character $id: $e');
		}

		var stages:Array<String> = [];
		for (file in CompatUtil.list(root + 'data/stages/'))
		{
			if (!file.toLowerCase().endsWith('.xml')) continue;
			var id:String = CompatUtil.baseName(file);
			var err:Array<String> = [];
			var xml:Xml = CompatUtil.readXml(root + 'data/stages/' + file, err);
			if (xml == null) { report.error('stage $id: not valid XML (${err.join('')})'); continue; }
			try
			{
				CompatUtil.writeJson(out + 'stages/$id.json', stageToPsych(xml, id, report));
				stages.push(id);
				report.ok('stage $id');
			}
			catch (e:Dynamic) report.error('stage $id: $e');
		}

		var songInfo:Map<String, Dynamic> = [];
		for (folder in CompatUtil.list(root + 'songs/'))
		{
			if (!CompatUtil.isDir(root + 'songs/$folder/charts')) continue;
			try
			{
				var info:Dynamic = importSong(root, folder, out, stages, chars, report);
				if (info != null) songInfo.set(Paths.formatToSongPath(folder), info);
			}
			catch (e:Dynamic) report.error('song $folder: $e');
		}

		// weeks
		var claimed:Array<String> = [];
		var order:Array<String> = [];
		var weekDir:String = root + 'data/weeks/weeks/';
		var weekFiles:Array<String> = CompatUtil.list(weekDir).filter(function(f) return f.toLowerCase().endsWith('.xml'));
		var listed:String = CompatUtil.readText(root + 'data/weeks/weeks.txt');
		if (listed != null)
		{
			var ordered:Array<String> = [];
			for (l in listed.split('\n')) { l = l.trim(); if (l.length > 0 && weekFiles.contains('$l.xml')) ordered.push('$l.xml'); }
			for (f in weekFiles) if (!ordered.contains(f)) ordered.push(f);
			weekFiles = ordered;
		}
		for (file in weekFiles)
		{
			var id:String = CompatUtil.baseName(file);
			var err:Array<String> = [];
			var xml:Xml = CompatUtil.readXml(weekDir + file, err);
			if (xml == null) { report.error('week $id: not valid XML (${err.join('')})'); continue; }
			var songs:Array<Dynamic> = [];
			for (s in xml.elementsNamed('song'))
			{
				var name:String = s.get('name');
				if (name == null && s.firstChild() != null) name = s.firstChild().nodeValue;
				if (name == null) continue;
				var key:String = Paths.formatToSongPath(name.trim());
				var si:Dynamic = songInfo.get(key);
				if (si == null) { report.warn('week $id lists song "$name", which has no usable chart in songs/'); continue; }
				songs.push([si.display, si.icon, si.color]);
				claimed.push(key);
			}
			if (songs.length < 1) { report.warn('week $id has no usable songs, skipped'); continue; }
			var weekChars:Array<String> = ['', 'bf', 'gf'];
			var charsAttr:String = xml.get('chars');
			if (charsAttr != null)
			{
				var parts:Array<String> = charsAttr.split(',');
				for (i in 0...3) if (i < parts.length) weekChars[i] = parts[i].trim();
				for (c in weekChars) if (c.length > 0 && !CompatUtil.exists('assets/shared/images/menucharacters/$c.json') && !CompatUtil.exists('assets/shared/images/menucharacters/$c.png'))
					report.warn('week $id: Story Mode character "$c" has no Psych menu character file; it may not show.');
			}
			var name:String = CompatUtil.str(xml.get('name'), id);
			CompatUtil.writeJson(out + 'weeks/$id.json', {
				songs: songs, weekCharacters: weekChars, weekBackground: '', weekBefore: '',
				storyName: name, weekName: name, startUnlocked: true, hiddenUntilUnlocked: false,
				hideStoryMode: false, hideFreeplay: false, difficulties: ''
			});
			order.push(id);
			report.ok('week $id "$name" (${songs.length} songs)');
		}

		var unlisted:Array<Dynamic> = [];
		var keys:Array<String> = [for (k in songInfo.keys()) k];
		keys.sort(Reflect.compare);
		for (k in keys) if (!claimed.contains(k)) { var si:Dynamic = songInfo.get(k); unlisted.push([si.display, si.icon, si.color]); }
		if (unlisted.length > 0)
		{
			CompatUtil.writeJson(out + 'weeks/codename-freeplay.json', {
				songs: unlisted, weekCharacters: ['', 'bf', 'gf'], weekBackground: '', weekBefore: '',
				storyName: 'Freeplay', weekName: 'Freeplay', startUnlocked: true, hiddenUntilUnlocked: false,
				hideStoryMode: true, hideFreeplay: false, difficulties: ''
			});
			order.push('codename-freeplay');
			report.note('${unlisted.length} songs are not in any week; they are listed in Freeplay only.');
		}
		if (order.length > 0) CompatUtil.writeText(out + 'weeks/weekList.txt', order.join('\n'));

		CompatScan.scanScripts(root, report, 'codename');
	}

	static function importSong(root:String, folder:String, out:String, stages:Array<String>, chars:Map<String, String>, report:CompatReport):Dynamic
	{
		var dir:String = root + 'songs/$folder/';
		var files:Array<String> = CompatUtil.list(dir + 'charts/').filter(function(f) return f.toLowerCase().endsWith('.json'));
		if (files.length < 1) { report.warn('songs/$folder/charts/ has no charts, skipped'); return null; }
		var diff:String = null;
		for (d in DIFF_ORDER) if (files.contains('$d.json')) { diff = d; break; }
		if (diff == null) diff = CompatUtil.baseName(files[0]);
		var others:Array<String> = [for (f in files) if (f != '$diff.json') CompatUtil.baseName(f)];
		if (others.length > 0) report.note('$folder: imported the "$diff" chart; Vortex has one difficulty, so ${others.join(', ')} were not imported.');

		var err:Array<String> = [];
		var chart:Dynamic = CompatUtil.readJson(dir + 'charts/$diff.json', err);
		if (chart == null) { report.error('$folder: charts/$diff.json is not valid JSON (${err.join('')})'); return null; }
		var meta:Dynamic = CompatUtil.readJson(dir + 'meta.json');
		if (meta == null) meta = CompatUtil.field(chart, 'meta', {});
		if (meta == null) meta = {};
		if (CompatUtil.field(chart, 'codenameChart', null) == null) report.warn('$folder: chart has no "codenameChart" flag; read it as a Codename chart anyway.');

		var startBpm:Float = CompatUtil.num(meta.bpm, 100);
		var bpms:Array<BpmChange> = [{time: 0, bpm: startBpm}];
		var speed:Float = CompatUtil.num(chart.scrollSpeed, 1);
		var noteTypes:Array<Dynamic> = CompatUtil.isArray(chart.noteTypes) ? chart.noteTypes : [];

		// strumlines
		var lines:Array<Dynamic> = CompatUtil.isArray(chart.strumLines) ? chart.strumLines : [];
		if (lines.length < 1) { report.error('$folder: the chart has no strumLines'); return null; }
		var playerIdx:Int = -1, oppIdx:Int = -1, gfIdx:Int = -1;
		for (i in 0...lines.length)
		{
			var type:Int = Std.int(CompatUtil.num(lines[i].type, 0));
			var noteCount:Int = CompatUtil.isArray(lines[i].notes) ? lines[i].notes.length : 0;
			if (type == 1 && playerIdx < 0) playerIdx = i;
			else if (type == 0 && oppIdx < 0) oppIdx = i;
			else if (type == 2 && gfIdx < 0 && noteCount == 0) gfIdx = i;
		}
		if (playerIdx < 0) report.warn('$folder: no player strumline (type 1); strumline 1 is empty.');
		if (oppIdx < 0) report.warn('$folder: no opponent strumline (type 0); strumline 2 is empty.');
		var order:Array<Int> = [playerIdx, oppIdx];
		for (i in 0...lines.length) if (i != playerIdx && i != oppIdx && i != gfIdx) order.push(i);
		if (order.length > backend.StrumLineData.MAX_LINES)
		{
			report.warn('$folder: ${order.length} strumlines; Vortex supports ${backend.StrumLineData.MAX_LINES}, the rest were left out.');
			order = order.slice(0, backend.StrumLineData.MAX_LINES);
		}
		var lineOf:Map<Int, Int> = [];
		for (vi in 0...order.length) if (order[vi] >= 0) lineOf.set(order[vi], vi);

		function charsOf(i:Int):Array<String>
		{
			if (i < 0) return [];
			var c:Array<Dynamic> = CompatUtil.isArray(lines[i].characters) ? lines[i].characters : [];
			return [for (x in c) Std.string(x)];
		}
		var p1:Array<String> = charsOf(playerIdx), p2:Array<String> = charsOf(oppIdx), gfc:Array<String> = charsOf(gfIdx);
		var player1:String = p1.length > 0 ? p1[0] : 'bf';
		var player2:String = p2.length > 0 ? p2[0] : 'dad';
		var gf:String = gfc.length > 0 ? gfc[0] : 'gf';
		if (gfIdx < 0) gf = CompatUtil.str(meta.gf, 'gf');

		var strumLines:Array<Dynamic> = [];
		var needsLines:Bool = order.length > 2 || p1.length > 1 || p2.length > 1;
		for (vi in 0...order.length)
		{
			var i:Int = order[vi];
			var src:Dynamic = (i >= 0) ? lines[i] : {};
			var type:Int = Std.int(CompatUtil.num(src.type, vi == 0 ? 1 : 0));
			var pos:String = switch (CompatUtil.str(src.position, '')) { case 'boyfriend' | 'bf': 'boyfriend'; case 'girlfriend' | 'gf': 'gf'; case 'dad' | 'opponent': 'dad'; default: type == 1 ? 'boyfriend' : (type == 2 ? 'gf' : 'dad'); };
			var names:Array<String> = charsOf(i);
			if (names.length < 1) names = [vi == 0 ? 'bf' : (vi == 1 ? 'dad' : 'gf')];
			strumLines.push({
				name: vi == 0 ? 'Player' : (vi == 1 ? 'Opponent' : 'Strumline ${vi + 1}'),
				type: vi == 0 ? 'player' : (vi == 1 ? 'opponent' : (type == 1 ? 'player' : (type == 0 ? 'opponent' : 'additional'))),
				characters: [for (n in names) {name: n, position: pos, x: 0, y: 0}],
				visible: CompatUtil.bool(src.visible, true)
			});
		}

		var notes:Array<TimedNote> = [];
		var typeNames:Array<String> = [];
		for (li => vi in lineOf)
		{
			var src:Array<Dynamic> = CompatUtil.isArray(lines[li].notes) ? lines[li].notes : [];
			for (n in src)
			{
				var t:Float = CompatUtil.num(n.time, Math.NaN);
				var id:Int = Std.int(CompatUtil.num(n.id, -1));
				if (Math.isNaN(t) || id < 0 || id > 3) { report.warn('$folder: a note with a bad time or direction (id ${n.id}) was left out.'); continue; }
				var typeIdx:Int = Std.int(CompatUtil.num(n.type, 0));
				var typeName:String = (typeIdx > 0 && typeIdx <= noteTypes.length) ? Std.string(noteTypes[typeIdx - 1]) : '';
				if (typeName.length > 0 && !typeNames.contains(typeName)) typeNames.push(typeName);
				notes.push({time: t, column: vi * 4 + id, length: CompatUtil.num(n.sLen, 0), type: typeName});
			}
		}
		for (t in typeNames) report.needs('$folder: note type "$t" needs custom_notetypes/$t.lua (Codename\'s data/notes/$t.hx does not run in Vortex); without it these play as normal notes.');

		// events
		var focus:Array<CamFocus> = [];
		var events:Array<TimedEvent> = [];
		var evs:Array<Dynamic> = CompatUtil.isArray(chart.events) ? chart.events : [];
		for (e in evs)
		{
			var t:Float = CompatUtil.num(e.time, Math.NaN);
			var name:String = CompatUtil.str(e.name, '');
			var params:Array<Dynamic> = CompatUtil.isArray(e.params) ? e.params : [];
			if (Math.isNaN(t) || name.length < 1) { report.warn('$folder: an event without a time or name was left out'); continue; }
			switch (name)
			{
				case 'Camera Movement':
					var li:Int = Std.int(CompatUtil.num(params[0], 0));
					var who:Int = (li == gfIdx) ? 2 : (lineOf.exists(li) ? (strumLines[lineOf.get(li)].type == 'player' ? 0 : 1) : 1);
					focus.push({time: t, who: who});
				case 'BPM Change':
					var b:Float = CompatUtil.num(params[0], startBpm);
					if (b > 0) bpms.push({time: t, bpm: b});
				case 'Add Camera Zoom':
					var amount:String = CompatUtil.str(params[0], '0.015');
					var hud:Bool = CompatUtil.str(params[1], 'camGame').toLowerCase().indexOf('hud') > -1;
					events.push({time: t, name: 'Add Camera Zoom', v1: hud ? '0' : amount, v2: hud ? amount : '0'});
				case 'Play Animation':
					var li:Int = Std.int(CompatUtil.num(params[0], 0));
					var target:String = (li == gfIdx) ? 'gf' : (lineOf.exists(li) && lineOf.get(li) == 0 ? 'bf' : 'dad');
					events.push({time: t, name: 'Play Animation', v1: CompatUtil.str(params[1], 'hey'), v2: target});
				case 'Scroll Speed Change':
					var tween:Bool = CompatUtil.bool(params[0], false);
					var newSpeed:Float = CompatUtil.num(params[1], speed);
					var dur:Float = tween ? ChartBuilder.stepsToSeconds(CompatUtil.num(params[2], 4), ChartBuilder.bpmAt(bpms, t, startBpm)) : 0;
					events.push({time: t, name: 'Change Scroll Speed', v1: Std.string(Math.round(newSpeed / Math.max(0.01, speed) * 1000) / 1000), v2: Std.string(Math.round(dur * 1000) / 1000)});
				default:
					events.push({time: t, name: name, v1: params.length > 0 ? Std.string(params[0]) : '', v2: params.length > 1 ? [for (i in 1...params.length) Std.string(params[i])].join(',') : ''});
					report.needs('$folder: Codename event "$name" was kept in the chart, but its Codename script does not run in Vortex. Add custom_events/$name.lua.');
			}
		}

		var stage:String = CompatUtil.str(chart.stage, CompatUtil.str(meta.stage, 'stage'));
		if (!stages.contains(stage) && !CompatUtil.exists('assets/shared/stages/$stage.json') && !backend.StageData.isBuiltIn(stage))
			report.warn('$folder: stage "$stage" is not in this mod or the base game; the default stage is used.');
		for (c in p1.concat(p2).concat(gfc))
			if (!chars.exists(c) && !CompatUtil.exists('assets/shared/characters/$c.json'))
				report.warn('$folder: character "$c" is not in this mod or the base game; Boyfriend is shown in its place.');

		var audio:String = dir + 'song/';
		if (!CompatUtil.exists(audio + 'Inst.ogg') && !CompatUtil.exists(audio + 'Inst.wav') && !CompatUtil.exists(dir + 'Inst.ogg'))
			report.error('$folder: songs/$folder/song/Inst.ogg is missing, the song will show the "Inst not found" screen.');
		var voices:Array<String> = CompatUtil.list(audio).filter(function(f) return f.startsWith('Voices'));
		var extraVoices:Array<String> = voices.filter(function(f) return f != 'Voices.ogg' && f != 'Voices-Player.ogg' && f != 'Voices-Opponent.ogg' && f != 'Voices.wav');
		if (extraVoices.length > 0) report.warn('$folder: per-strumline vocal files (${extraVoices.join(', ')}) are only used when their name matches a character (Voices-<character>.ogg).');

		var display:String = CompatUtil.str(meta.displayName, CompatUtil.str(meta.name, folder));
		if (Paths.formatToSongPath(display) != Paths.formatToSongPath(folder)) display = folder;
		var info:Dynamic = {
			bpm: startBpm, speed: speed, needsVoices: CompatUtil.bool(meta.needsVoices, voices.length > 0),
			player1: player1, player2: player2, gfVersion: gf, stage: stage, source: 'Codename Engine, difficulty $diff'
		};
		if (needsLines) info.strumLines = strumLines;
		var psych:Dynamic = ChartBuilder.build(Paths.formatToSongPath(folder), notes, bpms, focus, events, info, report);
		psych.song = display;
		var key:String = Paths.formatToSongPath(folder);
		CompatUtil.writeJson(out + 'data/$key/$key.json', psych);
		report.ok('song $folder: ${notes.length} notes on ${order.length} strumlines, ${bpms.length} BPM section(s), ${events.length} events ("$diff" chart)');

		var icon:String = CompatUtil.str(meta.icon, chars.exists(player2) ? chars.get(player2) : player2);
		return {display: display, icon: icon, color: CompatUtil.rgb(meta.color, [146, 113, 253])};
	}

	public static function characterToPsych(xml:Xml, id:String, root:String, report:CompatReport):Dynamic
	{
		var anims:Array<Dynamic> = [];
		for (a in xml.elementsNamed('anim'))
		{
			anims.push({
				anim: CompatUtil.str(a.get('name'), 'idle'),
				name: CompatUtil.str(a.get('anim'), CompatUtil.str(a.get('name'), 'idle')),
				fps: Std.int(CompatUtil.num(a.get('fps'), 24)),
				loop: CompatUtil.bool(a.get('loop'), false),
				indices: CompatUtil.parseIndices(a.get('indices')),
				offsets: [Std.int(CompatUtil.num(a.get('x'), 0)), Std.int(CompatUtil.num(a.get('y'), 0))]
			});
		}
		var sprite:String = CompatUtil.str(xml.get('sprite'), id);
		var image:String = 'characters/$sprite';
		if (!CompatUtil.exists(root + 'images/$image.png') && !CompatUtil.exists('assets/shared/images/$image.png') && !CompatUtil.isDir(root + 'images/$image'))
			report.warn('character $id: picture images/$image.png was not found in the mod or the base game.');
		var isPlayer:Bool = CompatUtil.bool(xml.get('isPlayer'), false);
		var flip:Bool = CompatUtil.bool(xml.get('flipX'), false);
		return {
			animations: anims,
			image: image,
			scale: CompatUtil.num(xml.get('scale'), 1),
			sing_duration: CompatUtil.num(xml.get('holdTime'), 4),
			healthicon: CompatUtil.str(xml.get('icon'), id),
			position: [CompatUtil.num(xml.get('x'), 0), CompatUtil.num(xml.get('y'), 0)],
			camera_position: [CompatUtil.num(xml.get('camx'), 0), CompatUtil.num(xml.get('camy'), 0)],
			flip_x: isPlayer != flip, // Codename flips player-made characters itself; Psych stores the result
			no_antialiasing: CompatUtil.bool(xml.get('antialiasing'), true) == false,
			healthbar_colors: CompatUtil.rgb(xml.get('color'), [161, 161, 161]),
			vocals_file: id,
			_editor_isPlayer: isPlayer,
			_vortex_source: 'Codename Engine character'
		};
	}

	public static function stageToPsych(xml:Xml, id:String, report:CompatReport):Dynamic
	{
		var folder:String = CompatUtil.str(xml.get('folder'), '');
		if (folder.length > 0 && !folder.endsWith('/')) folder += '/';
		var result:Dynamic = {
			directory: '', defaultZoom: CompatUtil.num(xml.get('zoom'), 1.05), stageUI: 'normal',
			boyfriend: [770, 100], girlfriend: [400, 130], opponent: [100, 100], hide_girlfriend: false,
			camera_boyfriend: [0, 0], camera_opponent: [0, 0], camera_girlfriend: [0, 0], camera_speed: 1,
			_vortex_source: 'Codename Engine stage'
		};
		var objects:Array<Dynamic> = [];
		var seen:Array<String> = [];
		var n:Int = 0;

		function walk(parent:Xml)
		{
			for (node in parent.elements())
			{
				var tag:String = node.nodeName.toLowerCase();
				switch (tag)
				{
					case 'high-memory' | 'low-memory':
						if (tag == 'low-memory') report.note('stage $id: a <low-memory> group was added for everyone.');
						walk(node);
					case 'sprite' | 'spr' | 'sparrow':
						var name:String = CompatUtil.str(node.get('name'), 'sprite${n++}');
						var scroll:Float = CompatUtil.num(node.get('scroll'), 1);
						var scale:Float = CompatUtil.num(node.get('scale'), 1);
						var obj:Dynamic = {
							name: name, image: folder + CompatUtil.str(node.get('sprite'), name),
							x: CompatUtil.num(node.get('x'), 0), y: CompatUtil.num(node.get('y'), 0),
							scale: [CompatUtil.num(node.get('scalex'), scale), CompatUtil.num(node.get('scaley'), scale)],
							scroll: [CompatUtil.num(node.get('scrollx'), scroll), CompatUtil.num(node.get('scrolly'), scroll)],
							alpha: CompatUtil.num(node.get('alpha'), 1), angle: CompatUtil.num(node.get('angle'), 0),
							antialiasing: CompatUtil.bool(node.get('antialiasing'), true), flipX: CompatUtil.bool(node.get('flipX'), false),
							color: CompatUtil.str(node.get('color'), 'FFFFFF').replace('#', ''), filters: 0
						};
						var anims:Array<Dynamic> = [for (a in node.elementsNamed('anim')) {
							anim: CompatUtil.str(a.get('name'), 'idle'), name: CompatUtil.str(a.get('anim'), CompatUtil.str(a.get('name'), 'idle')),
							fps: Std.int(CompatUtil.num(a.get('fps'), 24)), loop: CompatUtil.bool(a.get('loop'), true),
							indices: CompatUtil.parseIndices(a.get('indices')), offsets: [Std.int(CompatUtil.num(a.get('x'), 0)), Std.int(CompatUtil.num(a.get('y'), 0))]
						}];
						if (anims.length > 0)
						{
							obj.type = 'animatedSprite';
							obj.animations = anims;
							obj.firstAnimation = anims[0].anim;
							if (node.get('type') == 'beat' || node.get('beatInterval') != null) report.warn('stage $id: "$name" plays its animation on the beat in Codename; in Vortex it plays once/loops (add a stage script for beat animations).');
						}
						else obj.type = 'sprite';
						objects.push(obj);
					case 'solid' | 'box':
						var name:String = CompatUtil.str(node.get('name'), 'solid${n++}');
						objects.push({
							type: 'square', name: name, x: CompatUtil.num(node.get('x'), 0), y: CompatUtil.num(node.get('y'), 0),
							scale: [CompatUtil.num(node.get('width'), 100), CompatUtil.num(node.get('height'), 100)],
							scroll: [CompatUtil.num(node.get('scroll'), 1), CompatUtil.num(node.get('scroll'), 1)],
							color: CompatUtil.str(node.get('color'), 'FFFFFF').replace('#', ''), alpha: CompatUtil.num(node.get('alpha'), 1), filters: 0
						});
					case 'boyfriend' | 'bf' | 'girlfriend' | 'gf' | 'dad' | 'opponent':
						var slot:String = (tag == 'bf' || tag == 'boyfriend') ? 'boyfriend' : ((tag == 'gf' || tag == 'girlfriend') ? 'gf' : 'dad');
						var field:String = (slot == 'boyfriend') ? 'boyfriend' : (slot == 'gf' ? 'girlfriend' : 'opponent');
						var def:Array<Float> = Reflect.field(result, field);
						Reflect.setField(result, field, [CompatUtil.num(node.get('x'), def[0]), CompatUtil.num(node.get('y'), def[1])]);
						Reflect.setField(result, 'camera_' + field, [CompatUtil.num(node.get('camxoffset'), 0), CompatUtil.num(node.get('camyoffset'), 0)]);
						if (node.get('scroll') != null && CompatUtil.num(node.get('scroll'), 1) != 1) report.warn('stage $id: $slot has a scroll factor in Codename; Vortex characters keep the default.');
						if (!seen.contains(slot)) { seen.push(slot); objects.push({type: slot}); }
					default:
						report.warn('stage $id: <${node.nodeName}> is a Codename-only stage element and was not converted.');
				}
			}
		}
		walk(xml);
		for (slot in ['gf', 'dad', 'boyfriend']) if (!seen.contains(slot)) objects.push({type: slot});
		result.objects = objects;
		var cam:Float = CompatUtil.num(xml.get('startCamPosX'), Math.NaN);
		if (!Math.isNaN(cam)) report.note('stage $id: startCamPosX/Y are not used by Vortex (the camera starts on the characters).');
		return result;
	}
}
