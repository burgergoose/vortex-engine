package backend.compat;

import backend.Song;

/**
 * VORTEX ENGINE ADDITION - the V-Slice Converter (Developer menu -> V-Slice Converter).
 *
 * Copies a Vortex / Psych mod (or a mod Vortex translated from another engine) into a new folder laid out like a
 * V-Slice (Friday Night Funkin' 0.3+, Polymod) mod: data/songs/<id>/<id>-metadata.json + <id>-chart.json,
 * data/characters, data/stages, data/levels, songs/<id>/ audio, images, sounds, music, _polymod_meta.json.
 *
 * It never writes into the source mod. Everything it can't convert (Lua / HScript, most Psych events, extra
 * strumlines, menu characters...) is listed in REPORT.txt. A successful conversion means the FILES are in the
 * V-Slice format; it does not mean the mod plays the same in V-Slice. Nothing here was run inside V-Slice.
 */
class VSliceExport
{
	public static inline var OUTPUT_ROOT:String = 'vortex_converted/';
	static inline var METADATA_VERSION:String = '2.2.4';
	static inline var CHART_VERSION:String = '2.0.0';
	static inline var MARKER:String = '.vortex_vslice_export';

	// built-in Psych stages -> the V-Slice base-game stage with the same art
	static final STAGE_IDS:Map<String, String> = [
		'stage' => 'mainStage', 'spooky' => 'spookyMansion', 'philly' => 'phillyTrain', 'limo' => 'limoRide', 'mall' => 'mallXmas',
		'mallEvil' => 'mallEvil', 'school' => 'school', 'schoolEvil' => 'schoolEvil', 'tank' => 'tankmanBattlefield',
		'phillyStreets' => 'phillyStreets', 'phillyBlazin' => 'phillyBlazin'
	];

	// Vortex Engine 0.7: ids V-Slice's base game already uses (FunkinCrew/funkin.assets, 0.8.x). A mod file with one of these
	// ids REPLACES the base one for the whole game and gets its scripts attached (a converted "bf-dark" crashed with
	// "Render type mismatch" from the base bf-dark.hxc), so converted ones are renamed "<id>-<mod>".
	static final BASE_CHARACTERS:Array<String> = ['bf-car', 'bf-christmas', 'bf-dark', 'bf-holding-gf', 'bf-pixel', 'bf', 'dad', 'darnell-blazin',
		'darnell', 'gf-car', 'gf-christmas', 'gf-dark', 'gf-pixel', 'gf-tankmen', 'gf', 'mom-car', 'monster-christmas', 'monster', 'nene-christmas',
		'nene-dark', 'nene-pixel', 'nene-tankmen', 'nene', 'otis-speaker', 'parents-christmas', 'pico-blazin', 'pico-christmas', 'pico-dark',
		'pico-holding-nene', 'pico-pixel', 'pico-playable', 'pico-speaker', 'pico', 'senpai-angry', 'senpai', 'spirit', 'spooky-dark', 'spooky',
		'sserafim-chaewon', 'sserafim-eunchae', 'sserafim-gf', 'sserafim-kazuha', 'sserafim-sakura', 'sserafim-yunjin', 'tankman-bloody', 'tankman'];
	static final BASE_STAGES:Array<String> = ['limoride', 'limorideerect', 'mainstage', 'mainstageerect', 'mallevil', 'mallxmas', 'mallxmaserect',
		'phillyblazin', 'phillystreets', 'phillystreetserect', 'phillytrain', 'phillytrainerect', 'school', 'schoolerect', 'schoolevil',
		'schoolevilerect', 'spookymansion', 'spookymansionerect', 'sserafim', 'tankmanbattlefield', 'tankmanbattlefielderect'];
	static final BASE_SONGS:Array<String> = ['2hot', 'blammed', 'blazin', 'bopeebo', 'cocoa', 'dadbattle', 'darnell', 'eggnog', 'fresh', 'guns', 'high',
		'lit-up', 'milf', 'monster', 'philly-nice', 'pico', 'roses', 'satin-panties', 'senpai', 'south', 'spaghetti', 'spookeez', 'stress', 'test',
		'thorns', 'tutorial', 'ugh', 'winter-horrorland'];
	static final BASE_LEVELS:Array<String> = ['sserafim', 'tutorial', 'week1', 'week2', 'week3', 'week4', 'week5', 'week6', 'week7', 'weekend1'];
	// Psych's built-in week 1 stage (states/stages/StageWeek1.hx), exported as a normal stage so converted characters line up on it
	static final PSYCH_STAGE_OBJECTS:Array<Dynamic> = [
		{type: 'sprite', name: 'stageback', image: 'stageback', x: -600, y: -200, scroll: [0.9, 0.9], scale: [1, 1]},
		{type: 'sprite', name: 'stagefront', image: 'stagefront', x: -650, y: 600, scroll: [0.9, 0.9], scale: [1.1, 1.1]},
		{type: 'gf'}, {type: 'dad'}, {type: 'boyfriend'},
		{type: 'sprite', name: 'stagelight1', image: 'stage_light', x: -125, y: -100, scroll: [0.9, 0.9], scale: [1.1, 1.1]},
		{type: 'sprite', name: 'stagelight2', image: 'stage_light', x: 1225, y: -100, scroll: [0.9, 0.9], scale: [1.1, 1.1], flipX: true},
		{type: 'sprite', name: 'stagecurtains', image: 'stagecurtains', x: -500, y: -300, scroll: [1.3, 1.3], scale: [0.9, 0.9]}
	];
	static final MOBILE_MAX_TEXTURE:Int = 4096;

	// set by run() for the helpers below
	static var exRoot:String;
	static var exCache:String;
	static var exOut:String;
	static var exSlug:String;
	static var exReport:CompatReport;
	static var copiedBase:Map<String, String> = [];
	// mod pictures moved to images/<mod>/ (path also used by the base game, or shrunk for phones): not copied as-is
	static var remapped:Map<String, String> = [];
	static var shrunk:Map<String, Float> = [];
	static var usedEvents:Map<String, Int> = [];
	static var songFolders:Map<String, String> = []; // exported song id -> mod data/ folder
	static var exClassPrefix:String;
	static var psychShifts:Map<String, Array<Float>> = []; // V-Slice character id -> [dx, dy, Psych width, Psych height]
	static var psychCams:Map<String, Array<Float>> = []; // 'char:<id>' / 'stage:<id>:bf|dad|gf' -> Psych camera numbers

	// Vortex Engine 0.7: Psych's built-in events, written as tiny Lua scripts for the translator (see LuaToHScript.SHIM)
	static final BUILT_IN_EVENTS:Map<String, String> = [
		'Add Camera Zoom' => 'function onEvent(n, v1, v2) addCameraZoom(v1, v2) end',
		'Screen Shake' => 'function onEvent(n, v1, v2) screenShakePsych(v1, v2) end',
		'Camera Follow Pos' => 'function onEvent(n, v1, v2) cameraFollowPos(v1, v2) end',
		'Set GF Speed' => 'function onEvent(n, v1, v2) setGfSpeed(v1) end',
		'Alt Idle Animation' => 'function onEvent(n, v1, v2) altIdle(v1, v2) end',
		'Play Sound' => 'function onEvent(n, v1, v2) playSound(v1, tonumber(v2) or 1) end',
		'Set Property' => 'function onEvent(n, v1, v2) setProperty(v1, v2) end',
		'Change Character' => 'function onEvent(n, v1, v2) changeCharacter(v1, v2) end'
	];
	static final EVENT_IMPORTS:String = 'import funkin.play.event.SongEvent;\nimport funkin.play.PlayState;\nimport funkin.play.PlayStatePlaylist;\n'
		+ 'import funkin.Conductor;\nimport funkin.Preferences;\nimport funkin.Paths;\nimport funkin.audio.FunkinSound;\nimport funkin.graphics.FunkinSprite;\n'
		+ 'import haxe.ds.StringMap;\nimport StringTools;\nimport Reflect;\nimport funkin.play.character.BaseCharacter.CharacterType;\n'
		+ 'import funkin.data.character.CharacterData.CharacterDataParser;\nimport funkin.modding.module.ModuleHandler;\nimport flixel.FlxG;\nimport funkin.PlayerSettings;\nimport flixel.FlxSprite;\nimport flixel.text.FlxText;\nimport flixel.text.FlxTextBorderStyle;\nimport flixel.util.FlxTimer;\nimport flixel.tweens.FlxTween;\nimport flixel.tweens.FlxEase;\n';

	public static var lastOutput:String = null;

