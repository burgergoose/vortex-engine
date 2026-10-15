package backend;

/**
 * VORTEX ENGINE ADDITION.
 *
 * Heads up for anyone comparing this to vanilla Psych Engine: Psych itself
 * does NOT have an A/B/S/P-style letter grade. What it has is:
 *   - PlayState.ratingPercent -- the raw accuracy (0.0 - 1.0), same number
 *     that's stored in Highscore.songRating / Highscore.getRating().
 *   - PlayState.ratingName -- a word ("Sick"/"Good"/"Bad"/"Shit"/...)
 *     from the ratingStuff thresholds near the top of PlayState.hx.
 *   - PlayState.ratingFC -- a clear-type tag ("FC"/"GFC"/"SFC"/"SDCB"/"Clear").
 *
 * None of those are a single letter. This class adds that letter-grade
 * layer on top, as a pure function of the accuracy Psych already computes,
 * so Freeplay (and anything else) can show a P/S/A/B/C/D/F rank without
 * duplicating or disagreeing with the game's own accuracy math.
 *
 * Thresholds are just a static array -- edit freely, nothing else depends
 * on the exact numbers.
 */
class SongRank
{
	public static var thresholds:Array<{rank:String, minAccuracy:Float}> = [
		{rank: 'P', minAccuracy: 1.0},  // Perfect: 100% accuracy (all Sicks, no misses)
		{rank: 'S', minAccuracy: 0.90},
		{rank: 'A', minAccuracy: 0.80},
		{rank: 'B', minAccuracy: 0.70},
		{rank: 'C', minAccuracy: 0.60},
		{rank: 'D', minAccuracy: 0.50},
		{rank: 'F', minAccuracy: 0.0}
	];

	/** accuracy is expected 0.0 - 1.0 (same scale as Highscore.getRating / PlayState.ratingPercent). */
	public static function fromAccuracy(accuracy:Float):String
	{
		if (Math.isNaN(accuracy)) accuracy = 0;
		for (t in thresholds)
			if (accuracy >= t.minAccuracy)
				return t.rank;
		return 'F';
	}

	/** True if a song has never actually been played (as opposed to played and ranked F). */
	public static function hasNoAttempt(song:String, diff:Int):Bool
	{
		return Highscore.getScore(song, diff) <= 0 && Highscore.getRating(song, diff) <= 0;
	}

	/** Vortex Engine addition: the accent color for a rank badge (Freeplay cards, etc). Int, not FlxColor -- see CosmicBackground.hx for why. */
	public static function colorFor(rank:String):Int
	{
		return switch (rank)
		{
			case 'P': 0xFFFFD866; // gold
			case 'S': 0xFF52E7FF; // bright cyan
			case 'A': 0xFF6BFF95; // green
			case 'B': 0xFF6BAFFF; // blue
			case 'C': 0xFFFFE066; // yellow
			case 'D': 0xFFFFA352; // orange
			case 'F': 0xFFFF5C77; // red/pink
			default:  0xFF5A5470; // no attempt yet -- dim gray-violet
		}
	}
}
