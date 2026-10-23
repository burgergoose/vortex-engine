package backend.compat;

typedef Detection = {
	var engine:String;   // 'psych', 'vslice', 'codename', 'forever', 'fpsplus', 'unknown'
	var label:String;    // shown to people
	var version:String;  // best guess, '' when there's nothing to go on
	var translate:Bool;  // true when the mod needs Psych-format copies in the compat cache
	var hints:Array<String>;
}

/**
 * VORTEX ENGINE ADDITION - works out which engine a mod was made for, from the files it has (engines don't label their
 * mods), and lists scripts that need attention. A guess is always reported as a guess.
 */
class CompatScan
{
	public static function detect(root:String):Detection
	{
		var hints:Array<String> = [];
		var d:Detection = {engine: 'unknown', label: 'Unknown', version: '', translate: false, hints: hints};

		// --- V-Slice (Polymod) ---
		var vsMeta:Dynamic = CompatUtil.readJson(root + '_polymod_meta.json');
		var vsSongs:Int = 0, vsVersion:String = '';
		for (folder in CompatUtil.list(root + 'data/songs/'))
			for (f in CompatUtil.list(root + 'data/songs/$folder/'))
				if (f.endsWith('-metadata.json') && f.indexOf('-metadata-') < 0)
				{
					vsSongs++;
					if (vsVersion.length < 1)
					{
						var m:Dynamic = CompatUtil.readJson(root + 'data/songs/$folder/$f');
						if (m != null && m.version != null) vsVersion = 'song format ' + Std.string(m.version);
					}
				}
		if (vsMeta != null || vsSongs > 0 || CompatUtil.isDir(root + 'data/levels'))
		{
			d.engine = 'vslice'; d.label = 'V-Slice (Friday Night Funkin\' 0.3+)'; d.translate = true;
			var parts:Array<String> = [];
			if (vsMeta != null && vsMeta.api_version != null) parts.push('Polymod api_version ' + vsMeta.api_version);
			if (vsVersion.length > 0) parts.push(vsVersion);
			d.version = parts.join(', ');
			if (vsMeta != null) hints.push('_polymod_meta.json: "' + CompatUtil.str(vsMeta.title, '?') + '"');
			hints.push('$vsSongs songs with V-Slice metadata');
			return d;
		}

		// --- Codename Engine ---
		var cneCharts:Int = 0;
		for (folder in CompatUtil.list(root + 'songs/'))
			if (CompatUtil.isDir(root + 'songs/$folder/charts')) cneCharts++;
		var cneXml:Bool = CompatUtil.list(root + 'data/characters/').filter(function(f) return f.endsWith('.xml')).length > 0
			|| CompatUtil.list(root + 'data/stages/').filter(function(f) return f.endsWith('.xml')).length > 0
			|| CompatUtil.isDir(root + 'data/weeks/weeks');
		if (cneCharts > 0 || cneXml)
		{
			d.engine = 'codename'; d.label = 'Codename Engine'; d.translate = true;
			d.version = 'codenameChart format';
			hints.push('$cneCharts songs with songs/<song>/charts/');
			if (cneXml) hints.push('XML characters / stages / weeks');
			return d;
		}

		// --- FPS Plus: Psych-like charts kept in data/songs/<song>/<song>.json ---
		var fpsSongs:Int = 0;
		for (folder in CompatUtil.list(root + 'data/songs/'))
			if (CompatUtil.exists(root + 'data/songs/$folder/$folder.json')) fpsSongs++;
		if (fpsSongs > 0)
		{
			d.engine = 'fpsplus'; d.label = 'FPS Plus'; d.translate = true;
			hints.push('$fpsSongs charts in data/songs/<song>/<song>.json');
			return d;
		}

		// --- Forever Engine: base-game charts kept next to the audio in songs/<song>/ ---
		var feSongs:Int = 0;
		for (folder in CompatUtil.list(root + 'songs/'))
		{
			var dir:String = root + 'songs/$folder/';
			if (CompatUtil.list(dir).filter(function(f) return f.endsWith('.json') && f.startsWith(folder)).length > 0
				&& !CompatUtil.isDir(root + 'data/$folder')) feSongs++;
		}
		if (feSongs > 0)
		{
			d.engine = 'forever'; d.label = 'Forever Engine'; d.translate = true;
			hints.push('$feSongs charts kept in songs/<song>/ next to the audio');
			return d;
		}

		// --- Psych Engine family (0.4 - 1.0 and forks like NightmareVision) ---
		var charts:Int = 0, v1:Int = 0, legacyCharts:Int = 0;
		for (folder in CompatUtil.list(root + 'data/'))
		{
			var f:String = root + 'data/$folder/$folder.json';
			if (!CompatUtil.exists(f)) continue;
			charts++;
			var raw:String = CompatUtil.readText(f);
			if (raw != null && raw.indexOf('"psych_v1') > -1) v1++; else legacyCharts++;
		}
		var vocalsFile:Bool = false;
		for (c in CompatUtil.list(root + 'characters/'))
		{
			var raw:String = CompatUtil.readText(root + 'characters/$c');
			if (raw != null && raw.indexOf('"vocals_file"') > -1) { vocalsFile = true; break; }
		}
		var stageObjects:Bool = false;
		for (s in CompatUtil.list(root + 'stages/'))
		{
			var raw:String = CompatUtil.readText(root + 'stages/$s');
			if (raw != null && raw.indexOf('"objects"') > -1) { stageObjects = true; break; }
		}
		if (charts > 0 || CompatUtil.exists(root + 'pack.json') || CompatUtil.isDir(root + 'weeks') || CompatUtil.isDir(root + 'characters'))
		{
			d.engine = 'psych'; d.label = 'Psych Engine'; d.translate = false;
			if (v1 > 0 || stageObjects) d.version = '1.0 (psych_v1 charts / stage objects)';
			else if (vocalsFile) d.version = '0.7.x (characters with vocals_file)';
			else if (charts > 0) d.version = '0.6.x or 0.7.x (pre-1.0 chart format)';
			if (charts > 0) hints.push('$charts charts ($v1 in Psych 1.0 format, $legacyCharts older; older charts are converted when loaded)');
			return d;
		}
		return d;
	}

