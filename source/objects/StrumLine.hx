package objects;

import backend.StrumLineData;

/**
 * VORTEX ENGINE ADDITION - one strumline while a song plays (see backend/StrumLineData.hx for the chart format).
 * Line 0 wraps PlayState.playerStrums + boyfriend, line 1 wraps opponentStrums + dad, so everything Psych scripts
 * do with those keeps working; extra lines (2+) have their own arrows and characters.
 */
class StrumLine
{
	public var index:Int;
	public var name:String;
	public var type:String;
	public var strums:FlxTypedGroup<StrumNote>;
	/** Everyone who can sing this line's notes. For lines 0/1, characters[0] is boyfriend / dad. **/
	public var characters:Array<Character> = [];
	/** Variable names (getProperty / setProperty tags) of the characters added for this line. **/
	public var characterTags:Array<String> = [];
	public var data:StrumLineFile;
	public var visible(default, set):Bool = true;
	public var scale:Float = 1;

	public function new(index:Int, data:StrumLineFile, strums:FlxTypedGroup<StrumNote>)
	{
		this.index = index;
		this.data = data;
		this.name = data.name;
		this.type = data.type;
		this.strums = strums;
		this.scale = (data.strumScale != null && data.strumScale > 0) ? data.strumScale : (index < 2 ? 1 : 0.5);
	}

	public var mustPress(get, never):Bool;
	inline function get_mustPress():Bool
		return type == 'player';

	/** CPU-played and not the main opponent: doesn't move the camera or affect the opponent's vocals. **/
	public var isAdditional(get, never):Bool;
	inline function get_isAdditional():Bool
		return type == 'additional';

	function set_visible(v:Bool):Bool
	{
		visible = v;
		if(strums != null) for (s in strums) if(s != null) s.visible = v;
		return v;
	}

	/** Characters that sing a note: `singer` -1 = all of them, otherwise that one (if it exists). **/
	public function singersFor(singer:Int):Array<Character>
	{
		if(singer >= 0 && singer < characters.length && characters[singer] != null) return [characters[singer]];
		return [for (c in characters) if(c != null) c];
	}
}
