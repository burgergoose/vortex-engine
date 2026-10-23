package backend.compat;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * VORTEX ENGINE ADDITION - small file / JSON helpers shared by the engine-compatibility translators
 * (backend/compat/*). Everything here is defensive: a broken file returns null and the caller reports it.
 */
class CompatUtil
{
	public static function exists(path:String):Bool
	{
		#if sys return path != null && FileSystem.exists(path); #else return false; #end
	}

	public static function isDir(path:String):Bool
	{
		#if sys return exists(path) && FileSystem.isDirectory(path); #else return false; #end
	}

	/** Entries of a folder (names only), sorted, [] if it doesn't exist. */
	public static function list(dir:String):Array<String>
	{
		#if sys
		if (!isDir(dir)) return [];
		// Vortex Engine 0.6: zips made on a Mac carry __MACOSX/ and "._name" files (not real files); ignore them
		var out:Array<String> = FileSystem.readDirectory(dir).filter(function(n) return !isJunk(n));
		out.sort(function(a, b) return (a.toLowerCase() < b.toLowerCase()) ? -1 : (a.toLowerCase() > b.toLowerCase() ? 1 : 0));
		return out;
		#else
		return [];
		#end
	}

	/** Mac archive junk: the __MACOSX folder and AppleDouble "._name" files. */
	public static function isJunk(name:String):Bool
		return name == '__MACOSX' || name.startsWith('._') || name == '.DS_Store';

	/**
	 * V-Slice (Polymod) asset libraries: a V-Slice mod can keep pictures / sounds in these sub-folders instead of its
	 * root (most real mods use shared/images/). Same order V-Slice searches: shared, then the level libraries.
	 */
	public static final VSLICE_LIBRARIES:Array<String> = ['shared', 'tutorial', 'week1', 'week2', 'week3', 'week4', 'week5', 'week6', 'week7', 'weekend1', 'sserafim', 'videos'];

	/** First existing `rel` in the mod root or one of the given sub-folders (e.g. 'shared/'), or null. */
	public static function findIn(root:String, rel:String, prefixes:Array<String>):String
	{
		if (exists(root + rel)) return root + rel;
		if (prefixes != null) for (p in prefixes) if (exists(root + p + rel)) return root + p + rel;
		return null;
	}

	/**
	 * Vortex Engine 0.7: `rel` under `dir` matched without caring about upper / lower case (Windows doesn't, phones do).
	 * Returns the path as it is really spelled on disk (relative to `dir`), or null.
	 */
	public static function findCaseless(dir:String, rel:String):String
	{
		#if sys
		if (exists(dir + rel)) // exists() ignores case on Windows: still look up the real spelling
		{
			var parts:Array<String> = rel.split('/');
			var cur:String = '';
			for (part in parts)
			{
				if (part.length < 1) continue;
				var found:String = null;
				if (isDir(dir + cur)) for (n in FileSystem.readDirectory(dir + cur)) if (n == part) { found = n; break; }
				if (found == null && isDir(dir + cur)) for (n in FileSystem.readDirectory(dir + cur)) if (n.toLowerCase() == part.toLowerCase()) { found = n; break; }
				if (found == null) return rel;
				cur += (cur.length > 0 ? '/' : '') + found;
			}
			return cur;
		}
		var parts:Array<String> = rel.split('/');
		var cur:String = '';
		for (part in parts)
		{
			if (part.length < 1) continue;
			if (!isDir(dir + cur)) return null;
			var found:String = null;
			for (n in FileSystem.readDirectory(dir + cur)) if (n.toLowerCase() == part.toLowerCase()) { found = n; break; }
			if (found == null) return null;
			cur += (cur.length > 0 ? '/' : '') + found;
		}
		return cur;
		#else
		return exists(dir + rel) ? rel : null;
		#end
	}

	/**
	 * The folder that really holds a mod's files. People often extract a download so the mod ends up one folder too
	 * deep (mods/Download/My Mod/...). Returns '' when the mod is where it should be, or 'My Mod/' when its files are in
	 * the only sub-folder.
	 */
	public static function contentRoot(root:String):String
	{
		if (hasModMarkers(root)) return '';
		var dirs:Array<String> = list(root).filter(function(n) return isDir(root + n));
		if (dirs.length == 1 && hasModMarkers(root + dirs[0] + '/')) return dirs[0] + '/';
		return '';
	}

	static function hasModMarkers(dir:String):Bool
	{
		for (m in ['_polymod_meta.json', 'pack.json', 'data', 'songs', 'weeks', 'characters', 'images', 'stages', 'shared', 'scripts', 'custom_events'])
			if (exists(dir + m)) return true;
		return false;
	}

	/** Every file under `dir` (relative paths with '/'), depth-first, at most `limit` entries. */
	public static function walk(dir:String, ?limit:Int = 20000):Array<String>
	{
		var out:Array<String> = [];
		#if sys
		if (!dir.endsWith('/')) dir += '/';
		var stack:Array<String> = [''];
		while (stack.length > 0 && out.length < limit)
		{
			var rel:String = stack.pop();
			for (name in list(dir + rel))
			{
				var r:String = rel + name;
				if (isDir(dir + r)) stack.push(r + '/');
				else out.push(r);
			}
		}
		#end
		return out;
	}

	public static function readText(path:String):String
	{
		#if sys
		try { return exists(path) ? File.getContent(path) : null; } catch (e:Dynamic) { return null; }
		#else
		return null;
		#end
	}

	/** Parsed JSON (lenient, like the rest of the engine), or null. `err` gets the parse error. */
	public static function readJson(path:String, ?err:Array<String>):Dynamic
	{
		var raw:String = readText(path);
		if (raw == null) return null;
		try { return tjson.TJSON.parse(raw); }
		catch (e:Dynamic)
		{
			if (err != null) err.push(Std.string(e).split('\n')[0]);
			return null;
		}
	}

	public static function readXml(path:String, ?err:Array<String>):Xml
	{
		var raw:String = readText(path);
		if (raw == null) return null;
		try { return Xml.parse(raw).firstElement(); }
		catch (e:Dynamic)
		{
			if (err != null) err.push(Std.string(e).split('\n')[0]);
			return null;
		}
	}

	public static function makeDirs(dir:String):Void
	{
		#if sys
		if (dir == null || dir.length < 1) return;
		var parts:Array<String> = dir.replace('\\', '/').split('/');
		var cur:String = '';
		for (p in parts)
		{
			if (p.length < 1) { cur += '/'; continue; }
			cur += p + '/';
			if (!FileSystem.exists(cur)) FileSystem.createDirectory(cur);
		}
		#end
	}

	public static function writeText(path:String, text:String):Void
	{
		#if sys
		var dir:String = haxe.io.Path.directory(path);
		if (dir.length > 0) makeDirs(dir);
		File.saveContent(path, text);
		#end
	}

	public static function writeJson(path:String, data:Dynamic):Void
		writeText(path, haxe.Json.stringify(data, '\t'));

	public static function copyFile(from:String, to:String):Void
	{
		#if sys
		makeDirs(haxe.io.Path.directory(to));
		File.copy(from, to);
		#end
	}

	/** Deletes a folder tree. Only ever called on folders this engine generated (vortex_compat/, converter output). */
	public static function deleteTree(dir:String):Void
	{
		#if sys
		if (!isDir(dir)) return;
		for (name in FileSystem.readDirectory(dir))
		{
			var p:String = haxe.io.Path.join([dir, name]);
			if (FileSystem.isDirectory(p)) deleteTree(p);
			else FileSystem.deleteFile(p);
		}
		FileSystem.deleteDirectory(dir);
		#end
	}

	/** "size:mtime" of a file, used to notice changes cheaply. */
	public static function stamp(path:String):String
	{
		#if sys
		try
		{
			var st = FileSystem.stat(path);
			return st.size + ':' + st.mtime.getTime();
		}
		catch (e:Dynamic) {}
		#end
		return '?';
	}

	public static function field(obj:Dynamic, name:String, ?def:Dynamic = null):Dynamic
	{
		if (obj == null || Type.typeof(obj) != TObject) return def;
		var v:Dynamic = Reflect.field(obj, name);
		return v == null ? def : v;
	}

	public static function num(v:Dynamic, def:Float):Float
	{
		if (v == null) return def;
		if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) { var f:Float = v; return Math.isNaN(f) ? def : f; }
		var f:Float = Std.parseFloat(Std.string(v));
		return Math.isNaN(f) ? def : f;
	}

	public static function str(v:Dynamic, def:String):String
		return (v == null) ? def : Std.string(v);

	public static function bool(v:Dynamic, def:Bool):Bool
	{
		if (v == null) return def;
		if (Std.isOfType(v, Bool)) return v;
		var s:String = Std.string(v).toLowerCase().trim();
		return s == 'true' || s == '1' || s == 'yes';
	}

	public static function isArray(v:Dynamic):Bool
		return v != null && Std.isOfType(v, Array);

	/** "0..3,5,7..8" -> [0,1,2,3,5,7,8] (Codename-style frame indices). */
	public static function parseIndices(s:String):Array<Int>
	{
		var out:Array<Int> = [];
		if (s == null) return out;
		for (part in s.split(','))
		{
			part = part.trim();
			if (part.length < 1) continue;
			var range:Array<String> = part.split('..');
			if (range.length == 2)
			{
				var a:Null<Int> = Std.parseInt(range[0].trim()), b:Null<Int> = Std.parseInt(range[1].trim());
				if (a != null && b != null)
				{
					var step:Int = (b >= a) ? 1 : -1;
					var end:Int = b;
					var i:Int = a;
					while (true) { out.push(i); if (i == end) break; i += step; }
				}
			}
			else
			{
				var v:Null<Int> = Std.parseInt(part);
				if (v != null) out.push(v);
			}
		}
		return out;
	}

	/** "#RRGGBB" / "0xRRGGBB" / "RRGGBB" -> [r, g, b], or the default. */
	public static function rgb(color:Dynamic, def:Array<Int>):Array<Int>
	{
		if (color == null) return def;
		var s:String = Std.string(color).trim().replace('#', '').replace('0x', '').replace('0X', '');
		if (s.length == 8) s = s.substr(2);
		if (s.length != 6) return def;
		var v:Null<Int> = Std.parseInt('0x' + s);
		if (v == null) return def;
		return [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
	}

	/** Strips V-Slice library prefixes: "shared:characters/BOYFRIEND" -> "characters/BOYFRIEND". */
	public static function stripLibrary(path:String):String
	{
		if (path == null) return null;
		var i:Int = path.indexOf(':');
		return (i > 0 && i < 12) ? path.substr(i + 1) : path;
	}

	public static function fileName(path:String):String
		return haxe.io.Path.withoutDirectory(path);

	public static function baseName(path:String):String
		return haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(path));
}
