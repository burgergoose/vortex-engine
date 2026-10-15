package states;

import backend.VortexConfig;
import objects.CosmicBackground;
import objects.MenuButton;
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
	var camFollow:FlxObject;

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

		var yScroll:Float = 0.25;
		// Vortex Engine: cosmic space backdrop replaces the stock menu background
		cosmicBg = new CosmicBackground(Std.int(FlxG.width), Std.int(FlxG.height), true, FlxG.width * 0.72);
		add(cosmicBg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		// Flash overlay used by the selection flicker (keeps the stock visible-toggle behaviour)
		magenta = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, CosmicBackground.NEBULA_MAGENTA);
		magenta.scrollFactor.set();
		magenta.alpha = 0.35;
		magenta.visible = false;
		add(magenta);

		menuItems = new FlxTypedGroup<MenuButton>();
		add(menuItems);

		// Vortex Engine: big title block, top left
		var nameParts:Array<String> = VortexConfig.engineName.toUpperCase().split(' ');
		var bigName:String = nameParts[0];
		var smallName:String = nameParts.length > 1 ? nameParts.slice(1).join(' ') : 'MAIN MENU';
		titleBig = new FlxText(56, 26, 700, bigName, 92);
		titleBig.setFormat(Paths.font("vcr.ttf"), 92, CosmicBackground.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, CosmicBackground.NEBULA_VIOLET);
		titleBig.borderSize = 4;
		titleBig.scrollFactor.set();
		add(titleBig);
		titleSmall = new FlxText(62, 118, 700, smallName, 28);
		titleSmall.setFormat(Paths.font("vcr.ttf"), 28, CosmicBackground.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleSmall.scrollFactor.set();
		add(titleSmall);

		var accents:Array<Int> = [CosmicBackground.NEBULA_VIOLET, CosmicBackground.ACCENT_CYAN, CosmicBackground.NEBULA_MAGENTA, CosmicBackground.NEBULA_TEAL, CosmicBackground.NEBULA_VIOLET];
		var gap:Float = 14;
		var startY:Float = 188 + (4 - optionShit.length) * 40;
		for (num => option in optionShit)
		{
			var btn:MenuButton = createMenuItem(option, 60, startY + num * (76 + gap), accents[num % accents.length], false, num);
			btn.introDelay = 0.12 + num * 0.09;
		}

		if (leftOption != null)
		{
			leftItem = createMenuItem(leftOption, 60, 612, CosmicBackground.NEBULA_TEAL, true, 0);
			leftItem.introDelay = 0.6;
		}
		if (rightOption != null)
		{
			rightItem = createMenuItem(rightOption, FlxG.width - 60 - 300, 612, CosmicBackground.NEBULA_MAGENTA, true, 0);
			rightItem.introDelay = 0.7;
		}

		var psychVer:FlxText = new FlxText(12, FlxG.height - 44, 0, VortexConfig.engineName + " v" + psychEngineVersion, 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
		var fnfVer:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);
		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		// Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != psychEngineVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		FlxG.camera.follow(camFollow, null, 0.15);
	}

	function createMenuItem(name:String, x:Float, y:Float, accent:Int, small:Bool, index:Int):MenuButton
	{
		var pretty:String = name.replace('_', ' ');
		var btn:MenuButton = new MenuButton(name, pretty, small ? '' : '0' + (index + 1), accent, small);
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
							selectedSomethin = false;
							item.visible = true;
						default:
							trace('Menu Item ${option} doesn\'t do anything');
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
		titleBig.borderColor = FlxColor.interpolate(CosmicBackground.NEBULA_VIOLET, CosmicBackground.ACCENT_CYAN, 0.5 + 0.5 * Math.sin(titleTime * 0.8));

		super.update(elapsed);
	}

	function changeItem(change:Int = 0)
	{
		if(change != 0) curColumn = CENTER;
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));

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
	}
}
