package objects;

import flixel.util.FlxColor;
import objects.MenuItem;

/**
 * VORTEX ENGINE ADDITION.
 *
 * One row in the redesigned Story Mode week list. Wraps the existing
 * objects.MenuItem (which loads each week's own storymenu/WeekName.png
 * banner art) inside the same cosmic glass-panel framing SongCard uses,
 * instead of replacing the banner art with something generated -- mods
 * that ship custom week banners keep working exactly as before, they just
 * sit inside a nicer frame now.
 *
 * bannerItem is exposed publicly so StoryMenuState can still set
 * .isFlashing on it the same way it always could (that's an existing
 * MenuItem feature, untouched).
 */
class WeekCard extends FlxSpriteGroup
{
	public static inline var CARD_WIDTH:Int = 620;
	public static inline var CARD_HEIGHT:Int = 130;
	static inline var BORDER:Int = 2;

	public var weekFile(default, null):String;
	public var bannerItem(default, null):MenuItem;
	/** Mirrors MenuItem's own targetY -- lets StoryMenuState reuse its exact original scroll-position formula. */
	public var targetY:Float = 0;

	var border:FlxSprite;
	var fill:FlxSprite;
	var accentBar:FlxSprite;
	var lockedOverlay:FlxSprite;
	var lockIcon:FlxSprite;
	var titleFallback:FlxText;

	// Vortex Engine (UI polish): eased selection value + soft halo, same idea as SongCard
	public var highlight(default, null):Float = 0;
	var wantSelected:Bool = false;
	var glow:Array<FlxSprite> = [];
	var pulseTime:Float = 0;

