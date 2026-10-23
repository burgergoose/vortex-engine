package psychlua;

import objects.StrumLine;
import objects.Character;

/**
 * VORTEX ENGINE ADDITION - Lua / HScript control of the modular strumlines (see backend/StrumLineData.hx).
 * Lines are numbered like in the chart: 0 = player, 1 = opponent, 2+ = extra lines. Songs only.
 *
 *   getStrumLineCount()                          how many strumlines the song has
 *   getStrumLineInfo(line)                       {name, type, visible, scale, characters = {tag, ...}, names = {...}}
 *   setStrumLineVisible(line, visible)           show / hide its arrows and notes
 *   setStrumLinePosition(line, x, y)             move its arrows (x = left arrow; nil keeps that axis)
 *   getStrumLineCharacters(line)                 tags of its singers, for getProperty / setProperty / playAnim
 *   addStrumLineCharacter(line, name, [position], [x], [y])   add a singer now; returns its tag
 *   removeStrumLineCharacter(line, index)        remove a singer (not boyfriend / dad themselves)
 *   strumLineSing(line, direction, [suffix])     make all of its singers play a sing animation (0-3 = left..right)
 * A note's strumline and singer are its `strumLine` and `singer` fields:
 *   setPropertyFromGroup('notes', i, 'singer', 1)   -- only the line's 2nd character sings this note
 */
class StrumLineFunctions
{
	static inline function game():PlayState
		return PlayState.instance;

	public static function line(index:Int):StrumLine
	{
		if (game() == null || game().strumLines == null) return null;
		if (index < 0 || index >= game().strumLines.length)
		{
			LuaUtils.debugPrint('Strumline $index doesn\'t exist (the song has ${game().strumLines.length})', FlxColor.RED);
			return null;
		}
		return game().strumLines[index];
	}

	public static function info(index:Int):Dynamic
	{
		var l = line(index);
		if (l == null) return null;
		return {
			index: l.index, name: l.name, type: l.type, visible: l.visible, scale: l.scale,
			characters: characterTags(index), names: [for (c in l.characters) c != null ? c.curCharacter : '']
		};
	}

	public static function characterTags(index:Int):Array<String>
	{
		var l = line(index);
		if (l == null) return [];
		var out:Array<String> = [];
		for (i in 0...l.characters.length)
		{
			var c = l.characters[i];
			if (index < 2 && i == 0) out.push(index == 0 ? 'boyfriend' : 'dad');
			else out.push(i < l.characterTags.length ? l.characterTags[i] : '');
		}
		return out;
	}

	public static function setVisible(index:Int, visible:Bool):Bool
	{
		var l = line(index);
		if (l == null) return false;
		l.visible = visible;
		for (n in game().notes) if (n != null && game().lineIndexOf(n) == index) n.visible = visible;
		return true;
	}

	public static function setPosition(index:Int, ?x:Null<Float>, ?y:Null<Float>):Bool
	{
		var l = line(index);
		if (l == null || l.strums.length < 1) return false;
		var first = l.strums.members[0];
		var dx:Float = (x != null) ? x - first.x : 0;
		var dy:Float = (y != null) ? y - first.y : 0;
		for (s in l.strums) if (s != null) { s.x += dx; s.y += dy; }
		return true;
	}

	public static function addCharacter(index:Int, name:String, ?position:String, ?x:Float = 0, ?y:Float = 0):String
	{
		var l = line(index);
		if (l == null || name == null || name.length < 1) return null;
		var pos:String = (position != null && backend.StrumLineData.POSITIONS.contains(position.toLowerCase())) ? position.toLowerCase() : backend.StrumLineData.defaultPosition(l.type);
		var char:Character = game().makeStrumLineCharacter({name: name, position: pos, x: x, y: y, flipX: false}, l.mustPress);
		var tag:String = 'strumLine${index}_char${l.characters.length}';
		while (game().variables.exists(tag)) tag += '_';
		l.characters.push(char);
		l.characterTags.push(tag);
		game().variables.set(tag, char);
		return tag;
	}

	public static function removeCharacter(index:Int, charIndex:Int):Bool
	{
		var l = line(index);
		if (l == null || charIndex < 0 || charIndex >= l.characters.length) return false;
		if (index < 2 && charIndex == 0)
		{
			LuaUtils.debugPrint('removeStrumLineCharacter: boyfriend / dad can\'t be removed (use the "Change Character" event)', FlxColor.RED);
			return false;
		}
		var char:Character = l.characters[charIndex];
		var tag:String = (charIndex < l.characterTags.length) ? l.characterTags[charIndex] : null;
		l.characters.splice(charIndex, 1);
		if (charIndex < l.characterTags.length) l.characterTags.splice(charIndex, 1);
		if (tag != null) game().variables.remove(tag);
		if (char != null) { game().remove(char, true); char.destroy(); }
		return true;
	}

	public static function sing(index:Int, direction:Int, ?suffix:String = ''):Bool
	{
		var l = line(index);
		if (l == null) return false;
		var anims:Array<String> = @:privateAccess game().singAnimations;
		var anim:String = anims[Std.int(Math.max(0, Math.min(anims.length - 1, direction)))] + (suffix != null ? suffix : '');
		for (c in l.characters) if (c != null) { c.playAnim(anim, true); c.holdTimer = 0; }
		return true;
	}

	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua)
	{
		var lua:State = funk.lua;
		Lua_helper.add_callback(lua, "getStrumLineCount", function() return (game() != null) ? game().strumLines.length : 0);
		Lua_helper.add_callback(lua, "getStrumLineInfo", function(index:Int) return info(index));
		Lua_helper.add_callback(lua, "setStrumLineVisible", function(index:Int, visible:Bool) return setVisible(index, visible));
		Lua_helper.add_callback(lua, "setStrumLinePosition", function(index:Int, ?x:Null<Float>, ?y:Null<Float>) return setPosition(index, x, y));
		Lua_helper.add_callback(lua, "getStrumLineCharacters", function(index:Int) return characterTags(index));
		Lua_helper.add_callback(lua, "addStrumLineCharacter", function(index:Int, name:String, ?position:String, ?x:Float = 0, ?y:Float = 0) return addCharacter(index, name, position, x, y));
		Lua_helper.add_callback(lua, "removeStrumLineCharacter", function(index:Int, charIndex:Int) return removeCharacter(index, charIndex));
		Lua_helper.add_callback(lua, "strumLineSing", function(index:Int, direction:Int, ?suffix:String = '') return sing(index, direction, suffix));
	}
	#end
}
