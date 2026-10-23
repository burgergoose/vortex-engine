package backend.compat;

#if sys
import sys.io.File;
#end

/**
 * VORTEX ENGINE ADDITION (0.6) - reads the pictures out of a V-Slice scripted stage.
 *
 * Many V-Slice mods leave "props" empty in data/stages/<id>.json and build the stage in a script instead
 * (scripts/stages/<id>.hxc: `class X extends Stage`, `super('<id>')`, sprites made in onCreate). Vortex can't run
 * those scripts (they use V-Slice's own classes), so the stage used to be black. This reads the script WITHOUT running
 * it: it follows onCreate (and the class's own functions it calls) on paper, keeps track of the sprites it makes
 * (position, picture, animations, scale, scroll, alpha...) and which ones it add()s, and hands them back as Psych stage
 * objects. `if` / `switch` on the song id are followed for one song at a time, so a stage that looks different per
 * song gives a different result per song. Anything it can't work out is left out and reported, never guessed wildly.
 * Things the script does while the song plays (onBeatHit, onStepHit, onSongEvent...) are not converted.
 */
class StageScriptReader
{
	/** Stage scripts of a mod: stage id -> parsed script. */
	public static function findStageScripts(root:String):Map<String, StageScript>
	{
		var out:Map<String, StageScript> = [];
		if (!CompatUtil.isDir(root + 'scripts/')) return out;
		for (file in CompatUtil.walk(root + 'scripts/', 4000))
		{
			var low:String = file.toLowerCase();
			if (!(low.endsWith('.hxc') || low.endsWith('.hx') || low.endsWith('.hxs') || low.endsWith('.hscript'))) continue;
			var src:String = CompatUtil.readText(root + 'scripts/' + file);
			if (src == null || src.indexOf('Stage') < 0 || src.indexOf('super') < 0) continue;
			try
			{
				var s:StageScript = StageScript.parse(src, 'scripts/' + file);
				if (s != null && s.stageId != null && !out.exists(s.stageId)) out.set(s.stageId, s);
			}
			catch (e:Dynamic) {}
		}
		return out;
	}
}

typedef Tok = {k:Int, v:String}; // k: 0 identifier, 1 number, 2 string, 3 symbol

enum SV
{
	VNum(v:Float);
	VStr(v:String);
	VBool(v:Bool);
	VNull;
	VUnknown;
	VSprite(s:ScriptSprite);
	VMember(s:ScriptSprite, path:Array<String>);
	VPath(path:Array<String>);
	VImage(key:String, atlas:Bool);
	VArray(a:Array<SV>);
	VBound(recv:SV, name:String);
}

class ScriptSprite
{
	public var name:String = null;
	public var x:Float = 0;
	public var y:Float = 0;
	public var image:String = null;
	public var atlas:Bool = false;
	public var square:Bool = false;
	public var squareW:Float = 1;
	public var squareH:Float = 1;
	public var color:String = 'FFFFFF';
	public var anims:Array<Dynamic> = [];
	public var firstAnim:String = null;
	public var scaleX:Float = 1;
	public var scaleY:Float = 1;
	public var hitboxed:Bool = false; // updateHitbox() ran after the last scale change
	public var hitW:Null<Float> = null; // width after updateHitbox (null = frame width)
	public var hitH:Null<Float> = null;
	public var offX:Float = 0;
	public var offY:Float = 0;
	public var scrollX:Float = 1;
	public var scrollY:Float = 1;
	public var alpha:Float = 1;
	public var visible:Bool = true;
	public var flipX:Bool = false;
	public var flipY:Bool = false;
	public var angle:Float = 0;
	public var antialiasing:Bool = true;
	public var zIndex:Float = 0;
	public var onHud:Bool = false;
	public var tiled:Bool = false;
	public var special:Array<String> = []; // blend / shader / ... (reported)

	public function new() {}
}

class StageScript
{
	public var file:String;
	public var stageId:String = null;
	public var toks:Array<Tok>;
	public var funcs:Map<String, {args:Array<String>, start:Int, end:Int}> = [];
	public var fields:Array<{name:String, start:Int, end:Int}> = []; // class vars with an initial value
	/** song-time functions the script has (their effects are not converted) */
	public var liveFunctions:Array<String> = [];

	public function new() {}

	public static function parse(src:String, file:String):StageScript
	{
		var s:StageScript = new StageScript();
		s.file = file;
		s.toks = tokenize(src);
		var t = s.toks;
		var i:Int = 0;
		// class <Name> extends <...Stage>
		var body:Int = -1;
		while (i < t.length)
		{
			if (t[i].k == 0 && t[i].v == 'class' && i + 3 < t.length)
			{
				var j:Int = i + 2;
				var ext:Bool = false;
				while (j < t.length && !(t[j].k == 3 && t[j].v == '{'))
				{
					if (t[j].k == 0 && t[j].v.endsWith('Stage') && t[j - 1].k == 0 && t[j - 1].v == 'extends') ext = true;
					if (t[j].k == 0 && t[j].v.endsWith('Stage') && t[j - 1].k == 3 && t[j - 1].v == '.') ext = ext || (j > 1 && t[j - 2].k == 0);
					j++;
				}
				if (ext && j < t.length) { body = j; break; }
				i = j;
			}
			i++;
		}
		if (body < 0) return null;
		var end:Int = s.match(body);
		i = body + 1;
		while (i < end)
		{
			var tk = t[i];
			if (tk.k == 3 && tk.v == '@') { i += 2; if (i < end && t[i].k == 3 && t[i].v == '(') i = s.match(i) + 1; continue; } // @:meta
			if (tk.k == 0 && ['public', 'private', 'static', 'override', 'inline', 'dynamic', 'macro', 'extern'].contains(tk.v)) { i++; continue; }
			if (tk.k == 0 && (tk.v == 'var' || tk.v == 'final') && i + 1 < end)
			{
				var name:String = t[i + 1].v;
				var j:Int = i + 2;
				var depth:Int = 0;
				var eq:Int = -1;
				while (j < end)
				{
					var v = t[j];
					if (v.k == 3)
					{
						if (v.v == '(' || v.v == '[' || v.v == '{') depth++;
						else if (v.v == ')' || v.v == ']' || v.v == '}') depth--;
						else if (depth == 0 && v.v == '=' && eq < 0) eq = j;
						else if (depth == 0 && v.v == ';') break;
					}
					j++;
				}
				if (eq > 0) s.fields.push({name: name, start: eq + 1, end: j});
				i = j + 1;
				continue;
			}
			if (tk.k == 0 && tk.v == 'function' && i + 2 < end)
			{
				var name:String = t[i + 1].v;
				var p:Int = i + 2;
				if (!(t[p].k == 3 && t[p].v == '(')) { i++; continue; }
				var pe:Int = s.match(p);
				var args:Array<String> = [];
				var j:Int = p + 1;
				var expectName:Bool = true;
				var depth:Int = 0;
				while (j < pe)
				{
					var v = t[j];
					if (v.k == 3 && (v.v == '(' || v.v == '<' || v.v == '[')) depth++;
					else if (v.k == 3 && (v.v == ')' || v.v == '>' || v.v == ']')) depth--;
					else if (depth == 0 && v.k == 3 && v.v == ',') expectName = true;
					else if (depth == 0 && expectName && v.k == 0) { args.push(v.v); expectName = false; }
					j++;
				}
				j = pe + 1;
				while (j < end && !(t[j].k == 3 && (t[j].v == '{' || t[j].v == ';'))) j++;
				if (j < end && t[j].v == '{')
				{
					var be:Int = s.match(j);
					s.funcs.set(name, {args: args, start: j + 1, end: be});
					if (name == 'new')
						for (k in j + 1...be - 2)
							if (t[k].k == 0 && t[k].v == 'super' && t[k + 1].v == '(' && t[k + 2].k == 2) { s.stageId = t[k + 2].v; break; }
					if (['onBeatHit', 'onStepHit', 'onUpdate', 'onSongEvent', 'onNoteHit', 'onNoteMiss', 'onSongStart', 'onCountdownStart', 'onSongEnd'].contains(name))
						s.liveFunctions.push(name);
					i = be + 1;
				}
				else i = j + 1;
				continue;
			}
			i++;
		}
		return s;
	}

