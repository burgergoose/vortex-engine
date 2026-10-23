package states;

import backend.VortexConfig;
import objects.CosmicBackground;
import objects.MenuButton;
import objects.GlassPanel;
import objects.KeyHints;
import backend.WeekData;
import backend.Highscore;
import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;

enum MainMenuColumn {
	LEFT;
	CENTER;
	RIGHT;
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '0.1.0'; // Vortex Engine: real value applied from VortexConfig.engineVersion in Main.hx at startup. Also used for Discord RPC / the outdated-version check.
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;
	var allowMouse:Bool = true; //Turn this off to block mouse movement in menus

	var menuItems:FlxTypedGroup<MenuButton>;
	var leftItem:MenuButton;
	var rightItem:MenuButton;
	var titleBig:FlxText;
	var titleSmall:FlxText;
	var titleTime:Float = 0;

	//Centered/Text options
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		'credits'
	];

	var leftOption:String = #if ACHIEVEMENTS_ALLOWED 'achievements' #else null #end;
	var rightOption:String = 'options';

	var magenta:FlxSprite;
	var cosmicBg:CosmicBackground;
	// Vortex Engine 0.5: menu themes
	var classic:Bool = false;
	var showInfo:Bool = true;
	var wrapSelection:Bool = true;
	var classicItems:FlxTypedGroup<FlxSprite>;
	var classicLeft:FlxSprite;
	var classicRight:FlxSprite;
	var camFollow:FlxObject;

	// Vortex Engine: info panel on the right (what the selected option does + your progress)
	static inline var PANEL_X:Float = 800;
	static inline var PANEL_Y:Float = 170;
	static inline var PANEL_W:Int = 420;
	static inline var PANEL_H:Int = 400;
	var infoPanel:GlassPanel;
	var infoTitle:FlxText;
	var infoDesc:FlxText;
	var infoStats:Array<FlxText> = [];
	var infoHints:KeyHints;
	var infoFade:Float = 1;
	var accentFor:Map<String, Int> = [];

	/** Text shown in the info panel for each option. Mods can add their own from a state script (MainMenuState.optionInfo.set('my_option', '...')). */
	public static var optionInfo:Map<String, String> = [
		'story_mode' => 'Play the weeks in order, cutscenes included. Your score for the whole week is saved.',
		'freeplay' => 'Pick any unlocked song and play it on its own. Press SPACE there to listen to it first.',
		'mods' => 'Turn mods on or off and change the order they load in.',
		'credits' => 'The people behind Vortex Engine, Psych Engine and Friday Night Funkin\'.',
		'achievements' => 'See the achievements you have unlocked, including ones added by mods.',
		'options' => 'Controls, graphics, gameplay, visuals and other settings.',
		'donate' => 'Support the original Friday Night Funkin\' team.'
	];

	static var showOutdatedWarning:Bool = true;
	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;

		// Vortex Engine 0.5: menu themes (Developer menu -> Menu Editor). Mods may have been enabled since the last visit.
		MenuTheme.load();
		MenuTheme.apply();
		classic = MenuTheme.isClassic;
		if (classic)
		{
			createClassic();
			afterCreate();
			return;
		}
		var mm:Dynamic = MenuTheme.screen('mainMenu');
		showInfo = (mm == null || mm.showInfoPanel != false);
		if (mm != null && mm.navigation != null)
		{
			if (mm.navigation.wrap == false) wrapSelection = false;
			if (mm.navigation.mouse == false) allowMouse = false;
		}

		var yScroll:Float = 0.25;
		// Vortex Engine: cosmic space backdrop replaces the stock menu background (or the custom theme's background)
		var bgObj = MenuTheme.background('mainMenu', true, showInfo ? PANEL_X + PANEL_W / 2 : FlxG.width * 0.72); // rings frame the info panel
		if (Std.isOfType(bgObj, CosmicBackground)) cosmicBg = cast bgObj;
		add(bgObj);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		// Flash overlay used by the selection flicker (keeps the stock visible-toggle behaviour)
		magenta = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, MenuTheme.NEBULA_MAGENTA);
		magenta.scrollFactor.set();
		magenta.alpha = 0.35;
		magenta.visible = false;
		add(magenta);

		menuItems = new FlxTypedGroup<MenuButton>();
		add(menuItems);

		if (showInfo) buildInfoPanel();

		// Vortex Engine: big title block, top left
		var nameParts:Array<String> = VortexConfig.engineName.toUpperCase().split(' ');
		var bigName:String = nameParts[0];
		var smallName:String = nameParts.length > 1 ? nameParts.slice(1).join(' ') : 'MAIN MENU';
		titleBig = new FlxText(56, 26, 700, bigName, 92);
		titleBig.setFormat(MenuTheme.font(), 92, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, MenuTheme.NEBULA_VIOLET);
		titleBig.borderSize = 4;
		titleBig.scrollFactor.set();
		add(titleBig);
		titleSmall = new FlxText(62, 118, 700, smallName, 28);
		titleSmall.setFormat(MenuTheme.font(), 28, MenuTheme.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleSmall.scrollFactor.set();
		add(titleSmall);
		if (mm != null)
		{
			if (mm.title != null) titleBig.text = Std.string(mm.title);
			if (mm.subtitle != null) titleSmall.text = Std.string(mm.subtitle);
			if (mm.logo != null)
			{
				var logo:FlxSprite = (Type.typeof(mm.logo) == TObject) ? MenuTheme.animatedSprite(mm.logo) : MenuTheme.image(Std.string(mm.logo));
				if (logo != null)
				{
					if (Type.typeof(mm.logo) != TObject)
					{
						var fit:Float = Math.min(1, Math.min(620 / logo.width, 150 / logo.height));
						logo.scale.set(fit, fit);
						logo.updateHitbox();
						logo.setPosition(56, 16);
					}
					add(logo);
					titleBig.visible = titleSmall.visible = false;
				}
			}
		}

		var accents:Array<Int> = [MenuTheme.NEBULA_VIOLET, MenuTheme.ACCENT_CYAN, MenuTheme.NEBULA_MAGENTA, MenuTheme.NEBULA_TEAL, MenuTheme.NEBULA_VIOLET];
		var gap:Float = 14;
		var startY:Float = 188 + (4 - optionShit.length) * 40;
		var bx:Float = 60;
		var bw:Null<Int> = null;
		if (mm != null && mm.buttons != null)
		{
			var b:Dynamic = mm.buttons;
			if (b.spacing != null) gap = Std.parseFloat(Std.string(b.spacing));
			if (b.y != null) startY = Std.parseFloat(Std.string(b.y));
			if (b.width != null) bw = Std.int(Math.max(200, Math.min(900, Std.parseFloat(Std.string(b.width)))));
			var w:Float = (bw != null) ? bw : 470;
			var ox:Float = (b.x != null) ? Std.parseFloat(Std.string(b.x)) : 60;
			bx = switch (Std.string(b.align)) { case 'center': (FlxG.width - w) / 2 + ((b.x != null) ? ox : 0); case 'right': FlxG.width - w - ox - 36; default: ox; };
		}
		for (num => option in optionShit)
		{
			var btn:MenuButton = createMenuItem(option, bx, startY + num * (76 + gap), accents[num % accents.length], false, num, bw);
			btn.introDelay = 0.12 + num * 0.09;
		}

		if (leftOption != null)
		{
			leftItem = createMenuItem(leftOption, 60, 612, MenuTheme.NEBULA_TEAL, true, 0);
			leftItem.introDelay = 0.6;
		}
		if (rightOption != null)
		{
			rightItem = createMenuItem(rightOption, FlxG.width - 60 - 300, 612, MenuTheme.NEBULA_MAGENTA, true, 0);
			rightItem.introDelay = 0.7;
		}

		var psychVer:FlxText = new FlxText(12, FlxG.height - 44, 0, VortexConfig.engineName + " v" + psychEngineVersion, 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(MenuTheme.font(), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
		// Vortex Engine: the app version in Project.xml is the engine's version now, so the FNF version is written here
		var fnfVer:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v0.2.8", 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(MenuTheme.font(), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);
		if (mm != null && mm.showVersion == false) psychVer.visible = fnfVer.visible = false;
		changeItem();
		afterCreate();
	}

	/** Vortex Engine 0.5: the end of create(), shared by the Vortex / custom and Psych Classic layouts. */
	function afterCreate()
	{

		#if ACHIEVEMENTS_ALLOWED
		// Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		if (infoPanel != null) refreshStats();

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != psychEngineVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		FlxG.camera.follow(camFollow, null, 0.15);
	}

	function createMenuItem(name:String, x:Float, y:Float, accent:Int, small:Bool, index:Int, ?width:Null<Int>):MenuButton
	{
		var pretty:String = name.replace('_', ' ');
		var labels:Dynamic = MenuTheme.screenValue('mainMenu', 'labels', null); // Vortex Engine 0.5: custom theme labels / icons
		if (labels != null && Reflect.field(labels, name) != null) pretty = Std.string(Reflect.field(labels, name));
		var btn:MenuButton = new MenuButton(name, pretty, small ? '' : '0' + (index + 1), accent, small, small ? null : width);
		var icons:Dynamic = MenuTheme.screenValue('mainMenu', 'icons', null);
		if (icons != null && Reflect.field(icons, name) != null) btn.setIcon(MenuTheme.image(Std.string(Reflect.field(icons, name))));
		accentFor.set(name, accent);
		btn.baseX = x;
		btn.y = y;
		menuItems.add(btn);
		return btn;
	}

	var selectedSomethin:Bool = false;

	var timeNotMoving:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);
		if (classic) { updateClassic(elapsed); return; }

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			var allowMouse:Bool = allowMouse;
			if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed)) //FlxG.mouse.deltaScreenX/Y checks is more accurate than FlxG.mouse.justMoved
			{
				allowMouse = false;
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:MenuButton;
				switch(curColumn)
				{
					case CENTER:
						selectedItem = menuItems.members[curSelected];
					case LEFT:
						selectedItem = leftItem;
					case RIGHT:
						selectedItem = rightItem;
				}

				if(leftItem != null && FlxG.mouse.overlaps(leftItem))
				{
					allowMouse = true;
					if(selectedItem != leftItem)
					{
						curColumn = LEFT;
						changeItem();
					}
				}
				else if(rightItem != null && FlxG.mouse.overlaps(rightItem))
				{
					allowMouse = true;
					if(selectedItem != rightItem)
					{
						curColumn = RIGHT;
						changeItem();
					}
				}
				else
				{
					var dist:Float = -1;
					var distItem:Int = -1;
					for (i in 0...optionShit.length)
					{
						var memb:MenuButton = menuItems.members[i];
						if(FlxG.mouse.overlaps(memb))
						{
							var distance:Float = Math.abs(memb.midY() - FlxG.mouse.screenY);
							if (dist < 0 || distance < dist)
							{
								dist = distance;
								distItem = i;
								allowMouse = true;
							}
						}
					}

					if(distItem != -1 && selectedItem != menuItems.members[distItem])
					{
						curColumn = CENTER;
						curSelected = distItem;
						changeItem();
					}
				}
			}
			else
			{
				timeNotMoving += elapsed;
				if(timeNotMoving > 2) FlxG.mouse.visible = false;
			}

			switch(curColumn)
			{
				case CENTER:
					if(controls.UI_LEFT_P && leftOption != null)
					{
						curColumn = LEFT;
						changeItem();
					}
					else if(controls.UI_RIGHT_P && rightOption != null)
					{
						curColumn = RIGHT;
						changeItem();
					}

				case LEFT:
					if(controls.UI_RIGHT_P)
					{
						curColumn = CENTER;
						changeItem();
					}

				case RIGHT:
					if(controls.UI_LEFT_P)
					{
						curColumn = CENTER;
						changeItem();
					}
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT || (FlxG.mouse.justPressed && allowMouse))
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				selectedSomethin = true;
				FlxG.mouse.visible = false;

				if (ClientPrefs.data.flashing)
					FlxFlicker.flicker(magenta, 1.1, 0.15, false);

				var item:MenuButton;
				var option:String;
				switch(curColumn)
				{
					case CENTER:
						option = optionShit[curSelected];
						item = menuItems.members[curSelected];

					case LEFT:
						option = leftOption;
						item = leftItem;

					case RIGHT:
						option = rightOption;
						item = rightItem;
				}

				FlxFlicker.flicker(item, 1, 0.06, false, false, function(flick:FlxFlicker)
				{
					if (!openOption(option))
					{
						selectedSomethin = false;
						item.visible = true;
					}
				});
				
				for (memb in menuItems)
				{
					if(memb == item)
						continue;

					FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
				}
			}
			#if desktop
			if (controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
		}

		// Vortex Engine: title drops in and its outline colour slowly breathes between violet and cyan
		titleTime += elapsed;
		var tIn:Float = Math.max(0, Math.min(1, titleTime / 0.6));
		var tE:Float = 1 - Math.pow(1 - tIn, 3);
		titleBig.y = 26 - 90 * (1 - tE);
		titleBig.alpha = tE;
		titleSmall.alpha = tE;
		titleBig.borderColor = FlxColor.interpolate(MenuTheme.NEBULA_VIOLET, MenuTheme.ACCENT_CYAN, 0.5 + 0.5 * Math.sin(titleTime * 0.8));

		if (infoPanel != null) updateInfoPanel(elapsed);
		super.update(elapsed);
	}

	// Vortex Engine: info panel slides in from the right, its text fades in when the selection changes
	function updateInfoPanel(elapsed:Float)
	{
		var pIn:Float = Math.max(0, Math.min(1, (titleTime - 0.3) / 0.6));
		var pE:Float = 1 - Math.pow(1 - pIn, 3);
		var slide:Float = (1 - pE) * 480;
		infoFade = Math.min(1, infoFade + elapsed * 6);
		infoPanel.x = PANEL_X + slide;
		infoPanel.alpha = Math.max(0.001, pE);
		infoHints.x = PANEL_X + slide;
		infoHints.alpha = Math.max(0.001, pE);
		for (t in [infoTitle, infoDesc])
		{
			t.x = PANEL_X + 24 + slide + (1 - infoFade) * 12;
			t.alpha = pE * infoFade;
		}
		for (t in infoStats)
		{
			t.x = PANEL_X + 24 + slide;
			t.alpha = pE;
		}
	}

	/** Opens a menu option. Returns false if it doesn't lead anywhere (the menu stays usable). */
	function openOption(option:String):Bool
	{
		switch (option)
		{
			case 'story_mode':
				MusicBeatState.switchState(new StoryMenuState());
			case 'freeplay':
				MusicBeatState.switchState(new FreeplayState());

			#if MODS_ALLOWED
			case 'mods':
				MusicBeatState.switchState(new ModsMenuState());
			#end

			#if ACHIEVEMENTS_ALLOWED
			case 'achievements':
				MusicBeatState.switchState(new AchievementsMenuState());
			#end

			case 'credits':
				MusicBeatState.switchState(new CreditsState());
			case 'options':
				MusicBeatState.switchState(new OptionsState());
				OptionsState.onPlayState = false;
				if (PlayState.SONG != null)
				{
					PlayState.SONG.arrowSkin = null;
					PlayState.SONG.splashSkin = null;
					PlayState.stageUI = 'normal';
				}
			case 'donate':
				CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
				return false;
			default:
				trace('Menu Item ${option} doesn\'t do anything');
				return false;
		}
		return true;
	}

	function changeItem(change:Int = 0, playSound:Bool = true)
	{
		if (classic) { changeClassicItem(change, playSound); return; }
		if(change != 0) curColumn = CENTER;
		curSelected = wrapSelection ? FlxMath.wrap(curSelected + change, 0, optionShit.length - 1) : Std.int(FlxMath.bound(curSelected + change, 0, optionShit.length - 1));
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'));

		for (item in menuItems)
			item.setSelected(false);

		var selectedItem:MenuButton;
		switch(curColumn)
		{
			case CENTER:
				selectedItem = menuItems.members[curSelected];
			case LEFT:
				selectedItem = leftItem;
			case RIGHT:
				selectedItem = rightItem;
		}
		selectedItem.setSelected(true);
		camFollow.y = selectedItem.midY();
		showOptionInfo(selectedItem.optionName);
	}

	// Vortex Engine: right-hand info panel
	function buildInfoPanel():Void
	{
		infoPanel = new GlassPanel(PANEL_X, PANEL_Y, PANEL_W, PANEL_H, null, 0.66);
		add(infoPanel);

		infoTitle = new FlxText(PANEL_X + 24, PANEL_Y + 26, PANEL_W - 48, '', 32);
		infoTitle.setFormat(MenuTheme.font(), 32, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoTitle.scrollFactor.set();
		add(infoTitle);

		infoDesc = new FlxText(PANEL_X + 24, PANEL_Y + 72, PANEL_W - 48, '', 18);
		infoDesc.setFormat(MenuTheme.font(), 18, MenuTheme.TEXT_DIM, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoDesc.scrollFactor.set();
		add(infoDesc);

		var line:FlxSprite = new FlxSprite(PANEL_X + 24, PANEL_Y + 170).makeGraphic(PANEL_W - 48, 2, FlxColor.WHITE);
		line.color = MenuTheme.PANEL_BORDER_DIM;
		line.scrollFactor.set();
		add(line);

		var label:FlxText = new FlxText(PANEL_X + 24, PANEL_Y + 184, PANEL_W - 48, 'YOUR PROGRESS', 14);
		label.setFormat(MenuTheme.font(), 14, MenuTheme.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.scrollFactor.set();
		add(label);

		for (i in 0...4)
		{
			var name:FlxText = new FlxText(PANEL_X + 24, PANEL_Y + 210 + i * 34, PANEL_W - 48, '', 18);
			name.setFormat(MenuTheme.font(), 18, MenuTheme.TEXT_DIM, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			name.scrollFactor.set();
			add(name);
			var value:FlxText = new FlxText(PANEL_X + 24, PANEL_Y + 210 + i * 34, PANEL_W - 48, '', 18);
			value.setFormat(MenuTheme.font(), 18, MenuTheme.TEXT_BRIGHT, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			value.scrollFactor.set();
			add(value);
			infoStats.push(name);
			infoStats.push(value);
		}

		infoHints = new KeyHints(PANEL_X, PANEL_Y + PANEL_H - 40, PANEL_W, [['ARROWS', 'Move'], ['ENTER', 'Select'], ['ESC', 'Back']]);
		add(infoHints);
	}

	function showOptionInfo(option:String):Void
	{
		if (infoPanel == null) return;
		var pretty:String = option.replace('_', ' ').toUpperCase();
		var accent:Int = accentFor.exists(option) ? accentFor.get(option) : MenuTheme.PANEL_BORDER_BRIGHT;
		var custom:Dynamic = MenuTheme.screenValue('mainMenu', 'labels', null);
		if (custom != null && Reflect.field(custom, option) != null) pretty = Std.string(Reflect.field(custom, option)).toUpperCase();
		infoTitle.text = pretty;
		infoTitle.color = FlxColor.interpolate(accent, MenuTheme.TEXT_BRIGHT, 0.35);
		infoPanel.setAccent(accent);
		var texts:Dynamic = MenuTheme.screenValue('mainMenu', 'infoText', null);
		infoDesc.text = (texts != null && Reflect.field(texts, option) != null) ? Std.string(Reflect.field(texts, option)) : (optionInfo.exists(option) ? optionInfo.get(option) : '');
		infoFade = 0;
	}

	/** Counts what the player has done so far. Read-only: only looks at saved scores, weeks and achievements. */
	function refreshStats():Void
	{
		var rows:Array<Array<String>> = [];
		try
		{
			WeekData.reloadWeekFiles(false);
			var storyWeeks:Int = 0;
			var weeksDone:Int = 0;
			var seen:Map<String, Bool> = [];
			var songsDone:Int = 0;
			for (name in WeekData.weeksList)
			{
				var week:WeekData = WeekData.weeksLoaded.get(name);
				if (week == null) continue;
				if (!week.hideStoryMode)
				{
					storyWeeks++;
					if (StoryMenuState.weekCompleted.exists(name) && StoryMenuState.weekCompleted.get(name)) weeksDone++;
				}
				for (song in week.songs)
				{
					var key:String = Paths.formatToSongPath(Std.string(song[0]));
					if (seen.exists(key)) continue;
					seen.set(key, true);
					// Normal is the only difficulty; mods that only ship a -hard / -easy chart save under that name
					for (k in [key, key + '-hard', key + '-easy'])
						if (Highscore.songCompleted.get(k) == true) { songsDone++; break; }
				}
			}
			var songTotal:Int = Lambda.count(seen);
			rows.push(['Weeks cleared', '$weeksDone / $storyWeeks']);
			rows.push(['Songs cleared', '$songsDone / $songTotal']);
		}
		catch (e:Dynamic)
		{
			trace('Main menu stats: $e');
		}
		Mods.loadTopMod();

		#if ACHIEVEMENTS_ALLOWED
		var achTotal:Int = 0;
		var achDone:Int = 0;
		for (name => ach in Achievements.achievements)
		{
			achTotal++;
			if (Achievements.isUnlocked(name)) achDone++;
		}
		rows.push(['Achievements', '$achDone / $achTotal']);
		#end

		#if MODS_ALLOWED
		rows.push(['Mods enabled', Std.string(Mods.parseList().enabled.length)]);
		#end

		for (i in 0...Std.int(infoStats.length / 2))
		{
			var row:Array<String> = i < rows.length ? rows[i] : ['', ''];
			infoStats[i * 2].text = row[0];
			infoStats[i * 2 + 1].text = row[1];
		}
	}

	// =================================================================================================================
	// Vortex Engine 0.5: "Psych Classic" theme - the Psych Engine 1.0 main menu layout (scrolling menuBG, big animated
	// option sprites, magenta flash, Achievements / Options in the bottom corners). Same options, keys and mouse.
	// =================================================================================================================
	function createClassic()
	{
		var yScroll:Float = 0.25;
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		classicItems = new FlxTypedGroup<FlxSprite>();
		add(classicItems);
		for (num => option in optionShit)
		{
			var item:FlxSprite = classicItem(option, 0, (num * 140) + 90);
			item.scrollFactor.set(0, optionShit.length < 6 ? 0 : (optionShit.length - 4) * 0.135);
			item.screenCenter(X);
			classicItems.add(item);
		}
		if (leftOption != null) { classicLeft = classicItem(leftOption, 60, 490); classicLeft.scrollFactor.set(); add(classicLeft); }
		if (rightOption != null)
		{
			classicRight = classicItem(rightOption, FlxG.width - 60, 490);
			classicRight.x -= classicRight.width;
			classicRight.scrollFactor.set();
			add(classicRight);
		}

		var psychVer:FlxText = new FlxText(12, FlxG.height - 44, 0, VortexConfig.engineName + " v" + psychEngineVersion, 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
		var fnfVer:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v0.2.8", 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);
		changeClassicItem(0, false);
	}

	function classicItem(name:String, x:Float, y:Float):FlxSprite
	{
		var item:FlxSprite = new FlxSprite(x, y);
		item.frames = Paths.getSparrowAtlas('mainmenu/menu_' + name);
		item.animation.addByPrefix('idle', name + ' idle', 24, true);
		item.animation.addByPrefix('selected', name + ' selected', 24, true);
		item.animation.play('idle');
		item.updateHitbox();
		item.antialiasing = ClientPrefs.data.antialiasing;
		item.scrollFactor.set();
		return item;
	}

	function classicSelected():FlxSprite
	{
		return switch (curColumn)
		{
			case CENTER: classicItems.members[curSelected];
			case LEFT: classicLeft;
			case RIGHT: classicRight;
		}
	}

	function changeClassicItem(change:Int = 0, playSound:Bool = true)
	{
		if (change != 0) curColumn = CENTER;
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		if (playSound) FlxG.sound.play(Paths.sound('scrollMenu'));
		var all:Array<FlxSprite> = classicItems.members.copy();
		if (classicLeft != null) all.push(classicLeft);
		if (classicRight != null) all.push(classicRight);
		for (item in all)
		{
			item.animation.play('idle');
			item.centerOffsets();
		}
		var sel:FlxSprite = classicSelected();
		if (sel == null) { curColumn = CENTER; sel = classicItems.members[curSelected]; }
		sel.animation.play('selected');
		sel.centerOffsets();
		camFollow.y = sel.getGraphicMidpoint().y - (classicItems.length > 4 ? classicItems.length * 8 : 0);
	}

	function updateClassic(elapsed:Float)
	{
		if (!selectedSomethin)
		{
			if (controls.UI_UP_P) changeClassicItem(-1);
			if (controls.UI_DOWN_P) changeClassicItem(1);

			if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed))
			{
				FlxG.mouse.visible = true;
				timeNotMoving = 0;
				if (classicLeft != null && FlxG.mouse.overlaps(classicLeft)) { if (curColumn != LEFT) { curColumn = LEFT; changeClassicItem(); } }
				else if (classicRight != null && FlxG.mouse.overlaps(classicRight)) { if (curColumn != RIGHT) { curColumn = RIGHT; changeClassicItem(); } }
				else for (i in 0...classicItems.length)
					if (FlxG.mouse.overlaps(classicItems.members[i]) && (curColumn != CENTER || curSelected != i))
					{
						curColumn = CENTER;
						curSelected = i;
						changeClassicItem();
						break;
					}
			}
			else
			{
				timeNotMoving += elapsed;
				if (timeNotMoving > 2) FlxG.mouse.visible = false;
			}

			switch (curColumn)
			{
				case CENTER:
					if (controls.UI_LEFT_P && classicLeft != null) { curColumn = LEFT; changeClassicItem(); }
					else if (controls.UI_RIGHT_P && classicRight != null) { curColumn = RIGHT; changeClassicItem(); }
				case LEFT:
					if (controls.UI_RIGHT_P) { curColumn = CENTER; changeClassicItem(); }
				case RIGHT:
					if (controls.UI_LEFT_P) { curColumn = CENTER; changeClassicItem(); }
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			var sel:FlxSprite = classicSelected();
			if (controls.ACCEPT || (FlxG.mouse.justPressed && sel != null && FlxG.mouse.overlaps(sel)))
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				if (ClientPrefs.data.flashing) FlxFlicker.flicker(magenta, 1.1, 0.15, false);
				var option:String = switch (curColumn) { case CENTER: optionShit[curSelected]; case LEFT: leftOption; case RIGHT: rightOption; };
				FlxFlicker.flicker(sel, 1, 0.06, false, false, function(flick:FlxFlicker)
				{
					if (!openOption(option)) { selectedSomethin = false; sel.visible = true; }
				});
				for (memb in classicItems) if (memb != sel) FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
			}
			#if desktop
			if (controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
		}
		super.update(elapsed);
	}
}
