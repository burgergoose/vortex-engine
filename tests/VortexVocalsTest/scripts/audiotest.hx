import Reflect;
import Sys;
import Math;
import sys.io.File;
import flixel.FlxG;

// Pauses / resumes the song like a player does and checks that both vocal tracks resume and stay in sync.
// state lives in one object: functions called from a signal get a copy of the script's top-level variables
var st = {phase: 0, t0: 0.0, checksDone: 0, rapid: false, hook: null, done: false};  // phase: 0 waiting, 1 paused, 2 resumed, 3 re-pause
var out = [];
var target = [3000, 7000, 11000, 15000];

function log(s) { out.push(s); }

function trackLine(name, voc) {
	var music = FlxG.sound.music;
	var len = voc.length;
	var expected = len > 0 && music.time < len - 80;
	var diff = Math.abs(voc.time - music.time);
	var ok = (voc.playing == expected) && (!voc.playing || diff < 80);
	return (ok ? 'PASS ' : 'FAIL ') + name + ': length ' + Math.round(len) + 'ms, playing ' + voc.playing + ' (should be ' + expected + '), off by ' + Math.round(diff) + 'ms, volume ' + voc.volume;
}

function pauseGame() { Reflect.callMethod(game, Reflect.field(game, 'openPauseMenu'), []); }
function resumeGame() { if (game.subState != null) game.subState.close(); }

function tick() {
	if (PlayState.instance == null || FlxG.sound.music == null) return;
	var now = Sys.time();
	var pos = Conductor.songPosition;
	if (st.phase == 0 && st.checksDone < target.length && pos >= target[st.checksDone] && !game.startingSong) {
		st.rapid = (st.checksDone == target.length - 1);
		pauseGame();
		st.phase = 1; st.t0 = now;
	}
	else if (st.phase == 1 && now - st.t0 > (st.rapid ? 0.12 : 0.7)) {
		resumeGame();
		st.phase = 2; st.t0 = now;
		if (st.rapid) { st.rapid = false; st.phase = 3; }   // pause again right away
	}
	else if (st.phase == 3 && now - st.t0 > 0.12) { pauseGame(); st.phase = 1; st.t0 = now; }
	else if (st.phase == 2 && now - st.t0 > 0.8) {
		st.checksDone = st.checksDone + 1;
		log('  pause #' + st.checksDone + (st.checksDone == target.length ? ' (rapid double pause)' : '') + ' at ' + Math.round(FlxG.sound.music.time) + 'ms');
		log('    ' + trackLine('player vocals  ', game.vocals));
		log('    ' + trackLine('opponent vocals', game.opponentVocals));
		st.phase = 0;
		if (st.checksDone >= target.length) {
			// like the pause menu's Skip Time: jump 3 s ahead
			var to = Conductor.songPosition + 3000;
			game.clearNotesBefore(to);
			game.setSongTime(to);
			st.phase = 4; st.t0 = now;
		}
	}
	else if (st.phase == 4 && now - st.t0 > 0.8) {
		log('  skip time to ' + Math.round(FlxG.sound.music.time) + 'ms');
		log('    ' + trackLine('player vocals  ', game.vocals));
		log('    ' + trackLine('opponent vocals', game.opponentVocals));
		finish();
	}
}

function finish() {
	if (st.done) return;
	st.done = true;
	FlxG.signals.preUpdate.remove(st.hook);
	var f = File.append('vortex_audiotest.txt', false);
	f.writeString('SONG ' + PlayState.SONG.song + '\n' + out.join('\n') + '\n');
	f.close();
	setGlobalVar('at_index', getGlobalVar('at_index', 1) + 1);
	switchState('AudioRunner');
}

function onCreatePost() {
	game.cpuControlled = true;
	st.hook = tick;
	FlxG.signals.preUpdate.add(st.hook);
}

function onDestroy() {
	FlxG.signals.preUpdate.remove(st.hook);
}
