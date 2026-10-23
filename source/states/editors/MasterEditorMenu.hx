package states.editors;

import backend.WeekData;

import objects.Character;
import objects.CosmicBackground;
import objects.MenuButton;

import states.MainMenuState;
import states.FreeplayState;

/**
 * The Developer menu (7 on the main menu). Vortex Engine: remastered with the cosmic UI of the main menu
 * (same tools, same order, same keys: Up/Down pick a tool, Left/Right pick the mod folder, Enter opens,
 * Esc goes back; the mouse works too) and the Achievement Editor was added.
 */
class MasterEditorMenu extends MusicBeatState
{
	var options:Array<String> = [
		'Chart Editor',
		'Character Editor',
		'Stage Editor',
		'Week Editor',
		'Menu Character Editor',
		'Dialogue Editor',
		'Dialogue Portrait Editor',
		'Note Splash Editor'
		#if ACHIEVEMENTS_ALLOWED , 'Achievement Editor' #end
		, 'V-Slice Converter' // Vortex Engine 0.5
		, 'Menu Editor' // Vortex Engine 0.5
	];
	// Vortex Engine: shown next to the list for the selected tool
	static final descriptions:Map<String, String> = [
		'Chart Editor' => 'Place notes and events for a song, set the BPM, vocals and characters, and test-play it.',
		'Character Editor' => 'Set up a character\'s animations, offsets, health icon and colours.',
		'Stage Editor' => 'Build a stage: background pictures, layers and where the characters and camera stand.',
		'Week Editor' => 'Make a Story Mode week: its songs, characters, title picture and unlock order.',
		'Menu Character Editor' => 'Position and animate the characters shown in Story Mode.',
		'Dialogue Editor' => 'Write cutscene dialogue: lines, speakers, speed and box style.',
		'Dialogue Portrait Editor' => 'Set up the portraits used by the Dialogue Editor.',
		'Note Splash Editor' => 'Change how note splashes look and animate.',
		'Achievement Editor' => 'Make achievements for your mod: name, description, icon, unlock conditions and an attached Lua script.',
		'V-Slice Converter' => 'Turn a mod into a V-Slice mod folder (charts, metadata, characters, stages, levels, audio) and see what the Vortex compatibility layer found in it.',
		'Menu Editor' => 'Pick the menu theme: Vortex, Psych Classic or a custom menu from a mod (custom_menus/), with a preview, editing and a reset.'
	];
	var accents:Array<Int>; // Vortex Engine 0.5: set in create() (theme colours aren't known when the game boots)
	var classic:Bool = false;
	var classicItems:Array<Alphabet> = [];

	private var buttons:Array<MenuButton> = [];
	private var directories:Array<String> = [null];

	private var curSelected = 0;
	private var curDirectory = 0;
	private var directoryTxt:FlxText;
	var descTitle:FlxText;
	var descText:FlxText;
	var descAccent:FlxSprite;
	var chosen:Bool = false;

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Editors Main Menu", null);
		#end

		accents = [MenuTheme.NEBULA_VIOLET, MenuTheme.ACCENT_CYAN, MenuTheme.NEBULA_MAGENTA, MenuTheme.NEBULA_TEAL];
		classic = MenuTheme.isClassic;
		if (classic)
		{
			createClassic();
			super.create();
			return;
		}
		add(MenuTheme.background('developerMenu', true, FlxG.width * 0.78));

