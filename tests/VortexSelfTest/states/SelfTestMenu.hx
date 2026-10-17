import backend.Song;
import backend.Mods;
import states.LoadingState;

function stStartSong() {
	Mods.currentModDirectory = 'Vortex-Example-Mod';
	Song.loadFromJson('example-song', 'example-song');
	PlayState.isStoryMode = false;
	PlayState.storyDifficulty = 0;
	LoadingState.prepareToSong();
	LoadingState.loadAndSwitchState(new PlayState());
}
