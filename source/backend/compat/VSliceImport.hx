package backend.compat;

import backend.compat.ChartBuilder;
import backend.compat.StageScriptReader;

/**
 * VORTEX ENGINE ADDITION - reads a V-Slice (Friday Night Funkin' 0.3+ / "Funkin' Weekend 1" engine, Polymod) mod and
 * writes Psych-format copies of its songs, characters, stages and levels into the compatibility cache.
 *
 * V-Slice layout handled here:
 *   data/songs/<id>/<id>-metadata.json  (song name, BPM / time changes, characters, stage, difficulties)
 *   data/songs/<id>/<id>-chart.json     (notes per difficulty {t,d,l,k}, scroll speeds, events {t,e,v})
 *   data/characters/<id>.json           data/stages/<id>.json           data/levels/<id>.json
 *   songs/<id>/Inst.ogg, Voices-<character>.ogg (same folder as Psych; Vortex looks for Voices-<character>)
 * Scripts (.hxc / .hx, Polymod HScript classes) call V-Slice's own Haxe classes and are listed for manual porting.
 * 0.6: stages built by a script (scripts/stages/<id>.hxc, empty "props") get the sprites read from that script.
 */
class VSliceImport
{
	/** V-Slice base-game stage ids -> the matching built-in Psych / Vortex stages. */
	public static final BASE_STAGES:Map<String, String> = [
		'mainStage' => 'stage', 'spookyMansion' => 'spooky', 'phillyTrain' => 'philly', 'limoRide' => 'limo',
		'mallXmas' => 'mall', 'mallEvil' => 'mallEvil', 'school' => 'school', 'schoolEvil' => 'schoolEvil',
		'tankmanBattlefield' => 'tank', 'phillyStreets' => 'phillyStreets', 'phillyBlazin' => 'phillyBlazin'
	];
	static final DIFF_ORDER:Array<String> = ['normal', 'hard', 'easy'];

	// a V-Slice character stands with its feet on its stage position; Psych positions are the top-left corner.
	// These offsets turn mainStage's V-Slice positions into exactly Psych's stage.json positions.
	// PlayState uses them too, to stand converted V-Slice characters on their feet (Character.vsliceOrigin).
	public static final SLOT_OFFSET:Map<String, Array<Float>> = ['bf' => [-219.5, -785], 'dad' => [-235, -785], 'gf' => [-351.5, -657]];
	// camera: V-Slice aims at the character's centre + its stage cameraOffsets (defaults below when a stage leaves them
	// out, from V-Slice's StageData); Psych's moveCamera adds its own fixed numbers (PSYCH_CAMERA), which are taken off
	static final VSLICE_CAMERA_DEFAULT:Map<String, Array<Float>> = ['bf' => [-100, -100], 'dad' => [100, -100], 'gf' => [0, 0]];
	static final PSYCH_CAMERA:Map<String, Array<Float>> = ['bf' => [-100, -100], 'dad' => [150, -100], 'gf' => [0, 0]];

	/** V-Slice library folders this mod has (relative to its root, with '/'), set by run(). */
	static var libs:Array<String> = [];

	// Vortex Engine 0.6: V-Slice stages that are built by a script (scripts/stages/<id>.hxc) instead of their json "props"
	static var stageScripts:Map<String, StageScript> = [];
	static var stageSources:Map<String, Dynamic> = [];
	static var stageBase:Map<String, String> = [];
	static var sizeCache:Map<String, Array<Float>> = [];

	/** Built-in Psych / Vortex events: a V-Slice chart that uses one of these names with {value1, value2} just works. */
	public static final PSYCH_EVENTS:Array<String> = ['Hey!', 'Set GF Speed', 'Add Camera Zoom', 'Play Animation', 'Camera Follow Pos',
		'Alt Idle Animation', 'Screen Shake', 'Change Character', 'Change Scroll Speed', 'Set Property', 'Play Sound', 'Change Stage', 'Zoom Camera', 'Focus Camera'];

