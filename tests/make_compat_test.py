"""Builds the engine-compatibility test mods (run from the repo root):
    python tests/make_compat_test.py

Writes small mods in other engines' formats into tests/VortexCompatTest/fixtures/ (git-ignored) and copies the
example song's audio into them. They are hand-made samples of each engine's file layout, written for this test
(not real released mods):
    CompatVSlice    V-Slice: data/songs/<id>/<id>-metadata.json + -chart.json, data/characters, data/stages, data/levels
    CompatCodename  Codename Engine: songs/<id>/charts/*.json + meta.json, song/ audio folder, XML characters / stages / weeks
    CompatPsych06   Psych Engine 0.6-style: old chart format, separate events.json, Lua with old class names
    CompatFPSPlus   base-game chart in data/songs/<id>/<id>.json with an events format Psych can't read
    CompatForever   base-game chart kept in songs/<id>/ next to the audio
    CompatVSlice2   (0.6) laid out like real GameBanana V-Slice mods: shared/ and week1/ art, playerVocals, community events,
                    a level title picture, odd file names, __MACOSX junk, an .astc-only character, a stage built by its script
    CompatNested    (0.6) a Psych mod extracted one folder too deep
    CompatHideBase  (0.6) hides two base-game weeks with "hideBaseGameWeeks" in pack.json
Copy every folder in fixtures/ plus tests/VortexCompatTest/harness/VortexCompatTest into export/.../bin/mods/.
"""
import json, os, shutil

ROOT = 'tests/VortexCompatTest/fixtures'
AUDIO = 'example_mods/Vortex-Example-Mod/songs/example-song'


def write(path, data):
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(data if isinstance(data, str) else json.dumps(data, indent='\t'))


def audio(dest, names):
    """names: {'Inst.ogg': 'Inst.ogg', 'Voices-bf.ogg': 'Voices-Player.ogg'}  target -> source"""
    d = os.path.join(ROOT, dest)
    os.makedirs(d, exist_ok=True)
    for target, source in names.items():
        shutil.copy(os.path.join(AUDIO, source), os.path.join(d, target))


DAD_ANIMS = [('idle', 'Dad idle dance', [0, 0]), ('singLEFT', 'Dad Sing Note LEFT', [-9, 10]), ('singDOWN', 'Dad Sing Note DOWN', [0, -30]),
             ('singUP', 'Dad Sing Note UP', [-6, 50]), ('singRIGHT', 'Dad Sing Note RIGHT', [0, 27])]

if os.path.isdir(ROOT):
    shutil.rmtree(ROOT)

# ---------------------------------------------------------------- V-Slice
write('CompatVSlice/_polymod_meta.json', {'title': 'Compat V-Slice', 'description': 'test fixture', 'api_version': '0.6.3', 'mod_version': '1.0.0', 'license': 'test'})
write('CompatVSlice/data/songs/vs-test/vs-test-metadata.json', {
    'version': '2.2.4', 'songName': 'VS Test', 'artist': 'test', 'timeFormat': 'ms', 'divisions': 96, 'looped': False,
    'timeChanges': [{'t': 0, 'b': 0, 'bpm': 120, 'n': 4, 'd': 4, 'bt': [4, 4, 4, 4]}, {'t': 8000, 'bpm': 150}, {'t': 9000, 'bpm': 100}],
    'playData': {'album': 'volume1', 'songVariations': ['erect'], 'difficulties': ['easy', 'normal', 'hard'],
                 'characters': {'player': 'bf', 'girlfriend': 'gf', 'opponent': 'vs-dad', 'instrumental': '', 'altInstrumentals': []},
                 'stage': 'vsStage', 'noteStyle': 'funkin'},
    'generatedBy': 'Vortex test fixture'})
