package backend.compat;

/**
 * VORTEX ENGINE ADDITION - FPS Plus and Forever Engine mods use the base-game chart format (sections with
 * sectionNotes, like Psych 0.6), only kept in different folders:
 *   FPS Plus:       data/songs/<song>/<song>.json (+ -easy / -hard, events.json)
 *   Forever Engine: songs/<song>/<song>.json (next to Inst.ogg / Voices.ogg)
 * The charts are copied to data/<song>/<song>.json in the compatibility cache; Psych's own old-chart conversion
 * then runs when the song loads. Characters / stages of both engines are Haxe code and need porting.
 */
class LegacyImport
{
	public static function run(root:String, out:String, engine:String, report:CompatReport):Void
	{
		var found:Array<{id:String, dir:String}> = [];
		if (engine == 'fpsplus')
			for (folder in CompatUtil.list(root + 'data/songs/')) found.push({id: folder, dir: root + 'data/songs/$folder/'});
		else
			for (folder in CompatUtil.list(root + 'songs/')) found.push({id: folder, dir: root + 'songs/$folder/'});

		var weekSongs:Array<Dynamic> = [];
		for (s in found)
		{
			var key:String = Paths.formatToSongPath(s.id);
			var base:String = s.dir + '${s.id}.json';
			var chosen:String = null;
			for (cand in [base, s.dir + '${s.id}-normal.json', s.dir + '${s.id}-hard.json', s.dir + '${s.id}-easy.json'])
				if (CompatUtil.exists(cand)) { chosen = cand; break; }
			if (chosen == null) continue;
			var err:Array<String> = [];
			var chart:Dynamic = CompatUtil.readJson(chosen, err);
			if (chart == null) { report.error('${s.id}: ${CompatUtil.fileName(chosen)} is not valid JSON (${err.join('')})'); continue; }
			var data:Dynamic = (chart.song != null && Type.typeof(chart.song) == TObject) ? chart.song : chart;
			if (!CompatUtil.isArray(data.notes)) { report.error('${s.id}: ${CompatUtil.fileName(chosen)} has no "notes" sections'); continue; }

			// events kept in a format Psych can't read are moved aside instead of being dropped silently
			if (data.events != null && !isPsychEvents(data.events))
			{
				Reflect.setField(data, 'vortexOriginalEvents', data.events);
				Reflect.deleteField(data, 'events');
				report.needs('${s.id}: its events use the ${CompatScan.engineName(engine)} format, which Vortex can\'t read. They were kept in the chart as "vortexOriginalEvents" and need to be re-added in the Chart Editor.');
			}
			var evFile:String = s.dir + 'events.json';
			if (CompatUtil.exists(evFile))
			{
				var ev:Dynamic = CompatUtil.readJson(evFile);
				var evData:Dynamic = (ev != null && ev.song != null && Type.typeof(ev.song) == TObject) ? ev.song : ev;
				if (evData != null && evData.events != null && isPsychEvents(evData.events)) CompatUtil.writeJson(out + 'data/$key/events.json', ev);
				else report.needs('${s.id}: events.json is not in the Psych format and was not used; re-add those events in the Chart Editor.');
			}
			if (CompatUtil.exists(s.dir + '${s.id}-hard.json') && chosen != s.dir + '${s.id}-hard.json')
				report.note('${s.id}: imported ${CompatUtil.fileName(chosen)}; Vortex has one difficulty, the other chart files were not imported.');

			if (data.song == null) data.song = s.id;
			if (Paths.formatToSongPath(Std.string(data.song)) != key) data.song = s.id;
			Reflect.setField(data, 'vortexSource', CompatScan.engineName(engine) + ' chart ' + CompatUtil.fileName(chosen));
			CompatUtil.writeJson(out + 'data/$key/$key.json', {song: data});

			var audioDir:String = root + 'songs/${s.id}/';
			if (!CompatUtil.exists(audioDir + 'Inst.ogg') && !CompatUtil.exists(audioDir + 'Inst.wav'))
				report.error('${s.id}: songs/${s.id}/Inst.ogg is missing, the song will show the "Inst not found" screen.');
			for (c in [data.player1, data.player2, data.gfVersion != null ? data.gfVersion : data.player3])
				if (c != null && !CompatUtil.exists(root + 'characters/$c.json') && !CompatUtil.exists('assets/shared/characters/$c.json'))
					report.needs('${s.id}: character "$c" is ${CompatScan.engineName(engine)} Haxe code, not a file; make it in the Character Editor (Boyfriend is shown until then).');
			var count:Int = 0;
			for (sec in (data.notes : Array<Dynamic>)) if (sec != null && CompatUtil.isArray(sec.sectionNotes)) count += sec.sectionNotes.length;
			report.ok('song ${s.id}: $count notes (${CompatUtil.fileName(chosen)})');
			weekSongs.push([s.id, CompatUtil.str(data.player2, 'face'), [146, 113, 253]]);
		}
		if (weekSongs.length > 0)
		{
			var key:String = engine + '-songs';
			CompatUtil.writeJson(out + 'weeks/$key.json', {
				songs: weekSongs, weekCharacters: ['', 'bf', 'gf'], weekBackground: '', weekBefore: '',
				storyName: CompatScan.engineName(engine) + ' songs', weekName: CompatScan.engineName(engine) + ' songs',
				startUnlocked: true, hiddenUntilUnlocked: false, hideStoryMode: true, hideFreeplay: false, difficulties: ''
			});
			CompatUtil.writeText(out + 'weeks/weekList.txt', key);
			report.note('${CompatScan.engineName(engine)} keeps its weeks in Haxe code, so the songs are listed in Freeplay only. Make Story Mode weeks with the Week Editor.');
		}
		report.needs('${CompatScan.engineName(engine)} stages are Haxe code; songs use the default stage until you make one in the Stage Editor.');
		CompatScan.scanScripts(root, report, engine);
	}

	static function isPsychEvents(events:Dynamic):Bool
	{
		if (!CompatUtil.isArray(events)) return false;
		for (e in (events : Array<Dynamic>))
			if (!CompatUtil.isArray(e) || e.length < 2 || !CompatUtil.isArray(e[1])) return false;
		return true;
	}
}
