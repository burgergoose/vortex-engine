package substates;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.util.FlxStringUtil;

import states.StoryMenuState;
import states.FreeplayState;
import options.OptionsState;
import objects.CosmicBackground;
import objects.MenuButton;

class PauseSubState extends MusicBeatSubstate
{
	var grpMenuShit:FlxTypedGroup<MenuButton>; // Vortex Engine: cosmic panel buttons (was Alphabet)

	var menuItems:Array<String> = [];
	var menuItemsOG:Array<String> = ['Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'];
	var difficultyChoices = [];
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;
	var practiceText:FlxText;
	var skipTimeText:FlxText;
	var skipTimeTracker:MenuButton;
	var curTime:Float = Math.max(0, Conductor.songPosition);

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	public static var songName:String = null;

	var pauseStars:Array<FlxSprite> = [];
	var starTime:Float = 0;
	var listY:Float = 0; // smoothed scroll position of the button list

	override function create()
	{
		// No need to change difficulty if there is only one! Vortex Engine: count the charts that actually exist,
		// not just the names in the difficulty list (Vortex songs normally only have a Normal chart)
		var chartsFound:Int = 0;
		try
		{
			var songLower:String = Paths.formatToSongPath(PlayState.SONG.song);
			for (i in 0...Difficulty.list.length)
				if(Paths.fileExists('data/$songLower/' + Highscore.formatSong(songLower, i) + '.json', TEXT)) chartsFound++;
		}
		catch(e:Dynamic) { chartsFound = Difficulty.list.length; }
		if(Difficulty.list.length < 2 || chartsFound < 2) menuItemsOG.remove('Change Difficulty');
		if(PlayState.chartingMode)
		{
			menuItemsOG.insert(2, 'Leave Charting Mode');
			var num:Int = 0;
			if(!PlayState.instance.startingSong)
			{
				num = 1;
				menuItemsOG.insert(3, 'Skip Time');
			}
			menuItemsOG.insert(3 + num, 'End Song');
			menuItemsOG.insert(4 + num, 'Toggle Practice Mode');
			menuItemsOG.insert(5 + num, 'Toggle Botplay');
		} else if(PlayState.instance.practiceMode && !PlayState.instance.startingSong)
			menuItemsOG.insert(3, 'Skip Time');
		menuItems = menuItemsOG;

		for (i in 0...Difficulty.list.length) {
			var diff:String = Difficulty.getString(i);
			difficultyChoices.push(diff);
		}
		difficultyChoices.push('BACK');

		pauseMusic = new FlxSound();
		try
		{
			var pauseSong:String = getPauseSong();
			if(pauseSong != null) pauseMusic.loadEmbedded(Paths.music(pauseSong), true, true);
		}
		catch(e:Dynamic) {}
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));

		FlxG.sound.list.add(pauseMusic);

		// ---- Vortex Engine: cosmic pause screen (visuals only; every option works exactly like before) ----
		var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var panel:FlxSprite = new FlxSprite(0, 0).makeGraphic(610, FlxG.height, FlxColor.WHITE);
		panel.color = CosmicBackground.PANEL_FILL;
		panel.alpha = 0;
		panel.scrollFactor.set();
		add(panel);
		var panelEdge:FlxSprite = new FlxSprite(608, 0).makeGraphic(2, FlxG.height, FlxColor.WHITE);
		panelEdge.color = CosmicBackground.PANEL_BORDER_BRIGHT;
		panelEdge.alpha = 0;
		panelEdge.scrollFactor.set();
		add(panelEdge);

		for (i in 0...28)
		{
			var star:FlxSprite = new FlxSprite(FlxG.random.float(0, FlxG.width), FlxG.random.float(0, FlxG.height)).makeGraphic(2, 2, FlxColor.WHITE);
			star.scrollFactor.set();
			star.alpha = 0;
			star.ID = i;
			add(star);
			pauseStars.push(star);
		}

		var title:FlxText = new FlxText(48, 34, 0, 'PAUSED', 56);
		title.setFormat(Paths.font('vcr.ttf'), 56, CosmicBackground.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF140C30);
		title.borderSize = 3;
		title.scrollFactor.set();
		title.alpha = 0;
		add(title);
		var titleLine:FlxSprite = new FlxSprite(50, 100).makeGraphic(220, 3, FlxColor.WHITE);
		titleLine.color = CosmicBackground.NEBULA_VIOLET;
		titleLine.scrollFactor.set();
		titleLine.scale.x = 0;
		add(titleLine);

		var levelInfo:FlxText = new FlxText(20, 15, 0, PlayState.SONG.song, 32);
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32, CosmicBackground.TEXT_BRIGHT, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		levelInfo.updateHitbox();
		add(levelInfo);

		var levelDifficulty:FlxText = new FlxText(20, 15 + 32, 0, Difficulty.getString().toUpperCase(), 32);
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), 24, CosmicBackground.ACCENT_CYAN, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		levelDifficulty.updateHitbox();
		add(levelDifficulty);

		var blueballedTxt:FlxText = new FlxText(20, 15 + 64, 0, Language.getPhrase("blueballed", "Blueballed: {1}", [PlayState.deathCounter]), 32);
		blueballedTxt.scrollFactor.set();
		blueballedTxt.setFormat(Paths.font('vcr.ttf'), 24, CosmicBackground.TEXT_DIM, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		blueballedTxt.updateHitbox();
		add(blueballedTxt);

		practiceText = new FlxText(20, 15 + 101, 0, Language.getPhrase("Practice Mode").toUpperCase(), 32);
		practiceText.scrollFactor.set();
		practiceText.setFormat(Paths.font('vcr.ttf'), 24, CosmicBackground.NEBULA_TEAL, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		practiceText.x = FlxG.width - (practiceText.width + 20);
		practiceText.updateHitbox();
		practiceText.visible = PlayState.instance.practiceMode;
		add(practiceText);

		var chartingText:FlxText = new FlxText(20, 15 + 101, 0, Language.getPhrase("Charting Mode").toUpperCase(), 32);
		chartingText.scrollFactor.set();
		chartingText.setFormat(Paths.font('vcr.ttf'), 24, CosmicBackground.NEBULA_MAGENTA, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		chartingText.x = FlxG.width - (chartingText.width + 20);
		chartingText.y = FlxG.height - (chartingText.height + 20);
		chartingText.updateHitbox();
		chartingText.visible = PlayState.chartingMode;
		add(chartingText);

		var hint:FlxText = new FlxText(50, FlxG.height - 40, 520, 'UP/DOWN  select    ACCEPT  confirm    BACK  resume', 14);
		hint.setFormat(Paths.font('vcr.ttf'), 14, CosmicBackground.TEXT_DIM, LEFT);
		hint.scrollFactor.set();
		hint.alpha = 0;
		add(hint);

		blueballedTxt.alpha = 0;
		levelDifficulty.alpha = 0;
		levelInfo.alpha = 0;

		levelInfo.x = FlxG.width - (levelInfo.width + 20);
		levelDifficulty.x = FlxG.width - (levelDifficulty.width + 20);
		blueballedTxt.x = FlxG.width - (blueballedTxt.width + 20);

		FlxTween.tween(bg, {alpha: 0.55}, 0.35, {ease: FlxEase.quartInOut});
		FlxTween.tween(panel, {alpha: 0.72}, 0.35, {ease: FlxEase.quartOut});
		FlxTween.tween(panelEdge, {alpha: 0.9}, 0.35, {ease: FlxEase.quartOut, startDelay: 0.1});
		FlxTween.tween(title, {alpha: 1, y: 40}, 0.4, {ease: FlxEase.quartOut, startDelay: 0.05});
		FlxTween.tween(titleLine.scale, {x: 1}, 0.45, {ease: FlxEase.quartOut, startDelay: 0.15});
		FlxTween.tween(hint, {alpha: 0.8}, 0.4, {startDelay: 0.4});
		FlxTween.tween(levelInfo, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.2});
		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(blueballedTxt, {alpha: 1, y: blueballedTxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.4});

		grpMenuShit = new FlxTypedGroup<MenuButton>();
		add(grpMenuShit);

		missingTextBG = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		missingTextBG.scale.set(FlxG.width, FlxG.height);
		missingTextBG.updateHitbox();
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		regenMenu();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		super.create();
	}
	
	function getPauseSong()
	{
		var formattedSongName:String = (songName != null ? Paths.formatToSongPath(songName) : '');
		var formattedPauseMusic:String = Paths.formatToSongPath(ClientPrefs.data.pauseMusic);
		if(formattedSongName == 'none' || (formattedSongName != 'none' && formattedPauseMusic == 'none')) return null;

		return (formattedSongName != '') ? formattedSongName : formattedPauseMusic;
	}

	var holdTime:Float = 0;
	var cantUnpause:Float = 0.1;
	override function update(elapsed:Float)
	{
		cantUnpause -= elapsed;
		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);
		updateCosmicVisuals(elapsed);

		if(controls.BACK)
		{
			close();
			return;
		}

		if(FlxG.keys.justPressed.F5)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			PlayState.nextReloadAll = true;
			MusicBeatState.resetState();
		}

		updateSkipTextStuff();
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		var daSelected:String = menuItems[curSelected];
		switch (daSelected)
		{
			case 'Skip Time':
				if (controls.UI_LEFT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curTime -= 1000;
					holdTime = 0;
				}
				if (controls.UI_RIGHT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curTime += 1000;
					holdTime = 0;
				}

				if(controls.UI_LEFT || controls.UI_RIGHT)
				{
					holdTime += elapsed;
					if(holdTime > 0.5)
					{
						curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1);
					}

					if(curTime >= FlxG.sound.music.length) curTime -= FlxG.sound.music.length;
					else if(curTime < 0) curTime += FlxG.sound.music.length;
					updateSkipTimeText();
				}
		}

		if (controls.ACCEPT && (cantUnpause <= 0 || !controls.controllerMode))
		{
			if (menuItems == difficultyChoices)
			{
				var songLowercase:String = Paths.formatToSongPath(PlayState.SONG.song);
				var poop:String = Highscore.formatSong(songLowercase, curSelected);
				try
				{
					if(menuItems.length - 1 != curSelected && difficultyChoices.contains(daSelected))
					{
						Song.loadFromJson(poop, songLowercase);
						PlayState.storyDifficulty = curSelected;
						MusicBeatState.resetState();
						FlxG.sound.music.volume = 0;
						PlayState.changedDifficulty = true;
						PlayState.chartingMode = false;
						return;
					}
				}
				catch(e:haxe.Exception)
				{
					trace('ERROR! ${e.message}');
	
					var errorStr:String = e.message;
					if(errorStr.startsWith('[lime.utils.Assets] ERROR:')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
					else errorStr += '\n\n' + e.stack;

					missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
					missingText.screenCenter(Y);
					missingText.visible = true;
					missingTextBG.visible = true;
					FlxG.sound.play(Paths.sound('cancelMenu'));

					super.update(elapsed);
					return;
				}


				menuItems = menuItemsOG;
				regenMenu();
			}

			switch (daSelected)
			{
				case "Resume":
					close();
				case 'Change Difficulty':
					menuItems = difficultyChoices;
					deleteSkipTimeText();
					regenMenu();
				case 'Toggle Practice Mode':
					PlayState.instance.practiceMode = !PlayState.instance.practiceMode;
					PlayState.changedDifficulty = true;
					practiceText.visible = PlayState.instance.practiceMode;
				case "Restart Song":
					restartSong();
				case "Leave Charting Mode":
					restartSong();
					PlayState.chartingMode = false;
				case 'Skip Time':
					if(curTime < Conductor.songPosition)
					{
						PlayState.startOnTime = curTime;
						restartSong(true);
					}
					else
					{
						if (curTime != Conductor.songPosition)
						{
							PlayState.instance.clearNotesBefore(curTime);
							PlayState.instance.setSongTime(curTime);
						}
						close();
					}
				case 'End Song':
					close();
					PlayState.instance.notes.clear();
					PlayState.instance.unspawnNotes = [];
					PlayState.instance.finishSong(true);
				case 'Toggle Botplay':
					PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
					PlayState.changedDifficulty = true;
					PlayState.instance.botplayTxt.visible = PlayState.instance.cpuControlled;
					PlayState.instance.botplayTxt.alpha = 1;
					PlayState.instance.botplaySine = 0;
				case 'Options':
					PlayState.instance.paused = true; // For lua
					PlayState.instance.vocals.volume = 0;
					PlayState.instance.canResync = false;
					MusicBeatState.switchState(new OptionsState());
					if(ClientPrefs.data.pauseMusic != 'None')
					{
						FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)), pauseMusic.volume);
						FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.8);
						FlxG.sound.music.time = pauseMusic.time;
					}
					OptionsState.onPlayState = true;
				case "Exit to menu":
					#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
					PlayState.deathCounter = 0;
					PlayState.seenCutscene = false;

					PlayState.instance.canResync = false;
					Mods.loadTopMod();
					if(PlayState.isStoryMode)
						MusicBeatState.switchState(new StoryMenuState());
					else 
						MusicBeatState.switchState(new FreeplayState());

					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					PlayState.changedDifficulty = false;
					PlayState.chartingMode = false;
					FlxG.camera.followLerp = 0;
			}
		}
	}

	function deleteSkipTimeText()
	{
		if(skipTimeText != null)
		{
			skipTimeText.kill();
			remove(skipTimeText);
			skipTimeText.destroy();
		}
		skipTimeText = null;
		skipTimeTracker = null;
	}

	public static function restartSong(noTrans:Bool = false)
	{
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

		if(noTrans)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		MusicBeatState.resetState();
	}

	override function destroy()
	{
		pauseMusic.destroy();
		super.destroy();
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);
		for (num => item in grpMenuShit.members)
		{
			item.setSelected(num == curSelected);
			if (num == curSelected && item == skipTimeTracker)
			{
				curTime = Math.max(0, Conductor.songPosition);
				updateSkipTimeText();
			}
		}
		missingText.visible = false;
		missingTextBG.visible = false;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	static final PAUSE_ACCENTS:Array<Int> = [CosmicBackground.ACCENT_CYAN, CosmicBackground.NEBULA_VIOLET, CosmicBackground.NEBULA_MAGENTA, CosmicBackground.NEBULA_TEAL];
	function regenMenu():Void {
		for (i in 0...grpMenuShit.members.length)
		{
			var obj:MenuButton = grpMenuShit.members[0];
			obj.kill();
			grpMenuShit.remove(obj, true);
			obj.destroy();
		}
		deleteSkipTimeText();

		for (num => str in menuItems) {
			var accent:Int = PAUSE_ACCENTS[num % PAUSE_ACCENTS.length];
			if(str == 'Exit to menu' || str == 'BACK') accent = 0xFFFF5C8A;
			var item:MenuButton = new MenuButton(str, Language.getPhrase('pause_$str', str), (num + 1 < 10 ? '0' : '') + (num + 1), accent, false);
			item.baseX = 50;
			item.introDelay = 0.04 * num;
			item.ID = num;
			grpMenuShit.add(item);

			if(str == 'Skip Time')
			{
				skipTimeText = new FlxText(0, 0, 0, '', 40);
				skipTimeText.setFormat(Paths.font("vcr.ttf"), 40, CosmicBackground.ACCENT_CYAN, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				skipTimeText.scrollFactor.set();
				skipTimeText.borderSize = 2;
				skipTimeTracker = item;
				add(skipTimeText);
			}
		}
		curSelected = 0;
		listY = targetListY();
		placeButtons();
		changeSelection();
		if(skipTimeText != null) { updateSkipTextStuff(); updateSkipTimeText(); }
	}

	inline function targetListY():Float
	{
		// keep the selected button around the middle of the screen, but don't scroll short lists
		var spacing:Float = 88;
		var total:Float = menuItems.length * spacing;
		var top:Float = 150;
		if(top + total <= FlxG.height - 60) return top;
		return Math.max(FlxG.height - 60 - total, Math.min(top, FlxG.height * 0.45 - curSelected * spacing));
	}

	function placeButtons()
	{
		for (num => item in grpMenuShit.members)
		{
			if(item == null) continue;
			item.y = listY + num * 88;
			var dist:Float = Math.abs(num - curSelected);
			item.alpha = (menuItems.length <= 6) ? 1 : Math.max(0.3, 1 - dist * 0.16);
		}
	}

	function updateCosmicVisuals(elapsed:Float)
	{
		starTime += elapsed;
		for (star in pauseStars)
		{
			star.alpha = 0.25 + 0.35 * (0.5 + 0.5 * Math.sin(starTime * 2.2 + star.ID * 1.7));
			star.y -= elapsed * (6 + (star.ID % 5) * 3);
			if(star.y < -4) { star.y = FlxG.height + 2; star.x = FlxG.random.float(0, FlxG.width); }
		}
		listY += (targetListY() - listY) * Math.min(1, elapsed * 12);
		placeButtons();
	}

	function updateSkipTextStuff()
	{
		if(skipTimeText == null || skipTimeTracker == null) return;

		skipTimeText.x = skipTimeTracker.x + 500;
		skipTimeText.y = skipTimeTracker.y + (76 - skipTimeText.height) / 2;
		skipTimeText.visible = (grpMenuShit.members.indexOf(skipTimeTracker) == curSelected);
	}

	function updateSkipTimeText()
		skipTimeText.text = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false) + ' / ' + FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false);
}
