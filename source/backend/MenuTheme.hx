package backend;

import flixel.FlxBasic;
import flixel.group.FlxSpriteGroup;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxGradient;
import openfl.display.BitmapData;
import objects.CosmicBackground;

/**
 * VORTEX ENGINE ADDITION (0.5) - menu themes, picked in Developer menu -> Menu Editor.
 *
 *   vortex  The cosmic Vortex Engine menus (default).
 *   psych   Psych Classic: Psych Engine-style main menu, Freeplay, Story Mode and Developer menu.
 *   custom  A mod's `custom_menus/menu.json` (see docs): colours, font, backgrounds, layout, icons, labels,
 *           animations and transitions on top of the Vortex layout. If it fails to load, the last built-in
 *           theme is used and the problems are listed (Menu Editor, vortex_script_log.txt).
 *
 * The menus read colours / font / background from here instead of using fixed values.
 */
class MenuTheme
{
	public static inline var VORTEX:String = 'vortex';
	public static inline var PSYCH:String = 'psych';
	public static inline var CUSTOM:String = 'custom';
	public static inline var CONFIG_FORMAT:Int = 1;

	/** what the player picked ('vortex' until they pick something) */
	public static var selected(default, null):String = VORTEX;
	/** which mod's custom_menus/ the Custom theme uses ('' = first enabled mod that has one) */
	public static var selectedMod(default, null):String = '';
	/** the theme actually in use (Custom falls back to the last built-in theme when it can't load) */
	public static var active(default, null):String = VORTEX;
	public static var custom(default, null):Dynamic = null;
	public static var customFolder(default, null):String = null;
	public static var customMod(default, null):String = null;
	public static var errors(default, null):Array<String> = [];
	public static var warnings(default, null):Array<String> = [];
	static var loaded:Bool = false;
	static var fallback:String = VORTEX;
	static var chosenByPlayer:Bool = false;

	public static function load(force:Bool = false):Void
	{
		if (loaded && !force) return;
		if (FlxG.save == null || FlxG.save.data == null) return; // too early (before the save is bound): use the defaults for now
		loaded = true;
		var data:Dynamic = FlxG.save.data;
		selected = (data != null && data.vortexMenuTheme != null) ? Std.string(data.vortexMenuTheme) : VORTEX;
		selectedMod = (data != null && data.vortexMenuThemeMod != null) ? Std.string(data.vortexMenuThemeMod) : '';
		fallback = (data != null && data.vortexMenuThemeFallback == PSYCH) ? PSYCH : VORTEX;
		chosenByPlayer = data != null && data.vortexMenuTheme != null;
		if (selected != VORTEX && selected != PSYCH && selected != CUSTOM) selected = VORTEX;
		apply();
	}

	/** Re-reads custom_menus (call after mods are enabled / disabled or a menu.json was edited). */
	public static function apply(quiet:Bool = false):Void
	{
		custom = null;
		customFolder = null;
		customMod = null;
		errors = [];
		warnings = [];
		active = selected;

		var wantCustom:Bool = selected == CUSTOM;
		#if MODS_ALLOWED
		// a mod can ask for its menu to be used until the player picks a theme in the Menu Editor
		if (!chosenByPlayer && !wantCustom)
			for (mod in Mods.parseList().enabled)
			{
				var cfg:Dynamic = readConfig(Paths.mods('$mod/custom_menus/menu.json'), []);
				if (cfg != null && cfg.autoApply == true) { wantCustom = true; selectedMod = mod; break; }
			}
		#end
		if (!wantCustom) return;

		var folder:String = findCustomFolder(selectedMod);
		if (folder == null)
		{
			errors.push(selectedMod.length > 0 ? 'mods/$selectedMod/custom_menus/menu.json was not found.' : 'No enabled mod has a custom_menus/menu.json.');
			active = fallback;
			if (!quiet) report();
			return;
		}
		var cfg:Dynamic = readConfig(folder + 'menu.json', errors);
		if (cfg != null) validate(cfg, folder, errors, warnings);
		if (cfg == null || errors.length > 0)
		{
			active = fallback;
			if (!quiet) report();
			return;
		}
		custom = cfg;
		customFolder = folder;
		customMod = folder.split('/')[1];
		active = CUSTOM;
		if (warnings.length > 0 && !quiet) report();
	}

