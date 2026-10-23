import backend.Song;
import backend.Mods;
import states.LoadingState;

function startSong(name, mod) {
	Mods.currentModDirectory = mod;
	Song.loadFromJson(name, name);
	PlayState.isStoryMode = false;
	PlayState.storyDifficulty = 0;
	LoadingState.prepareToSong();
	LoadingState.loadAndSwitchState(new PlayState());
}
