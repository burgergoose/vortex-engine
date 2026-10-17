package backend;

#if ACHIEVEMENTS_ALLOWED
import objects.AchievementPopup;
import haxe.Exception;
import haxe.Json;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

typedef Achievement =
{
	var name:String;
	var description:String;
	@:optional var hidden:Bool;
	@:optional var maxScore:Float;
	@:optional var maxDecimals:Int;

	//handled automatically, ignore these two
	@:optional var mod:String;
	@:optional var ID:Int;

	// Vortex Engine: achievements made with the Achievement Editor (mods/<mod>/achievements/<id>.json)
	@:optional var icon:String;     // file name in the achievements/ folder (default <id>.png)
	@:optional var unlock:AchievementUnlock;
	@:optional var script:String;   // file name in the achievements/ folder (default <id>.lua / <id>.hx if present)
	@:optional var folder:String;   // resolved: the achievements/ folder this one was loaded from
}

/**
 * Vortex Engine: when an achievement unlocks by itself. Checked when a song ends (never in botplay or the chart editor).
 *   type "manual"        - only scripts unlock it (unlockAchievement / addAchievementScore)
 *   type "song_complete" - finish `song` (empty = any song)
 *   type "week_complete" - finish the last song of `week` (week file name) in Story Mode
 * maxMisses (-1 = any), minAccuracy (0-100), minScore (0 = any) apply to both; for weeks they use the whole week's
 * misses / score. allowPractice lets Practice Mode count. With maxScore > 0 every qualifying finish adds 1 progress.
 */
typedef AchievementUnlock =
{
	@:optional var type:String;
	@:optional var song:String;
	@:optional var week:String;
	@:optional var maxMisses:Int;
	@:optional var minAccuracy:Float;
	@:optional var minScore:Int;
	@:optional var allowPractice:Bool;
}

enum abstract AchievementOp(String)
{
	var GET = 'get';
	var SET = 'set';
	var ADD = 'add';
}

class Achievements {
	public static function init()
	{
		createAchievement('friday_night_play',		{name: "Freaky on a Friday Night", description: "Play on a Friday... Night.", hidden: true});
		#if BASE_GAME_FILES
		createAchievement('week1_nomiss',			{name: "She Calls Me Daddy Too", description: "Beat Week 1 on Hard with no Misses."});
		createAchievement('week2_nomiss',			{name: "No More Tricks", description: "Beat Week 2 on Hard with no Misses."});
		createAchievement('week3_nomiss',			{name: "Call Me The Hitman", description: "Beat Week 3 on Hard with no Misses."});
		createAchievement('week4_nomiss',			{name: "Lady Killer", description: "Beat Week 4 on Hard with no Misses."});
		createAchievement('week5_nomiss',			{name: "Missless Christmas", description: "Beat Week 5 on Hard with no Misses."});
		createAchievement('week6_nomiss',			{name: "Highscore!!", description: "Beat Week 6 on Hard with no Misses."});
		createAchievement('week7_nomiss',			{name: "God Effing Damn It!", description: "Beat Week 7 on Hard with no Misses."});
		createAchievement('weekend1_nomiss',		{name: "Just a Friendly Sparring", description: "Beat Weekend 1 on Hard with no Misses."});
		#end
		createAchievement('ur_bad',					{name: "What a Funkin' Disaster!", description: "Complete a Song with a rating lower than 20%."});
		createAchievement('ur_good',				{name: "Perfectionist", description: "Complete a Song with a rating of 100%."});
		#if BASE_GAME_FILES
		createAchievement('roadkill_enthusiast',	{name: "Roadkill Enthusiast", description: "Watch the Henchmen die 50 times.", maxScore: 50, maxDecimals: 0});
		#end
		createAchievement('oversinging', 			{name: "Oversinging Much...?", description: "Sing for 10 seconds without going back to Idle."});
		createAchievement('hype',					{name: "Hyperactive", description: "Finish a Song without going back to Idle."});
		createAchievement('two_keys',				{name: "Just the Two of Us", description: "Finish a Song pressing only two keys."});
		createAchievement('toastie',				{name: "Toaster Gamer", description: "Have you tried to run the game on a toaster?"});
		#if BASE_GAME_FILES
		createAchievement('debugger',				{name: "Debugger", description: "Beat the \"Test\" Stage from the Chart Editor.", hidden: true});
		#end
		#if (TITLE_SCREEN_EASTER_EGG || PSYCH_WATERMARKS)
		createAchievement('pessy_easter_egg',		{name: "Engine Gal Pal", description: "Teehee, you found me~!", hidden: true});
		#end

		//dont delete this thing below
		_originalLength = _sortID + 1;
	}

