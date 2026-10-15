package backend;

/**
 * VORTEX ENGINE: This file has been neutralized for the MinGW cross-compiled build.
 *
 * The original Native.hx contained:
 *   - DPI awareness setup (SetProcessDPIAware / SetProcessDpiAwarenessContext)
 *   - Dark title bar via DWM attribute hacks
 *   - A custom EnumWindows callback to find the game's own HWND
 *   - FlxColor-based HWND caption/border color manipulation
 *
 * All of this is purely cosmetic (window chrome appearance, not gameplay). It was causing
 * a launch hang under this MinGW cross-compiled build because:
 *   (a) The @:cppFileCode block with EnumWindows/GetDC/FillRect compiled and linked in
 *       regardless of whether fixScaling() was called -- still injectable C at class init time.
 *   (b) dwmapi.lib / the HWND manipulation may behave differently under 32-bit MinGW vs MSVC.
 *   (c) __init__() still fired registerDPIAware() unconditionally.
 *
 * Safe to re-enable once the engine is being built natively on Windows (MSVC or native MinGW),
 * where this code was originally written and tested. For now: stub everything to no-ops,
 * remove the @:cppFileCode block entirely so nothing gets injected at link time.
 */
class Native
{
	public static function __init__():Void {}

	public static function registerDPIAware():Void {}

	private static var fixedScaling:Bool = false;
	public static function fixScaling():Void {}

	public static function setDarkMode():Void {}

	public static function updateFrameRate(fps:Int):Void {}

	#if (cpp && windows)
	public static function getWindowsConsoleMode(handleType:Int):Int return 0;
	public static function setWindowsConsoleMode(handleType:Int, mode:Int):Bool return false;
	#end
}
