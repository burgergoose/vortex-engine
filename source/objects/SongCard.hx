package objects;

import backend.Highscore;
import backend.SongRank;
import flixel.util.FlxColor;

/**
 * VORTEX ENGINE ADDITION.
 *
 * One row in the redesigned Freeplay list: a self-contained "glass" card
 * with the opponent's icon, the song name, a secondary line for best
 * score/accuracy, and a rank badge on the far right (per SongRank.hx).
 *
 * Deliberately sharp-cornered rather than rounded -- a solid-color sprite
 * scaled up (the same "makeGraphic(1,1,WHITE) then .color = ..." trick
 * PsychUIBox already uses) is simple, cheap, and proven in this codebase;
 * a soft glowing gradient border done "properly" would mean drawing into
 * a BitmapData per card, which isn't worth the extra risk for something
 * built potentially hundreds of times over. The one place this project
 * uses that heavier drawing approach is CosmicBackground, where it only
 * has to happen twice (Freeplay + Story Mode), not once per song.
 *
 * Icons are positioned manually (icon.sprTracker is deliberately left
 * null) rather than via HealthIcon's built-in tracker, since that offset
 * is tuned for the old Alphabet-text layout, not a fixed card.
 */
class SongCard extends FlxSpriteGroup
{
	public static inline var CARD_WIDTH:Int = 860;
	public static inline var CARD_HEIGHT:Int = 92;
	static inline var BORDER:Int = 2;
	static inline var ICON_SIZE:Int = 64;

	public var songName(default, null):String;
	public var songCharacter(default, null):String;

	var border:FlxSprite;
	var fill:FlxSprite;
	var accentBar:FlxSprite;
	var icon:HealthIcon;
	var nameText:FlxText;
	var statsText:FlxText;
	var rankBadge:FlxSprite;
	var rankText:FlxText;

	var diffIndex:Int;

	// Vortex Engine (UI polish): eased 0..1 "how selected is this card" value + soft halo behind the border
	public var highlight(default, null):Float = 0;
	var wantSelected:Bool = false;
	var glow:Array<FlxSprite> = [];
	var pulseTime:Float = 0;

