package backend;

import flixel.FlxState;
import backend.PsychCamera;

class MusicBeatState extends FlxState
{
	// Vortex Engine: widened from `private` to `public` so tools like
	// debug.DebugOverlay (and Lua/HScript mods) can read these directly
	// instead of needing @:privateAccess. Purely informational fields --
	// nothing about making them public changes how they're written.
	public var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	public var curStep:Int = 0;
	public var curBeat:Int = 0;

	public var curDecStep:Float = 0;
	public var curDecBeat:Float = 0;
	public var controls(get, never):Controls;
	private function get_controls()
	{
		return Controls.instance;
	}

	var _psychCameraInitialized:Bool = false;

	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	public static function getVariables()
		return getState().variables;

	override function create() {
		var skip:Bool = FlxTransitionableState.skipNextTransOut;
		#if MODS_ALLOWED Mods.updatedOnState = false; #end

		if(!_psychCameraInitialized) initPsychCamera();

		super.create();

		// Vortex Engine: run mods/<mod>/states/<ThisStateName>.lua / .hx next to this state (songs use their own script system)
		if(!Std.isOfType(this, states.PlayState))
		{
			var scriptName:String = (stateScriptName != null) ? stateScriptName : Type.getClassName(Type.getClass(this)).split('.').pop();
			try { loadStateScripts(scriptName); }
			catch(e:Dynamic) { trace('State scripts for "$scriptName" failed to load: $e'); }
		}

		if(!skip) {
			openSubState(new CustomFadeTransition(0.5, true));
		}
		FlxTransitionableState.skipNextTransOut = false;
		timePassedOnState = 0;
	}

	public function initPsychCamera():PsychCamera
	{
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_psychCameraInitialized = true;
		//trace('initialized psych camera ' + Sys.cpuTime());
		return camera;
	}

	public static var timePassedOnState:Float = 0;
	override function update(elapsed:Float)
	{
		//everyStep();
		var oldStep:Int = curStep;
		timePassedOnState += elapsed;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep)
		{
			if(curStep > 0)
				stepHit();

			if(PlayState.SONG != null)
			{
				if (oldStep < curStep)
					updateSection();
				else
					rollbackSection();
			}
		}

		if(FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;
		
		stagesFunc(function(stage:BaseStage) {
			stage.update(elapsed);
		});

		var scripted:Bool = hasStateScripts();
		if(scripted)
		{
			if(!stateScriptsPosted)
			{
				stateScriptsPosted = true;
				callOnStateScripts('onCreatePost', []);
			}
			callOnStateScripts('onUpdate', [elapsed]);
		}
		psychlua.ScriptedClasses.update(elapsed);

		super.update(elapsed);

		if(scripted) callOnStateScripts('onUpdatePost', [elapsed]);
		updateDebugTexts(elapsed);
	}

