import Sys;
import sys.io.File;
import backend.Achievements;

function cleanupAndExit() {
	for (id in ['first-steps', 'combo-starter', 'song-collector', 'ach-test-practice', 'ach-test-week', 'ach-test-acc', 'ach-test-script'])
		if (Achievements.exists(id)) Achievements.reset(id);
	var f = File.append('vortex_achtest.txt', false);
	f.writeString('DONE\n');
	f.close();
	Sys.exit(0);
}
