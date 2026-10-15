package objects;

import openfl.display.BitmapData;
import openfl.display.BitmapDataChannel;
import openfl.display.Shape;
import openfl.display.GradientType;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.geom.ColorTransform;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;

/**
 * VORTEX ENGINE ADDITION.
 *
 * The shared cosmic backdrop for Freeplay and Story Mode: a gradient sky,
 * a couple of soft procedural nebula clouds, a static starfield, a small
 * number of individually-twinkling accent stars, and slow-drifting dust
 * particles.
 *
 * Everything is generated in code -- no new image assets required. The sky
 * gradient, nebula clouds, and static stars are all baked into ONE bitmap
 * once at construction time, so the ongoing per-frame cost is just
 * animating a couple dozen small sprites (twinkle stars + dust), not
 * anything pixel- or resolution-heavy.
 *
 * Also holds the shared cosmic color palette as public static constants,
 * so SongCard / WeekCard pull the exact same colors instead of every file
 * inventing its own. Declared as plain Int (not FlxColor) on purpose --
 * these values feed straight into raw OpenFL drawing APIs (Shape.graphics,
 * BitmapData) that want UInt/Int, as well as Flixel APIs that accept
 * FlxColor; Int converts cleanly into both, so this sidesteps any
 * abstract-conversion ambiguity between the two.
 */
class CosmicBackground extends FlxGroup
{
	// ---- Shared palette. Tweak these and the whole theme follows. ----
	public static inline var BG_TOP:Int = 0xFF05040D;
	public static inline var BG_MID:Int = 0xFF160F30;
	public static inline var BG_BOTTOM:Int = 0xFF0A0718;

	public static inline var NEBULA_VIOLET:Int = 0xFF7C4DFF;
	public static inline var NEBULA_MAGENTA:Int = 0xFFD84FA0;
	public static inline var NEBULA_TEAL:Int = 0xFF35D0C0;

	public static inline var PANEL_FILL:Int = 0xFF120C24;
	public static inline var PANEL_BORDER_DIM:Int = 0xFF4A3E7A;
	public static inline var PANEL_BORDER_BRIGHT:Int = 0xFF9C6BFF;

	public static inline var ACCENT_CYAN:Int = 0xFF52E7FF;
	public static inline var TEXT_BRIGHT:Int = 0xFFF3F0FF;
	public static inline var TEXT_DIM:Int = 0xFFAFA8D8;

	var twinkleStars:Array<FlxSprite> = [];
	var twinkleSeed:Array<Float> = [];
	var dust:Array<FlxSprite> = [];
	var dustSpeed:Array<Float> = [];
	var elapsedTime:Float = 0;

	// Vortex Engine (UI polish): gently swaying backdrop, shooting stars, optional rotating vortex rings
	var baked:FlxSprite;
	var shooters:Array<FlxSprite> = [];
	var shooterWait:Array<Float> = [];
	var shooterLife:Array<Float> = [];
	var shooterVX:Array<Float> = [];
	var shooterVY:Array<Float> = [];
	var rings:Array<FlxSprite> = [];
	var ringSpeed:Array<Float> = [];

	var screenW:Int;
	var screenH:Int;

	public function new(width:Int = 1280, height:Int = 720, withVortex:Bool = false, ringCenterX:Float = -1)
	{
		super();
		screenW = width;
		screenH = height;

		baked = null;
		try
		{
			baked = new FlxSprite(0, 0).loadGraphic(bakeSkyNebulaAndStars(width, height));
		}
		catch (e:Dynamic)
		{
			// Vortex Engine: if procedural generation ever misbehaves on some target,
			// fall back to a flat, still-thematic solid color rather than a crash.
			trace('CosmicBackground: procedural generation failed, using flat fallback ($e)');
			baked = new FlxSprite(0, 0).makeGraphic(width, height, BG_MID);
		}
		baked.scrollFactor.set();
		baked.scale.set(1.06, 1.06); // a little oversized so it can sway without showing edges
		baked.antialiasing = true;
		add(baked);

		if (withVortex) buildVortex(width, height, ringCenterX < 0 ? width / 2 : ringCenterX);
		buildTwinkleStars(width, height);
		buildDust(width, height);
		buildShooters();
	}