	public function new(weekFile:String, weekName:String, displayName:String = '')
	{
		super();
		this.weekFile = weekFile;

		for (i in 0...3)
		{
			var pad:Int = 5 + i * 5;
			var g:FlxSprite = new FlxSprite(-pad, -pad).makeGraphic(CARD_WIDTH + pad * 2, CARD_HEIGHT + pad * 2, FlxColor.WHITE);
			g.color = MenuTheme.PANEL_BORDER_BRIGHT;
			g.alpha = 0;
			add(g);
			glow.push(g);
		}

		border = new FlxSprite().makeGraphic(CARD_WIDTH, CARD_HEIGHT, FlxColor.WHITE);
		border.color = MenuTheme.PANEL_BORDER_DIM;
		add(border);

		fill = new FlxSprite(BORDER, BORDER).makeGraphic(CARD_WIDTH - BORDER * 2, CARD_HEIGHT - BORDER * 2, FlxColor.WHITE);
		fill.color = MenuTheme.PANEL_FILL;
		fill.alpha = 0.68;
		add(fill);

		accentBar = new FlxSprite(BORDER, BORDER).makeGraphic(6, CARD_HEIGHT - BORDER * 2, FlxColor.WHITE);
		accentBar.color = MenuTheme.PANEL_BORDER_BRIGHT;
		accentBar.visible = false;
		add(accentBar);

		bannerItem = new MenuItem(0, 0, weekName);
		var maxW:Float = CARD_WIDTH - 40;
		var maxH:Float = CARD_HEIGHT - 30;
		if (bannerItem.width > 0 && bannerItem.height > 0)
		{
			var scale:Float = Math.min(maxW / bannerItem.width, maxH / bannerItem.height);
			if (scale < 1)
			{
				bannerItem.setGraphicSize(Math.floor(bannerItem.width * scale), Math.floor(bannerItem.height * scale));
				bannerItem.updateHitbox();
			}
		}
		bannerItem.x = (CARD_WIDTH - bannerItem.width) / 2;
		bannerItem.y = (CARD_HEIGHT - bannerItem.height) / 2;
		bannerItem.scrollFactor.set();
		add(bannerItem);

		// Vortex Engine: a mod week with no storymenu/<week>.png banner used to be an empty card. Show its name instead.
		var hasBanner:Bool = bannerItem.graphic != null && bannerItem.frameWidth > 2 && bannerItem.frameHeight > 2;
		if (!hasBanner)
		{
			bannerItem.visible = false;
			var label:String = displayName.length > 0 ? displayName : weekFile;
			titleFallback = new FlxText(BORDER + 16, 0, CARD_WIDTH - 40, label.toUpperCase(), 40);
			titleFallback.setFormat(MenuTheme.font(), 40, MenuTheme.TEXT_BRIGHT, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			titleFallback.borderSize = 2;
			titleFallback.y = (CARD_HEIGHT - titleFallback.height) / 2;
			add(titleFallback);
		}

		// Vortex Engine: a separate overlay for the "locked" dimming, rather than tinting
		// bannerItem.color directly -- MenuItem already uses .color for its own isFlashing
		// effect (set every frame while flashing), so touching it here would fight that.
		lockedOverlay = new FlxSprite(BORDER, BORDER).makeGraphic(CARD_WIDTH - BORDER * 2, CARD_HEIGHT - BORDER * 2, FlxColor.BLACK);
		lockedOverlay.alpha = 0.55;
		lockedOverlay.visible = false;
		add(lockedOverlay);

		lockIcon = new FlxSprite(CARD_WIDTH - 44, CARD_HEIGHT - 44);
		lockIcon.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets'); // same atlas the original lock icon used
		lockIcon.animation.addByPrefix('lock', 'lock');
		lockIcon.animation.play('lock');
		lockIcon.setGraphicSize(30, 30);
		lockIcon.updateHitbox();
		lockIcon.scrollFactor.set();
		lockIcon.visible = false;
		add(lockIcon);

		setLocked(false);
		setSelected(false);
	}

	/** Vortex Engine 0.5: Psych Classic theme - only the week banner (and lock), no card frame. */
	public var classicMode(default, null):Bool = false;
	public function setClassic(on:Bool):Void
	{
		classicMode = on;
		if (titleFallback != null) titleFallback.color = on ? FlxColor.WHITE : MenuTheme.TEXT_BRIGHT;
	}

	public function setLocked(locked:Bool):Void
	{
		lockIcon.visible = locked;
		lockedOverlay.visible = locked;
	}

	public function setSelected(sel:Bool):Void
	{
		wantSelected = sel;
		accentBar.visible = true;
	}

	public function selectNudge():Float
		return highlight * 26;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		pulseTime += elapsed;
		var target:Float = wantSelected ? 1 : 0;
		highlight += (target - highlight) * Math.min(1, elapsed * 12);
		if (Math.abs(target - highlight) < 0.002) highlight = target;

		var ga:Float = alpha;
		var pulse:Float = 0.5 + 0.5 * Math.sin(pulseTime * 3.2);
		if (classicMode)
		{
			border.alpha = fill.alpha = accentBar.alpha = 0;
			for (g in glow) g.alpha = 0;
			bannerItem.alpha = ga;
			if (titleFallback != null) titleFallback.alpha = ga;
			lockedOverlay.alpha = 0;
			lockIcon.alpha = ga;
			return;
		}
		border.color = FlxColor.interpolate(MenuTheme.PANEL_BORDER_DIM, MenuTheme.PANEL_BORDER_BRIGHT, highlight);
		// Vortex Engine: every member's alpha is set from the card's alpha each frame. Changing a group's alpha
		// scales its members by new/old, which drifts when Story Mode fades a card close to 0 and back.
		border.alpha = ga;
		bannerItem.alpha = ga;
		if (titleFallback != null) titleFallback.alpha = ga;
		lockedOverlay.alpha = 0.55 * ga;
		lockIcon.alpha = ga;
		fill.alpha = (0.6 + 0.26 * highlight) * ga;
		accentBar.alpha = highlight * ga;
		for (i in 0...glow.length)
			glow[i].alpha = highlight * (0.05 + 0.04 * pulse) * (1 - i * 0.22) * ga;
	}
}
