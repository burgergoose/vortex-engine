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
	// Vortex Engine: week panel extras (second track column, cleared/locked status, progress bar)
	var txtTracklist2:FlxText;
	var weekStatusText:FlxText;
	var weekProgressText:FlxText;
	var weekProgressBar:FlxSprite;
	var weekCounterText:FlxText;
	var storyTitleText:FlxText;
	static inline var HEADER_H:Int = 84;
	static inline var PANEL_X:Float = 700;
	static inline var PANEL_Y:Float = 446;
	var tracklistPanel:FlxSprite;
	var tracklistPanelBorder:FlxSprite;
	// Vortex Engine 0.5: menu themes (the Vortex-only decorations are hidden by Psych Classic)
	var classic:Bool = false;
	var vortexDecor:Array<FlxSprite> = [];
	var bgYellow:FlxSprite;
	var tracksSprite:FlxSprite;

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

		// Vortex Engine: cosmic backdrop (or the menu theme's), added first so everything else draws on top of it
		classic = MenuTheme.isClassic;
		if (!classic)
		{
			var bgObj = MenuTheme.background('storyMode');
			if (Std.isOfType(bgObj, CosmicBackground)) cosmicBg = cast bgObj;
			add(bgObj);
		}

		// Vortex Engine: kept for mod compatibility (per-week custom background image, see
		// changeWeek()) but shown as a faint backdrop layer now instead of full-opacity/full-screen,
		// so it doesn't fight the cosmic theme.
		bgSprite = new FlxSprite(0, 0);
		bgSprite.alpha = 0.22;
		bgSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(bgSprite);

		// Vortex Engine: header is taller and its text starts below the FPS counter (top-left corner);
		// the week score and week name moved into the week panel (bottom right)
		scoreBG = new FlxSprite(0, 0).makeGraphic(1, HEADER_H, FlxColor.WHITE);
		scoreBG.color = MenuTheme.PANEL_FILL;
		scoreBG.alpha = 0.92;
		scoreBG.scale.x = FlxG.width;
		scoreBG.updateHitbox();
		add(scoreBG);

		storyTitleText = new FlxText(40, 36, FlxG.width - 80, Std.string(MenuTheme.screenValue('storyMode', 'title', 'STORY MODE')), 36);
		storyTitleText.setFormat(MenuTheme.font(), 36, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(storyTitleText);

		var brandText:FlxText = new FlxText(0, 16, FlxG.width - 40, VortexConfig.engineName.toUpperCase(), 16);
		brandText.setFormat(MenuTheme.font(), 16, MenuTheme.TEXT_DIM, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(brandText);
		vortexDecor = [storyTitleText, brandText];

		weekCounterText = new FlxText(0, 42, FlxG.width - 40, "", 24);
		weekCounterText.setFormat(MenuTheme.font(), 24, MenuTheme.ACCENT_CYAN, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(weekCounterText);
		vortexDecor.push(weekCounterText);

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

				// Vortex Engine 0.6: a week can name its banner picture (V-Slice levels' titleAsset), else storymenu/<week>.png
				var banner:String = WeekData.weeksList[i];
				if (weekFile.bannerImage != null && weekFile.bannerImage.length > 0) banner = weekFile.bannerImage.startsWith('storymenu/') ? weekFile.bannerImage.substr(10) : '../' + weekFile.bannerImage;
				var card:WeekCard = new WeekCard(WeekData.weeksList[i], banner, Language.getPhrase('storyname_${weekFile.fileName}', weekFile.storyName));
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
		// unified cosmic look -- purely decorative, no data/compat impact). 0.4: the panel
		// also holds the week name, week score, cleared/locked status and a progress bar.
		var panelX:Float = PANEL_X;
		var panelY:Float = PANEL_Y;
		var panelW:Float = FlxG.width - panelX - 40;
		var panelH:Float = FlxG.height - panelY - 24;

		tracklistPanelBorder = new FlxSprite(panelX, panelY).makeGraphic(Std.int(panelW), Std.int(panelH), FlxColor.WHITE);
		tracklistPanelBorder.color = MenuTheme.PANEL_BORDER_DIM;
		add(tracklistPanelBorder);

		tracklistPanel = new FlxSprite(panelX + 2, panelY + 2).makeGraphic(Std.int(panelW - 4), Std.int(panelH - 4), FlxColor.WHITE);
		tracklistPanel.color = MenuTheme.PANEL_FILL;
		tracklistPanel.alpha = 0.78;
		add(tracklistPanel);

		var strip:FlxSprite = new FlxSprite(panelX + 2, panelY + 2).makeGraphic(Std.int(panelW - 4), 4, FlxColor.WHITE);
		strip.color = MenuTheme.PANEL_BORDER_BRIGHT;
		add(strip);
		vortexDecor.push(strip);

		txtWeekTitle = new FlxText(panelX + 20, panelY + 16, panelW - 170, "", 24);
		txtWeekTitle.setFormat(MenuTheme.font(), 24, MenuTheme.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(txtWeekTitle);

		weekStatusText = new FlxText(panelX + panelW - 150, panelY + 20, 130, "", 16);
		weekStatusText.setFormat(MenuTheme.font(), 16, MenuTheme.TEXT_BRIGHT, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(weekStatusText);

		scoreText = new FlxText(panelX + 20, panelY + 50, panelW - 40, "", 22);
		scoreText.setFormat(MenuTheme.font(), 22, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(scoreText);

		var barBg:FlxSprite = new FlxSprite(panelX + 20, panelY + 84).makeGraphic(Std.int(panelW - 40), 8, FlxColor.WHITE);
		barBg.color = MenuTheme.PANEL_BORDER_DIM;
		add(barBg);
		vortexDecor.push(barBg);
		weekProgressBar = new FlxSprite(panelX + 20, panelY + 84).makeGraphic(Std.int(panelW - 40), 8, FlxColor.WHITE);
		weekProgressBar.color = 0xFF6BFF95;
		weekProgressBar.origin.set(0, 0);
		add(weekProgressBar);

		weekProgressText = new FlxText(panelX + 20, panelY + 96, panelW - 40, "", 14);
		weekProgressText.setFormat(MenuTheme.font(), 14, MenuTheme.TEXT_DIM, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(weekProgressText);

		var line:FlxSprite = new FlxSprite(panelX + 20, panelY + 122).makeGraphic(Std.int(panelW - 40), 2, FlxColor.WHITE);
		line.color = MenuTheme.PANEL_BORDER_DIM;
		add(line);
		vortexDecor.push(line);

		var tracksLabel:FlxText = new FlxText(panelX + 20, panelY + 130, panelW - 40, "TRACKS", 16);
		tracksLabel.setFormat(MenuTheme.font(), 16, MenuTheme.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(tracksLabel);
		vortexDecor.push(tracksLabel);

		txtTracklist = new FlxText(panelX + 20, panelY + 152, (panelW - 40) / 2, "", 20);
		txtTracklist.setFormat(MenuTheme.font(), 20, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(txtTracklist);
		txtTracklist2 = new FlxText(panelX + 20 + (panelW - 40) / 2, panelY + 152, (panelW - 40) / 2, "", 20);
		txtTracklist2.setFormat(MenuTheme.font(), 20, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(txtTracklist2);
		vortexDecor = vortexDecor.concat([tracklistPanelBorder, tracklistPanel, weekStatusText, weekProgressText, weekProgressBar, txtTracklist2]);
		if (classic) applyClassicLayout();

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

		// Vortex Engine (UI polish), placed before super.update() so each card sets its members' alpha from the new value: cards fly in from the left one after another, the selected one slides out a little
		introTime += elapsed;
		var offY:Float = grpWeekText.members[curWeek].targetY;
		for (num => item in grpWeekText.members)
		{
			item.y = FlxMath.lerp(item.targetY - offY + WEEK_FOCUS_Y, item.y, Math.exp(-elapsed * 10.2));
			var t:Float = Math.max(0, Math.min(1, (introTime - 0.08 * Math.abs(num - curWeek)) / 0.5));
			var intro:Float = 1 - Math.pow(1 - t, 3);
			item.x = WEEK_LIST_X + item.selectNudge() - (1 - intro) * 520;
			// Vortex Engine: cards above the selected one fade out instead of sliding behind the week characters and
			// the header (the original's yellow band used to cover them)
			var above:Float = Math.max(0, Math.min(1, (item.y - (WEEK_FOCUS_Y - 150)) / 140));
			if (classic)
			{
				// Psych Classic: banners centred, the yellow band covers the ones above
				item.x = (FlxG.width - WeekCard.CARD_WIDTH) / 2;
				item.alpha = (num == curWeek) ? 1 : 0.6;
				continue;
			}
			item.alpha = Math.max(0.001, (num == curWeek ? 1.0 : 0.7) * intro * above);
		}
		super.update(elapsed);
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
		// Vortex Engine: some weeks (the base Tutorial) have an empty storyName
		if(leName == null || leName.trim().length < 1) leName = leWeek.weekName;
		if(leName == null || leName.trim().length < 1) leName = leWeek.fileName;
		txtWeekTitle.text = leName.toUpperCase();
		if (classic) txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);

		var unlocked:Bool = !weekIsLocked(leWeek.fileName);
		for (num => item in grpWeekText.members)
			item.setSelected(num == curWeek && unlocked);

		bgSprite.visible = true;
		var assetName:String = leWeek.weekBackground;
		if(assetName == null || assetName.length < 1) {
			bgSprite.visible = false;
		} else {
			// Vortex Engine: a missing picture used to show Flixel's placeholder logo in the corner
			var weekBg = Paths.image('menubackgrounds/menu_' + assetName);
			if(weekBg != null) bgSprite.loadGraphic(weekBg);
			else bgSprite.visible = false;
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

		// Vortex Engine: up to 4 tracks per column, two columns; anything past 8 becomes "+N MORE"
		var col1:Array<String> = [];
		var col2:Array<String> = [];
		var cleared:Int = 0;
		for (i in 0...stringThing.length)
		{
			var done:Bool = Highscore.isCompleted(stringThing[i], curDifficulty);
			if (done) cleared++;
			var line:String = (done ? '* ' : '') + stringThing[i].toUpperCase();
			if (i < 4) col1.push(line);
			else if (i < 7 || stringThing.length == 8) col2.push(line);
			else if (i == 7) col2.push('+' + (stringThing.length - 7) + ' MORE');
		}
		txtTracklist.text = col1.join('\n');
		txtTracklist2.text = col2.join('\n');
		if (classic)
		{
			txtTracklist.text = [for (n in stringThing) n.toUpperCase()].join('\n');
			txtTracklist.screenCenter(X);
			txtTracklist.x -= FlxG.width * 0.35;
			txtTracklist2.text = '';
		}

		weekCounterText.text = 'WEEK ${curWeek + 1} / ${loadedWeeks.length}';
		var total:Int = stringThing.length;
		weekProgressBar.scale.x = total > 0 ? Math.max(0.0001, cleared / total) : 0.0001;
		if (weekIsLocked(leWeek.fileName))
		{
			var before:WeekData = WeekData.weeksLoaded.get(leWeek.weekBefore);
			var beforeName:String = before != null ? Language.getPhrase('storyname_${before.fileName}', before.storyName) : leWeek.weekBefore;
			weekStatusText.text = 'LOCKED';
			weekStatusText.color = 0xFFFF5C77;
			weekProgressText.text = 'Beat "' + beforeName + '" to unlock this week.';
		}
		else
		{
			var weekDone:Bool = weekCompleted.exists(leWeek.fileName) && weekCompleted.get(leWeek.fileName);
			if (total > 0 && cleared >= total) weekDone = true; // every song beaten (in Freeplay counts too)
			weekStatusText.text = weekDone ? 'CLEARED' : (cleared > 0 ? 'IN PROGRESS' : 'NEW');
			weekStatusText.color = weekDone ? 0xFF6BFF95 : MenuTheme.ACCENT_CYAN;
			weekProgressText.text = '$cleared / $total songs cleared' + (cleared > 0 ? '  (* = cleared)' : '');
		}

		#if !switch
		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
		#end
	}

	/** Vortex Engine 0.5: "Psych Classic" theme - Psych Engine 1.0's Story Mode look (black bar, yellow band with the
		week characters, week banners below, pink tracklist). Same weeks, keys and logic. */
	function applyClassicLayout()
	{
		for (d in vortexDecor) if (d != null) d.visible = false;
		var black:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		insert(0, black);

		scoreBG.makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		scoreBG.scale.set(1, 1);
		scoreBG.updateHitbox();
		scoreBG.alpha = 1;
		scoreBG.color = FlxColor.WHITE;

		bgYellow = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		insert(members.indexOf(grpWeekCharacters), bgYellow);
		remove(bgSprite, true);
		bgSprite.y = 56;
		bgSprite.alpha = 1;
		insert(members.indexOf(grpWeekCharacters), bgSprite);
		for (c in grpWeekCharacters) c.y -= 20;

		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT);
		scoreText.setPosition(10, 10);
		txtWeekTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.fieldWidth = 0;
		txtWeekTitle.setPosition(FlxG.width * 0.7, 10);
		txtWeekTitle.alpha = 0.7;
		remove(scoreText, true); add(scoreText);
		remove(txtWeekTitle, true); add(txtWeekTitle);

		tracksSprite = new FlxSprite(FlxG.width * 0.07 + 100, bgYellow.y + 425).loadGraphic(Paths.image('Menu_Tracks'));
		tracksSprite.antialiasing = ClientPrefs.data.antialiasing;
		tracksSprite.x -= tracksSprite.width / 2;
		add(tracksSprite);
		txtTracklist.setFormat(Paths.font("vcr.ttf"), 32, 0xFFe55777, CENTER);
		txtTracklist.fieldWidth = 0;
		txtTracklist.y = tracksSprite.y + 60;
		remove(txtTracklist, true); add(txtTracklist);

		for (card in grpWeekText) card.setClassic(true);
		// the band and black bar cover banners that scroll up
		remove(grpWeekText, true);
		insert(members.indexOf(bgYellow), grpWeekText);
		remove(scoreBG, true);
		insert(members.indexOf(scoreText), scoreBG);
	}
}
