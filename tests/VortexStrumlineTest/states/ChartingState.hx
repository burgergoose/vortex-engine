import Reflect;
import Sys;
import sys.io.File;
import tjson.TJSON;
import backend.Song;
import states.editors.ChartingState;

// Chart editor part of the strumline test. Since 0.5 strumlines are set up in the chart file (the editor's
// Strumlines menu was removed); the editor shows one column group per strumline and "Sung by" in the Note tab.
var st = {t: 0.0, stage: 0};
var out = [];
function check(name, ok, ?info) { out.push((ok ? 'PASS ' : 'FAIL ') + name + (info != null ? ' -- ' + info : '')); }
function fld(name) { return Reflect.field(game, name); }
function run(name, args) { return Reflect.callMethod(game, Reflect.field(game, name), args == null ? [] : args); }
function flush() { var f = File.append('vortex_strumtest.txt', false); f.writeString(out.join('\n') + '\n'); f.close(); out.splice(0, out.length); }

function onUpdate(elapsed) {
	st.t += elapsed;
	if (st.stage != 0 || st.t < 1.2) return;
	st.stage = 1;
	check('editor: 4 column groups for 4 strumlines', ChartingState.GRID_PLAYERS == 4, ChartingState.GRID_PLAYERS);
	check('editor: one icon per strumline', fld('icons').length == 4, fld('icons').length);
	var ub = fld('upperBox');
	check('editor: top bar is File / Edit / View (Strumlines menu removed)', ub.getTab('Strumlines') == null && ub.getTab('File') != null && ub.tabs.length == 3, ub.tabs.length);
	File.saveContent('shot_editor.txt', '1');

	var target = null;
	var all = fld('notes');
	if (all != null) for (n in all) if (n != null && n.songData != null && n.songData[1] == 10) target = n;
	check('editor: note on strumline 3 loaded', target != null);
	if (target == null) { out.push('DONE'); flush(); Sys.exit(0); }
	var sel = fld('selectedNotes');
	sel.splice(0, sel.length);
	sel.push(target);
	run('onSelectNote', null);
	check('editor: "Sung by" lists strumline 3 singers', fld('singerDropDown').list.length == 2, fld('singerDropDown').list.join(' | '));
	run('setSelectedSinger', [0]);
	check('editor: note now sung by singer 1 (5th value)', target.songData.length == 5 && target.songData[4] == 0, target.songData.join(','));
	run('saveChart', [true]);
	var saved = TJSON.parse(File.getContent(Song.chartPath));
	var root = (saved.notes != null) ? saved : saved.song; // Psych 1.0 saves charts flat
	var lines = root.strumLines;
	check('saved chart keeps 4 strumlines', lines != null && lines.length == 4, lines != null ? lines.length : null);
	var found = false;
	for (s in root.notes) for (n in s.sectionNotes) if (n[1] == 10 && n.length == 5 && n[4] == 0) found = true;
	check('saved chart keeps the note\'s singer', found);
	out.push('DONE');
	flush();
	st.stage = 2;
	st.t = 0;
}

function onUpdatePost(elapsed) {
	if (st.stage == 2 && st.t > 1.0) Sys.exit(0); // leave time for the screenshot
}
