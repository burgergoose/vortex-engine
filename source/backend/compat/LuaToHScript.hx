package backend.compat;

/**
 * VORTEX ENGINE ADDITION (0.7) - translates Psych Lua scripts into V-Slice HScript (used by the V-Slice Converter).
 *
 * V-Slice has no Lua. Psych event scripts are usually short (an onEvent with a few Psych functions), so this turns the
 * Lua into HScript class methods and adds small helpers that do what Psych's functions do, with V-Slice's own classes
 * (PsychShim below). Lua syntax is translated in full; Psych functions that have no helper are listed in `unsupported`
 * and become a trace() call, so the rest of the script still works.
 */
class LuaToHScript
{
	/** Psych Lua functions the shim implements (same names, same arguments) */
	public static final SHIM_FUNCTIONS:Array<String> = ['cameraFlash', 'cameraShake', 'cameraFade', 'doTweenZoom', 'doTweenAlpha', 'doTweenX', 'doTweenY',
		'doTweenAngle', 'doTweenColor', 'cancelTween', 'runTimer', 'cancelTimer', 'makeLuaSprite', 'makeAnimatedLuaSprite', 'makeGraphic', 'addLuaSprite',
		'removeLuaSprite', 'luaSpriteExists', 'setScrollFactor', 'setObjectCamera', 'scaleObject', 'setGraphicSize', 'screenCenter', 'addAnimationByPrefix',
		'addAnimationByIndices', 'playAnim', 'objectPlayAnimation', 'characterPlayAnim', 'getProperty', 'setProperty', 'triggerEvent', 'playSound',
		'playMusic', 'debugPrint', 'tonumber', 'tostring', 'setObjectOrder', 'getRandomInt', 'getRandomFloat', 'getRandomBool', 'getSongPosition',
		'luaSpriteMakeGraphic', 'addCameraZoom', 'screenShakePsych', 'cameraFollowPos', 'setGfSpeed', 'altIdle', 'setPropertyText', 'endSong', 'changeCharacter',
		'getMidpointX', 'getMidpointY', 'getGraphicMidpointX', 'getGraphicMidpointY', 'getCharacterX', 'getCharacterY', 'setCharacterX', 'setCharacterY',
		'setCameraFollowPoint', 'cameraSetTarget', 'getCameraFollowX', 'getCameraFollowY', 'getSongPosition', 'setHealth', 'getHealth', 'addHealth',
		'setVar', 'getVar', 'close', 'makeLuaText', 'addLuaText', 'removeLuaText', 'luaTextExists', 'setTextString', 'setTextSize', 'setTextWidth',
		'setTextHeight', 'setTextAutoSize', 'setTextBorder', 'setTextColor', 'setTextFont', 'setTextItalic', 'setTextAlignment', 'getTextString',
		'getTextSize', 'getTextFont', 'getTextWidth', 'getPropertyFromClass', 'setPropertyFromClass', 'keyJustPressed', 'keyPressed', 'keyReleased',
		'soundFadeOut', 'soundFadeIn', 'stopSound', 'setSoundVolume', 'getColorFromHex', 'stringStartsWith', 'stringEndsWith', 'stringTrim',
		'characterDance', 'updateHitbox', 'getObjectOrder', 'addOffset', 'getPropertyFromGroup', 'setPropertyFromGroup'];

	/**
	 * Vortex Engine 0.7.2: Lua globals with these names would hide the Haxe class of the same name inside the converted
	 * script (a Lua "Std = {}" broke every Std.* call of the shim), so they are renamed.
	 */
	static final SHADOWED:Array<String> = ['Std', 'Math', 'Reflect', 'StringTools', 'Type', 'FlxG', 'FlxSprite', 'FlxText', 'FlxTextBorderStyle',
		'FlxTween', 'FlxEase', 'FlxTimer', 'PlayState', 'PlayStatePlaylist', 'Paths', 'Conductor', 'Preferences', 'FunkinSprite', 'FunkinSound',
		'StringMap', 'Date', 'Lambda', 'String', 'Array', 'Int', 'Float', 'Bool', 'Dynamic', 'ModuleHandler', 'Module', 'SongEvent', 'CharacterType',
		'CharacterDataParser', 'PlayerSettings', 'Sys', 'EReg'];

	/** Lua globals Psych defines, as HScript */
	static final GLOBALS:Map<String, String> = [
		'flashingLights' => 'Preferences.flashingLights', 'downscroll' => 'Preferences.downscroll', 'middlescroll' => 'false',
		'camGame' => "'game'", 'camHUD' => "'hud'", 'camOther' => "'other'", 'screenWidth' => 'FlxG.width', 'screenHeight' => 'FlxG.height', 'difficultyName' => "'Normal'",
		'songPosition' => 'Conductor.instance.songPosition', 'curBeat' => 'Conductor.instance.currentBeat', 'curStep' => 'Conductor.instance.currentStep',
		'curSection' => 'Math.floor(Conductor.instance.currentBeat / 4)', 'mustHitSection' => 'psychMustHit', 'gfSection' => 'psychGfSection', 'isStoryMode' => 'PlayStatePlaylist.isStoryMode', 'seenCutscene' => 'false',
		'Function_Stop' => "'##STOP'", 'Function_Continue' => "'##CONTINUE'", 'Function_StopLua' => "'##STOP'", 'Function_StopAll' => "'##STOP'",
		'botPlay' => 'PlayState.instance.isBotPlayMode', 'lowQuality' => 'false', 'shadersEnabled' => 'true', 'bpm' => 'Conductor.instance.bpm',
		'crochet' => 'Conductor.instance.beatLengthMs', 'stepCrochet' => 'Conductor.instance.stepLengthMs', 'songName' => 'PlayState.instance.currentSong.songName',
		'difficulty' => '0', 'buildTarget' => "'windows'", 'playbackRate' => '1', 'cameraSpeed' => '1', 'healthGainMult' => '1',
		'healthLossMult' => '1', 'guitarHeroSustains' => 'true', 'instakillOnMiss' => 'false', 'practice' => 'false',
		'startedCountdown' => 'true', 'inGameOver' => 'false', 'hideHud' => 'false', 'timeBarType' => "'Time Left'",
		'scoreZoom' => 'true', 'cameraZoomOnBeat' => 'true', 'framerate' => '60', 'ghostTapping' => 'true', 'version' => "'1.0.4'"
	];

	static final RESERVED:Array<String> = ['var', 'new', 'class', 'default', 'switch', 'case', 'cast', 'dynamic', 'override', 'static', 'public',
		'private', 'this', 'super', 'try', 'catch', 'throw', 'macro', 'package', 'import', 'typedef', 'enum', 'abstract', 'untyped', 'inline',
		'extends', 'implements', 'interface', 'using', 'trace', 'final', 'operator', 'extern', 'null', 'continue'];

	// ---------------------------------------------------------------- output
	public var unsupported:Array<String> = [];
	public var functions:Array<String> = []; // Lua functions the script defines (become class methods)
	public var fields:Array<String> = []; // globals the script uses (become class fields)
	public var error:String = null;

	var toks:Array<LTok>;
	var p:Int = 0;
	var locals:Array<Array<String>> = [];
	var tmp:Int = 0;
	var lastIndex:{obj:String, key:String, field:String} = null; // set when the last suffix was .x / [x] (for assignments)
	// Vortex Engine 0.7 (speed): generated expressions known to be a number / a Bool need no num() / truthy() wrapper.
	// V-Slice interprets scripts, and on phones every extra call per operation per frame adds up.
	var numeric:Map<String, Bool> = [];
	var booleans:Map<String, Bool> = [];
	// values that may be text in Psych (event / callback values arrive as strings): only these get num() in arithmetic
	var stringy:Map<String, Bool> = [];
	// "c and x" parts, so "c and x or y" becomes one c ? x : y
	var andParts:Map<String, Array<String>> = [];

	public function new() {}

	/**
	 * Translates a whole Lua file. Returns the class body (fields + methods), or null if the Lua could not be parsed
	 * (see `error`).
	 */
	public function translate(src:String):String
	{
		try
		{
			toks = tokenize(src);
			p = 0;
			// first pass: which names are functions
			for (i in 0...toks.length - 1)
				if (toks[i].k == 'name' && toks[i].v == 'function' && toks[i + 1].k == 'name' && !(i > 0 && toks[i - 1].v == 'local'))
					// Vortex Engine 0.7.2: "function t.f()" defines a field of the table t, not a function named t
					if (!(i + 2 < toks.length && toks[i + 2].k == 'sym' && (toks[i + 2].v == '.' || toks[i + 2].v == ':')))
						if (!functions.contains(toks[i + 1].v)) functions.push(toks[i + 1].v);
			var top:StringBuf = new StringBuf();
			var methods:StringBuf = new StringBuf();
			locals = [[]];
			while (!at('eof'))
			{
				if (isWord('function'))
				{
					p++;
					var name:String = name_();
					var parts:Array<String> = [name];
					while (isSym('.') || isSym(':')) { p++; parts.push(name_()); }
					name = parts.join('_');
					if (parts.length > 1)
					{
						// Vortex Engine 0.7.2: "function t.f()" puts the function into the table t when the script reaches it
						// (calls go through t.f(...)); the body is a class method like the other functions
						if (!isLocal(parts[0]) && !functions.contains(parts[0])) addField(parts[0]);
						var obj:String = nameRef(parts[0]);
						for (i in 1...parts.length - 1) obj += '.' + parts[i];
						top.add('\t\t{ var self = this; luaSet($obj, ${quote(parts[parts.length - 1])}, function(?a, ?b, ?c, ?d) { return self.${fn(name)}(a, b, c, d); }); }\n');
					}
					methods.add('\t' + funcBody(fn(name), 1) + '\n\n');
				}
				else if (isWord('local') && peekWord(1, 'function'))
				{
					p += 2;
					var name:String = name_();
					if (!functions.contains(name)) functions.push(name);
					methods.add('\t' + funcBody(fn(name), 1) + '\n\n');
				}
				else if (isWord('local'))
				{
					// a file-level local is a field of the class
					p++;
					var names:Array<String> = [name_()];
					while (isSym(',')) { p++; names.push(name_()); }
					var vals:Array<String> = [];
					if (isSym('=')) { p++; vals = explist(); }
					for (i in 0...names.length)
					{
						addField(names[i]);
						if (i < vals.length) top.add('\t\t' + safe(names[i]) + ' = ' + vals[i] + ';\n');
					}
				}
				else
				{
					var st:String = statement(2);
					if (st.length > 0) top.add(st);
				}
				if (isSym(';')) p++;
			}
			var out:StringBuf = new StringBuf();
			for (f in fields) out.add('\tvar ' + safe(f) + ':Dynamic = null;\n');
			out.add('\tvar luaInitDone:Bool = false;\n');
			out.add('\tfunction luaInit()\n\t{\n\t\tif (luaInitDone) return;\n\t\tluaInitDone = true;\n' + top.toString() + '\t}\n\n');
			out.add(methods.toString());
			return out.toString();
		}
		catch (e:Dynamic)
		{
			var where:String = (toks != null && p < toks.length) ? ' (line ${toks[p].line})' : '';
			error = Std.string(e) + where;
			return null;
		}
	}

