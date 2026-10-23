import Reflect;
import sys.io.File;
import sys.FileSystem;
import backend.Mods;
import backend.Song;
import backend.WeekData;
import backend.StageData;
import backend.Paths;
import backend.compat.CompatLayer;
import objects.Character;
import states.LoadingState;

// Engine-compatibility test, part 1: detection, translation and loading (no gameplay yet).
var out = [];
function check(name, ok, ?info) { out.push((ok ? 'PASS ' : 'FAIL ') + name + (info != null ? ' -- ' + info : '')); }
function flush() { var f = File.append('vortex_compattest.txt', false); f.writeString(out.join('\n') + '\n'); f.close(); out.splice(0, out.length); }
function countNotes(song) { var n = 0; for (s in song.notes) n += s.sectionNotes.length; return n; }
function allNotes(song) { var a = []; for (s in song.notes) for (n in s.sectionNotes) a.push(n); return a; }
function eventNames(song) { var a = []; for (e in song.events) for (x in e[1]) a.push(x[0]); return a; }
function findEvent(song, name) { for (e in song.events) for (x in e[1]) if (x[0] == name) return x; return null; }
function report(mod) { var r = CompatLayer.reports.get(mod); return r == null ? '' : r.toText(); }
function has(text, part) { return text != null && text.indexOf(part) > -1; }
function objTypes(stage) { var a = []; for (o in stage.objects) a.push(o.name != null ? o.name : o.type); return a.join(','); }