	public static function run(root:String, out:String, report:CompatReport):Void
	{
		libs = [for (lib in CompatUtil.VSLICE_LIBRARIES) if (CompatUtil.isDir(root + lib)) lib + '/'];
		if (libs.length > 0) report.note('V-Slice library folders used for pictures / sounds: ' + libs.join(', ') + ' (Vortex looks there like V-Slice does).');

		// 0.6: find songs, characters, stages and levels by what is in the file, anywhere under data/ (real mods are not
		// always tidy). The standard places are data/songs/<id>/, data/characters/, data/stages/, data/levels/.
		var found = discover(root, report);

		var chars:Map<String, Dynamic> = [];
		for (c in found.characters)
		{
			try
			{
				var psych:Dynamic = characterToPsych(c.data, c.id, root, report);
				CompatUtil.writeJson(out + 'characters/${c.id}.json', psych);
				chars.set(c.id, c.data);
				report.ok('character ${c.id} (V-Slice ${CompatUtil.str(c.data.renderType, 'sparrow')})' + (c.path.startsWith('data/characters/') ? '' : ' found in ${c.path}'));
			}
			catch (e:Dynamic) report.error('character ${c.id}: $e');
		}

		stageScripts = StageScriptReader.findStageScripts(root);
		stageSources = [];
		stageBase = [];
		sizeCache = [];
		var stages:Array<String> = [];
		for (st in found.stages)
		{
			try
			{
				stageSources.set(st.id, st.data);
				var fromScript:Array<Dynamic> = scriptObjects(root, st.id, '', report);
				if (fromScript != null) stageBase.set(st.id, haxe.Json.stringify(fromScript));
				CompatUtil.writeJson(out + 'stages/${st.id}.json', stageToPsych(st.data, st.id, root, report, fromScript));
				stages.push(st.id);
				report.ok('stage ${st.id}' + (st.path.startsWith('data/stages/') ? '' : ' found in ${st.path}'));
			}
			catch (e:Dynamic) report.error('stage ${st.id}: $e');
		}

		var songInfo:Map<String, Dynamic> = [];
		var songIds:Array<String> = [for (k in found.songs.keys()) k];
		songIds.sort(Reflect.compare);
		for (id in songIds)
		{
			var entry = found.songs.get(id);
			try
			{
				var info:Dynamic = importSong(root, id, entry, out, stages, chars, report);
				if (info != null) songInfo.set(id, info);
			}
			catch (e:Dynamic) report.error('song $id: $e');
		}

		// levels -> weeks
		var claimed:Array<String> = [];
		var order:Array<String> = [];
		for (level in found.levels)
		{
			var id:String = level.id;
			var lv:Dynamic = level.data;
			var songs:Array<Dynamic> = [];
			var list:Array<Dynamic> = CompatUtil.isArray(lv.songs) ? lv.songs : [];
			for (s in list)
			{
				var sid:String = Std.string(s).trim();
				var si:Dynamic = songInfo.get(sid);
				if (si == null) si = songInfo.get(sid.toLowerCase());
				if (si == null) { report.warn('level $id lists song "$sid", which has no usable chart in data/songs/$sid/'); continue; }
				songs.push([si.display, si.icon, [146, 113, 253]]);
				claimed.push(sid);
			}
			if (songs.length < 1) { report.warn('level $id has no usable songs, skipped'); continue; }
			var name:String = CompatUtil.str(lv.name, id);
			CompatUtil.writeJson(out + 'weeks/$id.json', {
				songs: songs, weekCharacters: ['', 'bf', 'gf'], weekBackground: '', weekBefore: '',
				storyName: name, weekName: name, startUnlocked: true, hiddenUntilUnlocked: false,
				hideStoryMode: CompatUtil.bool(lv.visible, true) == false, hideFreeplay: false, difficulties: '',
				bannerImage: (lv.titleAsset != null) ? CompatUtil.stripLibrary(Std.string(lv.titleAsset)) : null
			});
			order.push(id);
			report.ok('level $id -> week "$name" (${songs.length} songs)');
			if (lv.props != null && (lv.props : Array<Dynamic>).length > 0)
				report.note('level $id: Story Mode props (${lv.props.length}) are V-Slice images, not Psych menu characters; the week shows Boyfriend and Girlfriend. Set weekCharacters in the Week Editor if you want others.');
		}

		var unlisted:Array<Dynamic> = [];
		for (sid => si in songInfo) if (!claimed.contains(sid)) unlisted.push([si.display, si.icon, [146, 113, 253]]);
		if (unlisted.length > 0)
		{
			var key:String = 'vslice-unlisted-songs';
			CompatUtil.writeJson(out + 'weeks/$key.json', {
				songs: unlisted, weekCharacters: ['', 'bf', 'gf'], weekBackground: '', weekBefore: '',
				storyName: 'Other songs', weekName: 'Other songs', startUnlocked: true, hiddenUntilUnlocked: false,
				hideStoryMode: true, hideFreeplay: false, difficulties: ''
			});
			order.push(key);
			report.note('${unlisted.length} songs are not in any level; they are listed in Freeplay under "Other songs".');
		}
		if (order.length > 0) CompatUtil.writeText(out + 'weeks/weekList.txt', order.join('\n'));

		CompatScan.scanScripts(root, report, 'vslice');
	}

