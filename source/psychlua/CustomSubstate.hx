package psychlua;

import flixel.FlxObject;

class CustomSubstate extends MusicBeatSubstate
{
	public static var name:String = 'unnamed';
	public static var instance:CustomSubstate;

	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua)
	{
		var lua = funk.lua;
		Lua_helper.add_callback(lua, "openCustomSubstate", openCustomSubstate);
		Lua_helper.add_callback(lua, "closeCustomSubstate", closeCustomSubstate);
		Lua_helper.add_callback(lua, "insertToCustomSubstate", insertToCustomSubstate);
	}
	#end

	// Vortex Engine: custom substates used to work in songs only (PlayState.instance was null anywhere else and
	// the game crashed). They now open on top of any menu / custom state too, and that state's scripts
	// (states/<State>.lua / .hx) get the onCustomSubstate... callbacks.
	static function host():MusicBeatState
		return (PlayState.instance != null) ? PlayState.instance : Std.downcast(FlxG.state, MusicBeatState);

	static function callOnHost(func:String, args:Array<Dynamic>)
	{
		if(PlayState.instance != null) PlayState.instance.callOnScripts(func, args);
		else if(host() != null) host().callOnStateScripts(func, args);
	}

	static function setOnHostHScript(variable:String, value:Dynamic)
	{
		if(PlayState.instance != null) PlayState.instance.setOnHScript(variable, value);
		else if(host() != null) host().setOnStateScripts(variable, value, null, false, true);
	}

	public static function openCustomSubstate(name:String, ?pauseGame:Bool = false)
	{
		if(host() == null) return;
		if(pauseGame && PlayState.instance != null)
		{
			FlxG.camera.followLerp = 0;
			PlayState.instance.persistentUpdate = false;
			PlayState.instance.persistentDraw = true;
			PlayState.instance.paused = true;
			if(FlxG.sound.music != null) {
				FlxG.sound.music.pause();
				PlayState.instance.vocals.pause();
			}
		}
		host().openSubState(new CustomSubstate(name));
	}

	public static function closeCustomSubstate()
	{
		if(instance != null)
		{
			if(host() != null) host().closeSubState();
			return true;
		}
		return false;
	}

	public static function insertToCustomSubstate(tag:String, ?pos:Int = -1)
	{
		if(instance != null)
		{
			var tagObject:FlxObject = cast (MusicBeatState.getVariables().get(tag), FlxObject);

			if(tagObject != null)
			{
				if(pos < 0) instance.add(tagObject);
				else instance.insert(pos, tagObject);
				return true;
			}
		}
		return false;
	}

	override function create()
	{
		instance = this;
		setOnHostHScript('customSubstate', instance);


		callOnHost('onCustomSubstateCreate', [name]);
		super.create();
		callOnHost('onCustomSubstateCreatePost', [name]);
	}

	public function new(name:String)
	{
		CustomSubstate.name = name;
		setOnHostHScript('customSubstateName', name);
		super();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	override function update(elapsed:Float)
	{
		callOnHost('onCustomSubstateUpdate', [name, elapsed]);
		super.update(elapsed);
		callOnHost('onCustomSubstateUpdatePost', [name, elapsed]);
	}

	override function destroy()
	{
		callOnHost('onCustomSubstateDestroy', [name]);
		instance = null;
		name = 'unnamed';

		setOnHostHScript('customSubstate', null);
		setOnHostHScript('customSubstateName', name);
		super.destroy();
	}
}
