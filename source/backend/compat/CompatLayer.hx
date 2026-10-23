package backend.compat;

/**
 * VORTEX ENGINE ADDITION - the universal mod compatibility layer.
 *
 * For every enabled mod it detects the engine the mod was made for (CompatScan.detect). Psych Engine mods (0.6 - 1.0
 * and Psych forks) load directly. Mods for V-Slice, Codename Engine, FPS Plus and Forever Engine are translated into
 * Psych-format files in `vortex_compat/<mod>/` next to the game; the mod's own folder is never written to.
 * Paths.modFolders, Mods.directoriesWithFile and WeekData look in that cache after the mod's own folder, so every
 * existing loader (charts, characters, stages, weeks) reads the translated files without knowing about them.
 *
 * Translation only runs again when the mod's files change (a fingerprint of their sizes and dates). Each mod gets
 * `vortex_compat/<mod>/report.txt`, and `vortex_compat_log.txt` collects one line per mod.
 */
class CompatLayer
{
	/** Bump when a translator changes, so cached translations are redone. */
	public static inline var TRANSLATOR_VERSION:Int = 6; // 0.7: atlas sizes read correctly // 0.6: V-Slice library folders, content discovery, more events, stage scripts, feet placement
	public static inline var CACHE_ROOT:String = 'vortex_compat/';

	public static var reports:Map<String, CompatReport> = [];
	public static var detections:Map<String, CompatScan.Detection> = [];
	static var cachedMods:Array<String> = [];
	/** 0.6: extra folders (relative to mods/<mod>/) searched for a file the mod doesn't have at its root: the real
		content folder of a mod extracted one folder too deep, and V-Slice's library folders (shared/, week1/...). */
	static var searchPrefixes:Map<String, Array<String>> = [];

	/** A file of `mod` found in one of its extra folders (see searchPrefixes), or null. Used by Paths.modFolders. */
	public static function extraFile(mod:String, key:String):String
	{
		#if MODS_ALLOWED
		var list:Array<String> = (mod != null) ? searchPrefixes.get(mod) : null;
		if (list == null) return null;
		for (p in list)
		{
			var f:String = Paths.mods(mod + '/' + p + key);
			if (FileSystem.exists(f)) return f;
		}
		#end
		return null;
	}

	public static function prefixesOf(mod:String):Array<String>
	{
		var list:Array<String> = searchPrefixes.get(mod);
		return list != null ? list : [];
	}

	public static inline function cacheDir(mod:String):String
		return CACHE_ROOT + mod + '/';

	/** True if `mod` has translated files (checked by the path lookups, so it must be cheap). */
	public static function hasCache(mod:String):Bool
		return mod != null && mod.length > 0 && cachedMods.contains(mod);

	public static function refreshAll():Void
	{
		#if MODS_ALLOWED
		var lines:Array<String> = [];
		var changed:Bool = false;
		for (mod in Mods.parseList().enabled)
		{
			try
			{
				var before:CompatReport = reports.get(mod);
				var rep:CompatReport = refresh(mod);
				if (rep != before) changed = true;
				if (rep != null) lines.push('$mod: ${rep.engine}' + (rep.version.length > 0 ? ' (${rep.version})' : '') + ' - ' + rep.summary());
			}
			catch (e:Dynamic)
			{
				lines.push('$mod: compatibility check failed: $e');
				psychlua.ScriptLog.error('Mod compatibility: $mod', Std.string(e));
			}
		}
		if (changed)
			try CompatUtil.writeText('vortex_compat_log.txt', 'Vortex Engine mod compatibility (' + Date.now().toString() + ')\nFull reports: ' + CACHE_ROOT + '<mod>/report.txt\n\n' + lines.join('\n') + '\n')
			catch (e:Dynamic) {}
		#end
	}