	static function importSong(root:String, folder:String, entry:SongFiles, out:String, stages:Array<String>, chars:Map<String, Dynamic>, report:CompatReport):Dynamic
	{
		// the default variation; a song that only exists as a variation (e.g. only "erect") uses that one
		var variation:String = '';
		if (entry.meta.get('') == null || entry.chart.get('') == null)
		{
			for (v in entry.meta.keys()) if (entry.chart.get(v) != null) { variation = v; break; }
			if (variation == '')
			{
				report.warn('$folder: found ' + (entry.meta.get('') == null ? 'a chart but no $folder-metadata.json' : 'metadata but no $folder-chart.json') + ', skipped');
				return null;
			}
			report.warn('$folder: has no default variation; imported the "$variation" one (its audio is Inst-$variation.ogg in V-Slice, Vortex plays Inst.ogg).');
		}
		var metaFile:String = root + entry.meta.get(variation);
		var chartFile:String = root + entry.chart.get(variation);
		for (v in entry.meta.keys())
			if (v != variation) report.note('$folder: song variation "$v" was not imported (only one variation is; Vortex has no variations).');

		var err:Array<String> = [];
		var meta:Dynamic = CompatUtil.readJson(metaFile, err);
		var chart:Dynamic = CompatUtil.readJson(chartFile, err);
		if (meta == null || chart == null) { report.error('$folder: metadata or chart is not valid JSON (${err.join('; ')})'); return null; }

		var version:String = CompatUtil.str(meta.version, '?') + ' / chart ' + CompatUtil.str(chart.version, '?');
		var play:Dynamic = CompatUtil.field(meta, 'playData', {});
		var characters:Dynamic = CompatUtil.field(play, 'characters', {});
		var player:String = CompatUtil.str(characters.player, 'bf');
		var opponent:String = CompatUtil.str(characters.opponent, 'dad');
		var girlfriend:String = CompatUtil.str(characters.girlfriend, 'gf');
		var instrumental:String = CompatUtil.str(characters.instrumental, '');
		if (instrumental.length > 0) report.warn('$folder: uses the alternate instrumental "Inst-$instrumental"; Vortex plays songs/$folder/Inst.ogg.');

		// difficulty: Vortex has only Normal, so pick one chart
		var notesByDiff:Dynamic = CompatUtil.field(chart, 'notes', {});
		var diffs:Array<String> = Type.typeof(notesByDiff) == TObject ? Reflect.fields(notesByDiff) : [];
		if (diffs.length < 1) { report.error('$folder: the chart has no notes for any difficulty'); return null; }
		var diff:String = null;
		for (d in DIFF_ORDER) if (diffs.contains(d)) { diff = d; break; }
		if (diff == null) { diffs.sort(Reflect.compare); diff = diffs[0]; }
		var skipped:Array<String> = diffs.filter(function(d) return d != diff);
		if (skipped.length > 0) report.note('$folder: imported the "$diff" chart; Vortex has one difficulty, so ${skipped.join(', ')} were not imported.');

		// BPM / time changes
		var bpms:Array<BpmChange> = [];
		var tc:Array<Dynamic> = CompatUtil.isArray(meta.timeChanges) ? meta.timeChanges : [];
		for (c in tc) bpms.push({time: CompatUtil.num(c.t, 0), bpm: CompatUtil.num(c.bpm, 100)});
		if (bpms.length < 1) { bpms.push({time: 0, bpm: 100}); report.warn('$folder: no timeChanges in the metadata, assumed 100 BPM'); }
		var startBpm:Float = bpms[0].bpm;
		if (CompatUtil.str(meta.timeFormat, 'ms') != 'ms') report.warn('$folder: timeFormat "${meta.timeFormat}" is not milliseconds; times were read as milliseconds.');

		var speedObj:Dynamic = CompatUtil.field(chart, 'scrollSpeed', null);
		var speed:Float = 1;
		if (speedObj != null && Type.typeof(speedObj) == TObject) speed = CompatUtil.num(Reflect.field(speedObj, diff), CompatUtil.num(Reflect.field(speedObj, 'default'), 1));
		else speed = CompatUtil.num(speedObj, 1);

		var notes:Array<TimedNote> = [];
		var badNotes:Int = 0, extraLanes:Int = 0;
		var kinds:Array<String> = [];
		for (n in (Reflect.field(notesByDiff, diff) : Array<Dynamic>))
		{
			var t:Float = CompatUtil.num(CompatUtil.field(n, 't'), Math.NaN);
			var d:Float = CompatUtil.num(CompatUtil.field(n, 'd'), Math.NaN);
			if (Math.isNaN(t) || Math.isNaN(d) || d < 0) { badNotes++; continue; }
			var col:Int = Std.int(d);
			if (col > 7) { extraLanes++; continue; }
			var kind:String = CompatUtil.str(CompatUtil.field(n, 'k'), '');
			if (kind == 'normal') kind = '';
			if (kind.length > 0 && !kinds.contains(kind)) kinds.push(kind);
			notes.push({time: t, column: col, length: CompatUtil.num(CompatUtil.field(n, 'l'), 0), type: kind});
		}
		if (badNotes > 0) report.warn('$folder: $badNotes notes without a valid time/direction were left out.');
		if (extraLanes > 0) report.warn('$folder: $extraLanes notes are in lanes above 7 (not a 4-key V-Slice chart); they were left out.');
		for (k in kinds) report.needs('$folder: note kind "$k" needs a Vortex/Psych note type script (custom_notetypes/$k.lua); without one it plays as a normal note.');

		var focus:Array<CamFocus> = [];
		var events:Array<TimedEvent> = [];
		var evs:Array<Dynamic> = CompatUtil.isArray(chart.events) ? chart.events : [];
		for (e in evs) convertEvent(folder, e, bpms, startBpm, speed, focus, events, report);

		// stage + characters
		var stage:String = CompatUtil.str(play.stage, 'mainStage');
		if (!stages.contains(stage))
		{
			if (BASE_STAGES.exists(stage)) stage = BASE_STAGES.get(stage);
			else if (!CompatUtil.exists('assets/shared/stages/$stage.json') && !backend.StageData.isBuiltIn(stage))
				report.warn('$folder: stage "$stage" is not in this mod and is not a base-game stage; the default stage is used.');
		}
		else if (stageScripts.exists(stage)) stage = stageForSong(root, out, stage, folder, report);
		for (c in [player, opponent, girlfriend])
			if (!chars.exists(c) && !CompatUtil.exists('assets/shared/characters/$c.json') && c.length > 0)
				report.warn('$folder: character "$c" is not in this mod or the base game; Boyfriend is shown in its place.');
		var noteStyle:String = CompatUtil.str(play.noteStyle, 'funkin');
		if (noteStyle != 'funkin' && noteStyle != 'default') report.warn('$folder: note style "$noteStyle" is not converted (pixel notes come from a pixel stage in Vortex).');

		// audio
		var audio:String = root + 'songs/$folder/';
		var hasInst:Bool = CompatUtil.exists(audio + 'Inst.ogg') || CompatUtil.exists(audio + 'Inst.wav');
		if (!hasInst) report.error('$folder: songs/$folder/Inst.ogg is missing, the song will show the "Inst not found" screen.');
		var voices:Array<String> = CompatUtil.list(audio).filter(function(f) return f.startsWith('Voices'));
		var playerVoice:String = pickVocals(audio, CompatUtil.isArray(characters.playerVocals) ? characters.playerVocals : null, player);
		var opponentVoice:String = pickVocals(audio, CompatUtil.isArray(characters.opponentVocals) ? characters.opponentVocals : null, opponent);
		if (voices.length > 0 && playerVoice == null && !voices.contains('Voices.ogg'))
			report.warn('$folder: none of the vocal files (${voices.join(', ')}) belongs to the player "$player" (V-Slice looks for Voices-<character>.ogg).');

		var display:String = CompatUtil.str(meta.songName, folder);
		if (Paths.formatToSongPath(display) != folder) display = folder; // Freeplay finds the chart through this name

		var psych:Dynamic = ChartBuilder.build(folder, notes, bpms, focus, events, {
			bpm: startBpm, speed: speed, needsVoices: voices.length > 0, player1: player, player2: opponent,
			gfVersion: girlfriend, stage: stage, source: 'V-Slice $version, difficulty $diff'
		}, report);
		psych.song = display;
		if (playerVoice != null) psych.vortexPlayerVocals = playerVoice;
		if (opponentVoice != null) psych.vortexOpponentVocals = opponentVoice;
		CompatUtil.writeJson(out + 'data/$folder/$folder.json', psych);
		report.ok('song $folder: ${notes.length} notes, ${bpms.length} BPM section(s), ${events.length} events ("$diff" chart, V-Slice $version)');

		var icon:String = opponent;
		var oc:Dynamic = chars.get(opponent);
		if (oc != null && oc.healthIcon != null && oc.healthIcon.id != null) icon = Std.string(oc.healthIcon.id);
		return {display: display, icon: icon};
	}

