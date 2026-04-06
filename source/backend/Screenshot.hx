package backend;

import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.Lib;
import openfl.events.Event;
import openfl.geom.Matrix;
import openfl.display.BitmapData;
import flash.display.Sprite;
import flash.system.System;
import sys.io.File;
import sys.FileSystem;
import sys.thread.Thread;
import StringTools;
import Std;

class Screenshot
{
	public static function init():Void
	{
		try
		{
			FlxG.stage.addEventListener(openfl.events.KeyboardEvent.KEY_DOWN, onKeyDown);
			trace("Screenshot: listener attached");
		}
		catch(e:Dynamic) { trace("Screenshot: attach failed: " + Std.string(e)); }
	}

	private static function onKeyDown(event:openfl.events.KeyboardEvent):Void
	{
		var screenshotKeys = ClientPrefs.keyBinds['screenshot'];
		if (screenshotKeys != null && screenshotKeys.contains(event.keyCode))
		{
			trace("Screenshot: key pressed");
			saveScreenshot();
		}
	}

	private static var pendingScreenshot:Dynamic = null;

	public static function saveScreenshot():Void
	{
		// Capture pixels immediately, defer heavy encoding/file I/O to thread
		try
		{
			var capW:Int = Std.int(FlxG.stage.stageWidth);
			var capH:Int = Std.int(FlxG.stage.stageHeight);
			var pixelData = FlxG.stage.window.readPixels(new lime.math.Rectangle(0, 0, capW, capH));
			
			// Show preview immediately on main thread
			showPreview();
			
			// Play sound immediately so it feels responsive
			FlxG.sound.play(Paths.sound('screenshot'), 1.0);
			
			// Run encoding and file saving in a background thread
			Thread.create(function():Void
			{
				performScreenshot(pixelData, capW, capH);
			});
			
			trace("Screenshot: capture initiated");
		}
		catch(e:Dynamic)
		{
			trace("Screenshot capture failed: " + Std.string(e));
		}
	}

	private static function performScreenshot(pixelData:Dynamic, capW:Int, capH:Int):Void
	{
		try
		{
			var appDir:String = lime.system.System.applicationDirectory;
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

			trace("Screenshot: encoding " + Std.string(capW) + "x" + Std.string(capH));
			var bytes = pixelData.encode();
			File.saveBytes(fullPath, bytes);
			bytes = null;
			pixelData = null;
			trace("Screenshot saved: " + fullPath);
			System.gc();
		}
		catch(e:Dynamic)
		{
			trace("Screenshot thread failed: " + Std.string(e));
			try
			{
				var bytes = pixelData.encode();
				File.saveBytes("screenshot.png", bytes);
				bytes = null;
				pixelData = null;
				trace("Screenshot saved to working dir: screenshot.png");

				System.gc();
			}
			catch(e2:Dynamic)
			{
				trace("Screenshot fallback failed: " + Std.string(e2));
			}
		}
	}

	private static function showPreview():Void
	{
		try
		{
			var pixelImage = FlxG.stage.window.readPixels();
			var screenshotData = BitmapData.fromImage(pixelImage);
			pixelImage = null;
			var popup = new ScreenshotPreview(screenshotData);
			FlxG.game.addChild(popup);
		}
		catch(e:Dynamic)
		{
			trace("Failed to create screenshot preview: " + Std.string(e));
		}
	}
}

class ScreenshotPreview extends Sprite
{
	var timePassed:Float = -1;
	var countedTime:Float = 0;
	var lerpTime:Float = 0;
	var lastScale:Float = 1;
	var intendedY:Float = 0;
	var screenshotData:BitmapData = null;
	var canCleanup:Bool = false;

	private static final PREVIEW_SCALE:Float = 0.2;
	private static final PREVIEW_FADE_OUT_DELAY:Float = 1.5;

	public function new(screenshotData:BitmapData)
	{
		super();

		this.screenshotData = screenshotData;
		var previewWidth:Int = Std.int(screenshotData.width * PREVIEW_SCALE);
		var previewHeight:Int = Std.int(screenshotData.height * PREVIEW_SCALE);

		// Draw border
		graphics.lineStyle(2, FlxColor.WHITE);
		graphics.drawRect(0, 0, previewWidth + 10, previewHeight + 10);

		// Draw scaled screenshot
		var matrix = new openfl.geom.Matrix();
		matrix.scale(PREVIEW_SCALE, PREVIEW_SCALE);
		matrix.translate(5, 5);
		graphics.beginBitmapFill(screenshotData, matrix, false, true);
		graphics.drawRect(5, 5, previewWidth, previewHeight);
		graphics.endFill();

		lastScale = (FlxG.stage.stageHeight / FlxG.height);
		this.x = 20 * lastScale;
		this.y = -130 * lastScale;
		this.scaleX = lastScale;
		this.scaleY = lastScale;
		intendedY = 20;

		FlxG.stage.addEventListener(Event.RESIZE, onResize);
		addEventListener(Event.ENTER_FRAME, update);
	}

	function update(e:Event)
	{
		if (timePassed < 0)
		{
			timePassed = Lib.getTimer();
			return;
		}

		var time = Lib.getTimer();
		var elapsed:Float = (time - timePassed) / 1000;
		timePassed = time;

		if (elapsed >= 0.5) return;

		countedTime += elapsed;
		if (countedTime < PREVIEW_FADE_OUT_DELAY)
		{
			lerpTime = Math.min(1, lerpTime + elapsed);
			y = ((FlxEase.elasticOut(lerpTime) * (intendedY + 130)) - 130) * lastScale;
		}
		else
		{
			y -= FlxG.height * 2 * elapsed * lastScale;
			if (y <= -130 * lastScale)
			{
				canCleanup = true;
				FlxG.stage.removeEventListener(Event.RESIZE, onResize);
				removeEventListener(Event.ENTER_FRAME, update);
				if (parent != null) parent.removeChild(this);
				cleanup();
			}
		}
	}

	private function onResize(e:Event)
	{
		var mult = (FlxG.stage.stageHeight / FlxG.height);
		scaleX = mult;
		scaleY = mult;

		x = (mult / lastScale) * x;
		y = (mult / lastScale) * y;
		lastScale = mult;
	}

	private function cleanup():Void
	{
		if (canCleanup)
		{
			graphics.clear();
			if (screenshotData != null)
			{
				screenshotData.dispose();
				screenshotData = null;
			}
		}
	}
}
