package shaders;

import flixel.FlxG;
import openfl.filters.BitmapFilter;
import openfl.filters.ColorMatrixFilter;
import openfl.Lib;
import backend.ClientPrefs;

class ColorFilters
{
    //i honesly have no ideas how to make it, so i hope that works
    public static var filterArray:Array<BitmapFilter> = [];
	public static var filterMap:Map<String, {filter:BitmapFilter, ?onUpdate:Void->Void}> =
	[
        //I found these values in official haxe guides :D

		"Deuteranopia" =>
		{
			var matrix:Array<Float> =
			[
				0.43, 0.72, -.15, 0, 0,
				0.34, 0.57, 0.09, 0, 0,
				-.02, 0.03,    1, 0, 0,
				   0,    0,    0, 1, 0,
			];

			{filter: new ColorMatrixFilter(matrix)}
		},
		"Protanopia" =>
		{
			var matrix:Array<Float> =
			[
				0.20, 0.99, -.19, 0, 0,
				0.16, 0.79, 0.04, 0, 0,
				0.01, -.01,    1, 0, 0,
				   0,    0,    0, 1, 0,
			];

			{filter: new ColorMatrixFilter(matrix)}
		},
		"Tritanopia" =>
		{
			var matrix:Array<Float> = 
			[
				0.97, 0.11, -.08, 0, 0,
				0.02, 0.82, 0.16, 0, 0,
				0.06, 0.88, 0.18, 0, 0,
				   0,    0,    0, 1, 0,
			];

			{filter: new ColorMatrixFilter(matrix)}
		},
		"Inverted" =>
		{
			// Invert all colors: new = 1 - old
			var matrix:Array<Float> = [
				-1,  0,  0, 0, 255,
				 0, -1,  0, 0, 255,
				 0,  0, -1, 0, 255,
				 0,  0,  0, 1,   0
			];
			{filter: new ColorMatrixFilter(matrix)}
		},
		"Greyscale" =>
		{
			// Greyscale filter: average RGB
			var matrix:Array<Float> = [
				0.33, 0.33, 0.33, 0, 0,
				0.33, 0.33, 0.33, 0, 0,
				0.33, 0.33, 0.33, 0, 0,
				   0,    0,    0, 1, 0
			];

			{filter: new ColorMatrixFilter(matrix)}
		}
    ];

	public static function applyFiltersOnGame()
	{
		filterArray = [];
		if (ClientPrefs.data.colorFilter != "None") //actually self explanatory, isn't it?
		{
			if (filterMap.get(ClientPrefs.data.colorFilter) != null) //anticrash system
			{
				var thisF = filterMap.get(ClientPrefs.data.colorFilter).filter;
				if (thisF != null)
				{
					filterArray.push(thisF);
				}
			}
		}

		// Avoid double-applying the same ColorMatrix on both the Flx game
		// container and the OpenFL root. That caused double-inversion: the
		// game would be inverted twice (back to normal) while overlays on the
		// root were inverted once. To fix that, apply the ColorMatrixFilter
		// (e.g. "Inverted") only to the OpenFL root and clear any existing
		// FlxG.game filters so the effect is visible on both game and HUD.
		if (ClientPrefs.data.colorFilter == "Inverted")
		{
			// clear flixel-side filters to prevent double application
			try { flixel.FlxG.game.setFilters([]); } catch(e:Dynamic) {}
			(untyped Lib.current).set_filters(filterArray);
			return;
		}

		// For non-invert filters, apply to the Flx game container so camera
		// effects and shader filters behave as before, and also set root
		// filters for HUD overlays.
		try { flixel.FlxG.game.setFilters(filterArray); } catch(e:Dynamic) {}
		try { (untyped Lib.current).set_filters(filterArray); } catch(e:Dynamic) {}
	}
}