	static function convertEvent(song:String, e:Dynamic, bpms:Array<BpmChange>, startBpm:Float, speed:Float, focus:Array<CamFocus>, events:Array<TimedEvent>, report:CompatReport)
	{
		var t:Float = CompatUtil.num(CompatUtil.field(e, 't'), Math.NaN);
		var name:String = CompatUtil.str(CompatUtil.field(e, 'e'), '');
		var v:Dynamic = CompatUtil.field(e, 'v');
		if (Math.isNaN(t) || name.length < 1) { report.warn('$song: an event without a time or name was left out'); return; }
		var obj:Bool = v != null && Type.typeof(v) == TObject;
		switch (name)
		{
			case 'FocusCamera':
				var who:Int = Std.int(CompatUtil.num(obj ? v.char : v, 0));
				if (obj && (v.x != null || v.y != null) && (CompatUtil.num(v.x, 0) != 0 || CompatUtil.num(v.y, 0) != 0))
					report.warn('$song: FocusCamera with an x/y offset at ${Std.int(t)} ms; only who the camera follows was kept.');
				if (who < 0) { report.warn('$song: FocusCamera on a fixed point (char -1) at ${Std.int(t)} ms is not supported; kept the previous focus.'); return; }
				focus.push({time: t, who: who == 0 ? 0 : (who == 2 ? 2 : 1)});
			case 'PlayAnimation':
				var target:String = CompatUtil.str(obj ? v.target : null, 'bf');
				target = switch (target) { case 'boyfriend' | 'player' | 'bf': 'bf'; case 'girlfriend' | 'gf': 'gf'; case 'dad' | 'opponent': 'dad'; default: target; }
				events.push({time: t, name: 'Play Animation', v1: CompatUtil.str(obj ? v.anim : v, 'hey'), v2: target});
			case 'ScrollSpeed':
				var scroll:Float = CompatUtil.num(obj ? v.scroll : v, 1);
				var absolute:Bool = obj && CompatUtil.bool(v.absolute, false);
				var mult:Float = absolute ? scroll / Math.max(0.01, speed) : scroll;
				var dur:Float = obj ? ChartBuilder.stepsToSeconds(CompatUtil.num(v.duration, 0), ChartBuilder.bpmAt(bpms, t, startBpm)) : 0;
				events.push({time: t, name: 'Change Scroll Speed', v1: Std.string(Math.round(mult * 1000) / 1000), v2: Std.string(Math.round(dur * 1000) / 1000)});
			case 'ZoomCamera':
				// Vortex "Zoom Camera": Value 1 = zoom ("x1.2" = times the stage's zoom), Value 2 = "seconds,ease"
				var zoom:Float = CompatUtil.num(obj ? v.zoom : v, 1);
				var mode:String = obj ? CompatUtil.str(v.mode, 'stage') : 'stage';
				var steps:Float = obj ? CompatUtil.num(v.duration, 4) : 4;
				var ease:String = obj ? CompatUtil.str(v.ease, 'linear') : 'linear';
				if (ease.toUpperCase() == 'INSTANT') steps = 0;
				if (obj && v.easeDir != null && ease != 'linear') ease += CompatUtil.str(v.easeDir, '');
				var secs:Float = ChartBuilder.stepsToSeconds(steps, ChartBuilder.bpmAt(bpms, t, startBpm));
				events.push({time: t, name: 'Zoom Camera', v1: (mode == 'direct' ? '' : 'x') + zoom, v2: (Math.round(secs * 1000) / 1000) + ',' + ease});
			case 'ChangeCharacter' | 'Change Character' if (obj && (v.newchar != null || v.character != null)):
				var target:String = CompatUtil.str(v.character, 'dad');
				events.push({time: t, name: 'Change Character', v1: target, v2: CompatUtil.str(v.newchar, '')});
			case 'ChangeStage' if (obj && v.stageid != null):
				var stageId:String = Std.string(v.stageid);
				events.push({time: t, name: 'Change Stage', v1: '', v2: BASE_STAGES.exists(stageId) ? BASE_STAGES.get(stageId) : stageId});
			case 'SetCameraBop' | 'PlaySoundEffect' | 'SetHealthIcon':
				events.push({time: t, name: name, v1: haxe.Json.stringify(v), v2: ''});
				report.needs('$song: V-Slice event "$name" has no built-in Vortex equivalent; it was kept in the chart under that name (values as JSON in Value 1). Add custom_events/$name.lua to make it do something.');
			default:
				if (obj && (v.value1 != null || v.value2 != null))
				{
					// Psych-style event kept in a V-Slice chart (ported mods do this): same name, same values
					events.push({time: t, name: name, v1: CompatUtil.str(v.value1, ''), v2: CompatUtil.str(v.value2, '')});
					if (!PSYCH_EVENTS.contains(name)) report.needs('$song: event "$name" (Psych-style values) is not built into Vortex; add custom_events/$name.lua.');
					return;
				}
				events.push({time: t, name: name, v1: (v == null) ? '' : (obj || CompatUtil.isArray(v) ? haxe.Json.stringify(v) : Std.string(v)), v2: ''});
				report.needs('$song: custom V-Slice event "$name" was kept in the chart, but its V-Slice script (scripts/events/) does not run in Vortex. Add custom_events/$name.lua.');
		}
	}