	public static var achievements:Map<String, Achievement> = new Map<String, Achievement>();
	public static var variables:Map<String, Float> = [];
	public static var achievementsUnlocked:Array<String> = [];
	private static var _firstLoad:Bool = true;

	public static function get(name:String):Achievement
		return achievements.get(name);
	public static function exists(name:String):Bool
		return achievements.exists(name);

	public static function load():Void
	{
		if(!_firstLoad) return;

		if(_originalLength < 0) init();

		if(FlxG.save.data != null) {
			if(FlxG.save.data.achievementsUnlocked != null)
				achievementsUnlocked = FlxG.save.data.achievementsUnlocked;

			var savedMap:Map<String, Float> = cast FlxG.save.data.achievementsVariables;
			if(savedMap != null)
			{
				for (key => value in savedMap)
				{
					variables.set(key, value);
				}
			}
			_firstLoad = false;
		}
	}

	public static function save():Void
	{
		FlxG.save.data.achievementsUnlocked = achievementsUnlocked;
		FlxG.save.data.achievementsVariables = variables;
	}
	
	public static function getScore(name:String):Float
		return _scoreFunc(name, GET);

	public static function setScore(name:String, value:Float, saveIfNotUnlocked:Bool = true):Float
		return _scoreFunc(name, SET, value, saveIfNotUnlocked);

	public static function addScore(name:String, value:Float = 1, saveIfNotUnlocked:Bool = true):Float
		return _scoreFunc(name, ADD, value, saveIfNotUnlocked);

	static function _scoreFunc(name:String, mode:AchievementOp, addOrSet:Float = 1, saveIfNotUnlocked:Bool = true):Float
	{
		if(!variables.exists(name))
			variables.set(name, 0);

		if(achievements.exists(name))
		{
			var achievement:Achievement = achievements.get(name);
			if(achievement.maxScore < 1) throw new Exception('Achievement has score disabled or is incorrectly configured: $name');

			if(achievementsUnlocked.contains(name)) return achievement.maxScore;

			var val = addOrSet;
			switch(mode)
			{
				case GET: return variables.get(name); //get
				case ADD: val += variables.get(name); //add
				default:
			}

			if(val >= achievement.maxScore)
			{
				unlock(name);
				val = achievement.maxScore;
			}
			variables.set(name, val);

			Achievements.save();
			if(saveIfNotUnlocked || val >= achievement.maxScore) FlxG.save.flush();
			return val;
		}
		return -1;
	}

	static var _lastUnlock:Int = -999;
	public static function unlock(name:String, autoStartPopup:Bool = true):String {
		if(!achievements.exists(name))
		{
			FlxG.log.error('Achievement "$name" does not exists!');
			throw new Exception('Achievement "$name" does not exists!');
			return null;
		}

		if(Achievements.isUnlocked(name)) return null;

		trace('Completed achievement "$name"');
		achievementsUnlocked.push(name);

		// earrape prevention
		var time:Int = openfl.Lib.getTimer();
		if(Math.abs(time - _lastUnlock) >= 100) //If last unlocked happened in less than 100 ms (0.1s) ago, then don't play sound
		{
			FlxG.sound.play(Paths.sound('confirmMenu'), 0.5);
			_lastUnlock = time;
		}

		Achievements.save();
		FlxG.save.flush();

		if(autoStartPopup) startPopup(name);
		return name;
	}

	inline public static function isUnlocked(name:String)
		return achievementsUnlocked.contains(name);

	@:allow(objects.AchievementPopup)
	private static var _popups:Array<AchievementPopup> = [];

	public static var showingPopups(get, never):Bool;
	public static function get_showingPopups()
		return _popups.length > 0;