	/**
	 * Runs `build` as if `theme` (and for 'custom', that mod's custom_menus) were the active theme, then puts the real
	 * theme back. Used by the Menu Editor's preview. Returns the errors / warnings of that theme.
	 */
	public static function preview(theme:String, mod:String, build:Void->Void):{errors:Array<String>, warnings:Array<String>}
	{
		load();
		var saved:Array<Dynamic> = [selected, selectedMod, active, custom, customFolder, customMod, errors, warnings, chosenByPlayer];
		selected = theme;
		selectedMod = (mod != null) ? mod : '';
		chosenByPlayer = true;
		apply(true);
		var result = {errors: errors, warnings: warnings};
		try build() catch (e:Dynamic) trace('Menu preview failed: $e');
		selected = saved[0]; selectedMod = saved[1]; active = saved[2]; custom = saved[3]; customFolder = saved[4];
		customMod = saved[5]; errors = saved[6]; warnings = saved[7]; chosenByPlayer = saved[8];
		return result;
	}

	/** Saves the player's choice. theme: vortex / psych / custom. */
	public static function set(theme:String, ?mod:String = ''):Void
	{
		FlxG.save.data.vortexMenuTheme = theme;
		FlxG.save.data.vortexMenuThemeMod = (mod != null) ? mod : '';
		if (theme == VORTEX || theme == PSYCH) FlxG.save.data.vortexMenuThemeFallback = theme;
		FlxG.save.data.vortexChartThemeStamp = (FlxG.save.data.vortexChartThemeStamp != null ? FlxG.save.data.vortexChartThemeStamp : 0) + 1;
		FlxG.save.flush();
		load(true);
	}

	/** Back to the default Vortex theme. */
	public static function reset():Void
		set(VORTEX, '');

	public static var isClassic(get, never):Bool;
	static function get_isClassic():Bool { load(); return active == PSYCH; }
	public static var isCustom(get, never):Bool;
	static function get_isCustom():Bool { load(); return active == CUSTOM && custom != null; }

	// ------------------------------------------------------------------ palette (Vortex colours unless the custom theme sets them)
	public static var PANEL_FILL(get, never):Int;
	static function get_PANEL_FILL() return colour('panelFill', CosmicBackground.PANEL_FILL);
	public static var PANEL_BORDER_DIM(get, never):Int;
	static function get_PANEL_BORDER_DIM() return colour('panelBorder', CosmicBackground.PANEL_BORDER_DIM);
	public static var PANEL_BORDER_BRIGHT(get, never):Int;
	static function get_PANEL_BORDER_BRIGHT() return colour('panelBorderSelected', CosmicBackground.PANEL_BORDER_BRIGHT);
	public static var ACCENT_CYAN(get, never):Int;
	static function get_ACCENT_CYAN() return colour('accent', CosmicBackground.ACCENT_CYAN);
	public static var TEXT_BRIGHT(get, never):Int;
	static function get_TEXT_BRIGHT() return colour('text', CosmicBackground.TEXT_BRIGHT);
	public static var TEXT_DIM(get, never):Int;
	static function get_TEXT_DIM() return colour('textDim', CosmicBackground.TEXT_DIM);
	public static var NEBULA_VIOLET(get, never):Int;
	static function get_NEBULA_VIOLET() return colour('primary', CosmicBackground.NEBULA_VIOLET);
	public static var NEBULA_MAGENTA(get, never):Int;
	static function get_NEBULA_MAGENTA() return colour('secondary', CosmicBackground.NEBULA_MAGENTA);
	public static var NEBULA_TEAL(get, never):Int;
	static function get_NEBULA_TEAL() return colour('tertiary', CosmicBackground.NEBULA_TEAL);

	public static final COLOR_KEYS:Array<String> = ['panelFill', 'panelBorder', 'panelBorderSelected', 'accent', 'text', 'textDim', 'primary', 'secondary', 'tertiary'];

	static function colour(key:String, def:Int):Int
	{
		if (!isCustom || custom.colors == null) return def;
		var v:Dynamic = Reflect.field(custom.colors, key);
		return (v == null) ? def : parseColour(v, def);
	}

	public static function parseColour(v:Dynamic, def:Int):Int
	{
		if (v == null) return def;
		var s:String = Std.string(v).trim().replace('#', '').replace('0x', '').replace('0X', '');
		if (s.length == 6) s = 'FF' + s;
		if (s.length != 8 || !~/^[0-9a-fA-F]{8}$/.match(s)) return def;
		// parsed in two halves: Std.parseInt('0xFF......') overflows a 32-bit int on native targets
		var a:Null<Int> = Std.parseInt('0x' + s.substr(0, 2));
		var rgb:Null<Int> = Std.parseInt('0x' + s.substr(2));
		if (a == null || rgb == null) return def;
		return (a << 24) | rgb;
	}