	public static function characterToPsych(data:Dynamic, id:String, root:String, report:CompatReport):Dynamic
	{
		var render:String = CompatUtil.str(data.renderType, 'sparrow');
		var image:String = CompatUtil.stripLibrary(CompatUtil.str(data.assetPath, 'characters/$id'));
		var anims:Array<Dynamic> = [];
		var images:Array<String> = [image];
		var src:Array<Dynamic> = CompatUtil.isArray(data.animations) ? data.animations : [];
		for (a in src)
		{
			var offsets:Array<Dynamic> = CompatUtil.isArray(a.offsets) ? a.offsets : [0, 0];
			var indices:Array<Dynamic> = CompatUtil.isArray(a.frameIndices) ? a.frameIndices : [];
			anims.push({
				anim: CompatUtil.str(a.name, 'idle'),
				name: CompatUtil.str(a.prefix, CompatUtil.str(a.name, 'idle')),
				fps: Std.int(CompatUtil.num(a.frameRate, 24)),
				loop: CompatUtil.bool(a.looped, false),
				indices: [for (i in indices) Std.int(CompatUtil.num(i, 0))],
				offsets: [Std.int(CompatUtil.num(offsets[0], 0)), Std.int(CompatUtil.num(offsets[1], 0))]
			});
			if (render == 'multisparrow' && a.assetPath != null)
			{
				var extra:String = CompatUtil.stripLibrary(Std.string(a.assetPath));
				if (!images.contains(extra)) images.push(extra);
			}
		}
		switch (render)
		{
			case 'sparrow' | 'multisparrow' | 'packer':
			case 'animateatlas' | 'multianimateatlas':
				report.warn('character $id uses an Adobe Animate texture atlas; Vortex loads it from images/$image/ (Animation.json), animation names are used as frame labels. Check it in the Character Editor.');
			default:
				report.warn('character $id: render type "$render" is unknown; loaded as a Sparrow sprite sheet.');
		}
		for (img in images) checkPicture(root, img, 'character $id', report);

		var offsets:Array<Dynamic> = CompatUtil.isArray(data.offsets) ? data.offsets : [0, 0];
		var cam:Array<Dynamic> = CompatUtil.isArray(data.cameraOffsets) ? data.cameraOffsets : [0, 0];
		var icon:Dynamic = CompatUtil.field(data, 'healthIcon', {});
		var scale:Float = CompatUtil.num(data.scale, 1);
		return {
			animations: anims,
			image: images.join(','),
			scale: scale,
			sing_duration: CompatUtil.num(data.singTime, 8) / 2,
			healthicon: CompatUtil.str(icon.id, id),
			position: [CompatUtil.num(offsets[0], 0), CompatUtil.num(offsets[1], 0)],
			camera_position: [CompatUtil.num(cam[0], 0), CompatUtil.num(cam[1], 0)],
			flip_x: CompatUtil.bool(data.flipX, false),
			no_antialiasing: CompatUtil.bool(data.isPixel, false),
			healthbar_colors: [161, 161, 161],
			vocals_file: id,
			_editor_isPlayer: false,
			vortex_vslice_origin: true, // 0.6: placed by its feet and camera centre like in V-Slice (see PlayState.startCharacterPos)
			_vortex_source: 'V-Slice character ' + CompatUtil.str(data.version, '')
		};
	}

	/** Reports a picture that can't be found in the mod (root or library folders) or the game, or that only exists as .astc. */
	public static function checkPicture(root:String, img:String, who:String, report:CompatReport):Void
	{
		if (img == null || img.length < 1 || img.startsWith('#')) return;
		if (CompatUtil.findIn(root, 'images/$img.png', libs) != null || CompatUtil.findIn(root, 'images/$img/Animation.json', libs) != null) return;
		if (CompatUtil.exists('assets/shared/images/$img.png') || CompatUtil.exists('assets/images/$img.png')) return;
		var week:Bool = false;
		for (w in ['week1', 'week2', 'week3', 'week4', 'week5', 'week6', 'week7', 'weekend1']) if (CompatUtil.exists('assets/$w/images/$img.png')) week = true;
		if (week) return;
		if (CompatUtil.findIn(root, 'images/$img.astc', libs) != null)
			report.error('$who: images/$img only exists as .astc, a compressed format for phones. V-Slice itself only uses .astc on mobile builds, so this is a mobile-only version of the mod: get its PC version (with .png pictures).');
		else
			report.warn('$who: picture images/$img.png was not found in the mod (also checked ${libs.length > 0 ? libs.join(', ') : 'no library folders'}) or the base game.');
	}

