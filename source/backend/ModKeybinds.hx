package backend;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.util.FlxSave;

typedef ModKeybind = {
	var id:String;
	var name:String;
	var mod:String;
}

/**
 * VORTEX ENGINE ADDITION - key binds that mods add themselves.
 *
 * A mod declares its own actions (taunt, toggle a HUD, open a menu...) in `mods/<mod>/data/keybinds.json`:
 *
 *     [
 *       {"id": "taunt", "name": "Taunt", "keys": ["T"], "buttons": ["RIGHT_SHOULDER"]},
 *       {"id": "toggle_hud", "name": "Toggle HUD", "keys": ["H"]}
 *     ]
 *
 * They show up in Options > Controls under "MOD CONTROLS", players can rebind them like any other key
 * (saved with the normal controls), and scripts read them with the usual functions:
 *     keyJustPressed('taunt'), keyPressed('taunt'), keyReleased('taunt')
 * Scripts can also add one at runtime with addKeybind('taunt', 'Taunt', {'T'}).
 *
 * Key names are FlxKey names (A, SPACE, SHIFT, LEFT, NUMPADONE...); button names are FlxGamepadInputID names.
 */
class ModKeybinds
{
	public static var list:Array<ModKeybind> = [];
	static var fromScripts:Array<ModKeybind> = []; // added with addKeybind(), kept when the json files are re-read

	static var savedKeys:Map<String, Array<FlxKey>> = null;
	static var savedButtons:Map<String, Array<FlxGamepadInputID>> = null;
	static var builtIn:Array<String> = null;

	/** Reads data/keybinds.json from every enabled mod. Safe to call any time (menus call it when they open). **/
	public static function reload()
	{
		if(ClientPrefs.defaultKeys == null) return; // too early in boot
		if(builtIn == null) builtIn = [for (k in ClientPrefs.defaultKeys.keys()) k];
		list = fromScripts.copy();
		#if MODS_ALLOWED
		for (path in Mods.allModFoldersWith('data/keybinds.json'))
		{
			var mod:String = modOf(path);
			try
			{
				var parsed:Dynamic = tjson.TJSON.parse(File.getContent(path));
				var entries:Array<Dynamic> = Std.isOfType(parsed, Array) ? parsed : [parsed];
				for (e in entries)
					if(e != null && e.id != null)
						register(Std.string(e.id), e.name != null ? Std.string(e.name) : Std.string(e.id), toStrings(e.keys), toStrings(e.buttons), mod);
			}
			catch(e:Dynamic)
			{
				psychlua.ScriptLog.error('Keybinds: $path', 'Could not read it: $e');
				trace('Could not read $path: $e');
			}
		}
		#end
	}

	/** Adds (or updates the name/defaults of) a mod key bind. Returns false for invalid or built-in ids. **/
	public static function register(id:String, name:String, keys:Array<String>, ?buttons:Array<String>, ?mod:String, fromScript:Bool = false):Bool
	{
		if(id == null || ClientPrefs.defaultKeys == null) return false;
		id = id.toLowerCase().trim();
		if(id.length < 1) return false;
		if(builtIn == null) builtIn = [for (k in ClientPrefs.defaultKeys.keys()) k];
		if(builtIn.contains(id)) return false; // never let a mod take over note_left, accept, etc.

		var defKeys:Array<FlxKey> = [for (k in (keys != null ? keys : [])) if(FlxKey.fromString(k.toUpperCase()) != NONE) FlxKey.fromString(k.toUpperCase())];
		var defButtons:Array<FlxGamepadInputID> = [for (b in (buttons != null ? buttons : [])) if(FlxGamepadInputID.fromString(b.toUpperCase()) != NONE) FlxGamepadInputID.fromString(b.toUpperCase())];
		ClientPrefs.defaultKeys.set(id, defKeys);
		ClientPrefs.defaultButtons.set(id, defButtons);

		loadSaved();
		if(!ClientPrefs.keyBinds.exists(id))
			ClientPrefs.keyBinds.set(id, (savedKeys != null && savedKeys.exists(id)) ? savedKeys.get(id).copy() : defKeys.copy());
		if(!ClientPrefs.gamepadBinds.exists(id))
			ClientPrefs.gamepadBinds.set(id, (savedButtons != null && savedButtons.exists(id)) ? savedButtons.get(id).copy() : defButtons.copy());

		for (bind in list) if(bind.id == id) { bind.name = name; return true; }
		var bind:ModKeybind = {id: id, name: name, mod: mod};
		list.push(bind);
		if(fromScript) fromScripts.push(bind);
		return true;
	}

	public static function exists(id:String):Bool
	{
		if(id == null) return false;
		id = id.toLowerCase();
		for (bind in list) if(bind.id == id) return true;
		return false;
	}

	/** The key names bound to `id` (built-in or mod), e.g. ['SPACE', 'SHIFT']. **/
	public static function keyNames(id:String):Array<String>
	{
		var keys:Array<FlxKey> = ClientPrefs.keyBinds.get(id != null ? id.toLowerCase() : '');
		return (keys != null) ? [for (k in keys) if(k != NONE) k.toString()] : [];
	}

	// controls are saved for every bind in ClientPrefs.keyBinds, but loadPrefs() only reads back the built-in
	// ones, so read the saved mod binds ourselves
	static function loadSaved()
	{
		if(savedKeys != null) return;
		savedKeys = new Map<String, Array<FlxKey>>();
		savedButtons = new Map<String, Array<FlxGamepadInputID>>();
		try
		{
			var save:FlxSave = new FlxSave();
			save.bind('controls_v3', CoolUtil.getSavePath());
			if(save.data.keyboard != null) savedKeys = save.data.keyboard;
			if(save.data.gamepad != null) savedButtons = save.data.gamepad;
		}
		catch(e:Dynamic) {}
	}

	static function toStrings(v:Dynamic):Array<String>
	{
		if(v == null) return [];
		if(Std.isOfType(v, Array)) return [for (x in (v:Array<Dynamic>)) Std.string(x)];
		return [Std.string(v)];
	}

	static function modOf(path:String):String
	{
		#if MODS_ALLOWED
		var parts:Array<String> = path.split('/');
		if(parts.length > 2 && parts[0] + '/' == Paths.mods()) return parts[1];
		#end
		return null;
	}
}
