package objects;

import sys.io.File;
import sys.FileSystem;
import openfl.display.BitmapData;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import backend.Mods;
import backend.Paths;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isPlayer:Bool = false;
	private var char:String = '';
	private var useGridIcon:Bool = false;

	// Guard against duplicate immediate reloads for the same char/mode
	private var _lastRequestedChar:String = null;
	private var _lastRequestedUseGrid:Bool = false;
	
	// Grid-based icon animation frames (for characters using the icon grid)
	// The base game icon grid is loaded from assets/shared/images/iconGrid.txt / iconGrid.png.
	// Mod iconGrid.txt files can provide new icon names that are not present in the base file.
	// New mod icon names are associated with the mod's own iconGrid.png only.
	private static var gridAnimations:Map<String, Array<Int>> = [];
	private static var gridAnimationsLoaded:Bool = false;
	private static var gridCustomGraphicPaths:Map<String, String> = [];
	private static var gridCustomGraphics:Map<String, FlxGraphic> = [];
	private static var baseGridGraphic:FlxGraphic = null;

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = true, ?useGridIcon:Bool = false)
	{
		super();
		
		if (!gridAnimationsLoaded)
		{
			loadGridAnimationsFromFile();
			gridAnimationsLoaded = true;
		}
		
		this.isPlayer = isPlayer;
		this.useGridIcon = useGridIcon;
		//trace('[HealthIcon] new char=' + char + ' useGridIcon=' + useGridIcon);
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	private static function loadGridAnimationsFromFile():Void
	{
		// Load the base game icon grid first.
		// This is the primary TXT and PNG used for all shared icons.
		var baseText:String = File.getContent(Paths.getSharedPath('images/iconGrid.txt'));
		if (baseText != null)
		{
			parseGridText(baseText, null);
		}

		#if MODS_ALLOWED
		var modPaths:Array<String> = [];
		for (path in Mods.directoriesWithFile(Paths.getSharedPath(''), 'images/iconGrid.txt'))
		{
			if (!modPaths.contains(path))
			{
				modPaths.push(path);
			}
		}

		for (mod in Mods.getModDirectories())
		{
			var modPath:String = Paths.mods(mod + '/images/iconGrid.txt');
			if (FileSystem.exists(modPath) && !modPaths.contains(modPath)) modPaths.push(modPath);
			var modRootPath:String = Paths.mods(mod + '/iconGrid.txt');
			if (FileSystem.exists(modRootPath) && !modPaths.contains(modRootPath)) modPaths.push(modRootPath);
		}

		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var currentPath:String = Paths.mods(Mods.currentModDirectory + '/images/iconGrid.txt');
			if (FileSystem.exists(currentPath) && !modPaths.contains(currentPath)) modPaths.push(currentPath);
			var currentRootPath:String = Paths.mods(Mods.currentModDirectory + '/iconGrid.txt');
			if (FileSystem.exists(currentRootPath) && !modPaths.contains(currentRootPath)) modPaths.push(currentRootPath);
		}

		for (path in modPaths)
		{
			if (path == Paths.getSharedPath('images/iconGrid.txt')) continue;
			var modText:String = File.getContent(path);
			if (modText == null) continue;
			parseGridText(modText, path);
		}
		#end
	}

	private static function parseGridText(text:String, sourcePath:String):Void
	{
		// Only add entries that do not already exist in the base game grid.
		// This prevents mods from overwriting the shared base icons.
		// If the entry comes from a mod TXT, associate it with that mod's iconGrid.png.
		for (line in text.split('\n'))
		{
			if (line == null || line.trim() == '') continue;

			var parts:Array<String> = line.split('::');
			if (parts.length != 2) continue;

			var charName:String = parts[0].trim();
			var frameRange:String = parts[1].trim();

			if (gridAnimations.exists(charName)) continue;

			var frames:Array<Int> = parseFrameRange(frameRange);
			if (frames.length == 0) continue;

			//trace('[HealthIcon] parseGridText char=' + charName + ' frames=' + frames.length + ' source=' + (sourcePath != null ? sourcePath : 'base'));

			if (sourcePath != null)
			{
				var imagePath:String = customGridImagePathForFile(sourcePath);
				if (imagePath == null) continue;
				gridCustomGraphicPaths.set(charName, imagePath);
			}

			gridAnimations.set(charName, frames);
		}
	}

	private static function customGridImagePathForFile(txtPath:String):String
	{
		// Support mod iconGrid.txt either in the mod root or inside the mod's images folder.
		var imagePath:String = null;

		if (txtPath.endsWith('images/iconGrid.txt'))
		{
			imagePath = txtPath.substr(0, txtPath.length - 'iconGrid.txt'.length) + 'iconGrid.png';
		}
		else if (txtPath.endsWith('iconGrid.txt'))
		{
			imagePath = txtPath.substr(0, txtPath.length - 'iconGrid.txt'.length) + 'iconGrid.png';
			if (!FileSystem.exists(imagePath))
			{
				imagePath = txtPath.substr(0, txtPath.length - 'iconGrid.txt'.length) + 'images/iconGrid.png';
			}
		}

		var resolvedPath:String = (imagePath != null && FileSystem.exists(imagePath)) ? imagePath : null;
		//trace('[HealthIcon] customGridImagePathForFile txtPath=' + txtPath + ' resolved=' + (resolvedPath != null ? resolvedPath : 'null'));
		return resolvedPath;
	}

	private static function getBaseGridGraphic():FlxGraphic
	{
		if (baseGridGraphic == null)
		{
			var baseImagePath:String = Paths.getSharedPath('images/iconGrid.png');
			if (FileSystem.exists(baseImagePath))
			{
				var bitmap:BitmapData = BitmapData.fromFile(baseImagePath);
				if (bitmap != null)
				{
					baseGridGraphic = FlxGraphic.fromBitmapData(bitmap, false, 'iconGrid-base');
					baseGridGraphic.persist = true;
					baseGridGraphic.destroyOnNoUse = false;
				}
			}
		}
		return baseGridGraphic;
	}

	private static function getCustomGridGraphic(path:String):FlxGraphic
	{
		if (gridCustomGraphics.exists(path))
		{
			return gridCustomGraphics.get(path);
		}

		if (!FileSystem.exists(path))
		{
			return null;
		}
		//trace('[HealthIcon] getCustomGridGraphic path=' + path + ' exists=' + FileSystem.exists(path));

		var bitmap:BitmapData = BitmapData.fromFile(path);
		if (bitmap == null)
		{
			return null;
		}

		var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, 'iconGrid-mod-' + path);
		graphic.persist = true;
		graphic.destroyOnNoUse = false;
		gridCustomGraphics.set(path, graphic);
		return graphic;
	}

	private static function parseFrameRange(frameRange:String):Array<Int>
	{
		var frames:Array<Int> = [];
		
		if (frameRange.contains('-'))
		{
			var parts:Array<String> = frameRange.split('-');
			if (parts.length == 2)
			{
				var start:Null<Int> = Std.parseInt(parts[0].trim());
				var end:Null<Int> = Std.parseInt(parts[1].trim());
				
				if (start != null && end != null)
				{
					for (i in start...(end + 1))
					{
						frames.push(i);
					}
				}
			}
		}
		else
		{
			var frame:Null<Int> = Std.parseInt(frameRange.trim());
			if (frame != null)
			{
				frames.push(frame);
			}
		}
		
		return frames;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
		{
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
		}
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public function changeIcon(char:String, ?allowGPU:Bool = true)
	{
		// Normalize empty or null icon names to the default 'face'
		if (char == null || StringTools.trim(char) == '') char = 'face' + (PlayState.isPixelStage ? '-pixel' : '');
		// Always attempt to (re)load the icon using the current grid mode so
		// typing a name while the checkbox is enabled uses grid icons immediately.
		if (useGridIcon)
		{
			// If the grid mapping doesn't have this name, try reloading the
			// grid data (in case files were changed or missed) and retry.
			if (!gridAnimations.exists(char))
			{
				try
				{
					loadGridAnimationsFromFile();
				}
				catch(e:Dynamic) {}
			}
			loadGridIcon(char);
		}
		else
		{
			loadStandardIcon(char, allowGPU);
		}
		this.char = char;
	}

	private function loadGridIcon(char:String):Void
	{
		// Prevent immediate duplicate loads for the same char + grid mode
		if (_lastRequestedChar == char && _lastRequestedUseGrid == true) return;
		_lastRequestedChar = char;
		_lastRequestedUseGrid = true;

		// Only characters known by the loaded grid animation map can use grid icons.
		// Custom mod-only names will use the mod's own iconGrid.png when available.
		if (!gridAnimations.exists(char))
		{
			var mapSize:Int = 0;
			for (k in gridAnimations.keys()) mapSize++;
			//trace('[HealthIcon] missing grid animation for char=' + char + ' mapSize=' + mapSize);
			useGridIcon = false;
			loadStandardIcon(char);
			return;
		}

		var gridGraphic:FlxGraphic = null;
		if (gridCustomGraphicPaths.exists(char))
		{
			var customPath:String = gridCustomGraphicPaths.get(char);
			if (customPath != null)
			{
				//trace('[HealthIcon] loadGridIcon char=' + char + ' customPath=' + customPath);
				gridGraphic = getCustomGridGraphic(customPath);
			}
		}
		var usingCustomGraphic:Bool = gridGraphic != null;

		if (gridGraphic == null)
			gridGraphic = getBaseGridGraphic();
		//trace('[HealthIcon] loadGridIcon char=' + char + ' usingCustom=' + usingCustomGraphic + ' basePresent=' + (gridGraphic != null));

		if (gridGraphic == null)
		{
			useGridIcon = false;
			loadStandardIcon(char);
			return;
		}

		loadGraphic(gridGraphic, true, 150, 150);
		antialiasing = true;

		switch(char)
		{
			/*
			case 'bf-pixel' | 'senpai' | 'senpai-angry' | 'spirit' | 'gf-pixel':
			{
				antialiasing = false;
			}
			*/
		}

		if (char.endsWith('-pixel'))
		{
			antialiasing = false;
		}

		var frames = gridAnimations.get(char);
		animation.add(char, frames, 0, false, isPlayer);
		animation.play(char);

		iconOffsets[0] = 0;
		iconOffsets[1] = 0;
		updateHitbox();
	}

	private function loadStandardIcon(char:String, ?allowGPU:Bool = true):Void
	{
		// Prevent immediate duplicate loads for the same char + standard mode
		if (_lastRequestedChar == char && _lastRequestedUseGrid == false) return;
		_lastRequestedChar = char;
		_lastRequestedUseGrid = false;

		var name:String = 'icons/' + char;
		if (!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; // Older versions of psych engine's support
		if (!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face' + (PlayState.isPixelStage ? '-pixel' : ''); // Prevents crash from missing icon
		
		var graphic = Paths.image(name, allowGPU);
		if (graphic == null)
		{
			this.visible = false;
			return;
		}
		var iSize:Float = Math.round(graphic.width / graphic.height);
		loadGraphic(graphic, true, Math.floor(graphic.width / iSize), Math.floor(graphic.height));
		iconOffsets[0] = (width - 150) / iSize;
		iconOffsets[1] = (height - 150) / iSize;
		updateHitbox();

		// Safely compute frame indices — some FlxTileFrames may be null/invalid
		var frameCount:Int = 1;
		try
		{
			if (this.frames != null && this.frames.frames != null)
			{
				frameCount = this.frames.frames.length;
			}
		}
		catch(e:Dynamic) { frameCount = 1; }

		var indices:Array<Int> = [];
		var limit:Int = frameCount < 1 ? 1 : frameCount;
		for (i in 0...limit) indices.push(i);
		animation.add(char, indices, 0, false, isPlayer);
		animation.play(char);

		if (char.endsWith('-pixel'))
		{
			antialiasing = false;
		}
		else
		{
			antialiasing = ClientPrefs.data.antialiasing;
		}
	}

	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();
		if (autoAdjustOffset)
		{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		}
	}

	public function getCharacter():String
	{
		return char;
	}

	public function setUseGridIcon(useGrid:Bool):Void
	{
		if (this.useGridIcon != useGrid)
		{
			this.useGridIcon = useGrid;
			// If enabling grid mode, refresh the grid mapping so newly-added
			// grid entries are available immediately.
			if (useGrid)
			{
				try
				{
					loadGridAnimationsFromFile();
				}
				catch(e:Dynamic) {}
				loadGridIcon(char);
			}
			else
			{
				loadStandardIcon(char);
			}
		}
	}

	public function isUsingGridIcon():Bool
	{
		return useGridIcon;
	}
}