function onCreatePost() {
	if (getGlobalVar('ct_started', false)) return;
	setGlobalVar('ct_started', true);
	File.saveContent('vortex_compattest.txt', 'Vortex Engine compatibility test\n');

	WeekData.reloadWeekFiles(false);
	var det = CompatLayer.detections;
	check('detect V-Slice', det.get('CompatVSlice') != null && det.get('CompatVSlice').engine == 'vslice', det.get('CompatVSlice') != null ? det.get('CompatVSlice').version : 'none');
	check('detect Codename Engine', det.get('CompatCodename') != null && det.get('CompatCodename').engine == 'codename');
	check('detect Psych 0.6-style', det.get('CompatPsych06') != null && det.get('CompatPsych06').engine == 'psych', det.get('CompatPsych06') != null ? det.get('CompatPsych06').version : 'none');
	check('detect FPS Plus layout', det.get('CompatFPSPlus') != null && det.get('CompatFPSPlus').engine == 'fpsplus');
	check('detect Forever Engine layout', det.get('CompatForever') != null && det.get('CompatForever').engine == 'forever');
	check('bundled example mod stays Psych (not translated)', det.get('Vortex-Example-Mod') != null && det.get('Vortex-Example-Mod').engine == 'psych' && !CompatLayer.hasCache('Vortex-Example-Mod'));
	check('translation cache made outside the mod folder', FileSystem.exists('vortex_compat/CompatVSlice/data/vs-test/vs-test.json') && !FileSystem.exists('mods/CompatVSlice/data/vs-test'));
	check('report written', FileSystem.exists('vortex_compat/CompatVSlice/report.txt') && FileSystem.exists('vortex_compat_log.txt'));

	var weeks = WeekData.weeksList;
	for (w in ['vsweek', 'vslice-unlisted-songs', 'cneweek', 'codename-freeplay', 'oldweek', 'fpsplus-songs', 'forever-songs'])
		check('Freeplay has week ' + w, weeks.indexOf(w) > -1);
	var vsweek = WeekData.weeksLoaded.get('vsweek');
	check('V-Slice level -> week with its folder set', vsweek != null && vsweek.folder == 'CompatVSlice' && vsweek.songs.length == 1 && vsweek.storyName == 'VS WEEK', vsweek != null ? vsweek.songs.length + ' songs' : null);
	WeekData.reloadWeekFiles(true);
	check('Freeplay-only weeks stay out of Story Mode', WeekData.weeksList.indexOf('vslice-unlisted-songs') < 0 && WeekData.weeksList.indexOf('vsweek') > -1 && WeekData.weeksList.indexOf('cneweek') > -1);

	// ---------------- V-Slice chart
	Mods.currentModDirectory = 'CompatVSlice';
	var s = Song.getChart('vs-test', 'vs-test');
	check('V-Slice chart loads', s != null);
	if (s != null) {
		check('V-Slice: 8 notes of the "normal" chart (lane 12 note left out)', countNotes(s) == 8, countNotes(s));
		check('V-Slice: scroll speed of the normal chart', s.speed == 1.5, s.speed);
		check('V-Slice: characters + stage', s.player1 == 'bf' && s.player2 == 'vs-dad' && s.gfVersion == 'gf' && s.stage == 'vsStage', s.player2 + '/' + s.stage);
		check('V-Slice: 120 BPM, 2000 ms sections', s.bpm == 120 && s.notes[0].sectionBeats == 4);
		check('V-Slice: BPM change 150 on the section boundary', s.notes[4].changeBPM == true && s.notes[4].bpm == 150, s.notes[4].bpm);
		check('V-Slice: mid-section BPM change makes a 2.5-beat section', s.notes[4].sectionBeats == 2.5 && s.notes[5].bpm == 100, s.notes[4].sectionBeats + ' / ' + s.notes[5].bpm);
		check('V-Slice: FocusCamera -> mustHitSection (dad, bf, dad)', s.notes[0].mustHitSection == false && s.notes[1].mustHitSection == true && s.notes[2].mustHitSection == false);
		var times = [for (n in allNotes(s)) n[0]];
		check('V-Slice: note times exact', times.indexOf(500) > -1 && times.indexOf(8500) > -1 && times.indexOf(9500) > -1);
		var hurt = false; var hold = false;
		for (n in allNotes(s)) { if (n[3] == 'hurt') hurt = true; if (n[0] == 3000 && n[2] == 400 && n[1] == 1) hold = true; }
		check('V-Slice: note kind -> note type, hold length kept', hurt && hold);
		var spd = findEvent(s, 'Change Scroll Speed');
		check('V-Slice: absolute ScrollSpeed 2.25 -> x1.5 of 1.5', spd != null && spd[1] == '1.5', spd != null ? spd[1] + ' ' + spd[2] : null);
		var anim = findEvent(s, 'Play Animation');
		check('V-Slice: PlayAnimation -> Play Animation (hey, bf)', anim != null && anim[1] == 'hey' && anim[2] == 'bf');
		check('V-Slice: ZoomCamera -> Zoom Camera, unknown events kept (not dropped)', findEvent(s, 'Zoom Camera') != null && findEvent(s, 'MyCustomEvent') != null, eventNames(s).join(','));
	}
	var rv = report('CompatVSlice');
	check('V-Slice report: variation, difficulties, kinds, scripts, broken files', has(rv, 'erect') && has(rv, 'easy, hard') && has(rv, 'note kind "hurt"') && has(rv, 'vs-broken') && has(rv, 'missing-song') && has(rv, 'vs-test.hxc') && has(rv, 'MyCustomEvent'));
	var st = StageData.getStageFile('vsStage');
	check('V-Slice stage: props + characters ordered by zIndex', st.objects != null && objTypes(st) == 'back,shade,front,gf,dad,boyfriend,curtains', st.objects != null ? objTypes(st) : null);
	check('V-Slice stage: mainStage-style feet positions -> Psych positions', st.boyfriend[0] == 770 && st.boyfriend[1] == 100 && st.opponent[0] == 100 && st.girlfriend[0] == 400 && st.defaultZoom == 1.1, st.boyfriend + ' ' + st.opponent + ' ' + st.girlfriend);
	check('V-Slice stage: solid color prop -> square', st.objects[1].type == 'square' && st.objects[1].color == '000000');
	var c = new Character(0, 0, 'vs-dad');
	check('V-Slice character loads (image + animations)', c.curCharacter == 'vs-dad' && c.animation.getByName('singLEFT') != null && c.healthIcon == 'dad', c.healthIcon);
	c.destroy();

	// ---------------- Codename chart
	Mods.currentModDirectory = 'CompatCodename';
	var cn = Song.getChart('cne-test', 'cne-test');
	check('Codename chart loads', cn != null);
	if (cn != null) {
		var lines = Reflect.field(cn, 'strumLines');
		check('Codename: 3 strumlines (player, opponent, additional; empty gf line dropped)', lines != null && lines.length == 3 && lines[0].type == 'player' && lines[1].type == 'opponent' && lines[2].type == 'additional', lines != null ? lines.length : null);
		check('Codename: additional line keeps both singers', lines != null && lines[2].characters.length == 2 && lines[2].characters[0].name == 'dad');
		var cols = [for (n in allNotes(cn)) n[1]];
		cols.sort(function(a, b) return a - b);
		check('Codename: notes on the right columns (bad id left out)', cols.join(',') == '2,3,4,5,8', cols.join(','));
		var typed = false;
		for (n in allNotes(cn)) if (n[0] == 1200 && n[3] == 'Hurt Note' && n[2] == 300) typed = true;
		check('Codename: note type + sustain', typed);
		check('Codename: characters / gf / stage / speed', cn.player1 == 'bf' && cn.player2 == 'cne-dad' && cn.gfVersion == 'gf' && cn.stage == 'cnestage' && cn.speed == 2);
		check('Codename: Camera Movement -> sections', cn.notes[0].mustHitSection == false && cn.notes[1].mustHitSection == true);
		var bpmSec = null;
		for (sec in cn.notes) if (sec.changeBPM == true) bpmSec = sec;
		check('Codename: BPM Change event -> section BPM', bpmSec != null && bpmSec.bpm == 150);
		var z = findEvent(cn, 'Add Camera Zoom');
		check('Codename: Add Camera Zoom on camHUD -> value 2', z != null && z[1] == '0' && z[2] == '0.05');
		var pa = findEvent(cn, 'Play Animation');
		check('Codename: Play Animation on the player line -> bf', pa != null && pa[2] == 'bf');
		check('Codename: HScript Call kept and reported', findEvent(cn, 'HScript Call') != null && has(report('CompatCodename'), 'HScript Call'));
		check('Codename: audio from songs/<song>/song/', Paths.instFile('cne-test') != null, Paths.instFile('cne-test'));
	}
	var rc = report('CompatCodename');
	check('Codename report: note type, scripts, unknown stage element, missing week song', has(rc, 'Hurt Note') && has(rc, 'script.hx') && has(rc, '<ratings>') && has(rc, 'not-here'));
	var cst = StageData.getStageFile('cnestage');
	check('Codename stage: sprites, solid, high-memory and character order', objTypes(cst) == 'back,shade,front,gf,dad,boyfriend,curtains' && cst.objects[1].type == 'square' && cst.camera_opponent[0] == 50, objTypes(cst));
	var cc = new Character(0, 0, 'cne-dad');
	check('Codename character XML loads', cc.curCharacter == 'cne-dad' && cc.animation.getByName('singUP') != null && cc.animation.getByName('idle-loop') != null);
	cc.destroy();
	var cw = WeekData.weeksLoaded.get('cneweek');

	// ---------------- Psych 0.6, FPS Plus, Forever
	Mods.currentModDirectory = 'CompatPsych06';
	var old = Song.getChart('old-song', 'old-song');
	if (old != null) {
		var cols6 = [for (n in allNotes(old)) n[0] + ':' + n[1]];
		check('Psych 0.6 chart: old must-hit-relative columns converted', cols6.indexOf('500:4') > -1 && cols6.indexOf('800:1') > -1 && cols6.indexOf('2400:1') > -1 && cols6.indexOf('2600:6') > -1, cols6.join(' '));
		check('Psych 0.6 chart: player3 -> gfVersion, -1 note -> event', old.gfVersion == 'gf' && findEvent(old, 'Hey!') != null);
	}
	else check('Psych 0.6 chart loads', false);
	check('Psych 0.6 report mentions old class names', has(report('CompatPsych06'), 'Psych 0.6-style class names'));

	Mods.currentModDirectory = 'CompatFPSPlus';
	var fps = Song.getChart('fps-test', 'fps-test');
	check('FPS Plus chart loads (4 notes)', fps != null && countNotes(fps) == 4, fps != null ? countNotes(fps) : null);
	check('FPS Plus: unreadable events kept aside and reported', fps != null && Reflect.field(fps, 'vortexOriginalEvents') != null && has(report('CompatFPSPlus'), 'vortexOriginalEvents'));
	Mods.currentModDirectory = 'CompatForever';
	var fe = Song.getChart('fe-test', 'fe-test');
	check('Forever chart loads (3 notes)', fe != null && countNotes(fe) == 3, fe != null ? countNotes(fe) : null);
	check('Forever: missing character reported for manual work', has(report('CompatForever'), 'pico-forever'));

	// ---------------- 0.6: laid out like real GameBanana V-Slice mods
	var r2 = report('CompatVSlice2');
	check('0.6 real layout: detected as V-Slice', det.get('CompatVSlice2') != null && det.get('CompatVSlice2').engine == 'vslice');
	check('0.6 library folders searched (shared, week1, videos)', CompatLayer.prefixesOf('CompatVSlice2').join(',') == 'shared/,week1/,videos/', CompatLayer.prefixesOf('CompatVSlice2').join(','));
	Mods.currentModDirectory = 'CompatVSlice2';
	check('0.6 picture in shared/images is found', Paths.image('characters/rl-dad') != null);
	check('0.6 video in videos/videos is found', FileSystem.exists(Paths.video('rl-cutscene')), Paths.video('rl-cutscene'));
	var c2 = new Character(0, 0, 'rl-dad');
	check('0.6 character with art in shared/images loads (not the BF fallback)', c2.curCharacter == 'rl-dad' && c2.animation.getByName('singLEFT') != null && c2.healthIcon == 'dad');
	c2.destroy();
	var c3 = new Character(0, 0, 'rl-dad-alt');
	check('0.6 character with art in week1/images ("week1:" assetPath) loads', c3.curCharacter == 'rl-dad-alt' && c3.animation.getByName('idle') != null);
	c3.destroy();
	check('0.6 .astc-only character explained as a mobile build', has(r2, 'rl-mobile') && has(r2, 'mobile-only version'));
	check('0.6 Mac junk (__MACOSX, ._ files) ignored', !has(r2, '._rl-song') && !has(r2, '__MACOSX'));
	check('0.6 variation noted, duplicate level file skipped', has(r2, 'variation "pico"') && has(r2, 'another level called "RL Week"'));
	var rl = Song.getChart('rl-song', 'rl-song');
	check('0.6 real-layout song loads ("hard" only)', rl != null && countNotes(rl) == 3 && rl.speed == 2, rl != null ? countNotes(rl) : null);
	if (rl != null) {
		check('0.6 vocals by V-Slice rules (playerVocals bf-car -> Voices-bf, opponent rl-dad)', Reflect.field(rl, 'vortexPlayerVocals') == 'bf' && Reflect.field(rl, 'vortexOpponentVocals') == 'rl-dad', Reflect.field(rl, 'vortexPlayerVocals') + '/' + Reflect.field(rl, 'vortexOpponentVocals'));
		var cc = findEvent(rl, 'Change Character');
		check('0.6 ChangeCharacter -> Change Character', cc != null && cc[1] == 'dad' && cc[2] == 'rl-dad-alt');
		var zc = findEvent(rl, 'Zoom Camera');
		check('0.6 ZoomCamera -> Zoom Camera (x1.2 of the stage, 1 s expoIn)', zc != null && zc[1] == 'x1.2' && zc[2] == '1,expoIn', zc != null ? zc[1] + ' ' + zc[2] : null);
		var cs = findEvent(rl, 'Change Stage');
		check('0.6 ChangeStage (mainStage) -> Change Stage to the built-in stage', cs != null && cs[2] == 'stage');
		var sh = findEvent(rl, 'Screen Shake');
		check('0.6 Psych-style event in a V-Slice chart keeps its values', sh != null && sh[1] == '0.2,0.01');
		check('0.6 script-only event reported', has(r2, 'NoteSwapEvent'));
	}
	var odd = Song.getChart('oddname', 'oddname');
	check('0.6 song files with other names found by their content', odd != null && countNotes(odd) == 1);

	// 0.6: a stage built by its V-Slice script (empty "props", sprites made in scripts/stages/rl-scripted.hxc)
	var base = StageData.getStageFile('rl-scripted');
	check('0.6 scripted stage: sprites read from the script, in add order, behind the characters', base != null && objTypes(base) == 'sky,floor,screen,gf,dad,boyfriend', base != null ? objTypes(base) : 'no stage');
	if (base != null && objTypes(base) == 'sky,floor,screen,gf,dad,boyfriend') {
		var sky = base.objects[0], floor = base.objects[1], screen = base.objects[2];
		check('0.6 scripted stage: picture, scroll, scale (centre-scaled like flixel)', sky.type == 'sprite' && sky.image == 'background/rl-sky' && sky.x == -132 && sky.y == -66 && sky.scale[0] == 2 && sky.scroll[0] == 0.5, sky.x + ',' + sky.y + ' ' + sky.scale + ' ' + sky.scroll);
		check('0.6 scripted stage: helper function, FunkinSprite.create, setGraphicSize + updateHitbox', floor.x == 10 && floor.y == 600 && floor.scale[0] == 10 && floor.scale[1] == 10, floor.x + ',' + floor.y + ' ' + floor.scale);
		check('0.6 scripted stage: makeGraphic + screenCenter', screen.type == 'square' && screen.x == 590 && screen.y == 335 && screen.scale[0] == 100 && screen.scale[1] == 50 && screen.color == '00FF00', screen.x + ',' + screen.y + ' ' + screen.scale + ' ' + screen.color);
	}
	var ss = Song.getChart('script-song', 'script-song');
	check('0.6 scripted stage: song-specific sprites give the song its own stage', ss != null && ss.stage == 'rl-scripted-script-song', ss != null ? ss.stage : 'no chart');
	var sv = StageData.getStageFile('rl-scripted-script-song');
	check('0.6 scripted stage: switch on the song id followed (dancer with zIndex 250 between dad and bf)', sv != null && objTypes(sv) == 'sky,floor,screen,gf,dad,dancer,boyfriend', sv != null ? objTypes(sv) : 'no stage');
	check('0.6 scripted stage: "return" for one song stops there', odd != null && odd.stage == 'rl-scripted-oddname' && StageData.getStageFile('rl-scripted-oddname') != null && objTypes(StageData.getStageFile('rl-scripted-oddname')) == 'sky,floor,gf,dad,boyfriend', odd != null ? odd.stage : 'no chart');
	if (sv != null) {
		var made = StageData.addObjectsToState(sv.objects, null, null, null, null, true);
		var dancer = made.get('dancer');
		var skySpr = made.get('sky');
		check('0.6 scripted stage loads in game (atlas animation, picture size)', dancer != null && dancer.animation.curAnim != null && dancer.animation.curAnim.name == 'bop' && skySpr != null && skySpr.frameWidth == 64 && skySpr.width == 128, dancer != null && dancer.animation.curAnim != null ? dancer.animation.curAnim.name : 'no dancer');
		for (k in made.keys()) made.get(k).destroy();
	}
	var r3 = report('CompatVSlice2');
	check('0.6 scripted stage reported (hidden / HUD sprites left out, song-time changes not converted)', has(r3, 'starts hidden') && has(r3, 'drawn on the HUD') && has(r3, 'changes the stage while the song plays (onBeatHit)'));
	WeekData.reloadWeekFiles(true);
	var rw = WeekData.weeksLoaded.get('RL Week');
	check('0.6 level title picture becomes the Story Mode banner', rw != null && rw.bannerImage == 'storymenu/titles/rlweek', rw != null ? rw.bannerImage : WeekData.weeksList.join(','));
	check('0.6 nested Psych mod: its week shows up', WeekData.weeksList.indexOf('nestweek') > -1 && WeekData.weeksLoaded.get('nestweek').folder == 'CompatNested');
	check('0.6 hideBaseGameWeeks hides tutorial + week2 only', WeekData.weeksList.indexOf('tutorial') < 0 && WeekData.weeksList.indexOf('week2') < 0 && WeekData.weeksList.indexOf('week1') > -1 && WeekData.weeksList.indexOf('week3') > -1, WeekData.weeksList.join(','));
	Mods.currentModDirectory = 'CompatNested';
	var ns = Song.getChart('nest-song', 'nest-song');
	check('0.6 nested Psych mod: chart and audio found', ns != null && countNotes(ns) == 2 && Paths.instFile('nest-song') != null);
	check('0.6 nested mod reported', has(report('CompatNested'), 'one folder too deep'));
	Mods.currentModDirectory = '';
	var pp = new Character(0, 0, 'pico-playable');
	check('0.6 base game characters ship (pico-playable)', pp.curCharacter == 'pico-playable' && pp.animation.getByName('idle') != null);
	pp.destroy();

	flush();
	// part 2 (scripts/compat.hx): play the V-Slice song
	Mods.currentModDirectory = 'CompatVSlice';
	Song.loadFromJson('vs-test', 'vs-test');
	PlayState.isStoryMode = false;
	PlayState.storyDifficulty = 0;
	LoadingState.prepareToSong();
	LoadingState.loadAndSwitchState(new PlayState());
}
