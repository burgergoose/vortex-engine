package states.editors;

import flixel.FlxCamera;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.group.FlxGroup;
import objects.GlassPanel;
import objects.KeyHints;
import objects.MenuButton;

/**
 * VORTEX ENGINE ADDITION (0.5) - Developer menu -> Menu Editor.
 *
 * Three themes: Vortex (cosmic, default), Psych Classic (Psych Engine's own menus) and Custom (a mod's
 * custom_menus/menu.json). The preview on the left draws the main menu of the highlighted theme; ENTER uses it
 * (main menu, Freeplay, Story Mode, Developer menu, Chart Editor). For Custom, the panel on the right edits the
 * most-used menu.json settings (Save writes them; everything else in the file is kept), lists problems, and can
 * create a starter custom_menus/ folder in the mod picked in the Developer menu. R resets to the Vortex theme.
 */
class MenuEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	static final THEMES:Array<String> = [MenuTheme.VORTEX, MenuTheme.PSYCH, MenuTheme.CUSTOM];
	static final NAMES:Array<String> = ['VORTEX THEME', 'PSYCH CLASSIC', 'CUSTOM THEME'];
	static final DESCS:Array<String> = [
		'The cosmic Vortex Engine menus.',
		'The menus of the original Psych Engine.',
		'A mod\'s custom_menus/ folder: your colours, font, background, layout, icons...'
	];

	var cur:Int = 0;
	var cards:Array<GlassPanel> = [];
	var cardTexts:Array<FlxText> = [];
	var activeTags:Array<FlxText> = [];

	var previewCam:FlxCamera;
	var previewGroup:FlxGroup;
	var previewFrame:FlxSprite;
	var problemsText:FlxText;
	var statusText:FlxText;
	var infoText:FlxText;

	var customMods:Array<String> = [];
	var customMod:String = '';
	var editGroup:FlxSpriteGroup;
	var modDropDown:PsychUIDropDownMenu;
	var nameInput:PsychUIInputText;
	var fontInput:PsychUIInputText;
	var autoCheck:PsychUICheckBox;
	var colorInputs:Map<String, PsychUIInputText> = [];
	var bgTypeDrop:PsychUIDropDownMenu;
	var bgColor1:PsychUIInputText;
	var bgColor2:PsychUIInputText;
	var bgImage:PsychUIInputText;
	var btnSteppers:Map<String, PsychUINumericStepper> = [];
	var alignDrop:PsychUIDropDownMenu;
	var titleInput:PsychUIInputText;
	var subtitleInput:PsychUIInputText;
	var introDrop:PsychUIDropDownMenu;
	var speedStepper:PsychUINumericStepper;
	var transDrop:PsychUIDropDownMenu;
	var transStepper:PsychUINumericStepper;
	var lastPreviewErrors:Array<String> = [];
	var lastPreviewWarnings:Array<String> = [];

	static inline var PX:Float = 560;
	static inline var PY:Float = 226;

	override function create()
	{
		super.create(); // first: it resets the cameras, and the preview camera is added below
		FlxG.mouse.visible = true;
		MenuTheme.load();
		MenuTheme.apply(true);
		add(MenuTheme.background('developerMenu'));

		var title:FlxText = new FlxText(40, 22, 0, 'MENU EDITOR', 40);
		title.setFormat(MenuTheme.font(), 40, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, MenuTheme.NEBULA_VIOLET);
		title.borderSize = 2;
		add(title);
		var sub:FlxText = new FlxText(44, 66, FlxG.width - 88, 'Main menu, Freeplay, Story Mode, Developer menu and Chart Editor follow the theme you pick.', 16);
		sub.setFormat(MenuTheme.font(), 16, MenuTheme.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(sub);

		for (i in 0...3)
		{
			var card:GlassPanel = new GlassPanel(40 + i * 405, 96, 390, 110);
			add(card);
			cards.push(card);
			var t:FlxText = new FlxText(60 + i * 405, 110, 350, NAMES[i] + '\n', 22);
			t.setFormat(MenuTheme.font(), 22, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(t);
			var d:FlxText = new FlxText(60 + i * 405, 142, 350, DESCS[i], 14);
			d.setFormat(MenuTheme.font(), 14, MenuTheme.TEXT_DIM, LEFT);
			add(d);
			cardTexts.push(t);
			var tag:FlxText = new FlxText(40 + i * 405 + 250, 110, 120, 'IN USE', 14);
			tag.setFormat(MenuTheme.font(), 14, 0xFF6BFF95, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(tag);
			activeTags.push(tag);
		}

		// preview: a second camera showing a 1280x720 mock main menu at 3/8 size
		previewFrame = new FlxSprite(36, 222).makeGraphic(488, 278, MenuTheme.PANEL_BORDER_BRIGHT);
		add(previewFrame);
		// flixel draws a camera at width x zoom on screen: 1280x720 of the world shown in a 480x270 box
		previewCam = new FlxCamera(40, 226, 1280, 720, 0.375);
		previewCam.bgColor = FlxColor.BLACK;
		FlxG.cameras.add(previewCam, false);
		previewGroup = new FlxGroup();
		previewGroup.cameras = [previewCam];
		add(previewGroup);
		var pl:FlxText = new FlxText(40, 504, 480, 'PREVIEW (main menu)', 12);
		pl.setFormat(MenuTheme.font(), 12, MenuTheme.TEXT_DIM, LEFT);
		add(pl);
		problemsText = new FlxText(40, 522, 480, '', 13);
		problemsText.setFormat(MenuTheme.font(), 13, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(problemsText);

		add(new GlassPanel(PX - 10, PY - 6, Std.int(FlxG.width - PX - 30), 440));
		infoText = new FlxText(PX + 10, PY + 14, FlxG.width - PX - 70, '', 16);
		infoText.setFormat(MenuTheme.font(), 16, MenuTheme.TEXT_DIM, LEFT);
		add(infoText);

		buildEditPanel();

		statusText = new FlxText(PX, FlxG.height - 66, FlxG.width - PX - 20, '', 14);
		statusText.setFormat(MenuTheme.font(), 14, MenuTheme.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(statusText);
		var bar:FlxSprite = new FlxSprite(0, FlxG.height - 36).makeGraphic(FlxG.width, 36, FlxColor.BLACK);
		bar.alpha = 0.6;
		add(bar);
		add(new KeyHints(0, FlxG.height - 29, FlxG.width, [['LEFT / RIGHT', 'Pick theme'], ['ENTER', 'Use it'], ['R', 'Reset to Vortex'], ['ESC', 'Back']]));

		cur = Std.int(Math.max(0, THEMES.indexOf(MenuTheme.selected)));
		customMods = MenuTheme.modsWithCustomMenus();
		customMod = (MenuTheme.selectedMod != null && customMods.contains(MenuTheme.selectedMod)) ? MenuTheme.selectedMod : (customMods.length > 0 ? customMods[0] : '');
		refreshModList();
		select(cur);
	}

	override function destroy()
	{
		if (previewCam != null && FlxG.cameras.list.contains(previewCam)) FlxG.cameras.remove(previewCam);
		super.destroy();
	}

	override function update(elapsed:Float)
	{
		var typing:Bool = PsychUIInputText.focusOn != null;
		if (!typing)
		{
			if (controls.UI_LEFT_P) select(cur - 1);
			if (controls.UI_RIGHT_P) select(cur + 1);
			if (controls.ACCEPT) useTheme();
			if (FlxG.keys.justPressed.C) createTemplate();
			if (FlxG.keys.justPressed.R)
			{
				MenuTheme.reset();
				statusText.text = 'Reset: the Vortex theme is in use again.';
				FlxG.sound.play(Paths.sound('cancelMenu'));
				select(0);
			}
			if (controls.BACK)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MasterEditorMenu());
			}
		}
		if (FlxG.mouse.justPressed)
			for (i in 0...cards.length)
				if (FlxG.mouse.overlaps(cards[i]) && i != cur) select(i);
		super.update(elapsed);
	}

	function select(i:Int)
	{
		var old:Int = cur;
		cur = FlxMath.wrap(i, 0, THEMES.length - 1);
		if (old != cur) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		for (j in 0...cards.length) cards[j].setBorderColor(j == cur ? MenuTheme.PANEL_BORDER_BRIGHT : MenuTheme.PANEL_BORDER_DIM);
		for (j in 0...activeTags.length) activeTags[j].visible = (THEMES[j] == MenuTheme.active);
		var theme:String = THEMES[cur];
		editGroup.visible = editGroup.active = (theme == MenuTheme.CUSTOM && customMod.length > 0);
		infoText.visible = !editGroup.visible;
		switch (theme)
		{
			case MenuTheme.VORTEX:
				infoText.text = 'VORTEX THEME\n\nThe default cosmic menus: glass buttons, the vortex rings, song and week info panels.\n\nENTER uses it.';
			case MenuTheme.PSYCH:
				infoText.text = 'PSYCH CLASSIC\n\nThe menus of the original Psych Engine: the yellow menu background with the big animated buttons, '
					+ 'the Freeplay song list on a colour-changing background, the Story Mode yellow band and Psych\'s developer menu. '
					+ 'The Chart Editor switches to Psych\'s grey look.\n\nEverything works the same; only the look changes. ENTER uses it.';
			default:
				if (customMods.length < 1)
					infoText.text = 'CUSTOM THEME\n\nNo enabled mod has a custom_menus/menu.json yet.\n\nPress C to create a starter custom_menus/ folder in the mod picked in the Developer menu ('
						+ (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0 ? Mods.currentModDirectory : 'none picked - go back and pick one with LEFT / RIGHT') + ').';
		}
		rebuildPreview();
	}

	function useTheme()
	{
		var theme:String = THEMES[cur];
		if (theme == MenuTheme.CUSTOM && customMod.length < 1) { statusText.text = 'Create or enable a mod with custom_menus/ first.'; FlxG.sound.play(Paths.sound('cancelMenu')); return; }
		MenuTheme.set(theme, theme == MenuTheme.CUSTOM ? customMod : '');
		if (theme == MenuTheme.CUSTOM && MenuTheme.active != MenuTheme.CUSTOM)
		{
			statusText.text = 'The custom menu has problems (listed on the left), so the ' + (MenuTheme.active == MenuTheme.PSYCH ? 'Psych Classic' : 'Vortex') + ' theme is used.';
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
		else
		{
			statusText.text = NAMES[cur] + ' is now in use' + (theme == MenuTheme.CUSTOM ? ' (mods/$customMod/custom_menus/)' : '') + '. It applies to menus you open from now on.';
			FlxG.sound.play(Paths.sound('confirmMenu'));
		}
		select(cur);
	}

	// ------------------------------------------------------------------ preview
	function rebuildPreview()
	{
		for (m in previewGroup.members) if (m != null) m.destroy();
		previewGroup.clear();
		var theme:String = THEMES[cur];
		var res = MenuTheme.preview(theme, customMod, function() buildMockMenu(theme));
		lastPreviewErrors = res.errors.copy();
		lastPreviewWarnings = res.warnings.copy();
		var b:StringBuf = new StringBuf();
		if (theme == MenuTheme.CUSTOM)
		{
			if (customMods.length < 1) b.add('No custom menu to preview.');
			else if (lastPreviewErrors.length > 0)
			{
				b.add('NOT USABLE (${lastPreviewErrors.length} problem' + (lastPreviewErrors.length == 1 ? '' : 's') + ') - the preview shows the fallback theme:\n');
				for (e in lastPreviewErrors.slice(0, 4)) b.add('- $e\n');
				if (lastPreviewErrors.length > 4) b.add('... ${lastPreviewErrors.length - 4} more in vortex_script_log.txt\n');
			}
			else b.add('mods/$customMod/custom_menus/menu.json loads without errors.\n');
			if (lastPreviewWarnings.length > 0) b.add('${lastPreviewWarnings.length} warning(s), e.g. ' + lastPreviewWarnings[0] + '\n');
		}
		problemsText.text = b.toString();
		for (m in previewGroup.members) if (m != null) setCameras(m);
	}

	function setCameras(b:FlxBasic)
	{
		b.cameras = [previewCam];
		if (Std.isOfType(b, FlxTypedGroup)) for (m in (cast b : FlxTypedGroup<FlxBasic>).members) if (m != null) setCameras(m);
		if (Std.isOfType(b, FlxSpriteGroup)) for (m in (cast b : FlxSpriteGroup).members) if (m != null) m.cameras = [previewCam];
	}

	function buildMockMenu(theme:String)
	{
		var options:Array<String> = ['story_mode', 'freeplay', 'mods', 'credits'];
		if (MenuTheme.isClassic)
		{
			var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuBG'));
			bg.setGraphicSize(Std.int(bg.width * 1.175));
			bg.updateHitbox();
			bg.screenCenter();
			previewGroup.add(bg);
			for (num => option in options)
			{
				var item:FlxSprite = new FlxSprite(0, num * 140 + 90);
				item.frames = Paths.getSparrowAtlas('mainmenu/menu_' + option);
				item.animation.addByPrefix('idle', option + (num == 0 ? ' selected' : ' idle'), 24, true);
				item.animation.play('idle');
				item.updateHitbox();
				item.screenCenter(X);
				previewGroup.add(item);
			}
			return;
		}
		previewGroup.add(MenuTheme.background('mainMenu', true, FlxG.width * 0.72));
		var mm:Dynamic = MenuTheme.screen('mainMenu');
		var big:FlxText = new FlxText(56, 26, 700, 'VORTEX', 92);
		big.setFormat(MenuTheme.font(), 92, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, MenuTheme.NEBULA_VIOLET);
		big.borderSize = 4;
		var small:FlxText = new FlxText(62, 118, 700, 'ENGINE', 28);
		small.setFormat(MenuTheme.font(), 28, MenuTheme.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		if (mm != null && mm.title != null) big.text = Std.string(mm.title);
		if (mm != null && mm.subtitle != null) small.text = Std.string(mm.subtitle);
		var logo:FlxSprite = null;
		if (mm != null && mm.logo != null)
		{
			logo = (Type.typeof(mm.logo) == TObject) ? MenuTheme.animatedSprite(mm.logo) : MenuTheme.image(Std.string(mm.logo));
			if (logo != null && Type.typeof(mm.logo) != TObject)
			{
				var fit:Float = Math.min(1, Math.min(620 / logo.width, 150 / logo.height));
				logo.scale.set(fit, fit);
				logo.updateHitbox();
				logo.setPosition(56, 16);
			}
		}
		if (logo != null) previewGroup.add(logo);
		else { previewGroup.add(big); previewGroup.add(small); }

		var accents:Array<Int> = [MenuTheme.NEBULA_VIOLET, MenuTheme.ACCENT_CYAN, MenuTheme.NEBULA_MAGENTA, MenuTheme.NEBULA_TEAL];
		var gap:Float = 14, startY:Float = 188, bx:Float = 60;
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
		for (num => option in options)
		{
			var label:String = option.replace('_', ' ');
			if (mm != null && mm.labels != null && Reflect.field(mm.labels, option) != null) label = Std.string(Reflect.field(mm.labels, option));
			var btn:MenuButton = new MenuButton(option, label, '0' + (num + 1), accents[num % accents.length], false, bw);
			btn.baseX = bx;
			btn.y = startY + num * (76 + gap);
			btn.introDelay = 0.05 * num;
			if (mm != null && mm.icons != null && Reflect.field(mm.icons, option) != null) btn.setIcon(MenuTheme.image(Std.string(Reflect.field(mm.icons, option))));
			btn.setSelected(num == 0);
			previewGroup.add(btn);
		}
		if (mm == null || mm.showInfoPanel != false)
		{
			var panel:GlassPanel = new GlassPanel(800, 170, 420, 400, null, 0.66);
			previewGroup.add(panel);
			var t:FlxText = new FlxText(824, 196, 372, 'STORY MODE', 32);
			t.setFormat(MenuTheme.font(), 32, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			previewGroup.add(t);
		}
	}

	// ------------------------------------------------------------------ custom menu editing
	function buildEditPanel()
	{
		editGroup = new FlxSpriteGroup();
		add(editGroup);
		function label(x:Float, y:Float, text:String)
		{
			var t:FlxText = new FlxText(x, y, 0, text, 8);
			editGroup.add(t);
		}
		label(PX + 10, PY, 'Custom menu of mod:');
		editGroup.add(new PsychUIButton(PX + 230, PY + 12, 'Reload', function() { MenuTheme.apply(true); loadFields(); rebuildPreview(); statusText.text = 'Reloaded menu.json.'; }, 70));
		editGroup.add(new PsychUIButton(PX + 310, PY + 12, 'Save menu.json', saveFields, 100));
		editGroup.add(new PsychUIButton(PX + 420, PY + 12, 'New template (C)', createTemplate, 110));
		editGroup.add(new PsychUIButton(PX + 540, PY + 12, 'Open folder', function() {
			#if sys if (customMod.length > 0) CoolUtil.openFolder(Paths.mods('$customMod/custom_menus/')); #end
		}, 90));

		label(PX + 10, PY + 42, 'Name:');
		nameInput = new PsychUIInputText(PX + 10, PY + 56, 200, '', 8);
		editGroup.add(nameInput);
		label(PX + 230, PY + 42, 'Font (assets/ or game font):');
		fontInput = new PsychUIInputText(PX + 230, PY + 56, 200, '', 8);
		editGroup.add(fontInput);
		autoCheck = new PsychUICheckBox(PX + 450, PY + 52, 'Use automatically', 120);
		editGroup.add(autoCheck);

		var i:Int = 0;
		for (key in MenuTheme.COLOR_KEYS)
		{
			var cx:Float = PX + 10 + (i % 3) * 225, cy:Float = PY + 84 + Std.int(i / 3) * 34;
			label(cx, cy, 'colors.$key:');
			var input:PsychUIInputText = new PsychUIInputText(cx, cy + 14, 110, '', 8);
			colorInputs.set(key, input);
			editGroup.add(input);
			i++;
		}

		label(PX + 10, PY + 190, 'Background:');
		label(PX + 135, PY + 190, 'Colour 1:');
		bgColor1 = new PsychUIInputText(PX + 135, PY + 204, 100, '', 8);
		editGroup.add(bgColor1);
		label(PX + 250, PY + 190, 'Colour 2 (gradient):');
		bgColor2 = new PsychUIInputText(PX + 250, PY + 204, 100, '', 8);
		editGroup.add(bgColor2);
		label(PX + 365, PY + 190, 'Image (in assets/):');
		bgImage = new PsychUIInputText(PX + 365, PY + 204, 160, '', 8);
		editGroup.add(bgImage);

		var keys:Array<String> = ['x', 'y', 'spacing', 'width'];
		var defs:Array<Float> = [60, 188, 14, 470];
		for (k in 0...keys.length)
		{
			label(PX + 10 + k * 95, PY + 232, 'Buttons ' + keys[k] + ':');
			var st:PsychUINumericStepper = new PsychUINumericStepper(PX + 10 + k * 95, PY + 246, keys[k] == 'spacing' ? 2 : 10, defs[k], keys[k] == 'width' ? 200 : -400, keys[k] == 'width' ? 900 : 1400, 0, 70);
			btnSteppers.set(keys[k], st);
			editGroup.add(st);
		}
		label(PX + 400, PY + 232, 'Align:');

		label(PX + 10, PY + 274, 'Title:');
		titleInput = new PsychUIInputText(PX + 10, PY + 288, 200, '', 8);
		editGroup.add(titleInput);
		label(PX + 230, PY + 274, 'Subtitle:');
		subtitleInput = new PsychUIInputText(PX + 230, PY + 288, 200, '', 8);
		editGroup.add(subtitleInput);

		label(PX + 10, PY + 316, 'Intro animation:');
		label(PX + 125, PY + 316, 'Speed:');
		speedStepper = new PsychUINumericStepper(PX + 125, PY + 330, 0.25, 1, 0.25, 4, 2, 60);
		editGroup.add(speedStepper);
		label(PX + 230, PY + 316, 'Transition:');
		label(PX + 345, PY + 316, 'Seconds:');
		transStepper = new PsychUINumericStepper(PX + 345, PY + 330, 0.1, 0.5, 0, 3, 1, 60);
		editGroup.add(transStepper);

		var note:FlxText = new FlxText(PX + 10, PY + 360, FlxG.width - PX - 60,
			'Icons, labels, logos, animations and per-screen backgrounds are set in menu.json (see README.md in the folder). Save keeps everything else in the file.', 8);
		editGroup.add(note);

		// drop-downs last, bottom to top, so their lists open over the fields below them
		introDrop = new PsychUIDropDownMenu(PX + 10, PY + 330, ['slide', 'fade', 'none'], function(id, name) {}, 100);
		transDrop = new PsychUIDropDownMenu(PX + 230, PY + 330, ['fade', 'none'], function(id, name) {}, 100);
		alignDrop = new PsychUIDropDownMenu(PX + 400, PY + 246, ['left', 'center', 'right'], function(id, name) {}, 100);
		bgTypeDrop = new PsychUIDropDownMenu(PX + 10, PY + 204, ['cosmic', 'color', 'gradient', 'image'], function(id, name) {}, 110);
		modDropDown = new PsychUIDropDownMenu(PX + 10, PY + 14, [''], function(id:Int, name:String) {
			customMod = name;
			loadFields();
			rebuildPreview();
		}, 200);
		for (d in [introDrop, transDrop, alignDrop, bgTypeDrop, modDropDown]) editGroup.add(d);
	}

	function refreshModList()
	{
		customMods = MenuTheme.modsWithCustomMenus();
		if (!customMods.contains(customMod)) customMod = customMods.length > 0 ? customMods[0] : '';
		modDropDown.list = customMods.length > 0 ? customMods : [''];
		if (customMod.length > 0) modDropDown.selectedLabel = customMod;
		loadFields();
	}

	function readJson():Dynamic
	{
		#if sys
		var path:String = Paths.mods('$customMod/custom_menus/menu.json');
		if (customMod.length > 0 && FileSystem.exists(path))
			try return tjson.TJSON.parse(File.getContent(path)) catch (e:Dynamic) {}
		#end
		return null;
	}

	static function str(v:Dynamic, def:String):String
		return v == null ? def : Std.string(v);

	function loadFields()
	{
		var cfg:Dynamic = readJson();
		if (cfg == null) cfg = {};
		nameInput.text = str(cfg.name, '');
		fontInput.text = str(cfg.font, '');
		autoCheck.checked = cfg.autoApply == true;
		var colors:Dynamic = cfg.colors != null ? cfg.colors : {};
		for (key => input in colorInputs) input.text = str(Reflect.field(colors, key), '');
		var bg:Dynamic = cfg.background != null ? cfg.background : {type: 'cosmic'};
		bgTypeDrop.selectedLabel = str(bg.type, 'cosmic');
		bgColor1.text = str(bg.color, (bg.colors != null && bg.colors.length > 0) ? Std.string(bg.colors[0]) : '');
		bgColor2.text = (bg.colors != null && bg.colors.length > 1) ? Std.string(bg.colors[1]) : '';
		bgImage.text = str(bg.image, '');
		var mm:Dynamic = cfg.mainMenu != null ? cfg.mainMenu : {};
		var b:Dynamic = mm.buttons != null ? mm.buttons : {};
		for (k => st in btnSteppers)
		{
			var v:Dynamic = Reflect.field(b, k);
			if (v != null) st.value = Std.parseFloat(Std.string(v));
		}
		alignDrop.selectedLabel = str(b.align, 'left');
		titleInput.text = str(mm.title, '');
		subtitleInput.text = str(mm.subtitle, '');
		var an:Dynamic = cfg.animations != null ? cfg.animations : {};
		introDrop.selectedLabel = str(an.intro, 'slide');
		speedStepper.value = an.speed != null ? Std.parseFloat(Std.string(an.speed)) : 1;
		var tr:Dynamic = cfg.transitions != null ? cfg.transitions : {};
		transDrop.selectedLabel = str(tr.type, 'fade');
		transStepper.value = tr.duration != null ? Std.parseFloat(Std.string(tr.duration)) : 0.5;
	}

	function saveFields()
	{
		#if sys
		if (customMod.length < 1) { statusText.text = 'No custom menu to save.'; return; }
		var cfg:Dynamic = readJson();
		if (cfg == null) cfg = {format: MenuTheme.CONFIG_FORMAT};
		function setOrRemove(obj:Dynamic, key:String, value:String)
		{
			if (value == null || value.trim().length < 1) Reflect.deleteField(obj, key);
			else Reflect.setField(obj, key, value.trim());
		}
		setOrRemove(cfg, 'name', nameInput.text);
		setOrRemove(cfg, 'font', fontInput.text);
		cfg.autoApply = autoCheck.checked;
		if (cfg.colors == null) cfg.colors = {};
		for (key => input in colorInputs) setOrRemove(cfg.colors, key, input.text);
		var bg:Dynamic = {type: bgTypeDrop.selectedLabel};
		if (cfg.background != null) for (k in ['scroll', 'alpha', 'animation', 'rings', 'fit']) if (Reflect.field(cfg.background, k) != null) Reflect.setField(bg, k, Reflect.field(cfg.background, k));
		switch (bgTypeDrop.selectedLabel)
		{
			case 'color': bg.color = bgColor1.text.trim();
			case 'gradient': bg.colors = [bgColor1.text.trim(), bgColor2.text.trim()];
			case 'image': bg.image = bgImage.text.trim();
		}
		cfg.background = bg;
		if (cfg.mainMenu == null) cfg.mainMenu = {};
		if (cfg.mainMenu.buttons == null) cfg.mainMenu.buttons = {};
		for (k => st in btnSteppers) Reflect.setField(cfg.mainMenu.buttons, k, st.value);
		cfg.mainMenu.buttons.align = alignDrop.selectedLabel;
		setOrRemove(cfg.mainMenu, 'title', titleInput.text);
		setOrRemove(cfg.mainMenu, 'subtitle', subtitleInput.text);
		if (cfg.animations == null) cfg.animations = {};
		cfg.animations.intro = introDrop.selectedLabel;
		cfg.animations.speed = speedStepper.value;
		cfg.transitions = {type: transDrop.selectedLabel, duration: transStepper.value};
		try
		{
			File.saveContent(Paths.mods('$customMod/custom_menus/menu.json'), haxe.Json.stringify(cfg, '\t'));
			MenuTheme.apply(true);
			rebuildPreview();
			statusText.text = 'Saved mods/$customMod/custom_menus/menu.json' + (lastPreviewErrors.length > 0 ? ' - it has problems (see the left).' : '. ENTER uses it.');
			FlxG.sound.play(Paths.sound('confirmMenu'));
		}
		catch (e:Dynamic) statusText.text = 'Could not save: $e';
		#end
	}

	function createTemplate()
	{
		#if sys
		var mod:String = Mods.currentModDirectory;
		if (mod == null || mod.length < 1) { statusText.text = 'Pick a mod in the Developer menu first (LEFT / RIGHT there).'; return; }
		var dir:String = Paths.mods('$mod/custom_menus/');
		if (FileSystem.exists(dir + 'menu.json')) { statusText.text = 'mods/$mod/custom_menus/menu.json already exists (not overwritten).'; return; }
		try
		{
			for (sub in ['', 'assets', 'animations']) if (!FileSystem.exists(dir + sub)) FileSystem.createDirectory(dir + sub);
			for (f in ['menu.json', 'README.md']) File.saveContent(dir + f, File.getContent(Paths.getSharedPath('data/custom_menu_template/$f')));
			File.saveContent(dir + 'assets/put-pictures-and-fonts-here.txt', 'Pictures (PNG) and fonts (TTF / OTF) for menu.json go in this folder.\n');
			File.saveContent(dir + 'animations/put-animations-here.txt', 'Animated pictures: name.png + name.xml (Sparrow sheet). Use them in menu.json as {"file": "name", "prefix": "..."}.\n');
			customMod = mod;
			refreshModList();
			select(2);
			statusText.text = 'Created mods/$mod/custom_menus/. Edit it here or in menu.json, then ENTER to use it.';
			FlxG.sound.play(Paths.sound('confirmMenu'));
		}
		catch (e:Dynamic) statusText.text = 'Could not create the template: $e';
		#end
	}

	public function UIEvent(id:String, sender:Dynamic) {}
}
