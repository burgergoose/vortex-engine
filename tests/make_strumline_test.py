"""Copies the example song's audio into tests/VortexStrumlineTest/songs/strum-test (run from the repo root):
    python tests/make_strumline_test.py"""
import os, shutil
src = 'example_mods/Vortex-Example-Mod/songs/example-song'
dst = 'tests/VortexStrumlineTest/songs/strum-test'
os.makedirs(dst, exist_ok=True)
for f in os.listdir(src):
    if f.endswith('.ogg'):
        shutil.copy(os.path.join(src, f), dst)
print('copied audio to', dst)
