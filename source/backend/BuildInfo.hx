package backend;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** VORTEX ENGINE ADDITION (0.5) - when and from which source commit this executable was compiled (for the build check). */
class BuildInfo
{
	public static macro function date():ExprOf<String>
	{
		return macro $v{Date.now().toString()};
	}

	public static macro function commit():ExprOf<String>
	{
		var c:String = 'unknown';
		try
		{
			var p = new sys.io.Process('git', ['rev-parse', '--short', 'HEAD']);
			var out:String = StringTools.trim(p.stdout.readAll().toString());
			if (p.exitCode() == 0 && out.length > 0) c = out;
			p.close();
		}
		catch (e:Dynamic) {}
		return macro $v{c};
	}
}
