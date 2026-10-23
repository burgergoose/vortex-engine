package backend;

import haxe.io.Bytes;
import haxe.crypto.Sha256;

enum BuildStatus
{
	CHECKING;
	VERIFIED;
	UNVERIFIED(reason:String);
	INTEGRITY_FAILURE(problems:Array<String>);
}

/**
 * VORTEX ENGINE ADDITION (0.5) - checks whether this copy of the game is an official Vortex Engine release.
 *
 * Official release zips contain `vortex_manifest.json` (SHA-256 of every program and asset file) and
 * `vortex_manifest.sig` (an RSA-2048 PKCS#1 v1.5 signature of the manifest, made with the release key, which is
 * NOT in the source code or the game). This class checks the signature with the public key below, then the files.
 *
 *   VERIFIED            signature good, every listed file matches
 *   UNVERIFIED          no manifest / signature, a signature that doesn't match, or a manifest for another version.
 *                       Normal for builds made from the source code; it does NOT mean the build is harmful.
 *   INTEGRITY_FAILURE   the signature is good but listed files are missing or changed, or extra program files
 *                       (.exe / .dll / .ndll) were added next to the game
 *
 * When the build isn't verified, UNOFFICIAL_BUILD_README.txt is written next to the game (or, if that folder can't
 * be written, to the app's data folder, and a message says where). The check runs on a background thread.
 *
 * Limits: someone who changes the executable itself can also remove this check, so a "verified" result is only as
 * trustworthy as the executable that reports it. Download releases from the official page.
 */
class BuildVerifier
{
	public static inline var README_NAME:String = 'UNOFFICIAL_BUILD_README.txt';
	public static inline var README_HEADER:String = '=== Vortex Engine: unofficial build notice ===';
	public static inline var OFFICIAL_URL:String = 'https://github.com/burgergoose/vortex-engine';

	/** Release public key (RSA-2048, e = 65537), hex. The private key is kept offline by the release maintainer. */
	public static inline var PUBLIC_KEY_N:String = 'bb3a550621b03130d7d4f073fb9030fe2c505a2f0235eabe14700a900f130916b87eb92ddfbb5a6473c1dc1911647f34af2cc08fa8ee9077d42ae8a41eec6b2d77798d24e03ea766514770869ac721bb7aca33cb8d2880adb437963bd16010c420f7db8c236ed8e3f3ceac6e2363df03a064ea1e7ca897748915a1688e7cdaa145309c782ee69253ccb4235bfc17e92fe89e73d5988ba1b0a1a2d74d31af400fc825e5b7f69441ae2d4dfcc4c376325de9d66312184385aae554b2cb800fbc6b81047155a0804fa217b798a92bb19b22a4d9d10b119c01a13fd31afeeb256588bf09bc13a3e6aab3a11b06ff6bbae01aa04533265ec0a786a5cc320198420a21';
	static inline var PUBLIC_KEY_E:Int = 65537;

	public static var status(default, null):BuildStatus = CHECKING;
	public static var readmePath(default, null):String = null;
	public static var manifestInfo(default, null):Dynamic = null;
	static var started:Bool = false;
	static var pendingToast:String = null;

	/** Starts the check (once). Call after the game window exists. */
	public static function start():Void
	{
		#if sys
		if (started) return;
		started = true;
		var dir:String = gameDir();
		#if target.threaded
		sys.thread.Thread.create(function() runCheck(dir));
		#else
		runCheck(dir);
		#end
		FlxG.signals.postUpdate.add(showPending);
		#end
	}

	public static function describe():String
	{
		return switch (status)
		{
			case CHECKING: 'checking...';
			case VERIFIED: 'official release (verified)';
			case UNVERIFIED(r): 'unofficial / unverified build';
			case INTEGRITY_FAILURE(p): 'INTEGRITY CHECK FAILED (${p.length} files)';
		}
	}

