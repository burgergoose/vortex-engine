package backend;

import haxe.Json;
import lime.utils.Assets;

import objects.Note;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
}

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Float;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = 'psych_v1';

	public static function convert(songJson:Dynamic) // Convert old charts to psych_v1 format
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.notes == null) songJson.notes = [];
		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];
				if(sec.sectionNotes == null) sec.sectionNotes = [];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		var sectionsData:Array<SwagSection> = songJson.notes;
		if(sectionsData == null) return;

		for (section in sectionsData)
		{
			if(section.sectionNotes == null) section.sectionNotes = [];
			var beats:Null<Float> = cast section.sectionBeats;
			if (beats == null || Math.isNaN(beats))
			{
				section.sectionBeats = 4;
				if(Reflect.hasField(section, 'lengthInSteps')) Reflect.deleteField(section, 'lengthInSteps');
			}

			for (note in section.sectionNotes)
			{
				var gottaHitNote:Bool = (note[1] < 4) ? section.mustHitSection : !section.mustHitSection;
				note[1] = (note[1] % 4) + (gottaHitNote ? 0 : 4);

				if(!Std.isOfType(note[3], String))
				{
					//compatibility with Week 7 and 0.1-0.3 psych charts
					// Vortex Engine: old/foreign charts may have no 4th value or a true/false there; that used to crash the loader
					var oldType:Dynamic = note[3];
					note[3] = (Std.isOfType(oldType, Int) && oldType >= 0 && oldType < Note.defaultNoteTypes.length) ? Note.defaultNoteTypes[oldType] : '';
				}
			}
		}
	}

	public static var chartPath:String;
	public static var loadedSongName:String;
	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		PlayState.SONG = getChart(jsonInput, folder);
		loadedSongName = folder;
		chartPath = _lastPath;
		#if windows
		// prevent any saving errors by fixing the path on Windows (being the only OS to ever use backslashes instead of forward slashes for paths)
		chartPath = chartPath.replace('/', '\\');
		#end
		StageData.loadDirectory(PlayState.SONG);
		return PlayState.SONG;
	}

	static var _lastPath:String;
	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		var rawData:String = null;
		
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		_lastPath = Paths.json('$formattedFolder/$formattedSong');

		#if MODS_ALLOWED
		if(FileSystem.exists(_lastPath))
			rawData = File.getContent(_lastPath);
		else
		#end
			rawData = Assets.getText(_lastPath);

		return rawData != null ? parseJSON(rawData, jsonInput) : null;
	}

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var songJson:SwagSong = cast Json.parse(rawData);
		if(Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if(subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if(convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if(fmt == null) fmt = songJson.format = 'unknown';

			switch(convertTo)
			{
				case 'psych_v1':
					if(!fmt.startsWith('psych_v1')) //Convert to Psych 1.0 format
					{
						trace('converting chart $nameForError with format $fmt to psych_v1 format...');
						songJson.format = 'psych_v1_convert';
						convert(songJson);
					}
			}
		}
		sanitize(songJson);
		return songJson;
	}

	/** Vortex Engine: charts from other engines / hand edits often leave fields out. Fill them in so the song loads instead of crashing. **/
	public static function sanitize(songJson:SwagSong):Void
	{
		if(songJson == null) return;
		var raw:Dynamic = songJson;
		if(songJson.notes == null) songJson.notes = [];
		if(songJson.events == null) songJson.events = [];
		else
		{
			// drop broken events ([time, [[name, v1, v2], ...]]) rather than crashing while the song is being built
			var e:Int = songJson.events.length;
			while(e-- > 0)
			{
				var ev:Dynamic = songJson.events[e];
				if(ev == null || !Std.isOfType(ev, Array) || ev.length < 2 || !Std.isOfType(ev[1], Array)) songJson.events.splice(e, 1);
			}
		}
		if(raw.bpm == null || Math.isNaN(raw.bpm) || raw.bpm <= 0) songJson.bpm = 100;
		if(raw.speed == null || Math.isNaN(raw.speed) || raw.speed <= 0) songJson.speed = 1;
		if(raw.offset == null) songJson.offset = 0;
		if(raw.needsVoices == null) songJson.needsVoices = true;
		if(songJson.player1 == null || songJson.player1.length < 1) songJson.player1 = 'bf';
		if(songJson.player2 == null || songJson.player2.length < 1) songJson.player2 = 'dad';
		if(songJson.gfVersion == null || songJson.gfVersion.length < 1) songJson.gfVersion = 'gf';

		for (section in songJson.notes)
		{
			if(section.sectionNotes == null) section.sectionNotes = [];
			var rs:Dynamic = section;
			if(rs.sectionBeats == null || Math.isNaN(rs.sectionBeats) || rs.sectionBeats <= 0) section.sectionBeats = 4;
			if(rs.mustHitSection == null) section.mustHitSection = true;

			var i:Int = section.sectionNotes.length;
			while(i-- > 0)
			{
				var n:Array<Dynamic> = section.sectionNotes[i];
				if(n == null || n.length < 3 || n[0] == null || n[1] == null) { section.sectionNotes.splice(i, 1); continue; }
				if(n[2] == null) n[2] = 0;
			}
		}
	}
}
