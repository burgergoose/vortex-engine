package psychlua;

/**
 * VORTEX ENGINE ADDITION - one place every script error goes (Lua and HScript, songs and menus).
 *
 * - Every error is written to `vortex_script_log.txt` next to the exe, with the full Lua stack traceback.
 * - The same error is only logged / shown on screen ONCE per session, so a broken onUpdate no longer
 *   floods the screen (or the log) 60 times a second.
 * - `errorCount` is shown in the F3 developer overlay.
 */
class ScriptLog
{
	public static inline var FILE:String = 'vortex_script_log.txt';
	public static var errorCount:Int = 0;

	static var seen:Map<String, Bool> = new Map<String, Bool>();
	static var started:Bool = false;

	/**
	 * Records an error. `details` (e.g. a stack traceback) only goes to the log file.
	 * Returns true the first time this error is seen, false for repeats.
	 */
	public static function error(source:String, message:String, ?details:String):Bool
	{
		var key:String = source + '\n' + message;
		if(seen.exists(key)) return false;
		seen.set(key, true);
		errorCount++;
		write('[ERROR] ' + source + '\n  ' + message.split('\n').join('\n  ') + (details != null && details.length > 0 ? '\n  ' + details.split('\n').join('\n  ') : ''));
		return true;
	}

	public static function info(message:String)
		write('[info] ' + message);

	/** Forget which errors were already shown (used by F7 "reload everything"), so they show again after a fix. **/
	public static function reset()
	{
		seen.clear();
		errorCount = 0;
	}

	static function write(text:String)
	{
		#if sys
		try
		{
			var out:sys.io.FileOutput = null;
			if(!started)
			{
				started = true;
				out = sys.io.File.write(FILE, false);
				out.writeString('Vortex Engine - script log (' + Date.now().toString() + ')\n'
					+ 'Every script error is written here once, with the Lua stack traceback when there is one.\n\n');
			}
			else out = sys.io.File.append(FILE, false);
			out.writeString(Date.now().toString().split(' ').pop() + ' ' + text + '\n');
			out.close();
		}
		catch(e:Dynamic) {}
		#end
	}
}
