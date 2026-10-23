import backend.MusicBeatState;
import states.editors.MasterEditorMenu;
import sys.io.File;

function onCreatePost() {
	if (getGlobalVar('ach_started', false)) return;
	setGlobalVar('ach_started', true);
	File.saveContent('vortex_achtest.txt', 'Vortex Engine achievement test\n');
	MusicBeatState.switchState(new MasterEditorMenu());
}