	public function new(songName:String, songCharacter:String, diffIndex:Int)
	{
		super();
		this.songName = songName;
		this.songCharacter = songCharacter;
		this.diffIndex = diffIndex;

		for (i in 0...3)
		{
			var pad:Int = 5 + i * 5;
			var g:FlxSprite = new FlxSprite(-pad, -pad).makeGraphic(CARD_WIDTH + pad * 2, CARD_HEIGHT + pad * 2, FlxColor.WHITE);
			g.color = CosmicBackground.PANEL_BORDER_BRIGHT;
			g.alpha = 0;
			add(g);
			glow.push(g);
		}

		border = new FlxSprite().makeGraphic(CARD_WIDTH, CARD_HEIGHT, FlxColor.WHITE);
		border.color = CosmicBackground.PANEL_BORDER_DIM;
		add(border);

		fill = new FlxSprite(BORDER, BORDER).makeGraphic(CARD_WIDTH - BORDER * 2, CARD_HEIGHT - BORDER * 2, FlxColor.WHITE);
		fill.color = CosmicBackground.PANEL_FILL;
		fill.alpha = 0.72;
		add(fill);

		accentBar = new FlxSprite(BORDER, BORDER).makeGraphic(5, CARD_HEIGHT - BORDER * 2, FlxColor.WHITE);
		accentBar.color = CosmicBackground.PANEL_BORDER_BRIGHT;
		accentBar.visible = false;
		add(accentBar);

		icon = new HealthIcon(songCharacter, false);
		// Scale by the longest frame side, then undo HealthIcon's offset tuning (it assumes an unscaled
		// 150px icon) so x/y below really are this icon's top-left corner.
		var iconScale:Float = ICON_SIZE / Math.max(icon.frameWidth, icon.frameHeight);
		icon.scale.set(iconScale, iconScale);
		icon.updateHitbox();
		icon.offset.set(-0.5 * (icon.width - icon.frameWidth), -0.5 * (icon.height - icon.frameHeight));
		icon.antialiasing = ClientPrefs.data.antialiasing;
		icon.x = 22;
		icon.y = (CARD_HEIGHT - ICON_SIZE) / 2;
		icon.scrollFactor.set();
		add(icon);

		var textX:Float = 22 + ICON_SIZE + 18;
		var textWidth:Float = CARD_WIDTH - textX - 96;

		nameText = new FlxText(textX, 14, textWidth, songName.toUpperCase(), 24);
		nameText.setFormat(Paths.font('vcr.ttf'), 24, CosmicBackground.TEXT_BRIGHT, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(nameText);

		statsText = new FlxText(textX, 50, textWidth, '', 16);
		statsText.setFormat(Paths.font('vcr.ttf'), 16, CosmicBackground.TEXT_DIM, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(statsText);

		var badgeSize:Int = 54;
		rankBadge = new FlxSprite(CARD_WIDTH - badgeSize - 20, (CARD_HEIGHT - badgeSize) / 2).makeGraphic(badgeSize, badgeSize, FlxColor.WHITE);
		add(rankBadge);

		rankText = new FlxText(rankBadge.x, rankBadge.y, badgeSize, '', 26);
		rankText.setFormat(Paths.font('vcr.ttf'), 26, FlxColor.BLACK, CENTER, FlxTextBorderStyle.NONE);
		rankText.y = rankBadge.y + (badgeSize - rankText.height) / 2;
		add(rankText);

		refreshStats();
		setSelected(false);
	}

	/** Re-reads this song's saved stats. Call after anything that could've changed them (e.g. a score reset). */
	public function refreshStats():Void
	{
		var noAttempt:Bool = SongRank.hasNoAttempt(songName, diffIndex);
		var score:Int = Highscore.getScore(songName, diffIndex);
		var acc:Float = Highscore.getRating(songName, diffIndex);
		var rank:String = noAttempt ? '-' : SongRank.fromAccuracy(acc);

		statsText.text = noAttempt ? 'Not played yet' : ('Best ' + score + '  |  ' + Std.string(CoolUtil.floorDecimal(acc * 100, 2)) + '%');

		rankText.text = rank;
		rankBadge.color = SongRank.colorFor(rank);
	}

	public function setSelected(sel:Bool):Void
	{
		wantSelected = sel;
		accentBar.visible = true;
	}

	/** Horizontal nudge Freeplay adds to the card's x so the selected card slides out of the list a little. */
	public function selectNudge():Float
		return highlight * 30;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		pulseTime += elapsed;
		var target:Float = wantSelected ? 1 : 0;
		highlight += (target - highlight) * Math.min(1, elapsed * 12);
		if (Math.abs(target - highlight) < 0.002) highlight = target;

		var pulse:Float = 0.5 + 0.5 * Math.sin(pulseTime * 3.2);
		border.color = FlxColor.interpolate(CosmicBackground.PANEL_BORDER_DIM, CosmicBackground.PANEL_BORDER_BRIGHT, highlight);
		var ga:Float = alpha; // the group's own alpha (Freeplay fades distant cards) -- members multiply by it
		fill.alpha = (0.68 + 0.22 * highlight) * ga;
		nameText.alpha = (0.78 + 0.22 * highlight) * ga;
		statsText.alpha = (0.5 + 0.5 * highlight) * ga;
		accentBar.alpha = highlight * ga;
		accentBar.scale.y = 1;
		for (i in 0...glow.length)
			glow[i].alpha = highlight * (0.05 + 0.04 * pulse) * (1 - i * 0.22) * ga;

		// icon bounces a touch when selected
		var iconScale:Float = ICON_SIZE / Math.max(icon.frameWidth, icon.frameHeight);
		var s:Float = iconScale * (1 + highlight * (0.08 + 0.04 * pulse));
		icon.scale.set(s, s);
		icon.updateHitbox();
		icon.offset.set(-0.5 * (icon.width - icon.frameWidth), -0.5 * (icon.height - icon.frameHeight));
	}
}