	/** Lists scripts and what they need. Lua is checked for old Psych class names (which Vortex maps). */
	public static function scanScripts(root:String, report:CompatReport, engine:String):Void
	{
		var lua:Int = 0, legacyNames:Int = 0, deprecated:Int = 0;
		var hx:Array<String> = [];
		var funkinHx:Int = 0;
		for (file in CompatUtil.walk(root, 8000))
		{
			var low:String = file.toLowerCase();
			if (low.startsWith('images/') || low.startsWith('songs/') && !low.endsWith('.hx') && !low.endsWith('.lua')) continue;
			if (low.endsWith('.lua'))
			{
				lua++;
				var src:String = CompatUtil.readText(root + file);
				if (src == null) continue;
				if (~/(get|set)PropertyFromClass\(\s*['"](ClientPrefs|PlayState|Conductor|MusicBeatState|CoolUtil|GameOverSubstate|PauseSubState)['"]/.match(src)) legacyNames++;
				if (~/luaSpriteMakeGraphic|luaSpriteAddAnimationByPrefix|luaSpritePlayAnimation|setLuaSpriteCamera|setLuaSpriteScrollFactor|objectPlayAnimation|characterPlayAnim/.match(src)) deprecated++;
			}
			else if (low.endsWith('.hx') || low.endsWith('.hxc') || low.endsWith('.hxs') || low.endsWith('.hscript'))
			{
				hx.push(file);
				var src:String = CompatUtil.readText(root + file);
				if (src != null && src.indexOf('funkin.') > -1) funkinHx++;
			}
		}
		if (lua > 0)
		{
			if (engine == 'psych' || engine == 'fpsplus' || engine == 'forever') report.ok('$lua Lua scripts (Psych Lua API)');
			else report.warn('$lua Lua scripts found; ${engineName(engine)} does not run Lua, so they are probably for another engine. Vortex runs them with the Psych Lua API.');
			if (legacyNames > 0) report.note('$legacyNames Lua scripts use Psych 0.6-style class names (ClientPrefs, PlayState...). Vortex maps those to the current classes when the script runs.');
			if (deprecated > 0) report.note('$deprecated Lua scripts use old Psych functions (luaSpriteMakeGraphic and similar); Vortex still has them.');
		}
		if (hx.length > 0)
		{
			var shown:String = hx.slice(0, 12).join(', ') + (hx.length > 12 ? ' and ${hx.length - 12} more' : '');
			switch (engine)
			{
				case 'psych':
					if (funkinHx > 0) report.needs('$funkinHx HScript files use funkin.* classes (NightmareVision / Codename style), which Vortex does not have: $shown');
					else report.note('${hx.length} HScript files: Psych 0.7 / 1.0 HScript mostly works in Vortex; check imports if one fails (errors go to vortex_script_log.txt).');
				default:
					report.needs('${hx.length} ${engineName(engine)} script files call that engine\'s own Haxe classes and do not run in Vortex. Port them to Lua or Psych HScript: $shown');
			}
		}
	}

	public static function engineName(engine:String):String
		return switch (engine)
		{
			case 'vslice': 'V-Slice';
			case 'codename': 'Codename Engine';
			case 'forever': 'Forever Engine';
			case 'fpsplus': 'FPS Plus';
			case 'psych': 'Psych Engine';
			default: 'this engine';
		}
}
