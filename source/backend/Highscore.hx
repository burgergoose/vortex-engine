package backend;

class Highscore
{
	public static var weekScores:Map<String, Int> = new Map();
	public static var songScores:Map<String, Int> = new Map<String, Int>();
	public static var songRating:Map<String, Float> = new Map<String, Float>();

	// Vortex Engine additions: same key format as the maps above (see formatSong()),
	// stored under their own save fields so old saves that only ever had
	// songScores/songRating stay perfectly readable -- these three simply won't
	// exist yet for a song no one has played since updating, and every getter
	// below already treats "not in the map" as "no data yet".
	public static var songMaxCombo:Map<String, Int> = new Map<String, Int>();
	public static var songMisses:Map<String, Int> = new Map<String, Int>();
	public static var songCompleted:Map<String, Bool> = new Map<String, Bool>();

	public static function resetSong(song:String, diff:Int = 0):Void
	{
		var daSong:String = formatSong(song, diff);
		setScore(daSong, 0);
		setRating(daSong, 0);
		setMaxCombo(daSong, 0);
		setMisses(daSong, 0);
		setCompleted(daSong, false);
	}

	public static function resetWeek(week:String, diff:Int = 0):Void
	{
		var daWeek:String = formatSong(week, diff);
		setWeekScore(daWeek, 0);
	}

	public static function saveScore(song:String, score:Int = 0, ?diff:Int = 0, ?rating:Float = -1):Void
	{
		if(song == null) return;
		var daSong:String = formatSong(song, diff);

		if (songScores.exists(daSong))
		{
			if (songScores.get(daSong) < score)
			{
				setScore(daSong, score);
				if(rating >= 0) setRating(daSong, rating);
			}
		}
		else
		{
			setScore(daSong, score);
			if(rating >= 0) setRating(daSong, rating);
		}
	}

	/**
	 * Vortex Engine addition. Everything saveScore() already did (score +
	 * accuracy, "only keep it if it beats the existing score") is untouched
	 * and still goes through saveScore() below -- this just also records
	 * max combo / misses / completed for that same best-scoring run, so
	 * the numbers Freeplay shows always describe one consistent play.
	 *
	 * completed defaults to true because the only place this is currently
	 * called from (PlayState.endSong()) already only runs after the
	 * death-check has passed -- i.e. every call here already represents a
	 * finished song. It's a real parameter (not hardcoded) so a script or
	 * future caller can still be explicit about it.
	 */
	public static function saveStats(song:String, score:Int = 0, ?diff:Int = 0, accuracy:Float = -1, maxCombo:Int = 0, misses:Int = 0, completed:Bool = true):Void
	{
		if(song == null) return;
		var daSong:String = formatSong(song, diff);
		var isNewBest:Bool = !songScores.exists(daSong) || songScores.get(daSong) < score;

		saveScore(song, score, diff, accuracy); // unchanged existing behavior

		if(isNewBest)
		{
			setMaxCombo(daSong, maxCombo);
			setMisses(daSong, misses);
		}
		if(completed) setCompleted(daSong, true); // sticky: a song stays "completed" once cleared, even if a later run fails
	}

	public static function saveWeekScore(week:String, score:Int = 0, ?diff:Int = 0):Void
	{
		var daWeek:String = formatSong(week, diff);

		if (weekScores.exists(daWeek))
		{
			if (weekScores.get(daWeek) < score)
				setWeekScore(daWeek, score);
		}
		else setWeekScore(daWeek, score);
	}

	/**
	 * YOU SHOULD FORMAT SONG WITH formatSong() BEFORE TOSSING IN SONG VARIABLE
	 */
	static function setScore(song:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songScores.set(song, score);
		FlxG.save.data.songScores = songScores;
		FlxG.save.flush();
	}
	static function setWeekScore(week:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		weekScores.set(week, score);
		FlxG.save.data.weekScores = weekScores;
		FlxG.save.flush();
	}

	static function setRating(song:String, rating:Float):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songRating.set(song, rating);
		FlxG.save.data.songRating = songRating;
		FlxG.save.flush();
	}

	// Vortex Engine additions, same pattern as setScore/setRating above.
	static function setMaxCombo(song:String, combo:Int):Void
	{
		songMaxCombo.set(song, combo);
		FlxG.save.data.songMaxCombo = songMaxCombo;
		FlxG.save.flush();
	}
	static function setMisses(song:String, misses:Int):Void
	{
		songMisses.set(song, misses);
		FlxG.save.data.songMisses = songMisses;
		FlxG.save.flush();
	}
	static function setCompleted(song:String, completed:Bool):Void
	{
		songCompleted.set(song, completed);
		FlxG.save.data.songCompleted = songCompleted;
		FlxG.save.flush();
	}

	public static function formatSong(song:String, diff:Int):String
	{
		return Paths.formatToSongPath(song) + Difficulty.getFilePath(diff);
	}

	public static function getScore(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		if (!songScores.exists(daSong))
			setScore(daSong, 0);

		return songScores.get(daSong);
	}

	public static function getRating(song:String, diff:Int):Float
	{
		var daSong:String = formatSong(song, diff);
		if (!songRating.exists(daSong))
			setRating(daSong, 0);

		return songRating.get(daSong);
	}

	// Vortex Engine additions, same pattern as getScore/getRating above.
	public static function getMaxCombo(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		return songMaxCombo.exists(daSong) ? songMaxCombo.get(daSong) : 0;
	}
	public static function getMisses(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		return songMisses.exists(daSong) ? songMisses.get(daSong) : 0;
	}
	public static function isCompleted(song:String, diff:Int):Bool
	{
		var daSong:String = formatSong(song, diff);
		return songCompleted.exists(daSong) && songCompleted.get(daSong);
	}
	/** Convenience: SongRank.fromAccuracy() applied to this song's saved accuracy. */
	public static function getRank(song:String, diff:Int):String
	{
		return SongRank.fromAccuracy(getRating(song, diff));
	}

	public static function getWeekScore(week:String, diff:Int):Int
	{
		var daWeek:String = formatSong(week, diff);
		if (!weekScores.exists(daWeek))
			setWeekScore(daWeek, 0);

		return weekScores.get(daWeek);
	}

	public static function load():Void
	{
		if (FlxG.save.data.weekScores != null)
			weekScores = FlxG.save.data.weekScores;

		if (FlxG.save.data.songScores != null)
			songScores = FlxG.save.data.songScores;

		if (FlxG.save.data.songRating != null)
			songRating = FlxG.save.data.songRating;

		// Vortex Engine additions -- simply absent on saves from before this existed, which is fine:
		// every getter above already treats "not in the map" as "no data yet".
		if (FlxG.save.data.songMaxCombo != null)
			songMaxCombo = FlxG.save.data.songMaxCombo;
		if (FlxG.save.data.songMisses != null)
			songMisses = FlxG.save.data.songMisses;
		if (FlxG.save.data.songCompleted != null)
			songCompleted = FlxG.save.data.songCompleted;
	}
}