write('CompatVSlice/data/songs/vs-test/vs-test-metadata-erect.json', {'version': '2.2.4', 'songName': 'VS Test Erect', 'timeChanges': [{'t': 0, 'bpm': 120}], 'playData': {'characters': {'player': 'bf', 'opponent': 'dad'}, 'stage': 'mainStage'}})
write('CompatVSlice/data/songs/vs-test/vs-test-chart.json', {
    'version': '2.0.0', 'scrollSpeed': {'easy': 1.0, 'normal': 1.5, 'hard': 2.0},
    'events': [
        {'t': 0, 'e': 'FocusCamera', 'v': {'char': 1}},
        {'t': 2000, 'e': 'FocusCamera', 'v': {'char': 0, 'x': 0, 'y': 0}},
        {'t': 4000, 'e': 'FocusCamera', 'v': 1},
        {'t': 3000, 'e': 'PlayAnimation', 'v': {'target': 'boyfriend', 'anim': 'hey', 'force': True}},
        {'t': 6000, 'e': 'ScrollSpeed', 'v': {'scroll': 2.25, 'duration': 4, 'ease': 'linear', 'absolute': True}},
        {'t': 7000, 'e': 'ZoomCamera', 'v': {'zoom': 1.2, 'duration': 4, 'mode': 'stage'}},
        {'t': 9200, 'e': 'MyCustomEvent', 'v': {'foo': 1}}],
    'notes': {
        'easy': [{'t': 500, 'd': 4, 'l': 0}],
        'normal': [{'t': 500, 'd': 4, 'l': 0}, {'t': 1000, 'd': 5, 'l': 0}, {'t': 2500, 'd': 0, 'l': 0}, {'t': 3000, 'd': 1, 'l': 400},
                   {'t': 3500, 'd': 2, 'l': 0, 'k': 'hurt'}, {'t': 8500, 'd': 3, 'l': 0}, {'t': 9000, 'd': 6, 'l': 0},
                   {'t': 9500, 'd': 7, 'l': 0}, {'t': 10000, 'd': 12, 'l': 0}],
        'hard': [{'t': 500, 'd': 4, 'l': 0}, {'t': 600, 'd': 4, 'l': 0}]},
    'generatedBy': 'Vortex test fixture'})
write('CompatVSlice/data/songs/vs-unlisted/vs-unlisted-metadata.json', {'version': '2.2.4', 'songName': 'VS Unlisted', 'timeChanges': [{'t': 0, 'bpm': 100}], 'playData': {'difficulties': ['normal'], 'characters': {'player': 'bf', 'girlfriend': 'gf', 'opponent': 'dad'}, 'stage': 'mainStage'}})
write('CompatVSlice/data/songs/vs-unlisted/vs-unlisted-chart.json', {'version': '2.0.0', 'scrollSpeed': {'normal': 1}, 'events': [], 'notes': {'normal': [{'t': 1000, 'd': 0, 'l': 0}]}})
write('CompatVSlice/data/characters/vs-dad.json', {
    'version': '1.0.0', 'name': 'VS Dad', 'renderType': 'sparrow', 'assetPath': 'shared:characters/DADDY_DEAREST', 'scale': 1,
    'healthIcon': {'id': 'dad', 'scale': 1, 'flipX': False, 'isPixel': False}, 'offsets': [0, 0], 'cameraOffsets': [0, 0],
    'singTime': 12.2, 'danceEvery': 2, 'startingAnimation': 'idle', 'flipX': False, 'isPixel': False,
    'animations': [{'name': n, 'prefix': p, 'offsets': o, 'looped': False, 'frameRate': 24} for n, p, o in DAD_ANIMS]})
write('CompatVSlice/data/characters/vs-broken.json', '{ "version": "1.0.0", "name": broken json ')
write('CompatVSlice/data/stages/vsStage.json', {
    'version': '1.0.1', 'name': 'VS Stage', 'cameraZoom': 1.1,
    'props': [{'name': 'back', 'assetPath': 'stageback', 'position': [-600, -200], 'zIndex': 10, 'scroll': [0.9, 0.9], 'scale': [1, 1]},
              {'name': 'shade', 'assetPath': '#000000', 'position': [0, 0], 'zIndex': 15, 'scale': [100, 50], 'alpha': 0.5},
              {'name': 'front', 'assetPath': 'stagefront', 'position': [-650, 600], 'zIndex': 20, 'scale': 1.1, 'scroll': [0.9, 0.9]},
              {'name': 'curtains', 'assetPath': 'stagecurtains', 'position': [-500, -300], 'zIndex': 400, 'scroll': [1.3, 1.3]}],
    'characters': {'bf': {'zIndex': 300, 'position': [989.5, 885], 'cameraOffsets': [-100, -100]},
                   'dad': {'zIndex': 200, 'position': [335, 885], 'cameraOffsets': [150, -100]},
                   'gf': {'zIndex': 100, 'position': [751.5, 787], 'cameraOffsets': [0, 0]}}})