	public static function startPopup(achieve:String, endFunc:Void->Void = null) {
		for (popup in _popups)
		{
			if(popup == null) continue;
			popup.intendedY += 150;
		}

		var newPop:AchievementPopup = new AchievementPopup(achieve, endFunc);
		_popups.push(newPop);
		//trace('Giving achievement ' + achieve);
	}

	// Map sorting cuz haxe is physically incapable of doing that by itself
	static var _sortID = 0;
	static var _originalLength = -1;
	public static function createAchievement(name:String, data:Achievement, ?mod:String = null)
	{
		data.ID = _sortID;
		data.mod = mod;
		achievements.set(name, data);
		_sortID++;
	}

	#if MODS_ALLOWED
	public static function reloadList()
	{
		// remove modded achievements
		if((_sortID + 1) > _originalLength)
			for (key => value in achievements)
				if(value.mod != null)
					achievements.remove(key);

		_sortID = _originalLength-1;

		var modLoaded:String = Mods.currentModDirectory;
		Mods.currentModDirectory = null;
		loadAchievementJson(Paths.mods('data/achievements.json'));
		loadAchievementFolder(Paths.mods('achievements/'), null); // Vortex Engine
		for (i => mod in Mods.parseList().enabled)
		{
			Mods.currentModDirectory = mod;
			loadAchievementJson(Paths.mods('$mod/data/achievements.json'));
			loadAchievementFolder(Paths.mods('$mod/achievements/'), mod); // Vortex Engine
		}
		Mods.currentModDirectory = modLoaded;
		listLoaded = true;
	}

	/** Vortex Engine: true once reloadList() has run this session. **/
	public static var listLoaded:Bool = false;

	/** Vortex Engine: lowercase letters, numbers, - and _ only (it's also the file name and the save key). **/
	public static function isValidId(id:String):Bool
		return id != null && ~/^[a-z0-9_\-]+$/.match(id);

	/**
	 * Vortex Engine: loads every <id>.json in a mod's achievements/ folder (made with the Achievement Editor).
	 * The file name is the achievement's id. Problems go to vortex_script_log.txt instead of popup windows.
	 */
	static function loadAchievementFolder(folder:String, mod:String)
	{
		if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return;
		var files:Array<String> = FileSystem.readDirectory(folder);
		files.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		for (file in files)
		{
			if(!file.toLowerCase().endsWith('.json')) continue;
			var id:String = file.substr(0, file.length - 5);
			if(!isValidId(id))
			{
				psychlua.ScriptLog.error('Achievements: $folder$file', 'Invalid id "$id" (use lowercase letters, numbers, - and _).');
				continue;
			}
			if(achievements.exists(id))
			{
				psychlua.ScriptLog.error('Achievements: $folder$file', 'Another achievement already uses the id "$id", this one was skipped.');
				continue;
			}
			try
			{
				var data:Dynamic = tjson.TJSON.parse(File.getContent(folder + file));
				var achieve:Achievement = {
					name: (data.name != null) ? Std.string(data.name) : id,
					description: (data.description != null) ? Std.string(data.description) : '',
					hidden: data.hidden == true,
					maxScore: (data.maxScore != null) ? Std.parseFloat(Std.string(data.maxScore)) : 0,
					maxDecimals: (data.maxDecimals != null) ? Std.parseInt(Std.string(data.maxDecimals)) : 0,
					icon: (data.icon != null && Std.string(data.icon).length > 0) ? Std.string(data.icon) : null,
					script: (data.script != null && Std.string(data.script).length > 0) ? Std.string(data.script) : null,
					unlock: (data.unlock != null) ? data.unlock : {type: 'manual'},
					folder: folder
				};
				if(Math.isNaN(achieve.maxScore)) achieve.maxScore = 0;
				createAchievement(id, achieve, mod);
			}
			catch(e:Dynamic) { psychlua.ScriptLog.error('Achievements: $folder$file', 'Could not read it: $e'); }
		}
	}
	#end

