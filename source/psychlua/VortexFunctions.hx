package psychlua;

import backend.ModKeybinds;

/**
 * VORTEX ENGINE ADDITION - extra modding API shared by Lua (implement) and HScript (HScript.preset calls the
 * same static functions). Everything here works in songs, menus and custom states unless it says otherwise.
 *
 * Global variables (kept across state switches and songs, for the whole session):
 *   setGlobalVar(name, value)  getGlobalVar(name, [default])  globalVarExists(name)  removeGlobalVar(name)
 * Mod key binds (see backend/ModKeybinds.hx):
 *   addKeybind(id, name, {keys}, [{buttons}])  getKeybind(id)  keybindExists(id)
 *   then keyJustPressed(id) / keyPressed(id) / keyReleased(id) like any other bind
 * Notes made by scripts (songs only):
 *   spawnNote(time, column, [mustPress = true], [noteType = ''], [holdLength = 0])
 * Debugging:
 *   getScriptErrorCount()  writeToScriptLog(text)
 */
class VortexFunctions
{
	public static var globalVars:Map<String, Dynamic> = new Map<String, Dynamic>();

	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua)
	{
		var lua:State = funk.lua;
		funk.set('vortexVersion', backend.VortexConfig.engineVersion);
		funk.set('engineName', backend.VortexConfig.engineName);

		Lua_helper.add_callback(lua, "setGlobalVar", function(name:String, value:Dynamic) return setGlobalVar(name, value));
		Lua_helper.add_callback(lua, "getGlobalVar", function(name:String, ?defaultValue:Dynamic = null) return getGlobalVar(name, defaultValue));
		Lua_helper.add_callback(lua, "globalVarExists", function(name:String) return globalVars.exists(name));
		Lua_helper.add_callback(lua, "removeGlobalVar", function(name:String) return globalVars.remove(name));

		Lua_helper.add_callback(lua, "addKeybind", function(id:String, name:String, ?keys:Dynamic = null, ?buttons:Dynamic = null)
			return addKeybind(id, name, LuaUtils.toArgArray(keys), LuaUtils.toArgArray(buttons)));
		Lua_helper.add_callback(lua, "getKeybind", function(id:String) return ModKeybinds.keyNames(id));
		Lua_helper.add_callback(lua, "keybindExists", function(id:String) return ClientPrefs.keyBinds.exists(id != null ? id.toLowerCase() : ''));

		Lua_helper.add_callback(lua, "spawnNote", function(time:Float, column:Int, ?mustPress:Bool = true, ?noteType:String = '', ?holdLength:Float = 0)
			return spawnNote(time, column, mustPress, noteType, holdLength) != null);

		Lua_helper.add_callback(lua, "getScriptErrorCount", function() return ScriptLog.errorCount);
		funk.addLocalCallback("writeToScriptLog", function(text:Dynamic) { ScriptLog.info(funk.shortName() + ': ' + Std.string(text)); return true; });
	}
	#end

	public static function setGlobalVar(name:String, value:Dynamic):Dynamic
	{
		if(name == null) return null;
		globalVars.set(name, value);
		return value;
	}

	public static function getGlobalVar(name:String, ?defaultValue:Dynamic = null):Dynamic
		return (name != null && globalVars.exists(name)) ? globalVars.get(name) : defaultValue;

	public static function addKeybind(id:String, name:String, keys:Array<Dynamic>, ?buttons:Array<Dynamic>):Bool
	{
		var keyNames:Array<String> = [for (k in (keys != null ? keys : [])) Std.string(k)];
		var buttonNames:Array<String> = [for (b in (buttons != null ? buttons : [])) Std.string(b)];
		var ok:Bool = ModKeybinds.register(id, (name != null && name.length > 0) ? name : id, keyNames, buttonNames, Mods.currentModDirectory, true);
		if(!ok) LuaUtils.debugPrint('addKeybind: "$id" is not a valid id (empty, or a built-in control like note_left)', FlxColor.RED);
		return ok;
	}

	public static function spawnNote(time:Float, column:Int, mustPress:Bool = true, ?noteType:String = '', ?holdLength:Float = 0):objects.Note
	{
		if(PlayState.instance == null)
		{
			LuaUtils.debugPrint('spawnNote: only works during a song', FlxColor.RED);
			return null;
		}
		return PlayState.instance.addNoteAtRuntime(time, column, mustPress, noteType, holdLength);
	}
}