write('CompatVSlice/data/levels/vsweek.json', {'version': '1.0.0', 'name': 'VS WEEK', 'titleAsset': 'storymenu/titles/vsweek', 'visible': True,
                                              'props': [{'assetPath': 'storymenu/props/dad', 'scale': 1}], 'background': '#F9CF51', 'songs': ['vs-test', 'missing-song']})
write('CompatVSlice/scripts/songs/vs-test.hxc', 'import funkin.play.song.Song;\nclass VsTestSong extends Song {\n\tpublic function new() { super("vs-test"); }\n}\n')
audio('CompatVSlice/songs/vs-test', {'Inst.ogg': 'Inst.ogg', 'Voices-bf.ogg': 'Voices-Player.ogg', 'Voices-vs-dad.ogg': 'Voices-Opponent.ogg'})
audio('CompatVSlice/songs/vs-unlisted', {'Inst.ogg': 'Inst.ogg'})

# ---------------------------------------------------------------- Codename Engine
write('CompatCodename/songs/cne-test/meta.json', {'name': 'cne-test', 'displayName': 'CNE Test', 'bpm': 100, 'needsVoices': True, 'icon': 'dad', 'color': '#AF66CE', 'difficulties': ['normal', 'hard']})
write('CompatCodename/songs/cne-test/charts/normal.json', {
    'codenameChart': True, 'stage': 'cnestage', 'scrollSpeed': 2, 'noteTypes': ['Hurt Note'],
    'strumLines': [
        {'characters': ['cne-dad'], 'type': 0, 'position': 'dad', 'visible': True,
         'notes': [{'time': 600, 'id': 0, 'sLen': 0, 'type': 0}, {'time': 1200, 'id': 1, 'sLen': 300, 'type': 1}]},
        {'characters': ['bf'], 'type': 1, 'position': 'boyfriend', 'visible': True,
         'notes': [{'time': 2400, 'id': 2, 'sLen': 0, 'type': 0}, {'time': 3000, 'id': 3, 'sLen': 0, 'type': 0}]},
        {'characters': ['gf'], 'type': 2, 'position': 'girlfriend', 'visible': False, 'notes': []},
        {'characters': ['dad', 'bf'], 'type': 2, 'position': 'girlfriend', 'visible': True,
         'notes': [{'time': 3600, 'id': 0, 'sLen': 0, 'type': 0}, {'time': 4200, 'id': 9, 'sLen': 0, 'type': 0}]}],
    'events': [
        {'time': 0, 'name': 'Camera Movement', 'params': [0]},
        {'time': 2400, 'name': 'Camera Movement', 'params': [1]},
        {'time': 3000, 'name': 'Add Camera Zoom', 'params': [0.05, 'camHUD']},
        {'time': 3600, 'name': 'Play Animation', 'params': [1, 'hey', True]},
        {'time': 4000, 'name': 'HScript Call', 'params': ['doThing', 'a']},
        {'time': 4800, 'name': 'BPM Change', 'params': [150]}]})
