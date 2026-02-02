package backend;

import openfl.Lib;
import openfl.events.KeyboardEvent;
import flixel.input.keyboard.FlxKey;
import lime.app.Application;
import lime.system.System;
import lime.math.Rectangle;
import sys.io.File;
import sys.FileSystem;
import StringTools;
import Std;

class Screenshot
{
	public static function init():Void
	{
		try
		{
			if (Lib.current != null && Lib.current.stage != null)
			{
				Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
				trace("Screenshot: listener attached");
			}
		}
		catch(e:Dynamic) { trace("Screenshot: attach failed: " + Std.string(e)); }
	}

	private static function onKeyDown(event:KeyboardEvent):Void
	{
		// Use FlxKey constants (event.keyCode matches these in project)
		if (event.keyCode == FlxKey.F9)
		{
			trace("Screenshot: F9 pressed");
			saveScreenshot();
		}
	}

	public static function saveScreenshot():Void
	{
		try
		{
			var appDir:String = System.applicationDirectory;
			var sep:String = if (appDir.indexOf("\\") != -1) "\\" else "/";
			if (appDir.length == 0) sep = "/";
			var baseDir = if (StringTools.endsWith(appDir, sep)) appDir else appDir + sep;
			var screenshotsDir = baseDir + "screenshots";
			try { FileSystem.createDirectory(screenshotsDir); } catch(e:Dynamic) {}

			var d:Date = Date.now();
			var year = d.getFullYear();
			var month = (d.getMonth() + 1);
			var day = d.getDate();
			var hour24 = d.getHours();
			var minute = d.getMinutes();
			var second = d.getSeconds();
			var ampm = if (hour24 >= 12) "pm" else "am";
			var hour12 = hour24 % 12;
			if (hour12 == 0) hour12 = 12;
			var pad = function(n:Int):String { return if (n < 10) "0" + Std.string(n) else Std.string(n); };
			var stamp = Std.string(year) + "-" + pad(month) + "-" + pad(day) + "-" + pad(hour12) + "-" + pad(minute) + "-" + pad(second) + "-" + ampm;
			var fileName = stamp + "_screenshot.png";
			var fullPath = screenshotsDir + (StringTools.endsWith(screenshotsDir, sep) ? "" : sep) + fileName;

			var capW:Int = Std.int(Lib.current.stage.stageWidth);
			var capH:Int = Std.int(Lib.current.stage.stageHeight);
			trace("Screenshot: capturing size " + Std.string(capW) + "x" + Std.string(capH));
			var bytes = lime.app.Application.current.window.readPixels(new Rectangle(0, 0, capW, capH)).encode();
			File.saveBytes(fullPath, bytes);
			trace("Screenshot saved: " + fullPath);
		}
		catch(e:Dynamic)
		{
			trace("Screenshot failed: " + Std.string(e));
			try
			{
				var capW2:Int = Std.int(Lib.current.stage.stageWidth);
				var capH2:Int = Std.int(Lib.current.stage.stageHeight);
				var fb = lime.app.Application.current.window.readPixels(new Rectangle(0, 0, capW2, capH2)).encode();
				File.saveBytes("screenshot.png", fb);
				trace("Screenshot saved to working dir: screenshot.png");
			}
			catch(e2:Dynamic)
			{
				trace("Screenshot fallback failed: " + Std.string(e2));
			}
		}
	}
}
