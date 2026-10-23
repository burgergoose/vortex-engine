"""Builds the 4 test songs of tests/VortexVocalsTest from the bundled example song (run from the repo root):
    python tests/make_vocals_test.py
  at-single       Inst + Voices.ogg
  at-split        Inst + Voices-Player + Voices-Opponent
  at-opponly      Inst + Voices-Opponent only (no player track)
  at-shortplayer  Inst + Voices-Player cut to 5 s + Voices-Opponent
The player track is shortened by cutting the Ogg file at a page boundary (no audio tools needed)."""
import json, os, shutil, struct

OUT = 'tests/VortexVocalsTest'
SRC = 'example_mods/Vortex-Example-Mod'


def truncate(src, dst, seconds):
    data = open(src, 'rb').read()
    k = data.find(b'\x01vorbis')
    rate = struct.unpack('<I', data[k + 12:k + 16])[0]
    i, cut = 0, None
    while True:
        j = data.find(b'OggS', i)
        if j < 0:
            break
        if struct.unpack('<q', data[j + 6:j + 14])[0] > seconds * rate:
            cut = j
            break
        i = j + 4
    open(dst, 'wb').write(data[:cut] if cut else data)


chart = json.load(open(SRC + '/data/example-song/example-song.json'))
songs = {'at-single': ['Voices'], 'at-split': ['Voices-Player', 'Voices-Opponent'],
         'at-opponly': ['Voices-Opponent'], 'at-shortplayer': ['Voices-Player', 'Voices-Opponent']}
for name, files in songs.items():
    d, s = f'{OUT}/data/{name}', f'{OUT}/songs/{name}'
    os.makedirs(d, exist_ok=True)
    os.makedirs(s, exist_ok=True)
    c = json.loads(json.dumps(chart))
    c['song']['song'] = name
    c['song']['needsVoices'] = True
    c['song']['events'] = []
    json.dump(c, open(f'{d}/{name}.json', 'w'))
    shutil.copy(SRC + '/songs/example-song/Inst.ogg', s + '/Inst.ogg')
    for f in files:
        src = SRC + '/songs/example-song/' + ('Voices-Player' if f == 'Voices' else f) + '.ogg'
        if name == 'at-shortplayer' and f == 'Voices-Player':
            truncate(src, f'{s}/{f}.ogg', 5.0)
        else:
            shutil.copy(src, f'{s}/{f}.ogg')
print('made', ', '.join(songs))
