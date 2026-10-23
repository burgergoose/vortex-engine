package objects;

import flixel.util.FlxColor;

/**
 * VORTEX ENGINE ADDITION.
 *
 * The cosmic "glass" box the menus use for side panels: a thin border, a dark
 * see-through fill and an optional coloured strip along the top. Same cheap
 * solid-sprite approach as SongCard / WeekCard (no per-panel bitmap drawing).
 */
class GlassPanel extends FlxSpriteGroup
{
	public var panelWidth(default, null):Int;
	public var panelHeight(default, null):Int;

	var border:FlxSprite;
	var fill:FlxSprite;
	var topStrip:FlxSprite;

	public function new(x:Float, y:Float, width:Int, height:Int, ?accent:Null<Int>, fillAlpha:Float = 0.74)
	{
		super(x, y);
		panelWidth = width;
		panelHeight = height;

		border = new FlxSprite().makeGraphic(width, height, FlxColor.WHITE);
		border.color = MenuTheme.PANEL_BORDER_DIM;
		add(border);

		fill = new FlxSprite(2, 2).makeGraphic(width - 4, height - 4, FlxColor.WHITE);
		fill.color = MenuTheme.PANEL_FILL;
		fill.alpha = fillAlpha;
		add(fill);

		topStrip = new FlxSprite(2, 2).makeGraphic(width - 4, 4, FlxColor.WHITE);
		topStrip.color = accent != null ? accent : MenuTheme.PANEL_BORDER_BRIGHT;
		add(topStrip);

		scrollFactor.set();
	}

	/** Colour of the strip along the top (e.g. the selected song's Freeplay colour). */
	public function setAccent(color:Int):Void
		topStrip.color = color;

	public function setBorderColor(color:Int):Void
		border.color = color;
}
