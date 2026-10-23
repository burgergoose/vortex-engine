package states.editors;

import backend.compat.CompatLayer;
import backend.compat.CompatReport;
import backend.compat.CompatScan;
import backend.compat.VSliceExport;
import objects.CosmicBackground;
import objects.GlassPanel;
import objects.KeyHints;

/**
 * VORTEX ENGINE ADDITION - Developer menu -> V-Slice Converter.
 * Pick a mod folder: the right panel shows which engine it was made for and what Vortex's compatibility layer did
 * with it. ENTER converts it to a V-Slice mod folder (vortex_converted/<mod>-vslice/, the mod itself is not
 * changed), R shows the full compatibility report, V shows the last conversion report, O opens the output folder.
 */
class VSliceConverterState extends MusicBeatState
{
	var mods:Array<String> = [];
	var curSelected:Int = 0;
	var listTexts:Array<FlxText> = [];
	var infoTitle:FlxText;
	var infoText:FlxText;
	var statusText:FlxText;
	var hints:KeyHints;

	var viewer:FlxSpriteGroup;
	var viewerText:FlxText;
	var viewerScroll:Float = 0;
	var viewing:Bool = false;
	var pendingConvert:Int = -1;
	var pendingZip:Bool = false; // Vortex Engine 0.6: zipping waits a frame so the "Making the zip..." text shows first
	var lastReport:CompatReport;

	override function create()
	{
		FlxG.mouse.visible = true;
		add(MenuTheme.background());

		var title:FlxText = new FlxText(40, 30, 0, 'V-SLICE CONVERTER', 40);
		title.setFormat(MenuTheme.font(), 40, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, MenuTheme.NEBULA_VIOLET);
		title.borderSize = 2;
		add(title);
		var sub:FlxText = new FlxText(44, 76, FlxG.width - 88, 'Turns a mod into V-Slice\'s folder layout in vortex_converted/. Your mod folder is not changed.', 16);
		sub.setFormat(MenuTheme.font(), 16, MenuTheme.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(sub);

		#if MODS_ALLOWED
		try CompatLayer.refreshAll() catch (e:Dynamic) {}
		mods = Mods.getModDirectories();
		#end

		add(new GlassPanel(40, 110, 360, 540));
		var label:FlxText = new FlxText(60, 124, 320, 'MOD FOLDERS', 14);
		label.setFormat(MenuTheme.font(), 14, MenuTheme.ACCENT_CYAN, LEFT);
		add(label);
		for (i in 0...mods.length)
		{
			var t:FlxText = new FlxText(60, 150 + i * 30, 320, mods[i], 18);
			t.setFormat(MenuTheme.font(), 18, MenuTheme.TEXT_DIM, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.ID = i;
			add(t);
			listTexts.push(t);
		}
		if (mods.length < 1)
		{
			var none:FlxText = new FlxText(60, 150, 320, 'No mod folders in mods/.', 18);
			none.setFormat(MenuTheme.font(), 18, MenuTheme.TEXT_DIM, LEFT);
			add(none);
		}

		add(new GlassPanel(420, 110, 820, 540));
		infoTitle = new FlxText(444, 126, 772, '', 26);
		infoTitle.setFormat(MenuTheme.font(), 26, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(infoTitle);
		infoText = new FlxText(444, 166, 772, '', 15);
		infoText.setFormat(MenuTheme.font(), 15, MenuTheme.TEXT_DIM, LEFT);
		add(infoText);
		statusText = new FlxText(444, 560, 772, '', 16);
		statusText.setFormat(MenuTheme.font(), 16, MenuTheme.ACCENT_CYAN, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(statusText);

		var bar:FlxSprite = new FlxSprite(0, FlxG.height - 40).makeGraphic(FlxG.width, 40, FlxColor.BLACK);
		bar.alpha = 0.6;
		add(bar);
		hints = new KeyHints(0, FlxG.height - 31, FlxG.width, [['ENTER', 'Convert to V-Slice'], ['R', 'Compatibility report'], ['V', 'Last conversion report'], ['O', 'Open output folder'], ['Z', 'Zip for V-Slice / phone'], ['ESC', 'Back']]);
		add(hints);

		// full-screen report viewer
		viewer = new FlxSpriteGroup();
		var vbg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		vbg.alpha = 0.92;
		viewer.add(vbg);
		viewerText = new FlxText(40, 30, FlxG.width - 80, '', 15);
		viewerText.setFormat(MenuTheme.font(), 15, MenuTheme.TEXT_BRIGHT, LEFT);
		viewer.add(viewerText);
		var vh:FlxText = new FlxText(0, FlxG.height - 28, FlxG.width, 'UP / DOWN or mouse wheel: scroll     ESC: close', 14);
		vh.setFormat(MenuTheme.font(), 14, MenuTheme.ACCENT_CYAN, CENTER);
		viewer.add(vh);
		viewer.visible = false;
		add(viewer);

		changeSelection();
		super.create();
	}

	override function update(elapsed:Float)
	{
		if (pendingZip)
		{
			pendingZip = false;
			doZip();
		}
		if (pendingConvert > -1)
		{
			var idx:Int = pendingConvert;
			pendingConvert = -1;
			doConvert(mods[idx]);
		}

		if (viewing)
		{
			var scroll:Float = 0;
			if (controls.UI_UP) scroll -= 600 * elapsed;
			if (controls.UI_DOWN) scroll += 600 * elapsed;
			if (FlxG.mouse.wheel != 0) scroll -= FlxG.mouse.wheel * 60;
			viewerScroll = Math.max(0, Math.min(Math.max(0, viewerText.height - FlxG.height + 100), viewerScroll + scroll));
			viewerText.y = 30 - viewerScroll;
			if (controls.BACK) { viewing = false; viewer.visible = false; FlxG.sound.play(Paths.sound('cancelMenu')); }
			super.update(elapsed);
			return;
		}

		if (mods.length > 0)
		{
			if (controls.UI_UP_P) changeSelection(-1);
			if (controls.UI_DOWN_P) changeSelection(1);
			if (FlxG.mouse.wheel != 0) changeSelection(-FlxG.mouse.wheel);
			for (t in listTexts)
				if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(t) && t.ID != curSelected) changeSelection(t.ID - curSelected);
			if (controls.ACCEPT)
			{
				statusText.text = 'Converting ${mods[curSelected]}... (copying pictures and audio can take a moment)';
				pendingConvert = curSelected;
			}
			if (FlxG.keys.justPressed.R) showText(fullReport(mods[curSelected]));
		}
		if (FlxG.keys.justPressed.V)
		{
			if (lastReport != null) showText(lastReport.toText('Vortex Engine V-Slice Converter report') + '\nOutput folder: ' + VSliceExport.lastOutput);
			else statusText.text = 'Convert a mod first (ENTER).';
		}
		if (FlxG.keys.justPressed.Z && !pendingZip)
		{
			if (VSliceExport.lastOutput == null) statusText.text = 'Convert a mod first (ENTER), then press Z to zip it.';
			else
			{
				statusText.text = 'Making the zip...';
				pendingZip = true;
			}
		}
		if (FlxG.keys.justPressed.O)
		{
			#if sys
			var folder:String = VSliceExport.lastOutput != null ? VSliceExport.lastOutput : VSliceExport.OUTPUT_ROOT;
			if (sys.FileSystem.exists(folder)) CoolUtil.openFolder(folder);
			else statusText.text = 'Nothing converted yet.';
			#end
		}
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MasterEditorMenu());
		}
		super.update(elapsed);
	}

	function changeSelection(change:Int = 0)
	{
		if (mods.length < 1)
		{
			infoTitle.text = 'NO MODS';
			infoText.text = 'Put a mod folder in mods/ and come back.';
			return;
		}
		if (change != 0) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, mods.length - 1);
		for (t in listTexts) t.color = (t.ID == curSelected) ? MenuTheme.TEXT_BRIGHT : MenuTheme.TEXT_DIM;
		for (t in listTexts) t.text = (t.ID == curSelected ? '> ' : '  ') + mods[t.ID];

		var mod:String = mods[curSelected];
		infoTitle.text = mod.toUpperCase();
		var b:StringBuf = new StringBuf();
		#if MODS_ALLOWED
		var det = CompatScan.detect(Paths.mods(mod + '/'));
		b.add('Made for: ${det.label}' + (det.version.length > 0 ? ' (${det.version})' : '') + '\n');
		for (h in det.hints) b.add('  - $h\n');
		var rep:CompatReport = CompatLayer.reports.get(mod);
		if (rep != null)
		{
			b.add('\nIn Vortex: ' + rep.summary() + '\n');
			if (det.translate) b.add('Vortex plays it through a Psych-format translation (vortex_compat/$mod/).\n');
			else if (det.engine == 'psych') b.add('Vortex loads it directly.\n');
			for (e in rep.errors.slice(0, 3)) b.add('  ERROR: $e\n');
			for (m in rep.manual.slice(0, 4)) b.add('  TO DO: $m\n');
			if (rep.manual.length > 4 || rep.errors.length > 3) b.add('  ... press R for everything\n');
		}
		else b.add('\nNot enabled in the Mods menu, so Vortex has not checked it yet.\n');
		b.add('\nENTER makes vortex_converted/$mod-vslice/ with V-Slice charts, metadata, characters, stages, levels and audio, '
			+ 'plus REPORT.txt listing what could not be converted (Lua / HScript, most events, extra strumlines...). '
			+ 'Converted files still need testing inside V-Slice.');
		#end
		infoText.text = b.toString();
	}

