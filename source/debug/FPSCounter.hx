package debug;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import openfl.Lib;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System;
import backend.ClientPrefs;

#if cpp
	#if windows
	@:cppFileCode('#include <windows.h>\nstatic float __hxcpp_batteryLevel() { SYSTEM_POWER_STATUS status; if (GetSystemPowerStatus(&status)) return status.BatteryLifePercent == 255 ? -1.0f : status.BatteryLifePercent / 100.0f; return -1.0f; }')
	#end
#end

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
class FPSCounter extends TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;

	/**
		The current memory usage (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	**/
	public var memoryMegas(get, never):Float;

	@:noCompletion private var times:Array<Float>;
	var array:Array<FlxColor> = [
		FlxColor.fromRGB(148, 0, 211),
		FlxColor.fromRGB(75, 0, 130),
		FlxColor.fromRGB(0, 0, 255),
		FlxColor.fromRGB(0, 255, 0),
		FlxColor.fromRGB(255, 255, 0),
		FlxColor.fromRGB(255, 127, 0),
		FlxColor.fromRGB(255, 0, 0)
	];
	var skippedFrames:Int = 0;
	public static var currentColor:Int = 0;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 14, color);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		times = [];
	}

	var deltaTimeout:Float = 0.0;

	// Event Handlers
	private override function __enterFrame(deltaTime:Float):Void
	{
		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000) times.shift();
		
		// Handle rainbow color cycling exactly like KadeEngine
		if (ClientPrefs.data.fpsColor == 'KE Rainbow')
		{
			var fpsCap:Float = FlxG.updateFramerate;
			if (Reflect.hasField(FlxG.save.data, 'fpsCap'))
			{
				fpsCap = Std.int(Reflect.field(FlxG.save.data, 'fpsCap'));
			}
			if (currentColor >= array.length)
			{
				currentColor = 0;
			}
			currentColor = Math.round(FlxMath.lerp(0, array.length, skippedFrames / (fpsCap / 3)));
			if (currentColor >= array.length)
			{
				currentColor = array.length - 1;
			}
			Main.changeFPSColor(array[currentColor]);
			currentColor++;
			skippedFrames++;
			if (skippedFrames > (fpsCap / 3))
			{
				skippedFrames = 0;
			}
		}

		// prevents the overlay from updating every frame, why would you need to anyways @crowplexus
		if (deltaTimeout < 50)
		{
			deltaTimeout += deltaTime;
			return;
		}

		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
		updateText();
		deltaTimeout = 0.0;
	}

	public dynamic function updateText():Void // so people can override it in hscript
	{
		// Get the current time
		var dateNow = Date.now();
		var hours = dateNow.getHours();
		var minutes = dateNow.getMinutes();
		var seconds = dateNow.getSeconds();
		var centis = Std.int((dateNow.getTime() % 1000) / 10);
		var ampm = (hours >= 12) ? "PM" : "AM";
		var tzMinutes = Std.int(dateNow.getTimezoneOffset());
		var tzName = "UTC";
		switch (tzMinutes) // List of all timezones
		{
			case 0: tzName = "GMT";
			case -60: tzName = "CET";
			case -120: tzName = "EET";
			case -180: tzName = "MSK";
			case -240: tzName = "GST";
			case -300: tzName = "EST";
			case -360: tzName = "CST";
			case -420: tzName = "MST";
			case -480: tzName = "PST";
			case 60: tzName = "WET";
			case 120: tzName = "CET";
			case 180: tzName = "EET";
			case 240: tzName = "GST";
			case 300: tzName = "EST";
			case 360: tzName = "CST";
			case 420: tzName = "MST";
			case 480: tzName = "PST";
			default: tzName = "UTC";
			// Defaults to UTC if timezone is not recognized.
			// If your time zone is not listed, please contact Nightmare62107 and I will add it in.
		}
		hours = (hours % 12 == 0) ? 12 : hours % 12;
		var timeStr = hours + ":" + (minutes < 10 ? "0" : "") + minutes + ":" + (seconds < 10 ? "0" : "") + seconds + "." + (centis < 10 ? "0" : "") + centis + " " + ampm;
		if (ClientPrefs.data.displayTimezone && ClientPrefs.data.displayTime)
		{
			timeStr += " " + tzName;
		}

		// Get the current date
		var month = dateNow.getMonth() + 1;
		var day = dateNow.getDate();
		var year = dateNow.getFullYear();
		var dateStr = (month < 10 ? "0" : "") + month + "/" + (day < 10 ? "0" : "") + day + "/" + year;

		var batteryText:String = "N/A";
		var batteryLevel:Float = getBatteryLevel();
		if (batteryLevel >= 0)
		{
			batteryText = Std.int(batteryLevel * 100) + "%";
		}

		text = "";
		if (ClientPrefs.data.displayFPS)
		{
			text += 'FPS: ${currentFPS}\n';
		}
		if (ClientPrefs.data.displayMemory)
		{
			text += 'Memory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)}\n';
		}
		if (ClientPrefs.data.displayDate)
		{
			text += 'Date: ${dateStr}\n';
		}
		if (ClientPrefs.data.displayTime)
		{
			text += 'Time: ${timeStr}\n';
		}
		if (ClientPrefs.data.displayBattery)
		{
			text += 'Battery: ${batteryText}\n';
		}
		// Remove trailing newline if present
		if (text.length > 0 && text.charAt(text.length - 1) == '\n')
		{
			text = text.substr(0, text.length - 1);
		}
	}

	private static function getBatteryLevel():Float
	{
		#if cpp
			#if windows
			return untyped __cpp__("__hxcpp_batteryLevel()");
			#else
			return -1.0;
			#end
		#else
		return -1.0;
		#end
	}

	inline function get_memoryMegas():Float
	{
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
	}
}
