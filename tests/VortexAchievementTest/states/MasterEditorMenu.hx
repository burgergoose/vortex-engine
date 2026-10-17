import Reflect;
import sys.io.File;
import backend.Achievements;
import backend.Mods;
import backend.MusicBeatState;
import states.editors.AchievementEditorState;

var st = {t: 0.0, stage: 0};
var out = [];
var ids = ['first-steps', 'combo-starter', 'song-collector', 'ach-test-practice', 'ach-test-week', 'ach-test-acc', 'ach-test-script', 'ed-made'];

function check(name, ok, ?info) { out.push((ok ? 'PASS ' : 'FAIL ') + name + (info != null ? ' -- ' + info : '')); }
function flush() {
	var f = File.append('vortex_achtest.txt', false);
	f.writeString(out.join('\n') + '\n');
	f.close();
	out.splice(0, out.length);
}
function resetAll() { for (id in ids) if (Achievements.exists(id)) Achievements.reset(id); }
function info(song, accuracy, practice, story, week, weekMisses) {
	return {song: song, week: week, storyMode: story, lastSongOfWeek: true, misses: 3, weekMisses: weekMisses,
		accuracy: accuracy, score: 1000, weekScore: 1000, practice: practice};
}
function score(id) { return Achievements.variables.exists(id) ? Achievements.variables.get(id) : 0; }

function logicTests() {
	Achievements.reloadList();
	resetAll();
	var opts = Reflect.field(game, 'options');
	check('Developer menu lists the Achievement Editor', opts.indexOf('Achievement Editor') >= 0 && opts.indexOf('Chart Editor') == 0 && opts.indexOf('Week Editor') >= 0 && opts.indexOf('Dialogue Editor') >= 0, opts.join(', '));
	check('example achievements load from achievements/', Achievements.exists('first-steps') && Achievements.exists('combo-starter') && Achievements.exists('song-collector'));
	check('icon comes from the achievements/ folder', Achievements.getIconFile('first-steps') != null && Achievements.getIcon('first-steps') != null, Achievements.getIconFile('first-steps'));
	check('attached script is found', Achievements.getScriptFile('combo-starter') != null, Achievements.getScriptFile('combo-starter'));
	check('Psych data/achievements.json style still loads (built-in list intact)', Achievements.exists('ur_good') && Achievements.exists('hype'));

	Achievements.checkSongEnd(info('other-song', 80, false, false, '', 3));
	check('song_complete for a different song stays locked', !Achievements.isUnlocked('first-steps'));
	check('any-song progress goal counts +1', score('song-collector') == 1, score('song-collector'));
	check('minAccuracy 90 not met at 80%', !Achievements.isUnlocked('ach-test-acc'));

	Achievements.checkSongEnd(info('Example Song', 95, false, false, '', 3));
	check('song_complete for its song unlocks (name matched like a song path)', Achievements.isUnlocked('first-steps'));
	check('minAccuracy 90 met at 95%', Achievements.isUnlocked('ach-test-acc'));
	check('progress goal at 2 of 3', score('song-collector') == 2 && !Achievements.isUnlocked('song-collector'), score('song-collector'));

	Achievements.checkSongEnd(info('other-song', 95, true, false, '', 3));
	check('practice mode does not count by default', score('song-collector') == 2, score('song-collector'));
	check('allowPractice lets practice count', Achievements.isUnlocked('ach-test-practice'));

	Achievements.checkSongEnd(info('other-song', 95, false, false, '', 3));
	check('progress goal reached unlocks', Achievements.isUnlocked('song-collector'));

	Achievements.checkSongEnd(info('w', 95, false, false, 'exampleweek', 0));
	check('week_complete needs Story Mode', !Achievements.isUnlocked('ach-test-week'));
	Achievements.checkSongEnd(info('w', 95, false, true, 'exampleweek', 1));
	check('week_complete maxMisses 0 not met with 1 miss', !Achievements.isUnlocked('ach-test-week'));
	Achievements.checkSongEnd(info('w', 95, false, true, 'exampleweek', 0));
	check('week_complete unlocks', Achievements.isUnlocked('ach-test-week'));
	check('manual achievements never unlock from songs', !Achievements.isUnlocked('combo-starter') && !Achievements.isUnlocked('ach-test-script'));

	FlxG.save.flush();
	var saved = FlxG.save.data.achievementsUnlocked;
	check('unlocks are written to the save', saved != null && saved.indexOf('first-steps') >= 0 && saved.indexOf('ach-test-week') >= 0);
	resetAll();
	check('reset relocks', !Achievements.isUnlocked('first-steps') && score('song-collector') == 0);
	flush();
}

function onUpdate(elapsed) {
	st.t += elapsed;
	if (st.stage == 0 && st.t > 1.2) { st.stage = 1; File.saveContent('shot_devmenu.txt', '1'); }
	if (st.stage == 1 && st.t > 3.0) {
		st.stage = 2;
		logicTests();
		Mods.currentModDirectory = 'VortexAchievementTest';
		MusicBeatState.switchState(new AchievementEditorState());
	}
}