	function addField(n:String) if (!fields.contains(n) && !functions.contains(n)) fields.push(n);

	// ---------------------------------------------------------------- statements
	function funcBody(name:String, indent:Int):String
	{
		expect('(');
		var args:Array<String> = [];
		while (!isSym(')'))
		{
			if (isSym('...')) { p++; args.push('rest'); }
			else args.push(name_());
			if (isSym(',')) p++;
		}
		expect(')');
		locals.push(args.copy());
		// Psych passes event values (onEvent value1 / value2, onTimerCompleted tag...) as text
		var oldStringy:Map<String, Bool> = stringy.copy();
		if (name == fn('onEvent') || name == fn('onEventPushed')) for (i in 1...args.length) stringy.set(safe(args[i]), true);
		var body:String = block(indent + 1, ['end']);
		stringy = oldStringy;
		expect('end');
		locals.pop();
		var tabs:String = ind(indent);
		// every method takes at least 4 (optional) arguments: callLua() passes 4, like Psych passes extra ones
		var padded:Array<String> = [for (a in args) '?' + safe(a)];
		while (padded.length < 4) padded.push('?_unused' + padded.length);
		var argList:String = padded.join(', ');
		return 'function $name($argList)\n$tabs{\n${ind(indent + 1)}if (!luaInitDone) luaInit();\n$body$tabs}';
	}

	function block(indent:Int, enders:Array<String>):String
	{
		var b:StringBuf = new StringBuf();
		while (!at('eof') && !(toks[p].k == 'name' && enders.contains(toks[p].v)))
		{
			b.add(statement(indent));
			if (isSym(';')) p++;
		}
		return b.toString();
	}

	function statement(indent:Int):String
	{
		var t:String = ind(indent);
		var tk:LTok = toks[p];
		if (isSym(';')) { p++; return ''; }
		if (tk.k == 'name')
		{
			switch (tk.v)
			{
				case 'local':
					p++;
					if (isWord('function'))
					{
						p++;
						var n:String = name_();
						declare(n);
						// a local function inside a function: a closure
						expect('(');
						var args:Array<String> = [];
						while (!isSym(')')) { args.push(name_()); if (isSym(',')) p++; }
						expect(')');
						locals.push(args.copy());
						var body:String = block(indent + 1, ['end']);
						expect('end');
						locals.pop();
						return '${t}var ${safe(n)} = function(${[for (a in args) '?' + safe(a)].join(', ')}) {\n$body$t};\n';
					}
					var names:Array<String> = [name_()];
					if (isSym('<')) { p++; name_(); expect('>'); } // Lua 5.4 attributes
					while (isSym(',')) { p++; names.push(name_()); }
					var vals:Array<String> = [];
					if (isSym('=')) { p++; vals = explist(); }
					var b:StringBuf = new StringBuf();
					for (i in 0...names.length)
					{
						declare(names[i]);
						if (i < vals.length && stringy.exists(vals[i])) stringy.set(safe(names[i]), true);
						b.add('${t}var ${safe(names[i])}:Dynamic = ' + (i < vals.length ? vals[i] : 'null') + ';\n');
					}
					return b.toString();
				case 'if':
					p++;
					var b:StringBuf = new StringBuf();
					b.add('${t}if (' + cond() + ')\n$t{\n');
					expect('then');
					locals.push([]);
					b.add(block(indent + 1, ['elseif', 'else', 'end']));
					locals.pop();
					b.add('$t}\n');
					while (isWord('elseif'))
					{
						p++;
						b.add('${t}else if (' + cond() + ')\n$t{\n');
						expect('then');
						locals.push([]);
						b.add(block(indent + 1, ['elseif', 'else', 'end']));
						locals.pop();
						b.add('$t}\n');
					}
					if (isWord('else'))
					{
						p++;
						b.add('${t}else\n$t{\n');
						locals.push([]);
						b.add(block(indent + 1, ['end']));
						locals.pop();
						b.add('$t}\n');
					}
					expect('end');
					return b.toString();
				case 'while':
					p++;
					var c:String = cond();
					expect('do');
					locals.push([]);
					var body:String = block(indent + 1, ['end']);
					locals.pop();
					expect('end');
					return '${t}while ($c)\n$t{\n$body$t}\n';
				case 'repeat':
					p++;
					locals.push([]);
					var body:String = block(indent + 1, ['until']);
					expect('until');
					var c:String = cond();
					locals.pop();
					return '${t}do\n$t{\n$body$t}\nwhile (!($c));\n';
				case 'for':
					p++;
					var v:String = name_();
					if (isSym('='))
					{
						p++;
						var a:String = expr(0);
						expect(',');
						var b2:String = expr(0);
						var step:String = '1';
						if (isSym(',')) { p++; step = expr(0); }
						expect('do');
						locals.push([v]);
						var body:String = block(indent + 1, ['end']);
						locals.pop();
						expect('end');
						var sv:String = safe(v);
						var st:String = n(step), lim:String = n(b2);
						var test:String = isNum(step) && !step.startsWith('-') ? '$sv <= $lim' : '($st >= 0) ? ($sv <= $lim) : ($sv >= $lim)';
						return '${t}var $sv:Float = ${n(a)};\n${t}while ($test)\n$t{\n$body${ind(indent + 1)}$sv += $st;\n$t}\n';
					}
					// for k, v in pairs / ipairs (t)
					var names:Array<String> = [v];
					while (isSym(',')) { p++; names.push(name_()); }
					expect('in');
					var src:String = expr(0);
					expect('do');
					locals.push(names);
					var body:String = block(indent + 1, ['end']);
					locals.pop();
					expect('end');
					var it:String = '_it' + (tmp++);
					var kv:String = names.length > 1 ? safe(names[1]) : '_v' + tmp;
					return '${t}var $it:Array<Dynamic> = luaPairs($src);\n${t}for (_e in $it)\n$t{\n${ind(indent + 1)}var ${safe(names[0])}:Dynamic = _e[0];\n${ind(indent + 1)}var $kv:Dynamic = _e[1];\n$body$t}\n';
				case 'do':
					p++;
					locals.push([]);
					var body:String = block(indent + 1, ['end']);
					locals.pop();
					expect('end');
					return '$t{\n$body$t}\n';
				case 'break':
					p++;
					return '${t}break;\n';
				case 'return':
					p++;
					if (at('eof') || isWord('end') || isWord('else') || isWord('elseif') || isWord('until') || isSym(';')) return '${t}return null;\n';
					var vals:Array<String> = explist();
					return '${t}return ' + vals[0] + ';\n';
				case 'goto':
					throw 'goto is not supported';
				case 'function':
					// a global function defined inside another function
					p++;
					var n:String = name_();
					expect('(');
					var args:Array<String> = [];
					while (!isSym(')')) { args.push(name_()); if (isSym(',')) p++; }
					expect(')');
					locals.push(args.copy());
					var body:String = block(indent + 1, ['end']);
					locals.pop();
					expect('end');
					addField(n);
					return '${t}${safe(n)} = function(${[for (a in args) '?' + safe(a)].join(', ')}) {\n$body$t};\n';
				default:
			}
		}
		// assignment or call
		var targets:Array<String> = [suffixedExp(true)];
		var indexes:Array<{obj:String, key:String, field:String}> = [lastIndex];
		while (isSym(',')) { p++; targets.push(suffixedExp(true)); indexes.push(lastIndex); }
		if (isSym('='))
		{
			p++;
			var vals:Array<String> = explist();
			var b:StringBuf = new StringBuf();
			for (i in 0...targets.length)
			{
				var v:String = i < vals.length ? vals[i] : 'null';
				if (indexes[i] != null && indexes[i].field != null) b.add('${t}${indexes[i].obj}.${indexes[i].field} = $v;\n');
				else if (indexes[i] != null) b.add('${t}luaSet(${indexes[i].obj}, ${indexes[i].key}, $v);\n');
				else b.add('$t${targets[i]} = $v;\n');
			}
			return b.toString();
		}
		if (targets.length > 1) throw 'unexpected ","';
		return '$t${targets[0]};\n';
	}

	function declare(n:String) locals[locals.length - 1].push(n);

	function isLocal(n:String):Bool
	{
		for (scope in locals) if (scope.contains(n)) return true;
		return false;
	}

	// ---------------------------------------------------------------- expressions
	function explist():Array<String>
	{
		var out:Array<String> = [expr(0)];
		while (isSym(',')) { p++; out.push(expr(0)); }
		return out;
	}

	/** an expression used as a condition (Lua truthiness: only nil and false are false) */
	function cond():String
		return condExpr(0);

	function condExpr(level:Int):String
	{
		// or / and / not keep their meaning as conditions
		var l:String = condAnd();
		while (isWord('or')) { p++; l = '($l || ${condAnd()})'; }
		return l;
	}

	function condAnd():String
	{
		var l:String = condNot();
		while (isWord('and')) { p++; l = '($l && ${condNot()})'; }
		return l;
	}

	function condNot():String
	{
		if (isWord('not')) { p++; return '!(' + condNot() + ')'; }
		var e:String = expr(3); // comparison and above
		return t(e);
	}

	static final BINARY:Map<String, Int> = ['or' => 1, 'and' => 2, '<' => 3, '>' => 3, '<=' => 3, '>=' => 3, '~=' => 3, '==' => 3,
		'..' => 5, '+' => 6, '-' => 6, '*' => 7, '/' => 7, '//' => 7, '%' => 7, '^' => 10];

	function opAt():String
	{
		var tk:LTok = toks[p];
		if ((tk.k == 'sym' || (tk.k == 'name' && (tk.v == 'and' || tk.v == 'or'))) && BINARY.exists(tk.v)) return tk.v;
		return null;
	}

	function expr(minPrec:Int):String
	{
		var left:String = unary();
		while (true)
		{
			var op:String = opAt();
			if (op == null) break;
			var prec:Int = BINARY.get(op);
			if (prec < minPrec) break;
			p++;
			// .. and ^ are right-associative
			var right:String = expr((op == '..' || op == '^') ? prec : prec + 1);
			left = binary(op, left, right);
		}
		return left;
	}

