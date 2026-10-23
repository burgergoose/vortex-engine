import Math;
import sys.io.File;
import backend.Song;
import backend.Mods;
import states.LoadingState;

var st = {hits4800: [], hits10200: [], done: false, checked: []};
var out = [];
function check(name, ok, ?info) { out.push((ok ? 'PASS ' : 'FAIL ') + name + (info != null ? ' -- ' + info : '')); }
function sings(c) { return c != null && StringTools.startsWith(c.getAnimationName(), 'sing'); }
function anims(list) { var a = []; for (c in list) a.push(c.curCharacter + '=' + c.getAnimationName()); return a.join(', '); }
function flush() { var f = File.append('vortex_strumtest.txt', false); f.writeString(out.join('\n') + '\n'); f.close(); out.splice(0, out.length); }

function onCreatePost() {
	game.cpuControlled = true;
	var L = game.strumLines;
	check('chart has 4 strumlines', L.length == 4, L.length);
	check('types player/opponent/player/additional', L[0].type == 'player' && L[1].type == 'opponent' && L[2].type == 'player' && L[3].type == 'additional', L[0].type + '/' + L[1].type + '/' + L[2].type + '/' + L[3].type);
	check('singers per line 2/1/1/2', L[0].characters.length == 2 && L[1].characters.length == 1 && L[2].characters.length == 1 && L[3].characters.length == 2);
	check('line 1 main singer is boyfriend, line 2 is dad', L[0].characters[0] == game.boyfriend && L[1].characters[0] == game.dad);
	var extra = L[0].characters[1];
	check('extra singer stands at boyfriend + 260', extra != null && Math.abs(extra.x - (game.BF_X + 260 + extra.positionArray[0])) < 0.01, extra != null ? extra.x : null);
	check('flipX turns a player-side singer back around (dad faces right)', extra != null && extra.flipX == false, extra != null ? extra.flipX : null);
	var backup = L[3].characters[1];
	check('additional singer stands at dad - 560', backup != null && Math.abs(backup.x - (game.DAD_X - 560 + backup.positionArray[0])) < 0.01);
	check('16 arrows (4 per strumline)', game.strumLineNotes.length == 16, game.strumLineNotes.length);
	check('Psych arrow indexes unchanged (0-3 opponent, 4-7 player)', game.strumLineNotes.members[0] == game.opponentStrums.members[0] && game.strumLineNotes.members[4] == game.playerStrums.members[0]);
	check('half-size arrows on the extra lines', Math.abs(L[2].strums.members[0].scale.x - game.playerStrums.members[0].scale.x * 0.5) < 0.01);
	check('extra singers registered as variables', game.variables.exists('strumLine0_char1') && game.variables.exists('strumLine3_char1'));
	var heads = game.unspawnNotes.filter(function(n) return !n.isSustainNote).length + game.notes.members.filter(function(n) return n != null && !n.isSustainNote).length;
	var bad = game.unspawnNotes.filter(function(n) return n.strumLine >= 4).length;
	check('note in the undefined 6th strumline was skipped (9 kept, none on a missing line)', heads == 9 && bad == 0, heads + ' kept, ' + bad + ' on missing lines (unspawn ' + game.unspawnNotes.length + ')');
	check('...and reported in the script log', getScriptErrorCount() >= 1, getScriptErrorCount());
	flush();
}

function goodNoteHit(note) {
	if (note.isSustainNote) return;
	var t = Math.round(note.strumTime);
	var L = game.strumLines;
	if (t == 2400) check('note for singer 2 only: extra singer sings, boyfriend does not', sings(L[0].characters[1]) && !sings(game.boyfriend), anims(L[0].characters));
	if (t == 3600) check('note for everyone: both singers of the line sing', sings(L[0].characters[0]) && sings(L[0].characters[1]), anims(L[0].characters));
	if (t == 4800) st.hits4800.push(note.strumLine);
	if (t == 10200) st.hits10200.push(note.strumLine);
	if (t == 4800 && note.strumLine == 2) check('extra player line: its singer sings', sings(L[2].characters[0]), anims(L[2].characters));
}

function opponentNoteHit(note) {
	if (note.isSustainNote) return;
	var t = Math.round(note.strumTime);
	var L = game.strumLines;
	if (t == 6000) check('additional line, everyone: both backup singers sing', note.strumLine == 3 && sings(L[3].characters[0]) && sings(L[3].characters[1]), anims(L[3].characters));
	if (t == 7800) check('additional line, singer 1 only', note.strumLine == 3 && sings(L[3].characters[0]) && !sings(L[3].characters[1]), anims(L[3].characters));
	if (t == 9000) check('opponent line: dad sings, backup singers do not join', note.strumLine == 1 && sings(game.dad) && !sings(L[3].characters[0]), anims([game.dad, L[3].characters[0]]));
}

function onUpdatePost(elapsed) {
	if (st.done || Conductor.songPosition < 11600) return;
	st.done = true;
	check('simultaneous notes on 2 player lines both hit', st.hits4800.indexOf(0) >= 0 && st.hits4800.indexOf(2) >= 0, st.hits4800.join(','));
	check('simultaneous holds on 2 player lines both hit', st.hits10200.indexOf(0) >= 0 && st.hits10200.indexOf(2) >= 0, st.hits10200.join(','));
	check('combo counts only player-line notes (6)', game.combo == 6, game.combo);
	flush();
	// next: a plain Psych chart must play exactly like before
	Mods.currentModDirectory = 'Vortex-Example-Mod';
	Song.loadFromJson('example-song', 'example-song');
	LoadingState.prepareToSong();
	LoadingState.loadAndSwitchState(new PlayState());
}