	/**
	 * Vortex Engine: the icon of an achievement. Editor-made ones use achievements/<icon or id>.png from their folder;
	 * everything else uses Psych's images/achievements/<id>.png (and -pixel). Returns null if there's no picture.
	 */
	static var iconCache:Map<String, flixel.graphics.FlxGraphic> = new Map<String, flixel.graphics.FlxGraphic>();
	public static function getIconFile(name:String):String
	{
		var achieve:Achievement = achievements.get(name);
		if(achieve == null || achieve.folder == null) return null;
		var file:String = achieve.folder + ((achieve.icon != null) ? achieve.icon : name + '.png');
		if(!file.toLowerCase().endsWith('.png')) file += '.png';
		return FileSystem.exists(file) ? file : null;
	}

	public static function getIcon(name:String):flixel.graphics.FlxGraphic
	{
		var file:String = getIconFile(name);
		if(file == null) return null;
		var graphic = iconCache.get(file);
		if(graphic != null && graphic.bitmap != null) return graphic;
		try
		{
			graphic = flixel.graphics.FlxGraphic.fromBitmapData(openfl.display.BitmapData.fromFile(file), false, file);
			graphic.persist = true;
			graphic.destroyOnNoUse = false;
			iconCache.set(file, graphic);
			return graphic;
		}
		catch(e:Dynamic) { psychlua.ScriptLog.error('Achievements: $file', 'Could not load the icon: $e'); }
		return null;
	}

	/** Vortex Engine: forget a cached icon (the Achievement Editor calls this after the file changes). **/
	public static function clearIconCache()
	{
		for (g in iconCache) { g.persist = false; g.destroyOnNoUse = true; }
		iconCache.clear();
	}

	/** Vortex Engine: the attached script of an achievement (achievements/<script or id>.lua / .hx), or null. **/
	public static function getScriptFile(name:String):String
	{
		var achieve:Achievement = achievements.get(name);
		if(achieve == null || achieve.folder == null) return null;
		if(achieve.script != null)
		{
			var file:String = achieve.folder + achieve.script;
			return FileSystem.exists(file) ? file : null;
		}
		for (ext in ['.lua', '.hx'])
			if(FileSystem.exists(achieve.folder + name + ext)) return achieve.folder + name + ext;
		return null;
	}

	/** Vortex Engine: relock an achievement and clear its progress (Achievement Editor "Reset progress"). **/
	public static function reset(name:String)
	{
		achievementsUnlocked.remove(name);
		variables.remove(name);
		save();
		FlxG.save.flush();
	}

	/**
	 * Vortex Engine: called by PlayState when a song is finished. Unlocks (or adds progress to) every editor-made
	 * achievement whose "unlock" condition was met. `info` comes from PlayState.endSong.
	 */
	public static function checkSongEnd(info:{song:String, week:String, storyMode:Bool, lastSongOfWeek:Bool, misses:Int,
		weekMisses:Int, accuracy:Float, score:Int, weekScore:Int, practice:Bool}):Array<String>
	{
		var done:Array<String> = [];
		for (name => achieve in achievements)
		{
			var u:AchievementUnlock = achieve.unlock;
			if(u == null || u.type == null || isUnlocked(name)) continue;
			var type:String = u.type.toLowerCase();
			if(type != 'song_complete' && type != 'week_complete') continue;
			if(info.practice && u.allowPractice != true) continue;

			var misses:Int = info.misses;
			var score:Int = info.score;
			if(type == 'song_complete')
			{
				if(u.song != null && u.song.trim().length > 0 && Paths.formatToSongPath(u.song) != Paths.formatToSongPath(info.song)) continue;
			}
			else
			{
				if(!info.storyMode || !info.lastSongOfWeek) continue;
				if(u.week == null || u.week.trim() != info.week) continue;
				misses = info.weekMisses;
				score = info.weekScore;
			}
			if(u.maxMisses != null && u.maxMisses >= 0 && misses > u.maxMisses) continue;
			if(u.minAccuracy != null && u.minAccuracy > 0 && info.accuracy < u.minAccuracy) continue;
			if(u.minScore != null && u.minScore > 0 && score < u.minScore) continue;

			if(achieve.maxScore != null && achieve.maxScore > 0) addScore(name, 1);
			else unlock(name);
			done.push(name);
		}
		return done;
	}