	/** never nil / false: a number, text, a table or a calculation */
	function surelyTruthy(code:String):Bool
		return isNum(code) || code.startsWith("'") || code.startsWith('{') || code.startsWith('[') || code == 'true';

	function isNum(code:String):Bool
		return numeric.exists(code) || ~/^-?[0-9][0-9.eE+-]*$/.match(code) || code.startsWith('0x');

	/**
	 * The value as a number. Vortex Engine 0.7 (speed): V-Slice interprets scripts, so a num() call on every operation
	 * every frame made converted scripts several times slower on phones. Lua turns text into numbers in arithmetic;
	 * in Psych scripts that only happens with values Psych passes as text (event values), so only those get num().
	 */
	function n(code:String):String
		return (stringy.exists(code) || code.startsWith("'")) ? 'num($code)' : code;

	/** a condition: Bool expressions as they are, anything else with Lua truthiness */
	function t(code:String):String
		return (booleans.exists(code) || code == 'true' || code == 'false') ? code : 'truthy($code)';

	function binary(op:String, a:String, b:String):String
	{
		var out:String = switch (op)
		{
			case 'or' if (andParts.exists(a) && surelyTruthy(andParts.get(a)[1])): '(${t(andParts.get(a)[0])} ? ${andParts.get(a)[1]} : $b)';
			case 'or': '(${t(a)} ? $a : $b)';
			case 'and': '(${t(a)} ? $b : $a)';
			case '..': 'cat($a, $b)';
			case '+' | '-' | '*' | '/': '(${n(a)} $op ${n(b)})';
			case '//': 'Math.floor(${n(a)} / ${n(b)})';
			case '%': 'luaMod($a, $b)';
			case '^': 'Math.pow(${n(a)}, ${n(b)})';
			case '~=': '($a != $b)';
			case '==': '($a == $b)';
			default: '(${n(a)} $op ${n(b)})'; // < > <= >=
		}
		if (op == 'and') andParts.set(out, [a, b]);
		switch (op)
		{
			case '+' | '-' | '*' | '/' | '//' | '%' | '^': numeric.set(out, true);
			case '~=' | '==' | '<' | '>' | '<=' | '>=': booleans.set(out, true);
			case 'or' | 'and': if (isNum(a) && isNum(b)) numeric.set(out, true); else if (booleans.exists(a) && booleans.exists(b)) booleans.set(out, true);
			default:
		}
		return out;
	}

	function unary():String
	{
		if (isWord('not')) { p++; var o:String = '!' + t(expr(8)); booleans.set(o, true); return o; }
		if (isSym('-')) { p++; var o:String = '(-' + n(expr(8)) + ')'; numeric.set(o, true); return o; }
		if (isSym('#')) { p++; var o:String = 'luaLen(' + expr(8) + ')'; numeric.set(o, true); return o; }
		return simple();
	}

	function simple():String
	{
		var tk:LTok = toks[p];
		switch (tk.k)
		{
			case 'num':
				p++;
				return tk.v;
			case 'str':
				p++;
				return quote(tk.v);
			default:
		}
		if (tk.k == 'name')
		{
			switch (tk.v)
			{
				case 'nil': p++; return 'null';
				case 'true': p++; return 'true';
				case 'false': p++; return 'false';
				case 'function':
					p++;
					expect('(');
					var args:Array<String> = [];
					while (!isSym(')')) { if (isSym('...')) { p++; args.push('rest'); } else args.push(name_()); if (isSym(',')) p++; }
					expect(')');
					locals.push(args.copy());
					var body:String = block(3, ['end']);
					locals.pop();
					expect('end');
					return 'function(${[for (a in args) '?' + safe(a)].join(', ')}) {\n$body}';
				default:
			}
		}
		if (isSym('{')) return table();
		if (isSym('...')) { p++; return 'rest'; }
		return suffixedExp(false);
	}

	function table():String
	{
		expect('{');
		var arr:Array<String> = [];
		var pairs:Array<String> = []; // [key, value] (keys can be numbers / any value in Lua)
		var named:Array<String> = []; // name: value (only plain names: those stay a fast object literal)
		while (!isSym('}'))
		{
			if (toks[p].k == 'name' && p + 1 < toks.length && toks[p + 1].k == 'sym' && toks[p + 1].v == '=')
			{
				var k:String = toks[p].v;
				p += 2;
				var v:String = expr(0);
				pairs.push('[' + quote(k) + ', ' + v + ']');
				if (!RESERVED.contains(k)) named.push('$k: $v');
			}
			else if (isSym('['))
			{
				p++;
				var k:String = expr(0);
				expect(']');
				expect('=');
				pairs.push('[$k, ' + expr(0) + ']');
			}
			else arr.push(expr(0));
			if (isSym(',') || isSym(';')) p++;
		}
		expect('}');
		// an empty {} can become a list or a dictionary later: an object holds both (number keys through Reflect)
		if (pairs.length == 0 && arr.length == 0) return '{}';
		// only plain names: an object literal (t.name is a direct field read, the fastest V-Slice scripts have)
		if (pairs.length > 0 && named.length == pairs.length && arr.length == 0) return '{' + named.join(', ') + '}';
		if (pairs.length > 0)
		{
			// other keys (numbers, expressions): an object with the keys as text
			for (i in 0...arr.length) pairs.push('[${i + 1}, ${arr[i]}]');
			return 'luaTable([' + pairs.join(', ') + '])';
		}
		return '[' + arr.join(', ') + ']';
	}

	/** name / (expr) followed by .x [x] :m() () "str" {t} */
	function suffixedExp(statementStart:Bool):String
	{
		var base:String;
		var baseName:String = null;
		if (isSym('('))
		{
			p++;
			base = '(' + expr(0) + ')';
			expect(')');
		}
		else
		{
			baseName = name_();
			base = null;
		}
		// dotted names for library calls: math.floor, string.lower, os.time
		var path:Array<String> = baseName != null ? [baseName] : [];
		while (baseName != null && isSym('.') && p + 1 < toks.length && toks[p + 1].k == 'name' && !isLocal(baseName) && (baseName == 'math' || baseName == 'string' || baseName == 'os' || baseName == 'table' || baseName == 'io'))
		{
			p++;
			path.push(name_());
		}
		var calledDirectly:Bool = baseName != null && path.length == 1 && (isSym('(') || toks[p].k == 'str' || isSym('{'))
			&& !isLocal(baseName) && !fields.contains(baseName);
		if (base == null) base = (path.length > 1) ? path.join('.') : (calledDirectly ? safe(baseName) : nameRef(baseName));
		if (path.length > 1 && !(isSym('(') || toks[p].k == 'str' || isSym('{')))
			switch (base)
			{
				case 'math.pi': base = 'Math.PI'; numeric.set(base, true);
				case 'math.huge': base = 'Math.POSITIVE_INFINITY'; numeric.set(base, true);
				default:
			}
		var isLibrary:Bool = path.length > 1;
		var last:{obj:String, key:String, field:String} = null; // only kept if .x / [x] is the very last suffix
		while (true)
		{
			if (isSym('.'))
			{
				p++;
				var name:String = name_();
				var k:String = quote(name);
				// Vortex Engine 0.7 (speed): t.name is a plain field (V-Slice interprets every reflection call slowly)
				if (!RESERVED.contains(name))
				{
					last = {obj: base, key: null, field: name};
					base = '$base.$name';
				}
				else
				{
					last = {obj: base, key: k, field: null};
					base = 'luaGet($base, $k)';
				}
			}
			else if (isSym('['))
			{
				p++;
				var k:String = expr(0);
				expect(']');
				last = {obj: base, key: k, field: null};
				base = 'luaGet($base, $k)';
			}
			else if (isSym(':'))
			{
				p++;
				last = null;
				var m:String = name_();
				var args:Array<String> = callArgs();
				base = method(base, m, args);
			}
			else if (isSym('(') || toks[p].k == 'str' || isSym('{'))
			{
				last = null;
				var args:Array<String> = callArgs();
				base = call(isLibrary ? path.join('.') : (baseName != null && (calledDirectly || base == nameRef(baseName)) ? baseName : null), base, args);
				calledDirectly = false;
				isLibrary = false;
				baseName = null;
			}
			else break;
		}
		lastIndex = last; // statement() turns "a.b = v" into luaSet(a, 'b', v)
		return base;
	}

	function callArgs():Array<String>
	{
		if (toks[p].k == 'str') { var s:String = quote(toks[p].v); p++; return [s]; }
		if (isSym('{')) return [table()];
		expect('(');
		var args:Array<String> = [];
		while (!isSym(')'))
		{
			args.push(expr(0));
			if (isSym(',')) p++;
			else if (!isSym(')')) throw 'expected , or )';
		}
		expect(')');
		return args;
	}

	function nameRef(n:String):String
	{
		if (isLocal(n)) return safe(n);
		if (stringy.exists(safe(n))) return safe(n);
		if (GLOBALS.exists(n)) return GLOBALS.get(n);
		if (functions.contains(n)) return fn(n);
		if (SHIM_FUNCTIONS.contains(n)) return n;
		addField(n);
		return safe(n);
	}