	public static function stageToPsych(data:Dynamic, id:String, ?root:String, report:CompatReport, ?fromScript:Array<Dynamic>):Dynamic
	{
		var items:Array<{z:Float, obj:Dynamic}> = [];
		var props:Array<Dynamic> = CompatUtil.isArray(data.props) ? data.props : [];
		var n:Int = 0;
		for (p in props)
		{
			var name:String = CompatUtil.str(p.name, 'prop${n++}');
			var asset:String = CompatUtil.str(p.assetPath, '');
			var pos:Array<Dynamic> = CompatUtil.isArray(p.position) ? p.position : [0, 0];
			var scroll:Array<Dynamic> = CompatUtil.isArray(p.scroll) ? p.scroll : [1, 1];
			var scale:Array<Float> = CompatUtil.isArray(p.scale) ? [CompatUtil.num(p.scale[0], 1), CompatUtil.num(p.scale[1], 1)] : [CompatUtil.num(p.scale, 1), CompatUtil.num(p.scale, 1)];
			var obj:Dynamic = {
				name: name, x: CompatUtil.num(pos[0], 0), y: CompatUtil.num(pos[1], 0), scale: scale,
				scroll: [CompatUtil.num(scroll[0], 1), CompatUtil.num(scroll[1], 1)], alpha: CompatUtil.num(p.alpha, 1),
				angle: CompatUtil.num(p.angle, 0), antialiasing: !CompatUtil.bool(p.isPixel, false),
				flipX: CompatUtil.bool(p.flipX, false), flipY: CompatUtil.bool(p.flipY, false), color: 'FFFFFF', filters: 0
			};
			if (asset.startsWith('#'))
			{
				obj.type = 'square';
				obj.color = asset.substr(1);
			}
			else
			{
				obj.image = CompatUtil.stripLibrary(asset);
				if (root != null) checkPicture(root, obj.image, 'stage $id prop "$name"', report);
				var anims:Array<Dynamic> = CompatUtil.isArray(p.animations) ? p.animations : [];
				if (anims.length > 0)
				{
					obj.type = 'animatedSprite';
					obj.animations = [for (a in anims) {
						anim: CompatUtil.str(a.name, 'idle'), name: CompatUtil.str(a.prefix, CompatUtil.str(a.name, 'idle')),
						fps: Std.int(CompatUtil.num(a.frameRate, 24)), loop: CompatUtil.bool(a.looped, false),
						indices: CompatUtil.isArray(a.frameIndices) ? a.frameIndices : [],
						offsets: CompatUtil.isArray(a.offsets) ? a.offsets : [0, 0]
					}];
					obj.firstAnimation = CompatUtil.str(p.startingAnimation, CompatUtil.str(anims[0].name, 'idle'));
					if (CompatUtil.num(p.danceEvery, 0) > 0) report.warn('stage $id: prop "$name" dances to the beat in V-Slice; in Vortex it only plays its first animation (add a stage script to make it dance).');
				}
				else obj.type = 'sprite';
			}
			items.push({z: CompatUtil.num(p.zIndex, 0), obj: obj});
		}

		var chars:Dynamic = CompatUtil.field(data, 'characters', {});
		var result:Dynamic = {
			directory: '', defaultZoom: CompatUtil.num(data.cameraZoom, 0.9), stageUI: 'normal',
			boyfriend: [770, 100], girlfriend: [400, 130], opponent: [100, 100], hide_girlfriend: false,
			camera_boyfriend: [0, 0], camera_opponent: [0, 0], camera_girlfriend: [0, 0], camera_speed: 1,
			_vortex_source: 'V-Slice stage ' + CompatUtil.str(data.version, '')
		};
		for (slot in ['bf', 'dad', 'gf'])
		{
			var c:Dynamic = CompatUtil.field(chars, slot, null);
			var z:Float = (slot == 'gf') ? 100 : (slot == 'dad' ? 200 : 300);
			if (c != null)
			{
				z = CompatUtil.num(c.zIndex, z);
				if (CompatUtil.isArray(c.position))
				{
					var off:Array<Float> = SLOT_OFFSET.get(slot);
					var p:Array<Float> = [CompatUtil.num(c.position[0], 0) + off[0], CompatUtil.num(c.position[1], 0) + off[1]];
					Reflect.setField(result, slot == 'bf' ? 'boyfriend' : (slot == 'gf' ? 'girlfriend' : 'opponent'), p);
				}
				// Vortex Engine 0.6: Psych's moveCamera already adds bf -100,-100 / dad 150,-100; take those off so the
				// camera lands where V-Slice puts it (it used to be pushed twice)
				var vs:Array<Float> = VSLICE_CAMERA_DEFAULT.get(slot);
				if (CompatUtil.isArray(c.cameraOffsets)) vs = [CompatUtil.num(c.cameraOffsets[0], 0), CompatUtil.num(c.cameraOffsets[1], 0)];
				var ps:Array<Float> = PSYCH_CAMERA.get(slot);
				Reflect.setField(result, 'camera_' + (slot == 'bf' ? 'boyfriend' : (slot == 'gf' ? 'girlfriend' : 'opponent')), [vs[0] - ps[0], vs[1] - ps[1]]);
			}
			items.push({z: z, obj: {type: slot == 'bf' ? 'boyfriend' : slot}});
		}
		// sprites made by the stage's script: V-Slice adds them after the json props (same zIndex keeps that order)
		if (fromScript != null)
			for (o in fromScript)
			{
				var copy:Dynamic = Reflect.copy(o);
				var z:Float = CompatUtil.num(copy.zIndex, 0);
				Reflect.deleteField(copy, 'zIndex');
				items.push({z: z, obj: copy});
			}
		haxe.ds.ArraySort.sort(items, function(a, b) return a.z < b.z ? -1 : (a.z > b.z ? 1 : 0));
		result.objects = [for (i in items) i.obj];
		report.note('stage $id: V-Slice places characters by their feet; characters from this mod are placed the same way in Vortex, Psych characters (like the base game ones) use Psych\'s positions.');
		return result;
	}