	/** Runs the script on paper for one song ('' = no song) and returns what onCreate adds. */
	public function read(songId:String, sizeOf:String->Bool->Array<Float>):StageRun
	{
		var run:StageRun = new StageRun(this, songId, sizeOf);
		for (f in fields)
		{
			var v:SV = run.evalRange(f.start, f.end);
			run.setVar(f.name, v);
		}
		for (entry in ['onCreate', 'create', 'buildStage'])
			if (funcs.exists(entry)) { run.callFunc(entry, []); break; }
		return run;
	}

	public function match(i:Int):Int
	{
		var open:String = toks[i].v;
		var close:String = open == '(' ? ')' : (open == '[' ? ']' : '}');
		var depth:Int = 0;
		for (j in i...toks.length)
		{
			var t = toks[j];
			if (t.k != 3) continue;
			if (t.v == open) depth++;
			else if (t.v == close && --depth == 0) return j;
		}
		return toks.length - 1;
	}

	static function tokenize(src:String):Array<Tok>
	{
		var out:Array<Tok> = [];
		var i:Int = 0;
		var n:Int = src.length;
		inline function isDigit(c:Int) return c >= '0'.code && c <= '9'.code;
		inline function isId(c:Int) return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || c == '_'.code || (c >= '0'.code && c <= '9'.code);
		while (i < n)
		{
			var c:Int = src.charCodeAt(i);
			if (c == ' '.code || c == '\t'.code || c == '\n'.code || c == '\r'.code) { i++; continue; }
			if (c == '/'.code && i + 1 < n && src.charCodeAt(i + 1) == '/'.code) { while (i < n && src.charCodeAt(i) != '\n'.code) i++; continue; }
			if (c == '/'.code && i + 1 < n && src.charCodeAt(i + 1) == '*'.code) { var e:Int = src.indexOf('*/', i + 2); i = e < 0 ? n : e + 2; continue; }
			if (c == '#'.code) // #if / #end: skip the directive word
			{
				i++;
				while (i < n && isId(src.charCodeAt(i))) i++;
				continue;
			}
			if (c == '"'.code || c == "'".code)
			{
				var buf:StringBuf = new StringBuf();
				i++;
				while (i < n && src.charCodeAt(i) != c)
				{
					var ch:Int = src.charCodeAt(i);
					if (ch == '\\'.code && i + 1 < n)
					{
						i++;
						ch = src.charCodeAt(i);
						if (ch == 'n'.code) ch = '\n'.code;
						else if (ch == 't'.code) ch = '\t'.code;
					}
					buf.addChar(ch);
					i++;
				}
				i++;
				out.push({k: 2, v: buf.toString()});
				continue;
			}
			if (isDigit(c) || (c == '.'.code && i + 1 < n && isDigit(src.charCodeAt(i + 1))))
			{
				var s:Int = i;
				if (c == '0'.code && i + 1 < n && (src.charAt(i + 1) == 'x' || src.charAt(i + 1) == 'X'))
				{
					i += 2;
					while (i < n && isId(src.charCodeAt(i))) i++;
				}
				else
				{
					while (i < n && (isDigit(src.charCodeAt(i)) || (src.charCodeAt(i) == '.'.code && !(i + 1 < n && src.charCodeAt(i + 1) == '.'.code)))) i++;
					if (i < n && (src.charAt(i) == 'e' || src.charAt(i) == 'E'))
					{
						i++;
						if (i < n && (src.charAt(i) == '-' || src.charAt(i) == '+')) i++;
						while (i < n && isDigit(src.charCodeAt(i))) i++;
					}
				}
				out.push({k: 1, v: src.substring(s, i)});
				continue;
			}
			if (isId(c))
			{
				var s:Int = i;
				while (i < n && isId(src.charCodeAt(i))) i++;
				out.push({k: 0, v: src.substring(s, i)});
				continue;
			}
			if (src.substr(i, 3) == '...') { out.push({k: 3, v: '...'}); i += 3; continue; }
			var two:String = src.substr(i, 2);
			if (['==', '!=', '<=', '>=', '&&', '||', '+=', '-=', '*=', '/=', '++', '--', '->', '=>', '??', '?.'].contains(two))
			{
				out.push({k: 3, v: two});
				i += 2;
				continue;
			}
			out.push({k: 3, v: src.charAt(i)});
			i++;
		}
		return out;
	}
}

/** One on-paper run of a stage script for one song. */
class StageRun
{
	public var songId:String;
	public var added:Array<ScriptSprite> = [];
	public var created:Array<ScriptSprite> = [];
	public var guessed:Int = 0; // conditions that could not be decided (the "then" branch was taken)
	public var skippedSwitches:Int = 0;
	public var unsupported:Array<String> = [];

