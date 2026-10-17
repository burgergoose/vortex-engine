package backend;

/**
 * VORTEX ENGINE
 * -------------
 * Single source of truth for engine identity (name/version/branding) and a
 * couple of engine-level feature defaults (Discord RPC). Everything that
 * used to say "Psych Engine" in the UI should read from here instead.
 *
 * Values are loaded from assets/shared/data/vortexConfig.json at startup
 * (see load(), called once from Main.hx before anything else needs it).
 * That means the engine name/Discord App ID can be changed by editing a
 * text file -- no recompiling required -- while still having safe,
 * hardcoded fallbacks below if that file is ever missing or malformed, so
 * a bad config can never crash the game.
 *
 * Mod packs can also ship their own assets/.../data/vortexConfig.json
 * inside a mod folder to override these per-mod, for free, because this
 * goes through Paths.getTextFromFile() -- the same mod-aware asset
 * resolution every other JSON file in the engine already uses.
 *
 * NOTE ON Project.xml: the window title / exe metadata baked into
 * Project.xml (<app title="..."/>) is a *compile-time* Lime/OpenFL setting
 * and can't read this JSON (it doesn't exist yet at build time). Main.hx
 * re-applies engineName to the live window title at runtime after this
 * config loads, so in practice the in-game name is fully config-driven;
 * only the .exe's own filename/metadata needs Project.xml edited and a
 * recompile.
 */
class VortexConfig
{
	// ---- Defaults. Only used if vortexConfig.json is missing/broken. ----
	public static var engineName(default, null):String = "Vortex Engine";
	public static var engineVersion(default, null):String = "0.3.0";

	/**
	 * Your own Discord Application ID from https://discord.com/developers/applications
	 * Leave as "0" and Discord Rich Presence will simply stay off (DiscordClient
	 * still checks ClientPrefs.data.discordRPC separately from this).
	 */
	public static var discordAppId(default, null):String = "0";

	/** Optional: a raw-text URL (e.g. a raw GitHub file) with your own build's version string, for CoolUtil.checkForUpdates(). Empty = update checking is skipped. */
	public static var updateCheckUrl(default, null):String = "";

	/** Optional: shown in crash logs / the outdated-version popup so bug reports go to the right place. Empty = the line is simply omitted. */
	public static var issueTrackerUrl(default, null):String = "";

	static var loaded:Bool = false;

	/** Safe to call more than once -- only does real work the first time. */
	public static function load():Void
	{
		if (loaded) return;
		loaded = true;

		try
		{
			var raw:String = Paths.getTextFromFile('data/vortexConfig.json');
			if (raw == null || raw.trim().length == 0)
			{
				trace('VortexConfig: no vortexConfig.json found, using built-in defaults');
				return;
			}

			var parsed:Dynamic = haxe.Json.parse(raw);
			if (Reflect.hasField(parsed, 'engineName') && parsed.engineName != null)
				engineName = Std.string(parsed.engineName);
			if (Reflect.hasField(parsed, 'engineVersion') && parsed.engineVersion != null)
				engineVersion = Std.string(parsed.engineVersion);
			if (Reflect.hasField(parsed, 'discordAppId') && parsed.discordAppId != null)
				discordAppId = Std.string(parsed.discordAppId);
			if (Reflect.hasField(parsed, 'updateCheckUrl') && parsed.updateCheckUrl != null)
				updateCheckUrl = Std.string(parsed.updateCheckUrl);
			if (Reflect.hasField(parsed, 'issueTrackerUrl') && parsed.issueTrackerUrl != null)
				issueTrackerUrl = Std.string(parsed.issueTrackerUrl);
		}
		catch (e:Dynamic)
		{
			trace('VortexConfig: failed to parse vortexConfig.json, using built-in defaults ($e)');
		}
	}
}