	static function showPending()
	{
		if (pendingToast == null) return;
		var msg:String = pendingToast;
		pendingToast = null;
		FlxG.signals.postUpdate.remove(showPending);
		try Main.showToast(msg) catch (e:Dynamic) {}
	}

	#if sys
	static function gameDir():String
	{
		var p:String = haxe.io.Path.directory(Sys.programPath());
		if (p == null || p.length < 1 || !sys.FileSystem.exists(p)) p = Sys.getCwd();
		return haxe.io.Path.addTrailingSlash(p.replace('\\', '/'));
	}

	static function runCheck(dir:String)
	{
		try
		{
			status = verify(dir);
		}
		catch (e:Dynamic)
		{
			status = UNVERIFIED('the check itself failed: $e');
		}
		trace('Build check: ' + describe());
		try handleReadme(dir) catch (e:Dynamic) trace('Build check: could not write $README_NAME: $e');
	}

	/** The actual check (no side effects). `dir` ends with '/'. */
	public static function verify(dir:String):BuildStatus
	{
		var manifestPath:String = dir + 'vortex_manifest.json';
		var sigPath:String = dir + 'vortex_manifest.sig';
		if (!sys.FileSystem.exists(manifestPath) || !sys.FileSystem.exists(sigPath))
			return UNVERIFIED('this copy has no signed release manifest (vortex_manifest.json + .sig). Builds made from the source code never have one.');
		if (PUBLIC_KEY_N.indexOf('__') == 0)
			return UNVERIFIED('this executable was built without a release public key, so it cannot verify anything.');

		var manifestBytes:Bytes = sys.io.File.getBytes(manifestPath);
		var sigHex:String = sys.io.File.getContent(sigPath).trim();
		if (!Rsa.verifySha256(manifestBytes, sigHex, PUBLIC_KEY_N, PUBLIC_KEY_E))
			return UNVERIFIED('the release signature does not match vortex_manifest.json (the manifest was changed, or it was not signed with the official key).');

		var manifest:Dynamic = haxe.Json.parse(manifestBytes.toString());
		manifestInfo = manifest;
		var version:String = Std.string(manifest.version);
		if (version != VortexConfig.engineVersion)
			return UNVERIFIED('the signed manifest is for version $version, but this executable reports ${VortexConfig.engineVersion}.');

		var problems:Array<String> = [];
		var files:Dynamic = manifest.files;
		for (rel in Reflect.fields(files))
		{
			var p:String = dir + rel;
			if (!sys.FileSystem.exists(p)) { problems.push('missing: $rel'); continue; }
			var expected:String = Std.string(Reflect.field(files, rel)).toLowerCase();
			if (Sha256.make(sys.io.File.getBytes(p)).toHex() != expected) problems.push('changed: $rel');
		}
		// program files that the official release doesn't have
		for (name in sys.FileSystem.readDirectory(dir))
		{
			var low:String = name.toLowerCase();
			if ((low.endsWith('.exe') || low.endsWith('.dll') || low.endsWith('.ndll')) && Reflect.field(files, name) == null)
				problems.push('added program file: $name');
		}
		return problems.length > 0 ? INTEGRITY_FAILURE(problems) : VERIFIED;
	}

	static function handleReadme(dir:String)
	{
		var target:String = dir + README_NAME;
		switch (status)
		{
			case VERIFIED:
				// an old notice of ours (e.g. from before an official reinstall) is removed; anyone else's file is left alone
				if (sys.FileSystem.exists(target) && !sys.FileSystem.isDirectory(target) && sys.io.File.getContent(target).startsWith(README_HEADER))
					sys.FileSystem.deleteFile(target);
				return;
			case CHECKING:
				return;
			default:
		}
		var text:String = readmeText();
		var written:String = writeIfChanged(target, text);
		if (written == null)
		{
			var fallback:String = haxe.io.Path.addTrailingSlash(lime.system.System.applicationStorageDirectory) + README_NAME;
			written = writeIfChanged(fallback, text);
			if (written != null) pendingToast = 'This build is not a verified official release.\nThe game folder can\'t be written to, so the notice was saved to:\n$written';
		}
		readmePath = written;
		switch (status)
		{
			case INTEGRITY_FAILURE(p):
				pendingToast = 'Integrity check failed: ${p.length} game file(s) differ from the official release.\nSee ' + (written != null ? written : README_NAME) + (pendingToast != null ? '\n\n' + pendingToast : '');
			default:
		}
	}

