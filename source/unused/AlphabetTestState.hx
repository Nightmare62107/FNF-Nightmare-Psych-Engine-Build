package/* states.editors*/;

import objects.Alphabet;
import openfl.utils.Assets;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;

class AlphabetTestState extends MusicBeatState
{
	var curSelected:Int = 0;
	var grpOptions:FlxTypedGroup<Alphabet>;
	var alphabetEntries:Array<String> = [];

	public function new()
	{
		super();
	}

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		var defaultList:Array<String> = [
			"a",
			"b",
			"c",
			"d",
			"e",
			"f",
			"g",
			"h",
			"i",
			"j",
			"k",
			"l",
			"m",
			"n",
			"o",
			"p",
			"q",
			"r",
			"s",
			"t",
			"u",
			"v",
			"w",
			"x",
			"y",
			"z",
			"0",
			"1",
			"2",
			"3",
			"4",
			"5",
			"6",
			"7",
			"8",
			"9",
			"á",
			"é",
			"í",
			"ó",
			"ú",
			"à",
			"è",
			"ì",
			"ò",
			"ù",
			"â",
			"ê",
			"î",
			"ô",
			"û",
			"ã",
			"ë",
			"ï",
			"õ",
			"ü",
			"ä",
			"ö",
			"å",
			"ø",
			"æ",
			"ñ",
			"ç",
			"š",
			"ž",
			"ý",
			"ÿ",
			"ß",
			"&",
			"(",
			")",
			"[",
			"]",
			"*",
			"+",
			"-",
			"=",
			"<",
			">",
			"'",
			"\"",
			"!",
			"?",
			".",
			"❝",
			"❞",
			"_",
			"#",
			"$",
			"%",
			":",
			";",
			"@",
			"^",
			",",
			"\\",
			"/",
			"|",
			"~",
			"¡",
			"¿",
			"{",
			"}",
			"•"
		];
		alphabetEntries = defaultList;

		for (i in 0...alphabetEntries.length)
		{
			var char:String = alphabetEntries[i].length > 0 ? alphabetEntries[i] : '""';
			var normalText:Alphabet = new Alphabet(0, 320, char, false);
			normalText.isMenuItem = true;
			normalText.targetY = i;
			normalText.changeX = false;
			normalText.snapToPosition();

			var boldText:Alphabet = new Alphabet(0, 320, char, true);
			boldText.isMenuItem = true;
			boldText.targetY = i;
			boldText.changeX = false;
			boldText.snapToPosition();

			if (normalText.width > 0 && normalText.height > 0 && boldText.width > 0 && boldText.height > 0)
			{
				var widthFactor:Float = boldText.width / normalText.width;
				var heightFactor:Float = boldText.height / normalText.height;
				var scaleFactor:Float = (widthFactor + heightFactor) / 2;
				scaleFactor = Math.max(1, scaleFactor);
				scaleFactor = Math.min(scaleFactor, 1.5);
				normalText.setScale(scaleFactor);
			}

			boldText.x = FlxG.width / 2;
			normalText.x = boldText.x - normalText.width - 20;
			normalText.startPosition.x = normalText.x;
			boldText.startPosition.x = boldText.x;
			normalText.startPosition.y = 220;
			boldText.startPosition.y = 320;

			normalText.snapToPosition();
			boldText.snapToPosition();
			grpOptions.add(normalText);
			grpOptions.add(boldText);
		}

		changeSelection();
		super.create();
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, alphabetEntries.length - 1);

		for (i => item in grpOptions.members)
		{
			var pairIndex:Int = Math.floor(i / 2);
			item.targetY = pairIndex - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
	}

	var transitioning:Bool = false;
	override function update(elapsed:Float)
	{
		if (transitioning)
		{
			super.update(elapsed);
			return;
		}

		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}

		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}
		
		if (FlxG.mouse.wheel != 0)
		{
			changeSelection(-FlxG.mouse.wheel);
		}

		if (controls.BACK)
		{
			MusicBeatState.switchState(new states.editors.MasterEditorMenu());
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
			transitioning = true;
		}

		super.update(elapsed);
	}
}