write('CompatCodename/songs/cne-test/charts/hard.json', {'codenameChart': True, 'strumLines': [{'characters': ['dad'], 'type': 0, 'notes': []}, {'characters': ['bf'], 'type': 1, 'notes': []}], 'events': []})
write('CompatCodename/songs/cne-test/scripts/script.hx', 'function onSongStart() {\n\ttrace("codename song script");\n}\n')
audio('CompatCodename/songs/cne-test/song', {'Inst.ogg': 'Inst.ogg', 'Voices.ogg': 'Voices-Player.ogg'})
write('CompatCodename/songs/cne-free/meta.json', {'name': 'cne-free', 'bpm': 120})
write('CompatCodename/songs/cne-free/charts/normal.json', {'codenameChart': True, 'strumLines': [{'characters': ['dad'], 'type': 0, 'notes': [{'time': 500, 'id': 1, 'sLen': 0}]}, {'characters': ['bf'], 'type': 1, 'notes': [{'time': 1000, 'id': 2, 'sLen': 0}]}], 'events': []})
audio('CompatCodename/songs/cne-free/song', {'Inst.ogg': 'Inst.ogg'})
write('CompatCodename/data/characters/cne-dad.xml',
      '<!DOCTYPE codename-engine-character>\n<character isPlayer="false" flipX="false" holdTime="6.1" color="#AF66CE" icon="dad" x="0" y="0" camx="0" camy="0" scale="1" sprite="DADDY_DEAREST">\n'
      + ''.join('\t<anim name="%s" anim="%s" fps="24" loop="false" x="%d" y="%d"/>\n' % (n, p, o[0], o[1]) for n, p, o in DAD_ANIMS)
      + '\t<anim name="idle-loop" anim="Dad idle dance" fps="24" loop="true" indices="10..12,12"/>\n</character>\n')
write('CompatCodename/data/stages/cnestage.xml',
      '<!DOCTYPE codename-engine-stage>\n<stage zoom="0.95" name="cnestage" folder="" startCamPosX="0" startCamPosY="0">\n'
      '\t<sprite name="back" x="-600" y="-200" sprite="stageback" scroll="0.9"/>\n'
      '\t<solid name="shade" x="0" y="0" width="200" height="40" color="#000000" alpha="0.4"/>\n'
      '\t<high-memory>\n\t\t<sprite name="front" x="-650" y="600" sprite="stagefront" scale="1.1" scroll="0.9"/>\n\t</high-memory>\n'
      '\t<girlfriend x="400" y="130"/>\n\t<dad x="100" y="100" camxoffset="50"/>\n\t<boyfriend x="770" y="100"/>\n'
      '\t<sprite name="curtains" x="-500" y="-300" sprite="stagecurtains" scroll="1.3"/>\n\t<ratings x="500" y="300"/>\n</stage>\n')
write('CompatCodename/data/weeks/weeks/cneweek.xml', '<week name="CNE Week" chars="dad,bf,gf" sprite="week1">\n\t<song>cne-test</song>\n\t<song name="not-here"/>\n</week>\n')
write('CompatCodename/data/weeks/weeks.txt', 'cneweek\n')

# ---------------------------------------------------------------- Psych Engine 0.6-style
write('CompatPsych06/pack.json', {'name': 'Compat Psych 0.6', 'description': 'test fixture', 'restart': False, 'runsGlobally': False})
write('CompatPsych06/data/old-song/old-song.json', {'song': {
    'song': 'Old Song', 'bpm': 130, 'needsVoices': True, 'player1': 'bf', 'player2': 'dad', 'player3': 'gf', 'speed': 2, 'validScore': True,
    'notes': [
        {'lengthInSteps': 16, 'mustHitSection': False, 'sectionNotes': [[500, 0, 0], [800, 5, 0], [900, -1, 'Hey!', 'BF', '0.6']]},
        {'lengthInSteps': 16, 'mustHitSection': True, 'sectionNotes': [[2400, 1, 0], [2600, 6, 200], [3000, 2, 0, 1]]},
        {'lengthInSteps': 16, 'mustHitSection': True, 'sectionNotes': [[4000, 3, 0, 'Hurt Note']]}]}})
