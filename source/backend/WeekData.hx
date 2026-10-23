package backend;

import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import haxe.Json;

typedef WeekFile =
{
	// JSON variables
	var songs:Array<Dynamic>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;
	@:optional var bannerImage:String; // Vortex Engine 0.6: Story Mode banner other than storymenu/<week>.png (V-Slice titleAsset)
}

class WeekData {
	public static var weeksLoaded:Map<String, WeekData> = new Map<String, WeekData>();
	public static var weeksList:Array<String> = [];
	public var folder:String = '';

	// JSON variables
	public var songs:Array<Dynamic>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var difficulties:String;
	public var bannerImage:String = null; // Vortex Engine 0.6

	public var fileName:String;

	public static function createWeekFile():WeekFile {
		var weekFile:WeekFile = {
			songs: [["Bopeebo", "face", [146, 113, 253]], ["Fresh", "face", [146, 113, 253]], ["Dad Battle", "face", [146, 113, 253]]],
			#if BASE_GAME_FILES
			weekCharacters: ['dad', 'bf', 'gf'],
			#else
			weekCharacters: ['bf', 'bf', 'gf'],
			#end
			weekBackground: 'stage',
			weekBefore: 'tutorial',
			storyName: 'Your New Week',
			weekName: 'Custom Week',
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: false,
			hideFreeplay: false,
			difficulties: ''
		};
		return weekFile;
	}

	// HELP: Is there any way to convert a WeekFile to WeekData without having to put all variables there manually? I'm kind of a noob in haxe lmao
	public function new(weekFile:WeekFile, fileName:String) {
		// here ya go - MiguelItsOut
		for (field in Reflect.fields(weekFile))
			if(Reflect.fields(this).contains(field)) // Reflect.hasField() won't fucking work :/
				Reflect.setProperty(this, field, Reflect.getProperty(weekFile, field));

		this.fileName = fileName;
	}

