package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.VortexConfig;

import flixel.group.FlxGroup;
import flixel.graphics.FlxGraphic;

import objects.MenuCharacter;
import objects.WeekCard;
import objects.CosmicBackground;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import backend.StageData;

class StoryMenuState extends MusicBeatState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();

	var scoreText:FlxText;
	var scoreBG:FlxSprite;

	var curDifficulty:Int = 1;

	var txtWeekTitle:FlxText;
	var bgSprite:FlxSprite;
	var cosmicBg:CosmicBackground;

	private static var curWeek:Int = 0;

	var txtTracklist:FlxText;
	var tracklistPanel:FlxSprite;
	var tracklistPanelBorder:FlxSprite;

	var grpWeekText:FlxTypedGroup<WeekCard>;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;

	var loadedWeeks:Array<WeekData> = [];

	static inline var WEEK_LIST_X:Float = 40;
	static inline var WEEK_FOCUS_Y:Float = 470;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		persistentUpdate = persistentDraw = true;
		PlayState.isStoryMode = true;
		WeekData.reloadWeekFiles(true);

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR STORY MODE\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		if(curWeek >= WeekData.weeksList.length) curWeek = 0;

		// Vortex Engine: cosmic backdrop, added first so everything else draws on top of it
		cosmicBg = new CosmicBackground(Std.int(FlxG.width), Std.int(FlxG.height));
		add(cosmicBg);

		// Vortex Engine: kept for mod compatibility (per-week custom background image, see
		// changeWeek()) but shown as a faint backdrop layer now instead of full-opacity/full-screen,
		// so it doesn't fight the cosmic theme.
		bgSprite = new FlxSprite(0, 0);
		bgSprite.alpha = 0.22;
		bgSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(bgSprite);

		scoreBG = new FlxSprite(0, 0).makeGraphic(1, 74, FlxColor.WHITE);
		scoreBG.color = CosmicBackground.PANEL_FILL;
		scoreBG.alpha = 0.7;
		scoreBG.scale.x = FlxG.width;
		scoreBG.updateHitbox();
		add(scoreBG);

		scoreText = new FlxText(40, 12, FlxG.width - 80, "", 26);
		scoreText.setFormat(Paths.font("vcr.ttf"), 26, CosmicBackground.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(scoreText);

		var brandText:FlxText = new FlxText(0, 12, FlxG.width - 40, VortexConfig.engineName.toUpperCase() + " — STORY MODE", 26);
		brandText.setFormat(Paths.font("vcr.ttf"), 26, CosmicBackground.TEXT_DIM, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(brandText);

		txtWeekTitle = new FlxText(40, 44, FlxG.width - 80, "", 22);
		txtWeekTitle.setFormat(Paths.font("vcr.ttf"), 22, CosmicBackground.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(txtWeekTitle);

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();

		grpWeekText = new FlxTypedGroup<WeekCard>();
		add(grpWeekText);

		var num:Int = 0;
		var itemTargetY:Float = 0;
		for (i in 0...WeekData.weeksList.length)
		{
			var weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var isLocked:Bool = weekIsLocked(WeekData.weeksList[i]);
			if(!isLocked || !weekFile.hiddenUntilUnlocked)
			{
				loadedWeeks.push(weekFile);
				WeekData.setDirectoryFromWeek(weekFile);

				var card:WeekCard = new WeekCard(WeekData.weeksList[i], WeekData.weeksList[i], Language.getPhrase('storyname_${weekFile.fileName}', weekFile.storyName));
				card.x = WEEK_LIST_X;
				card.y = WEEK_FOCUS_Y; // real position is set every frame in update(), same formula as the original
				card.ID = num;
				card.targetY = itemTargetY;
				itemTargetY += WeekCard.CARD_HEIGHT + 16;
				card.setLocked(isLocked);
				grpWeekText.add(card);

				num++;
			}
		}

		WeekData.setDirectoryFromWeek(loadedWeeks[0]);
		var charArray:Array<String> = loadedWeeks[0].weekCharacters;
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charArray[char]);
			weekCharacterThing.y += 90;
			grpWeekCharacters.add(weekCharacterThing);
		}

		Difficulty.resetList();

		add(grpWeekCharacters);

		// Vortex Engine: tracklist now sits in its own cosmic glass panel on the right,
		// instead of the original's Menu_Tracks decorative image (dropped in favor of the
		// unified cosmic look -- purely decorative, no data/compat impact).
		var panelX:Float = 700;
		var panelY:Float = 452;
		var panelW:Float = FlxG.width - panelX - 40;
		var panelH:Float = FlxG.height - panelY - 36;

		tracklistPanelBorder = new FlxSprite(panelX, panelY).makeGraphic(Std.int(panelW), Std.int(panelH), FlxColor.WHITE);
		tracklistPanelBorder.color = CosmicBackground.PANEL_BORDER_DIM;
		add(tracklistPanelBorder);

		tracklistPanel = new FlxSprite(panelX + 2, panelY + 2).makeGraphic(Std.int(panelW - 4), Std.int(panelH - 4), FlxColor.WHITE);
		tracklistPanel.color = CosmicBackground.PANEL_FILL;
		tracklistPanel.alpha = 0.72;
		add(tracklistPanel);

		var tracksLabel:FlxText = new FlxText(panelX + 20, panelY + 10, panelW - 40, "TRACKS", 20);
		tracksLabel.setFormat(Paths.font("vcr.ttf"), 20, CosmicBackground.ACCENT_CYAN, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(tracksLabel);

		txtTracklist = new FlxText(panelX + 20, panelY + 38, panelW - 40, "", 24);
		txtTracklist.setFormat(Paths.font("vcr.ttf"), 24, CosmicBackground.TEXT_BRIGHT, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(txtTracklist);

		changeWeek();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence -- Vortex Engine: names the actual week instead of a generic "In the Menus"
		var weekName:String = Language.getPhrase('storyname_${loadedWeeks[curWeek].fileName}', loadedWeeks[curWeek].storyName);
		DiscordClient.changePresence("In Story Mode", weekName);
		#end

		super.create();
	}

	override function closeSubState() {
		persistentUpdate = true;
		changeWeek();
		super.closeSubState();
	}

	override function update(elapsed:Float)
	{
		if(WeekData.weeksList.length < 1)
		{
			if (controls.BACK && !movedBack && !selectedWeek)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				movedBack = true;
				MusicBeatState.switchState(new MainMenuState());
			}
			super.update(elapsed);
			return;
		}

		if(intendedScore != lerpScore)
		{
			lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 30)));
			if(Math.abs(intendedScore - lerpScore) < 10) lerpScore = intendedScore;

			scoreText.text = Language.getPhrase('week_score', 'WEEK SCORE: {1}', [lerpScore]);
		}

		if (!movedBack && !selectedWeek)
		{
			if (controls.UI_UP_P)
			{
				changeWeek(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}

			if (controls.UI_DOWN_P)
			{
				changeWeek(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}

			if(FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				changeWeek(-FlxG.mouse.wheel);
			}
			// Vortex Engine: difficulty arrows/key-handling removed here (was UI_LEFT/UI_RIGHT press
			// anims + UI_LEFT_P/UI_RIGHT_P -> changeDifficulty()). changeWeek() now resolves curDifficulty
			// and intendedScore by itself, so there's nothing left to refresh after a week change either.

			// click a week card to select it (playing it still needs ENTER, same as keyboard nav)
			for (num => item in grpWeekText.members)
			{
				if (num != curWeek && FlxG.mouse.justPressed && FlxG.mouse.overlaps(item))
				{
					changeWeek(num - curWeek);
					FlxG.sound.play(Paths.sound('scrollMenu'));
					break;
				}
			}

			if(FlxG.keys.justPressed.CONTROL)
			{
				persistentUpdate = false;
				openSubState(new GameplayChangersSubstate());
			}
			else if(controls.RESET)
			{
				persistentUpdate = false;
				openSubState(new ResetScoreSubState('', curDifficulty, '', curWeek));
				//FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			else if (controls.ACCEPT)
				selectWeek();
		}

		if (controls.BACK && !movedBack && !selectedWeek)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			movedBack = true;
			MusicBeatState.switchState(new MainMenuState());
		}

		super.update(elapsed);

		// Vortex Engine (UI polish): cards fly in from the left one after another, the selected one slides out a little
		introTime += elapsed;
		var offY:Float = grpWeekText.members[curWeek].targetY;
		for (num => item in grpWeekText.members)
		{
			item.y = FlxMath.lerp(item.targetY - offY + WEEK_FOCUS_Y, item.y, Math.exp(-elapsed * 10.2));
			var t:Float = Math.max(0, Math.min(1, (introTime - 0.08 * Math.abs(num - curWeek)) / 0.5));
			var intro:Float = 1 - Math.pow(1 - t, 3);
			item.x = WEEK_LIST_X + item.selectNudge() - (1 - intro) * 520;
			item.alpha = Math.max(0.001, (num == curWeek ? 1.0 : 0.7) * intro);
		}
	}

	var introTime:Float = 0;
	var movedBack:Bool = false;
	var selectedWeek:Bool = false;
	var stopspamming:Bool = false;

	function selectWeek()
	{
		if (!weekIsLocked(loadedWeeks[curWeek].fileName))
		{
			// We can't use Dynamic Array .copy() because that crashes HTML5, here's a workaround.
			var songArray:Array<String> = [];
			var leWeek:Array<Dynamic> = loadedWeeks[curWeek].songs;
			for (i in 0...leWeek.length) {
				songArray.push(leWeek[i][0]);
			}

			// Nevermind that's stupid lmao
			try
			{
				PlayState.storyPlaylist = songArray;
				PlayState.isStoryMode = true;
				selectedWeek = true;
	
				var diffic = Difficulty.getFilePath(curDifficulty);
				if(diffic == null) diffic = '';
	
				PlayState.storyDifficulty = curDifficulty;
	
				Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
				PlayState.campaignScore = 0;
				PlayState.campaignMisses = 0;
			}
			catch(e:Dynamic)
			{
				trace('ERROR! $e');
				selectedWeek = false; // otherwise the menu stays locked after a failed load
				// Vortex Engine: tell the player why the week didn't start instead of doing nothing
				FlxG.sound.play(Paths.sound('cancelMenu'));
				Main.showToast('Could not load this week\'s first song:\n' + Std.string(e).split('\n')[0] + '\nCheck the chart (.json) in mods/<your mod>/data/<song>/');
				return;
			}
			
			if (stopspamming == false)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));

				grpWeekText.members[curWeek].bannerItem.isFlashing = true;
				for (char in grpWeekCharacters.members)
				{
					if (char.character != '' && char.hasConfirmAnimation)
					{
						char.animation.play('confirm');
					}
				}
				stopspamming = true;
			}

			var directory = StageData.forceNextDirectory;
			LoadingState.loadNextDirectory();
			StageData.forceNextDirectory = directory;

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			new FlxTimer().start(1, function(tmr:FlxTimer)
			{
				#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
				LoadingState.loadAndSwitchState(new PlayState(), true);
				FreeplayState.destroyFreeplayVocals();
			});
			
			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else FlxG.sound.play(Paths.sound('cancelMenu'));
	}

	var lerpScore:Int = 49324858;
	var intendedScore:Int = 0;

	function changeWeek(change:Int = 0):Void
	{
		curWeek += change;

		if (curWeek >= loadedWeeks.length)
			curWeek = 0;
		if (curWeek < 0)
			curWeek = loadedWeeks.length - 1;

		var leWeek:WeekData = loadedWeeks[curWeek];
		WeekData.setDirectoryFromWeek(leWeek);

		var leName:String = Language.getPhrase('storyname_${leWeek.fileName}', leWeek.storyName);
		txtWeekTitle.text = leName.toUpperCase();

		var unlocked:Bool = !weekIsLocked(leWeek.fileName);
		for (num => item in grpWeekText.members)
			item.setSelected(num == curWeek && unlocked);

		bgSprite.visible = true;
		var assetName:String = leWeek.weekBackground;
		if(assetName == null || assetName.length < 1) {
			bgSprite.visible = false;
		} else {
			bgSprite.loadGraphic(Paths.image('menubackgrounds/menu_' + assetName));
		}
		PlayState.storyWeek = curWeek;

		Difficulty.loadFromWeek();

		if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;
		if(leWeek.songs != null && leWeek.songs.length > 0)
			curDifficulty = Difficulty.pickAvailable(Std.string(leWeek.songs[0][0]), curDifficulty); // mods that only ship a -hard / -easy chart

		#if !switch
		intendedScore = Highscore.getWeekScore(leWeek.fileName, curDifficulty);
		#end

		updateText();
	}

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore)));
	}

	function updateText()
	{
		var weekArray:Array<String> = loadedWeeks[curWeek].weekCharacters;
		for (i in 0...grpWeekCharacters.length) {
			grpWeekCharacters.members[i].changeCharacter(weekArray[i]);
		}

		var leWeek:WeekData = loadedWeeks[curWeek];
		var stringThing:Array<String> = [];
		for (i in 0...leWeek.songs.length) {
			stringThing.push(leWeek.songs[i][0]);
		}

		txtTracklist.text = '';
		for (i in 0...stringThing.length)
		{
			txtTracklist.text += stringThing[i] + '\n';
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		#if !switch
		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
		#end
	}
}