	/**
	 * Vortex Engine 0.6: the sprites a stage's V-Slice script makes in onCreate for one song ('' = no particular song),
	 * as Psych stage objects (see StageScriptReader). null if the stage has no script.
	 */
	static function scriptObjects(root:String, id:String, songId:String, report:CompatReport):Array<Dynamic>
	{
		var script:StageScript = stageScripts.get(id);
		if (script == null) return null;
		var run:StageRun = script.read(songId, function(key:String, atlas:Bool) return pictureSize(root, key, atlas));
		var skipped:Array<String> = [];
		var objs:Array<Dynamic> = run.toPsychObjects(id, skipped);
		var who:String = songId == '' ? 'stage $id' : '$songId (stage $id)';
		for (o in objs) if (o.image != null) checkPicture(root, o.image, '$who: script sprite "${o.name}"', report);
		for (s in skipped) report.note('$who: script sprite $s; left out.');
		for (u in run.unsupported) report.warn('$who: ${script.file} uses $u, which Vortex does not convert.');
		if (songId == '')
		{
			report.note('stage $id: its pictures are made by ${script.file} (a V-Slice script, which Vortex can not run); Vortex read the sprites it adds when the stage is created. Check the stage in game.');
			if (script.liveFunctions.length > 0)
				report.note('stage $id: ${script.file} also changes the stage while the song plays (${script.liveFunctions.join(', ')}); Vortex only shows how the stage starts. Port that part to a Lua or HScript stage script if you need it.');
			if (run.skippedSwitches > 0) report.note('stage $id: ${script.file} has a switch Vortex could not follow; check the stage in game.');
		}
		return objs;
	}

	/** A song on a script-built stage: if the script builds it differently for this song, write "<stage>-<song>". */
	static function stageForSong(root:String, out:String, stage:String, songId:String, report:CompatReport):String
	{
		var objs:Array<Dynamic> = scriptObjects(root, stage, songId, report);
		if (objs == null || haxe.Json.stringify(objs) == stageBase.get(stage)) return stage;
		var variant:String = '$stage-$songId';
		var quiet:CompatReport = new CompatReport(variant); // the stage's own notes were already reported once
		CompatUtil.writeJson(out + 'stages/$variant.json', stageToPsych(stageSources.get(stage), variant, null, quiet, objs));
		report.ok('$songId: stage "$stage" is built differently for this song by its script; it uses stage "$variant" (${objs.length} sprites from the script)');
		return variant;
	}

	/** Frame size of a picture (first atlas frame for a spritesheet), for scale / screenCenter in stage scripts. */
	static function pictureSize(root:String, key:String, atlas:Bool):Array<Float>
	{
		var cacheKey:String = '$key|$atlas';
		if (sizeCache.exists(cacheKey)) return sizeCache.get(cacheKey);
		var size:Array<Float> = null;
		try
		{
			if (atlas)
			{
				var xmlPath:String = findPicture(root, key, '.xml');
				var xml:Xml = xmlPath != null ? CompatUtil.readXml(xmlPath) : null;
				if (xml != null) // Vortex Engine 0.7: readXml already returns the <TextureAtlas> element
					for (node in xml.elementsNamed('SubTexture'))
					{
						var w:String = node.exists('frameWidth') ? node.get('frameWidth') : node.get('width');
						var h:String = node.exists('frameHeight') ? node.get('frameHeight') : node.get('height');
						if (w != null && h != null) size = [Std.parseFloat(w), Std.parseFloat(h)];
						break;
					}
			}
			if (size == null)
			{
				var png:String = findPicture(root, key, '.png');
				#if sys
				if (png != null)
				{
					var input = sys.io.File.read(png, true);
					var b:haxe.io.Bytes = input.read(24);
					input.close();
					if (b.length >= 24 && b.get(1) == 'P'.code)
						size = [(b.get(16) << 24) | (b.get(17) << 16) | (b.get(18) << 8) | b.get(19), (b.get(20) << 24) | (b.get(21) << 16) | (b.get(22) << 8) | b.get(23)];
				}
				#end
			}
		}
		catch (e:Dynamic) size = null;
		sizeCache.set(cacheKey, size);
		return size;
	}

	static function findPicture(root:String, key:String, ext:String):String
	{
		var f:String = CompatUtil.findIn(root, 'images/$key$ext', libs);
		if (f != null) return f;
		for (base in ['assets/shared/images/', 'assets/images/']) if (CompatUtil.exists(base + key + ext)) return base + key + ext;
		return null;
	}

