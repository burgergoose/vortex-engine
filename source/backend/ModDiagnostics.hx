package backend;

/**
 * Vortex Engine addition.
 *
 * Writes vortex_mods_log.txt next to the .exe every time the game starts: where it is looking for mods,
 * which mod folders it found, whether each is enabled, and how many weeks / songs / characters / stages /
 * events each one contains. If a mod "doesn't show up", this file says why in plain words.
 */
class ModDiagnostics
{
	public static function write():Void
	{
		#if (MODS_ALLOWED && sys)
		try
		{
			var out:Array<String> = [];
			out.push('Vortex Engine - mod report (' + Date.now().toString() + ')');
			out.push('Working folder : ' + Sys.getCwd());
			out.push('Mods folder    : ' + Sys.getCwd() + 'mods' + (FileSystem.exists('mods') ? '' : '   <-- DOES NOT EXIST, create it next to the .exe'));
			out.push('');

			var all:Array<String> = Mods.getModDirectories();
			if (all.length < 1)
				out.push('No mod folders found. A mod is a folder inside mods/ (e.g. mods/My-Mod/songs, mods/My-Mod/data ...).');

			var list = Mods.parseList();
			for (mod in all)
			{
				var enabled:Bool = list.enabled.contains(mod);
				var base:String = Paths.mods(mod + '/');
				out.push((enabled ? '[ON ] ' : '[OFF] ') + mod + (enabled ? '' : '   <-- turned off in the Mods menu, its content is hidden'));

				var weeks:Int = countFiles(base + 'weeks', '.json');
				var charts:Int = countSongFolders(base + 'data');
				var audio:Int = countSongFolders(base + 'songs');
				out.push('       weeks: $weeks | song charts (data/*): $charts | song audio folders (songs/*): $audio | characters: '
					+ countFiles(base + 'characters', '.json') + ' | stages: ' + countFiles(base + 'stages', '.json')
					+ ' | events: ' + countFiles(base + 'custom_events', '.txt'));

				if (audio > 0)
					for (song in FileSystem.readDirectory(base + 'songs'))
					{
						var dir:String = base + 'songs/' + song;
						if (!FileSystem.isDirectory(dir)) continue;
						var hasInst:Bool = FileSystem.exists(dir + '/Inst.ogg') || FileSystem.exists(dir + '/Inst.wav');
						out.push('         song "$song": ' + (hasInst ? 'Inst OK' : 'NO Inst.ogg  <-- the song would end instantly'));
						if (FileSystem.exists(dir + '/Inst.mp3') && !hasInst)
							out.push('           (found Inst.mp3 - mp3 is not supported, convert it to .ogg)');
					}
			}
			File.saveContent('vortex_mods_log.txt', out.join('\n') + '\n');
		}
		catch (e:Dynamic) {}
		#end
	}

	#if (MODS_ALLOWED && sys)
	static function countFiles(dir:String, ext:String):Int
	{
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return 0;
		var n:Int = 0;
		for (f in FileSystem.readDirectory(dir))
			if (f.toLowerCase().endsWith(ext) && !FileSystem.isDirectory(dir + '/' + f)) n++;
		return n;
	}

	static function countSongFolders(dir:String):Int
	{
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return 0;
		var n:Int = 0;
		for (f in FileSystem.readDirectory(dir))
			if (FileSystem.isDirectory(dir + '/' + f)) n++;
		return n;
	}
	#end
}
