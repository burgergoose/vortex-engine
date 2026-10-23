import Reflect;
import sys.io.File;
import backend.Song;
import backend.Mods;
import backend.MusicBeatState;
import states.editors.ChartingState;

// only for the plain Psych chart (Example Song). st.mine: this copy of the script was started by the Example Song game
// (the strumline song's copy sees PlayState.SONG change to Example Song a moment before the switch and must ignore it)
var st = {done: false, sang: false, mine: false};
var out = [];
function check(name, ok, ?info) { out.push((ok ? 'PASS ' : 'FAIL ') + name + (info != null ? ' -- ' + info : '')); }

function onCreatePost() {
	if (PlayState.SONG.song != 'Example Song') return;
	st.mine = true;
	game.cpuControlled = true;
	check('legacy chart: 2 strumlines', game.strumLines.length == 2, game.strumLines.length);
	check('legacy chart: 8 arrows', game.strumLineNotes.length == 8, game.strumLineNotes.length);
	check('legacy chart: no strumLines added to the song data', Reflect.field(PlayState.SONG, 'strumLines') == null);
	check('legacy chart: no extra singers', game.extraStrumLineCharacters().length == 0);
}

function goodNoteHit(note) {
	if (!st.mine || st.sang || note.isSustainNote) return;
	st.sang = true;
	check('legacy chart: boyfriend sings player notes', StringTools.startsWith(game.boyfriend.getAnimationName(), 'sing'), game.boyfriend.getAnimationName());
	check('legacy chart: note belongs to line 0', game.lineIndexOf(note) == 0 && note.strumLine == 0);
}

function opponentNoteHit(note) {
	if (!st.mine || note.isSustainNote) return;
	if (out.length < 9) check('legacy chart: dad sings opponent notes', StringTools.startsWith(game.dad.getAnimationName(), 'sing') && game.lineIndexOf(note) == 1, game.dad.getAnimationName());
}

function onUpdatePost(elapsed) {
	if (!st.mine || st.done || Conductor.songPosition < 9000) return;
	st.done = true;
	var f = File.append('vortex_strumtest.txt', false);
	f.writeString(out.join('\n') + '\n');
	f.close();
	// next: the chart editor with the strumline chart
	Mods.currentModDirectory = 'VortexStrumlineTest';
	Song.loadFromJson('strum-test', 'strum-test');
	MusicBeatState.switchState(new ChartingState());
}
