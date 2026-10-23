package objects;

import flixel.util.FlxColor;

/**
 * VORTEX ENGINE ADDITION.
 *
 * A row of key "chips" for the bottom of a menu: [ENTER] Play  [SPACE] Listen ...
 * Centred inside the given width. Call setHints() to change them.
 */
class KeyHints extends FlxSpriteGroup
{
	static inline var CHIP_H:Int = 22;
	static inline var GAP:Int = 22;

	var areaWidth:Float;

	public function new(x:Float, y:Float, areaWidth:Float, hints:Array<Array<String>>)
	{
		super(x, y);
		this.areaWidth = areaWidth;
		scrollFactor.set();
		setHints(hints);
	}

	/** hints = [[key, what it does], ...], for example [['ENTER', 'Play'], ['ESC', 'Back']] */
	public function setHints(hints:Array<Array<String>>):Void
	{
		for (member in members) if (member != null) member.destroy();
		clear();

		var parts:Array<{chip:FlxSprite, key:FlxText, label:FlxText}> = [];
		var total:Float = 0;
		for (hint in hints)
		{
			var key:FlxText = new FlxText(0, 0, 0, hint[0], 14);
			key.setFormat(MenuTheme.font(), 14, MenuTheme.PANEL_FILL, CENTER);
			var chipW:Int = Std.int(key.width + 14);
			var chip:FlxSprite = new FlxSprite().makeGraphic(chipW, CHIP_H, FlxColor.WHITE);
			chip.color = MenuTheme.ACCENT_CYAN;
			var label:FlxText = new FlxText(0, 0, 0, hint.length > 1 ? hint[1] : '', 14);
			label.setFormat(MenuTheme.font(), 14, MenuTheme.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			parts.push({chip: chip, key: key, label: label});
			total += chipW + 8 + label.width;
		}
		total += GAP * Math.max(0, parts.length - 1);

		var cx:Float = Math.max(0, (areaWidth - total) / 2);
		for (p in parts)
		{
			// positions are relative: FlxSpriteGroup.add() offsets members by the group's own x/y
			p.chip.setPosition(cx, 0);
			p.key.setPosition(cx + (p.chip.width - p.key.width) / 2, (CHIP_H - p.key.height) / 2);
			cx += p.chip.width + 8;
			p.label.setPosition(cx, (CHIP_H - p.label.height) / 2);
			cx += p.label.width + GAP;
			add(p.chip);
			add(p.key);
			add(p.label);
		}
	}
}