	function call(name:String, base:String, args:Array<String>):String
	{
		var a:String = args.join(', ');
		if (name == null) return '$base($a)';
		switch (name)
		{
			case 'print': return 'trace($a)';
			case 'type': return 'luaType($a)';
			case 'pairs' | 'ipairs': return 'luaPairs($a)';
			case 'math.floor': return 'Math.floor(num($a))';
			case 'math.ceil': return 'Math.ceil(num($a))';
			case 'math.abs': return 'Math.abs(num($a))';
			case 'math.sqrt': return 'Math.sqrt(num($a))';
			case 'math.sin': return 'Math.sin(num($a))';
			case 'math.cos': return 'Math.cos(num($a))';
			case 'math.min': return 'Math.min(num(${args[0]}), num(${args[1]}))';
			case 'math.max': return 'Math.max(num(${args[0]}), num(${args[1]}))';
			case 'math.random': return 'luaRandom($a)';
			case 'math.pi': return 'Math.PI';
			case 'math.exp': return 'Math.exp(${n(args[0])})';
			case 'math.log': return args.length > 1 ? '(Math.log(${n(args[0])}) / Math.log(${n(args[1])}))' : 'Math.log(${n(args[0])})';
			case 'math.pow': return 'Math.pow(${n(args[0])}, ${n(args[1])})';
			case 'math.fmod': return 'luaMod(${args[0]}, ${args[1]})';
			case 'math.tan': return 'Math.tan(${n(args[0])})';
			case 'math.atan': return args.length > 1 ? 'Math.atan2(${n(args[0])}, ${n(args[1])})' : 'Math.atan(${n(args[0])})';
			case 'math.asin': return 'Math.asin(${n(args[0])})';
			case 'math.acos': return 'Math.acos(${n(args[0])})';
			case 'math.rad': return '(${n(args[0])} * Math.PI / 180)';
			case 'math.deg': return '(${n(args[0])} * 180 / Math.PI)';
			case 'math.modf': return 'Math.ffloor(${n(args[0])})';
			case 'string.lower': return 'Std.string(${args[0]}).toLowerCase()';
			case 'string.upper': return 'Std.string(${args[0]}).toUpperCase()';
			case 'string.len': return 'Std.string(${args[0]}).length';
			case 'string.sub': return 'luaSub($a)';
			case 'string.find': return 'luaFind($a)';
			case 'string.format': return 'luaFormat($a)';
			case 'string.rep': return 'StringTools.lpad(\'\', Std.string(${args[0]}), Std.string(${args[0]}).length * Std.int(num(${args[1]})))';
			case 'os.time' | 'os.clock': return 'Date.now().getTime() / 1000';
			case 'table.insert': return 'luaInsert($a)';
			case 'table.remove': return 'luaRemove($a)';
			case 'table.concat': return 'luaConcat($a)';
			case 'table.unpack' | 'unpack': return '${args[0]}';
			default:
		}
		if (isLocal(name)) return '${safe(name)}($a)';
		if (functions.contains(name)) return '${fn(name)}($a)';
		if (SHIM_FUNCTIONS.contains(name)) return '$name($a)';
		if (fields.contains(name)) return '${safe(name)}($a)'; // a function stored in a global
		if (!unsupported.contains(name)) unsupported.push(name);
		return 'unsupportedCall(${quote(name)})';
	}

	function method(obj:String, m:String, args:Array<String>):String
	{
		switch (m)
		{
			case 'lower': return 'Std.string($obj).toLowerCase()';
			case 'upper': return 'Std.string($obj).toUpperCase()';
			case 'len': return 'Std.string($obj).length';
			case 'sub': return 'luaSub($obj' + (args.length > 0 ? ', ' + args.join(', ') : '') + ')';
			case 'find': return 'luaFind($obj' + (args.length > 0 ? ', ' + args.join(', ') : '') + ')';
			default:
		}
		var n:String = ':' + m;
		if (!unsupported.contains(n)) unsupported.push(n);
		return 'unsupportedCall(${quote(n)})';
	}

	// ---------------------------------------------------------------- tokens
	function at(k:String):Bool return toks[p].k == k;
	function isSym(v:String):Bool return toks[p].k == 'sym' && toks[p].v == v;
	function isWord(v:String):Bool return toks[p].k == 'name' && toks[p].v == v;
	function peekWord(o:Int, v:String):Bool return p + o < toks.length && toks[p + o].k == 'name' && toks[p + o].v == v;

	function expect(v:String)
	{
		if (toks[p].v != v || toks[p].k == 'str') throw 'expected "$v" but found "${toks[p].v}"';
		p++;
	}

	function name_():String
	{
		if (toks[p].k != 'name') throw 'expected a name but found "${toks[p].v}"';
		return toks[p++].v;
	}

	/**
	 * The method name of a Lua function: "lua_" + its name. V-Slice classes have methods with Psych's callback names
	 * (onUpdate, onBeatHit, onSongStart...), and a script method with the same name is a "Duplicate field".
	 */
	public static function fn(n:String):String
		return 'lua_' + n;

	static function safe(n:String):String
		return (RESERVED.contains(n) || SHADOWED.contains(n)) ? 'l_' + n : n;

	static function ind(n:Int):String
		return StringTools.lpad('', '\t', n);

	static function quote(s:String):String
	{
		var b:StringBuf = new StringBuf();
		b.add("'");
		for (i in 0...s.length)
		{
			var c:String = s.charAt(i);
			switch (c)
			{
				case "'": b.add("\\'");
				case '\\': b.add('\\\\');
				case '\n': b.add('\\n');
				case '\r': b.add('\\r');
				case '\t': b.add('\\t');
				case '$': b.add('$$'); // no string interpolation
				default: b.add(c);
			}
		}
		b.add("'");
		return b.toString();
	}

	static function tokenize(src:String):Array<LTok>
	{
		var out:Array<LTok> = [];
		var i:Int = 0, n:Int = src.length, line:Int = 1;
		inline function isDigit(c:String) return c >= '0' && c <= '9';
		inline function isId(c:String) return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || isDigit(c);
		function longBracket(at:Int):Int // [[ / [==[ : returns the level or -1
		{
			if (src.charAt(at) != '[') return -1;
			var j:Int = at + 1, lvl:Int = 0;
			while (j < n && src.charAt(j) == '=') { j++; lvl++; }
			return (j < n && src.charAt(j) == '[') ? lvl : -1;
		}
		function readLong(at:Int, lvl:Int):{text:String, end:Int}
		{
			var open:Int = at + lvl + 2;
			var close:String = ']' + StringTools.lpad('', '=', lvl) + ']';
			var e:Int = src.indexOf(close, open);
			if (e < 0) e = n;
			var text:String = src.substring(open, e);
			if (text.startsWith('\n')) text = text.substr(1);
			return {text: text, end: e + close.length};
		}
		while (i < n)
		{
			var c:String = src.charAt(i);
			if (c == '\n') { line++; i++; continue; }
			if (c == ' ' || c == '\t' || c == '\r') { i++; continue; }
			if (c == '-' && src.charAt(i + 1) == '-')
			{
				var lvl:Int = longBracket(i + 2);
				if (lvl >= 0) { var r = readLong(i + 2, lvl); for (ch in 0...r.text.length) if (r.text.charAt(ch) == '\n') line++; i = r.end; }
				else { while (i < n && src.charAt(i) != '\n') i++; }
				continue;
			}
			if (c == '"' || c == "'")
			{
				var b:StringBuf = new StringBuf();
				i++;
				while (i < n && src.charAt(i) != c)
				{
					var ch:String = src.charAt(i);
					if (ch == '\\' && i + 1 < n)
					{
						i++;
						var e:String = src.charAt(i);
						switch (e)
						{
							case 'n': b.add('\n');
							case 't': b.add('\t');
							case 'r': b.add('\r');
							default: b.add(e);
						}
					}
					else b.add(ch);
					i++;
				}
				i++;
				out.push({k: 'str', v: b.toString(), line: line});
				continue;
			}
			var lvl:Int = longBracket(i);
			if (lvl >= 0)
			{
				var r = readLong(i, lvl);
				out.push({k: 'str', v: r.text, line: line});
				i = r.end;
				continue;
			}
			if (isDigit(c) || (c == '.' && isDigit(src.charAt(i + 1))))
			{
				var s:Int = i;
				if (c == '0' && (src.charAt(i + 1) == 'x' || src.charAt(i + 1) == 'X')) { i += 2; while (i < n && isId(src.charAt(i))) i++; }
				else
				{
					while (i < n && (isDigit(src.charAt(i)) || src.charAt(i) == '.')) i++;
					if (i < n && (src.charAt(i) == 'e' || src.charAt(i) == 'E')) { i++; if (src.charAt(i) == '-' || src.charAt(i) == '+') i++; while (i < n && isDigit(src.charAt(i))) i++; }
				}
				var numText:String = src.substring(s, i);
				if (numText.startsWith('.')) numText = '0' + numText; // .5 is Lua, 0.5 is Haxe
				if (numText.endsWith('.')) numText += '0';
				out.push({k: 'num', v: numText, line: line});
				continue;
			}
			if (isId(c))
			{
				var s:Int = i;
				while (i < n && isId(src.charAt(i))) i++;
				out.push({k: 'name', v: src.substring(s, i), line: line});
				continue;
			}
			var three:String = src.substr(i, 3);
			if (three == '...') { out.push({k: 'sym', v: three, line: line}); i += 3; continue; }
			var two:String = src.substr(i, 2);
			if (['==', '~=', '<=', '>=', '..', '//', '::'].contains(two)) { out.push({k: 'sym', v: two, line: line}); i += 2; continue; }
			out.push({k: 'sym', v: c, line: line});
			i++;
		}
		out.push({k: 'eof', v: '<end of file>', line: line});
		return out;
	}

	// ---------------------------------------------------------------- the Psych API in V-Slice terms
	/**
	 * Helper methods added to every translated class. They do what Psych's Lua functions do, using V-Slice classes.
	 * "luaGet(a, 'b')" on the left of "=" is rewritten to luaSet by fixAssignments().
	 */
	public static final SHIM:String = "
	// ---- Psych Lua API for V-Slice (made by the Vortex Engine V-Slice Converter)
	// StringMap: V-Slice scripts can't use Haxe's Map
	var luaSprites:Dynamic = new StringMap();
	var luaTimers:Dynamic = new StringMap();
	var luaTweens:Dynamic = new StringMap();
	var luaVars:Dynamic = new StringMap();