	var script:StageScript;
	var t:Array<Tok>;
	var env:Map<String, SV> = [];
	var sizeOf:String->Bool->Array<Float>;
	var p:Int = 0;
	var lim:Int = 0;
	var returned:Bool = false;
	var retVal:SV = VUnknown;
	var stack:Array<String> = [];
	var work:Int = 0;

	public function new(script:StageScript, songId:String, sizeOf:String->Bool->Array<Float>)
	{
		this.script = script;
		this.t = script.toks;
		this.songId = songId;
		this.sizeOf = sizeOf;
	}

	public function setVar(name:String, v:SV)
	{
		switch (v)
		{
			case VSprite(s): if (s.name == null) s.name = name;
			default:
		}
		env.set(name, v);
	}

	public function callFunc(name:String, args:Array<SV>):SV
	{
		var f = script.funcs.get(name);
		if (f == null || stack.contains(name) || stack.length > 6) return VUnknown;
		stack.push(name);
		for (i in 0...f.args.length) env.set(f.args[i], i < args.length ? args[i] : VNull);
		var oldRet:Bool = returned;
		returned = false;
		retVal = VUnknown;
		exec(f.start, f.end);
		returned = oldRet;
		stack.pop();
		return retVal;
	}

	/* ---------------- statements ---------------- */

	function isSym(i:Int, v:String):Bool return i < t.length && t[i].k == 3 && t[i].v == v;
	function isWord(i:Int, v:String):Bool return i < t.length && t[i].k == 0 && t[i].v == v;

	function exec(a:Int, b:Int)
	{
		var i:Int = a;
		while (i < b && !returned && work++ < 200000)
		{
			var next:Int = stmt(i, b);
			i = next > i ? next : i + 1;
		}
	}

	function stmt(i:Int, end:Int):Int
	{
		var tk = t[i];
		if (tk.k == 3)
		{
			if (tk.v == '{') { var j:Int = script.match(i); exec(i + 1, j); return j + 1; }
			if (tk.v == ';') return i + 1;
		}
		if (tk.k == 0)
		{
			switch (tk.v)
			{
				case 'if':
					if (!isSym(i + 1, '(')) return i + 1;
					var ce:Int = script.match(i + 1);
					var cond:Null<Bool> = truthy(evalRange(i + 2, ce));
					var thenEnd:Int = skip(ce + 1, end);
					var hasElse:Bool = isWord(thenEnd, 'else');
					if (cond == null) guessed++;
					if (cond == null || cond) stmt(ce + 1, thenEnd);
					else if (hasElse) stmt(thenEnd + 1, end);
					return hasElse ? skip(thenEnd + 1, end) : thenEnd;
				case 'else':
					return skip(i + 1, end); // stray else (already handled by its if)
				case 'try':
					var bodyEnd:Int = skip(i + 1, end);
					stmt(i + 1, bodyEnd);
					var j:Int = bodyEnd;
					while (isWord(j, 'catch') && isSym(j + 1, '(')) j = skip(script.match(j + 1) + 1, end);
					return j;
				case 'for', 'while':
					return skip(i, end);
				case 'do':
					var j:Int = skip(i + 1, end);
					if (isWord(j, 'while') && isSym(j + 1, '(')) j = script.match(j + 1) + 1;
					return isSym(j, ';') ? j + 1 : j;
				case 'switch':
					return doSwitch(i, end);
				case 'return':
					var e:Int = stmtEnd(i + 1, end);
					if (e > i + 1) retVal = evalRange(i + 1, e);
					returned = true;
					return e + 1;
				case 'var', 'final':
					var e:Int = stmtEnd(i, end);
					var name:String = t[i + 1].v;
					var j:Int = i + 2;
					if (isSym(j, ':')) { var d:Int = 0; while (j < e && !(d == 0 && isSym(j, '='))) { if (isSym(j, '<')) d++; else if (isSym(j, '>')) d--; j++; } }
					setVar(name, isSym(j, '=') ? evalRange(j + 1, e) : VNull);
					return e + 1;
				case 'function':
					return skip(i, end);
				case 'break', 'continue':
					return stmtEnd(i, end) + 1;
				default:
			}
		}
		var e:Int = stmtEnd(i, end);
		evalRange(i, e);
		return e + 1;
	}

	/** index of the ';' that ends the statement starting at i (or end) */
	function stmtEnd(i:Int, end:Int):Int
	{
		var depth:Int = 0;
		var j:Int = i;
		while (j < end)
		{
			var v = t[j];
			if (v.k == 3)
			{
				if (v.v == '(' || v.v == '[' || v.v == '{') depth++;
				else if (v.v == ')' || v.v == ']' || v.v == '}') { if (--depth < 0) return j; }
				else if (v.v == ';' && depth == 0) return j;
			}
			j++;
		}
		return end;
	}

	/** index just after the statement that starts at i */
	function skip(i:Int, end:Int):Int
	{
		if (i >= end) return end;
		if (isSym(i, '{')) return script.match(i) + 1;
		if (t[i].k == 0)
		{
			switch (t[i].v)
			{
				case 'if':
					var s:Int = skip(script.match(i + 1) + 1, end);
					return isWord(s, 'else') ? skip(s + 1, end) : s;
				case 'for', 'while':
					return isSym(i + 1, '(') ? skip(script.match(i + 1) + 1, end) : i + 1;
				case 'switch':
					var j:Int = isSym(i + 1, '(') ? script.match(i + 1) + 1 : i + 1;
					return isSym(j, '{') ? script.match(j) + 1 : j;
				case 'try':
					var j:Int = skip(i + 1, end);
					while (isWord(j, 'catch') && isSym(j + 1, '(')) j = skip(script.match(j + 1) + 1, end);
					return j;
				case 'function':
					var j:Int = i + 1;
					while (j < end && !isSym(j, '{') && !isSym(j, ';')) { if (isSym(j, '(')) j = script.match(j); j++; }
					return isSym(j, '{') ? script.match(j) + 1 : j + 1;
				default:
			}
		}
		return stmtEnd(i, end) + 1;
	}