	/** Detects and (re)translates one mod. Returns its report. */
	public static function refresh(mod:String):CompatReport
	{
		#if MODS_ALLOWED
		var modRoot:String = Paths.mods(mod + '/');
		var inner:String = CompatUtil.contentRoot(modRoot); // 0.6: mod extracted one folder too deep
		var root:String = modRoot + inner;
		var out:String = cacheDir(mod);
		var det = CompatScan.detect(root);
		detections.set(mod, det);
		var prefixes:Array<String> = [];
		if (inner.length > 0) prefixes.push(inner);
		if (det.engine == 'vslice')
			for (lib in CompatUtil.VSLICE_LIBRARIES) if (CompatUtil.isDir(root + lib)) prefixes.push(inner + lib + '/');
		if (prefixes.length > 0) searchPrefixes.set(mod, prefixes); else searchPrefixes.remove(mod);
		if (inner.length > 0 && !det.translate) det.translate = true; // its weeks are copied into the cache so Story Mode / Freeplay find them

		if (!det.translate)
		{
			cachedMods.remove(mod);
			if (CompatUtil.isDir(out)) CompatUtil.deleteTree(out); // the mod used to need translating and doesn't anymore
			var rep:CompatReport = reports.get(mod);
			if (rep == null || rep.engine != det.label)
			{
				rep = new CompatReport(mod);
				rep.engine = det.label;
				rep.version = det.version;
				rep.hints = det.hints;
				if (det.engine == 'psych') CompatScan.scanScripts(root, rep, 'psych');
				reports.set(mod, rep);
			}
			return rep;
		}

		var fp:String = fingerprint(root) + '|' + inner;
		var old:String = CompatUtil.readText(out + '.fingerprint');
		if (old == fp && reports.exists(mod)) { if (!cachedMods.contains(mod)) cachedMods.push(mod); return reports.get(mod); }

		var rep:CompatReport = new CompatReport(mod);
		rep.engine = det.label;
		rep.version = det.version;
		rep.hints = det.hints;
		if (old == fp && CompatUtil.exists(out + 'report.json'))
		{
			// translated in an earlier session and unchanged: reuse the files and the saved report
			var saved:CompatReport = CompatReport.fromJson(CompatUtil.readText(out + 'report.json'));
			if (saved != null) rep = saved;
			reports.set(mod, rep);
			if (!cachedMods.contains(mod)) cachedMods.push(mod);
			return rep;
		}

		if (CompatUtil.isDir(out)) CompatUtil.deleteTree(out);
		CompatUtil.makeDirs(out);
		if (inner.length > 0)
			rep.warn('This mod is one folder too deep: its files are in mods/$mod/$inner. Vortex reads them from there, but moving "${inner.substr(0, inner.length - 1)}" straight into mods/ is safer: other engines do not look inside it.');
		switch (det.engine)
		{
			case 'psych': // only here because it is nested: make its weeks visible
				for (f in CompatUtil.list(root + 'weeks/')) if (f.endsWith('.json') || f == 'weekList.txt') CompatUtil.copyFile(root + 'weeks/' + f, out + 'weeks/' + f);
				CompatScan.scanScripts(root, rep, 'psych');
			case 'vslice': VSliceImport.run(root, out, rep);
			case 'codename': CodenameImport.run(root, out, rep);
			case 'fpsplus' | 'forever': LegacyImport.run(root, out, det.engine, rep);
		}
		rep.note('Translated files are in ${out} (Psych format). The mod folder itself was not changed.');
		CompatUtil.writeText(out + 'report.txt', rep.toText());
		CompatUtil.writeText(out + 'report.json', rep.toJson());
		CompatUtil.writeText(out + '.fingerprint', fp);
		reports.set(mod, rep);
		if (!cachedMods.contains(mod)) cachedMods.push(mod);
		trace('Mod compatibility: translated $mod (${det.label}) - ' + rep.summary());
		return rep;
		#else
		return null;
		#end
	}

	/** Sizes + dates of the files the translators read; changes when the mod is edited. */
	static function fingerprint(root:String):String
	{
		var b:StringBuf = new StringBuf();
		b.add('v$TRANSLATOR_VERSION|' + backend.VortexConfig.engineVersion + '|');
		for (sub in ['data/', 'scripts/', '_polymod_meta.json']) // Vortex Engine 0.6: scripts/ too (stage scripts are read)
		{
			if (CompatUtil.isDir(root + sub)) for (f in CompatUtil.walk(root + sub, 20000)) b.add(sub + f + '=' + CompatUtil.stamp(root + sub + f) + ';');
			else if (CompatUtil.exists(root + sub)) b.add(sub + '=' + CompatUtil.stamp(root + sub) + ';');
		}
		for (folder in CompatUtil.list(root + 'songs/'))
		{
			var dir:String = root + 'songs/$folder/';
			for (f in CompatUtil.list(dir)) if (!CompatUtil.isDir(dir + f)) b.add('songs/$folder/$f=' + CompatUtil.stamp(dir + f) + ';');
			for (f in CompatUtil.list(dir + 'charts/')) b.add('songs/$folder/charts/$f=' + CompatUtil.stamp(dir + 'charts/' + f) + ';');
			for (f in CompatUtil.list(dir + 'song/')) b.add('songs/$folder/song/$f=' + CompatUtil.stamp(dir + 'song/' + f) + ';');
		}
		return haxe.crypto.Md5.encode(b.toString());
	}

	/** Path of `key` in a mod's translation cache, or null (used by Paths.modFolders). */
	public static function cached(mod:String, key:String):String
	{
		#if MODS_ALLOWED
		if (hasCache(mod))
		{
			var p:String = cacheDir(mod) + key;
			if (FileSystem.exists(p)) return p;
		}
		#end
		return null;
	}

	/** Translated weeks of every enabled mod: [folderName, weekFileName, path]. */
	public static function cachedWeeks():Array<Array<String>>
	{
		var out:Array<Array<String>> = [];
		#if MODS_ALLOWED
		for (mod in Mods.parseList().enabled)
		{
			if (!hasCache(mod)) continue;
			var dir:String = cacheDir(mod) + 'weeks/';
			var order:Array<String> = [];
			var listed:String = CompatUtil.readText(dir + 'weekList.txt');
			if (listed != null) for (l in listed.split('\n')) { l = l.trim(); if (l.length > 0 && CompatUtil.exists(dir + '$l.json')) order.push(l); }
			for (f in CompatUtil.list(dir)) if (f.endsWith('.json') && !order.contains(f.substr(0, f.length - 5))) order.push(f.substr(0, f.length - 5));
			for (w in order) out.push([mod, w, dir + '$w.json']);
		}
		#end
		return out;
	}
}