write('CompatPsych06/data/old-song/events.json', {'song': {'song': 'Old Song', 'notes': [], 'bpm': 130, 'events': [[1500, [['Add Camera Zoom', '0.03', '0.02']]]]}})
write('CompatPsych06/weeks/oldweek.json', {'songs': [['Old Song', 'dad', [146, 113, 253]]], 'weekCharacters': ['dad', 'bf', 'gf'], 'weekBackground': 'stage', 'weekBefore': '',
                                          'storyName': 'Old Week', 'weekName': 'Old Week', 'freeplayColor': [146, 113, 253], 'startUnlocked': True, 'hiddenUntilUnlocked': False,
                                          'hideStoryMode': False, 'hideFreeplay': False, 'difficulties': ''})
write('CompatPsych06/data/old-song/legacy.lua', '''-- Psych 0.6-style script (old class names, old settings location)
function onCreatePost()
\tlocal down = getPropertyFromClass('ClientPrefs', 'downScroll')
\tlocal song = getPropertyFromClass('PlayState', 'SONG.song')
\tlocal bpm = getPropertyFromClass('Conductor', 'bpm')
\tsetGlobalVar('legacy_down_type', type(down))
\tsetGlobalVar('legacy_song', song)
\tsetGlobalVar('legacy_bpm', bpm)
\tluaSpriteMakeGraphic('oldbox', 10, 10, 'FF0000')
end
''')
audio('CompatPsych06/songs/old-song', {'Inst.ogg': 'Inst.ogg', 'Voices.ogg': 'Voices-Player.ogg'})

# ---------------------------------------------------------------- FPS Plus layout
write('CompatFPSPlus/data/songs/fps-test/fps-test.json', {'song': {
    'song': 'fps-test', 'bpm': 110, 'needsVoices': False, 'player1': 'bf', 'player2': 'dad', 'gfVersion': 'gf', 'speed': 1.8,
    'notes': [{'sectionBeats': 4, 'mustHitSection': True, 'sectionNotes': [[600, 0, 0], [1200, 4, 0]]},
              {'sectionBeats': 4, 'mustHitSection': False, 'sectionNotes': [[2400, 1, 0], [2800, 5, 0]]}],
    'events': {'events': [[0, 0, 'camFocus', 'bf']]}}})
write('CompatFPSPlus/data/songs/fps-test/fps-test-hard.json', {'song': {'song': 'fps-test', 'bpm': 110, 'notes': [], 'player1': 'bf', 'player2': 'dad'}})
audio('CompatFPSPlus/songs/fps-test', {'Inst.ogg': 'Inst.ogg'})

# ---------------------------------------------------------------- Forever Engine layout
write('CompatForever/songs/fe-test/fe-test.json', {'song': {
    'song': 'fe-test', 'bpm': 125, 'needsVoices': True, 'player1': 'bf', 'player2': 'pico-forever', 'speed': 2.1,
    'notes': [{'lengthInSteps': 16, 'mustHitSection': True, 'sectionNotes': [[480, 2, 0], [960, 7, 0]]},
              {'lengthInSteps': 16, 'mustHitSection': False, 'sectionNotes': [[2400, 0, 0]]}]}})
audio('CompatForever/songs/fe-test', {'Inst.ogg': 'Inst.ogg', 'Voices.ogg': 'Voices-Player.ogg'})

# ---------------------------------------------------------------- 0.6: laid out like real GameBanana V-Slice mods
# (VS Sunday / Rivals / TITULAR / Overwritten style: art in shared/images/, playerVocals, Psych-style and community
# events, a level title picture, a trailing space in a level file name, __MACOSX junk, an .astc-only character)
EXDAD = 'example_mods/Vortex-Example-Mod/images/characters/example-dad'


def copy_img(dest_rel):
    d = os.path.join(ROOT, dest_rel)
    os.makedirs(os.path.dirname(d), exist_ok=True)
    shutil.copy(EXDAD + '.png', d + '.png')
    shutil.copy(EXDAD + '.xml', d + '.xml')