	/** Converts mods/<mod>/ into vortex_converted/<mod>-vslice/. Returns the report (also saved as REPORT.txt). */
	public static function run(mod:String):CompatReport
	{
		var report:CompatReport = new CompatReport(mod);
		#if MODS_ALLOWED
		var root:String = Paths.mods(mod + '/');
		var cache:String = CompatLayer.cacheDir(mod);
		var det = CompatScan.detect(root);
		report.engine = det.label;
		report.version = det.version;
		if (!CompatUtil.isDir(root)) { report.error('mods/$mod/ does not exist'); return report; }
		if (det.engine == 'vslice') report.warn('This mod is already a V-Slice mod; the converter re-exports it from the Psych-format translation Vortex made of it.');

		var out:String = OUTPUT_ROOT + mod + '-vslice/';
		if (CompatUtil.isDir(out))
		{
			if (CompatUtil.exists(out + MARKER)) CompatUtil.deleteTree(out); // our own earlier output
			else
			{
				var n:Int = 2;
				while (CompatUtil.isDir(OUTPUT_ROOT + mod + '-vslice-$n')) n++;
				out = OUTPUT_ROOT + mod + '-vslice-$n/';
				report.note('A folder that was not made by this converter already had the default name, so the output went to $out instead.');
			}
		}
		var oldDirectory:String = Mods.currentModDirectory;
		Mods.currentModDirectory = mod; // stage / chart lookups below read this mod's files
		CompatUtil.makeDirs(out);
		CompatUtil.writeText(out + MARKER, 'Made by the Vortex Engine V-Slice Converter. Safe to delete; converting again replaces this folder.\n');
		lastOutput = out;

		// files of the mod, with Vortex's Psych-format translation of a non-Psych mod filling in what the mod lacks
		function find(rel:String):String
		{
			if (CompatUtil.exists(root + rel)) return root + rel;
			if (CompatUtil.exists(cache + rel)) return cache + rel;
			return null;
		}
		function listBoth(rel:String):Array<String>
		{
			var a:Array<String> = CompatUtil.list(root + rel);
			for (f in CompatUtil.list(cache + rel)) if (!a.contains(f)) a.push(f);
			return a;
		}

		exRoot = root;
		exCache = cache;
		exOut = out;
		exSlug = slugOf(mod);
		exReport = report;
		copiedBase = [];
		remapped = [];
		shrunk = [];
		usedEvents = [];
		songFolders = [];
		madeSpeakers = [];
		psychShifts = [];
		psychCams = [];
		exClassPrefix = className(mod);

		// ---------------- which characters / stages the songs use (0.7: base-game ones the mod relies on are exported too)
		var usage:Map<String, Map<String, Int>> = [];
		var usedStages:Array<String> = [];
		for (folder in listBoth('data/'))
		{
			var chartPath:String = find('data/$folder/$folder.json');
			if (chartPath == null) continue;
			var raw:Dynamic = CompatUtil.readJson(chartPath);
			if (raw == null) continue;
			var s:Dynamic = (raw.song != null && Type.typeof(raw.song) == TObject) ? raw.song : raw;
			for (pair in [['bf', s.player1], ['dad', s.player2], ['gf', s.gfVersion != null ? s.gfVersion : s.player3]])
			{
				if (pair[1] == null || Std.string(pair[1]).length < 1) continue;
				var cid:String = Std.string(pair[1]);
				if (!usage.exists(cid)) usage.set(cid, []);
				var m:Map<String, Int> = usage.get(cid);
				m.set(pair[0], (m.exists(pair[0]) ? m.get(pair[0]) : 0) + 1);
			}
			var st:String = (s.stage != null && Std.string(s.stage).length > 0) ? Std.string(s.stage) : 'stage';
			if (!usedStages.contains(st)) usedStages.push(st);
		}

		// ---------------- characters
		var charMap:Map<String, String> = [];
		var charFiles:Map<String, String> = [];
		for (file in listBoth('characters/')) if (file.endsWith('.json')) charFiles.set(CompatUtil.baseName(file), find('characters/$file'));
		for (cid in usage.keys())
			if (!charFiles.exists(cid))
			{
				var basePath:String = CompatUtil.exists('assets/shared/characters/$cid.json') ? 'assets/shared/characters/$cid.json' : null;
				if (basePath != null) charFiles.set(cid, basePath);
				else report.warn('character "$cid" is used by a song but is not in the mod or Vortex\'s base game; V-Slice will look for its own "$cid".');
			}
		var charList:Array<String> = [for (k in charFiles.keys()) k];
		charList.sort(Reflect.compare);
		for (id in charList)
		{
			var err:Array<String> = [];
			var c:Dynamic = CompatUtil.readJson(charFiles.get(id), err);
			if (c == null) { report.error('character $id: not valid JSON (${err.join('')})'); continue; }
			var newId:String = freeId(id, BASE_CHARACTERS);
			try
			{
				CompatUtil.writeJson(out + 'data/characters/$newId.json', characterToVSlice(c, id, newId, mainSlot(usage.get(id)), root, report));
				charMap.set(id, newId);
				var fromBase:Bool = charFiles.get(id).startsWith('assets/');
				report.ok('character $id' + (newId != id ? ' -> $newId (V-Slice\'s base game has a "$id"; the same id would replace it and run its script)' : '')
					+ (fromBase ? ' (from the base game; the mod uses it)' : ''));
			}
			catch (e:Dynamic) report.error('character $id: $e');
		}

		// ---------------- stages
		var stageIds:Map<String, String> = [];
		if (usedStages.contains('stage') && find('stages/stage.json') == null)
		{
			// 0.7: Psych's default stage is code in Psych; write it as a stage so the characters stand where they do in Psych
			var def:Dynamic = backend.StageData.dummy();
			def.objects = PSYCH_STAGE_OBJECTS;
			var newId:String = 'stage-$exSlug';
			CompatUtil.writeJson(out + 'data/stages/$newId.json', stageToVSlice(def, 'stage', newId, report));
			stageIds.set('stage', newId);
			report.ok('stage stage (Psych\'s default stage) -> $newId');
		}
		for (file in listBoth('stages/'))
		{
			if (!file.endsWith('.json')) continue;
			var id:String = CompatUtil.baseName(file);
			var err:Array<String> = [];
			var s:Dynamic = CompatUtil.readJson(find('stages/$file'), err);
			if (s == null) { report.error('stage $id: not valid JSON (${err.join('')})'); continue; }
			var newId:String = (id == 'stage') ? 'stage-$exSlug' : freeId(id, BASE_STAGES);
			try
			{
				CompatUtil.writeJson(out + 'data/stages/$newId.json', stageToVSlice(s, id, newId, report));
				stageIds.set(id, newId);
				report.ok('stage $id' + (newId != id ? ' -> $newId (V-Slice\'s base game uses that id)' : ''));
			}
			catch (e:Dynamic) report.error('stage $id: $e');
			if (find('stages/$id.lua') != null || find('stages/$id.hx') != null)
				report.needs('stage $id has a stage script; V-Slice stages use their own HScript classes (scripts/stages/), so port it by hand.');
		}

		// ---------------- songs
		var songIds:Array<String> = [];
		var songMap:Map<String, String> = [];
		for (folder in listBoth('data/'))
		{
			if (!CompatUtil.isDir(root + 'data/$folder') && !CompatUtil.isDir(cache + 'data/$folder')) continue;
			var chart:String = find('data/$folder/$folder.json');
			if (chart == null) continue;
			var newId:String = freeId(folder, BASE_SONGS);
			try
			{
				if (exportSong(folder, newId, root, cache, out, stageIds, charMap, find, report))
				{
					songIds.push(newId);
					songMap.set(folder, newId);
					if (newId != folder) report.ok('song $folder -> $newId (V-Slice\'s base game has a song "$folder"; the same id would replace it)');
				}
			}
			catch (e:Dynamic) report.error('song $folder: $e');
		}
		if (songIds.length < 1) report.warn('No songs were found (charts are expected in data/<song>/<song>.json).');

		// ---------------- 0.7: events and dialogue as V-Slice scripts
		exportEvents(find, report);
		for (sid in songIds) exportDialogue(sid, songFolders.get(sid), find, report);
		exportScripts(songIds, report);
		writeCameraModule(); // song / global scripts can use Camera Follow Pos too

		// ---------------- weeks -> levels
		for (file in listBoth('weeks/'))
		{
			if (!file.endsWith('.json')) continue;
			var id:String = CompatUtil.baseName(file);
			var w:Dynamic = CompatUtil.readJson(find('weeks/$file'));
			if (w == null) { report.error('week $id: not valid JSON'); continue; }
			var songs:Array<String> = [];
			var list:Array<Dynamic> = CompatUtil.isArray(w.songs) ? w.songs : [];
			for (s in list)
			{
				var sid:String = Paths.formatToSongPath(Std.string(s[0]));
				if (songMap.exists(sid)) songs.push(songMap.get(sid));
				else report.warn('week $id: song "${s[0]}" was not converted, left out of the level.');
			}
			var levelId:String = freeId(id, BASE_LEVELS);
			if (levelId != id) report.ok('week $id -> level $levelId (V-Slice\'s base game has a level "$id")');
			var banner:String = find('images/storymenu/$id.png');
			if (banner != null) CompatUtil.copyFile(banner, out + 'images/storymenu/titles/$levelId.png');
			CompatUtil.writeJson(out + 'data/levels/$levelId.json', {
				version: '1.0.0', name: CompatUtil.str(w.storyName, id), titleAsset: 'storymenu/titles/$levelId',
				props: [], background: '#F9CF51', songs: songs, visible: CompatUtil.bool(w.hideStoryMode, false) == false
			});
			report.ok('week $id -> level (${songs.length} songs)');
			var chars:Array<Dynamic> = CompatUtil.isArray(w.weekCharacters) ? w.weekCharacters : [];
			if (chars.filter(function(c) return c != null && Std.string(c).length > 0).length > 0)
				report.needs('week $id: Story Mode characters (${chars.join(', ')}) are Psych menu characters; V-Slice levels use "props" images. Add them to data/levels/$id.json by hand.');
		}

		// ---------------- plain assets (same folder names in both engines)
		var copied:Int = 0;
		for (dir in ['images', 'sounds', 'music', 'shaders', 'videos'])
			for (file in CompatUtil.walk(root + dir + '/'))
			{
				if (dir == 'images' && file.startsWith('storymenu/') && file.endsWith('.png') && file.indexOf('/') == file.lastIndexOf('/')) continue;
				// Vortex Engine 0.7: a picture at a base-game path would replace the base game's picture everywhere
				if (dir == 'images' && (file.endsWith('.png') || file.endsWith('.xml'))
					&& (isBasePicture(file.substr(0, file.length - 4)) || remapped.exists(file.substr(0, file.length - 4)))) continue;
				// Vortex Engine 0.7.2: V-Slice's "videos" library is assets/videos/ and Paths.videos() adds videos/ again, so a
				// mod's videos/videos/<name>.mp4 is what VideoCutscene finds (videos/<name>.mp4 gave "Video file does not exist")
				if (dir == 'videos')
				{
					var low:String = file.toLowerCase();
					if (!(low.endsWith('.mp4') || low.endsWith('.mkv') || low.endsWith('.webm') || low.endsWith('.mov'))) continue;
					CompatUtil.copyFile(root + '$dir/$file', out + 'videos/videos/$file');
					copied++;
					continue;
				}
				CompatUtil.copyFile(root + '$dir/$file', out + '$dir/$file');
				copied++;
			}
		if (copied > 0) report.ok('$copied pictures / sounds / music / shader / video files copied');
		if (CompatUtil.isDir(root + 'fonts')) report.needs('fonts/: V-Slice loads fonts from assets of its own; check that text using these fonts still works.');

		// ---------------- scripts and other things V-Slice can't use
		var lua:Array<String> = [], hx:Array<String> = [];
		for (file in CompatUtil.walk(root))
		{
			var low:String = file.toLowerCase();
			if (low.endsWith('.lua')) lua.push(file);
			else if (low.endsWith('.hx')) hx.push(file);
		}
		// converted: custom_events/, scripts/*.lua, data/<song>/*.lua (exportEvents / exportScripts / exportDialogue)
		lua = lua.filter(function(f) return !f.startsWith('custom_events/') && !f.startsWith('data/') && !(f.startsWith('scripts/') && f.indexOf('/', 8) < 0));
		if (lua.length > 0) report.needs('${lua.length} Lua scripts in other folders were not converted (Psych only runs Lua from scripts/, data/<song>/, custom_events/ and similar): ' + lua.slice(0, 15).join(', ') + (lua.length > 15 ? '...' : ''));
		if (hx.length > 0) report.needs('${hx.length} HScript files were not converted: Psych HScript and V-Slice scripted classes use different APIs: ' + hx.slice(0, 15).join(', ') + (hx.length > 15 ? '...' : ''));
		for (folder in ['custom_notetypes', 'achievements', 'states', 'classes', 'lib', 'custom_menus'])
			if (CompatUtil.isDir(root + folder)) report.needs('$folder/ is Psych / Vortex-only and was not converted.');

		// ---------------- polymod metadata
		var pack:Dynamic = CompatUtil.readJson(root + 'pack.json');
		CompatUtil.writeJson(out + '_polymod_meta.json', {
			title: CompatUtil.str(pack != null ? pack.name : null, mod),
			description: CompatUtil.str(pack != null ? pack.description : null, 'Converted from a Vortex Engine / Psych Engine mod.'),
			contributors: [], api_version: '0.8.0', mod_version: '1.0.0', license: ''
		});
		if (CompatUtil.exists(root + 'pack.png')) CompatUtil.copyFile(root + 'pack.png', out + '_polymod_icon.png');
		// Vortex Engine 0.6: mods unzipped one folder too deep are skipped by V-Slice without a message (seen on phones)
		report.note('Installing: the mod folder must sit right inside V-Slice\'s mods/ folder, so that mods/${mod}-vslice/_polymod_meta.json exists. One folder deeper (mods/vortex_converted/...) and V-Slice ignores it without a message. The converter also makes ${mod}-vslice.zip next to this folder, which unzips the right way (also on Android / iOS, where mods/ is in the game\'s data folder). Restart the game after adding a mod.');
		report.note('_polymod_meta.json: "api_version" is 0.8.0. V-Slice 0.8.x loads every mod in its mods/ folder automatically (there is no mod list) if api_version matches ">=0.8.0 <0.9.0"; change it if your V-Slice is a different version.');

		validate(out, songIds, report);
		checkTextures(out, report);
		report.note(iosNote());
		report.note('A successful conversion means the files are in V-Slice\'s format. It was not run inside V-Slice: play every song there and check the items above before releasing it.');
		CompatUtil.writeText(out + 'REPORT.txt', report.toText('Vortex Engine V-Slice Converter report') + '\nOutput folder: $out\nSource (unchanged): mods/$mod/\n');
		// Vortex Engine 0.7: the phone-ready zip is made every time (Z remakes it)
		var zipErr:Array<String> = [];
		if (makeZip(out, zipErr) == null) report.warn('could not make the zip: ' + zipErr.join('; '));
		Mods.currentModDirectory = oldDirectory;
		#else
		report.error('This build has no mod support.');
		#end
		return report;
	}

	/**
	 * Vortex Engine 0.6: zips a converted mod folder as "<folder name>.zip" next to it, with the mod folder itself at the
	 * top of the zip (<mod>-vslice/_polymod_meta.json), so unzipping it into V-Slice's mods/ puts it at the right depth.
	 * Files are written one at a time (big mods don't have to fit in memory); text files are compressed, pictures and
	 * audio are already compressed and are stored. Returns the zip's path, or null (error in `error`).
	 */
	public static function makeZip(folder:String, ?error:Array<String>):String
	{
		#if sys
		if (folder == null || !CompatUtil.isDir(folder)) { if (error != null) error.push('nothing converted yet'); return null; }
		while (folder.endsWith('/')) folder = folder.substr(0, folder.length - 1);
		var name:String = folder.substr(folder.lastIndexOf('/') + 1);
		var zipPath:String = folder + '.zip';
		var output:sys.io.FileOutput = null;
		try
		{
			output = sys.io.File.write(zipPath, true);
			var writer:haxe.zip.Writer = new haxe.zip.Writer(output);
			for (rel in CompatUtil.walk(folder + '/', 100000))
			{
				if (rel == MARKER || rel.endsWith('/' + MARKER)) continue;
				var bytes:haxe.io.Bytes = sys.io.File.getBytes(folder + '/' + rel);
				var entry:haxe.zip.Entry = {
					fileName: name + '/' + rel, fileSize: bytes.length, fileTime: Date.now(), compressed: false,
					dataSize: bytes.length, data: bytes, crc32: haxe.crypto.Crc32.make(bytes)
				};
				var ext:String = rel.substr(rel.lastIndexOf('.') + 1).toLowerCase();
				if (['json', 'txt', 'xml', 'hx', 'hxc', 'lua', 'frag', 'vert', 'csv'].contains(ext) && bytes.length > 0)
					haxe.zip.Tools.compress(entry, 6);
				writer.writeEntryHeader(entry);
				output.writeFullBytes(entry.data, 0, entry.data.length);
			}
			writer.writeCDR();
			output.close();
			return zipPath;
		}
		catch (e:Dynamic)
		{
			if (output != null) try output.close() catch (_:Dynamic) {}
			if (error != null) error.push(Std.string(e));
			return null;
		}
		#else
		if (error != null) error.push('not supported on this platform');
		return null;
		#end
	}