	/** Writes the file unless it already has exactly this text. Returns the path, or null if it can't be written there. */
	static function writeIfChanged(path:String, text:String):String
	{
		try
		{
			if (sys.FileSystem.exists(path))
			{
				if (sys.FileSystem.isDirectory(path)) return null;
				var old:String = sys.io.File.getContent(path);
				if (old == text) return path;
				if (!old.startsWith(README_HEADER)) return null; // somebody else's file with this name: don't overwrite it
			}
			var dir:String = haxe.io.Path.directory(path);
			if (dir.length > 0 && !sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
			sys.io.File.saveContent(path, text);
			return path;
		}
		catch (e:Dynamic) {}
		return null;
	}
	#end

	public static function readmeText():String
	{
		var b:StringBuf = new StringBuf();
		b.add(README_HEADER + '\n\n');
		b.add('Detected version: ${VortexConfig.engineName} ${VortexConfig.engineVersion}\n');
		b.add('Executable built: ${BuildInfo.date()} (source commit ${BuildInfo.commit()})\n');
		if (manifestInfo != null) b.add('Release manifest: version ${manifestInfo.version}, commit ${manifestInfo.commit}, signed ${manifestInfo.built}\n');
		b.add('\nVerification status: ');
		switch (status)
		{
			case UNVERIFIED(reason):
				b.add('UNVERIFIED\n  $reason\n\n');
				b.add('This copy of Vortex Engine could not be confirmed as an official release. That is normal for:\n'
					+ '  - builds you or someone else compiled from the source code (including GitHub Actions builds),\n'
					+ '  - modified versions and forks,\n'
					+ '  - mod packs that re-share the game.\n'
					+ 'An unofficial build is NOT automatically harmful. Missing verification information alone is not proof that anything was tampered with.\n');
			case INTEGRITY_FAILURE(problems):
				b.add('INTEGRITY CHECK FAILED\n');
				b.add('  The release signature is valid, but these files are not the ones that were released:\n');
				for (p in problems.slice(0, 50)) b.add('    - $p\n');
				if (problems.length > 50) b.add('    ... and ${problems.length - 50} more\n');
				b.add('\nThe game files were changed after the release was made (by a mod pack, a manual edit, a broken download or something else). '
					+ 'If you didn\'t do this on purpose, download the game again from the official page.\n');
			default:
				b.add('${describe()}\n');
		}
		b.add('\nOfficial releases: $OFFICIAL_URL\n');
		b.add('\nAbout this check: official release zips include a signed list of the game\'s files (vortex_manifest.json + vortex_manifest.sig). '
			+ 'The game checks that signature and the files every time it starts. This cannot guarantee that a copy is safe: someone who '
			+ 'modifies the executable itself can also remove or fake this check. Only download the game from the official page.\n');
		b.add('\nThis file is written by the game and is replaced or removed automatically. It is safe to delete.\n');
		return b.toString();
	}
}

/** Minimal RSA signature check (PKCS#1 v1.5 with SHA-256). Numbers are little-endian arrays of 15-bit limbs. */
class Rsa
{
	static inline var BITS:Int = 15;
	static inline var MASK:Int = 0x7FFF;
	static final DIGEST_INFO:Array<Int> = [0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20];

