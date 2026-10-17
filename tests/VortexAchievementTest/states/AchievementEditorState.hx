import Reflect;
import sys.io.File;
import sys.FileSystem;
import tjson.TJSON;
import backend.Achievements;
import backend.Mods;
import backend.Song;
import states.LoadingState;

var st = {t: 0.0, stage: 0};
var out = [];

function check(name, ok, ?info) { out.push((ok ? 'PASS ' : 'FAIL ') + name + (info != null ? ' -- ' + info : '')); }
function flush() {
	var f = File.append('vortex_achtest.txt', false);
	f.writeString(out.join('\n') + '\n');
	f.close();
	out.splice(0, out.length);
}
function fld(name) { return Reflect.field(game, name); }
function run(name, args) { return Reflect.callMethod(game, Reflect.field(game, name), args == null ? [] : args); }

function editorTests() {
	var folder = fld('folder');
	check('editor saves into the selected mod', folder == 'mods/VortexAchievementTest/achievements/', folder);
	fld('idInput').text = 'ed-made';
	fld('nameInput').text = 'Editor Made';
	fld('descInput').text = 'Saved by the Achievement Editor.';
	fld('typeDropDown').selectedLabel = 'song_complete';
	fld('songInput').text = 'example-song';
	fld('missesStepper').value = 5;
	fld('maxScoreStepper').value = 2;
	run('refreshPreview', null);
	run('saveAchievement', null);
	var path = folder + 'ed-made.json';
	check('Save writes <id>.json', FileSystem.exists(path));
	var data = TJSON.parse(File.getContent(path));
	check('saved fields are right', data.name == 'Editor Made' && data.unlock.type == 'song_complete' && data.unlock.song == 'example-song' && data.unlock.maxMisses == 5 && data.maxScore == 2,
		StringTools.replace(StringTools.replace(File.getContent(path), '\n', ' '), '\t', ''));
	check('saved achievement is usable right away', Achievements.exists('ed-made') && Achievements.get('ed-made').maxScore == 2);
	run('createScript', ['.lua']);
	check('Create Lua script writes a template', FileSystem.exists(folder + 'ed-made.lua'));

	fld('idInput').text = 'first-steps';
	var err = run('validate', null);
	check('refuses an id another mod already uses', err != null && err.indexOf('already used') >= 0, err);
	fld('idInput').text = 'ed-made';
	fld('nameInput').text = '';
	err = run('validate', null);
	check('refuses an empty name', err != null, err);

	run('loadAchievement', ['ach-test-script']);
	check('Load fills the fields from a file', fld('nameInput').text == 'Test: script' && fld('typeDropDown').selectedLabel == 'manual', fld('nameInput').text);
	flush();
}

function startSong() {
	Mods.currentModDirectory = 'Vortex-Example-Mod';
	Song.loadFromJson('example-song', 'example-song');
	PlayState.isStoryMode = false;
	PlayState.storyDifficulty = 0;
	LoadingState.prepareToSong();
	LoadingState.loadAndSwitchState(new PlayState());
}

function onUpdate(elapsed) {
	st.t += elapsed;
	if (st.stage == 0 && st.t > 1.0) { st.stage = 1; editorTests(); }
	if (st.stage == 1 && st.t > 2.0) { st.stage = 2; File.saveContent('shot_editor.txt', '1'); }
	if (st.stage == 2 && st.t > 4.5) { st.stage = 3; run('testPopup', null); }
	if (st.stage == 3 && st.t > 5.3) { st.stage = 4; File.saveContent('shot_popup.txt', '1'); }
	if (st.stage == 4 && st.t > 8.0) {
		st.stage = 5;
		FileSystem.deleteFile('mods/VortexAchievementTest/achievements/ed-made.json');
		FileSystem.deleteFile('mods/VortexAchievementTest/achievements/ed-made.lua');
		Achievements.reloadList();
		startSong();
	}
}