		var title:FlxText = new FlxText(60, 26, 0, Std.string(MenuTheme.screenValue('developerMenu', 'title', 'DEVELOPER')), 56);
		title.setFormat(MenuTheme.font(), 56, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, MenuTheme.NEBULA_VIOLET);
		title.borderSize = 3;
		add(title);
		var subtitle:FlxText = new FlxText(64, 84, 0, 'VORTEX ENGINE TOOLS', 20);
		subtitle.setFormat(MenuTheme.font(), 20, MenuTheme.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(subtitle);

		var startY:Float = 116;
		var step:Float = 50;
		for (i in 0...options.length)
		{
			var btn:MenuButton = new MenuButton(options[i], options[i], (i + 1 < 10 ? '0' : '') + (i + 1), accents[i % accents.length], true, 400, 44);
			btn.baseX = 60;
			btn.y = startY + i * step;
			btn.introDelay = 0.03 * i;
			btn.ID = i;
			add(btn);
			buttons.push(btn);
		}

		// description panel for the selected tool
		var panelX:Float = 520, panelY:Float = 122, panelW:Int = 400, panelH:Int = 150;
		var border:FlxSprite = new FlxSprite(panelX, panelY).makeGraphic(panelW, panelH, FlxColor.WHITE);
		border.color = MenuTheme.PANEL_BORDER_DIM;
		add(border);
		var fill:FlxSprite = new FlxSprite(panelX + 2, panelY + 2).makeGraphic(panelW - 4, panelH - 4, FlxColor.WHITE);
		fill.color = MenuTheme.PANEL_FILL;
		fill.alpha = 0.85;
		add(fill);
		descAccent = new FlxSprite(panelX + 2, panelY + 2).makeGraphic(6, panelH - 4, FlxColor.WHITE);
		add(descAccent);
		descTitle = new FlxText(panelX + 22, panelY + 14, panelW - 40, '', 22);
		descTitle.setFormat(MenuTheme.font(), 22, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(descTitle);
		descText = new FlxText(panelX + 22, panelY + 48, panelW - 40, '', 16);
		descText.setFormat(MenuTheme.font(), 16, MenuTheme.TEXT_DIM, LEFT);
		add(descText);

		#if MODS_ALLOWED
		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 42, FlxColor.WHITE);
		textBG.color = MenuTheme.PANEL_FILL;
		textBG.alpha = 0.85;
		add(textBG);
		var textLine:FlxSprite = new FlxSprite(0, FlxG.height - 44).makeGraphic(FlxG.width, 2, FlxColor.WHITE);
		textLine.color = MenuTheme.PANEL_BORDER_BRIGHT;
		add(textLine);

		directoryTxt = new FlxText(textBG.x, textBG.y + 8, FlxG.width, '', 24);
		directoryTxt.setFormat(MenuTheme.font(), 24, MenuTheme.ACCENT_CYAN, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);

		for (folder in Mods.getModDirectories())
		{
			directories.push(folder);
		}

		var found:Int = directories.indexOf(Mods.currentModDirectory);
		if(found > -1) curDirectory = found;
		changeDirectory();
		#end
		changeSelection();

		FlxG.mouse.visible = true;
		super.create();
	}