	function truthy(v:Dynamic):Bool return v != null && v != false;
	function num(v:Dynamic):Float
	{
		if (v == null) return 0;
		if (Std.isOfType(v, String)) { var f = Std.parseFloat(v); return Math.isNaN(f) ? 0 : f; }
		if (v == true) return 1;
		if (v == false) return 0;
		return v;
	}
	function cat(a:Dynamic, b:Dynamic):String return luaStr(a) + luaStr(b);
	function luaStr(v:Dynamic):String
	{
		if (v == null) return 'nil';
		if (Std.isOfType(v, Float) && Math.floor(v) == v && Math.abs(v) < 1e15) return Std.string(Std.int(v));
		return Std.string(v);
	}
	function tostring(v:Dynamic):String return luaStr(v);
	function tonumber(v:Dynamic, ?b:Dynamic):Dynamic
	{
		if (v == null) return null;
		if (Std.isOfType(v, String))
		{
			var s:String = StringTools.trim(v);
			if (s.length == 0) return null;
			var f = Std.parseFloat(s);
			return Math.isNaN(f) ? null : f;
		}
		return v;
	}
	function luaMod(a:Dynamic, b:Dynamic):Float { var x = num(a), y = num(b); return x - Math.floor(x / y) * y; }
	function luaLen(v:Dynamic):Int
	{
		if (v == null) return 0;
		if (Std.isOfType(v, String)) return v.length;
		if (Std.isOfType(v, Array)) return v.length;
		// a Lua table as an object: count 1, 2, 3... like Lua's # does
		var n:Int = 0;
		while (luaGet(v, n + 1) != null) n++;
		return n;
	}
	function luaInsert(t:Dynamic, a:Dynamic, ?b:Dynamic)
	{
		if (t == null) return;
		if (Std.isOfType(t, Array)) { if (b == null) t.push(a); else t.insert(Std.int(num(a)) - 1, b); return; }
		var len:Int = luaLen(t);
		if (b == null) { luaSet(t, len + 1, a); return; }
		var pos:Int = Std.int(num(a));
		var i:Int = len;
		while (i >= pos) { luaSet(t, i + 1, luaGet(t, i)); i--; }
		luaSet(t, pos, b);
	}
	function luaRemove(t:Dynamic, ?pos:Dynamic):Dynamic
	{
		if (t == null) return null;
		if (Std.isOfType(t, Array)) return (pos == null) ? t.pop() : t.splice(Std.int(num(pos)) - 1, 1)[0];
		var len:Int = luaLen(t);
		if (len == 0) return null;
		var at:Int = (pos == null) ? len : Std.int(num(pos));
		var v = luaGet(t, at);
		var i:Int = at;
		while (i < len) { luaSet(t, i, luaGet(t, i + 1)); i++; }
		luaSet(t, len, null);
		return v;
	}
	function luaConcat(t:Dynamic, ?sep:Dynamic):String
	{
		var parts:Array<String> = [];
		for (e in luaPairs(t)) if (Std.isOfType(e[0], Float) || Std.isOfType(e[0], Int)) parts.push(luaStr(e[1]));
		return parts.join(sep == null ? '' : Std.string(sep));
	}
	function luaSub(s:Dynamic, i:Dynamic, ?j:Dynamic):String
	{
		var str:String = Std.string(s);
		var a:Int = Std.int(num(i)), b:Int = (j == null) ? str.length : Std.int(num(j));
		if (a < 0) a = str.length + a + 1;
		if (b < 0) b = str.length + b + 1;
		if (a < 1) a = 1;
		if (b > str.length) b = str.length;
		return (b < a) ? '' : str.substring(a - 1, b);
	}
	/** string.find with a plain search (Lua patterns other than plain text are rare in FNF scripts) */
	function luaFind(s:Dynamic, what:Dynamic, ?start:Dynamic, ?plain:Dynamic):Dynamic
	{
		if (s == null || what == null) return null;
		var i:Int = Std.string(s).indexOf(Std.string(what), start == null ? 0 : Std.int(num(start)) - 1);
		return i < 0 ? null : i + 1;
	}
	function luaFormat(f:Dynamic, ?a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic):String
	{
		var out:String = Std.string(f);
		for (v in [a, b, c, d]) { var i = out.indexOf('%'); if (i < 0 || v == null) break; out = out.substr(0, i) + luaStr(v) + out.substr(i + 2); }
		return out;
	}
	var psychMustHit:Bool = false;
	var psychGfSection:Bool = false;
	function luaType(v:Dynamic):String
	{
		if (v == null) return 'nil';
		if (Std.isOfType(v, String)) return 'string';
		if (Std.isOfType(v, Bool)) return 'boolean';
		if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) return 'number';
		if (Reflect.isFunction(v)) return 'function';
		return 'table';
	}
	function luaRandom(?a:Dynamic, ?b:Dynamic):Float
	{
		if (a == null) return Math.random();
		if (b == null) return FlxG.random.int(1, Std.int(num(a)));
		return FlxG.random.int(Std.int(num(a)), Std.int(num(b)));
	}
	function luaPairs(t:Dynamic):Array<Dynamic>
	{
		var out:Array<Dynamic> = [];
		if (t == null) return out;
		if (Std.isOfType(t, Array)) { for (i in 0...t.length) out.push([i + 1, t[i]]); return out; }
		if (Std.isOfType(t, StringMap)) { for (k in t.keys()) out.push([tonumber(k) != null ? tonumber(k) : k, t.get(k)]); return out; }
		// numbered entries first, in order (ipairs), then the named ones
		var n:Int = 1;
		while (luaGet(t, n) != null) { out.push([n, luaGet(t, n)]); n++; }
		for (f in Reflect.fields(t)) { var k = tonumber(f); if (k == null || k < 1 || k >= n || k != Math.floor(k)) out.push([k != null ? k : f, Reflect.field(t, f)]); }
		return out;
	}
	function luaTable(pairs:Array<Dynamic>):Dynamic
	{
		var o:Dynamic = {};
		for (p in pairs) Reflect.setField(o, luaStr(p[0]), p[1]);
		return o;
	}
	function luaGet(o:Dynamic, k:Dynamic):Dynamic
	{
		if (o == null) return null;
		if (Std.isOfType(o, Array)) return o[Std.int(num(k)) - 1];
		if (Std.isOfType(o, StringMap)) return o.get(luaStr(k));
		return Reflect.getProperty(o, luaStr(k));
	}
	function luaSet(o:Dynamic, k:Dynamic, v:Dynamic)
	{
		if (o == null) return;
		if (Std.isOfType(o, Array)) { o[Std.int(num(k)) - 1] = v; return; }
		if (Std.isOfType(o, StringMap)) { o.set(luaStr(k), v); return; }
		Reflect.setProperty(o, luaStr(k), v);
	}
	var luaWarned:Dynamic = null;
	function unsupportedCall(name:String):Dynamic
	{
		if (luaWarned == null) luaWarned = new StringMap();
		if (!luaWarned.exists(name)) { luaWarned.set(name, true); trace('[Psych Lua] ' + name + ' is not available in V-Slice (converted script)'); }
		return null;
	}
	function debugPrint(?a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic, ?e:Dynamic)
	{
		var parts = [];
		for (x in [a, b, c, d, e]) if (x != null) parts.push(luaStr(x));
		trace(parts.join(''));
	}
	function close(?a:Dynamic) {}
	function setVar(n:String, v:Dynamic) luaVars.set(n, v);
	function getVar(n:String):Dynamic return luaVars.get(n);

	function luaCamera(c:Dynamic):Dynamic
	{
		var s:String = (c == null) ? 'game' : Std.string(c).toLowerCase();
		var ps = PlayState.instance;
		if (ps == null) return FlxG.camera;
		if (s == 'hud' || s == 'camhud') return ps.camHUD;
		if (s == 'other' || s == 'camother') return ps.camCutscene;
		return ps.camGame;
	}
	function luaColor(c:Dynamic):Int
	{
		if (c == null) return 0xFFFFFFFF;
		if (!Std.isOfType(c, String)) return Std.int(c);
		var s:String = StringTools.trim(c);
		if (StringTools.startsWith(s, '#')) s = s.substr(1);
		if (StringTools.startsWith(s, '0x') || StringTools.startsWith(s, '0X')) s = s.substr(2);
		if (s.length <= 6) s = 'FF' + StringTools.lpad(s, '0', 6);
		var v:Null<Int> = Std.parseInt('0x' + s);
		return v == null ? 0xFFFFFFFF : v;
	}
	function luaEase(name:Dynamic):Dynamic
	{
		var n:String = (name == null) ? 'linear' : Std.string(name);
		var f = Reflect.field(FlxEase, n);
		if (f == null) f = Reflect.field(FlxEase, n.charAt(0).toLowerCase() + n.substr(1));
		return f != null ? f : FlxEase.linear;
	}
	/** 'boyfriend.x', 'dad', 'camGame.zoom', a Lua sprite tag... */
	function luaObject(path:String):Dynamic
	{
		var ps = PlayState.instance;
		var parts:Array<String> = path.split('.');
		var o:Dynamic = luaRoot(parts[0]);
		for (i in 1...parts.length) { if (o == null) return null; o = Reflect.getProperty(o, parts[i]); }
		return o;
	}
	function luaRoot(n:String):Dynamic
	{
		if (luaSprites.exists(n)) return luaSprites.get(n);
		var ps = PlayState.instance;
		if (ps == null) return null;
		var st = ps.currentStage;
		switch (n)
		{
			// Vortex Engine 0.7.2: Psych's character groups are the characters themselves in V-Slice (setObjectOrder next to them)
			case 'boyfriend' | 'bf' | 'boyfriendGroup': return st != null ? st.getBoyfriend() : null;
			case 'dad' | 'dadGroup': return st != null ? st.getDad() : null;
			case 'gf' | 'girlfriend' | 'gfGroup': return st != null ? st.getGirlfriend() : null;
			case 'camGame': return ps.camGame;
			case 'camHUD': return ps.camHUD;
			case 'camOther': return ps.camCutscene;
			case 'camFollow': return ps.cameraFollowPoint;
			case 'healthBar': return ps.healthBar;
			case 'iconP1': return ps.iconP1;
			case 'iconP2': return ps.iconP2;
			case 'game': return ps;
			default:
		}
		if (st != null) { var prop = st.getNamedProp(n); if (prop != null) return prop; }
		return Reflect.getProperty(ps, n);
	}
	/**
	 * Psych and V-Slice measure a character's x / y from different points (top-left vs feet), so the converter lists, per
	 * character, what to add to V-Slice's x / y to get Psych's, and Psych's hitbox size: [dx, dy, width, height].
	 */
	var psychShifts:Dynamic = null;
	function psychShift(c:Dynamic):Array<Dynamic>
	{
		if (psychShifts == null)
		{
			psychShifts = new StringMap();
%PSYCH_SHIFTS%
		}
		var id:String = (c == null) ? null : Reflect.field(c, 'characterId');
		return (id != null && psychShifts.exists(id)) ? psychShifts.get(id) : null;
	}
	function isCharacterName(n:String):Bool return n == 'boyfriend' || n == 'bf' || n == 'dad' || n == 'gf' || n == 'girlfriend';
	function getProperty(path:String):Dynamic
	{
		// 'name[0]': read the field, then the index
		var idx:Int = -1;
		var br:Int = path.lastIndexOf('[');
		if (br > 0 && StringTools.endsWith(path, ']'))
		{
			idx = Std.parseInt(path.substring(br + 1, path.length - 1));
			var arr = getProperty(path.substr(0, br));
			return (arr == null || idx == null) ? null : arr[idx];
		}
		switch (path)
		{
			case 'cameraSpeed' | 'playbackRate' | 'healthGain' | 'healthLoss': return 1;
			case 'camGame.zoom': return PlayState.instance.camGame.zoom;
			case 'camGame.angle': return PlayState.instance.camGame.angle;
			case 'camHUD.zoom': return PlayState.instance.camHUD.zoom;
			case 'camGame.targetOffset.x': return PlayState.instance.camGame.targetOffset.x;
			case 'camGame.targetOffset.y': return PlayState.instance.camGame.targetOffset.y;
			default:
		}
		var stageId:String = (PlayState.instance != null && PlayState.instance.currentStage != null) ? PlayState.instance.currentStage.id : '';
		switch (path)
		{
			case 'boyfriendCameraOffset': var v = psychCam('stage:' + stageId + ':bf'); return v != null ? v : [0, 0];
			case 'opponentCameraOffset': var v = psychCam('stage:' + stageId + ':dad'); return v != null ? v : [0, 0];
			case 'girlfriendCameraOffset': var v = psychCam('stage:' + stageId + ':gf'); return v != null ? v : [0, 0];
			case 'isCameraOnForcedPos': var m = ModuleHandler.getModule('%CAMERA_MODULE%'); return m != null && m.scriptGet('locked') == true;
			case 'camFollow.x': return PlayState.instance.cameraFollowPoint.x;
			case 'camFollow.y': return PlayState.instance.cameraFollowPoint.y;
			default:
		}
		var parts:Array<String> = path.split('.');
		if (parts.length == 2 && isCharacterName(parts[0]) && parts[1] == 'cameraPosition')
		{
			var c = luaRoot(parts[0]);
			var v = c != null ? psychCam('char:' + Reflect.field(c, 'characterId')) : null;
			return v != null ? v : [0, 0];
		}
		if (parts.length == 2 && isCharacterName(parts[0]))
		{
			var c = luaRoot(parts[0]);
			var sh = psychShift(c);
			if (c != null && sh != null)
				switch (parts[1])
				{
					case 'x': return c.x + sh[0];
					case 'y': return c.y + sh[1];
					case 'width': return sh[2];
					case 'height': return sh[3];
					default:
				}
		}
		switch (path)
		{
			case 'defaultCamZoom': return PlayState.instance.currentCameraZoom;
			case 'camGame.zoom': return PlayState.instance.camGame.zoom;
			case 'health': return PlayState.instance.health;
			case 'inCutscene': return PlayState.instance.isInCutscene;
			default:
		}
		return luaObject(path);
	}
	function setProperty(path:String, value:Dynamic)
	{
		var ps = PlayState.instance;
		if (ps == null) return;
		switch (path)
		{
			case 'defaultCamZoom': ps.currentCameraZoom = num(value); return;
			case 'camFollow.x': ps.cameraFollowPoint.x = num(value); return;
			case 'camGame.targetOffset.x': ps.camGame.targetOffset.x = num(value); return;
			case 'camGame.targetOffset.y': ps.camGame.targetOffset.y = num(value); return;
			case 'camGame.angle': ps.camGame.angle = num(value); return;
			case 'camHUD.zoom': ps.camHUD.zoom = num(value); return;
			case 'camHUD.angle': ps.camHUD.angle = num(value); return;
			case 'camFollow.y': ps.cameraFollowPoint.y = num(value); return;
			// Psych's camGame.zoom is the live zoom, eased back to defaultCamZoom every frame: in V-Slice that is the
			// camera bop multiplier (also eased back to 1), not the base zoom
			case 'camGame.zoom': ps.cameraBopMultiplier = num(value) / Math.max(0.0001, ps.currentCameraZoom); return;
			case 'health': ps.health = num(value); return;
			case 'inCutscene': ps.isInCutscene = truthy(value); return;
			default:
		}
		var parts:Array<String> = path.split('.');
		if (parts.length == 2 && isCharacterName(parts[0]) && (parts[1] == 'x' || parts[1] == 'y'))
		{
			var c = luaRoot(parts[0]);
			var sh = psychShift(c);
			if (c != null && sh != null)
			{
				if (parts[1] == 'x') c.x = num(value) - sh[0];
				else c.y = num(value) - sh[1];
				return;
			}
		}
		var field:String = parts.pop();
		var o:Dynamic = parts.length > 0 ? luaObject(parts.join('.')) : ps;
		if (o == null) return;
		if (Std.isOfType(value, String))
		{
			var s:String = value;
			if (s == 'true') value = true;
			else if (s == 'false') value = false;
			else if (!Math.isNaN(Std.parseFloat(s))) value = Std.parseFloat(s);
		}
		Reflect.setProperty(o, field, value);
	}
	function setPropertyText(path:String, value:Dynamic) setProperty(path, value);

	function cameraFlash(cam:Dynamic, color:Dynamic, duration:Dynamic, ?forced:Dynamic)
	{
		if (!Preferences.flashingLights && forced != true) return;
		luaCamera(cam).flash(luaColor(color), num(duration), null, true);
	}
	function cameraShake(cam:Dynamic, intensity:Dynamic, duration:Dynamic)
		luaCamera(cam).shake(num(intensity), num(duration));
	function cameraFade(cam:Dynamic, color:Dynamic, duration:Dynamic, ?forced:Dynamic, ?fadeOut:Dynamic)
		luaCamera(cam).fade(luaColor(color), num(duration), fadeOut == true, null, true);
	function doTweenZoom(tag:String, cam:Dynamic, zoom:Dynamic, duration:Dynamic, ?ease:Dynamic)
	{
		var c = luaCamera(cam);
		if (c == PlayState.instance.camGame)
		{
			// Psych keeps easing the game camera back to defaultCamZoom, so a zoom tween only lasts while it runs
			var ps = PlayState.instance;
			var back:Float = ps.currentCameraZoom;
			ps.tweenCameraZoom(num(zoom), num(duration), true, luaEase(ease));
			new FlxTimer().start(Math.max(0.01, num(duration)), function(t) {
				if (PlayState.instance == ps) ps.tweenCameraZoom(back, 0.8, true, FlxEase.expoOut);
			});
		}
		else luaTween(tag, c, {zoom: num(zoom)}, duration, ease);
	}
	function luaTween(tag:String, o:Dynamic, values:Dynamic, duration:Dynamic, ease:Dynamic)
	{
		if (o == null) return;
		cancelTween(tag);
		var self = this;
		luaTweens.set(tag, FlxTween.tween(o, values, num(duration), {ease: luaEase(ease), onComplete: function(t) {
			self.luaTweens.remove(tag);
			self.callLua('onTweenCompleted', [tag]);
		}}));
	}
	function doTweenAlpha(tag:String, obj:String, value:Dynamic, duration:Dynamic, ?ease:Dynamic) luaTween(tag, luaObject(obj), {alpha: num(value)}, duration, ease);
	function doTweenX(tag:String, obj:String, value:Dynamic, duration:Dynamic, ?ease:Dynamic) luaTween(tag, luaObject(obj), {x: num(value)}, duration, ease);
	function doTweenY(tag:String, obj:String, value:Dynamic, duration:Dynamic, ?ease:Dynamic) luaTween(tag, luaObject(obj), {y: num(value)}, duration, ease);
	function doTweenAngle(tag:String, obj:String, value:Dynamic, duration:Dynamic, ?ease:Dynamic) luaTween(tag, luaObject(obj), {angle: num(value)}, duration, ease);
	function doTweenColor(tag:String, obj:String, color:Dynamic, duration:Dynamic, ?ease:Dynamic)
	{
		var o = luaObject(obj);
		if (o != null) o.color = luaColor(color);
	}
	function cancelTween(tag:String)
	{
		if (luaTweens.exists(tag)) { luaTweens.get(tag).cancel(); luaTweens.remove(tag); }
	}
	function runTimer(tag:String, ?time:Dynamic, ?loops:Dynamic)
	{
		cancelTimer(tag);
		var self = this;
		var l:Int = (loops == null) ? 1 : Std.int(num(loops));
		luaTimers.set(tag, new FlxTimer().start(time == null ? 1 : num(time), function(t) {
			if (t.finished) self.luaTimers.remove(tag);
			self.callLua('onTimerCompleted', [tag, t.loops, t.loopsLeft]);
		}, l));
	}
	function cancelTimer(tag:String)
	{
		if (luaTimers.exists(tag)) { luaTimers.get(tag).cancel(); luaTimers.remove(tag); }
	}
	function makeLuaSprite(tag:String, ?image:Dynamic, ?x:Dynamic, ?y:Dynamic)
	{
		removeLuaSprite(tag, true);
		var s = new FunkinSprite(num(x), num(y));
		if (image != null && Std.string(image).length > 0) s.loadTexture(Std.string(image));
		luaSprites.set(tag, s);
	}
	function makeAnimatedLuaSprite(tag:String, ?image:Dynamic, ?x:Dynamic, ?y:Dynamic, ?type:Dynamic)
	{
		removeLuaSprite(tag, true);
		var s = new FunkinSprite(num(x), num(y));
		if (image != null) s.loadSparrow(Std.string(image));
		luaSprites.set(tag, s);
	}
	function makeGraphic(tag:String, width:Dynamic, height:Dynamic, ?color:Dynamic)
	{
		var s = luaObject(tag);
		if (s != null) s.makeSolidColor(Std.int(num(width)), Std.int(num(height)), luaColor(color == null ? 'FFFFFF' : color));
	}
	function luaSpriteMakeGraphic(tag:String, width:Dynamic, height:Dynamic, ?color:Dynamic) makeGraphic(tag, width, height, color);
	function addLuaSprite(tag:String, ?front:Dynamic)
	{
		var s = luaSprites.get(tag);
		var ps = PlayState.instance;
		if (s == null || ps == null) return;
		var onGame:Bool = s.cameras == null || s.cameras.length == 0 || s.cameras[0] == ps.camGame;
		if (onGame && ps.currentStage != null)
		{
			s.zIndex = (front == true) ? 5000 : 0;
			ps.currentStage.add(s);
			ps.currentStage.refresh();
		}
		else luaAddHud(s);
	}
	/**
	 * Vortex Engine 0.7.2: V-Slice draws the HUD in zIndex order (health bar 800, combo 900, notes 1000 / 1001). Psych
	 * draws a Lua sprite / text over the HUD; one that covers most of the screen (a black screen, a flash) goes just
	 * under the notes instead, so they can still be seen and hit (on phones too).
	 */
	function luaAddHud(s:Dynamic)
	{
		var ps = PlayState.instance;
		var cover:Bool = s.width * s.height >= FlxG.width * FlxG.height * 0.6;
		if (cover && s.cameras != null && s.cameras.length > 0 && s.cameras[0] == ps.camCutscene) s.cameras = [ps.camHUD];
		s.zIndex = cover ? 999 : 1100;
		ps.add(s);
		ps.refresh();
	}
	function makeLuaText(tag:String, ?text:Dynamic, ?width:Dynamic, ?x:Dynamic, ?y:Dynamic)
	{
		removeLuaSprite(tag, true);
		var t = new FlxText(num(x), num(y), num(width), text == null ? '' : luaStr(text), 16);
		t.setFormat(Paths.font('vcr.ttf'), 16, 0xFFFFFFFF, 'center', FlxTextBorderStyle.OUTLINE, 0xFF000000);
		if (PlayState.instance != null) t.cameras = [PlayState.instance.camHUD];
		t.scrollFactor.set();
		t.borderSize = 2;
		luaSprites.set(tag, t);
	}
	function addLuaText(tag:String)
	{
		var t = luaSprites.get(tag);
		if (t != null && PlayState.instance != null) luaAddHud(t);
	}
	function removeLuaText(tag:String, ?destroy:Dynamic) removeLuaSprite(tag, destroy);
	function luaTextExists(tag:String):Bool return luaSprites.exists(tag);
	function setTextString(tag:String, text:Dynamic) { var t = luaObject(tag); if (t != null) t.text = luaStr(text); }
	function setTextSize(tag:String, size:Dynamic) { var t = luaObject(tag); if (t != null) t.size = Std.int(num(size)); }
	function setTextWidth(tag:String, w:Dynamic) { var t = luaObject(tag); if (t != null) t.fieldWidth = num(w); }
	function setTextHeight(tag:String, h:Dynamic) { var t = luaObject(tag); if (t != null) t.fieldHeight = num(h); }
	function setTextAutoSize(tag:String, v:Dynamic) { var t = luaObject(tag); if (t != null) t.autoSize = truthy(v); }
	function setTextBorder(tag:String, size:Dynamic, ?color:Dynamic, ?style:Dynamic)
	{
		var t = luaObject(tag);
		if (t == null) return;
		var st:String = style == null ? 'outline' : Std.string(style).toLowerCase();
		t.borderStyle = num(size) <= 0 ? FlxTextBorderStyle.NONE : (st == 'shadow' ? FlxTextBorderStyle.SHADOW : (st == 'outline_fast' ? FlxTextBorderStyle.OUTLINE_FAST : FlxTextBorderStyle.OUTLINE));
		t.borderSize = num(size);
		if (color != null) t.borderColor = luaColor(color);
	}
	function setTextColor(tag:String, color:Dynamic) { var t = luaObject(tag); if (t != null) t.color = luaColor(color); }
	function setTextFont(tag:String, font:Dynamic) { var t = luaObject(tag); if (t != null) t.font = Paths.font(luaStr(font)); }
	function setTextItalic(tag:String, v:Dynamic) { var t = luaObject(tag); if (t != null) t.italic = truthy(v); }
	function setTextAlignment(tag:String, ?align:Dynamic)
	{
		var t = luaObject(tag);
		if (t == null) return;
		var a:String = align == null ? 'left' : StringTools.trim(Std.string(align)).toLowerCase();
		t.alignment = (a == 'right' || a == 'center' || a == 'justify') ? a : 'left';
	}
	function getTextString(tag:String):Dynamic { var t = luaObject(tag); return t != null ? t.text : null; }
	function getTextSize(tag:String):Dynamic { var t = luaObject(tag); return t != null ? t.size : -1; }
	function getTextFont(tag:String):Dynamic { var t = luaObject(tag); return t != null ? t.font : null; }
	function getTextWidth(tag:String):Dynamic { var t = luaObject(tag); return t != null ? t.fieldWidth : 0; }
	function removeLuaSprite(tag:String, ?destroy:Dynamic)
	{
		var s = luaSprites.get(tag);
		if (s == null) return;
		var ps = PlayState.instance;
		if (ps != null)
		{
			if (ps.currentStage != null) ps.currentStage.remove(s, true);
			ps.remove(s, true);
		}
		if (destroy != false) { s.destroy(); luaSprites.remove(tag); }
	}
	function luaSpriteExists(tag:String):Bool return luaSprites.exists(tag);
	function setScrollFactor(tag:String, x:Dynamic, y:Dynamic)
	{
		var s = luaObject(tag);
		if (s != null) s.scrollFactor.set(num(x), num(y));
	}
	function setObjectCamera(tag:String, cam:Dynamic)
	{
		var s = luaObject(tag);
		if (s != null) s.cameras = [luaCamera(cam)];
	}
	function scaleObject(tag:String, x:Dynamic, y:Dynamic, ?update:Dynamic)
	{
		var s = luaObject(tag);
		if (s == null) return;
		s.scale.set(num(x), num(y));
		if (update != false) s.updateHitbox();
	}
	function setGraphicSize(tag:String, x:Dynamic, ?y:Dynamic, ?update:Dynamic)
	{
		var s = luaObject(tag);
		if (s == null) return;
		s.setGraphicSize(Std.int(num(x)), Std.int(num(y)));
		if (update != false) s.updateHitbox();
	}
	function screenCenter(tag:String, ?pos:Dynamic)
	{
		var s = luaObject(tag);
		if (s != null) s.screenCenter();
	}
	function setObjectOrder(tag:String, order:Dynamic)
	{
		var s = luaObject(tag);
		if (s != null) { s.zIndex = Std.int(num(order)); if (PlayState.instance.currentStage != null) PlayState.instance.currentStage.refresh(); }
	}
	function addAnimationByPrefix(tag:String, name:String, prefix:String, ?fps:Dynamic, ?loop:Dynamic)
	{
		var s = luaObject(tag);
		if (s != null) s.animation.addByPrefix(name, prefix, fps == null ? 24 : Std.int(num(fps)), loop != false);
	}
	function addAnimationByIndices(tag:String, name:String, prefix:String, indices:Dynamic, ?fps:Dynamic, ?loop:Dynamic)
	{
		var s = luaObject(tag);
		if (s == null) return;
		var list:Array<Int> = [];
		if (Std.isOfType(indices, String)) for (i in Std.string(indices).split(',')) list.push(Std.parseInt(StringTools.trim(i)));
		else for (i in (indices:Array<Dynamic>)) list.push(Std.int(num(i)));
		s.animation.addByIndices(name, prefix, list, '', fps == null ? 24 : Std.int(num(fps)), loop == true);
	}
	function playAnim(tag:String, anim:String, ?forced:Dynamic, ?reverse:Dynamic, ?frame:Dynamic)
	{
		var s = luaObject(tag);
		if (s == null) return;
		if (Reflect.field(s, 'characterId') != null) s.playAnimation(anim, true, true); // a character
		else
		{
			s.animation.play(anim, forced == true);
			// addOffset() offsets, like Psych's ModchartSprite
			var o = luaOffsets.get(tag + '::' + anim);
			if (o != null) s.offset.set(o[0], o[1]);
		}
	}
	var luaOffsets:Dynamic = new StringMap();
	var luaSounds:Dynamic = new StringMap();
	function addOffset(tag:String, anim:String, x:Dynamic, y:Dynamic) luaOffsets.set(tag + '::' + anim, [num(x), num(y)]);
	function updateHitbox(tag:String) { var s = luaObject(tag); if (s != null) s.updateHitbox(); }
	function getObjectOrder(tag:String):Dynamic { var s = luaObject(tag); return s != null ? s.zIndex : -1; }
	function characterDance(c:Dynamic) { var o = luaRoot(c == null ? 'bf' : Std.string(c)); if (o != null) o.dance(true); }
	function getColorFromHex(c:Dynamic):Int return luaColor(c);
	function stringStartsWith(a:Dynamic, b:Dynamic):Bool return a != null && b != null && StringTools.startsWith(Std.string(a), Std.string(b));
	function stringEndsWith(a:Dynamic, b:Dynamic):Bool return a != null && b != null && StringTools.endsWith(Std.string(a), Std.string(b));
	function stringTrim(a:Dynamic):String return a == null ? '' : StringTools.trim(Std.string(a));
	/** Psych's class names: FlxG and PlayState work (the others have no V-Slice equivalent to read) */
	function luaClass(name:String):Dynamic
	{
		switch (name)
		{
			case 'flixel.FlxG' | 'FlxG': return FlxG;
			case 'states.PlayState' | 'PlayState': return PlayState.instance;
			case 'backend.Conductor' | 'Conductor': return Conductor.instance;
			default: return null;
		}
	}
	function getPropertyFromClass(cls:String, path:String):Dynamic
	{
		var o:Dynamic = luaClass(cls);
		if (o == null) return unsupportedCall('getPropertyFromClass ' + cls);
		for (part in path.split('.')) { if (o == null) return null; o = Reflect.getProperty(o, part); }
		return o;
	}
	function setPropertyFromClass(cls:String, path:String, value:Dynamic)
	{
		var o:Dynamic = luaClass(cls);
		if (o == null) { unsupportedCall('setPropertyFromClass ' + cls); return; }
		var parts:Array<String> = path.split('.');
		var last:String = parts.pop();
		for (part in parts) { if (o == null) return; o = Reflect.getProperty(o, part); }
		if (o != null) Reflect.setProperty(o, last, value);
	}
	function getPropertyFromGroup(group:String, index:Dynamic, field:String):Dynamic
	{
		var g = luaObject(group);
		if (g == null) return null;
		var m = Std.isOfType(g, Array) ? g : g.members;
		var o:Dynamic = m == null ? null : m[Std.int(num(index))];
		for (part in field.split('.')) { if (o == null) return null; o = Reflect.getProperty(o, part); }
		return o;
	}
	function setPropertyFromGroup(group:String, index:Dynamic, field:String, value:Dynamic)
	{
		var g = luaObject(group);
		if (g == null) return;
		var m = Std.isOfType(g, Array) ? g : g.members;
		var o:Dynamic = m == null ? null : m[Std.int(num(index))];
		var parts:Array<String> = field.split('.');
		var last:String = parts.pop();
		for (part in parts) { if (o == null) return; o = Reflect.getProperty(o, part); }
		if (o != null) Reflect.setProperty(o, last, value);
	}
	/** Psych's key names -> V-Slice controls (suffix: '_P' just pressed, '' held, '_R' released) */
	function luaKey(name:Dynamic, suffix:String):Bool
	{
		var c = PlayerSettings.player1 != null ? PlayerSettings.player1.controls : null;
		if (c == null || name == null) return false;
		switch (Std.string(name).toLowerCase())
		{
			case 'left': return Reflect.getProperty(c, 'NOTE_LEFT' + suffix) == true;
			case 'down': return Reflect.getProperty(c, 'NOTE_DOWN' + suffix) == true;
			case 'up': return Reflect.getProperty(c, 'NOTE_UP' + suffix) == true;
			case 'right': return Reflect.getProperty(c, 'NOTE_RIGHT' + suffix) == true;
			case 'ui_left': return Reflect.getProperty(c, 'UI_LEFT' + suffix) == true;
			case 'ui_down': return Reflect.getProperty(c, 'UI_DOWN' + suffix) == true;
			case 'ui_up': return Reflect.getProperty(c, 'UI_UP' + suffix) == true;
			case 'ui_right': return Reflect.getProperty(c, 'UI_RIGHT' + suffix) == true;
			case 'accept': return suffix == '_P' && c.ACCEPT;
			case 'back': return suffix == '_P' && c.BACK;
			case 'pause': return suffix == '_P' && c.PAUSE;
			case 'reset': return suffix == '_P' && c.RESET;
			case 'space': return suffix == '_P' ? FlxG.keys.justPressed.SPACE : (suffix == '_R' ? FlxG.keys.justReleased.SPACE : FlxG.keys.pressed.SPACE);
			default: return false;
		}
	}
	function keyJustPressed(name:Dynamic):Bool return luaKey(name, '_P');
	function keyPressed(name:Dynamic):Bool return luaKey(name, '');
	function keyReleased(name:Dynamic):Bool return luaKey(name, '_R');
	function luaSound(tag:Dynamic):Dynamic
	{
		if (tag == null || Std.string(tag).length < 1) return FlxG.sound.music;
		return luaSounds.get(Std.string(tag));
	}
	function soundFadeOut(tag:Dynamic, duration:Dynamic, ?to:Dynamic)
	{
		var snd = luaSound(tag);
		if (snd != null) snd.fadeOut(num(duration), to == null ? 0 : num(to));
	}
	function soundFadeIn(tag:Dynamic, duration:Dynamic, ?from:Dynamic, ?to:Dynamic)
	{
		var snd = luaSound(tag);
		if (snd != null) snd.fadeIn(num(duration), from == null ? 0 : num(from), to == null ? 1 : num(to));
	}
	function stopSound(tag:Dynamic)
	{
		var snd = luaSound(tag);
		if (snd != null) snd.stop();
	}
	function setSoundVolume(tag:Dynamic, volume:Dynamic)
	{
		var snd = luaSound(tag);
		if (snd != null) snd.volume = num(volume);
	}
	function objectPlayAnimation(tag:String, anim:String, ?forced:Dynamic) playAnim(tag, anim, forced);
	function characterPlayAnim(tag:String, anim:String, ?forced:Dynamic) playAnim(tag, anim, forced);
	function playSound(sound:String, ?volume:Dynamic, ?tag:Dynamic)
	{
		var snd = FunkinSound.playOnce(Paths.sound(sound), volume == null ? 1 : num(volume));
		// a tagged sound can be faded / stopped later (soundFadeOut, stopSound...)
		if (tag != null && Std.string(tag).length > 0 && snd != null) luaSounds.set(Std.string(tag), snd);
	}
	function playMusic(sound:String, ?volume:Dynamic, ?loop:Dynamic)
		FunkinSound.playMusic(sound, {startingVolume: volume == null ? 1 : num(volume), loop: loop == true, overrideExisting: true});
	function getRandomInt(a:Dynamic, b:Dynamic):Int return FlxG.random.int(Std.int(num(a)), Std.int(num(b)));
	function getRandomFloat(a:Dynamic, b:Dynamic):Float return FlxG.random.float(num(a), num(b));
	function getRandomBool(?chance:Dynamic):Bool return FlxG.random.bool(chance == null ? 50 : num(chance));
	function getSongPosition():Float return Conductor.instance.songPosition;
	function endSong() { if (PlayState.instance != null) PlayState.instance.endSong(true); }

	// Psych's built-in events
	function addCameraZoom(?game:Dynamic, ?hud:Dynamic)
	{
		var ps = PlayState.instance;
		if (ps == null || !Preferences.zoomCamera) return;
		ps.cameraBopMultiplier += (game == null || tonumber(game) == null) ? 0.015 : num(game);
		ps.camHUD.zoom += (hud == null || tonumber(hud) == null) ? 0.03 : num(hud);
	}
	function screenShakePsych(v1:Dynamic, v2:Dynamic)
	{
		var ps = PlayState.instance;
		if (ps == null) return;
		var pairs = [[v1, ps.camGame], [v2, ps.camHUD]];
		for (pair in pairs)
		{
			var parts = Std.string(pair[0] == null ? '' : pair[0]).split(',');
			var dur = parts.length > 0 ? num(parts[0]) : 0;
			var amt = parts.length > 1 ? num(parts[1]) : 0;
			if (dur > 0 && amt != 0) pair[1].shake(amt, dur);
		}
	}
	/**
	 * Psych's Camera Follow Pos keeps the camera on that point (section cameras don't move it) until it is called with
	 * blank values. The converter's PsychCamera module does the holding (scripts/modules/).
	 */
	function cameraFollowPos(x:Dynamic, y:Dynamic)
	{
		var m = ModuleHandler.getModule('%CAMERA_MODULE%');
		if (tonumber(x) == null || tonumber(y) == null)
		{
			if (m != null) m.scriptCall('release', []);
			return;
		}
		if (m != null) m.scriptCall('lockAt', [num(x), num(y)]);
		else if (PlayState.instance != null) PlayState.instance.tweenCameraToPosition(num(x), num(y), 0);
	}
	function setCameraFollowPoint(x:Dynamic, y:Dynamic)
	{
		var ps = PlayState.instance;
		if (ps != null && ps.cameraFollowPoint != null) ps.cameraFollowPoint.setPosition(num(x), num(y));
	}
	function getCameraFollowX():Float return PlayState.instance.cameraFollowPoint.x;
	function getCameraFollowY():Float return PlayState.instance.cameraFollowPoint.y;
	function cameraSetTarget(target:String)
	{
		var t = Std.string(target).toLowerCase();
		var c = luaRoot((t == 'bf' || t == 'boyfriend') ? 'boyfriend' : ((t == 'gf' || t == 'girlfriend') ? 'gf' : 'dad'));
		if (c != null && c.cameraFocusPoint != null) setCameraFollowPoint(c.cameraFocusPoint.x, c.cameraFocusPoint.y);
	}
	function setHealth(v:Dynamic) PlayState.instance.health = num(v);
	function getHealth():Float return PlayState.instance.health;
	function addHealth(v:Dynamic) PlayState.instance.health += num(v);
	/** Psych camera numbers: stage camera_boyfriend / opponent / girlfriend, character camera_position */
	var psychCams:Dynamic = null;
	function psychCam(key:String):Dynamic
	{
		if (psychCams == null)
		{
			psychCams = new StringMap();
%PSYCH_CAMS%
		}
		return psychCams.get(key);
	}
	function getMidpointX(obj:String):Float
	{
		var w = getProperty(obj + '.width');
		return num(getProperty(obj + '.x')) + num(w) / 2;
	}
	function getMidpointY(obj:String):Float
	{
		var h = getProperty(obj + '.height');
		return num(getProperty(obj + '.y')) + num(h) / 2;
	}
	function getGraphicMidpointX(obj:String):Float return getMidpointX(obj);
	function getGraphicMidpointY(obj:String):Float return getMidpointY(obj);
	function getCharacterX(type:String):Float return num(getProperty((type == 'gf' || type == 'girlfriend') ? 'gf.x' : ((type == 'dad' || type == 'opponent') ? 'dad.x' : 'boyfriend.x')));
	function getCharacterY(type:String):Float return num(getProperty((type == 'gf' || type == 'girlfriend') ? 'gf.y' : ((type == 'dad' || type == 'opponent') ? 'dad.y' : 'boyfriend.y')));
	function setCharacterX(type:String, v:Dynamic) setProperty((type == 'gf' || type == 'girlfriend') ? 'gf.x' : ((type == 'dad' || type == 'opponent') ? 'dad.x' : 'boyfriend.x'), v);
	function setCharacterY(type:String, v:Dynamic) setProperty((type == 'gf' || type == 'girlfriend') ? 'gf.y' : ((type == 'dad' || type == 'opponent') ? 'dad.y' : 'boyfriend.y'), v);
	function setGfSpeed(speed:Dynamic)
	{
		var gf = luaRoot('gf');
		if (gf != null) gf.danceEvery = Math.max(1, num(speed));
	}
	function altIdle(who:Dynamic, suffix:Dynamic)
	{
		var w = Std.string(who == null ? 'dad' : who).toLowerCase();
		var c = luaRoot((w == 'bf' || w == 'boyfriend' || w == '0') ? 'boyfriend' : ((w == 'gf' || w == 'girlfriend' || w == '1') ? 'gf' : 'dad'));
		if (c != null) c.idleSuffix = (suffix == null) ? '' : Std.string(suffix);
	}
	/** Psych's Change Character: Value 1 = bf / dad / gf (or 0 / 1 / 2), Value 2 = the new character */
	function changeCharacter(who:Dynamic, newId:Dynamic)
	{
		var ps = PlayState.instance;
		if (ps == null || ps.currentStage == null || newId == null || Std.string(newId).length == 0) return;
		var w = StringTools.trim(Std.string(who == null ? '' : who).toLowerCase());
		// like Psych: gf / girlfriend / 2, dad / opponent / 1, anything else is Boyfriend
		var type = CharacterType.BF;
		if (w == 'gf' || w == 'girlfriend' || w == '2') type = CharacterType.GF;
		else if (w == 'dad' || w == 'opponent' || w == '1') type = CharacterType.DAD;
		var st = ps.currentStage;
		var old = (type == CharacterType.BF) ? st.getBoyfriend() : ((type == CharacterType.GF) ? st.getGirlfriend() : st.getDad());
		if (old != null && old.characterId == Std.string(newId)) return;
		var c = CharacterDataParser.fetchCharacter(Std.string(newId));
		if (c == null) { trace('[Psych Lua] Change Character: no character ' + newId); return; }
		st.addCharacter(c, type);
		if (old != null) { st.remove(old, true); old.kill(); }
		st.refresh();
	}

	function triggerEvent(name:String, ?v1:Dynamic, ?v2:Dynamic)
	{
		var a = v1 == null ? '' : luaStr(v1), b = v2 == null ? '' : luaStr(v2);
		switch (name)
		{
			case 'Camera Follow Pos': cameraFollowPos(a, b);
			case 'Add Camera Zoom': addCameraZoom(a, b);
			case 'Screen Shake': screenShakePsych(a, b);
			case 'Play Animation': playAnim(b == '' ? 'dad' : b, a, true);
			case 'Set GF Speed': setGfSpeed(a);
			case 'Alt Idle Animation': altIdle(a, b);
			case 'Play Sound': playSound(a, b == '' ? 1 : num(b));
			case 'Set Property': setProperty(a, b);
			case 'Change Character': changeCharacter(a, b);
			default: trace('[Psych Lua] triggerEvent(' + name + ') is not available in V-Slice');
		}
	}
";
}

typedef LTok = {k:String, v:String, line:Int};
