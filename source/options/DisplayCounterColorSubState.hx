package options;

import flixel.util.FlxColor;

class DisplayCounterColorSubState extends MusicBeatSubstate
{
	var parentState:DisplayCounterSettingsSubState;
	var parentOption:Option;
	var grpOptions:FlxTypedGroup<Alphabet> = new FlxTypedGroup<Alphabet>();
	var menuOptions:Array<String> = [
        'Colors',
        'Special'
    ];
	public static var colorOptions:Array<String> = [
        'White',
        'Black',
        'Red',
        'Blue',
        'Green',
        'Yellow',
        'Orange',
        'Purple',
        'Pink',
		'Lime',
		'Gold',
		'Silver'
    ];
	public static var specialOptions:Array<String> = [
        'KE Rainbow'
    ];
	public static var fpsColorMap:Map<String, FlxColor> = [
		'White' => FlxColor.WHITE,
		'Black' => FlxColor.BLACK,
		'Red' => FlxColor.RED,
		'Blue' => FlxColor.BLUE,
		'Green' => FlxColor.GREEN,
		'Yellow' => FlxColor.YELLOW,
		'Orange' => FlxColor.ORANGE,
		'Purple' => FlxColor.PURPLE,
		'Pink' => FlxColor.PINK,
		'Lime' => FlxColor.LIME,
		'Gold' => FlxColor.GOLD,
		'Silver' => FlxColor.SILVER
	];
	var curSelected:Int = 0;

	public function new(parentState:DisplayCounterSettingsSubState, parentOption:Option)
	{
		super();
		this.parentState = parentState;
		this.parentOption = parentOption;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Display Counter Color Menu', null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		add(grpOptions);

		var titleText:Alphabet = new Alphabet(75, 45, 'Display Counter Color', true);
		titleText.setScale(0.6);
		titleText.alpha = 0.4;
		add(titleText);

		for (num => option in menuOptions)
		{
			var item:Alphabet = new Alphabet(0, 260, option, true);
			item.isMenuItem = true;
			item.targetY = num;
			item.changeX = false;
			item.distancePerItem.y = 90;
			item.screenCenter(X);
			grpOptions.add(item);
		}

		changeSelected();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.mouse.wheel != 0)
		{
			changeSelected(-FlxG.mouse.wheel);
		}

		if (controls.UI_UP_P)
		{
			changeSelected(-1);
		}

		if (controls.UI_DOWN_P)
		{
			changeSelected(1);
		}

		if (controls.ACCEPT)
		{
			selectMenu();
		}

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			#if DISCORD_ALLOWED
			DiscordClient.changePresence('Display Counter Settings Menu', null);
			#end
			close();
		}
	}

	function changeSelected(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, menuOptions.length - 1);
		for (num => item in grpOptions.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function selectMenu()
	{
		var selected:String = menuOptions[curSelected];
		if (selected == 'Colors')
		{
			openSubState(new DisplayCounterColorListSubState(parentState, parentOption, colorOptions, 'Colors'));
		}
		else if (selected == 'Special')
		{
			openSubState(new DisplayCounterColorListSubState(parentState, parentOption, specialOptions, 'Special'));
		}
	}

	function onChangeCounterColor()
	{
		if (Main.fpsVar != null)
		{
			var colorValue = ClientPrefs.data.fpsColor;
			var color:Null<FlxColor> = getFPSColor(colorValue);
			if (color != null)
			{
				Main.changeFPSColor(color);
			}
		}
	}

	public static function getFPSColor(colorValue:String):Null<FlxColor>
	{
		if (colorValue == null)
		{
			return null;
		}

		if (colorValue == 'Rainbow' || colorValue == 'KE Rainbow' || colorValue == 'KERAINBOW')
		{
			return FlxColor.fromRGB(148, 0, 211);
		}

		return fpsColorMap.get(colorValue);
	}
}

class DisplayCounterColorListSubState extends MusicBeatSubstate
{
	var parentState:DisplayCounterSettingsSubState;
	var parentOption:Option;
	var grpColors:FlxTypedGroup<Alphabet> = new FlxTypedGroup<Alphabet>();
	var colorOptions:Array<String>;
	var title:String;
	var curSelected:Int = 0;

	public function new(parentState:DisplayCounterSettingsSubState, parentOption:Option, colorOptions:Array<String>, title:String)
	{
		super();
		this.parentState = parentState;
		this.parentOption = parentOption;
		this.colorOptions = colorOptions;
		this.title = title;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Display Counter ' + title + ' Menu', null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		add(grpColors);

		var titleText:Alphabet = new Alphabet(75, 45, title, true);
		titleText.setScale(0.6);
		titleText.alpha = 0.4;
		add(titleText);

		for (num => color in colorOptions)
		{
			var item:Alphabet = new Alphabet(0, 260, color, true);
			item.isMenuItem = true;
			item.targetY = num;
			item.changeX = false;
			item.distancePerItem.y = 90;
			item.screenCenter(X);
			grpColors.add(item);
		}

		changeSelected();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.mouse.wheel != 0)
		{
			changeSelected(-FlxG.mouse.wheel);
		}

		if (controls.UI_UP_P)
		{
			changeSelected(-1);
		}

		if (controls.UI_DOWN_P)
		{
			changeSelected(1);
		}

		if (controls.ACCEPT)
		{
			selectColor();
		}

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			#if DISCORD_ALLOWED
			DiscordClient.changePresence('Display Counter Color Menu', null);
			#end
			close();
		}
	}

	function changeSelected(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, colorOptions.length - 1);
		for (num => item in grpColors.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function selectColor()
	{
		var chosen:String = colorOptions[curSelected];
		parentOption.setValue(chosen);
		parentOption.change();
		parentState.updateTextFrom(parentOption);
		ClientPrefs.saveSettings();

		var color:Null<FlxColor> = DisplayCounterColorSubState.getFPSColor(chosen);
		if (color != null)
		{
			Main.changeFPSColor(color);
		}

		FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
	}
}
