package states.editors;

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
import objects.CosmicBackground;
import haxe.Json;
import openfl.display.BitmapData;
import flixel.graphics.FlxGraphic;

/**
 * VORTEX ENGINE ADDITION - Achievement Editor (Developer menu, key 7 on the main menu).
 *
 * Makes and edits achievements as files in the selected mod: mods/<mod>/achievements/<id>.json, with an optional
 * <id>.png icon and <id>.lua / <id>.hx script next to it (see backend/Achievements.hx for the format).
 * Without a mod directory selected in the Developer menu, files go to mods/achievements/.
 */
class AchievementEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	static final UNLOCK_TYPES:Array<String> = ['manual', 'song_complete', 'week_complete'];
	static final UNLOCK_HELP:Map<String, String> = [
		'manual' => 'Only scripts unlock it:\nunlockAchievement(id) or\naddAchievementScore(id, 1).',
		'song_complete' => 'Unlocks when a song is finished.\nSong empty = any song.',
		'week_complete' => 'Unlocks when the last song of the\nweek is finished in Story Mode.\nMisses/score count the whole week.'
	];

	var folder:String;
	var unsaved:Bool = false;

	// preview card
	var cardBorder:FlxSprite;
	var cardFill:FlxSprite;
	var cardIcon:FlxSprite;
	var cardName:FlxText;
	var cardDesc:FlxText;
	var cardState:FlxText;
	var cardBarBG:FlxSprite;
	var cardBar:FlxSprite;
	var listText:FlxText;
	var statusText:FlxText;
	var statusTime:Float = 0;

	var UI_box:PsychUIBox;
	var loadDropDown:PsychUIDropDownMenu;
	var idInput:PsychUIInputText;
	var nameInput:PsychUIInputText;
	var descInput:PsychUIInputText;
	var iconInput:PsychUIInputText;
	var hiddenCheck:PsychUICheckBox;
	var maxScoreStepper:PsychUINumericStepper;

	var typeDropDown:PsychUIDropDownMenu;
	var songInput:PsychUIInputText;
	var weekInput:PsychUIInputText;
	var missesStepper:PsychUINumericStepper;
	var accuracyStepper:PsychUINumericStepper;
	var scoreStepper:PsychUINumericStepper;
	var practiceCheck:PsychUICheckBox;
	var unlockHelp:FlxText;

	var scriptInfo:FlxText;

	override function create()
	{
		#if DISCORD_ALLOWED DiscordClient.changePresence("Achievement Editor", null); #end
		folder = (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) ? Paths.mods(Mods.currentModDirectory + '/achievements/') : Paths.mods('achievements/');

		add(new CosmicBackground(FlxG.width, FlxG.height));

		var title:FlxText = new FlxText(40, 24, 0, 'ACHIEVEMENT EDITOR', 40);
		title.setFormat(Paths.font('vcr.ttf'), 40, CosmicBackground.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, CosmicBackground.NEBULA_VIOLET);
		add(title);
		var where:FlxText = new FlxText(42, 70, 760, 'Saving to: $folder', 16);
		where.setFormat(Paths.font('vcr.ttf'), 16, CosmicBackground.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(where);

		// preview card, like the in-game popup
		cardBorder = new FlxSprite(40, 110).makeGraphic(620, 160, FlxColor.WHITE);
		cardBorder.color = CosmicBackground.PANEL_BORDER_BRIGHT;
		add(cardBorder);
		cardFill = new FlxSprite(42, 112).makeGraphic(616, 156, FlxColor.WHITE);
		cardFill.color = CosmicBackground.PANEL_FILL;
		cardFill.alpha = 0.92;
		add(cardFill);
		cardIcon = new FlxSprite(62, 130);
		add(cardIcon);
		cardName = new FlxText(190, 132, 450, '', 26);
		cardName.setFormat(Paths.font('vcr.ttf'), 26, CosmicBackground.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(cardName);
		cardDesc = new FlxText(190, 168, 450, '', 16);
		cardDesc.setFormat(Paths.font('vcr.ttf'), 16, CosmicBackground.TEXT_DIM, LEFT);
		add(cardDesc);
		cardState = new FlxText(190, 236, 450, '', 14);
		cardState.setFormat(Paths.font('vcr.ttf'), 14, CosmicBackground.ACCENT_CYAN, LEFT);
		add(cardState);
		cardBarBG = new FlxSprite(62, 244).makeGraphic(100, 8, 0xFF2A2350);
		add(cardBarBG);
		cardBar = new FlxSprite(62, 244).makeGraphic(1, 8, CosmicBackground.NEBULA_TEAL);
		cardBar.origin.set(0, 0);
		add(cardBar);

		var listTitle:FlxText = new FlxText(40, 292, 0, 'IN THIS FOLDER', 18);
		listTitle.setFormat(Paths.font('vcr.ttf'), 18, CosmicBackground.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(listTitle);
		listText = new FlxText(40, 318, 620, '', 14);
		listText.setFormat(Paths.font('vcr.ttf'), 14, CosmicBackground.TEXT_DIM, LEFT);
		add(listText);

		statusText = new FlxText(40, FlxG.height - 70, 760, '', 16);
		statusText.setFormat(Paths.font('vcr.ttf'), 16, CosmicBackground.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(statusText);
		var help:FlxText = new FlxText(40, FlxG.height - 36, FlxG.width - 80, 'ESC: back to Developer menu   |   Icons: put a PNG in the folder above   |   Scripts run during songs while the achievement is locked', 14);
		help.setFormat(Paths.font('vcr.ttf'), 14, CosmicBackground.TEXT_DIM, LEFT);
		add(help);

		addEditorBox();
		newAchievement();
		refreshList();
		FlxG.mouse.visible = true;
		super.create();
	}

	function addEditorBox()
	{
		UI_box = new PsychUIBox(FlxG.width - 440, 100, 400, 470, ['Achievement', 'Unlock', 'Script']);
		UI_box.scrollFactor.set();

		// ---- Achievement ----
		var tab = UI_box.getTab('Achievement').menu;
		idInput = new PsychUIInputText(10, 70, 180, '', 8);
		idInput.forceCase = LOWER_CASE;
		idInput.customFilterPattern = ~/[^a-z0-9_\-]*/g;
		nameInput = new PsychUIInputText(10, 115, 370, '', 8);
		descInput = new PsychUIInputText(10, 160, 370, '', 8);
		iconInput = new PsychUIInputText(10, 205, 180, '', 8);
		hiddenCheck = new PsychUICheckBox(10, 240, 'Hidden until unlocked', 150, function() { unsaved = true; refreshPreview(); });
		maxScoreStepper = new PsychUINumericStepper(10, 290, 1, 0, 0, 100000, 0, 80);

		tab.add(makeLabel(10, 52, 'ID (file name, lowercase, a-z 0-9 _ -):'));
		tab.add(makeLabel(10, 97, 'Name:'));
		tab.add(makeLabel(10, 142, 'Description:'));
		tab.add(makeLabel(10, 187, 'Icon file in the folder (empty = <id>.png):'));
		tab.add(makeLabel(10, 272, 'Progress goal (0 = no progress bar):'));
		tab.add(makeLabel(100, 293, 'e.g. 5 = "finish 5 songs"'));
		tab.add(idInput);
		tab.add(nameInput);
		tab.add(descInput);
		tab.add(iconInput);
		tab.add(hiddenCheck);
		tab.add(maxScoreStepper);

		tab.add(new PsychUIButton(10, 330, 'New', function() { newAchievement(); setStatus('New achievement - fill it in and press Save.'); }, 80));
		tab.add(new PsychUIButton(100, 330, 'Save', saveAchievement, 80));
		tab.add(new PsychUIButton(190, 330, 'Test Popup', testPopup, 90));
		tab.add(new PsychUIButton(290, 330, 'Reset Progress', resetProgress, 90));
		tab.add(makeLabel(10, 370, 'Reset Progress relocks it in YOUR save, for testing.'));

		loadDropDown = new PsychUIDropDownMenu(10, 22, [''], function(index:Int, label:String) {
			if(label != null && label.length > 0) loadAchievement(label);
		}, 180);
		tab.add(makeLabel(10, 4, 'Load from this folder:'));
		tab.add(loadDropDown); // added last so its list draws on top

		// ---- Unlock ----
		var tab = UI_box.getTab('Unlock').menu;
		songInput = new PsychUIInputText(10, 75, 180, '', 8);
		weekInput = new PsychUIInputText(200, 75, 180, '', 8);
		missesStepper = new PsychUINumericStepper(10, 125, 1, -1, -1, 99999, 0, 70);
		accuracyStepper = new PsychUINumericStepper(130, 125, 1, 0, 0, 100, 2, 70);
		scoreStepper = new PsychUINumericStepper(250, 125, 1000, 0, 0, 99999999, 0, 100);
		practiceCheck = new PsychUICheckBox(10, 165, 'Practice Mode counts too', 160, function() unsaved = true);
		unlockHelp = new FlxText(10, 205, 370, '', 12);
		unlockHelp.setFormat(Paths.font('vcr.ttf'), 12, FlxColor.WHITE, LEFT);

		tab.add(makeLabel(10, 57, 'Song (empty = any):'));
		tab.add(makeLabel(200, 57, 'Week file (week_complete):'));
		tab.add(makeLabel(10, 107, 'Max misses (-1 = any):'));
		tab.add(makeLabel(130, 107, 'Min accuracy %:'));
		tab.add(makeLabel(250, 107, 'Min score:'));
		tab.add(makeLabel(10, 300, 'Botplay and the Chart Editor never unlock achievements.'));
		tab.add(songInput);
		tab.add(weekInput);
		tab.add(missesStepper);
		tab.add(accuracyStepper);
		tab.add(scoreStepper);
		tab.add(practiceCheck);
		tab.add(unlockHelp);
		typeDropDown = new PsychUIDropDownMenu(10, 22, UNLOCK_TYPES, function(index:Int, label:String) {
			unsaved = true;
			refreshUnlockHelp();
		}, 180);
		tab.add(makeLabel(10, 4, 'Unlock when:'));
		tab.add(typeDropDown);

		// ---- Script ----
		var tab = UI_box.getTab('Script').menu;
		scriptInfo = new FlxText(10, 10, 370, '', 12);
		scriptInfo.setFormat(Paths.font('vcr.ttf'), 12, FlxColor.WHITE, LEFT);
		tab.add(scriptInfo);
		tab.add(new PsychUIButton(10, 300, 'Create Lua script', function() createScript('.lua'), 130));
		tab.add(new PsychUIButton(150, 300, 'Create HScript', function() createScript('.hx'), 110));

		UI_box.selectedName = 'Achievement';
		add(UI_box);
	}

	function makeLabel(x:Float, y:Float, text:String):FlxText
		return new FlxText(x, y, 0, text);

	// ------------------------------------------------------------------------------------------------------------

	function newAchievement()
	{
		idInput.text = '';
		nameInput.text = '';
		descInput.text = '';
		iconInput.text = '';
		hiddenCheck.checked = false;
		maxScoreStepper.value = 0;
		typeDropDown.selectedLabel = 'manual';
		songInput.text = '';
		weekInput.text = '';
		missesStepper.value = -1;
		accuracyStepper.value = 0;
		scoreStepper.value = 0;
		practiceCheck.checked = false;
		unsaved = false;
		refreshUnlockHelp();
		refreshPreview();
	}

	function loadAchievement(id:String)
	{
		var path:String = folder + id + '.json';
		if(!FileSystem.exists(path)) { setStatus('Not found: $path', true); return; }
		try
		{
			var data:Dynamic = tjson.TJSON.parse(File.getContent(path));
			newAchievement();
			idInput.text = id;
			nameInput.text = data.name != null ? Std.string(data.name) : '';
			descInput.text = data.description != null ? Std.string(data.description) : '';
			iconInput.text = data.icon != null ? Std.string(data.icon) : '';
			hiddenCheck.checked = data.hidden == true;
			maxScoreStepper.value = data.maxScore != null ? Std.parseFloat(Std.string(data.maxScore)) : 0;
			var u:Dynamic = data.unlock;
			if(u != null)
			{
				typeDropDown.selectedLabel = (u.type != null && UNLOCK_TYPES.contains(u.type)) ? u.type : 'manual';
				songInput.text = u.song != null ? Std.string(u.song) : '';
				weekInput.text = u.week != null ? Std.string(u.week) : '';
				missesStepper.value = u.maxMisses != null ? u.maxMisses : -1;
				accuracyStepper.value = u.minAccuracy != null ? u.minAccuracy : 0;
				scoreStepper.value = u.minScore != null ? u.minScore : 0;
				practiceCheck.checked = u.allowPractice == true;
			}
			unsaved = false;
			loadDropDown.selectedLabel = id;
			refreshUnlockHelp();
			refreshPreview();
			setStatus('Loaded $id');
		}
		catch(e:Dynamic) { setStatus('Could not read $path: $e', true); }
	}

	function buildData():Dynamic
	{
		var type:String = typeDropDown.selectedLabel != null ? typeDropDown.selectedLabel : 'manual';
		var unlock:Dynamic = {type: type};
		if(type != 'manual')
		{
			if(type == 'song_complete') unlock.song = songInput.text.trim();
			if(type == 'week_complete') unlock.week = weekInput.text.trim();
			unlock.maxMisses = Std.int(missesStepper.value);
			unlock.minAccuracy = accuracyStepper.value;
			unlock.minScore = Std.int(scoreStepper.value);
			unlock.allowPractice = practiceCheck.checked;
		}
		var data:Dynamic = {
			name: nameInput.text.trim(),
			description: descInput.text.trim(),
			hidden: hiddenCheck.checked,
			unlock: unlock
		};
		if(iconInput.text.trim().length > 0) data.icon = iconInput.text.trim();
		if(maxScoreStepper.value > 0) { data.maxScore = Std.int(maxScoreStepper.value); data.maxDecimals = 0; }
		return data;
	}

	/** Returns an error message, or null when the fields are fine to save. **/
	function validate():String
	{
		var id:String = idInput.text.trim();
		if(!Achievements.isValidId(id)) return 'The ID must only use lowercase letters, numbers, - and _.';
		if(nameInput.text.trim().length < 1) return 'Give it a name.';
		var existing = Achievements.get(id);
		if(existing != null && (existing.folder == null || existing.folder != folder))
			return 'The ID "$id" is already used by another achievement' + (existing.mod != null ? ' (mod "${existing.mod}")' : ' (built-in)') + '.';
		if(typeDropDown.selectedLabel == 'week_complete' && weekInput.text.trim().length < 1) return 'week_complete needs a week file name.';
		return null;
	}

	function saveAchievement()
	{
		var err:String = validate();
		if(err != null) { setStatus(err, true); return; }
		var id:String = idInput.text.trim();
		try
		{
			if(!FileSystem.exists(folder)) FileSystem.createDirectory(folder);
			File.saveContent(folder + id + '.json', Json.stringify(buildData(), '\t'));
			unsaved = false;
			Achievements.clearIconCache();
			Achievements.reloadList();
			refreshList();
			loadDropDown.selectedLabel = id;
			refreshPreview();
			setStatus('Saved ${folder}$id.json');
		}
		catch(e:Dynamic) { setStatus('Could not save: $e', true); }
	}

	function testPopup()
	{
		var id:String = idInput.text.trim();
		if(!Achievements.exists(id)) { setStatus('Save it first, then test the popup.', true); return; }
		Achievements.startPopup(id);
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.5);
	}

	function resetProgress()
	{
		var id:String = idInput.text.trim();
		if(!Achievements.exists(id)) { setStatus('Nothing to reset: "$id" isn\'t saved yet.', true); return; }
		Achievements.reset(id);
		refreshPreview();
		setStatus('"$id" is locked again in your save.');
	}

	function createScript(ext:String)
	{
		var id:String = idInput.text.trim();
		if(!Achievements.isValidId(id)) { setStatus('Set a valid ID first.', true); return; }
		var path:String = folder + id + ext;
		if(FileSystem.exists(path)) { setStatus('$path already exists.', true); return; }
		var code:String = (ext == '.lua') ? [
			'-- Attached to the achievement "$id". It runs in every song while the achievement is still locked.',
			'-- achievementId is "$id". Unlock it with unlockAchievement(achievementId)',
			'-- (or addAchievementScore(achievementId, 1) if it has a progress goal).',
			'',
			'function onUpdatePost(elapsed)',
			'\t-- example: unlock it when you reach a 50 combo (botplay doesn\'t count)',
			'\tif not botPlay and getProperty(\'combo\') >= 50 then',
			'\t\tunlockAchievement(achievementId)',
			'\tend',
			'end',
			''
		].join('\n') : [
			'// Attached to the achievement "$id". It runs in every song while the achievement is still locked.',
			'// achievementId is "$id". Unlock it with Achievements.unlock(achievementId).',
			'import backend.Achievements;',
			'',
			'function onUpdatePost(elapsed:Float) {',
			'\t// example: unlock it when you reach a 50 combo (botplay doesn\'t count)',
			'\tif (!game.cpuControlled && game.combo >= 50 && !Achievements.isUnlocked(achievementId))',
			'\t\tAchievements.unlock(achievementId);',
			'}',
			''
		].join('\n');
		try
		{
			if(!FileSystem.exists(folder)) FileSystem.createDirectory(folder);
			File.saveContent(path, code);
			refreshPreview();
			setStatus('Created $path (edit it in any text editor).');
		}
		catch(e:Dynamic) { setStatus('Could not create the script: $e', true); }
	}

	// ------------------------------------------------------------------------------------------------------------

	function refreshList()
	{
		var ids:Array<String> = [];
		if(FileSystem.exists(folder))
			for (file in FileSystem.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json')) ids.push(file.substr(0, file.length - 5));
		ids.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		loadDropDown.list = ids.length > 0 ? ids : [''];

		var lines:Array<String> = [];
		for (id in ids)
		{
			var a = Achievements.get(id);
			var state:String = (a == null) ? '(not loaded: check vortex_script_log.txt)' : (Achievements.isUnlocked(id) ? 'UNLOCKED' : 'locked');
			var type:String = (a != null && a.unlock != null && a.unlock.type != null) ? a.unlock.type : 'manual';
			lines.push('$id  -  ${a != null ? a.name : '?'}  [$type, $state]');
		}
		listText.text = lines.length > 0 ? lines.join('\n') : 'Nothing yet. Fill in the fields on the right and press Save.';
	}

	function refreshUnlockHelp()
	{
		var type:String = typeDropDown.selectedLabel != null ? typeDropDown.selectedLabel : 'manual';
		unlockHelp.text = UNLOCK_HELP.exists(type) ? UNLOCK_HELP.get(type) : '';
		var on:Bool = (type != 'manual');
		for (obj in [songInput, missesStepper, accuracyStepper, scoreStepper, practiceCheck]) obj.alpha = on ? 1 : 0.35;
		songInput.alpha = (type == 'song_complete') ? 1 : 0.35;
		weekInput.alpha = (type == 'week_complete') ? 1 : 0.35;
	}

	function refreshPreview()
	{
		var id:String = idInput.text.trim();
		cardName.text = nameInput.text.trim().length > 0 ? nameInput.text : '(no name)';
		cardDesc.text = descInput.text.trim().length > 0 ? descInput.text : '(no description)';

		// icon: the file in the folder, else Psych's images/achievements/<id>, else the "unknown" picture
		var graphic:FlxGraphic = null;
		var iconName:String = iconInput.text.trim().length > 0 ? iconInput.text.trim() : id + '.png';
		if(!iconName.toLowerCase().endsWith('.png')) iconName += '.png';
		var iconPath:String = folder + iconName;
		if(id.length > 0 && FileSystem.exists(iconPath))
		{
			try { graphic = FlxGraphic.fromBitmapData(BitmapData.fromFile(iconPath), false, null, false); } catch(e:Dynamic) {}
		}
		if(graphic == null && id.length > 0) graphic = Paths.image('achievements/$id', null, false);
		if(graphic == null) graphic = Paths.image('unknownMod', null, false);
		if(graphic != null) cardIcon.loadGraphic(graphic);
		cardIcon.setGraphicSize(100, 100);
		cardIcon.updateHitbox();
		cardIcon.setPosition(62, 130);

		var exists:Bool = Achievements.exists(id);
		var unlocked:Bool = exists && Achievements.isUnlocked(id);
		var goal:Float = maxScoreStepper.value;
		var progress:Float = 0;
		if(exists && goal > 0) progress = unlocked ? goal : (Achievements.variables.exists(id) ? Achievements.variables.get(id) : 0);
		cardBarBG.visible = cardBar.visible = goal > 0;
		cardBar.scale.x = goal > 0 ? Math.max(0.0001, 100 * Math.min(1, progress / goal)) : 0;
		cardState.text = (!exists ? 'NOT SAVED YET' : (unlocked ? 'UNLOCKED (in your save)' : 'LOCKED'))
			+ (goal > 0 ? '   progress ${Std.int(progress)} / ${Std.int(goal)}' : '')
			+ (hiddenCheck.checked ? '   hidden' : '') + (unsaved ? '   * unsaved changes' : '');
		cardIcon.alpha = unlocked ? 1 : 0.55;

		var lua:String = folder + id + '.lua';
		var hx:String = folder + id + '.hx';
		var has:String = (id.length > 0 && FileSystem.exists(lua)) ? lua : ((id.length > 0 && FileSystem.exists(hx)) ? hx : null);
		scriptInfo.text = (has != null ? 'Script: $has\n\n' : 'No script yet. Scripts are optional.\n\n')
			+ 'A script named <id>.lua or <id>.hx in the achievements\nfolder runs in every song while the achievement is\nlocked. It gets the variable achievementId.\n\n'
			+ 'Lua functions:\n  unlockAchievement(achievementId)\n  addAchievementScore(achievementId, 1)\n  getAchievementScore(achievementId)\n  isAchievementUnlocked(achievementId)\n  getAchievementInfo(achievementId)\n\n'
			+ 'The buttons below write a working example\n(unlock at a 50 combo) that you can edit.';
	}

	function setStatus(text:String, isError:Bool = false)
	{
		statusText.text = text;
		statusText.color = isError ? 0xFFFF6B8B : CosmicBackground.TEXT_BRIGHT;
		statusTime = 6;
		if(isError) FlxG.sound.play(Paths.sound('cancelMenu'), 0.5);
	}

	public function UIEvent(id:String, sender:Dynamic)
	{
		if(id == PsychUIInputText.CHANGE_EVENT || id == PsychUINumericStepper.CHANGE_EVENT)
		{
			unsaved = true;
			refreshPreview();
		}
	}

	override function update(elapsed:Float)
	{
		if(statusTime > 0)
		{
			statusTime -= elapsed;
			if(statusTime <= 0) statusText.text = '';
		}

		if(PsychUIInputText.focusOn == null)
		{
			ClientPrefs.toggleVolumeKeys(true);
			if(FlxG.keys.justPressed.ESCAPE)
			{
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
			}
		}
		else ClientPrefs.toggleVolumeKeys(false);
		super.update(elapsed);
	}
}
#end