	function bakeRing(size:Int, color:Int, arcs:Int, seed:Int):BitmapData
	{
		var shape:Shape = new Shape();
		var g = shape.graphics;
		var c:Float = size / 2;
		for (a in 0...arcs)
		{
			var radius:Float = size * (0.20 + 0.11 * a);
			var thick:Float = 2 + a * 1.2;
			g.lineStyle(thick, color, Math.max(0.25, 0.95 - 0.2 * a));
			for (seg in 0...3)
			{
				var start:Float = (seg * 120 + a * 47 + seed * 31) * Math.PI / 180;
				var sweep:Float = (70 - a * 8) * Math.PI / 180;
				var steps:Int = 28;
				for (i in 0...steps + 1)
				{
					var ang:Float = start + sweep * i / steps;
					var px:Float = c + Math.cos(ang) * radius;
					var py:Float = c + Math.sin(ang) * radius;
					if (i == 0) g.moveTo(px, py); else g.lineTo(px, py);
				}
			}
		}
		var bmp:BitmapData = new BitmapData(size, size, true, 0x00000000);
		bmp.draw(shape);
		return bmp;
	}

	function buildVortex(w:Int, h:Int, cx:Float):Void
	{
		var defs:Array<Array<Dynamic>> = [[720, NEBULA_VIOLET, 4, 1, 5.0, 0.45], [560, ACCENT_CYAN, 3, 2, -8.0, 0.38], [380, NEBULA_MAGENTA, 3, 3, 12.0, 0.40]];
		for (d in defs)
		{
			var ring:FlxSprite = new FlxSprite().loadGraphic(bakeRing(d[0], d[1], d[2], d[3]));
			ring.screenCenter();
			ring.x = cx - ring.width / 2;
			ring.scrollFactor.set();
			ring.antialiasing = true;
			ring.alpha = d[5];
			add(ring);
			rings.push(ring);
			ringSpeed.push(d[4]);
		}
	}

	function buildShooters():Void
	{
		var tail:BitmapData = new BitmapData(150, 3, true, 0x00000000);
		for (x in 0...150)
		{
			var a:Float = Math.pow(x / 149, 2.2);
			for (y in 0...3)
				tail.setPixel32(x, y, (Std.int(a * 255) << 24) | 0xFFFFFF);
		}
		for (i in 0...2)
		{
			var sh:FlxSprite = new FlxSprite().loadGraphic(tail);
			sh.scrollFactor.set();
			sh.visible = false;
			sh.origin.set(0, 1.5);
			add(sh);
			shooters.push(sh);
			shooterWait.push(1.5 + Math.random() * 4 + i * 2);
			shooterLife.push(0);
			shooterVX.push(0);
			shooterVY.push(0);
		}
	}

	function bakeSkyNebulaAndStars(w:Int, h:Int):BitmapData
	{
		var canvas:BitmapData = new BitmapData(w, h, false, BG_MID);

		// --- sky gradient ---
		var sky:Shape = new Shape();
		var m:Matrix = new Matrix();
		m.createGradientBox(w, h, Math.PI / 2, 0, 0);
		sky.graphics.beginGradientFill(GradientType.LINEAR, [BG_TOP, BG_MID, BG_BOTTOM], [1, 1, 1], [0, 140, 255], m);
		sky.graphics.drawRect(0, 0, w, h);
		sky.graphics.endFill();
		canvas.draw(sky);

		// --- nebula clouds: perlin noise used as an alpha mask over a flat tint ---
		drawNebulaLayer(canvas, w, h, NEBULA_VIOLET, 0.16, 220, 1);
		drawNebulaLayer(canvas, w, h, NEBULA_MAGENTA, 0.12, 160, 2);
		drawNebulaLayer(canvas, w, h, NEBULA_TEAL, 0.09, 260, 3);

		// --- static starfield, baked in (twinkle stars are separate live sprites on top) ---
		var stars:Shape = new Shape();
		var starCount:Int = Math.round((w * h) / 2600); // scales with resolution instead of a fixed count
		for (i in 0...starCount)
		{
			var sx:Float = Math.random() * w;
			var sy:Float = Math.random() * h;
			var r:Float = 0.6 + Math.random() * 1.3;
			var a:Float = 0.35 + Math.random() * 0.55;
			stars.graphics.beginFill(0xFFFFFF, a);
			stars.graphics.drawCircle(sx, sy, r);
			stars.graphics.endFill();
		}
		canvas.draw(stars);

		return canvas;
	}