R = 'CompatVSlice2/'
write(R + '_polymod_meta.json', {'title': 'Real-layout test', 'description': 'test fixture', 'api_version': '0.8.4', 'mod_version': '1.0.0', 'license': 'test'})
write(R + 'data/songs/rl-song/rl-song-metadata.json', {
    'version': '2.2.4', 'songName': 'RL Song', 'artist': 'test', 'timeFormat': 'ms', 'timeChanges': [{'t': 0, 'bpm': 120}],
    'playData': {'difficulties': ['hard'], 'songVariations': ['pico'], 'stage': 'rl-stage', 'noteStyle': 'funkin',
                 'characters': {'player': 'bf', 'girlfriend': 'gf', 'opponent': 'rl-dad', 'instrumental': '', 'altInstrumentals': [],
                                'playerVocals': ['bf-car'], 'opponentVocals': ['rl-dad']}}})
write(R + 'data/songs/rl-song/rl-song-metadata-pico.json', {'version': '2.2.4', 'songName': 'RL Song', 'timeChanges': [{'t': 0, 'bpm': 120}], 'playData': {'difficulties': ['hard'], 'characters': {'player': 'pico-playable', 'opponent': 'rl-dad', 'instrumental': 'pico'}, 'stage': 'rl-stage'}})
write(R + 'data/songs/rl-song/rl-song-chart.json', {'version': '2.0.0', 'scrollSpeed': {'hard': 2.0},
    'events': [{'t': 0, 'e': 'FocusCamera', 'v': {'char': '1'}},
               {'t': 1000, 'e': 'ChangeCharacter', 'v': {'character': 'dad', 'newchar': 'rl-dad-alt'}},
               {'t': 1500, 'e': 'ZoomCamera', 'v': {'duration': 8, 'ease': 'expo', 'easeDir': 'In', 'mode': 'stage', 'zoom': 1.2}},
               {'t': 2000, 'e': 'Screen Shake', 'v': {'value1': '0.2,0.01', 'value2': ''}},
               {'t': 3500, 'e': 'ChangeStage', 'v': {'stageid': 'mainStage'}},
               {'t': 3000, 'e': 'NoteSwapEvent', 'v': {'notestyle': 'pixel', 'strumline': 'both'}}],
    'notes': {'hard': [{'t': 500, 'd': 4, 'l': 0}, {'t': 1200, 'd': 0, 'l': 0}, {'t': 1800, 'd': 1, 'l': 0, 'p': []}]}})
write(R + 'data/songs/rl-song/rl-song-chart-pico.json', {'version': '2.0.0', 'scrollSpeed': {'hard': 2.0}, 'events': [], 'notes': {'hard': []}})
write(R + 'data/songs/rl-song/manifest.json', {'version': '1.0.0', 'songId': 'rl-song'})
# a song whose files don't follow the <id>-metadata.json naming (found by content)
write(R + 'data/songs/oddname/meta.json', {'version': '2.2.4', 'songName': 'oddname', 'timeChanges': [{'t': 0, 'bpm': 100}], 'playData': {'difficulties': ['normal'], 'characters': {'player': 'bf', 'opponent': 'dad'}, 'stage': 'rl-scripted'}})
write(R + 'data/songs/oddname/notes.json', {'version': '2.0.0', 'scrollSpeed': {'normal': 1}, 'events': [], 'notes': {'normal': [{'t': 800, 'd': 2, 'l': 0}]}})
write(R + 'data/characters/rl-dad.json', {'version': '1.0.0', 'name': 'RL Dad', 'assetPath': 'characters/rl-dad', 'healthIcon': {'id': 'dad'},
    'animations': [{'name': n, 'prefix': p, 'offsets': o} for n, p, o in DAD_ANIMS]})
write(R + 'data/characters/rl-dad-alt.json', {'version': '1.0.0', 'renderType': 'sparrow', 'assetPath': 'week1:characters/rl-dad-alt',
    'animations': [{'name': n, 'prefix': p, 'offsets': o} for n, p, o in DAD_ANIMS]})