	function doSwitch(i:Int, end:Int):Int
	{
		if (!isSym(i + 1, '(')) return skip(i, end);
		var ce:Int = script.match(i + 1);
		var value:SV = evalRange(i + 2, ce);
		var bo:Int = ce + 1;
		if (!isSym(bo, '{')) return bo;
		var be:Int = script.match(bo);
		var known:Bool = switch (value) { case VStr(_), VNum(_), VBool(_): true; default: false; };
		if (!known) { skippedSwitches++; return be + 1; }
		// case labels at the body's top level
		var labels:Array<{at:Int, colon:Int, isDefault:Bool}> = [];
		var depth:Int = 0;
		var j:Int = bo + 1;
		while (j < be)
		{
			var v = t[j];
			if (v.k == 3 && (v.v == '(' || v.v == '[' || v.v == '{')) depth++;
			else if (v.k == 3 && (v.v == ')' || v.v == ']' || v.v == '}')) depth--;
			else if (depth == 0 && v.k == 0 && (v.v == 'case' || v.v == 'default'))
			{
				var c:Int = j + 1;
				var d2:Int = 0;
				while (c < be && !(d2 == 0 && isSym(c, ':'))) { if (isSym(c, '(') || isSym(c, '[')) d2++; else if (isSym(c, ')') || isSym(c, ']')) d2--; c++; }
				labels.push({at: j, colon: c, isDefault: v.v == 'default'});
				j = c;
			}
			j++;
		}
		var chosen:Int = -1;
		for (k in 0...labels.length)
		{
			var l = labels[k];
			if (l.isDefault) continue;
			// "case 'a', 'b':" -> any of the values
			var a:Int = l.at + 1;
			while (a < l.colon)
			{
				var e:Int = a;
				var d3:Int = 0;
				while (e < l.colon && !(d3 == 0 && isSym(e, ','))) { if (isSym(e, '(') || isSym(e, '[')) d3++; else if (isSym(e, ')') || isSym(e, ']')) d3--; e++; }
				if (same(evalRange(a, e), value) == true) { chosen = k; break; }
				a = e + 1;
			}
			if (chosen >= 0) break;
		}
		if (chosen < 0) for (k in 0...labels.length) if (labels[k].isDefault) chosen = k;
		if (chosen >= 0) exec(labels[chosen].colon + 1, chosen + 1 < labels.length ? labels[chosen + 1].at : be);
		return be + 1;
	}

	/* ---------------- expressions ---------------- */

	public function evalRange(a:Int, b:Int):SV
	{
		if (a >= b) return VUnknown;
		var oldP:Int = p, oldLim:Int = lim;
		p = a;
		lim = b;
		var v:SV = VUnknown;
		try v = parseAssign() catch (e:Dynamic) v = VUnknown;
		p = oldP;
		lim = oldLim;
		return v;
	}

	function at(v:String):Bool return p < lim && t[p].k == 3 && t[p].v == v;

	function parseAssign():SV
	{
		// plain variable assignment: name = ..., this.name = ...
		var nameAt:Int = -1;
		if (p < lim && t[p].k == 0 && p + 1 < lim && t[p + 1].k == 3 && isAssignOp(t[p + 1].v)) nameAt = p;
		else if (isWord(p, 'this') && isSym(p + 1, '.') && p + 3 < lim && t[p + 2].k == 0 && t[p + 3].k == 3 && isAssignOp(t[p + 3].v)) nameAt = p + 2;
		if (nameAt >= 0)
		{
			var name:String = t[nameAt].v;
			var op:String = t[nameAt + 1].v;
			p = nameAt + 2;
			var r:SV = parseAssign();
			setVar(name, op == '=' ? r : arith(op.charAt(0), read(env.exists(name) ? env.get(name) : VUnknown), r));
			return r;
		}
		var l:SV = parseTernary();
		if (p < lim && t[p].k == 3 && isAssignOp(t[p].v))
		{
			var op:String = t[p++].v;
			var r:SV = parseAssign();
			assign(l, op, r);
			return r;
		}
		return l;
	}

	static function isAssignOp(v:String):Bool return v == '=' || v == '+=' || v == '-=' || v == '*=' || v == '/=';

	function parseTernary():SV
	{
		var c:SV = parseOr();
		if (at('?'))
		{
			p++;
			var a:SV = parseAssign();
			if (at(':')) p++;
			var b:SV = parseAssign();
			var tr:Null<Bool> = truthy(c);
			return tr == false ? b : a;
		}
		return c;
	}

	function parseOr():SV
	{
		var l:SV = parseAnd();
		while (at('||') || at('??'))
		{
			var op:String = t[p++].v;
			var r:SV = parseAnd();
			if (op == '??') { l = switch (l) { case VNull, VUnknown: r; default: l; }; continue; }
			var a:Null<Bool> = truthy(l), b:Null<Bool> = truthy(r);
			l = (a == true || b == true) ? VBool(true) : ((a == false && b == false) ? VBool(false) : VUnknown);
		}
		return l;
	}

	function parseAnd():SV
	{
		var l:SV = parseCmp();
		while (at('&&'))
		{
			p++;
			var r:SV = parseCmp();
			var a:Null<Bool> = truthy(l), b:Null<Bool> = truthy(r);
			l = (a == false || b == false) ? VBool(false) : ((a == true && b == true) ? VBool(true) : VUnknown);
		}
		return l;
	}

	function parseCmp():SV
	{
		var l:SV = parseAdd();
		if (p < lim && t[p].k == 3 && ['==', '!=', '<', '>', '<=', '>='].contains(t[p].v))
		{
			var op:String = t[p++].v;
			var r:SV = parseAdd();
			var a:SV = read(l), b:SV = read(r);
			if (op == '==' || op == '!=')
			{
				var s:Null<Bool> = same(a, b);
				if (s == null) return VUnknown;
				return VBool(op == '==' ? s : !s);
			}
			var x:Null<Float> = numOf(a), y:Null<Float> = numOf(b);
			if (x == null || y == null) return VUnknown;
			return VBool(switch (op) { case '<': x < y; case '>': x > y; case '<=': x <= y; default: x >= y; });
		}
		return l;
	}

	function parseAdd():SV
	{
		var l:SV = parseMul();
		while (at('+') || at('-'))
		{
			var op:String = t[p++].v;
			l = arith(op, read(l), read(parseMul()));
		}
		return l;
	}

	function parseMul():SV
	{
		var l:SV = parseUnary();
		while (at('*') || at('/') || at('%'))
		{
			var op:String = t[p++].v;
			l = arith(op, read(l), read(parseUnary()));
		}
		return l;
	}