	static function pickVocals(audioDir:String, list:Array<Dynamic>, id:String):String
	{
		var cands:Array<String> = [];
		if (list != null) for (c in list) cands.push(Std.string(c));
		cands.push(id);
		var all:Array<String> = [];
		for (c in cands)
		{
			var cur:String = c;
			while (cur.length > 0)
			{
				if (!all.contains(cur)) all.push(cur);
				var i:Int = cur.lastIndexOf('-');
				if (i < 1) break;
				cur = cur.substr(0, i); // V-Slice: Voices-bf-car.ogg missing -> Voices-bf.ogg
			}
		}
		for (c in all) if (CompatUtil.exists(audioDir + 'Voices-$c.ogg') || CompatUtil.exists(audioDir + 'Voices-$c.wav')) return c;
		return null;
	}

	/** Sorts every JSON under data/ by what it contains. */
	static function discover(root:String, report:CompatReport):Found
	{
		var f:Found = {characters: [], stages: [], levels: [], songs: new Map<String, SongFiles>()};
		var seen:Map<String, String> = [];
		var files:Array<String> = CompatUtil.walk(root + 'data/', 20000);
		var rank = function(r:String) return ~/^(characters|stages|levels|songs)\//.match(r) ? 0 : 1;
		files.sort(function(a, b) return rank(a) != rank(b) ? rank(a) - rank(b) : Reflect.compare(a.toLowerCase(), b.toLowerCase()));
		for (rel in files)
		{
			if (!rel.toLowerCase().endsWith('.json')) continue;
			var path:String = 'data/' + rel;
			var name:String = CompatUtil.baseName(rel).trim();
			var parent:String = haxe.io.Path.directory(rel).split('/').pop();
			var low:String = name.toLowerCase();
			// songs by file name: <id>-metadata[-variation].json / <id>-chart[-variation].json
			for (kind in ['metadata', 'chart'])
			{
				var i:Int = low.indexOf('-' + kind);
				if (i > 0 && (low.length == i + kind.length + 1 || low.charAt(i + kind.length + 1) == '-'))
				{
					var id:String = name.substr(0, i);
					var variation:String = (low.length > i + kind.length + 1) ? name.substr(i + kind.length + 2) : '';
					var entry:SongFiles = f.songs.get(id);
					if (entry == null) { entry = {meta: new Map(), chart: new Map()}; f.songs.set(id, entry); }
					(kind == 'metadata' ? entry.meta : entry.chart).set(variation, path);
					name = null;
					break;
				}
			}
			if (name == null) continue;
			var err:Array<String> = [];
			var d:Dynamic = CompatUtil.readJson(root + path, err);
			var standard:Bool = ~/^data\/(characters|stages|levels)\//.match(path);
			// other V-Slice registries have look-alike files (dialogue speakers have animations + assetPath): not ours
			if (!standard && ~/^data\/(dialogue|notestyles|ui|players|stickerpacks|speakers|conversations|boxes|freeplay|events|album)/i.match(path)) continue;
			if (d == null)
			{
				if (standard) report.error('$path: not valid JSON (${err.join('')})');
				continue;
			}
			if (Type.typeof(d) != TObject) continue;
			var kind:String = null;
			if (CompatUtil.isArray(d.animations) && (d.assetPath != null || d.renderType != null)) kind = 'character';
			else if (CompatUtil.isArray(d.props) && (d.characters != null || d.cameraZoom != null)) kind = 'stage';
			else if (CompatUtil.isArray(d.songs) && (d.titleAsset != null || d.name != null)) kind = 'level';
			else if (d.playData != null && d.timeChanges != null) kind = 'metadata';
			else if (d.notes != null && Type.typeof(d.notes) == TObject && d.scrollSpeed != null) kind = 'chart';
			if (kind == null)
			{
				if (standard) report.warn('$path: not a V-Slice ' + path.split('/')[1].substr(0, path.split('/')[1].length - 1) + ' file, skipped');
				continue;
			}
			if (kind == 'metadata' || kind == 'chart')
			{
				// a song file that doesn't follow the <id>-metadata.json naming: use its folder name as the song id
				var entry:SongFiles = f.songs.get(parent);
				if (entry == null) { entry = {meta: new Map(), chart: new Map()}; f.songs.set(parent, entry); }
				(kind == 'metadata' ? entry.meta : entry.chart).set('', path);
				report.note('$path: used as the ${kind} of song "$parent" (V-Slice names it $parent-$kind.json).');
				continue;
			}
			var key:String = kind + ':' + name.toLowerCase();
			if (seen.exists(key)) { report.warn('$path: another $kind called "$name" was already found (${seen.get(key)}); this one was skipped.'); continue; }
			seen.set(key, path);
			var item = {id: name, path: path, data: d};
			switch (kind)
			{
				case 'character': f.characters.push(item);
				case 'stage': f.stages.push(item);
				case 'level': f.levels.push(item);
			}
		}
		var byPath = function(a:FoundFile, b:FoundFile) return Reflect.compare(a.path.toLowerCase(), b.path.toLowerCase());
		f.characters.sort(byPath);
		f.stages.sort(byPath);
		f.levels.sort(byPath);
		return f;
	}
}

typedef SongFiles = {meta:Map<String, String>, chart:Map<String, String>};
typedef FoundFile = {id:String, path:String, data:Dynamic};
typedef Found = {characters:Array<FoundFile>, stages:Array<FoundFile>, levels:Array<FoundFile>, songs:Map<String, SongFiles>};