	static function exportSong(id:String, newId:String, root:String, cache:String, out:String, stageIds:Map<String, String>, charMap:Map<String, String>, find:String->String, report:CompatReport):Bool
	{
		// Vortex Engine 0.7: characters / stages / the song may have been renamed away from V-Slice base-game ids
		function ch(c:String):String return (c != null && charMap.exists(c)) ? charMap.get(c) : c;
		var diffs:Array<{name:String, path:String}> = [];
		for (d in [['normal', '$id.json'], ['easy', '$id-easy.json'], ['hard', '$id-hard.json']])
		{
			var p:String = find('data/$id/${d[1]}');
			if (p != null) diffs.push({name: d[0], path: p});
		}
		var base:SwagSong = null;
		var notesByDiff:Dynamic = {};
		var speeds:Dynamic = {};
		var extraCols:Int = 0, singers:Int = 0;
		for (d in diffs)
		{
			var raw:String = CompatUtil.readText(d.path);
			var song:SwagSong = null;
			try song = Song.parseJSON(raw, id) catch (e:Dynamic) { report.error('$id: ${CompatUtil.fileName(d.path)} could not be read: $e'); continue; }
			if (base == null) base = song;
			var notes:Array<Dynamic> = [];
			for (sec in song.notes)
				for (n in sec.sectionNotes)
				{
					var col:Int = Std.int(n[1]);
					if (col > 7) { extraCols++; continue; }
					var note:Dynamic = {t: n[0], d: col, l: Math.max(0, CompatUtil.num(n[2], 0))};
					var type:String = (n.length > 3 && n[3] != null) ? Std.string(n[3]) : '';
					if (type.length > 0) note.k = type;
					if (n.length > 4 && n[4] != null && n[4] >= 0) singers++;
					notes.push(note);
				}
			notes.sort(function(a, b) return a.t < b.t ? -1 : (a.t > b.t ? 1 : 0));
			Reflect.setField(notesByDiff, d.name, notes);
			Reflect.setField(speeds, d.name, song.speed);
		}
		if (base == null) return false;
		if (extraCols > 0) report.needs('$id: $extraCols notes are on extra strumlines (3 and up); V-Slice charts only have the player and opponent lanes, so they were left out.');
		if (singers > 0) report.warn('$id: $singers notes pick a singer ("Sung by"); V-Slice has one character per side, the choice was dropped.');

		// time changes + camera focus from the sections
		var timeChanges:Array<Dynamic> = [{t: 0, b: 0, bpm: base.bpm, n: 4, d: 4, bt: [4, 4, 4, 4]}];
		var events:Array<Dynamic> = [];
		var t:Float = 0, beat:Float = 0, bpm:Float = base.bpm;
		var lastFocus:Int = -1;
		for (sec in base.notes)
		{
			if (sec.changeBPM == true && sec.bpm > 0 && sec.bpm != bpm)
			{
				bpm = sec.bpm;
				timeChanges.push({t: round(t), b: round(beat), bpm: bpm, n: 4, d: 4, bt: [4, 4, 4, 4]});
			}
			var focus:Int = sec.gfSection == true ? 2 : (sec.mustHitSection ? 0 : 1);
			if (focus != lastFocus)
			{
				events.push({t: round(t), e: 'FocusCamera', v: {char: focus}});
				lastFocus = focus;
			}
			var beats:Float = (sec.sectionBeats > 0) ? sec.sectionBeats : 4;
			t += beats * 60000 / bpm;
			beat += beats;
		}
		if (sectionsHaveAlt(base)) report.needs('$id: some sections use "Alt Animation"; V-Slice uses note kinds / scripts for alt animations.');

		var unsupported:Map<String, Int> = [];
		for (group in base.events)
		{
			var time:Float = group[0];
			for (e in (group[1] : Array<Dynamic>))
			{
				var name:String = Std.string(e[0]);
				var v1:String = e[1] != null ? Std.string(e[1]) : '', v2:String = e[2] != null ? Std.string(e[2]) : '';
				switch (name)
				{
					case 'Play Animation':
						var target:String = switch (v2.toLowerCase().trim()) { case 'bf' | 'boyfriend' | '1': 'bf'; case 'gf' | 'girlfriend' | '2': 'gf'; default: 'dad'; };
						events.push({t: round(time), e: 'PlayAnimation', v: {target: target, anim: v1, force: true}});
					case 'Hey!':
						var who:String = v1.toLowerCase().trim();
						if (who != 'gf' && who != 'girlfriend' && who != '1') events.push({t: round(time), e: 'PlayAnimation', v: {target: 'bf', anim: 'hey', force: true}});
						if (who != 'bf' && who != 'boyfriend' && who != '0') events.push({t: round(time), e: 'PlayAnimation', v: {target: 'gf', anim: 'cheer', force: true}});
					case 'Change Scroll Speed':
						var mult:Float = CompatUtil.num(v1, 1);
						var secs:Float = CompatUtil.num(v2, 0);
						events.push({t: round(time), e: 'ScrollSpeed', v: {scroll: mult, duration: round(secs * bpm / 60 * 4), ease: 'linear', absolute: false}});
					// Vortex Engine 0.7: Vortex's camera events are V-Slice's own
					case 'Focus Camera':
						var who:String = v1.toLowerCase().trim();
						events.push({t: round(time), e: 'FocusCamera', v: {char: (who == 'bf' || who == 'boyfriend' || who == '0') ? 0 : ((who == 'gf' || who == 'girlfriend' || who == '2') ? 2 : 1)}});
					case 'Zoom Camera':
						var z:String = v1.trim().toLowerCase();
						var parts:Array<String> = v2.split(',');
						var zsecs:Float = CompatUtil.num(parts[0], 0);
						events.push({t: round(time), e: 'ZoomCamera', v: {zoom: CompatUtil.num(z.startsWith('x') ? z.substr(1) : z, 1), mode: z.startsWith('x') ? 'stage' : 'direct',
							duration: round(zsecs * bpm / 60 * 4), ease: zsecs <= 0 ? 'INSTANT' : (parts.length > 1 ? parts[1].trim() : 'linear')}});
					default:
						// Vortex Engine 0.7: kept with its values; exportEvents() writes a V-Slice script class that runs it
						if (name == 'Change Character') v2 = ch(v2.trim()); // the character may have been renamed
						events.push({t: round(time), e: name, v: {value1: v1, value2: v2}});
						usedEvents.set(name, (usedEvents.exists(name) ? usedEvents.get(name) : 0) + 1);
				}
			}
		}
		for (name => count in unsupported)
			report.needs('$id: $count "$name" event(s) have no V-Slice equivalent and were left out; recreate them as a V-Slice song event or script.');
		songFolders.set(newId, id);
		events.sort(function(a, b) return a.t < b.t ? -1 : (a.t > b.t ? 1 : 0));

		var stage:String = (base.stage != null && base.stage.length > 0) ? base.stage : 'stage';
		if (stageIds.exists(stage)) stage = stageIds.get(stage);
		else if (STAGE_IDS.exists(stage))
		{
			stage = STAGE_IDS.get(stage);
			report.warn('$id: uses Psych\'s built-in stage "${base.stage}"; it plays on V-Slice\'s "$stage", where converted characters may stand a little differently than in Psych.');
		}
		else report.warn('$id: stage "$stage" was not converted (no stages/$stage.json in the mod); the level uses V-Slice\'s mainStage until you add it.');
		var p1:String = ch(base.player1), p2:String = ch(base.player2), gfc:String = ch(base.gfVersion);
		var difficulties:Array<String> = [for (d in diffs) d.name];
		var meta:Dynamic = {
			version: METADATA_VERSION, songName: base.song, artist: 'Unknown', charter: '', timeFormat: 'ms', divisions: 96, looped: false,
			timeChanges: timeChanges, generatedBy: 'Vortex Engine ' + backend.VortexConfig.engineVersion + ' V-Slice Converter',
			playData: {
				album: 'volume1', previewStart: 0, previewEnd: 15000, songVariations: [], difficulties: difficulties,
				characters: {player: p1, girlfriend: gfc, opponent: p2, instrumental: '', altInstrumentals: [],
					playerVocals: [p1], opponentVocals: [p2]},
				stage: stage, noteStyle: (backend.StageData.getStageFile(base.stage).isPixelStage == true) ? 'pixel' : 'funkin', ratings: {normal: 0}
			}
		};
		var chart:Dynamic = {version: CHART_VERSION, scrollSpeed: speeds, events: events, notes: notesByDiff, generatedBy: meta.generatedBy};
		CompatUtil.writeJson(out + 'data/songs/$newId/$newId-metadata.json', meta);
		CompatUtil.writeJson(out + 'data/songs/$newId/$newId-chart.json', chart);

		// audio: V-Slice names vocals after the characters
		var inst:String = find('songs/$id/Inst.ogg');
		if (inst == null) inst = find('songs/$id/song/Inst.ogg');
		if (inst != null) CompatUtil.copyFile(inst, out + 'songs/$newId/Inst.ogg');
		else report.error('$id: songs/$id/Inst.ogg not found (only .ogg is copied; V-Slice needs an Inst.ogg).');
		var vp:String = find('songs/$id/Voices-Player.ogg'), vo:String = find('songs/$id/Voices-Opponent.ogg');
		var single:String = find('songs/$id/Voices.ogg');
		if (single == null) single = find('songs/$id/song/Voices.ogg');
		if (vp != null) CompatUtil.copyFile(vp, out + 'songs/$newId/Voices-$p1.ogg');
		if (vo != null) CompatUtil.copyFile(vo, out + 'songs/$newId/Voices-$p2.ogg');
		if (vp == null && single != null)
		{
			CompatUtil.copyFile(single, out + 'songs/$newId/Voices-$p1.ogg');
			report.note('$id: the single Voices.ogg became Voices-$p1.ogg (V-Slice loads vocals per character); the opponent has no separate track.');
		}
		for (f in CompatUtil.list(root + 'songs/$id/'))
			if (f.startsWith('Voices-') && f != 'Voices-Player.ogg' && f != 'Voices-Opponent.ogg' && f.endsWith('.ogg'))
			{
				// Voices-<character>.ogg follows a renamed character
				var who:String = f.substring(7, f.length - 4);
				CompatUtil.copyFile(root + 'songs/$id/$f', out + 'songs/$newId/Voices-${ch(who)}.ogg');
			}
		if (find('songs/$id/Inst.wav') != null && inst == null) report.needs('$id: convert Inst.wav to .ogg for V-Slice.');

		for (s in ['data/$id/script.lua', 'data/$id/script.hx'])
			if (find(s) != null) report.needs('$id: song script $s does not run in V-Slice (write a scripts/songs/$id.hxc module).');
		var count:Int = 0;
		for (d in difficulties) count += (Reflect.field(notesByDiff, d) : Array<Dynamic>).length;
		report.ok('song $id: ${difficulties.join(', ')} ($count notes), ${timeChanges.length} time change(s), ${events.length} events');
		return true;
	}

	static function sectionsHaveAlt(song:SwagSong):Bool
	{
		for (s in song.notes) if (s.altAnim == true) return true;
		return false;
	}

	/**
	 * Vortex Engine 0.7: a Psych character as a V-Slice character that stands EXACTLY where it does in Psych.
	 * Psych: top-left = stage point + "position", drawn at x - animation offset, hitbox = the sheet's first picture.
	 * V-Slice (Stage.addCharacter / BaseCharacter.setScale / Bopper.getScreenPosition): x = feet - idle width / 2,
	 * y = feet - idle height, drawn at x - animation offset * scale. The stage keeps Psych's points as the feet, the
	 * global "offsets" stay 0 (V-Slice applies them in two places), and the difference is folded into every animation
	 * offset. The camera offset is worked out the same way (V-Slice aims at the idle body's centre).
	 */
	public static function characterToVSlice(c:Dynamic, id:String, newId:String, slot:String, root:String, report:CompatReport):Dynamic
	{
		var images:Array<String> = CompatUtil.str(c.image, 'characters/$id').split(',').map(function(i) return i.trim());
		var render:String = images.length > 1 ? 'multisparrow' : 'sparrow';
		var sheets:Array<Array<AtlasFrame>> = [];
		var keys:Array<String> = [];
		var pics:Array<Pic> = [];
		for (img in images)
		{
			var pic:Pic = resolvePicture(img, 'character $id');
			if (pic != null) pics.push(pic);
			if (pic == null)
			{
				if (findAnimateAtlas(img)) { render = 'animateatlas'; keys.push(img); continue; }
				report.error('character $id: picture images/$img.png was not found in the mod or the base game.');
				keys.push(img);
				sheets.push([]);
				continue;
			}
			keys.push(pic.key);
			sheets.push(pic.xml != null ? readAtlas(pic.xml) : []);
		}
		var src:Array<Dynamic> = CompatUtil.isArray(c.animations) ? c.animations : [];
		var s:Float = CompatUtil.num(c.scale, 1);
		if (s == 0) s = 1;
		var pos:Array<Float> = CompatUtil.isArray(c.position) ? [CompatUtil.num(c.position[0], 0), CompatUtil.num(c.position[1], 0)] : [0, 0];
		var cp:Array<Float> = CompatUtil.isArray(c.camera_position) ? [CompatUtil.num(c.camera_position[0], 0), CompatUtil.num(c.camera_position[1], 0)] : [0, 0];

		// W1/H1: first picture of the first sheet (Psych's hitbox). fw/fh: first idle picture (what V-Slice measures).
		var first:AtlasFrame = (sheets.length > 0 && sheets[0].length > 0) ? sheets[0][0] : null;
		var idleAnim:Dynamic = null;
		for (name in ['danceLeft', 'idle']) for (a in src) if (idleAnim == null && a.anim == name) idleAnim = a;
		if (idleAnim == null && src.length > 0) idleAnim = src[0];
		var idle:AtlasFrame = idleAnim != null ? findFrame(sheets, CompatUtil.str(idleAnim.name, ''), CompatUtil.isArray(idleAnim.indices) ? idleAnim.indices : null) : null;
		var exact:Bool = first != null && idle != null;
		var W1:Float = first != null ? first.w : 0, H1:Float = first != null ? first.h : 0;
		var fw:Float = idle != null ? idle.w : W1, fh:Float = idle != null ? idle.h : H1;
		if (!exact)
		{
			var why:String = render == 'animateatlas' ? 'it is a texture atlas' : (first == null ? 'its sprite sheet has no .xml'
				: 'its idle animation "${idleAnim != null ? idleAnim.name : ''}" is not in its sprite sheet (it can not show in Psych either)');
			report.warn('character $id: could not be measured ($why), so its V-Slice position is approximate.');
		}
		// phones: one factor for all of the character's sheets (they share one scale); V-Slice draws offsets x scale
		var f:Float = 1;
		for (pic in pics) f = Math.min(f, shrinkFactor(pic.w, pic.h));
		var sv:Float = s / f; // the scale written for V-Slice
		if (f < 1)
			for (i in 0...pics.length)
			{
				var k:String = shrinkPicture(pics[i], f);
				var at:Int = keys.indexOf(pics[i].key);
				if (at > -1) keys[at] = k;
			}
		var shiftX:Float = pos[0] + fw * s / 2 + W1 * (1 - s) / 2;
		var shiftY:Float = pos[1] + fh * s + H1 * (1 - s) / 2;
		// for scripts: Psych x = V-Slice x + pos + idle width / 2, Psych y = V-Slice y + pos + idle height
		psychShifts.set(newId, [round2(pos[0] + fw * s / 2), round2(pos[1] + fh * s), round2(W1 * s), round2(H1 * s)]);
		psychCams.set('char:$newId', cp);

		var anims:Array<Dynamic> = [];
		for (a in src)
		{
			var off:Array<Dynamic> = CompatUtil.isArray(a.offsets) ? a.offsets : [0, 0];
			var anim:Dynamic = {
				name: CompatUtil.str(a.anim, 'idle'), prefix: CompatUtil.str(a.name, 'idle'),
				offsets: [round2((CompatUtil.num(off[0], 0) - shiftX) / sv), round2((CompatUtil.num(off[1], 0) - shiftY) / sv)],
				looped: CompatUtil.bool(a.loop, false), frameRate: Std.int(CompatUtil.num(a.fps, 24))
			};
			if (CompatUtil.isArray(a.indices) && a.indices.length > 0) anim.frameIndices = a.indices;
			// multisparrow: an animation on another sheet needs that sheet's assetPath
			if (render == 'multisparrow')
				for (i in 1...sheets.length)
					if (sheetHas(sheets[i], anim.prefix) && !sheetHas(sheets[0], anim.prefix)) { anim.assetPath = keys[i]; break; }
			anims.push(anim);
		}
		var hasDanceLR:Bool = src.filter(function(a) return a.anim == 'danceLeft').length > 0;
		var icon:String = CompatUtil.str(c.healthicon, id);
		// camera: Psych aims at the hitbox centre (+ camera_position, which Psych mirrors for the player)
		var camX:Float = pos[0] + W1 * s / 2 + (slot == 'bf' ? -cp[0] : cp[0]);
		var camY:Float = pos[1] + (H1 + fh) * s / 2 + cp[1];
		if (CompatUtil.isArray(c.healthbar_colors)) report.note('character $id: health bar colours are not part of V-Slice character files.');
		return {
			version: '1.0.0', name: newId, renderType: render, assetPath: keys[0], scale: round2(sv * 10000) / 10000,
			healthIcon: {id: icon, scale: 1, flipX: false, isPixel: CompatUtil.bool(c.no_antialiasing, false), offsets: [0, 0]},
			offsets: [0, 0], cameraOffsets: [round2(camX), round2(camY)], isPixel: CompatUtil.bool(c.no_antialiasing, false),
			flipX: CompatUtil.bool(c.flip_x, false), singTime: CompatUtil.num(c.sing_duration, 4) * 2, danceEvery: hasDanceLR ? 1 : 2,
			startingAnimation: hasDanceLR ? 'danceLeft' : 'idle', animations: anims
		};
	}