	#if MODS_ALLOWED

	inline static function loadAchievementJson(path:String, addMods:Bool = true)
	{
		var retVal:Array<Dynamic> = null;
		if(FileSystem.exists(path)) {
			try {
				var rawJson:String = File.getContent(path).trim();
				if(rawJson != null && rawJson.length > 0) retVal = tjson.TJSON.parse(rawJson); //Json.parse('{"achievements": $rawJson}').achievements;
				
				if(addMods && retVal != null)
				{
					for (i in 0...retVal.length)
					{
						var achieve:Dynamic = retVal[i];
						if(achieve == null)
						{
							var errorTitle = 'Mod name: ' + Mods.currentModDirectory != null ? Mods.currentModDirectory : "None";
							var errorMsg = 'Achievement #${i+1} is invalid.';
							#if windows
							lime.app.Application.current.window.alert(errorMsg, errorTitle);
							#end
							trace('$errorTitle - $errorMsg');
							continue;
						}

						var key:String = achieve.save;
						if(key == null || key.trim().length < 1)
						{
							var errorTitle = 'Error on Achievement: ' + (achieve.name != null ? achieve.name : achieve.save);
							var errorMsg = 'Missing valid "save" value.';
							#if windows
							lime.app.Application.current.window.alert(errorMsg, errorTitle);
							#end
							trace('$errorTitle - $errorMsg');
							continue;
						}
						key = key.trim();
						if(achievements.exists(key)) continue;

						createAchievement(key, achieve, Mods.currentModDirectory);
					}
				}
			} catch(e:Dynamic) {
				var errorTitle = 'Mod name: ' + Mods.currentModDirectory != null ? Mods.currentModDirectory : "None";
				var errorMsg = 'Error loading achievements.json: $e';
				#if windows
				lime.app.Application.current.window.alert(errorMsg, errorTitle);
				#end
				trace('$errorTitle - $errorMsg');
			}
		}
		return retVal;
	}
	#end

	#if LUA_ALLOWED
	public static function addLuaCallbacks(lua:State)
	{
		Lua_helper.add_callback(lua, "getAchievementScore", function(name:String):Float
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('getAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return -1;
			}
			return getScore(name);
		});
		Lua_helper.add_callback(lua, "setAchievementScore", function(name:String, ?value:Float = 0, ?saveIfNotUnlocked:Bool = true):Float
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('setAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return -1;
			}
			return setScore(name, value, saveIfNotUnlocked);
		});
		Lua_helper.add_callback(lua, "addAchievementScore", function(name:String, ?value:Float = 1, ?saveIfNotUnlocked:Bool = true):Float
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('addAchievementScore: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return -1;
			}
			return addScore(name, value, saveIfNotUnlocked);
		});
		Lua_helper.add_callback(lua, "unlockAchievement", function(name:String):Dynamic
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('unlockAchievement: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return null;
			}
			return unlock(name);
		});
		Lua_helper.add_callback(lua, "isAchievementUnlocked", function(name:String):Dynamic
		{
			if(!achievements.exists(name))
			{
				FunkinLua.luaTrace('isAchievementUnlocked: Couldnt find achievement: $name', false, false, FlxColor.RED);
				return null;
			}
			return isUnlocked(name);
		});
		Lua_helper.add_callback(lua, "achievementExists", function(name:String) return achievements.exists(name));
		// Vortex Engine: everything about one achievement in a table, or nil
		Lua_helper.add_callback(lua, "getAchievementInfo", function(name:String):Dynamic
		{
			var a:Achievement = achievements.get(name);
			if(a == null) return null;
			var score:Float = (a.maxScore != null && a.maxScore > 0) ? (isUnlocked(name) ? a.maxScore : (variables.exists(name) ? variables.get(name) : 0)) : 0;
			return {
				id: name, name: a.name, description: a.description, hidden: a.hidden == true, unlocked: isUnlocked(name),
				score: score, maxScore: (a.maxScore != null ? a.maxScore : 0), mod: a.mod,
				unlockType: (a.unlock != null && a.unlock.type != null) ? a.unlock.type : 'manual'
			};
		});
	}
	#end
}
#end