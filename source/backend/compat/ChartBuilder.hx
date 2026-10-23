package backend.compat;

typedef TimedNote = {time:Float, column:Int, length:Float, type:String, ?singer:Int};
typedef BpmChange = {time:Float, bpm:Float};
typedef CamFocus = {time:Float, who:Int}; // 0 = player, 1 = opponent, 2 = girlfriend
typedef TimedEvent = {time:Float, name:String, v1:String, v2:String};

/**
 * VORTEX ENGINE ADDITION - builds a Psych 1.0 ("psych_v1") chart from time-based data, which is how V-Slice and
 * Codename store songs. Note times are kept exactly (Psych notes carry absolute times); sections only hold the
 * camera focus and BPM. A BPM change in the middle of a 4-beat section ends that section early (Psych allows
 * fractional sectionBeats), so the beat grid stays exact after the change.
 */
class ChartBuilder
{
	public static function build(songId:String, notes:Array<TimedNote>, bpms:Array<BpmChange>, focus:Array<CamFocus>, events:Array<TimedEvent>, info:Dynamic, report:CompatReport):Dynamic
	{
		bpms = bpms.filter(function(b) return b != null && b.bpm > 0 && !Math.isNaN(b.time));
		bpms.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
		focus.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
		notes.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

		var startBpm:Float = (bpms.length > 0 && bpms[0].time <= 1) ? bpms[0].bpm : CompatUtil.num(info.bpm, 100);
		var endTime:Float = 0;
		for (n in notes) endTime = Math.max(endTime, n.time + Math.max(0, n.length));
		for (e in events) endTime = Math.max(endTime, e.time);
		for (f in focus) endTime = Math.max(endTime, f.time);
		for (b in bpms) endTime = Math.max(endTime, b.time); // a BPM change after the last note still gets its section

		var sections:Array<Dynamic> = [];
		var cur:Float = 0;
		var bpm:Float = startBpm;
		var idx:Int = 0;
		var noteIdx:Int = 0;
		var guard:Int = 0;
		var offGrid:Int = 0;
		while ((cur <= endTime || sections.length < 1) && guard++ < 100000)
		{
			var changed:Bool = false;
			while (idx < bpms.length && bpms[idx].time <= cur + 1)
			{
				if (bpms[idx].bpm != bpm) changed = true;
				bpm = bpms[idx].bpm;
				idx++;
			}
			var len:Float = 4 * 60000 / bpm;
			var beats:Float = 4;
			if (idx < bpms.length && bpms[idx].time < cur + len - 1)
			{
				len = bpms[idx].time - cur;
				beats = len * bpm / 60000;
			}

			// the camera at the start of the section; moves later inside it become "Focus Camera" events (exact timing)
			var who:Int = focusAt(focus, cur + 2);
			var inside:Int = who;
			for (f in focus)
				if (f.time > cur + 2 && f.time < cur + len - 2 && f.who != inside)
				{
					events.push({time: f.time, name: 'Focus Camera', v1: f.who == 0 ? 'bf' : (f.who == 2 ? 'gf' : 'dad'), v2: ''});
					inside = f.who;
					offGrid++;
				}

			var secNotes:Array<Dynamic> = [];
			while (noteIdx < notes.length && notes[noteIdx].time < cur + len)
			{
				var n:TimedNote = notes[noteIdx++];
				var arr:Array<Dynamic> = [round(n.time), n.column, round(Math.max(0, n.length)), n.type != null ? n.type : ''];
				if (n.singer != null && n.singer >= 0) arr.push(n.singer);
				secNotes.push(arr);
			}

			var sec:Dynamic = {
				sectionNotes: secNotes,
				sectionBeats: Math.round(beats * 10000) / 10000,
				mustHitSection: who == 0,
				gfSection: who == 2,
				altAnim: false
			};
			if (changed && sections.length > 0) { sec.changeBPM = true; sec.bpm = bpm; }
			sections.push(sec);
			cur += len;
		}
		if (offGrid > 0) report.note('$songId: $offGrid camera moves happen in the middle of a section; they became "Focus Camera" events so the camera moves at the right time.');

		var grouped:Array<Dynamic> = [];
		events.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
		for (e in events)
		{
			var t:Float = round(e.time);
			var last:Array<Dynamic> = grouped.length > 0 ? grouped[grouped.length - 1] : null;
			var entry:Array<Dynamic> = [e.name, e.v1 != null ? e.v1 : '', e.v2 != null ? e.v2 : ''];
			if (last != null && last[0] == t) (last[1] : Array<Dynamic>).push(entry);
			else grouped.push([t, [entry]]);
		}

		var chart:Dynamic = {
			song: songId,
			notes: sections,
			events: grouped,
			bpm: startBpm,
			needsVoices: CompatUtil.bool(info.needsVoices, true),
			speed: CompatUtil.num(info.speed, 1),
			offset: CompatUtil.num(info.offset, 0),
			player1: CompatUtil.str(info.player1, 'bf'),
			player2: CompatUtil.str(info.player2, 'dad'),
			gfVersion: CompatUtil.str(info.gfVersion, 'gf'),
			stage: CompatUtil.str(info.stage, 'stage'),
			format: 'psych_v1_convert',
			vortexSource: CompatUtil.str(info.source, '')
		};
		if (info.strumLines != null) chart.strumLines = info.strumLines;
		if (info.arrowSkin != null) chart.arrowSkin = info.arrowSkin;
		return chart;
	}

	static function focusAt(list:Array<CamFocus>, t:Float):Int
	{
		// Vortex Engine 0.6: before the first camera event the camera is on the opponent (V-Slice starts it on dad
		// and Codename on strumline 0); a chart without camera events keeps it there the whole song
		var who:Int = 1;
		for (f in list)
		{
			if (f.time <= t) who = f.who;
			else break;
		}
		return who;
	}

	static inline function round(v:Float):Float
		return Math.round(v * 1000) / 1000;

	/** ms of a number of steps at a BPM (V-Slice / Codename give tween lengths in steps). */
	public static function stepsToSeconds(steps:Float, bpm:Float):Float
		return steps * (60 / bpm) / 4;

	public static function bpmAt(bpms:Array<BpmChange>, t:Float, def:Float):Float
	{
		var b:Float = def;
		for (c in bpms) if (c.time <= t) b = c.bpm;
		return b;
	}
}
