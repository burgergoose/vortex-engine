import Sys;
import Reflect;
import sys.io.File;
import backend.Song;
import backend.Mods;
import backend.MenuTheme;
import backend.MusicBeatState;
import states.MainMenuState;
import states.FreeplayState;
import states.StoryMenuState;
import states.editors.MasterEditorMenu;
import states.editors.ChartingState;
import states.editors.MenuEditorState;

// Menu theme test: every themed screen in Psych Classic and in the example mod's custom menu (screenshot markers
// shot_<step>.txt), a broken custom menu falling back, then a reset. The theme is set back to Vortex at the end.
var out = [];
var st = {t: 0.0, shot: false, left: false};
function check(name, ok, ?info) { out.push((ok ? 'PASS ' : 'FAIL ') + name + (info != null ? ' -- ' + info : '')); }
function flush() { if (out.length < 1) return; var f = File.append('vortex_themetest.txt', false); f.writeString(out.join('\n') + '\n'); f.close(); out.splice(0, out.length); }
function has(list, part) { for (s in list) if (s.indexOf(part) > -1) return true; return false; }

// step -> [shot name, state]
function stepName(i) { return ['classic_main', 'classic_freeplay', 'classic_story', 'classic_dev', 'classic_chart', 'custom_main', 'custom_freeplay', 'custom_story', 'custom_dev', 'custom_chart', 'editor_custom', 'editor_errors', 'reset_main'][i]; }
function stepState(i) { return ['MainMenuState', 'FreeplayState', 'StoryMenuState', 'MasterEditorMenu', 'ChartingState', 'MainMenuState', 'FreeplayState', 'StoryMenuState', 'MasterEditorMenu', 'ChartingState', 'MenuEditorState', 'MenuEditorState', 'MainMenuState'][i]; }

function go(i) {
	setGlobalVar('tt_step', i);
	if (i == 0) {
		MenuTheme.set('psych', '');
		check('Psych Classic selected and active', MenuTheme.selected == 'psych' && MenuTheme.active == 'psych' && MenuTheme.isClassic);
	}
	if (i == 5) {
		MenuTheme.set('custom', 'Vortex-Example-Mod');
		check('example custom menu loads without errors', MenuTheme.active == 'custom' && MenuTheme.errors.length == 0, MenuTheme.errors.join(' | '));
		check('custom colours / font / intro come from menu.json', (MenuTheme.ACCENT_CYAN & 0xFFFFFF) == 0xFFD27A && MenuTheme.introStyle() == 'fade' && MenuTheme.transitionTime() == 0.4);
	}
	if (i == 11) {
		MenuTheme.set('custom', 'VortexThemeTest');
		var e = MenuTheme.errors;
		check('broken menu.json is not used, last built-in theme (Psych Classic) used instead', MenuTheme.active == 'psych', MenuTheme.active);
		check('broken menu.json: every problem listed', e.length == 5 && has(e, 'colors.accent') && has(e, 'missing.png') && has(e, 'animations.intro') && has(e, 'nope.png') && has(e, 'buttons.align'), e.join(' | '));
		check('broken menu.json: unknown settings are warnings', has(MenuTheme.warnings, 'unknownKey') && has(MenuTheme.warnings, 'colors.bogus'), MenuTheme.warnings.join(' | '));
		var path = 'mods/VortexThemeTest/custom_menus/menu.json';
		var good = File.getContent(path);
		File.saveContent(path, '{ "format": 1, oops');
		MenuTheme.apply(true);
		check('menu.json that is not valid JSON is reported', has(MenuTheme.errors, 'not valid JSON') && MenuTheme.active == 'psych', MenuTheme.errors.join(' | '));
		File.saveContent(path, good);
		MenuTheme.apply(true);
	}
	if (i == 12) {
		MenuTheme.reset();
		check('reset: back to the Vortex theme', MenuTheme.selected == 'vortex' && MenuTheme.active == 'vortex' && !MenuTheme.isClassic && !MenuTheme.isCustom);
	}
	flush();
	var s = stepState(i);
	if (s == 'ChartingState') {
		Mods.currentModDirectory = 'Vortex-Example-Mod';
		Song.loadFromJson('example-song', 'example-song');
		MusicBeatState.switchState(new ChartingState(false));
	}
	else if (s == 'MainMenuState') MusicBeatState.switchState(new MainMenuState());
	else if (s == 'FreeplayState') MusicBeatState.switchState(new FreeplayState());
	else if (s == 'StoryMenuState') MusicBeatState.switchState(new StoryMenuState());
	else if (s == 'MasterEditorMenu') MusicBeatState.switchState(new MasterEditorMenu());
	else if (s == 'MenuEditorState') MusicBeatState.switchState(new MenuEditorState());
}

function onCreatePost() {
	if (getGlobalVar('tt_started', false)) return;
	setGlobalVar('tt_started', true);
	File.saveContent('vortex_themetest.txt', 'Vortex Engine menu theme test\n');
	go(0);
}

function onUpdate(elapsed) {
	var i = getGlobalVar('tt_step', -1);
	if (i < 0 || getStateName() != stepState(i)) return;
	st.t += elapsed;
	if (st.t > 2.0 && !st.shot) {
		st.shot = true;
		if (stepName(i) == 'classic_chart') check('chart editor follows Psych Classic (Psych grey theme)', Reflect.field(game, 'theme') == 'default', Reflect.field(game, 'theme'));
		if (stepName(i) == 'custom_chart') check('chart editor uses the custom menu\'s colours', Reflect.field(game, 'theme') == 'custom' && (Reflect.field(game, 'bg').color & 0xFFFFFF) == 0x2A1A12, Reflect.field(game, 'theme'));
		if (stepName(i) == 'classic_main') check('classic main menu built (Psych menu sprites)', Reflect.field(game, 'classicItems') != null && Reflect.field(game, 'classicItems').length >= 3);
		if (stepName(i) == 'classic_freeplay') check('classic Freeplay built (Alphabet list)', Reflect.field(game, 'classicTexts').length > 0);
		if (stepName(i) == 'classic_dev') check('classic Developer menu lists the new tools', Reflect.field(game, 'classicItems').length == 11, Reflect.field(game, 'classicItems').length);
		flush();
		File.saveContent('shot_' + stepName(i) + '.txt', '1');
	}
	if (st.t > 3.2 && !st.left) {
		st.left = true;
		if (i >= 12) { out.push('DONE'); flush(); Sys.exit(0); }
		else go(i + 1);
	}
}