	override function update(elapsed:Float)
	{
		if(classic && !chosen)
		{
			if (controls.UI_UP_P) changeSelection(-1);
			if (controls.UI_DOWN_P) changeSelection(1);
			#if MODS_ALLOWED
			if (controls.UI_LEFT_P) changeDirectory(-1);
			if (controls.UI_RIGHT_P) changeDirectory(1);
			#end
			if (FlxG.mouse.wheel != 0) changeSelection(-FlxG.mouse.wheel);
			if (controls.BACK) MusicBeatState.switchState(new MainMenuState());
			if (controls.ACCEPT) openTool(options[curSelected]);
			super.update(elapsed);
			return;
		}
		if(!chosen)
		{
			if (controls.UI_UP_P)
			{
				changeSelection(-1);
			}
			if (controls.UI_DOWN_P)
			{
				changeSelection(1);
			}
			#if MODS_ALLOWED
			if(controls.UI_LEFT_P)
			{
				changeDirectory(-1);
			}
			if(controls.UI_RIGHT_P)
			{
				changeDirectory(1);
			}
			#end

			// Vortex Engine: mouse - hover picks a tool, click opens it, the wheel scrolls
			var mouseOn:Int = -1;
			if(FlxG.mouse.visible)
				for (btn in buttons)
				{
					var b = btn.bounds();
					if(FlxG.mouse.screenX >= b.x && FlxG.mouse.screenX <= b.x + b.w && FlxG.mouse.screenY >= b.y && FlxG.mouse.screenY <= b.y + b.h)
						mouseOn = btn.ID;
				}
			if(mouseOn > -1 && mouseOn != curSelected && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0))
				changeSelection(mouseOn - curSelected);
			if(FlxG.mouse.wheel != 0) changeSelection(-FlxG.mouse.wheel);

			if (controls.BACK)
			{
				MusicBeatState.switchState(new MainMenuState());
			}

			if (controls.ACCEPT || (FlxG.mouse.justPressed && mouseOn > -1))
				openTool(options[curSelected]);
		}
		super.update(elapsed);
	}

	function openTool(name:String)
	{
		chosen = true;
		FlxG.mouse.visible = false;
		switch(name) {
			case 'Chart Editor'://felt it would be cool maybe
				LoadingState.loadAndSwitchState(new ChartingState(), false);
			case 'Character Editor':
				LoadingState.loadAndSwitchState(new CharacterEditorState(Character.DEFAULT_CHARACTER, false));
			case 'Stage Editor':
				LoadingState.loadAndSwitchState(new StageEditorState());
			case 'Week Editor':
				MusicBeatState.switchState(new WeekEditorState());
			case 'Menu Character Editor':
				MusicBeatState.switchState(new MenuCharacterEditorState());
			case 'Dialogue Editor':
				LoadingState.loadAndSwitchState(new DialogueEditorState(), false);
			case 'Dialogue Portrait Editor':
				LoadingState.loadAndSwitchState(new DialogueCharacterEditorState(), false);
			case 'Note Splash Editor':
				MusicBeatState.switchState(new NoteSplashEditorState());
			#if ACHIEVEMENTS_ALLOWED
			case 'Achievement Editor':
				MusicBeatState.switchState(new AchievementEditorState());
			#end
			case 'V-Slice Converter':
				MusicBeatState.switchState(new VSliceConverterState());
			case 'Menu Editor':
				MusicBeatState.switchState(new MenuEditorState());
		}
		FlxG.sound.music.volume = 0;
		FreeplayState.destroyFreeplayVocals();
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
		if (classic)
		{
			for (i => item in classicItems)
			{
				item.targetY = i - curSelected;
				item.alpha = (item.targetY == 0) ? 1 : 0.6;
			}
			return;
		}
		for (btn in buttons) btn.setSelected(btn.ID == curSelected);

		var name:String = options[curSelected];
		descTitle.text = name.toUpperCase();
		descText.text = descriptions.exists(name) ? descriptions.get(name) : '';
		descAccent.color = accents[curSelected % accents.length];
	}

	#if MODS_ALLOWED
	function changeDirectory(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curDirectory += change;

		if(curDirectory < 0)
			curDirectory = directories.length - 1;
		if(curDirectory >= directories.length)
			curDirectory = 0;

		WeekData.setDirectoryFromWeek();
		if(directories[curDirectory] == null || directories[curDirectory].length < 1)
			directoryTxt.text = '< No Mod Directory Loaded >';
		else
		{
			Mods.currentModDirectory = directories[curDirectory];
			directoryTxt.text = '< Loaded Mod Directory: ' + Mods.currentModDirectory + ' >';
		}
		directoryTxt.text = directoryTxt.text.toUpperCase();
	}
	#end

	/** Vortex Engine 0.5: "Psych Classic" theme - Psych Engine's Alphabet list on a dark background. */
	function createClassic()
	{
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);
		for (i in 0...options.length)
		{
			var leText:Alphabet = new Alphabet(90, 320, options[i], true);
			leText.isMenuItem = true;
			leText.targetY = i;
			add(leText);
			leText.snapToPosition();
			classicItems.push(leText);
		}
		#if MODS_ALLOWED
		var textBG:FlxSprite = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 42, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);
		directoryTxt = new FlxText(textBG.x, textBG.y + 4, FlxG.width, '', 32);
		directoryTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);
		for (folder in Mods.getModDirectories()) directories.push(folder);
		var found:Int = directories.indexOf(Mods.currentModDirectory);
		if (found > -1) curDirectory = found;
		changeDirectory();
		#end
		changeSelection();
		FlxG.mouse.visible = false;
	}
}