	public static function stageToVSlice(s:Dynamic, id:String, newId:String, report:CompatReport):Dynamic
	{
		for (slot in [['bf', 'camera_boyfriend'], ['dad', 'camera_opponent'], ['gf', 'camera_girlfriend']])
		{
			var c:Array<Dynamic> = Reflect.field(s, slot[1]);
			psychCams.set('stage:$newId:${slot[0]}', [CompatUtil.num(c != null ? c[0] : null, 0), CompatUtil.num(c != null ? c[1] : null, 0)]);
		}
		var props:Array<Dynamic> = [];
		var chars:Dynamic = {};
		var objects:Array<Dynamic> = CompatUtil.isArray(s.objects) ? s.objects : [];
		var z:Int = 0;
		var placed:Array<String> = [];
		function charSlot(slot:String, field:String, zIndex:Int)
		{
			var p:Array<Dynamic> = Reflect.field(s, field);
			var cam:Array<Dynamic> = Reflect.field(s, 'camera_' + field);
			// Vortex Engine 0.6: Psych's moveCamera adds bf -100,-100 / dad +150,-100 by itself, V-Slice only adds the
			// stage's cameraOffsets, so they go in here (the camera used to sit 100-150 px off in converted mods)
			var builtIn:Array<Float> = slot == 'bf' ? [-100, -100] : (slot == 'dad' ? [150, -100] : [0, 0]);
			// Vortex Engine 0.7: Psych's point is used as the feet; converted characters carry the rest (characterToVSlice)
			var data:Dynamic = {
				zIndex: zIndex,
				position: [CompatUtil.num(p != null ? p[0] : null, 0), CompatUtil.num(p != null ? p[1] : null, 0)],
				cameraOffsets: [CompatUtil.num(cam != null ? cam[0] : null, 0) + builtIn[0], CompatUtil.num(cam != null ? cam[1] : null, 0) + builtIn[1]]
			};
			if (slot == 'gf') data.scroll = [0.95, 0.95]; // Psych's girlfriend group scrolls at 0.95
			Reflect.setField(chars, slot, data);
			placed.push(slot);
		}
		for (o in objects)
		{
			z += 10;
			var type:String = CompatUtil.str(o.type, 'sprite');
			switch (type)
			{
				case 'gf' | 'gfGroup': charSlot('gf', 'girlfriend', z);
				case 'dad' | 'dadGroup': charSlot('dad', 'opponent', z);
				case 'boyfriend' | 'boyfriendGroup': charSlot('bf', 'boyfriend', z);
				case 'square' | 'sprite' | 'animatedSprite':
					var scale:Array<Dynamic> = CompatUtil.isArray(o.scale) ? o.scale : [1, 1];
					var prop:Dynamic = {
						name: CompatUtil.str(o.name, 'prop$z'), position: [CompatUtil.num(o.x, 0), CompatUtil.num(o.y, 0)], zIndex: z,
						scale: scale, scroll: CompatUtil.isArray(o.scroll) ? o.scroll : [1, 1], alpha: CompatUtil.num(o.alpha, 1),
						isPixel: CompatUtil.bool(o.antialiasing, true) == false, flipX: CompatUtil.bool(o.flipX, false), flipY: CompatUtil.bool(o.flipY, false)
					};
					if (type == 'square') prop.assetPath = '#' + CompatUtil.str(o.color, 'FFFFFF').replace('#', '');
					else
					{
						var pic:Pic = resolvePicture(CompatUtil.str(o.image, ''), 'stage $id prop "${o.name}"');
						prop.assetPath = pic != null ? pic.key : CompatUtil.str(o.image, '');
						var pf:Float = pic != null ? shrinkFactor(pic.w, pic.h) : 1;
						if (pf < 1)
						{
							prop.assetPath = shrinkPicture(pic, pf);
							scale = [CompatUtil.num(scale[0], 1) / pf, CompatUtil.num(scale.length > 1 ? scale[1] : scale[0], 1) / pf];
							prop.scale = scale;
						}
						if (pic == null) report.warn('stage $id: picture images/${o.image}.png for "${o.name}" was not found.');
						if (o.color != null && Std.string(o.color).toUpperCase() != 'FFFFFF') report.warn('stage $id: "${o.name}" is tinted (${o.color}); V-Slice props have no tint field.');
					}
					if (type == 'animatedSprite' && CompatUtil.isArray(o.animations))
					{
						prop.animType = 'sparrow';
						prop.animations = [for (a in (o.animations : Array<Dynamic>)) {
							name: CompatUtil.str(a.anim, 'idle'), prefix: CompatUtil.str(a.name, 'idle'), frameRate: Std.int(CompatUtil.num(a.fps, 24)),
							looped: CompatUtil.bool(a.loop, false), offsets: propOffsets(a.offsets, scale),
							frameIndices: CompatUtil.isArray(a.indices) ? a.indices : []
						}];
						prop.startingAnimation = CompatUtil.str(o.firstAnimation, prop.animations[0].name);
					}
					props.push(prop);
				default:
					report.warn('stage $id: object type "$type" was not converted.');
			}
		}
		if (objects.length < 1) report.needs('stage $id has no objects in its JSON (its pictures come from a script or built-in code); add V-Slice props by hand.');
		if (!placed.contains('gf')) charSlot('gf', 'girlfriend', 5);
		if (!placed.contains('dad')) charSlot('dad', 'opponent', 6);
		if (!placed.contains('bf')) charSlot('bf', 'boyfriend', 7);
		if (CompatUtil.bool(s.hide_girlfriend, false)) report.warn('stage $id hides Girlfriend; V-Slice decides that per song (no girlfriend character).');
		return {version: '1.0.1', name: newId, cameraZoom: CompatUtil.num(s.defaultZoom, 1), props: props, characters: chars};
	}

	/** Re-reads everything written and checks the fields V-Slice needs. */
	static function validate(out:String, songIds:Array<String>, report:CompatReport)
	{
		var bad:Int = 0;
		for (file in CompatUtil.walk(out))
		{
			if (!file.endsWith('.json')) continue;
			var err:Array<String> = [];
			if (CompatUtil.readJson(out + file, err) == null) { bad++; report.error('validation: $file is not valid JSON (${err.join('')})'); }
		}
		for (id in songIds)
		{
			var meta:Dynamic = CompatUtil.readJson(out + 'data/songs/$id/$id-metadata.json');
			var chart:Dynamic = CompatUtil.readJson(out + 'data/songs/$id/$id-chart.json');
			if (meta == null || chart == null) { report.error('validation: $id is missing its metadata or chart'); continue; }
			var diffs:Array<Dynamic> = meta.playData.difficulties;
			for (d in diffs)
			{
				var notes:Array<Dynamic> = Reflect.field(chart.notes, d);
				if (notes == null) report.error('validation: $id lists difficulty "$d" but the chart has no notes for it');
				else for (n in notes) if (n.d < 0 || n.d > 7 || n.t < 0) { report.error('validation: $id has a note outside lanes 0-7'); break; }
				if (Reflect.field(chart.scrollSpeed, d) == null) report.error('validation: $id has no scroll speed for "$d"');
			}
			if ((meta.timeChanges : Array<Dynamic>).length < 1) report.error('validation: $id has no time changes');
			if (!CompatUtil.exists(out + 'songs/$id/Inst.ogg')) report.warn('validation: $id has no songs/$id/Inst.ogg');
		}
		if (bad == 0) report.ok('validation: every written JSON file reads back correctly, every converted song has metadata, a chart and its difficulties');
	}

	public static function iosNote():String
		return 'iOS: NOT VERIFIED. This converter only writes files; nothing was tested on iOS. To run a mod on iOS you need a V-Slice build for iOS '
			+ 'that can load it (usually built from source on a Mac with Xcode, with the mod\'s files included), and: no Lua (V-Slice has none), '
			+ 'HScript (.hxc) modules ported from your scripts, shaders that compile as GLSL ES on mobile GPUs, videos in a codec iOS plays (H.264 .mp4), '
			+ '.ogg audio as V-Slice expects, and no native extensions or Windows-only code. Test on a real device before saying it works on iOS.';

	static inline function round(v:Float):Float
		return Math.round(v * 1000) / 1000;

	static inline function round2(v:Float):Float
		return Math.round(v * 100) / 100;

