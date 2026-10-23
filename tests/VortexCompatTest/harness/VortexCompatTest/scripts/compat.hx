import Reflect;
import Sys;
import sys.io.File;
import backend.Mods;
import backend.Song;
import states.LoadingState;

// Engine-compatibility test, part 2: the translated songs really play. st.mine = this copy was started by the song
// it checks (the previous song's copy sees PlayState.SONG change a moment before the switch).
var st = {mine: '', hits: 0, opp: 0, done: false};
var out = [];
function check(name, ok, ?info) { out.push((ok ? 'PASS ' : 'FAIL ') + name + (info != null ? ' -- ' + info : '')); }
function flush() { var f = File.append('vortex_compattest.txt', false); f.writeString(out.join('\n') + '\n'); f.close(); out.splice(0, out.length); }
function next(mod, song) {
	Mods.currentModDirectory = mod;
	Song.loadFromJson(song, song);
	LoadingState.prepareToSong();
	LoadingState.loadAndSwitchState(new PlayState());
}

function onCreatePost() {
	st.mine = PlayState.SONG.song;
	game.cpuControlled = true;
	if (st.mine == 'VS Test') {
		check('play V-Slice song: opponent is the converted character', game.dad.curCharacter == 'vs-dad');
		check('play V-Slice song: converted stage sprites are on screen', game.variables.exists('back') && game.variables.exists('curtains') && game.variables.get('shade').alpha == 0.5);
	}
	if (st.mine == 'CNE Test') check('play Codename song: 3 strumlines, 12 arrows', game.strumLines.length == 3 && game.strumLineNotes.length == 12, game.strumLines.length);
}

function goodNoteHit(note) { if (!note.isSustainNote) st.hits++; }
function opponentNoteHit(note) { if (!note.isSustainNote) st.opp++; }

function onUpdatePost(elapsed) {
	if (st.done || st.mine != PlayState.SONG.song) return;
	if (st.mine == 'VS Test' && Conductor.songPosition > 4200) {
		st.done = true;
		check('play V-Slice song: instrumental plays', game.inst != null && game.inst.length > 0 && FlxG.sound.music.playing);
		check('play V-Slice song: Voices-bf.ogg / Voices-vs-dad.ogg found by character name', game.vocals.length > 0 && game.opponentVocals.length > 0, game.vocals.length + ' / ' + game.opponentVocals.length);
		check('play V-Slice song: notes are hit', st.hits >= 2 && st.opp >= 2, st.hits + ' player, ' + st.opp + ' opponent');
		flush();
		next('CompatCodename', 'cne-test');
	}
	if (st.mine == 'CNE Test' && Conductor.songPosition > 3800) {
		st.done = true;
		check('play Codename song: instrumental + vocals from song/ folder', FlxG.sound.music.length > 0 && game.vocals.length > 0, FlxG.sound.music.length + ' / ' + game.vocals.length);
		check('play Codename song: all strumlines hit their notes', st.hits >= 2 && st.opp >= 3, st.hits + ' player, ' + st.opp + ' cpu');
		flush();
		next('CompatPsych06', 'old-song');
	}
	if (st.mine == 'Old Song' && Conductor.songPosition > 3200) {
		st.done = true;
		check('legacy Lua: getPropertyFromClass(\'ClientPrefs\', \'downScroll\') works', getGlobalVar('legacy_down_type', '') == 'boolean', getGlobalVar('legacy_down_type', 'unset'));
		check('legacy Lua: PlayState / Conductor class names work', getGlobalVar('legacy_song', '') == 'Old Song' && getGlobalVar('legacy_bpm', 0) == 130, getGlobalVar('legacy_song', '') + ' ' + getGlobalVar('legacy_bpm', 0));
		check('play Psych 0.6 song: notes are hit', st.hits >= 2 && st.opp >= 2, st.hits + ' / ' + st.opp);
		flush();
		next('CompatForever', 'fe-test');
	}
	if (st.mine == 'fe-test' && Conductor.songPosition > 1500) {
		st.done = true;
		check('play Forever song', FlxG.sound.music.length > 0 && st.hits >= 1, st.hits);
		flush();
		next('CompatVSlice2', 'rl-song');
	}
	if (st.mine == 'RL Song' && !st.done) {
		if (Conductor.songPosition > 1300 && getGlobalVar('rl_char', '') == '') setGlobalVar('rl_char', game.dad.curCharacter);
		if (Conductor.songPosition > 2900 && getGlobalVar('rl_zoom', 0) == 0) setGlobalVar('rl_zoom', game.defaultCamZoom);
		if (Conductor.songPosition > 3900) {
			st.done = true;
			check('0.6 play real-layout song: vocals Voices-bf + Voices-rl-dad loaded', game.vocals.length > 0 && game.opponentVocals.length > 0, game.vocals.length + ' / ' + game.opponentVocals.length);
			check('0.6 play: Change Character event switched the opponent', getGlobalVar('rl_char', '') == 'rl-dad-alt', getGlobalVar('rl_char', ''));
			check('0.6 play: Zoom Camera event zoomed to 1.2x the stage', Math.abs(getGlobalVar('rl_zoom', 0) - 1.2) < 0.05, getGlobalVar('rl_zoom', 0));
			check('0.6 play: Change Stage event moved to the built-in stage', PlayState.curStage == 'stage', PlayState.curStage);
			out.push('DONE');
			flush();
			Sys.exit(0);
		}
	}
}
