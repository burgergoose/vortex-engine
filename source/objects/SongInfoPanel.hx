package objects;

import backend.Highscore;
import backend.SongRank;
import flixel.util.FlxColor;

/**
 * VORTEX ENGINE ADDITION.
 *
 * Freeplay's right-hand panel: the selected song's icon, name, week and mod,
 * and its saved stats (best score, accuracy, rank, best combo, misses, cleared).
 * Read-only: it never writes scores, it only shows what Highscore has saved.
 */
class SongInfoPanel extends GlassPanel
{
	public static inline var PANEL_W:Int = 460;
	public static inline var PANEL_H:Int = 520;
	static inline var ICON_SIZE:Int = 120;

	var icon:HealthIcon;
	var nameText:FlxText;
	var weekText:FlxText;
	var modText:FlxText;
	var rankBadge:FlxSprite;
	var rankText:FlxText;
	var rankLabel:FlxText;
	var values:Map<String, FlxText> = [];
	var accBarBg:FlxSprite;
	var accBar:FlxSprite;
	var accBarW:Int;
	var noteText:FlxText;

	var songName:String = '';
	var diff:Int = 0;
	var shownScore:Int = -1;
	var shownRating:Float = -1;

	public function new(x:Float, y:Float)
	{
		super(x, y, PANEL_W, PANEL_H);

		var textX:Float = 24 + ICON_SIZE + 18;
		var textW:Float = PANEL_W - textX - 112;
		nameText = makeText(textX, 30, textW, 28, MenuTheme.TEXT_BRIGHT);
		weekText = makeText(textX, 0, textW, 16, MenuTheme.ACCENT_CYAN);
		modText = makeText(textX, 0, textW, 14, MenuTheme.TEXT_DIM);

		var badge:Int = 80;
		rankBadge = new FlxSprite(PANEL_W - badge - 24, 34).makeGraphic(badge, badge, FlxColor.WHITE);
		add(rankBadge);
		rankText = new FlxText(rankBadge.x - x, 0, badge, '', 48);
		rankText.setFormat(MenuTheme.font(), 48, FlxColor.BLACK, CENTER);
		rankText.y = 34 + (badge - rankText.height) / 2;
		add(rankText);
		rankLabel = makeText(PANEL_W - badge - 24, 34 + badge + 4, badge, 12, MenuTheme.TEXT_DIM, CENTER);
		rankLabel.text = 'RANK';

		var line:FlxSprite = new FlxSprite(24, 176).makeGraphic(PANEL_W - 48, 2, FlxColor.WHITE);
		line.color = MenuTheme.PANEL_BORDER_DIM;
		add(line);

		var cellW:Float = (PANEL_W - 48) / 2;
		var rows:Array<Array<String>> = [['BEST SCORE', 'ACCURACY'], ['BEST COMBO', 'MISSES'], ['STATUS', 'SONG']];
		for (r in 0...rows.length)
			for (c in 0...2)
			{
				var cx:Float = 24 + c * cellW;
				var cy:Float = 194 + r * 80;
				makeText(cx, cy, cellW - 10, 14, MenuTheme.TEXT_DIM).text = rows[r][c];
				values.set(rows[r][c], makeText(cx, cy + 18, cellW - 10, 26, MenuTheme.TEXT_BRIGHT));
			}

		accBarW = PANEL_W - 48;
		makeText(24, 446, accBarW, 14, MenuTheme.TEXT_DIM).text = 'ACCURACY';
		accBarBg = new FlxSprite(24, 466).makeGraphic(accBarW, 10, FlxColor.WHITE);
		accBarBg.color = MenuTheme.PANEL_BORDER_DIM;
		add(accBarBg);
		accBar = new FlxSprite(24, 466).makeGraphic(accBarW, 10, FlxColor.WHITE);
		accBar.origin.set(0, 0);
		add(accBar);

		noteText = makeText(24, 486, PANEL_W - 48, 12, MenuTheme.TEXT_DIM);
	}

	function makeText(tx:Float, ty:Float, w:Float, size:Int, color:Int, align:FlxTextAlign = LEFT):FlxText
	{
		var t:FlxText = new FlxText(tx, ty, w, '', size);
		t.setFormat(MenuTheme.font(), size, color, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(t);
		return t;
	}

	/** Shows a song. Call with Mods.currentModDirectory already set to the song's mod (the icon is loaded from it). */
	public function showSong(song:String, character:String, diffIndex:Int, color:Int, weekName:String, modName:String, index:Int, total:Int):Void
	{
		songName = song;
		diff = diffIndex;
		setAccent(color);

		if (icon == null || icon.getCharacter() != character)
		{
			if (icon != null)
			{
				remove(icon, true);
				icon.destroy();
			}
			icon = new HealthIcon(character, false);
			icon.autoAdjustOffset = false;
			var s:Float = ICON_SIZE / Math.max(icon.frameWidth, icon.frameHeight);
			icon.scale.set(s, s);
			icon.updateHitbox();
			icon.offset.set(-0.5 * (icon.width - icon.frameWidth), -0.5 * (icon.height - icon.frameHeight));
			icon.setPosition(24, 30);
			add(icon);
		}

		nameText.text = song.toUpperCase();
		nameText.size = nameText.text.length > 14 ? 22 : 28;
		weekText.text = weekName.length > 0 ? 'Week: ' + weekName : '';
		weekText.y = nameText.y + nameText.height + 6;
		modText.text = modName;
		modText.y = weekText.y + weekText.height + 4;

		var noAttempt:Bool = SongRank.hasNoAttempt(song, diffIndex);
		var acc:Float = Highscore.getRating(song, diffIndex);
		var rank:String = noAttempt ? '-' : SongRank.fromAccuracy(acc);
		rankText.text = rank;
		rankBadge.color = SongRank.colorFor(rank);

		var misses:Int = Highscore.getMisses(song, diffIndex);
		var cleared:Bool = Highscore.isCompleted(song, diffIndex);
		values.get('BEST COMBO').text = noAttempt ? '-' : Std.string(Highscore.getMaxCombo(song, diffIndex));
		values.get('MISSES').text = noAttempt ? '-' : Std.string(misses);
		var status:String = noAttempt ? 'NEW' : (cleared ? (misses == 0 ? 'FULL COMBO' : 'CLEARED') : 'PLAYED');
		values.get('STATUS').text = status;
		values.get('STATUS').color = noAttempt ? MenuTheme.ACCENT_CYAN : (cleared ? 0xFF6BFF95 : MenuTheme.TEXT_BRIGHT);
		values.get('SONG').text = '${index + 1} / $total';
		noteText.text = noAttempt ? 'You haven\'t played this song yet.' : '';

		shownScore = -1;
		shownRating = -1;
	}

	/** Score and accuracy count up/down (FreeplayState passes its lerpScore / lerpRating every frame). */
	public function setLive(score:Int, rating:Float):Void
	{
		if (score != shownScore)
		{
			shownScore = score;
			values.get('BEST SCORE').text = Std.string(score);
		}
		if (rating != shownRating)
		{
			shownRating = rating;
			values.get('ACCURACY').text = Std.string(CoolUtil.floorDecimal(rating * 100, 2)) + '%';
			var r:Float = Math.max(0, Math.min(1, rating));
			accBar.scale.x = Math.max(0.0001, r);
			accBar.color = SongRank.colorFor(r > 0 ? SongRank.fromAccuracy(r) : '-');
		}
	}
}
