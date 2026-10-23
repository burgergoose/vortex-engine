package objects;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

/**
 * VORTEX ENGINE ADDITION - "Little Buddies" for the chart editor.
 *
 * Idea and artwork: FPS Plus by ThatRozebudDude (https://github.com/ThatRozebudDude/FPS-Plus-Public).
 * The two tiny characters (and their little stage) sing along in real time with the notes you placed
 * while the song plays in the chart editor: the right one for the player's notes, the left one for the opponent's.
 * FPS Plus is free for NON-COMMERCIAL use only; the pictures in images/editors/buddies/ come from it.
 */
class ChartBuddy extends FlxSprite
{
	var holdMs:Float = 0;
	var current:String = 'idle';
	public var playing:Bool = false;

	public function new(x:Float, y:Float, image:String, swapSides:Bool)
	{
		super(x, y);
		loadGraphic(Paths.image(image), true, 300, 256);
		antialiasing = false;

		var left:Array<Int> = [3, 4, 5];
		var down:Array<Int> = [6, 7, 8];
		var up:Array<Int> = [9, 10, 11];
		var right:Array<Int> = [12, 13, 14];
		if(swapSides) { var t = left; left = right; right = t; } // the boyfriend buddy faces the other way

		animation.add('idle', [0, 1], 12, true);
		var sets:Array<Array<Int>> = [left, down, up, right];
		for (i in 0...4)
		{
			animation.add('sing$i', sets[i], 12, false);
			animation.add('hold$i', [sets[i][1], sets[i][2]], 12, true);
		}
		animation.play('idle');
	}

	public function sing(direction:Int, sustainMs:Float)
	{
		direction = direction % 4;
		current = 'sing$direction';
		animation.play(current, true);
		holdMs = Math.max(sustainMs, 0);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(!playing) { if(current != 'idle') { current = 'idle'; animation.play('idle'); } holdMs = 0; return; }

		if(holdMs > 0) holdMs -= elapsed * 1000;
		if(current.startsWith('sing') && animation.curAnim != null && animation.curAnim.finished)
		{
			if(holdMs > 0) { current = 'hold' + current.substr(4); animation.play(current, true); }
			else { current = 'idle'; animation.play('idle', true); }
		}
		else if(current.startsWith('hold') && holdMs <= 0)
		{
			current = 'idle';
			animation.play('idle', true);
		}
	}
}

class ChartBuddies extends FlxSpriteGroup
{
	public var guy:ChartBuddy; // plays the opponent's notes
	public var bf:ChartBuddy;  // plays the player's notes

	public function new(x:Float, y:Float)
	{
		super();
		var stage:FlxSprite = new FlxSprite(x, y).loadGraphic(Paths.image('editors/buddies/lilStage'));
		stage.antialiasing = false;
		add(stage);

		guy = new ChartBuddy(x, y, 'editors/buddies/lilGuy', false);
		bf = new ChartBuddy(x, y, 'editors/buddies/lilBf', true);
		add(guy);
		add(bf);

		var label:FlxText = new FlxText(x - 20, y + 262, 300, 'LITTLE BUDDIES  -  art by FPS Plus', 10);
		label.alignment = CENTER;
		label.color = 0xFF9C8CFF;
		add(label);
		scrollFactor.set();
	}

	public function setPlaying(value:Bool)
	{
		guy.playing = bf.playing = value;
	}

	public function hit(playerNote:Bool, direction:Int, sustainMs:Float)
	{
		(playerNote ? bf : guy).sing(direction, sustainMs);
	}
}