	function doConvert(mod:String)
	{
		var t0:Float = haxe.Timer.stamp();
		lastReport = VSliceExport.run(mod);
		var secs:Float = Math.round((haxe.Timer.stamp() - t0) * 10) / 10;
		statusText.text = 'Done in ${secs}s: ' + lastReport.summary() + '\nSaved to ' + VSliceExport.lastOutput + ' (V = report, O = open folder, Z = zip for V-Slice / phone)';
		FlxG.sound.play(Paths.sound(lastReport.errors.length > 0 ? 'cancelMenu' : 'confirmMenu'));
	}

	function doZip()
	{
		var err:Array<String> = [];
		var zip:String = VSliceExport.makeZip(VSliceExport.lastOutput, err);
		if (zip == null)
		{
			statusText.text = 'Could not make the zip: ' + err.join('; ');
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}
		var folder:String = VSliceExport.lastOutput;
		while (folder.endsWith('/')) folder = folder.substr(0, folder.length - 1);
		var name:String = folder.substr(folder.lastIndexOf('/') + 1);
		statusText.text = 'Saved $zip\nUnzip it inside V-Slice\'s mods/ folder so that mods/$name/_polymod_meta.json exists, then restart the game. (O = open folder)';
		FlxG.sound.play(Paths.sound('confirmMenu'));
	}

	function fullReport(mod:String):String
	{
		var rep:CompatReport = CompatLayer.reports.get(mod);
		#if MODS_ALLOWED
		var file:String = CompatLayer.cacheDir(mod) + 'report.txt';
		if (sys.FileSystem.exists(file)) return sys.io.File.getContent(file);
		#end
		return rep != null ? rep.toText() : 'No compatibility report for $mod (enable it in the Mods menu first).';
	}

	function showText(text:String)
	{
		viewerText.text = text;
		viewerScroll = 0;
		viewerText.y = 30;
		viewer.visible = viewing = true;
	}
}