	/** Font for menu text (the custom theme's, else vcr.ttf). */
	public static function font():String
	{
		if (isCustom && custom.font != null)
		{
			var f:String = resolveFile(Std.string(custom.font), 'assets/');
			if (f != null) return f;
		}
		return Paths.font('vcr.ttf');
	}

	/** Intro animation of buttons / cards: 'slide' (default), 'fade' or 'none'. */
	public static function introStyle():String
	{
		if (!isCustom || custom.animations == null || custom.animations.intro == null) return 'slide';
		return Std.string(custom.animations.intro);
	}

	/** Multiplier for menu animation speed (custom themes; 1 = normal). */
	public static function animSpeed():Float
	{
		if (!isCustom || custom.animations == null || custom.animations.speed == null) return 1;
		var v:Float = Std.parseFloat(Std.string(custom.animations.speed));
		return (Math.isNaN(v) || v <= 0) ? 1 : v;
	}

	/** Screen transition length in seconds (0 = no transition). */
	public static function transitionTime():Float
	{
		if (!isCustom || custom.transitions == null) return 0.5;
		if (custom.transitions.type == 'none') return 0;
		var v:Float = Std.parseFloat(Std.string(custom.transitions.duration));
		return (Math.isNaN(v) || v < 0) ? 0.5 : Math.min(v, 3);
	}

	/** A screen's section of menu.json ('mainMenu', 'freeplay', 'storyMode', 'developerMenu', 'chartEditor'), or null. */
	public static function screen(name:String):Dynamic
	{
		if (!isCustom) return null;
		return Reflect.field(custom, name);
	}

	public static function screenValue(screenName:String, key:String, ?def:Dynamic = null):Dynamic
	{
		var s:Dynamic = screen(screenName);
		if (s == null) return def;
		var v:Dynamic = Reflect.field(s, key);
		return (v == null) ? def : v;
	}