	/** "My Cool Mod!" -> "my-cool-mod" */
	static function slugOf(mod:String):String
	{
		var b:StringBuf = new StringBuf();
		var dash:Bool = false;
		for (i in 0...mod.length)
		{
			var c:String = mod.charAt(i).toLowerCase();
			if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) { b.add(c); dash = false; }
			else if (!dash) { b.add('-'); dash = true; }
		}
		var out:String = b.toString();
		while (out.startsWith('-')) out = out.substr(1);
		while (out.endsWith('-')) out = out.substr(0, out.length - 1);
		return out.length > 0 ? out : 'mod';
	}

	/** an id that doesn't clash with V-Slice's base game ("<id>-<mod>" if it does) */
	static function freeId(id:String, base:Array<String>):String
		return base.contains(id.toLowerCase()) ? '$id-$exSlug' : id;

	/** the side a character is used on most: bf, dad or gf */
	static function mainSlot(m:Map<String, Int>):String
	{
		var best:String = 'dad', n:Int = -1;
		if (m != null) for (k => v in m) if (v > n) { best = k; n = v; }
		return best;
	}

	static function propOffsets(o:Dynamic, scale:Array<Dynamic>):Array<Float>
	{
		var off:Array<Dynamic> = CompatUtil.isArray(o) ? o : [0, 0];
		var sx:Float = CompatUtil.num(scale != null ? scale[0] : null, 1), sy:Float = CompatUtil.num(scale != null ? scale[1] : null, 1);
		return [round2(CompatUtil.num(off[0], 0) / (sx == 0 ? 1 : sx)), round2(CompatUtil.num(off[1], 0) / (sy == 0 ? 1 : sy))];
	}

	/**
	 * Vortex Engine 0.7: finds a picture the way the converted mod will need it on a phone. Android / iOS file names are
	 * case-sensitive (Windows isn't), so the key is changed to the file's real spelling. A picture that only exists in
	 * Vortex's base game is copied into the mod under images/<mod>-base/ (V-Slice's own copy may differ or be missing).
	 */
	static function resolvePicture(key:String, who:String):Pic
	{
		if (key == null || key.length < 1) return null;
		key = CompatUtil.stripLibrary(key);
		for (dir in [exRoot + 'images/', exCache + 'images/'])
		{
			var real:String = CompatUtil.findCaseless(dir, key + '.png');
			if (real == null) continue;
			var realKey:String = real.substr(0, real.length - 4);
			if (realKey != key)
				exReport.note('$who: picture "$key" is really spelled "$realKey"; the converted mod uses the real spelling (phones care about upper / lower case).');
			var xml:String = CompatUtil.findCaseless(dir, realKey + '.xml');
			var size:Array<Int> = pngSize(dir + real);
			// Vortex Engine 0.7: a picture at a path the base game also uses would replace the base game's picture for
			// every song (Polymod replaces files by path), so it moves to images/<mod>/
			if (remapped.exists(realKey)) return {key: remapped.get(realKey), xml: exOut + 'images/' + remapped.get(realKey) + '.xml', png: exOut + 'images/' + remapped.get(realKey) + '.png', w: size[0], h: size[1], privateCopy: true};
			if (isBasePicture(realKey))
			{
				var newKey:String = '$exSlug/$realKey';
				copyPicture(dir, realKey, newKey);
				remapped.set(realKey, newKey);
				exReport.note('$who: picture "$realKey" has the same path as a base-game picture (it would replace it everywhere); the converted mod uses images/$newKey.png.');
				return {key: newKey, xml: xml != null ? dir + xml : null, png: exOut + 'images/$newKey.png', w: size[0], h: size[1], privateCopy: true};
			}
			if (dir == exCache + 'images/') copyPicture(dir, realKey, realKey);
			return {key: realKey, xml: xml != null ? dir + xml : null, png: dir + real, w: size[0], h: size[1], privateCopy: false};
		}
		if (copiedBase.exists(key))
		{
			var ck:String = copiedBase.get(key);
			var sz:Array<Int> = pngSize(exOut + 'images/$ck.png');
			return {key: ck, xml: exOut + 'images/$ck.xml', png: exOut + 'images/$ck.png', w: sz[0], h: sz[1], privateCopy: true};
		}
		var dirs:Array<String> = ['assets/shared/images/', 'assets/images/'];
		for (w in ['week1', 'week2', 'week3', 'week4', 'week5', 'week6', 'week7', 'weekend1', 'tutorial']) dirs.push('assets/$w/images/');
		for (dir in dirs)
		{
			var real:String = CompatUtil.findCaseless(dir, key + '.png');
			if (real == null) continue;
			var realKey:String = real.substr(0, real.length - 4);
			var newKey:String = '$exSlug-base/$realKey';
			copyPicture(dir, realKey, newKey);
			copiedBase.set(key, newKey);
			exReport.note('$who: picture "$key" comes from the base game; copied into the mod as images/$newKey.png.');
			var xml:String = exOut + 'images/$newKey.xml';
			var sz:Array<Int> = pngSize(exOut + 'images/$newKey.png');
			return {key: newKey, xml: CompatUtil.exists(xml) ? xml : null, png: exOut + 'images/$newKey.png', w: sz[0], h: sz[1], privateCopy: true};
		}
		return null;
	}

	/** is images/<key>.png also a base-game picture (Vortex ships the same base game as V-Slice) */
	static function isBasePicture(key:String):Bool
	{
		var dirs:Array<String> = ['assets/shared/images/', 'assets/images/'];
		for (w in ['week1', 'week2', 'week3', 'week4', 'week5', 'week6', 'week7', 'weekend1', 'tutorial']) dirs.push('assets/$w/images/');
		for (d in dirs) if (CompatUtil.findCaseless(d, key + '.png') != null) return true;
		return false;
	}

	static function pngSize(path:String):Array<Int>
	{
		try
		{
			var input = sys.io.File.read(path, true);
			var b:haxe.io.Bytes = input.read(24);
			input.close();
			return [(b.get(16) << 24) | (b.get(17) << 16) | (b.get(18) << 8) | b.get(19), (b.get(20) << 24) | (b.get(21) << 16) | (b.get(22) << 8) | b.get(23)];
		}
		catch (e:Dynamic) return [0, 0];
	}

	/** the factor (<= 1) that brings a picture down to MOBILE_MAX_TEXTURE */
	static function shrinkFactor(w:Int, h:Int):Float
	{
		var m:Int = w > h ? w : h;
		return m > MOBILE_MAX_TEXTURE ? MOBILE_MAX_TEXTURE / m : 1;
	}

	/**
	 * Vortex Engine 0.7: makes a picture f times smaller for phones (an 8192x8192 picture takes 256 MB of video memory and
	 * made converted mods lag or reload on phones). Writes images/<mod>/<key>.png (+ .xml with every frame's numbers
	 * scaled); the caller multiplies the sprite's scale by 1 / f so it looks the same size. Returns the new key.
	 */
	static function shrinkPicture(pic:Pic, f:Float):String
	{
		var newKey:String = pic.privateCopy ? pic.key : '$exSlug/${pic.key}';
		if (shrunk.exists(newKey)) return newKey;
		var outPng:String = exOut + 'images/$newKey.png';
		try
		{
			var src = openfl.display.BitmapData.fromFile(pic.png);
			if (src == null) return pic.key;
			var w:Int = Math.ceil(src.width * f), h:Int = Math.ceil(src.height * f);
			var dst = new openfl.display.BitmapData(w, h, true, 0);
			var m = new openfl.geom.Matrix();
			m.scale(f, f);
			dst.draw(src, m, null, null, null, true);
			CompatUtil.makeDirs(outPng.substr(0, outPng.lastIndexOf('/') + 1));
			sys.io.File.saveBytes(outPng, dst.encode(dst.rect, new openfl.display.PNGEncoderOptions()));
			src.dispose();
			dst.dispose();
			if (pic.xml != null)
			{
				var root:Xml = CompatUtil.readXml(pic.xml);
				if (root != null)
				{
					for (node in root.elementsNamed('SubTexture'))
						for (attr in ['x', 'y', 'width', 'height', 'frameX', 'frameY', 'frameWidth', 'frameHeight'])
							if (node.exists(attr)) node.set(attr, Std.string(Math.round(Std.parseFloat(node.get(attr)) * f)));
					CompatUtil.writeText(exOut + 'images/$newKey.xml', '<?xml version="1.0" encoding="utf-8"?>\n' + root.toString());
				}
			}
			if (!pic.privateCopy) remapped.set(pic.key, newKey);
			shrunk.set(newKey, f);
			exReport.note('phones: images/${pic.key}.png (${pic.w}x${pic.h}) was made ${Math.round(f * 100)}% size for the converted mod (images/$newKey.png); it is drawn ${Math.round(100 / f)}% bigger, so it looks the same.');
			return newKey;
		}
		catch (e:Dynamic)
		{
			exReport.warn('phones: images/${pic.key}.png could not be made smaller ($e); it is used at full size.');
			return pic.key;
		}
	}

	static function copyPicture(dir:String, key:String, newKey:String)
	{
		for (ext in ['.png', '.xml', '.txt'])
			if (CompatUtil.exists(dir + key + ext)) CompatUtil.copyFile(dir + key + ext, exOut + 'images/' + newKey + ext);
	}

	static function findAnimateAtlas(key:String):Bool
	{
		for (dir in [exRoot + 'images/', exCache + 'images/', 'assets/shared/images/'])
			if (CompatUtil.exists(dir + key + '/Animation.json')) return true;
		return false;
	}

	/** the pictures of a Sparrow .xml in file order, with their full (untrimmed) sizes */
	static function readAtlas(path:String):Array<AtlasFrame>
	{
		var out:Array<AtlasFrame> = [];
		var xml:Xml = CompatUtil.readXml(path);
		if (xml == null) return out; // readXml returns the <TextureAtlas> element itself
		for (node in xml.elementsNamed('SubTexture'))
		{
			var w:String = node.exists('frameWidth') ? node.get('frameWidth') : node.get('width');
			var h:String = node.exists('frameHeight') ? node.get('frameHeight') : node.get('height');
			out.push({name: node.get('name'), w: Std.parseFloat(w), h: Std.parseFloat(h)});
		}
		return out;
	}

	static function sheetHas(sheet:Array<AtlasFrame>, prefix:String):Bool
	{
		for (f in sheet) if (f.name != null && f.name.startsWith(prefix)) return true;
		return false;
	}

	/** the first picture an animation shows (flixel sorts a prefix's pictures by their number) */
	static function findFrame(sheets:Array<Array<AtlasFrame>>, prefix:String, indices:Array<Dynamic>):AtlasFrame
	{
		for (sheet in sheets)
		{
			var matches:Array<{n:Int, f:AtlasFrame}> = [];
			for (f in sheet)
				if (f.name != null && f.name.startsWith(prefix))
				{
					var rest:String = f.name.substr(prefix.length);
					var digits:String = '';
					var i:Int = rest.length - 1;
					while (i >= 0 && rest.charAt(i) >= '0' && rest.charAt(i) <= '9') { digits = rest.charAt(i) + digits; i--; }
					matches.push({n: digits.length > 0 ? Std.parseInt(digits) : 0, f: f});
				}
			if (matches.length < 1) continue;
			matches.sort(function(a, b) return a.n - b.n);
			if (indices != null && indices.length > 0)
			{
				var want:Int = Std.int(CompatUtil.num(indices[0], 0));
				for (m in matches) if (m.n == want) return m.f;
				if (want >= 0 && want < matches.length) return matches[want].f;
			}
			return matches[0].f;
		}
		return null;
	}

	static function className(mod:String):String
	{
		var b:StringBuf = new StringBuf();
		var up:Bool = true;
		for (i in 0...mod.length)
		{
			var c:String = mod.charAt(i);
			var ok:Bool = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9');
			if (!ok) { up = true; continue; }
			b.add(up ? c.toUpperCase() : c);
			up = false;
		}
		var out:String = b.toString();
		if (out.length < 1 || (out.charAt(0) >= '0' && out.charAt(0) <= '9')) out = 'Mod' + out;
		return out;
	}

	static function luaStartsDialogue(path:String):Bool
	{
		var src:String = CompatUtil.readText(path);
		return src != null && (src.indexOf('startDialogue') > -1 || src.indexOf('startVideo') > -1);
	}

	/**
	 * Vortex Engine 0.7: every Psych event the charts use becomes a V-Slice song event class (scripts/events/).
	 * custom_events/<name>.lua is translated to HScript (LuaToHScript); Psych's built-in events use small helpers.
	 */
	/** the Psych API helpers with this mod's character table and camera module filled in */
	static function shim():String
	{
		var lines:Array<String> = [];
		var ids:Array<String> = [for (k in psychShifts.keys()) k];
		ids.sort(Reflect.compare);
		for (id in ids)
			lines.push('\t\t\tpsychShifts.set(${quoteHx(id)}, [' + psychShifts.get(id).join(', ') + ']);');
		var cams:Array<String> = [];
		var keys:Array<String> = [for (k in psychCams.keys()) k];
		keys.sort(Reflect.compare);
		for (k in keys) cams.push('\t\t\tpsychCams.set(${quoteHx(k)}, [' + psychCams.get(k).join(', ') + ']);');
		return LuaToHScript.SHIM.split('%PSYCH_SHIFTS%').join(lines.join('\n')).split('%PSYCH_CAMS%').join(cams.join('\n'))
			.split('%CAMERA_MODULE%').join(exClassPrefix + 'PsychCamera');
	}

	/**
	 * Vortex Engine 0.7: holds the camera for Psych's Camera Follow Pos (V-Slice's FocusCamera events would move it away;
	 * Psych keeps it there until the event is called with blank values).
	 */
	static function writeCameraModule()
	{
		var id:String = exClassPrefix + 'PsychCamera';
		var b:StringBuf = new StringBuf();
		b.add('// Made by the Vortex Engine V-Slice Converter: Psych\'s "Camera Follow Pos" keeps the camera on a point\n');
		b.add('import funkin.modding.module.Module;\nimport funkin.play.PlayState;\n\n');
		b.add('class $id extends Module\n{\n\tvar locked:Bool = false;\n\tvar lockX:Float = 0;\n\tvar lockY:Float = 0;\n\n');
		b.add('\tpublic function new()\n\t{\n\t\tsuper(${quoteHx(id)});\n\t}\n\n');
		b.add('\tpublic function lockAt(x:Float, y:Float)\n\t{\n\t\tlocked = true;\n\t\tlockX = x;\n\t\tlockY = y;\n');
		b.add('\t\tif (PlayState.instance != null) PlayState.instance.tweenCameraToPosition(x, y, 0);\n\t}\n\n');
		b.add('\tpublic function release()\n\t{\n\t\tlocked = false;\n\t}\n\n');
		b.add('\tpublic override function onCountdownStart(event)\n\t{\n\t\tsuper.onCountdownStart(event);\n\t\tlocked = false; // a new song starts free\n\t}\n\n');
		b.add('\tpublic override function onSongEvent(event)\n\t{\n\t\tsuper.onSongEvent(event);\n');
		b.add('\t\tif (locked && event.eventData != null && event.eventData.eventKind == \'FocusCamera\') event.cancelEvent();\n\t}\n\n');
		b.add('\tpublic override function onUpdate(event)\n\t{\n\t\tsuper.onUpdate(event);\n');
		b.add('\t\tif (locked && PlayState.instance != null && PlayState.instance.cameraFollowPoint != null) PlayState.instance.cameraFollowPoint.setPosition(lockX, lockY);\n\t}\n}\n');
		CompatUtil.writeText(exOut + 'scripts/modules/$id.hxc', b.toString());
	}

	/**
	 * V-Slice scripted classes can't look their own functions up by name, so callLua lists them. A callback that throws
	 * (something V-Slice doesn't have) is switched off after one message instead of failing every frame.
	 */
	static function callLuaCode(functions:Array<String>):String
	{
		var b:StringBuf = new StringBuf();
		b.add('\n\tvar luaBroken:Dynamic = new StringMap();\n');
		b.add('\tfunction callLua(name:String, args:Array<Dynamic>):Dynamic\n\t{\n\t\tif (luaBroken.exists(name)) return null;\n\t\ttry\n\t\t{\n\t\t\tswitch (name)\n\t\t\t{\n');
		for (f in functions)
			b.add('\t\t\t\tcase ${quoteHx(f)}: return ${LuaToHScript.fn(f)}(args[0], args[1], args[2], args[3]);\n');
		b.add('\t\t\t\tdefault:\n\t\t\t}\n\t\t}\n\t\tcatch (e:Dynamic)\n\t\t{\n\t\t\tluaBroken.set(name, true);\n');
		b.add('\t\t\ttrace(\'[converted Psych Lua] \' + name + \' stopped: \' + e);\n\t\t}\n\t\treturn null;\n\t}\n');
		return b.toString();
	}

	/**
	 * Vortex Engine 0.7: song scripts (data/<song>/*.lua) and global scripts (scripts/*.lua) as V-Slice modules. Psych's
	 * callbacks are called from the matching V-Slice ones, only while one of the mod's songs (or that song) plays.
	 * Dialogue starters are left out (exportDialogue converts those).
	 */
	static function exportScripts(songIds:Array<String>, report:CompatReport)
	{
		var jobs:Array<{file:String, songs:Array<String>}> = [];
		for (f in CompatUtil.list(exRoot + 'scripts/'))
			if (f.toLowerCase().endsWith('.lua')) jobs.push({file: 'scripts/$f', songs: songIds});
		for (sid in songIds)
		{
			var folder:String = songFolders.get(sid);
			if (folder == null) continue;
			for (f in CompatUtil.list(exRoot + 'data/$folder/'))
				if (f.toLowerCase().endsWith('.lua') && !luaStartsDialogue(exRoot + 'data/$folder/$f')) jobs.push({file: 'data/$folder/$f', songs: [sid]});
		}
		var made:Int = 0;
		for (job in jobs)
		{
			var src:String = CompatUtil.readText(exRoot + job.file);
			if (src == null) continue;
			var tr:LuaToHScript = new LuaToHScript();
			var body:String = tr.translate(src);
			if (body == null) { report.needs('${job.file} could not be translated (${tr.error}); port it by hand.'); continue; }
			var base:String = job.file.substr(job.file.lastIndexOf('/') + 1);
			base = base.substr(0, base.length - 4);
			var scope:String = job.songs.length == 1 ? job.songs[0] : 'all';
			var cls:String = exClassPrefix + 'Script' + className(scope == 'all' ? base : scope + '-' + base);
			var b:StringBuf = new StringBuf();
			b.add('// Made by the Vortex Engine V-Slice Converter from ${job.file} (Psych Lua -> V-Slice HScript module)\n');
			b.add(EVENT_IMPORTS.split('import funkin.play.event.SongEvent;').join('import funkin.modding.module.Module;') + '\n');
			b.add('class $cls extends Module\n{\n');
			b.add('\tvar forSongs:Array<String> = [' + [for (s in job.songs) quoteHx(s)].join(', ') + '];\n\tvar lastPs:Dynamic = null;\n\n');
			b.add('\tpublic function new()\n\t{\n\t\tsuper(${quoteHx(cls)});\n\t}\n\n');
			b.add('\tfunction active():Bool\n\t{\n\t\tvar ps = PlayState.instance;\n\t\treturn ps != null && ps.currentSong != null && forSongs.indexOf(ps.currentSong.id) > -1;\n\t}\n\n');
			// a new PlayState = a fresh Psych script (Psych makes one per song)
			b.add('\tfunction psychStart():Bool\n\t{\n\t\tif (!active()) return false;\n\t\tif (lastPs != PlayState.instance)\n\t\t{\n');
			b.add('\t\t\tlastPs = PlayState.instance;\n\t\t\tluaInitDone = false;\n\t\t\tpsychMustHit = false;\n\t\t\tluaInit();\n');
			b.add('\t\t\tcallLua(\'onCreate\', []);\n\t\t\tcallLua(\'onCreatePost\', []);\n\t\t}\n\t\treturn true;\n\t}\n\n');
			var hooks:Array<Array<String>> = [
				['onCountdownStart', 'callLua(\'onCountdownStarted\', []);'],
				['onSongStart', 'callLua(\'onSongStart\', []);'],
				['onUpdate', 'callLua(\'onUpdate\', [event.elapsed]);\n\t\tcallLua(\'onUpdatePost\', [event.elapsed]);'],
				['onBeatHit', 'callLua(\'onBeatHit\', []);'],
				['onStepHit', 'callLua(\'onStepHit\', []);'],
				['onSongEnd', 'callLua(\'onEndSong\', []);'],
				['onGameOver', 'callLua(\'onGameOver\', []);'],
				['onNoteHit', 'var n = event.note.noteData;\n\t\tvar args = [0, n.getDirection(), n.kind == null ? \'\' : n.kind, false];\n\t\tif (n.getMustHitNote()) callLua(\'goodNoteHit\', args);\n\t\telse callLua(\'opponentNoteHit\', args);'],
				['onNoteMiss', 'var n = event.note.noteData;\n\t\tcallLua(\'noteMiss\', [0, n.getDirection(), n.kind == null ? \'\' : n.kind, false]);'],
				['onSongEvent', 'var d = event.eventData;\n\t\tif (d.eventKind == \'FocusCamera\') { var c = Std.string(d.value != null ? d.value.char : 1); psychMustHit = c == \'0\'; psychGfSection = c == \'2\'; }\n'
					+ '\t\tvar v1 = (d.value != null && d.value.value1 != null) ? Std.string(d.value.value1) : \'\';\n\t\tvar v2 = (d.value != null && d.value.value2 != null) ? Std.string(d.value.value2) : \'\';\n'
					+ '\t\tcallLua(\'onEvent\', [d.eventKind, v1, v2, d.time]);']
			];
			// Vortex Engine 0.7 (speed): only hook what the script uses (a V-Slice module hook runs for every module, every frame)
			var uses = function(names:Array<String>) return names.filter(function(f) return tr.functions.indexOf(f) > -1).length > 0;
			var needs:Map<String, Array<String>> = [
				'onCountdownStart' => ['onCreate', 'onCreatePost', 'onCountdownStarted'], 'onSongStart' => ['onSongStart'],
				'onUpdate' => ['onUpdate', 'onUpdatePost'], 'onBeatHit' => ['onBeatHit'], 'onStepHit' => ['onStepHit'],
				'onSongEnd' => ['onEndSong'], 'onGameOver' => ['onGameOver'], 'onNoteHit' => ['goodNoteHit', 'opponentNoteHit'],
				'onNoteMiss' => ['noteMiss'], 'onSongEvent' => ['onEvent']
			];
			var tracksSections:Bool = body.indexOf('psychMustHit') > -1 || body.indexOf('psychGfSection') > -1;
			for (h in hooks)
			{
				var wanted:Bool = uses(needs.get(h[0])) || h[0] == 'onCountdownStart' || (h[0] == 'onSongEvent' && tracksSections);
				if (!wanted) continue;
				var call:String = h[1];
				if (h[0] == 'onUpdate')
					call = [for (f in ['onUpdate', 'onUpdatePost']) if (tr.functions.indexOf(f) > -1) 'callLua(\'$f\', [event.elapsed]);'].join('\n\t\t');
				b.add('\tpublic override function ${h[0]}(event)\n\t{\n\t\tsuper.${h[0]}(event);\n\t\tif (!psychStart()) return;\n\t\t$call\n\t}\n\n');
			}
			b.add(body);
			b.add(shim());
			b.add(callLuaCode(tr.functions) + '}\n');
			CompatUtil.writeText(exOut + 'scripts/modules/$cls.hxc', b.toString());
			made++;
			var notes:Array<String> = [];
			if (tr.unsupported.length > 0) notes.push('these Psych functions have no V-Slice version yet and only print a message: ' + tr.unsupported.join(', '));
			report.ok('${job.file} -> scripts/modules/$cls.hxc' + (scope == 'all' ? ' (all songs of the mod)' : ' (song $scope)'));
			if (notes.length > 0) report.needs('${job.file}: ' + notes.join('; '));
		}
	}

	static function exportEvents(find:String->String, report:CompatReport)
	{
		var wroteModule:Bool = false;
		var names:Array<String> = [for (k in usedEvents.keys()) k];
		names.sort(Reflect.compare);
		for (name in names)
		{
			var lua:String = null;
			var from:String = null;
			if (BUILT_IN_EVENTS.exists(name)) { lua = BUILT_IN_EVENTS.get(name); from = 'Psych built-in event'; }
			else
			{
				var path:String = find('custom_events/$name.lua');
				if (path != null) { lua = CompatUtil.readText(path); from = 'custom_events/$name.lua'; }
				else if (find('custom_events/$name.hx') != null)
				{
					report.needs('event "$name" is an HScript event (custom_events/$name.hx); Psych HScript and V-Slice use different classes, port it by hand to scripts/events/.');
					continue;
				}
			}
			if (lua == null)
			{
				report.needs('event "$name" (${usedEvents.get(name)} in the charts) has no script in the mod and is not a Psych built-in event V-Slice can run; it was kept in the charts but does nothing.');
				continue;
			}
			var tr:LuaToHScript = new LuaToHScript();
			var body:String = tr.translate(lua);
			if (body == null) { report.needs('event "$name": $from could not be translated (${tr.error}); port it by hand.'); continue; }
			var cls:String = exClassPrefix + 'Event' + className(name);
			var q:String = quoteHx(name);
			var b:StringBuf = new StringBuf();
			b.add('// Made by the Vortex Engine V-Slice Converter from $from (Psych Lua -> V-Slice HScript)\n');
			b.add(EVENT_IMPORTS + '\n');
			b.add('class $cls extends SongEvent\n{\n');
			b.add('\tpublic function new()\n\t{\n\t\tsuper($q);\n\t}\n\n');
			b.add('\toverride public function getTitle():String\n\t{\n\t\treturn $q;\n\t}\n\n');
			b.add('\toverride public function handleEvent(data)\n\t{\n\t\tvar v:Dynamic = data.value;\n');
			b.add('\t\tvar v1:String = (v != null && v.value1 != null) ? Std.string(v.value1) : \'\';\n');
			b.add('\t\tvar v2:String = (v != null && v.value2 != null) ? Std.string(v.value2) : \'\';\n');
			b.add('\t\tcallLua(\'onEvent\', [$q, v1, v2, data.time]);\n\t}\n\n');
			b.add(body);
			b.add(shim());
			// V-Slice scripted classes can't look their own functions up by name, so callLua lists them
			b.add(callLuaCode(tr.functions) + '}\n');
			CompatUtil.writeText(exOut + 'scripts/events/$cls.hxc', b.toString());
			if (!wroteModule && body.indexOf('cameraFollowPos(') + lua.indexOf('Camera Follow Pos') > -2) { writeCameraModule(); wroteModule = true; }
			report.ok('event "$name" -> scripts/events/$cls.hxc (from $from)');
			if (tr.unsupported.length > 0)
				report.needs('event "$name": these Psych functions have no V-Slice version yet and only print a message: ' + tr.unsupported.join(', '));
			var callbacks:Array<String> = tr.functions.filter(function(f) return ['onEvent', 'onTimerCompleted', 'onTweenCompleted'].indexOf(f) < 0 && StringTools.startsWith(f, 'on'));
			if (callbacks.length > 0)
				report.needs('event "$name": ${callbacks.join(', ')} are not called in V-Slice event scripts (only onEvent, onTimerCompleted and onTweenCompleted are).');
		}
	}

	static function quoteHx(s:String):String
		return "'" + s.split('\\').join('\\\\').split("'").join("\\'").split('$').join('$$') + "'";

	/**
	 * Vortex Engine 0.7: Psych dialogue (data/<song>/<file>.json started by startDialogue() in a song's Lua) becomes a
	 * V-Slice conversation (data/dialogue/conversations), its portraits speakers (data/dialogue/speakers, placed where
	 * Psych's DialogueBoxPsych puts them), Psych's speech bubble a dialogue box, and a song script
	 * (scripts/songs/<song>.hxc) starts it before the countdown or after the song, like the Lua did.
	 */
	static function exportDialogue(songId:String, folder:String, find:String->String, report:CompatReport)
	{
		if (folder == null) return;
		var startConv:String = null, endConv:String = null;
		// Vortex Engine 0.7.2: startVideo() before the countdown / after the song too (videos are copied as they are)
		var startVideo:String = null, endVideo:String = null;
		var storyOnly:Bool = false;
		for (file in CompatUtil.list(exRoot + 'data/$folder/'))
		{
			if (!file.toLowerCase().endsWith('.lua')) continue;
			var src:String = CompatUtil.readText(exRoot + 'data/$folder/$file');
			if (src == null || (src.indexOf('startDialogue') < 0 && src.indexOf('startVideo') < 0)) continue;
			var re:EReg = ~/(startDialogue|startVideo)\s*\(\s*['"]([^'"]+)['"]\s*(,\s*['"]([^'"]*)['"])?/;
			var pos:Int = 0;
			while (re.matchSub(src, pos))
			{
				var video:Bool = re.matched(1) == 'startVideo';
				var file2:String = re.matched(2);
				var music:String = re.matched(4);
				var at:Int = re.matchedPos().pos;
				pos = at + re.matchedPos().len;
				// which function is this in? onEndSong -> after the song, anything else -> before the countdown
				var before:String = src.substr(0, at);
				var fnRe:EReg = ~/function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
				var lastFn:String = null;
				var p2:Int = 0;
				while (fnRe.matchSub(before, p2)) { lastFn = fnRe.matched(1); p2 = fnRe.matchedPos().pos + fnRe.matchedPos().len; }
				var atEnd:Bool = lastFn == 'onEndSong' || (lastFn != 'onStartCountdown' && src.indexOf('onEndSong') > -1 && src.indexOf('onStartCountdown') < 0);
				if (video)
				{
					if (!atEnd && lastFn != null && ['onStartCountdown', 'onCreate', 'onCreatePost', 'onTimerCompleted', 'onSongStart'].indexOf(lastFn) < 0)
					{
						report.warn('$songId: data/$folder/$file plays the video "$file2" during the song ($lastFn); only videos before the countdown or after the song are converted.');
						continue;
					}
					var vfile:String = CompatUtil.findCaseless(exRoot + 'videos/', file2 + '.mp4');
					if (vfile == null)
					{
						report.warn('$songId: its Lua plays the video "$file2", but videos/$file2.mp4 does not exist (it can\'t play in Psych either).');
						continue;
					}
					var key:String = vfile.substr(0, vfile.length - 4);
					if (atEnd) endVideo = key;
					else
					{
						startVideo = key;
						if (src.indexOf('isStoryMode') > -1) storyOnly = true;
					}
					continue;
				}
				var conv:String = convertConversation(songId, folder, file2, music, report);
				if (conv == null) continue;
				if (atEnd) endConv = conv;
				else
				{
					startConv = conv;
					if (src.indexOf('isStoryMode') > -1) storyOnly = true;
				}
			}
		}
		if (startConv == null && endConv == null && startVideo == null && endVideo == null) return;
		var cls:String = exClassPrefix + 'Song' + className(songId);
		var b:StringBuf = new StringBuf();
		b.add('// Made by the Vortex Engine V-Slice Converter: plays the dialogue / videos the Psych version of this song started with startDialogue() / startVideo()\n');
		b.add('import funkin.play.song.Song;\nimport funkin.play.PlayState;\nimport funkin.play.PlayStatePlaylist;\nimport funkin.play.cutscene.VideoCutscene;\nimport funkin.play.cutscene.CutsceneType;\nimport funkin.Paths;\n\n');
		b.add('class $cls extends Song\n{\n\tvar startDone:Bool = false;\n\tvar startVideoDone:Bool = false;\n\tvar endStarted:Bool = false;\n\tvar endConvDone:Bool = false;\n\tvar endDone:Bool = false;\n\n');
		b.add('\tpublic function new()\n\t{\n\t\tsuper(${quoteHx(songId)});\n\t}\n\n');
		b.add('\tpublic override function onCreate(event)\n\t{\n\t\tsuper.onCreate(event);\n\t\tstartDone = false;\n\t\tstartVideoDone = false;\n\t\tendStarted = false;\n\t\tendConvDone = false;\n\t\tendDone = false;\n\t}\n\n');
		b.add('\tpublic override function onSongRetry(event)\n\t{\n\t\tsuper.onSongRetry(event);\n\t\tstartDone = true; // no dialogue / video again after a restart\n\t\tstartVideoDone = true;\n\t}\n\n');
		if (startConv != null || startVideo != null)
		{
			// the countdown is asked for again after each cutscene (V-Slice starts it when a video / conversation ends)
			b.add('\tpublic override function onCountdownStart(event)\n\t{\n\t\tsuper.onCountdownStart(event);\n\t\tif (PlayState.instance.isChartingMode) return;\n');
			if (storyOnly) b.add('\t\tif (!PlayStatePlaylist.isStoryMode) return; // the Psych script only showed it in Story Mode\n');
			if (startVideo != null)
				b.add('\t\tif (!startVideoDone)\n\t\t{\n\t\t\tstartVideoDone = true;\n\t\t\tevent.cancel();\n\t\t\tVideoCutscene.play(Paths.videos(${quoteHx(startVideo)}), CutsceneType.STARTING); // the countdown starts when it ends\n\t\t\treturn;\n\t\t}\n');
			if (startConv != null)
				b.add('\t\tif (!startDone)\n\t\t{\n\t\t\tstartDone = true;\n\t\t\tevent.cancel();\n\t\t\tPlayState.instance.startConversation(${quoteHx(startConv)}); // the countdown starts when it ends\n\t\t}\n');
			b.add('\t}\n\n');
		}
		if (endConv != null || endVideo != null)
		{
			b.add('\tpublic override function onSongEnd(event)\n\t{\n\t\tsuper.onSongEnd(event);\n\t\tif (endDone || endStarted) return;\n\t\tif (PlayState.instance.isChartingMode) return;\n\t\tendStarted = true;\n\t\tevent.cancel();\n');
			if (endConv != null)
				// Vortex Engine 0.7.2: V-Slice's endSong() turns keys off before onSongEnd, and the "next line" key only works
				// while they are on, so the dialogue after the song could never be clicked through (notes stay off: isInCutscene)
				b.add('\t\tPlayState.instance.startConversation(${quoteHx(endConv)});\n\t\tPlayState.instance.disableKeys = false; // endSong() turned keys off; the dialogue needs them\n\t}\n\n');
			else
				b.add('\t\tendConvDone = true;\n\t\tendDone = true;\n\t\tVideoCutscene.play(Paths.videos(${quoteHx(endVideo)}), CutsceneType.ENDING); // ends the song when it ends\n\t}\n\n');
			if (endConv != null)
			{
				b.add('\tpublic override function onUpdate(event)\n\t{\n\t\tsuper.onUpdate(event);\n');
				b.add('\t\tif (endStarted && !endConvDone && PlayState.instance.currentConversation == null)\n\t\t{\n\t\t\tendConvDone = true;\n\t\t\tendDone = true;\n\t\t\tPlayState.instance.disableKeys = true;\n');
				if (endVideo != null) b.add('\t\t\tVideoCutscene.play(Paths.videos(${quoteHx(endVideo)}), CutsceneType.ENDING); // ends the song when it ends\n');
				else b.add('\t\t\tPlayState.instance.endSong(true);\n');
				b.add('\t\t}\n\t}\n');
			}
		}
		b.add('}\n');
		CompatUtil.writeText(exOut + 'scripts/songs/$songId.hxc', b.toString());
		var what:Array<String> = [];
		if (startVideo != null) what.push('video $startVideo before the song');
		if (startConv != null) what.push('dialogue $startConv before the song');
		if (endConv != null) what.push('dialogue $endConv after the song');
		if (endVideo != null) what.push('video $endVideo after the song');
		report.ok('$songId: ' + what.join(', ') + ' (scripts/songs/$songId.hxc)');
	}

	static var madeBoxes:Bool = false;
	static var madeSpeakers:Array<String> = [];

	/** one Psych dialogue file -> a V-Slice conversation; returns its id or null */
	static function convertConversation(songId:String, folder:String, file:String, music:String, report:CompatReport):String
	{
		var path:String = CompatUtil.exists(exRoot + 'data/$folder/$file.json') ? exRoot + 'data/$folder/$file.json' : null;
		if (path == null && CompatUtil.exists(exCache + 'data/$folder/$file.json')) path = exCache + 'data/$folder/$file.json';
		if (path == null)
		{
			report.warn('$songId: its Lua starts the dialogue "$file", but data/$folder/$file.json does not exist (it can\'t show in Psych either).');
			return null;
		}
		var data:Dynamic = CompatUtil.readJson(path);
		var lines:Array<Dynamic> = (data != null && CompatUtil.isArray(data.dialogue)) ? data.dialogue : [];
		if (lines.length < 1) { report.warn('$songId: data/$folder/$file.json has no dialogue lines.'); return null; }
		makeBoxes(report);
		var convId:String = '$exSlug-$songId-' + slugOf(file);
		var entries:Array<Dynamic> = [];
		var lastPortrait:String = null;
		for (l in lines)
		{
			var portrait:String = CompatUtil.str(l.portrait, 'bf');
			var sp:Dynamic = makeSpeaker(portrait, report);
			var angry:Bool = CompatUtil.str(l.boxState, 'normal') == 'angry';
			var side:String = sp != null ? sp.pos : 'right';
			var box:String = '$exSlug-psych-box' + (side == 'left' ? '-left' : (side == 'center' ? '-center' : ''));
			var boxAnim:String = angry ? 'angry' : 'normal';
			// Vortex Engine 0.7.2: like DialogueBoxPsych, the box opens again when the speaker changes and only switches
			// (no opening) when just the mood changes
			var enter:Bool = portrait != lastPortrait;
			lastPortrait = portrait;
			var expression:String = CompatUtil.str(l.expression, 'talk');
			var anims:Array<String> = sp != null ? sp.anims : [];
			if (anims.length > 0 && !anims.contains(expression)) expression = anims[0];
			entries.push({
				speaker: sp != null ? sp.id : '$exSlug-$portrait', speakerAnimation: expression, box: box,
				boxAnimation: enter ? boxAnim + 'Enter' : boxAnim, text: [CompatUtil.str(l.text, '').length > 0 ? CompatUtil.str(l.text, '') : ' '],
				speed: round2(CompatUtil.num(l.speed, 0.05) / 0.05)
			});
		}
		var conv:Dynamic = {
			version: '1.0.0', backdrop: {type: 'solid', color: '#80FFFFFF', fadeTime: 0.5}, outro: {type: 'fade', fadeTime: 0.5}, dialogue: entries
		};
		if (music != null && music.length > 0) conv.music = {asset: music, fadeTime: 2.0, looped: true};
		CompatUtil.writeJson(exOut + 'data/dialogue/conversations/$convId.json', conv);
		return convId;
	}

	/** Psych's speech bubble as two V-Slice dialogue boxes (Psych flips it when the speaker is on the left) */
	static function makeBoxes(report:CompatReport)
	{
		if (CompatUtil.exists(exOut + 'data/dialogue/boxes/$exSlug-psych-box.json')) return;
		var pic:Pic = resolvePicture('speech_bubble', 'dialogue box');
		if (pic == null) { report.warn('dialogue: Psych\'s speech_bubble picture was not found, the dialogue box has no picture.'); return; }
		// Vortex Engine 0.7.2: the text is drawn with Psych's own alphabet letters by a script (V-Slice's box text is a
		// plain font that looked too small and sat in the wrong place); the box's own text is still typed (invisibly)
		// because V-Slice waits for it before the next line
		var alphabet:Pic = resolvePicture('alphabet', 'dialogue text');
		if (alphabet == null) report.warn('dialogue: Psych\'s alphabet picture was not found, the dialogue text uses V-Slice\'s font.');
		var sound:String = null;
		for (src in [exRoot + 'sounds/dialogue.ogg', exCache + 'sounds/dialogue.ogg', 'assets/shared/sounds/dialogue.ogg'])
			if (sound == null && CompatUtil.exists(src))
			{
				sound = '$exSlug-dialogue';
				CompatUtil.makeDirs(exOut + 'sounds/');
				CompatUtil.copyFile(src, exOut + 'sounds/$sound.ogg');
			}
		var table:String = alphabet != null ? alphabetTable() : null;
		for (side in ['right', 'left', 'center'])
		{
			var left:Bool = side == 'left';
			var center:String = side == 'center' ? 'center-' : '';
			var id:String = '$exSlug-psych-box' + (side == 'right' ? '' : '-$side');
			// Psych's speech bubble is always the same picture, so these numbers were measured once: Psych and V-Slice
			// screenshots of the same dialogue, bubble body at x 112-1180, y 440-640 in both.
			// (V-Slice centres the box group at 640, 360 and then adds the offsets.)
			var oy:Float = left ? 10 : 0; // Psych moves the flipped bubble 10 px down (DialogueBoxPsych.updateBoxOffsets)
			// DialogueBoxPsych.updateBoxOffsets: offset (10, 0) normally, (50, 65) angry, (50, 30) centre angry
			var angryOff:Array<Dynamic> = side == 'center' ? [-40, -30] : [-40, -65];
			var zero:Array<Dynamic> = [0, 0];
			CompatUtil.writeJson(exOut + 'data/dialogue/boxes/$id.json', {
				version: '1.1.0', name: 'Psych speech bubble', assetPath: pic.key, isPixel: false, flipX: left, flipY: false,
				offsets: [-531, round2(-11.3 + oy)], scale: 0.924,
				text: {offsets: [79, 143], width: 950, size: 36, color: '#000000', fontFamily: 'VCR OSD Mono', shadowColor: '#00000000', shadowWidth: 0},
				animations: side == 'center' ? [
					{name: 'normalEnter', prefix: 'Speech Bubble Middle Open', offsets: zero, frameRate: 24, looped: false},
					{name: 'normal', prefix: 'speech bubble middle', offsets: zero, frameRate: 24, looped: true},
					{name: 'angryEnter', prefix: 'speech bubble Middle loud open', offsets: angryOff, frameRate: 24, looped: false},
					{name: 'angry', prefix: 'AHH Speech Bubble middle', offsets: angryOff, frameRate: 24, looped: true}
				] : [
					{name: 'normalEnter', prefix: 'Speech Bubble Normal Open', offsets: zero, frameRate: 24, looped: false},
					{name: 'normal', prefix: 'speech bubble normal', offsets: zero, frameRate: 24, looped: true},
					{name: 'angryEnter', prefix: 'speech bubble loud open', offsets: angryOff, frameRate: 24, looped: false},
					{name: 'angry', prefix: 'AHH speech bubble', offsets: angryOff, frameRate: 24, looped: true}
				]
			});
			if (alphabet != null)
			{
				var cls:String = exClassPrefix + 'DialogueBox' + (side == 'right' ? '' : className(side));
				var code:String = BOX_SCRIPT.split('%CLASS%').join(cls).split('%ID%').join(quoteHx(id))
					.split('%ALPHABET%').join(quoteHx(alphabet.key)).split('%SOUND%').join(sound != null ? quoteHx(sound) : 'null')
					.split('%TABLE%').join(table);
				CompatUtil.writeText(exOut + 'scripts/dialogue/$cls.hxc', code);
			}
		}
	}

	/** Psych's alphabet.json (letters allowed, animation names, offsets) as code for the dialogue box script */
	static function alphabetTable():String
	{
		var path:String = null;
		for (p in [exRoot + 'images/alphabet.json', exCache + 'images/alphabet.json', 'assets/shared/images/alphabet.json'])
			if (path == null && CompatUtil.exists(p)) path = p;
		var data:Dynamic = path != null ? CompatUtil.readJson(path) : null;
		var letters:Map<String, Array<Dynamic>> = [];
		var order:Array<String> = [];
		var allowed:String = data != null ? CompatUtil.str(data.allowed, '') : 'abcdefghijklmnopqrstuvwxyz0123456789!?.,\'-';
		for (i in 0...allowed.length)
		{
			var c:String = allowed.charAt(i).toLowerCase();
			if (c == ' ' || letters.exists(c)) continue;
			letters.set(c, [c, 0, 0]);
			order.push(c);
		}
		if (data != null && data.characters != null)
			for (f in Reflect.fields(data.characters))
			{
				var c:String = f.toLowerCase().substr(0, 1);
				if (!letters.exists(c)) continue;
				var d:Dynamic = Reflect.field(data.characters, f);
				var n:Array<Dynamic> = CompatUtil.isArray(d.normal) ? d.normal : [0, 0];
				letters.set(c, [CompatUtil.str(d.animation, c), CompatUtil.num(n[0], 0), CompatUtil.num(n.length > 1 ? n[1] : 0, 0)]);
			}
		if (!letters.exists('?')) { letters.set('?', ['question', 0, 0]); order.push('?'); }
		var b:StringBuf = new StringBuf();
		for (c in order)
		{
			var l:Array<Dynamic> = letters.get(c);
			// Alphabet.isTypeAlphabet: letters get " lowercase" / " uppercase" animations, the rest " normal"
			var code:Int = StringTools.fastCodeAt(c, 0);
			var alpha:Bool = (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || (code >= 192 && code <= 214) || (code >= 216 && code <= 246) || (code >= 248 && code <= 255);
			b.add('\t\tm.set(${quoteHx(c)}, [${quoteHx(l[0])}, ${fmtNum(l[1])}, ${fmtNum(l[2])}, $alpha]);\n');
		}
		return b.toString();
	}

	/** a number as script code (V-Slice's script parser needs 0.5, not .5) */
	static function fmtNum(v:Float):String
	{
		var s:String = Std.string(v);
		if (s.startsWith('.')) s = '0' + s;
		if (s.startsWith('-.')) s = '-0' + s.substr(1);
		return s;
	}

	/**
	 * Vortex Engine 0.7.2: a V-Slice dialogue box that shows Psych's text: Alphabet letters at 0.7 size from (175, 460),
	 * 85 px rows, wrapped after a space past 65% of the screen, 24 px higher for more than 2 rows (DialogueBoxPsych +
	 * Alphabet.createLetters). The box's own text keeps typing invisibly; a letter shows once its character is typed.
	 */
	static final BOX_SCRIPT:String = '// Made by the Vortex Engine V-Slice Converter: Psych dialogue text (Alphabet letters, placed like DialogueBoxPsych)
import funkin.play.cutscene.dialogue.DialogueBox;
import funkin.Paths;
import funkin.audio.FunkinSound;
import flixel.FlxSprite;
import haxe.ds.StringMap;
import StringTools;

class %CLASS% extends DialogueBox
{
	var psychLetters:Array<Dynamic> = [];
	var psychShown:Int = 0;
	var psychRows:Int = 0;
	var psychLine:String = null;
	var psychLastX:Float = -99999;
	var psychLastY:Float = -99999;
	var psychTyped:Int = -1;
	var psychTable:StringMap = null;
	var psychAtlas:Dynamic = null;

	public function new()
	{
		super(%ID%);
	}

	function psychLetterTable():StringMap
	{
		var m:StringMap = new StringMap();
%TABLE%		return m;
	}

	public override function onCreate(event)
	{
		super.onCreate(event);
		// revived boxes were cleared: start with no letters
		psychLetters = [];
		psychShown = 0;
		psychLine = null;
		psychTyped = -1;
		if (textDisplay != null)
		{
			textDisplay.visible = false;
			var snd:String = %SOUND%;
			if (snd != null) textDisplay.sounds = [FunkinSound.load(Paths.sound(snd), 1)];
		}
	}

	public override function setText(newText:String)
	{
		super.setText(newText);
		psychLayout(newText);
	}

	function psychLayout(txt:String)
	{
		if (psychTable == null) psychTable = psychLetterTable();
		if (psychAtlas == null)
		{
			psychAtlas = Paths.getSparrowAtlas(%ALPHABET%);
			if (psychAtlas == null) return;
			psychAtlas.parent.destroyOnNoUse = false;
			psychAtlas.parent.persist = true;
		}
		psychLine = txt;
		var used:Int = 0;
		var xPos:Float = 0;
		var rows:Int = 0;
		var spaces:Int = 0;
		var i:Int = 0;
		while (i < txt.length)
		{
			var c:String = txt.charAt(i);
			var at:Int = i;
			i++;
			if (c == "\\\\" && i < txt.length && txt.charAt(i) == "n") { i++; c = "\\n"; }
			if (c == "\\n")
			{
				xPos = 0;
				rows++;
				continue;
			}
			if (c == " ") spaces++;
			var low:String = c.toLowerCase();
			if (!psychTable.exists(low)) continue;
			if (spaces > 0)
			{
				xPos += 28 * spaces * 0.7;
				if (xPos >= 832) { xPos = 0; rows++; }
			}
			spaces = 0;
			var d:Array<Dynamic> = psychTable.get(low);
			var anim:String = d[0] + (d[3] ? (low != c ? " uppercase" : " lowercase") : " normal");
			var spr:FlxSprite = null;
			if (used < psychLetters.length) spr = psychLetters[used][0];
			else
			{
				spr = new FlxSprite(0, 0);
				spr.frames = psychAtlas;
				spr.antialiasing = true;
				spr.visible = false;
				add(spr);
				psychLetters.push([spr, 0, 0, 0]);
			}
			if (spr.animation.getByName(anim) == null) spr.animation.addByPrefix(anim, anim, 24);
			if (spr.animation.getByName(anim) == null)
			{
				anim = "question normal";
				if (spr.animation.getByName(anim) == null) spr.animation.addByPrefix(anim, anim, 24);
			}
			spr.animation.play(anim, true);
			spr.scale.set(0.7, 0.7);
			spr.updateHitbox();
			spr.offset.x += d[1] * 0.7;
			spr.offset.y += d[2] * 0.7 - (110 * 0.7 - spr.height);
			var entry:Array<Dynamic> = psychLetters[used];
			entry[1] = at;
			entry[2] = xPos;
			entry[3] = rows * 85 * 0.7;
			used++;
			xPos += spr.width + (d[1] + 2) * 0.7;
		}
		if (used > 0) rows++;
		for (j in used...psychLetters.length) psychLetters[j][0].visible = false;
		psychShown = used;
		psychRows = rows;
		psychTyped = -1;
		psychPlace();
	}

	function psychPlace()
	{
		psychLastX = this.x;
		psychLastY = this.y;
		var top:Float = psychRows > 2 ? 436 : 460;
		for (j in 0...psychShown)
		{
			var e:Array<Dynamic> = psychLetters[j];
			e[0].x = 175 + e[2];
			e[0].y = top + e[3];
		}
	}

	public override function onUpdate(event)
	{
		super.onUpdate(event);
		if (psychLine == null) return;
		// the box moves for angry / opening animations; Psych\'s text does not
		if (this.x != psychLastX || this.y != psychLastY) psychPlace();
		var typed:Int = textDisplay != null ? textDisplay.text.length : 999999;
		if (typed == psychTyped) return;
		psychTyped = typed;
		for (j in 0...psychShown)
		{
			var e:Array<Dynamic> = psychLetters[j];
			e[0].visible = e[1] < typed;
		}
	}
}
';

	/** a Psych dialogue portrait (images/dialogue/<name>.json) -> V-Slice speaker, placed where Psych puts it */
	static function makeSpeaker(portrait:String, report:CompatReport):Dynamic
	{
		var id:String = '$exSlug-' + slugOf(portrait);
		var path:String = null;
		// Vortex Engine 0.7.2: Psych's own portraits (gf, bf) too, like Psych falls back to them
		for (dir in [exRoot, exCache, 'assets/shared/']) if (path == null && CompatUtil.exists(dir + 'images/dialogue/$portrait.json')) path = dir + 'images/dialogue/$portrait.json';
		if (path == null && CompatUtil.exists('assets/shared/images/dialogue/bf.json'))
		{
			// DialogueCharacter.reloadCharacterJson shows bf when a portrait doesn't exist
			report.warn('dialogue: portrait "$portrait" (images/dialogue/$portrait.json) was not found; Psych shows bf instead, so the converted mod does too.');
			path = 'assets/shared/images/dialogue/bf.json';
		}
		if (path == null) { report.warn('dialogue: portrait "$portrait" (images/dialogue/$portrait.json) was not found.'); return null; }
		var d:Dynamic = CompatUtil.readJson(path);
		if (d == null) return null;
		var anims:Array<Dynamic> = CompatUtil.isArray(d.animations) ? d.animations : [];
		var pos:String = CompatUtil.str(d.dialogue_pos, 'left');
		var out:Dynamic = {id: id, pos: pos, anims: [for (a in anims) CompatUtil.str(a.anim, 'talk')]};
		if (madeSpeakers.contains(id)) return out;
		madeSpeakers.push(id);
		var pic:Pic = resolvePicture('dialogue/' + CompatUtil.str(d.image, portrait), 'dialogue portrait "$portrait"');
		if (pic == null) { report.warn('dialogue: picture images/dialogue/${d.image}.png for portrait "$portrait" was not found.'); return out; }
		var frames:Array<AtlasFrame> = pic.xml != null ? readAtlas(pic.xml) : [];
		var W1:Float = frames.length > 0 ? frames[0].w : 0, H1:Float = frames.length > 0 ? frames[0].h : 0;
		var s:Float = 0.7 * CompatUtil.num(d.scale, 1);
		var p:Array<Dynamic> = CompatUtil.isArray(d.position) ? d.position : [0, 0];
		// DialogueBoxPsych.spawnCharacters: left at -60, right at 1280 - width - 100, center at 640 - width / 2; y 60
		var X:Float = switch (pos) { case 'right': 1280 - W1 * s - 100; case 'center': 640 - W1 * s / 2; default: -60; };
		X += CompatUtil.num(p[0], 0);
		var Y:Float = 60 + CompatUtil.num(p[1], 0);
		// V-Slice centres the speaker, then adds its offsets; Psych's offsets are subtracted, V-Slice's added
		var gx:Float = X + W1 * (1 - s) / 2 - (1280 - W1) / 2, gy:Float = Y + H1 * (1 - s) / 2 - (720 - H1) / 2;
		CompatUtil.writeJson(exOut + 'data/dialogue/speakers/$id.json', {
			version: '1.0.0', name: portrait, assetPath: pic.key, flipX: false, flipY: false, isPixel: CompatUtil.bool(d.no_antialiasing, false),
			scale: round2(s), offsets: [round2(gx), round2(gy)],
			// Vortex Engine 0.7.2: DialogueCharacter.playAnim plays the talking loop with loop_offsets, but the idle animation
			// with idle_offsets when there is no loop or it is the idle one; V-Slice has one animation per name, so: the loop
			// (talking) with its own offsets, or the idle with its own (they can be hundreds of pixels apart)
			animations: [for (a in anims) {
				var loop:String = CompatUtil.str(a.loop_name, ''), idle:String = CompatUtil.str(a.idle_name, '');
				var useIdle:Bool = loop.length < 1 || loop == idle;
				var o:Dynamic = useIdle ? a.idle_offsets : a.loop_offsets;
				var lo:Array<Dynamic> = CompatUtil.isArray(o) ? o : [0, 0];
				{name: CompatUtil.str(a.anim, 'talk'), prefix: useIdle ? idle : loop, frameRate: 24, looped: true,
					offsets: [-CompatUtil.num(lo[0], 0), -CompatUtil.num(lo.length > 1 ? lo[1] : 0, 0)]};
			}]
		});
		return out;
	}

	/** pictures wider or taller than most phones can load */
	static function checkTextures(out:String, report:CompatReport)
	{
		var big:Array<String> = [];
		for (file in CompatUtil.walk(out + 'images/'))
		{
			if (!file.toLowerCase().endsWith('.png')) continue;
			try
			{
				var input = sys.io.File.read(out + 'images/' + file, true);
				var b:haxe.io.Bytes = input.read(24);
				input.close();
				var w:Int = (b.get(16) << 24) | (b.get(17) << 16) | (b.get(18) << 8) | b.get(19);
				var h:Int = (b.get(20) << 24) | (b.get(21) << 16) | (b.get(22) << 8) | b.get(23);
				if (w > MOBILE_MAX_TEXTURE || h > MOBILE_MAX_TEXTURE) big.push('images/$file (${w}x$h)');
			}
			catch (e:Dynamic) {}
		}
		if (big.length > 0)
			report.warn('${big.length} pictures are bigger than ${MOBILE_MAX_TEXTURE}x$MOBILE_MAX_TEXTURE, the largest many phones can load (they may show up black or missing on mobile): ' + big.slice(0, 10).join(', ') + (big.length > 10 ? '...' : ''));
		else report.ok('mobile: every picture is at most ${MOBILE_MAX_TEXTURE}x$MOBILE_MAX_TEXTURE');
	}
}

typedef Pic = {key:String, xml:String, ?png:String, ?w:Int, ?h:Int, ?privateCopy:Bool};
typedef AtlasFrame = {name:String, w:Float, h:Float};