	function parseUnary():SV
	{
		if (at('-')) { p++; var v:Null<Float> = numOf(read(parseUnary())); return v == null ? VUnknown : VNum(-v); }
		if (at('!')) { p++; var b:Null<Bool> = truthy(read(parseUnary())); return b == null ? VUnknown : VBool(!b); }
		if (at('++') || at('--')) { p++; return parsePostfix(); }
		if (isWord(p, 'cast') || isWord(p, 'untyped')) { p++; return parseUnary(); }
		return parsePostfix();
	}

	function parsePostfix():SV
	{
		var v:SV = parsePrimary();
		while (p < lim)
		{
			if ((at('.') || at('?.')) && p + 1 < lim && t[p + 1].k == 0) { v = field(v, t[p + 1].v); p += 2; }
			else if (at('(')) { var args:Array<SV> = parseArgs(')'); v = call(v, args); }
			else if (at('['))
			{
				var idx:Array<SV> = parseArgs(']');
				v = switch (v)
				{
					case VArray(a):
						var n:Null<Float> = idx.length > 0 ? numOf(read(idx[0])) : null;
						(n != null && n >= 0 && n < a.length) ? a[Std.int(n)] : VUnknown;
					default: VUnknown;
				}
			}
			else if (at('++') || at('--')) p++;
			else break;
		}
		return v;
	}

	/** at '(' or '[': reads the comma-separated values up to the closing bracket */
	function parseArgs(close:String):Array<SV>
	{
		var endAt:Int = script.match(p);
		if (endAt > lim) endAt = lim;
		p++;
		var out:Array<SV> = [];
		var oldLim:Int = lim;
		lim = endAt;
		while (p < lim)
		{
			var before:Int = p;
			out.push(parseAssign());
			if (at(',')) p++;
			else if (p == before) p++;
			else if (p < lim) { while (p < lim && !at(',')) p++; if (at(',')) p++; } // something not understood: skip to the next value
		}
		lim = oldLim;
		p = endAt + 1;
		return out;
	}

	function parsePrimary():SV
	{
		if (p >= lim) return VUnknown;
		var tk = t[p];
		switch (tk.k)
		{
			case 1:
				p++;
				if (tk.v.startsWith('0x') || tk.v.startsWith('0X')) return VNum(hexValue(tk.v.substr(2)));
				var f:Float = Std.parseFloat(tk.v);
				return Math.isNaN(f) ? VUnknown : VNum(f);
			case 2:
				p++;
				return VStr(tk.v);
			case 3:
				if (tk.v == '(') { var a:Array<SV> = parseArgs(')'); return a.length > 0 ? a[a.length - 1] : VUnknown; }
				if (tk.v == '[') return VArray(parseArgs(']'));
				if (tk.v == '{') { p = script.match(p) + 1; return VUnknown; }
				p++;
				return VUnknown;
			default:
		}
		p++;
		switch (tk.v)
		{
			case 'true': return VBool(true);
			case 'false': return VBool(false);
			case 'null': return VNull;
			case 'this': return VPath(['this']);
			case 'function':
				while (p < lim && !at('{')) p++;
				if (at('{')) p = script.match(p) + 1;
				return VUnknown;
			case 'new':
				var type:String = '';
				while (p < lim && (t[p].k == 0 || at('.'))) type += t[p++].v;
				if (at('<')) { var d:Int = 0; do { if (at('<')) d++; else if (at('>')) d--; p++; } while (p < lim && d > 0); }
				var args:Array<SV> = at('(') ? parseArgs(')') : [];
				return construct(type, args);
			default:
		}
		if (env.exists(tk.v)) return env.get(tk.v);
		return VPath([tk.v]);
	}

	/* ---------------- values ---------------- */

	function field(v:SV, name:String):SV
	{
		return switch (v)
		{
			case VPath(path):
				if (path.length == 1 && path[0] == 'this') env.exists(name) ? env.get(name) : VPath([name]);
				else resolvePath(path.concat([name]));
			case VSprite(s): VMember(s, [name]);
			case VMember(s, path): VMember(s, path.concat([name]));
			case VStr(s): name == 'length' ? VNum(s.length) : VBound(v, name);
			case VArray(a): name == 'length' ? VNum(a.length) : VBound(v, name);
			default: VUnknown;
		}
	}

	function resolvePath(path:Array<String>):SV
	{
		var full:String = path.join('.');
		var last:String = path[path.length - 1];
		switch (full)
		{
			case 'FlxG.width': return VNum(1280);
			case 'FlxG.height': return VNum(720);
			case 'FlxG.onMobile', 'Preferences.lowQuality', 'Preferences.downscroll', 'ClientPrefs.lowQuality', 'ClientPrefs.data.lowQuality': return VBool(false);
			case 'Preferences.flashingLights', 'Preferences.naughtyness', 'Preferences.zoomCamera', 'Preferences.antialiasing': return VBool(true);
			case 'PlayState.SONG.song': return VStr(songId);
			case 'FlxAxes.X': return VStr('X');
			case 'FlxAxes.Y': return VStr('Y');
			case 'FlxAxes.XY': return VStr('XY');
			default:
		}
		// PlayState.instance.currentSong.id, PlayState.instance.currentChart.song.id, currentSong.songId ...
		if ((last == 'id' || last == 'songId') && (full.indexOf('currentSong') > -1 || full.indexOf('currentChart') > -1 || full.indexOf('.song.') > -1))
			return VStr(songId);
		if (path[0] == 'FlxColor' && path.length == 2)
		{
			var c:Null<Int> = COLORS.get(last);
			if (c != null) return VNum(c);
		}
		return VPath(path);
	}

	static final COLORS:Map<String, Int> = [
		'BLACK' => 0x000000, 'WHITE' => 0xFFFFFF, 'RED' => 0xFF0000, 'GREEN' => 0x008000, 'LIME' => 0x00FF00, 'BLUE' => 0x0000FF,
		'YELLOW' => 0xFFFF00, 'ORANGE' => 0xFFA500, 'PURPLE' => 0x800080, 'PINK' => 0xFFC0CB, 'MAGENTA' => 0xFF00FF,
		'CYAN' => 0x00FFFF, 'GRAY' => 0x808080, 'BROWN' => 0x8B4513, 'TRANSPARENT' => 0x000000
	];

