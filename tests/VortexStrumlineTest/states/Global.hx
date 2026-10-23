import sys.io.File;
import backend.Song;
import backend.Mods;
import states.LoadingState;

function onCreatePost() {
	if (getGlobalVar('sl_started', false)) return;
	setGlobalVar('sl_started', true);
	File.saveContent('vortex_strumtest.txt', 'Vortex Engine strumline test\n');
	Mods.currentModDirectory = 'VortexStrumlineTest';
	Song.loadFromJson('strum-test', 'strum-test');
	PlayState.isStoryMode = false;
	PlayState.storyDifficulty = 0;
	LoadingState.prepareToSong();
	LoadingState.loadAndSwitchState(new PlayState());
}