	function drawNebulaLayer(canvas:BitmapData, w:Int, h:Int, tint:Int, maxAlpha:Float, scale:Int, seed:Int):Void
	{
		var noise:BitmapData = new BitmapData(w, h, true, 0x00000000);
		noise.perlinNoise(scale, scale, 3, seed * 7919, false, true, 7, false);

		var colored:BitmapData = new BitmapData(w, h, true, (0xFF000000 | (tint & 0x00FFFFFF)));
		colored.copyChannel(noise, new Rectangle(0, 0, w, h), new Point(0, 0), BitmapDataChannel.RED, BitmapDataChannel.ALPHA);

		var faded:BitmapData = new BitmapData(w, h, true, 0x00000000);
		var ct:ColorTransform = new ColorTransform(1, 1, 1, maxAlpha);
		faded.draw(colored, null, ct);

		canvas.draw(faded);
		noise.dispose();
		colored.dispose();
		faded.dispose();
	}

	function buildTwinkleStars(w:Int, h:Int):Void
	{
		var count:Int = 22;
		for (i in 0...count)
		{
			var star:FlxSprite = new FlxSprite(Math.random() * w, Math.random() * h);
			var size:Int = (Math.random() < 0.3) ? 3 : 2;
			star.makeGraphic(size, size, FlxColor.WHITE);
			star.scrollFactor.set();
			star.alpha = 0.5;
			add(star);
			twinkleStars.push(star);
			twinkleSeed.push(Math.random() * 10);
		}
	}

	function buildDust(w:Int, h:Int):Void
	{
		var count:Int = 16;
		for (i in 0...count)
		{
			var mote:FlxSprite = new FlxSprite(Math.random() * w, h + Math.random() * h);
			mote.makeGraphic(2, 2, ACCENT_CYAN);
			mote.scrollFactor.set();
			mote.alpha = 0.12 + Math.random() * 0.18;
			add(mote);
			dust.push(mote);
			dustSpeed.push(4 + Math.random() * 10);
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		elapsedTime += elapsed;

		// slow sway so the whole sky feels alive
		if (baked != null)
		{
			baked.x = Math.sin(elapsedTime * 0.11) * 16;
			baked.y = Math.cos(elapsedTime * 0.08) * 9;
		}

		for (i in 0...rings.length)
		{
			rings[i].angle += ringSpeed[i] * elapsed;
			rings[i].scale.x = rings[i].scale.y = 1 + 0.025 * Math.sin(elapsedTime * 0.6 + i * 1.7);
		}

		for (i in 0...shooters.length)
		{
			var sh:FlxSprite = shooters[i];
			if (shooterLife[i] > 0)
			{
				shooterLife[i] -= elapsed;
				sh.x += shooterVX[i] * elapsed;
				sh.y += shooterVY[i] * elapsed;
				var t:Float = Math.max(0, shooterLife[i] / 0.9);
				sh.alpha = Math.sin(t * Math.PI) * 0.9;
				if (shooterLife[i] <= 0) { sh.visible = false; shooterWait[i] = 3 + Math.random() * 6; }
			}
			else
			{
				shooterWait[i] -= elapsed;
				if (shooterWait[i] <= 0)
				{
					var ang:Float = (18 + Math.random() * 20) * Math.PI / 180;
					sh.x = Math.random() * screenW * 0.7;
					sh.y = Math.random() * screenH * 0.4;
					sh.angle = ang * 180 / Math.PI;
					shooterVX[i] = Math.cos(ang) * 780;
					shooterVY[i] = Math.sin(ang) * 780;
					shooterLife[i] = 0.9;
					sh.visible = true;
				}
			}
		}

		for (i in 0...twinkleStars.length)
		{
			var s = twinkleStars[i];
			if (s == null) continue;
			s.alpha = 0.35 + 0.45 * (0.5 + 0.5 * Math.sin(elapsedTime * 1.4 + twinkleSeed[i]));
		}

		for (i in 0...dust.length)
		{
			var d = dust[i];
			if (d == null) continue;
			d.y -= dustSpeed[i] * elapsed;
			d.x += Math.sin(elapsedTime * 0.5 + i) * 4 * elapsed;
			if (d.y < -10)
			{
				d.y = screenH + 10;
				d.x = Math.random() * screenW;
			}
		}
	}
}