	private function updateSection():Void
	{
		if(stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while(curStep >= stepsToDo)
		{
			curSection++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}

	private function rollbackSection():Void
	{
		if(curStep < 0) return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if(stepsToDo > curStep) break;
				
				curSection++;
			}
		}

		if(curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public static function switchState(nextState:FlxState = null) {
		if(nextState == null) nextState = FlxG.state;
		if(nextState == FlxG.state)
		{
			resetState();
			return;
		}

		if(FlxTransitionableState.skipNextTransIn) FlxG.switchState(nextState);
		else startTransition(nextState);
		FlxTransitionableState.skipNextTransIn = false;
	}

	public static function resetState() {
		if(FlxTransitionableState.skipNextTransIn) FlxG.resetState();
		else startTransition();
		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	public static function startTransition(nextState:FlxState = null)
	{
		if(nextState == null)
			nextState = FlxG.state;

		FlxG.state.openSubState(new CustomFadeTransition(0.5, false));
		if(nextState == FlxG.state)
			CustomFadeTransition.finishCallback = function() FlxG.resetState();
		else
			CustomFadeTransition.finishCallback = function() FlxG.switchState(nextState);
	}

	public static function getState():MusicBeatState {
		return cast (FlxG.state, MusicBeatState);
	}

	public function stepHit():Void
	{
		stagesFunc(function(stage:BaseStage) {
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if(hasStateScripts())
		{
			setOnStateScripts('curStep', curStep);
			callOnStateScripts('onStepHit', [curStep]);
		}
		psychlua.ScriptedClasses.stepHit(curStep);

		if (curStep % 4 == 0)
			beatHit();
	}

	public var stages:Array<BaseStage> = [];
	public function beatHit():Void
	{
		//trace('Beat: ' + curBeat);
		stagesFunc(function(stage:BaseStage) {
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
		if(hasStateScripts())
		{
			setOnStateScripts('curBeat', curBeat);
			callOnStateScripts('onBeatHit', [curBeat]);
		}
		psychlua.ScriptedClasses.beatHit(curBeat);
	}

	public function sectionHit():Void
	{
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
		stagesFunc(function(stage:BaseStage) {
			stage.curSection = curSection;
			stage.sectionHit();
		});
	}

	function stagesFunc(func:BaseStage->Void)
	{
		// Vortex Engine: a broken built-in stage is switched off (and logged) instead of crashing the song
		for (stage in stages.copy())
			if(stage != null && stage.exists && stage.active)
			{
				try { func(stage); }
				catch(e:Dynamic)
				{
					trace('ERROR! stage callback failed, disabling that stage script: $e');
					stage.active = false;
				}
			}
	}

	function getBeatsOnSection()
	{
		var val:Null<Float> = 4;
		if(PlayState.SONG != null && PlayState.SONG.notes[curSection] != null) val = PlayState.SONG.notes[curSection].sectionBeats;
		return val == null ? 4 : val;
	}

	// ===================================================================================================
	// Vortex Engine: state scripts. Any menu/state (not PlayState, which has its own system) runs
	// mods/<mod>/states/<StateName>.lua and .hx, e.g. states/MainMenuState.lua. Custom states
	// (states.ScriptedState) use the same host with their own name.
	// ===================================================================================================
	public var stateScriptName:String = null;
	#if LUA_ALLOWED public var stateLuaArray:Array<psychlua.FunkinLua> = []; #else public var stateLuaArray:Array<Dynamic> = []; #end
	#if HSCRIPT_ALLOWED public var stateHScripts:Array<psychlua.HScript> = []; #end
	var stateScriptsPosted:Bool = false;

	public inline function hasStateScripts():Bool
		return stateLuaArray.length > 0 #if HSCRIPT_ALLOWED || stateHScripts.length > 0 #end;

	/** Loads states/<name>.lua and states/<name>.hx from every place mods can put files. Returns how many were found. **/
	public function loadStateScripts(name:String):Int
	{
		var found:Int = 0;
		#if MODS_ALLOWED
		for (folder in Mods.allModFoldersWith('states/'))
		{
			if(!folder.endsWith('/')) folder += '/';
			#if LUA_ALLOWED
			var luaFile:String = folder + name + '.lua';
			if(FileSystem.exists(luaFile))
			{
				var script = new psychlua.FunkinLua(luaFile, false);
				if(script.lua != null && !script.closed) { stateLuaArray.push(script); found++; }
				else script.stop();
			}
			#end
			#if HSCRIPT_ALLOWED
			var hxFile:String = folder + name + '.hx';
			if(FileSystem.exists(hxFile))
			{
				try
				{
					var hs = new psychlua.HScript(null, hxFile);
					if(hs.exists('onCreate')) hs.call('onCreate');
					stateHScripts.push(hs);
					found++;
				}
				catch(e:Dynamic) { psychlua.LuaUtils.debugPrint('Error in $hxFile: $e', FlxColor.RED); }
			}
			#end
		}
		#end
		return found;
	}

	/** Calls a function on this state's scripts. Returns the first result that isn't Function_Continue. **/
	public function callOnStateScripts(funcToCall:String, ?args:Array<Dynamic>):Dynamic
	{
		var ret:Dynamic = psychlua.LuaUtils.Function_Continue;
		if(args == null) args = [];
		#if LUA_ALLOWED
		for (script in stateLuaArray.copy())
		{
			if(script.closed) { stateLuaArray.remove(script); script.stop(); continue; }
			var r:Dynamic = script.call(funcToCall, args);
			if(r != null && r != psychlua.LuaUtils.Function_Continue) ret = r;
		}
		#end
		#if HSCRIPT_ALLOWED
		for (hs in stateHScripts.copy())
		{
			if(hs == null || !hs.exists(funcToCall)) continue;
			var c = hs.call(funcToCall, args);
			if(c != null && c.returnValue != null && c.returnValue != psychlua.LuaUtils.Function_Continue) ret = c.returnValue;
		}
		#end
		return ret;
	}

	public function setOnStateScripts(variable:String, value:Dynamic)
	{
		#if LUA_ALLOWED for (script in stateLuaArray) script.set(variable, value); #end
		#if HSCRIPT_ALLOWED for (hs in stateHScripts) hs.set(variable, value); #end
	}

	// on-screen debugPrint() output for menus / custom states (songs use PlayState's own list)
	var debugTexts:Array<FlxText> = [];
	var debugTextAge:Map<FlxText, Float> = new Map<FlxText, Float>();
	public function addDebugText(text:String, color:FlxColor)
	{
		var t:FlxText = new FlxText(10, 10, FlxG.width - 20, text, 16);
		t.setFormat(Paths.font('vcr.ttf'), 16, color, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.scrollFactor.set();
		t.cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		for (old in debugTexts) old.y += t.height + 2;
		debugTexts.push(t);
		debugTextAge.set(t, 0);
		add(t);
		while(debugTexts.length > 12) { var o = debugTexts.shift(); debugTextAge.remove(o); remove(o, true); o.destroy(); }
	}

	function updateDebugTexts(elapsed:Float)
	{
		if(debugTexts.length < 1) return;
		for (t in debugTexts.copy())
		{
			var age:Float = debugTextAge.get(t) + elapsed;
			debugTextAge.set(t, age);
			if(age > 6) t.alpha -= elapsed;
			if(t.alpha <= 0) { debugTexts.remove(t); debugTextAge.remove(t); remove(t, true); t.destroy(); }
		}
	}

	override function destroy()
	{
		if(hasStateScripts())
		{
			try { callOnStateScripts('onDestroy', []); } catch(e:Dynamic) {}
			#if LUA_ALLOWED for (script in stateLuaArray) script.stop(); #end
			#if HSCRIPT_ALLOWED for (hs in stateHScripts) if(hs != null) hs.destroy(); #end
		}
		stateLuaArray = [];
		#if HSCRIPT_ALLOWED stateHScripts = []; #end
		psychlua.ScriptedClasses.clear();
		super.destroy();
	}
}