write(R + 'data/characters/rl-mobile.json', {'version': '1.0.0', 'renderType': 'sparrow', 'assetPath': 'characters/rl-mobile', 'animations': [{'name': 'idle', 'prefix': 'idle'}]})
copy_img(R + 'shared/images/characters/rl-dad')
copy_img(R + 'week1/images/characters/rl-dad-alt')
write(R + 'shared/images/characters/rl-mobile.xml', '<TextureAtlas imagePath="rl-mobile.png"></TextureAtlas>')
open(os.path.join(ROOT, R + 'shared/images/characters/rl-mobile.astc'), 'wb').write(b'\x13\xab\xa1\x5c' + bytes(12))
copy_img(R + 'shared/images/background/rl-back')
write(R + 'data/stages/rl-stage.json', {'version': '1.0.0', 'name': 'RL Stage', 'cameraZoom': 1.0,
    'props': [{'name': 'back', 'assetPath': 'background/rl-back', 'position': [0, 0], 'zIndex': 10, 'scale': [1, 1], 'scroll': [1, 1], 'animType': 'sparrow', 'animations': []}],
    'characters': {'bf': {'zIndex': 300, 'position': [989.5, 885]}, 'dad': {'zIndex': 200, 'position': [335, 885]}, 'gf': {'zIndex': 100, 'position': [751.5, 787]}}})
write(R + 'data/levels/RL Week .json', {'version': '1.0.0', 'name': 'RL WEEK', 'titleAsset': 'storymenu/titles/rlweek', 'props': [], 'background': '#9271FD', 'songs': ['rl-song']})
write(R + 'data/levels/RL Week.json', {'version': '1.0.0', 'name': 'RL WEEK (copy)', 'titleAsset': 'storymenu/titles/rlweek', 'props': [], 'songs': ['rl-song']})
os.makedirs(os.path.join(ROOT, R + 'images/storymenu/titles'), exist_ok=True)
shutil.copy('assets/shared/images/storymenu/week1.png', os.path.join(ROOT, R + 'images/storymenu/titles/rlweek.png'))
write(R + 'data/ui/freeplay/style.json', {'version': '1.0.0', 'bgAsset': 'freeplay/bgs/x'})
write(R + 'scripts/events/ChangeCharacterEvent.hxc', 'class ChangeCharacterEvent extends SongEvent { function new() { super("ChangeCharacter"); } }\n')
write(R + '__MACOSX/data/songs/rl-song/._rl-song-chart.json', '\x00\x05\x16\x07 not json')
write(R + 'data/songs/rl-song/._rl-song-chart.json', '\x00\x05\x16\x07 not json')
audio(R + 'songs/rl-song', {'Inst.ogg': 'Inst.ogg', 'Voices-bf.ogg': 'Voices-Player.ogg', 'Voices-rl-dad.ogg': 'Voices-Opponent.ogg', 'Inst-pico.ogg': 'Inst.ogg'})
audio(R + 'songs/oddname', {'Inst.ogg': 'Inst.ogg'})
# a stage built by its script (VS Sunday style: empty "props", sprites made in scripts/stages/<id>.hxc, per-song)
write(R + 'data/stages/rl-scripted.json', {'version': '1.0.0', 'name': 'RL Scripted', 'cameraZoom': 1.0, 'props': [],
    'characters': {'bf': {'zIndex': 300, 'position': [989.5, 885]}, 'dad': {'zIndex': 200, 'position': [335, 885]}, 'gf': {'zIndex': 100, 'position': [751.5, 787]}}})