	/**
	 * Background for a screen: the custom theme's (screen override, then the shared one) or the cosmic backdrop.
	 * withVortex / ringCenterX are passed to CosmicBackground for the Vortex look.
	 */
	public static function background(?screenName:String, withVortex:Bool = false, ringCenterX:Float = -1):FlxBasic
	{
		var def:Dynamic = null;
		if (isCustom)
		{
			def = screenValue(screenName, 'background', null);
			if (def == null) def = custom.background;
		}
		if (def == null || def.type == null || def.type == 'cosmic')
			return new CosmicBackground(Std.int(FlxG.width), Std.int(FlxG.height), withVortex && (def == null || def.rings != false), ringCenterX);

		var group:FlxSpriteGroup = new FlxSpriteGroup();
		group.scrollFactor.set();
		try
		{
			switch (Std.string(def.type))
			{
				case 'color':
					var spr:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
					spr.color = parseColour(def.color, FlxColor.BLACK);
					group.add(spr);
				case 'gradient':
					var cols:Array<Dynamic> = (def.colors != null) ? def.colors : ['#120C24', '#05040D'];
					var spr:FlxSprite = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [for (c in cols) FlxColor.fromInt(parseColour(c, FlxColor.BLACK))]);
					group.add(spr);
				case 'image':
					var file:String = resolveFile(Std.string(def.image), 'assets/');
					var spr:FlxSprite = makeImage(file, def);
					if (spr != null) group.add(spr);
			}
			if (def.animation != null)
			{
				var anim:FlxSprite = animatedSprite(def.animation);
				if (anim != null) group.add(anim);
			}
			if (def.alpha != null) group.alpha = Std.parseFloat(Std.string(def.alpha));
		}
		catch (e:Dynamic)
		{
			trace('Custom menu background failed: $e');
			return new CosmicBackground(Std.int(FlxG.width), Std.int(FlxG.height), withVortex, ringCenterX);
		}
		return group;
	}

	static function makeImage(file:String, def:Dynamic):FlxSprite
	{
		var g:FlxGraphic = graphic(file);
		if (g == null) return null;
		var scroll:Array<Dynamic> = (def.scroll != null && Std.isOfType(def.scroll, Array)) ? def.scroll : null;
		var spr:FlxSprite;
		if (scroll != null && (scroll[0] != 0 || scroll[1] != 0))
		{
			var bd = new flixel.addons.display.FlxBackdrop(g);
			bd.velocity.set(Std.parseFloat(Std.string(scroll[0])), Std.parseFloat(Std.string(scroll[1])));
			spr = bd;
		}
		else
		{
			spr = new FlxSprite().loadGraphic(g);
			if (def.fit != 'none')
			{
				var s:Float = Math.max(FlxG.width / spr.width, FlxG.height / spr.height);
				spr.scale.set(s, s);
				spr.updateHitbox();
				spr.screenCenter();
			}
		}
		spr.antialiasing = ClientPrefs.data.antialiasing;
		spr.scrollFactor.set();
		return spr;
	}

	/** An animated sprite from custom_menus/animations/<file>.png + .xml (Sparrow). def: {file, prefix, fps, x, y, scale, loop} */
	public static function animatedSprite(def:Dynamic):FlxSprite
	{
		if (def == null || def.file == null) return null;
		var base:String = resolveFile(Std.string(def.file) + '.png', 'animations/');
		var xml:String = resolveFile(Std.string(def.file) + '.xml', 'animations/');
		if (base == null || xml == null) return null;
		var g:FlxGraphic = graphic(base);
		if (g == null) return null;
		var spr:FlxSprite = new FlxSprite(num(def.x, 0), num(def.y, 0));
		spr.frames = FlxAtlasFrames.fromSparrow(g, File.getContent(xml));
		spr.animation.addByPrefix('anim', def.prefix != null ? Std.string(def.prefix) : '', Std.int(num(def.fps, 24)), def.loop != false);
		spr.animation.play('anim');
		var sc:Float = num(def.scale, 1);
		if (sc != 1) { spr.scale.set(sc, sc); spr.updateHitbox(); }
		spr.antialiasing = ClientPrefs.data.antialiasing;
		spr.scrollFactor.set();
		return spr;
	}

	/** A still picture from custom_menus/assets/ (used for logos and button icons). */
	public static function image(name:String):FlxSprite
	{
		var file:String = resolveFile(name, 'assets/');
		var g:FlxGraphic = graphic(file);
		if (g == null) return null;
		var spr:FlxSprite = new FlxSprite().loadGraphic(g);
		spr.antialiasing = ClientPrefs.data.antialiasing;
		spr.scrollFactor.set();
		return spr;
	}

	static function graphic(file:String):FlxGraphic
	{
		if (file == null) return null;
		var key:String = 'vortex_menu:' + file;
		var g:FlxGraphic = FlxG.bitmap.get(key);
		if (g != null) return g;
		var bmp:BitmapData = BitmapData.fromFile(file);
		if (bmp == null) return null;
		g = FlxGraphic.fromBitmapData(bmp, false, key);
		return g;
	}

	static inline function num(v:Dynamic, def:Float):Float
	{
		if (v == null) return def;
		var f:Float = Std.parseFloat(Std.string(v));
		return Math.isNaN(f) ? def : f;
	}

	/** A file of the custom menu: custom_menus/<sub><name>, custom_menus/<name>, then the game's fonts/images. */
	public static function resolveFile(name:String, sub:String):String
	{
		if (name == null || name.length < 1 || name.indexOf('..') > -1) return null;
		#if sys
		if (customFolder != null)
			for (p in [customFolder + sub + name, customFolder + name])
				if (FileSystem.exists(p)) return p;
		if (sub == 'assets/' && (name.endsWith('.ttf') || name.endsWith('.otf')))
		{
			var f:String = Paths.font(name);
			if (FileSystem.exists(f)) return f;
		}
		#end
		return null;
	}

	// ------------------------------------------------------------------ custom_menus loading / validation
	public static function findCustomFolder(mod:String):String
	{
		#if MODS_ALLOWED
		if (mod != null && mod.length > 0)
			return FileSystem.exists(Paths.mods('$mod/custom_menus/menu.json')) ? Paths.mods('$mod/custom_menus/') : null;
		for (m in Mods.parseList().enabled)
			if (FileSystem.exists(Paths.mods('$m/custom_menus/menu.json'))) return Paths.mods('$m/custom_menus/');
		#end
		return null;
	}

	/** Enabled mods that have a custom_menus/menu.json. */
	public static function modsWithCustomMenus():Array<String>
	{
		var out:Array<String> = [];
		#if MODS_ALLOWED
		for (m in Mods.parseList().enabled)
			if (FileSystem.exists(Paths.mods('$m/custom_menus/menu.json'))) out.push(m);
		#end
		return out;
	}

	static function readConfig(path:String, errs:Array<String>):Dynamic
	{
		#if sys
		if (!FileSystem.exists(path)) return null;
		try
		{
			var cfg:Dynamic = tjson.TJSON.parse(File.getContent(path));
			if (cfg == null || Type.typeof(cfg) != TObject) { errs.push('menu.json must be a JSON object { ... }'); return null; }
			return cfg;
		}
		catch (e:Dynamic)
		{
			errs.push('menu.json is not valid JSON: ' + Std.string(e).split('\n')[0]);
		}
		#end
		return null;
	}

	static final TOP_KEYS:Array<String> = ['format', 'name', 'author', 'description', 'autoApply', 'font', 'colors', 'background', 'animations', 'transitions', 'mainMenu', 'freeplay', 'storyMode', 'developerMenu', 'chartEditor'];
	static final SCREEN_KEYS:Map<String, Array<String>> = [
		'mainMenu' => ['background', 'title', 'subtitle', 'logo', 'buttons', 'icons', 'labels', 'showInfoPanel', 'infoText', 'navigation', 'showVersion'],
		'freeplay' => ['background', 'title', 'showInfoPanel'],
		'storyMode' => ['background', 'title'],
		'developerMenu' => ['background', 'title'],
		'chartEditor' => ['background', 'grid', 'gridOther']
	];

	/** Checks a menu.json. Problems that would break a menu are errors (the theme is not used); the rest are warnings. */
	public static function validate(cfg:Dynamic, folder:String, errs:Array<String>, warns:Array<String>):Void
	{
		for (k in Reflect.fields(cfg)) if (!TOP_KEYS.contains(k)) warns.push('"$k" is not a menu.json setting (ignored).');
		var fmt:Dynamic = cfg.format;
		if (fmt != null && Std.parseInt(Std.string(fmt)) != CONFIG_FORMAT) warns.push('format is $fmt; this Vortex Engine reads format $CONFIG_FORMAT.');

		if (cfg.colors != null)
		{
			if (Type.typeof(cfg.colors) != TObject) errs.push('colors must be an object like {"accent": "#52E7FF"}.');
			else for (k in Reflect.fields(cfg.colors))
			{
				if (!COLOR_KEYS.contains(k)) warns.push('colors.$k is not a colour setting (use ${COLOR_KEYS.join(', ')}).');
				else if (parseColour(Reflect.field(cfg.colors, k), -1) == -1) errs.push('colors.$k: "${Reflect.field(cfg.colors, k)}" is not a colour like "#52E7FF".');
			}
		}
		var prevFolder:String = customFolder;
		customFolder = folder;
		if (cfg.font != null && resolveFile(Std.string(cfg.font), 'assets/') == null) errs.push('font: "${cfg.font}" was not found in custom_menus/assets/ or the game\'s fonts.');
		checkBackground(cfg.background, 'background', errs);
		if (cfg.animations != null)
		{
			var intro:Dynamic = cfg.animations.intro;
			if (intro != null && !['slide', 'fade', 'none'].contains(Std.string(intro))) errs.push('animations.intro must be "slide", "fade" or "none".');
		}
		if (cfg.transitions != null && cfg.transitions.type != null && !['fade', 'none'].contains(Std.string(cfg.transitions.type))) errs.push('transitions.type must be "fade" or "none".');

		for (name => keys in SCREEN_KEYS)
		{
			var s:Dynamic = Reflect.field(cfg, name);
			if (s == null) continue;
			if (Type.typeof(s) != TObject) { errs.push('$name must be an object.'); continue; }
			for (k in Reflect.fields(s)) if (!keys.contains(k)) warns.push('$name.$k is not a setting of this screen (ignored).');
			if (name == 'chartEditor')
			{
				if (s.background != null && parseColour(s.background, -1) == -1) errs.push('chartEditor.background: "${s.background}" is not a colour like "#303030".');
			}
			else checkBackground(s.background, '$name.background', errs);
		}
		var mm:Dynamic = cfg.mainMenu;
		if (mm != null)
		{
			if (mm.logo != null)
			{
				if (Type.typeof(mm.logo) == TObject) { if (animatedSprite(mm.logo) == null) errs.push('mainMenu.logo: animation "${mm.logo.file}" needs animations/${mm.logo.file}.png and .xml.'); }
				else if (resolveFile(Std.string(mm.logo), 'assets/') == null) errs.push('mainMenu.logo: "${mm.logo}" was not found in custom_menus/assets/.');
			}
			if (mm.icons != null && Type.typeof(mm.icons) == TObject)
				for (k in Reflect.fields(mm.icons))
					if (resolveFile(Std.string(Reflect.field(mm.icons, k)), 'assets/') == null) errs.push('mainMenu.icons.$k: "${Reflect.field(mm.icons, k)}" was not found in custom_menus/assets/.');
			if (mm.buttons != null)
			{
				var b:Dynamic = mm.buttons;
				if (b.align != null && !['left', 'center', 'right'].contains(Std.string(b.align))) errs.push('mainMenu.buttons.align must be "left", "center" or "right".');
				for (k in ['x', 'y', 'spacing', 'width'])
				{
					var v:Dynamic = Reflect.field(b, k);
					if (v != null && Math.isNaN(Std.parseFloat(Std.string(v)))) errs.push('mainMenu.buttons.$k must be a number.');
				}
			}
		}
		var ce:Dynamic = cfg.chartEditor;
		if (ce != null)
		{
			for (k in ['grid', 'gridOther'])
			{
				var v:Dynamic = Reflect.field(ce, k);
				if (v != null && (!Std.isOfType(v, Array) || (v : Array<Dynamic>).length < 2)) errs.push('chartEditor.$k must be two colours, like ["#DFDFDF", "#BFBFBF"].');
			}
		}
		customFolder = prevFolder;
	}

	static function checkBackground(bg:Dynamic, where:String, errs:Array<String>)
	{
		if (bg == null) return;
		if (Type.typeof(bg) != TObject) { errs.push('$where must be an object like {"type": "color", "color": "#000000"}.'); return; }
		var type:String = Std.string(bg.type);
		switch (type)
		{
			case 'cosmic':
			case 'color': if (parseColour(bg.color, -1) == -1) errs.push('$where.color: "${bg.color}" is not a colour.');
			case 'gradient':
				if (bg.colors == null || !Std.isOfType(bg.colors, Array) || (bg.colors : Array<Dynamic>).length < 2) errs.push('$where.colors needs at least two colours.');
			case 'image':
				if (bg.image == null || resolveFile(Std.string(bg.image), 'assets/') == null) errs.push('$where.image: "${bg.image}" was not found in custom_menus/assets/.');
			default: errs.push('$where.type must be "cosmic", "color", "gradient" or "image" (got "$type").');
		}
		if (bg.animation != null && animatedSprite(bg.animation) == null) errs.push('$where.animation: needs animations/${bg.animation.file}.png and .xml.');
	}

	static function report()
	{
		var where:String = customFolder != null ? customFolder : 'custom_menus';
		for (e in errors) psychlua.ScriptLog.error('Custom menu: $where', e);
		if (errors.length > 0)
		{
			trace('Custom menu not used (${errors.length} problems), using the $fallback theme: ' + errors.join(' | '));
			try Main.showToast('Custom menu could not be loaded (${errors.length} problem' + (errors.length == 1 ? '' : 's') + ').\nUsing the ' + (fallback == PSYCH ? 'Psych Classic' : 'Vortex') + ' theme. Details: Developer menu > Menu Editor.') catch (e:Dynamic) {}
		}
	}

	/** Chart editor colours for the active theme: [bg, grid1, grid2, other1, other2], or null for "leave the editor's own choice". */
	public static function chartEditorColours():Array<Int>
	{
		if (!isCustom || custom.chartEditor == null) return null;
		var ce:Dynamic = custom.chartEditor;
		var grid:Array<Dynamic> = ce.grid != null ? ce.grid : ['#DFDFDF', '#BFBFBF'];
		var other:Array<Dynamic> = ce.gridOther != null ? ce.gridOther : ['#5F5F5F', '#4A4A4A'];
		return [parseColour(ce.background, 0xFF303030), parseColour(grid[0], 0xFFDFDFDF), parseColour(grid[1], 0xFFBFBFBF), parseColour(other[0], 0xFF5F5F5F), parseColour(other[1], 0xFF4A4A4A)];
	}
}