	public static function verifySha256(message:Bytes, sigHex:String, nHex:String, e:Int):Bool
	{
		if (sigHex == null || !~/^[0-9a-fA-F]+$/.match(sigHex)) return false;
		var n:Array<Int> = fromHex(nHex);
		var k:Int = Std.int((nHex.length + 1) / 2); // modulus length in bytes
		var s:Array<Int> = fromHex(sigHex);
		if (compare(s, n) >= 0) return false;
		var m:Array<Int> = modPow(s, e, n);
		// expected encoding: 00 01 FF..FF 00 DigestInfo hash
		var hash:Bytes = Sha256.make(message);
		var em:Bytes = Bytes.alloc(k);
		em.fill(0, k, 0xFF);
		em.set(0, 0);
		em.set(1, 1);
		var tLen:Int = DIGEST_INFO.length + hash.length;
		em.set(k - tLen - 1, 0);
		for (i in 0...DIGEST_INFO.length) em.set(k - tLen + i, DIGEST_INFO[i]);
		em.blit(k - hash.length, hash, 0, hash.length);
		return compare(m, fromHex(em.toHex())) == 0;
	}

	static function fromHex(hex:String):Array<Int>
	{
		var out:Array<Int> = [];
		var acc:Int = 0, accBits:Int = 0;
		var i:Int = hex.length;
		while (i > 0)
		{
			var c:Int = Std.parseInt('0x' + hex.charAt(--i));
			acc |= c << accBits;
			accBits += 4;
			if (accBits >= BITS)
			{
				out.push(acc & MASK);
				acc >>= BITS;
				accBits -= BITS;
			}
		}
		if (accBits > 0) out.push(acc & MASK);
		trim(out);
		return out;
	}

	static function trim(a:Array<Int>)
	{
		while (a.length > 0 && a[a.length - 1] == 0) a.pop();
	}

	static function compare(a:Array<Int>, b:Array<Int>):Int
	{
		trim(a); trim(b);
		if (a.length != b.length) return a.length < b.length ? -1 : 1;
		var i:Int = a.length;
		while (i-- > 0) if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
		return 0;
	}

	static function mul(a:Array<Int>, b:Array<Int>):Array<Int>
	{
		var r:Array<Int> = [for (i in 0...(a.length + b.length + 1)) 0];
		for (i in 0...a.length)
		{
			var carry:Int = 0;
			var ai:Int = a[i];
			for (j in 0...b.length)
			{
				var t:Int = r[i + j] + ai * b[j] + carry;
				r[i + j] = t & MASK;
				carry = t >>> BITS;
			}
			var k:Int = i + b.length;
			while (carry != 0)
			{
				var t:Int = r[k] + carry;
				r[k] = t & MASK;
				carry = t >>> BITS;
				k++;
			}
		}
		trim(r);
		return r;
	}

	/** x mod n by shift-and-subtract (fine for the 17 multiplications of e = 65537). */
	static function mod(x:Array<Int>, n:Array<Int>):Array<Int>
	{
		var r:Array<Int> = [];
		var bits:Int = x.length * BITS;
		var i:Int = bits;
		while (i-- > 0)
		{
			// r = r * 2 + bit
			var carry:Int = (x[Std.int(i / BITS)] >> (i % BITS)) & 1;
			for (j in 0...r.length)
			{
				var t:Int = (r[j] << 1) | carry;
				r[j] = t & MASK;
				carry = t >> BITS;
			}
			if (carry != 0) r.push(carry);
			if (compare(r, n) >= 0) sub(r, n);
		}
		return r;
	}

	static function sub(a:Array<Int>, b:Array<Int>)
	{
		var borrow:Int = 0;
		for (i in 0...a.length)
		{
			var t:Int = a[i] - (i < b.length ? b[i] : 0) - borrow;
			if (t < 0) { t += MASK + 1; borrow = 1; } else borrow = 0;
			a[i] = t;
		}
		trim(a);
	}

	static function modPow(base:Array<Int>, e:Int, n:Array<Int>):Array<Int>
	{
		var result:Array<Int> = [1];
		var b:Array<Int> = mod(base, n);
		var exp:Int = e;
		while (exp > 0)
		{
			if (exp & 1 == 1) result = mod(mul(result, b), n);
			exp >>= 1;
			if (exp > 0) b = mod(mul(b, b), n);
		}
		return result;
	}
}
