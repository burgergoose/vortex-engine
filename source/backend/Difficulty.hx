package backend;

class Difficulty
{
	public static final defaultList:Array<String> = [
		'Easy',
		'Normal',
		'Hard'
	];
	private static final defaultDifficulty:String = 'Normal'; //The chart that has no postfix and starting difficulty on Freeplay/Story Mode

	public static var list:Array<String> = [];

	inline public static function getFilePath(num:Null<Int> = null)
	{
		if(num == null) num = PlayState.storyDifficulty;

		var filePostfix:String = list[num];
		if(filePostfix != null && Paths.formatToSongPath(filePostfix) != Paths.formatToSongPath(defaultDifficulty))
			filePostfix = '-' + filePostfix;
		else
			filePostfix = '';
		return Paths.formatToSongPath(filePostfix);
	}

	inline public static function loadFromWeek(week:WeekData = null)
	{
		if(week == null) week = WeekData.getCurrentWeek();

		var diffStr:String = week.difficulties;
		if(diffStr != null && diffStr.length > 0)
		{
			var diffs:Array<String> = diffStr.trim().split(',');
			var i:Int = diffs.length - 1;
			while (i > 0)
			{
				if(diffs[i] != null)
				{
					diffs[i] = diffs[i].trim();
					if(diffs[i].length < 1) diffs.remove(diffs[i]);
				}
				--i;
			}

			if(diffs.length > 0 && diffs[0].length > 0)
				list = diffs;
		}
		else resetList();
	}

	inline public static function resetList()
	{
		list = defaultList.copy();
	}

	inline public static function copyFrom(diffs:Array<String>)
	{
		list = diffs.copy();
	}

	inline public static function getString(?num:Null<Int> = null, ?canTranslate:Bool = true):String
	{
		var diffName:String = list[num == null ? PlayState.storyDifficulty : num];
		if(diffName == null) diffName = defaultDifficulty;
		return canTranslate ? Language.getPhrase('difficulty_$diffName', diffName) : diffName;
	}

	/**
	 * Vortex Engine addition. Freeplay / Story Mode only offer Normal now, but plenty of mods ship ONLY
	 * <song>-hard.json (or -easy) and never made a plain <song>.json. Looking for a Normal chart that doesn't
	 * exist made such songs fail to open (Story Mode failed without saying anything). This returns `preferred`
	 * when its chart exists, otherwise the first difficulty in the list that does have a chart (Hard before
	 * Easy), otherwise `preferred` unchanged so the usual "missing chart" error still names the real file.
	 */
	public static function pickAvailable(song:String, preferred:Int):Int
	{
		try
		{
			var folder:String = Paths.formatToSongPath(song);
			var order:Array<Int> = [preferred];
			var i:Int = list.length - 1;
			while (i >= 0)
			{
				if (i != preferred) order.push(i);
				i--;
			}
			for (idx in order)
			{
				var path:String = Paths.json('$folder/$folder' + getFilePath(idx));
				#if sys
				if (sys.FileSystem.exists(path)) return idx;
				#end
				if (openfl.utils.Assets.exists(path)) return idx;
			}
		}
		catch (e:Dynamic) {}
		return preferred;
	}

	inline public static function getDefault():String
	{
		return defaultDifficulty;
	}
}