	function call(v:SV, args:Array<SV>):SV
	{
		switch (v)
		{
			case VPath(path):
				var full:String = path.join('.');
				var last:String = path[path.length - 1];
				if (path.length == 1 && script.funcs.exists(full) && full != 'new') return callFunc(full, args);
				switch (last)
				{
					case 'add', 'addProp', 'addBehindGF', 'addBehindBF', 'addBehindDad', 'insert':
						if (path.length == 1 || path[0] == 'this' || full.indexOf('PlayState') > -1 || full.indexOf('Stage') > -1)
						{
							for (a in args) switch (a) { case VSprite(s): addSprite(s); default: }
							return VUnknown;
						}
					case 'remove':
						if (path.length == 1 || path[0] == 'this')
							for (a in args) switch (a) { case VSprite(s): added.remove(s); default: }
						return VUnknown;
					default:
				}
				switch (full)
				{
					case 'Paths.image': return VImage(keyOf(args[0]), false);
					case 'Paths.getSparrowAtlas', 'Paths.getPackerAtlas', 'Paths.getAtlas': return VImage(keyOf(args[0]), true);
					case 'FunkinSprite.create', 'FunkinSprite.createSparrow', 'FunkinSprite.createPacker':
						var s:ScriptSprite = newSprite(numArg(args, 0, 0), numArg(args, 1, 0));
						var k:String = args.length > 2 ? keyOf(args[2]) : null;
						if (k != null) { s.image = k; s.atlas = full != 'FunkinSprite.create'; }
						return VSprite(s);
					case 'FunkinSprite.createTextureAtlas':
						note('texture atlas (Adobe Animate) sprites');
						return VUnknown;
					case 'FlxColor.fromRGB':
						return VNum((Std.int(numArg(args, 0, 0)) << 16) | (Std.int(numArg(args, 1, 0)) << 8) | Std.int(numArg(args, 2, 0)));
					case 'FlxColor.fromString':
						var s:String = strOf(args[0]);
						if (s == null) return VUnknown;
						s = s.replace('#', '').replace('0x', '');
						return VNum(hexValue(s.substr(s.length > 6 ? s.length - 6 : 0)));
					case 'Std.int', 'Math.floor': var n:Null<Float> = numOf(read(args[0])); return n == null ? VUnknown : VNum(Math.floor(n));
					case 'Math.round': var n:Null<Float> = numOf(read(args[0])); return n == null ? VUnknown : VNum(Math.round(n));
					case 'Math.abs': var n:Null<Float> = numOf(read(args[0])); return n == null ? VUnknown : VNum(Math.abs(n));
					default:
				}
				return VUnknown;
			case VMember(s, path):
				return spriteCall(s, path.join('.'), args);
			case VBound(VStr(s), name):
				switch (name)
				{
					case 'toLowerCase': return VStr(s.toLowerCase());
					case 'toUpperCase': return VStr(s.toUpperCase());
					case 'trim': return VStr(s.trim());
					case 'startsWith': var a:String = strOf(args[0]); return a == null ? VUnknown : VBool(s.startsWith(a));
					case 'endsWith': var a:String = strOf(args[0]); return a == null ? VUnknown : VBool(s.endsWith(a));
					case 'indexOf': var a:String = strOf(args[0]); return a == null ? VUnknown : VNum(s.indexOf(a));
					case 'contains': var a:String = strOf(args[0]); return a == null ? VUnknown : VBool(s.indexOf(a) > -1);
					default:
				}
				return VUnknown;
			case VBound(VArray(a), name):
				if ((name == 'contains' || name == 'indexOf') && args.length > 0)
				{
					var idx:Int = -1;
					for (i in 0...a.length) if (same(read(a[i]), read(args[0])) == true) { idx = i; break; }
					return name == 'contains' ? VBool(idx > -1) : VNum(idx);
				}
				return VUnknown;
			default:
				return VUnknown;
		}
	}

	function spriteCall(s:ScriptSprite, name:String, args:Array<SV>):SV
	{
		switch (name)
		{
			case 'loadGraphic', 'loadTexture':
				var k:String = keyOf(args[0]);
				if (k != null) { s.image = k; s.atlas = false; s.square = false; s.hitW = null; s.hitH = null; }
				if (name == 'loadGraphic' && args.length > 1 && truthy(read(args[1])) == true) note('loadGraphic with animation frames (grid sprites)');
			case 'loadSparrow', 'loadPacker':
				var k:String = keyOf(args[0]);
				if (k != null) { s.image = k; s.atlas = true; s.square = false; s.hitW = null; s.hitH = null; }
			case 'makeGraphic', 'makeSolidColor':
				s.square = true;
				s.image = null;
				s.squareW = numArg(args, 0, 1);
				s.squareH = numArg(args, 1, 1);
				s.hitW = null;
				s.hitH = null;
				var c:Null<Float> = args.length > 2 ? numOf(read(args[2])) : 0xFFFFFF;
				if (c != null) s.color = rgbHex(c);
			case 'setPosition':
				s.x = numArg(args, 0, 0);
				s.y = numArg(args, 1, 0);
			case 'setGraphicSize':
				var size:Array<Float> = frameSize(s);
				var w:Float = numArg(args, 0, 0), h:Float = numArg(args, 1, 0);
				if (size != null)
				{
					if (w > 0) s.scaleX = w / size[0];
					if (h > 0) s.scaleY = h / size[1];
					if (w <= 0) s.scaleX = s.scaleY;
					if (h <= 0) s.scaleY = s.scaleX;
					s.hitboxed = false;
				}
				else note('setGraphicSize on a picture that could not be measured');
			case 'updateHitbox':
				var size:Array<Float> = frameSize(s);
				if (size != null) { s.hitW = size[0] * Math.abs(s.scaleX); s.hitH = size[1] * Math.abs(s.scaleY); }
				s.hitboxed = true;
				s.offX = 0;
				s.offY = 0;
			case 'screenCenter':
				var axes:String = args.length > 0 ? strOf(args[0]) : 'XY';
				if (axes == null) axes = 'XY';
				var size:Array<Float> = frameSize(s);
				if (size == null) { note('screenCenter on a picture that could not be measured'); return VSprite(s); }
				var w:Float = s.hitW != null ? s.hitW : size[0];
				var h:Float = s.hitH != null ? s.hitH : size[1];
				if (axes.indexOf('X') > -1) s.x = (1280 - w) / 2;
				if (axes.indexOf('Y') > -1) s.y = (720 - h) / 2;
			case 'animation.addByPrefix':
				var an:String = strOf(args[0]), pre:String = strOf(args[1]);
				if (an != null && pre != null)
					s.anims.push({anim: an, name: pre, fps: Std.int(numArg(args, 2, 30)), loop: args.length > 3 ? truthy(read(args[3])) != false : true, indices: [], offsets: [0, 0]});
			case 'animation.addByIndices':
				var an:String = strOf(args[0]), pre:String = strOf(args[1]);
				var ind:Array<Int> = [];
				switch (args.length > 2 ? args[2] : VUnknown)
				{
					case VArray(a): for (x in a) { var n:Null<Float> = numOf(read(x)); if (n != null) ind.push(Std.int(n)); }
					default:
				}
				if (an != null && pre != null && ind.length > 0)
					s.anims.push({anim: an, name: pre, fps: Std.int(numArg(args, 4, 30)), loop: args.length > 5 ? truthy(read(args[5])) != false : true, indices: ind, offsets: [0, 0]});
			case 'animation.play', 'playAnimation', 'playAnim':
				var an:String = strOf(args[0]);
				if (an != null) s.firstAnim = an;
			case 'scale.set':
				s.scaleX = numArg(args, 0, 0);
				s.scaleY = numArg(args, 1, 0);
				s.hitboxed = false;
			case 'scrollFactor.set':
				s.scrollX = numArg(args, 0, 0);
				s.scrollY = numArg(args, 1, 0);
			case 'offset.set':
				s.offX = numArg(args, 0, 0);
				s.offY = numArg(args, 1, 0);
			case 'kill':
				s.visible = false;
			case 'revive':
				s.visible = true;
			default:
		}
		return VSprite(s);
	}