def png(path, w, h, rgb):
    import struct
    import zlib
    raw = b''.join(b'\x00' + bytes(rgb) * w for _ in range(h))
    chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    d = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(d), exist_ok=True)
    open(d, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


png(R + 'shared/images/background/rl-sky.png', 64, 32, (40, 60, 160))
write(R + 'scripts/stages/rl-scripted.hxc', '''import funkin.play.stage.Stage;
import funkin.play.PlayState;
import funkin.graphics.FunkinSprite;
import funkin.Paths;
import flixel.FlxSprite;

class RlScriptedStage extends Stage
{
	var sky:FlxSprite = new FlxSprite(-100, -50);
	var hud:FlxSprite;

	function new() { super('rl-scripted'); }

	override function onCreate()
	{
		super.onCreate();
		sky.loadGraphic(Paths.image('background/rl-sky'));
		sky.scrollFactor.set(0.5, 0.5);
		sky.scale.set(2, 2); // no updateHitbox: flixel scales around the centre
		add(sky);
		makeFloor();
		var hidden = new FlxSprite(0, 0).loadGraphic(Paths.image('background/rl-sky'));
		hidden.alpha = 0;
		add(hidden);
		hud = new FlxSprite().loadGraphic(Paths.image('shared:background/rl-sky'));
		hud.cameras = [PlayState.instance.camHUD];
		add(hud);
		switch (PlayState.instance.currentSong.id)
		{
			case 'script-song', 'other-song':
				var dancer = new FlxSprite(400 + 100, 300 * 2);
				dancer.frames = Paths.getSparrowAtlas('background/rl-back');
				dancer.animation.addByPrefix('bop', 'Dad idle dance', 24, false);
				dancer.animation.play('bop');
				dancer.zIndex = 250;
				add(dancer);
			default:
		}
		if (PlayState.instance.currentSong.id == "oddname") return;
		var screen = new FlxSprite().makeGraphic(100, 50, 0xFF00FF00);
		screen.screenCenter();
		add(screen);
	}

	function makeFloor()
	{
		var floor = FunkinSprite.create(10, 600, 'background/rl-sky');
		floor.setGraphicSize(640);
		floor.updateHitbox();
		add(floor);
	}

	override function onBeatHit(event)
	{
		super.onBeatHit(event);
		sky.alpha = 0.5;
	}
}
''')
write(R + 'data/songs/script-song/script-song-metadata.json', {'version': '2.2.4', 'songName': 'Script Song', 'timeChanges': [{'t': 0, 'bpm': 100}],
    'playData': {'difficulties': ['normal'], 'characters': {'player': 'bf', 'opponent': 'rl-dad', 'girlfriend': 'gf'}, 'stage': 'rl-scripted'}})
write(R + 'data/songs/script-song/script-song-chart.json', {'version': '2.0.0', 'scrollSpeed': {'normal': 1}, 'events': [], 'notes': {'normal': [{'t': 600, 'd': 1, 'l': 0}]}})
audio(R + 'songs/script-song', {'Inst.ogg': 'Inst.ogg'})
os.makedirs(os.path.join(ROOT, R + 'videos/videos'), exist_ok=True)
open(os.path.join(ROOT, R + 'videos/videos/rl-cutscene.mp4'), 'wb').write(b'fake video for path test')

# a Psych mod extracted one folder too deep: mods/CompatNested/Nested Mod/...
N = 'CompatNested/Nested Mod/'
write(N + 'pack.json', {'name': 'Nested', 'runsGlobally': False})
write(N + 'data/nest-song/nest-song.json', {'song': {'song': 'Nest Song', 'bpm': 100, 'needsVoices': False, 'player1': 'bf', 'player2': 'dad', 'gfVersion': 'gf', 'speed': 1, 'format': 'psych_v1',
    'notes': [{'sectionBeats': 4, 'mustHitSection': True, 'sectionNotes': [[600, 0, 0, ''], [1200, 5, 0, '']]}], 'events': []}})
write(N + 'weeks/nestweek.json', {'songs': [['Nest Song', 'dad', [146, 113, 253]]], 'weekCharacters': ['dad', 'bf', 'gf'], 'weekBackground': '', 'weekBefore': '',
    'storyName': 'Nested Week', 'weekName': 'Nested Week', 'startUnlocked': True, 'hiddenUntilUnlocked': False, 'hideStoryMode': False, 'hideFreeplay': False, 'difficulties': ''})
audio(N + 'songs/nest-song', {'Inst.ogg': 'Inst.ogg'})

# a mod that hides two base-game weeks (pack.json "hideBaseGameWeeks")
write('CompatHideBase/pack.json', {'name': 'Hide base weeks', 'runsGlobally': False, 'hideBaseGameWeeks': ['tutorial', 'week2']})
write('CompatHideBase/data/readme.txt', 'test fixture')

print('wrote test mods to', ROOT)
