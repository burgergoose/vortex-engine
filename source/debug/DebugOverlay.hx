package debug;

import openfl.text.TextField;
import openfl.text.TextFormat;
import backend.VortexConfig;
import debug.FPSCounter;
import states.MainMenuState;
import states.FreeplayState;

/**
 * VORTEX ENGINE ADDITION.
 *
 * A companion to debug.FPSCounter (which stays untouched and keeps doing
 * its one job: a small always-on FPS/memory readout). This is the bigger,
 * opt-in "Developer Mode" panel: live engine + gameplay info, plus a few
 * developer actions, all gated behind F3 so normal players never see it.
 *
 * Lives at the same level as Main.fpsVar (added straight to the root
 * OpenFL Sprite in Main.hx), so -- like the FPS counter -- it works the
 * same way in every menu and in gameplay without any per-state wiring.
 *
 * Key bindings (deliberately NOT run through the rebindable `controls`
 * system -- these are developer-only, same idea as the engine's existing
 * F1/F5/F12 editor & pause shortcuts, which also bypass it):
 *   F3  - show/hide this overlay
 *   F6  - restart the current song
 *   F7  - reload Lua/HScript + stage + characters
 *   F8  - bail out to the main menu
 *
 * On F7: Psych Engine has no mechanism to hot-swap a stage/character/script
 * without recreating the PlayState (there's no in-place "reload" anywhere
 * in the engine to extend), so -- to keep this stable -- F7 reuses the
 * exact same full-restart path as F6. A real hot-reload (no restart, song
 * keeps playing) would be a much bigger, separate change; worth doing
 * later if you want it, but not something to bolt on here.
 */
class DebugOverlay extends TextField
{
	// Named overlayEnabled (not `enabled`) to steer clear of any same-named
	// property somewhere in TextField's own OpenFL ancestry.
	public var overlayEnabled(default, set):Bool = false;

	public function new(x:Float = 10, y:Float = 68)
	{
		super();
		this.x = x;
		this.y = y;
		selectable = false;
		mouseEnabled = false;
		multiline = true;
		autoSize = LEFT;
		defaultTextFormat = new TextFormat("_sans", 13, 0xFFB8FFEA);
		background = true;
		backgroundColor = 0x000000;
		alpha = 0.85;
		visible = false;
		text = '';
	}

	function set_overlayEnabled(value:Bool):Bool
	{
		overlayEnabled = value;
		visible = value;
		return value;
	}

	var textTimer:Float = 1000;
	override private function __enterFrame(deltaTime:Float):Void
	{
		#if !mobile
		if (FlxG.keys.justPressed.F3)
			overlayEnabled = !overlayEnabled;

		if (!overlayEnabled) return;

		if (FlxG.keys.justPressed.F6) restartSong();
		else if (FlxG.keys.justPressed.F7) reloadEverything();
		else if (FlxG.keys.justPressed.F8) returnToMenu();

		// Vortex Engine (performance): rebuilding this text every frame was wasted work; 10 times a second is plenty
		textTimer += deltaTime;
		if (textTimer < 100) return;
		textTimer = 0;
		updateText();
		#end
	}

	inline function inPlayState():Bool
		return PlayState.instance != null && FlxG.state == PlayState.instance;

	public dynamic function updateText():Void // dynamic so it's overridable from HScript/Lua like FPSCounter's
	{
		var lines:Array<String> = [];
		lines.push('${VortexConfig.engineName} v${VortexConfig.engineVersion} -- Developer Mode (F3 to hide)');
		lines.push('FPS: ${Main.fpsVar != null ? Main.fpsVar.currentFPS : 0}  |  Memory: ${flixel.util.FlxStringUtil.formatBytes(FPSCounter.getMemoryBytes())}');

		if (inPlayState())
		{
			var play:PlayState = PlayState.instance;
			lines.push('Song: ${PlayState.SONG != null ? PlayState.SONG.song : "?"}  |  Position: ${Math.round(Conductor.songPosition)}ms  |  BPM: ${Conductor.bpm}  |  Section: ${play.curSection}');
			lines.push('Score: ${play.songScore}  |  Combo: ${play.combo} (best ${play.highestCombo})  |  Misses: ${play.songMisses}');

			var bfAnim:String = (play.boyfriend != null) ? play.boyfriend.getAnimationName() : '-';
			var dadAnim:String = (play.dad != null) ? play.dad.getAnimationName() : '-';
			var gfAnim:String = (play.gf != null) ? play.gf.getAnimationName() : '-';
			lines.push('BF anim: $bfAnim  |  Dad anim: $dadAnim  |  GF anim: $gfAnim');

			if (play.camGame != null && play.camHUD != null)
				lines.push('Cam Game: zoom=${flixelRound(play.camGame.zoom)} pos=(${flixelRound(play.camGame.scroll.x)}, ${flixelRound(play.camGame.scroll.y)})  |  Cam HUD: zoom=${flixelRound(play.camHUD.zoom)}');

			lines.push('[F6] Restart Song   [F7] Reload Scripts/Stage/Characters   [F8] Return to Menu');
		}
		else
		{
			lines.push('(Song info only shows up while a song is loaded)');
		}

		text = lines.join('\n');
		textColor = 0xFFB8FFEA;
	}

	inline function flixelRound(n:Float):Float
		return Math.round(n * 100) / 100;

	function restartSong():Void
	{
		if (!inPlayState() || FlxG.state.subState != null) return;

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		PlayState.nextReloadAll = true;
		MusicBeatState.resetState();
	}

	function reloadEverything():Void
	{
		// See the class doc comment: this is intentionally the same path as
		// restartSong() -- Psych has no lighter-weight reload to extend.
		restartSong();
	}

	function returnToMenu():Void
	{
		if (!inPlayState() || FlxG.state.subState != null) return;

		FlxG.sound.music.stop();
		FreeplayState.destroyFreeplayVocals();
		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		Mods.loadTopMod();
		overlayEnabled = false;
		MusicBeatState.switchState(new MainMenuState());
	}
}