	function assign(l:SV, op:String, r:SV)
	{
		switch (l)
		{
			case VMember(s, path):
				var name:String = path.join('.');
				var rv:SV = read(r);
				var n:Null<Float> = numOf(rv);
				if (op != '=')
				{
					var cur:Null<Float> = numOf(read(l));
					n = (cur == null || n == null) ? null : switch (op) { case '+=': cur + n; case '-=': cur - n; case '*=': cur * n; default: n == 0 ? cur : cur / n; };
				}
				switch (name)
				{
					case 'x': if (n != null) s.x = n;
					case 'y': if (n != null) s.y = n;
					case 'alpha': if (n != null) s.alpha = n;
					case 'angle': if (n != null) s.angle = n;
					case 'zIndex': if (n != null) s.zIndex = n;
					case 'scale.x': if (n != null) { s.scaleX = n; s.hitboxed = false; }
					case 'scale.y': if (n != null) { s.scaleY = n; s.hitboxed = false; }
					case 'scrollFactor.x': if (n != null) s.scrollX = n;
					case 'scrollFactor.y': if (n != null) s.scrollY = n;
					case 'offset.x': if (n != null) s.offX = n;
					case 'offset.y': if (n != null) s.offY = n;
					case 'visible': var b:Null<Bool> = truthy(rv); if (b != null) s.visible = b;
					case 'flipX': var b:Null<Bool> = truthy(rv); if (b != null) s.flipX = b;
					case 'flipY': var b:Null<Bool> = truthy(rv); if (b != null) s.flipY = b;
					case 'antialiasing': var b:Null<Bool> = truthy(rv); if (b != null) s.antialiasing = b;
					case 'color': if (n != null) s.color = rgbHex(n);
					case 'frames':
						switch (rv) { case VImage(k, _): if (k != null) { s.image = k; s.atlas = true; s.square = false; s.hitW = null; s.hitH = null; } default: }
					case 'cameras', 'camera':
						var text:String = Std.string(r);
						if (text.indexOf('camHUD') > -1 || text.indexOf('camOther') > -1 || text.indexOf('camCutscene') > -1) s.onHud = true;
					case 'blend', 'shader':
						if (!s.special.contains(name)) s.special.push(name);
					default:
				}
			default:
		}
	}

	/** reads a sprite member (x, y, alpha...) as a value */
	function read(v:SV):SV
	{
		if (v == null) return VUnknown; // a missing argument
		switch (v)
		{
			case VMember(s, path):
				switch (path.join('.'))
				{
					case 'x': return VNum(s.x);
					case 'y': return VNum(s.y);
					case 'alpha': return VNum(s.alpha);
					case 'angle': return VNum(s.angle);
					case 'visible': return VBool(s.visible);
					case 'scale.x': return VNum(s.scaleX);
					case 'scale.y': return VNum(s.scaleY);
					case 'width', 'height', 'frameWidth', 'frameHeight':
						var size:Array<Float> = frameSize(s);
						if (size == null) return VUnknown;
						var key:String = path[0];
						if (key == 'frameWidth') return VNum(size[0]);
						if (key == 'frameHeight') return VNum(size[1]);
						if (key == 'width') return VNum(s.hitW != null ? s.hitW : size[0]);
						return VNum(s.hitH != null ? s.hitH : size[1]);
					default: return VUnknown;
				}
			default:
				return v;
		}
	}

	function construct(type:String, args:Array<SV>):SV
	{
		var name:String = type.substr(type.lastIndexOf('.') + 1);
		switch (name)
		{
			case 'FlxSprite', 'FunkinSprite', 'FlxSkewedSprite', 'ModchartSprite', 'FlxAnimate':
				var s:ScriptSprite = newSprite(numArg(args, 0, 0), numArg(args, 1, 0));
				if (args.length > 2) { var k:String = keyOf(args[2]); if (k != null) s.image = k; }
				if (name == 'FlxAnimate') note('texture atlas (Adobe Animate) sprites');
				return VSprite(s);
			case 'BGSprite': // Psych-style helper some ports keep
				var s:ScriptSprite = newSprite(numArg(args, 1, 0), numArg(args, 2, 0));
				s.image = keyOf(args[0]);
				s.scrollX = numArg(args, 3, 1);
				s.scrollY = numArg(args, 4, 1);
				return VSprite(s);
			case 'FlxBackdrop':
				var s:ScriptSprite = newSprite(0, 0);
				s.image = args.length > 0 ? keyOf(args[0]) : null;
				s.tiled = true;
				return VSprite(s);
			default:
				return VUnknown;
		}
	}

	function newSprite(x:Float, y:Float):ScriptSprite
	{
		var s:ScriptSprite = new ScriptSprite();
		s.x = x;
		s.y = y;
		created.push(s);
		return s;
	}

	function addSprite(s:ScriptSprite)
	{
		added.remove(s);
		added.push(s);
	}

	function note(what:String) if (!unsupported.contains(what)) unsupported.push(what);

