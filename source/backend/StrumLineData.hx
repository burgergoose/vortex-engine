package backend;

import backend.Song.SwagSong;

/**
 * VORTEX ENGINE ADDITION - modular strumlines (Codename Engine style), stored in the chart as `strumLines`.
 *
 * A strumline is a row of 4 arrows with its own notes and its own characters. Line 0 is always the player line and
 * line 1 the opponent line, exactly like Psych (chart columns 0-3 and 4-7, boyfriend and dad). Every extra line uses
 * the next 4 chart columns: line 2 = columns 8-11, line 3 = 12-15, ... A chart without `strumLines` is a normal
 * Psych chart and plays exactly as before.
 *
 *   "strumLines": [
 *     {"name": "Player",   "type": "player",   "characters": [{"name": "bf"}, {"name": "pico", "position": "boyfriend", "x": 250}]},
 *     {"name": "Opponent", "type": "opponent", "characters": [{"name": "dad"}]},
 *     {"name": "Backup",   "type": "additional", "characters": [{"name": "spooky", "position": "gf", "x": -300}],
 *      "visible": true, "strumScale": 0.5}
 *   ]
 *
 * type: "player" (you hit its notes: score, health, misses), "opponent" (the CPU hits them, like dad's), "additional"
 * (the CPU hits them too; meant for extra singers - it never moves the camera or touches the opponent's vocals).
 * characters[].position: "boyfriend" / "dad" / "gf" (stage spot from the stage file) or "custom" (x, y are absolute);
 * x / y move the character from that spot. For lines 0 and 1, the first character is always the song's
 * player1 / player2 (boyfriend / dad).
 * A note's 5th value picks which of its line's characters sing it (0 = first...); missing or -1 = all of them.
 */
typedef StrumLineFile =
{
	@:optional var name:String;
	@:optional var type:String;
	@:optional var characters:Array<StrumLineCharacter>;
	@:optional var visible:Null<Bool>;
	@:optional var strumX:Null<Float>;     // screen x of the left arrow; null = automatic
	@:optional var strumY:Null<Float>;     // screen y; null = same height as the other arrows
	@:optional var strumScale:Null<Float>; // 1 = normal size; null = 1 for lines 0/1, 0.5 for extra lines
}

typedef StrumLineCharacter =
{
	var name:String;
	@:optional var position:String; // boyfriend | dad | gf | custom
	@:optional var x:Null<Float>;
	@:optional var y:Null<Float>;
	@:optional var flipX:Null<Bool>;
}

class StrumLineData
{
	public static inline var MAX_LINES:Int = 8;
	public static final TYPES:Array<String> = ['player', 'opponent', 'additional'];
	public static final POSITIONS:Array<String> = ['boyfriend', 'dad', 'gf', 'custom'];

	/**
	 * The song's strumlines, always at least 2, cleaned up (unknown types / positions fixed, missing fields filled,
	 * too many lines cut). Problems go to vortex_script_log.txt. Writes the cleaned list back to the song only when
	 * the song already had one, so plain Psych charts stay plain.
	 */
	public static function get(song:SwagSong):Array<StrumLineFile>
	{
		var raw:Dynamic = (song != null) ? Reflect.field(song, 'strumLines') : null;
		var lines:Array<StrumLineFile> = [];
		if(raw != null && Std.isOfType(raw, Array))
		{
			for (entry in (raw:Array<Dynamic>))
				if(entry != null) lines.push(entry);
		}
		if(lines.length > MAX_LINES)
		{
			psychlua.ScriptLog.error('Chart: ${song.song}', 'More than $MAX_LINES strumlines, the extra ones were ignored.');
			lines = lines.slice(0, MAX_LINES);
		}
		while(lines.length < 2) lines.push({});

		for (i in 0...lines.length)
		{
			var line:StrumLineFile = lines[i];
			if(i == 0) line.type = 'player';
			else if(i == 1) line.type = 'opponent';
			else
			{
				var t:String = (line.type != null) ? Std.string(line.type).toLowerCase().trim() : 'additional';
				if(!TYPES.contains(t))
				{
					psychlua.ScriptLog.error('Chart: ${song.song}', 'Strumline ${i + 1} has an unknown type "${line.type}", using "additional".');
					t = 'additional';
				}
				line.type = t;
			}
			if(line.name == null || Std.string(line.name).trim().length < 1)
				line.name = (i == 0) ? 'Player' : ((i == 1) ? 'Opponent' : 'Strumline ${i + 1}');
			if(line.visible == null) line.visible = true;

			var chars:Array<StrumLineCharacter> = [];
			if(line.characters != null && Std.isOfType(line.characters, Array))
				for (c in (line.characters:Array<Dynamic>))
				{
					if(c == null) continue;
					if(Std.isOfType(c, String)) c = {name: c};
					if(c.name == null || Std.string(c.name).trim().length < 1) continue;
					var ch:StrumLineCharacter = {name: Std.string(c.name).trim()};
					var pos:String = (c.position != null) ? Std.string(c.position).toLowerCase() : null;
					ch.position = (pos != null && POSITIONS.contains(pos)) ? pos : defaultPosition(line.type);
					ch.x = (c.x != null && !Math.isNaN(Std.parseFloat(Std.string(c.x)))) ? Std.parseFloat(Std.string(c.x)) : 0;
					ch.y = (c.y != null && !Math.isNaN(Std.parseFloat(Std.string(c.y)))) ? Std.parseFloat(Std.string(c.y)) : 0;
					ch.flipX = (c.flipX == true);
					chars.push(ch);
				}
			// lines 0 and 1: the first character IS the song's boyfriend / dad
			if(i < 2 && song != null)
			{
				var main:String = (i == 0) ? song.player1 : song.player2;
				if(chars.length < 1) chars.push({name: main, position: defaultPosition(line.type), x: 0, y: 0, flipX: false});
				else chars[0].name = main;
			}
			line.characters = chars;
		}
		if(raw != null) Reflect.setField(song, 'strumLines', lines);
		return lines;
	}

	public static function defaultPosition(type:String):String
		return (type == 'player') ? 'boyfriend' : (type == 'opponent' ? 'dad' : 'gf');

	/** Does this song use more than the two standard strumlines (or more than one character on them)? **/
	public static function isModular(song:SwagSong):Bool
		return song != null && Reflect.field(song, 'strumLines') != null;
}