	public static function reloadWeekFiles(isStoryMode:Null<Bool> = false)
	{
		weeksList = [];
		weeksLoaded.clear();
		#if MODS_ALLOWED
		// Vortex Engine: translate mods made for other engines (cheap when nothing changed; see backend/compat)
		try { backend.compat.CompatLayer.refreshAll(); }
		catch (e:Dynamic) { trace('Mod compatibility check failed: $e'); }
		var directories:Array<String> = [Paths.mods(), Paths.getSharedPath()];
		var originalLength:Int = directories.length;

		for (mod in Mods.parseList().enabled)
			directories.push(Paths.mods(mod + '/'));
		#else
		var directories:Array<String> = [Paths.getSharedPath()];
		var originalLength:Int = directories.length;
		#end

		var sexList:Array<String> = CoolUtil.coolTextFile(Paths.getSharedPath('weeks/weekList.txt'));
		for (i in 0...sexList.length) {
			for (j in 0...directories.length) {
				var fileToCheck:String = directories[j] + 'weeks/' + sexList[i] + '.json';
				if(!weeksLoaded.exists(sexList[i])) {
					var week:WeekFile = getWeekFile(fileToCheck);
					if(week != null) {
						var weekFile:WeekData = new WeekData(week, sexList[i]);

						#if MODS_ALLOWED
						if(j >= originalLength) {
							weekFile.folder = directories[j].substring(Paths.mods().length, directories[j].length-1);
						}
						#end

						if(weekFile != null && (isStoryMode == null || (isStoryMode && !weekFile.hideStoryMode) || (!isStoryMode && !weekFile.hideFreeplay))) {
							weeksLoaded.set(sexList[i], weekFile);
							weeksList.push(sexList[i]);
						}
					}
				}
			}
		}

		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i] + 'weeks/';
			if(FileSystem.exists(directory)) {
				var listOfWeeks:Array<String> = CoolUtil.coolTextFile(directory + 'weekList.txt');
				for (daWeek in listOfWeeks)
				{
					var path:String = directory + daWeek + '.json';
					if(FileSystem.exists(path))
					{
						addWeek(daWeek, path, directories[i], i, originalLength, isStoryMode);
					}
				}

				for (file in FileSystem.readDirectory(directory))
				{
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						addWeek(file.substr(0, file.length - 5), path, directories[i], i, originalLength, isStoryMode);
					}
				}
			}
		}

		// Vortex Engine: weeks of mods translated from other engines (vortex_compat/<mod>/weeks/)
		for (entry in backend.compat.CompatLayer.cachedWeeks())
		{
			var key:String = entry[1];
			if (weeksLoaded.exists(key)) continue;
			var week:WeekFile = getWeekFile(entry[2]);
			if (week == null) continue;
			var weekData:WeekData = new WeekData(week, key);
			weekData.folder = entry[0];
			var story:Bool = (isStoryMode != null) ? isStoryMode : PlayState.isStoryMode;
			if ((story && !weekData.hideStoryMode) || (!story && !weekData.hideFreeplay))
			{
				weeksLoaded.set(key, weekData);
				weeksList.push(key);
			}
		}

		// Vortex Engine: mods that have songs but no week file
		try { addUnlistedModSongs(isStoryMode); }
		catch (e:Dynamic) { trace('addUnlistedModSongs failed: $e'); }

		// Vortex Engine 0.6: an enabled mod can hide the base game's weeks with "hideBaseGameWeeks" in its pack.json
		// (true = all of them, or a list like ["tutorial", "week1"])
		try { hideBaseGameWeeks(); }
		catch (e:Dynamic) { trace('hideBaseGameWeeks failed: $e'); }
		#end
	}

	#if MODS_ALLOWED
	/**
	 * Vortex Engine addition.
	 *
	 * Vanilla Psych only shows a mod's songs in Freeplay / Story Mode if the mod ships a weeks/<name>.json made
	 * with the Week Editor -- a mod with a chart (data/<song>/<song>.json) and audio but no week file is simply
	 * invisible, which looks exactly like "my mod isn't being loaded". For every enabled mod, any song folder
	 * inside mods/<mod>/data/ that has a chart and is NOT already listed by one of that mod's weeks is collected
	 * into one automatic week named after the mod. A real week file always wins; nothing here changes how
	 * existing weeks load.
	 */
	private static function addUnlistedModSongs(isStoryMode:Null<Bool>):Void
	{
		for (mod in Mods.parseList().enabled)
		{
			var dataDir:String = Paths.mods(mod + '/data/');
			if (!FileSystem.exists(dataDir) || !FileSystem.isDirectory(dataDir)) continue;

			// Vortex Engine: read EVERY week file of the mod. Using only the loaded weeks missed weeks hidden from the
			// current menu (hideStoryMode / hideFreeplay), so their songs ended up in the automatic week too.
			var claimed:Array<String> = [];
			for (weeksDir in [Paths.mods(mod + '/weeks/'), Paths.mods('weeks/')])
			{
				if (!FileSystem.exists(weeksDir) || !FileSystem.isDirectory(weeksDir)) continue;
				for (file in FileSystem.readDirectory(weeksDir))
				{
					if (!file.toLowerCase().endsWith('.json')) continue;
					try
					{
						var wf:Dynamic = tjson.TJSON.parse(File.getContent(weeksDir + file));
						var songs:Array<Dynamic> = (wf != null) ? wf.songs : null;
						if (songs != null) for (song in songs) if (song != null && song[0] != null) claimed.push(Paths.formatToSongPath(Std.string(song[0])));
					}
					catch (e:Dynamic) {}
				}
			}

			var found:Array<Dynamic> = [];
			var names:Array<String> = FileSystem.readDirectory(dataDir);
			names.sort(function(a:String, b:String) return (a.toLowerCase() < b.toLowerCase()) ? -1 : 1);
			for (name in names)
			{
				var songDir:String = dataDir + name;
				if (!FileSystem.isDirectory(songDir)) continue;
				if (claimed.contains(Paths.formatToSongPath(name))) continue;

				var chartFile:String = null;
				var files:Array<String> = FileSystem.readDirectory(songDir);
				for (f in files)
					if (f.endsWith('.json') && f != 'events.json' && (f == name + '.json' || f.startsWith(name + '-')))
					{
						if (chartFile == null || f == name + '.json') chartFile = f;
					}
				if (chartFile == null) continue;
				// Vortex Engine: only real songs (a chart AND audio), not data folders like menus or cutscenes
				var audioDir:String = Paths.mods(mod + '/songs/' + name + '/');
				if (!FileSystem.exists(audioDir + 'Inst.ogg') && !FileSystem.exists(audioDir + 'Inst.wav')) continue;

				var icon:String = 'face';
				try
				{
					var chart:Dynamic = tjson.TJSON.parse(File.getContent(songDir + '/' + chartFile));
					var data:Dynamic = (chart.song != null && !Std.isOfType(chart.song, String)) ? chart.song : chart;
					if (data.player2 != null && Std.string(data.player2).length > 0) icon = Std.string(data.player2);
				}
				catch (e:Dynamic) {}
				// use the character's own health icon when its character file names one (e.g. example-dad -> dad)
				try
				{
					var charFile:String = Paths.mods(mod + '/characters/' + icon + '.json');
					if (!FileSystem.exists(charFile)) charFile = Paths.getSharedPath('characters/' + icon + '.json');
					if (FileSystem.exists(charFile))
					{
						var ch:Dynamic = tjson.TJSON.parse(File.getContent(charFile));
						if (ch.healthicon != null && Std.string(ch.healthicon).length > 0) icon = Std.string(ch.healthicon);
					}
				}
				catch (e:Dynamic) {}

				var display:String = [for (part in name.replace('_', '-').split('-')) if (part.length > 0) part.charAt(0).toUpperCase() + part.substr(1)].join(' ');
				found.push([display, icon, [146, 113, 253]]);
			}
			if (found.length < 1) continue;

			var key:String = mod + '-songs';
			if (weeksLoaded.exists(key)) continue;

			var weekFile:WeekFile = {
				songs: found,
				weekCharacters: ['', 'bf', 'gf'],
				weekBackground: 'stage',
				weekBefore: '',
				storyName: mod,
				weekName: mod,
				startUnlocked: true,
				hiddenUntilUnlocked: false,
				hideStoryMode: true, // Vortex Engine: Freeplay only - a made-up week shouldn't appear in Story Mode
				hideFreeplay: false,
				difficulties: ''
			};
			var weekData:WeekData = new WeekData(weekFile, key);
			weekData.folder = mod;
			if (isStoryMode != true)
			{
				weeksLoaded.set(key, weekData);
				weeksList.push(key);
			}
		}
	}
	#end

	#if MODS_ALLOWED
	private static function hideBaseGameWeeks():Void
	{
		var hideAll:Bool = false;
		var hide:Array<String> = [];
		for (mod in Mods.parseList().enabled)
		{
			var pack:Dynamic = Mods.getPack(mod);
			if (pack == null || pack.hideBaseGameWeeks == null) continue;
			var v:Dynamic = pack.hideBaseGameWeeks;
			if (v == true) hideAll = true;
			else if (Std.isOfType(v, Array)) for (w in (v : Array<Dynamic>)) hide.push(Std.string(w).toLowerCase());
		}
		if (!hideAll && hide.length < 1) return;
		for (name in weeksList.copy())
		{
			var week:WeekData = weeksLoaded.get(name);
			var isBase:Bool = (week.folder == null || week.folder.length < 1) && FileSystem.exists(Paths.getSharedPath('weeks/$name.json'));
			if (isBase && (hideAll || hide.contains(name.toLowerCase())))
			{
				weeksList.remove(name);
				weeksLoaded.remove(name);
			}
		}
	}
	#end

	private static function addWeek(weekToCheck:String, path:String, directory:String, i:Int, originalLength:Int, ?isStoryMode:Null<Bool>)
	{
		if(!weeksLoaded.exists(weekToCheck))
		{
			var week:WeekFile = getWeekFile(path);
			if(week != null)
			{
				var weekFile:WeekData = new WeekData(week, weekToCheck);
				if(i >= originalLength)
				{
					#if MODS_ALLOWED
					weekFile.folder = directory.substring(Paths.mods().length, directory.length-1);
					#end
				}
				// Vortex Engine: use the menu reloadWeekFiles() was called for (this read PlayState.isStoryMode, which isn't
				// always set yet, so hidden weeks could show up in the wrong menu)
				var story:Bool = (isStoryMode != null) ? isStoryMode : PlayState.isStoryMode;
				if((story && !weekFile.hideStoryMode) || (!story && !weekFile.hideFreeplay))
				{
					weeksLoaded.set(weekToCheck, weekFile);
					weeksList.push(weekToCheck);
				}
			}
		}
	}

	private static function getWeekFile(path:String):WeekFile {
		var rawJson:String = null;
		#if MODS_ALLOWED
		if(FileSystem.exists(path)) {
			rawJson = File.getContent(path);
		}
		#else
		if(OpenFlAssets.exists(path)) {
			rawJson = Assets.getText(path);
		}
		#end

		if(rawJson != null && rawJson.length > 0) {
			return cast tjson.TJSON.parse(rawJson);
		}
		return null;
	}

	//   FUNCTIONS YOU WILL PROBABLY NEVER NEED TO USE

	//To use on PlayState.hx or Highscore stuff
	public static function getWeekFileName():String {
		return weeksList[PlayState.storyWeek];
	}

	//Used on LoadingState, nothing really too relevant
	public static function getCurrentWeek():WeekData {
		return weeksLoaded.get(weeksList[PlayState.storyWeek]);
	}

	public static function setDirectoryFromWeek(?data:WeekData = null) {
		Mods.currentModDirectory = '';
		if(data != null && data.folder != null && data.folder.length > 0) {
			Mods.currentModDirectory = data.folder;
		}
	}
}