	/** frame size of a sprite's picture (null if unknown) */
	public function frameSize(s:ScriptSprite):Array<Float>
	{
		if (s.square) return [s.squareW, s.squareH];
		if (s.image == null || sizeOf == null) return null;
		return sizeOf(s.image, s.atlas);
	}

	/** picture key of Paths.image('x') / 'x' / 'shared:x' / 'assets/images/x.png' */
	function keyOf(v:SV):String
	{
		var k:String = switch (read(v))
		{
			case VImage(key, _): key;
			case VStr(s): s;
			default: null;
		}
		if (k == null) return null;
		k = CompatUtil.stripLibrary(k);
		var i:Int = k.indexOf('images/');
		if (i > -1) k = k.substr(i + 7);
		if (k.endsWith('.png')) k = k.substr(0, k.length - 4);
		return k;
	}

	function strOf(v:SV):String
	{
		return switch (read(v)) { case VStr(s): s; default: null; };
	}

	function numArg(args:Array<SV>, i:Int, def:Float):Float
	{
		if (i >= args.length) return def;
		var n:Null<Float> = numOf(read(args[i]));
		return n == null ? def : n;
	}

	static function numOf(v:SV):Null<Float>
	{
		if (v == null) return null;
		return switch (v) { case VNum(n): n; default: null; };
	}

	static function truthy(v:SV):Null<Bool>
	{
		if (v == null) return null;
		return switch (v)
		{
			case VBool(b): b;
			case VNum(n): n != 0;
			case VStr(_), VSprite(_), VImage(_, _), VArray(_): true;
			case VNull: false;
			default: null;
		}
	}

	static function same(a:SV, b:SV):Null<Bool>
	{
		if (a == null || b == null) return null;
		switch (a)
		{
			case VStr(x): switch (b) { case VStr(y): return x == y; case VNull: return false; default: return null; }
			case VNum(x): switch (b) { case VNum(y): return x == y; case VNull: return false; default: return null; }
			case VBool(x): switch (b) { case VBool(y): return x == y; default: return null; }
			case VNull: switch (b) { case VNull: return true; case VStr(_), VNum(_), VBool(_), VSprite(_): return false; default: return null; }
			case VSprite(x): switch (b) { case VSprite(y): return x == y; case VNull: return false; default: return null; }
			default: return null;
		}
	}

	static function arith(op:String, a:SV, b:SV):SV
	{
		switch (a)
		{
			case VStr(x):
				if (op != '+') return VUnknown;
				return switch (b) { case VStr(y): VStr(x + y); case VNum(y): VStr(x + (y == Math.ffloor(y) ? Std.string(Std.int(y)) : Std.string(y))); default: VUnknown; };
			case VNum(x):
				switch (b)
				{
					case VNum(y):
						return VNum(switch (op) { case '+': x + y; case '-': x - y; case '*': x * y; case '%': y == 0 ? 0 : x % y; default: y == 0 ? 0 : x / y; });
					case VStr(y):
						return op == '+' ? VStr(Std.string(x) + y) : VUnknown;
					default:
						return VUnknown;
				}
			default:
				return VUnknown;
		}
	}

	/** Psych stage objects for the sprites onCreate add()s, in add order. */
	public function toPsychObjects(id:String, skipped:Array<String>):Array<Dynamic>
	{
		var out:Array<Dynamic> = [];
		var n:Int = 0;
		for (s in added)
		{
			var name:String = s.name != null ? s.name : 'scriptSprite${n}';
			n++;
			if (s.image == null && !s.square) { skipped.push('"$name" (it has no picture when the stage is created; the script gives it one for other songs or later)'); continue; }
			if (s.onHud) { skipped.push('"$name" (it is drawn on the HUD, not the stage)'); continue; }
			if (!s.visible || s.alpha <= 0) { skipped.push('"$name" (it starts hidden; the script shows it during the song)'); continue; }
			var size:Array<Float> = frameSize(s);
			var x:Float = s.x - s.offX, y:Float = s.y - s.offY;
			var sx:Float = s.scaleX, sy:Float = s.scaleY;
			// Psych calls updateHitbox() after scaling (picture's top-left on x/y); in flixel without it the picture
			// is scaled around its centre, so move it to where flixel draws it.
			if (!s.hitboxed && size != null && (sx != 1 || sy != 1))
			{
				x += size[0] * (1 - sx) / 2;
				y += size[1] * (1 - sy) / 2;
			}
			var obj:Dynamic = {
				name: name, x: round(x), y: round(y), scale: [round(sx), round(sy)], scroll: [round(s.scrollX), round(s.scrollY)],
				alpha: round(s.alpha), angle: s.angle, antialiasing: s.antialiasing, flipX: s.flipX, flipY: s.flipY, color: s.color, filters: 0,
				zIndex: s.zIndex
			};
			if (s.square)
			{
				obj.type = 'square';
				obj.scale = [round(s.squareW * sx), round(s.squareH * sy)];
			}
			else
			{
				obj.image = s.image;
				if (s.atlas && s.anims.length > 0)
				{
					obj.type = 'animatedSprite';
					// the animation played first goes first (Psych plays the first one it adds unless firstAnimation matches)
					obj.animations = s.anims;
					obj.firstAnimation = s.firstAnim != null ? s.firstAnim : s.anims[0].anim;
				}
				else if (s.atlas)
				{
					obj.type = 'animatedSprite';
					obj.animations = [];
				}
				else obj.type = 'sprite';
			}
			if (s.tiled) skipped.push('"$name" repeats across the screen in V-Slice (FlxBackdrop); Vortex shows it once');
			for (sp in s.special) note(sp + ' on stage sprites');
			out.push(obj);
		}
		return out;
	}

	static inline function round(v:Float):Float return Math.round(v * 1000) / 1000;

	/** hex digits as a Float (0xAARRGGBB colours don't fit an Int) */
	static function hexValue(digits:String):Float
	{
		var v:Float = 0;
		for (i in 0...digits.length)
		{
			var d:Int = '0123456789abcdef'.indexOf(digits.charAt(i).toLowerCase());
			if (d < 0) break;
			v = v * 16 + d;
		}
		return v;
	}

	/** RRGGBB of a colour number (drops the alpha byte) */
	static function rgbHex(v:Float):String
	{
		var rgb:Float = v % 16777216;
		if (rgb < 0) rgb += 16777216;
		return StringTools.hex(Std.int(rgb), 6);
	}
}
