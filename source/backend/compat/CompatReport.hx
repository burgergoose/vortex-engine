package backend.compat;

/**
 * VORTEX ENGINE ADDITION - what the compatibility layer (or the V-Slice converter) did with one mod:
 * what was translated, what was approximated, what failed and what needs a person to finish it.
 * Written as plain text so modders can read it without tools.
 */
class CompatReport
{
	public var title:String;
	public var engine:String = 'unknown';
	public var version:String = '';
	public var hints:Array<String> = [];
	public var converted:Array<String> = [];
	public var warnings:Array<String> = [];
	public var errors:Array<String> = [];
	public var manual:Array<String> = [];
	public var notes:Array<String> = [];

	public function new(title:String)
		this.title = title;

	public function ok(s:String) converted.push(s);
	public function warn(s:String) if (!warnings.contains(s)) warnings.push(s);
	public function error(s:String) if (!errors.contains(s)) errors.push(s);
	public function needs(s:String) if (!manual.contains(s)) manual.push(s);
	public function note(s:String) if (!notes.contains(s)) notes.push(s);

	/** Vortex Engine: saved next to report.txt so a later start can show the same summary without translating again. */
	public function toJson():String
		return haxe.Json.stringify({title: title, engine: engine, version: version, hints: hints, converted: converted,
			warnings: warnings, errors: errors, manual: manual, notes: notes}, '\t');

	public static function fromJson(text:String):CompatReport
	{
		try
		{
			var d:Dynamic = haxe.Json.parse(text);
			var r:CompatReport = new CompatReport(Std.string(d.title));
			r.engine = d.engine; r.version = d.version; r.hints = d.hints; r.converted = d.converted;
			r.warnings = d.warnings; r.errors = d.errors; r.manual = d.manual; r.notes = d.notes;
			return r;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public function summary():String
		return '${converted.length} converted, ${warnings.length} warnings, ${errors.length} errors, ${manual.length} manual changes';

	public function toText(?heading:String):String
	{
		var b:StringBuf = new StringBuf();
		b.add((heading != null ? heading : 'Vortex Engine compatibility report') + '\n');
		b.add('Mod: $title\n');
		b.add('Detected: $engine' + (version.length > 0 ? ' ($version)' : '') + '\n');
		for (h in hints) b.add('  - $h\n');
		b.add('Summary: ' + summary() + '\n');
		section(b, 'CONVERTED', converted);
		section(b, 'ERRORS (these files could not be used)', errors);
		section(b, 'WARNINGS (loaded, but check these)', warnings);
		section(b, 'NEEDS MANUAL CHANGES', manual);
		section(b, 'NOTES', notes);
		return b.toString();
	}

	static function section(b:StringBuf, name:String, list:Array<String>)
	{
		b.add('\n== $name (${list.length}) ==\n');
		if (list.length < 1) b.add('  (none)\n');
		for (s in list) b.add('  - $s\n');
	}
}
