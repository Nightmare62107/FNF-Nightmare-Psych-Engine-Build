package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;

enum MainMenuColumn {
	LEFT;
	CENTER;
	RIGHT;
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '1.0.4'; // This is also used for Discord RPC
	public static var nightmare62107BuildVersion:String = 'V8';
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;
	var allowMouse:Bool = true; //Turn this off to block mouse movement in menus

	var menuItems:FlxTypedGroup<FlxSprite>;
	var leftItem:FlxSprite;
	
	// Track scroll offset to prevent glitching during fast scrolls
	var scrollOffset:Float = 0;

	//Centered/Text options
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		//#if ACHIEVEMENTS_ALLOWED 'awards', #end // Legacy version of achievements
		'credits',
		//'donate',
		//'merch',
		//'kickstarter',
		//'options_text' // Legacy version of options
	];

	var leftOption:String = #if ACHIEVEMENTS_ALLOWED 'achievements' #else null #end;
	// Right column now supports multiple options. options_icon stays at bottom,
	// the other four are smaller and stacked above it.
	var rightOption:Array<String> = [#if ACHIEVEMENTS_ALLOWED 'awards', #end 'donate', 'merch', 'options_text', 'kickstarter', 'options_icon'];
	var rightItems:Array<FlxSprite> = [];
	var curRightSelected:Int = 0;

	var magenta:FlxSprite;
	var camFollow:FlxObject;

	static var showOutdatedWarning:Bool = true;
	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Main Menu", null);
		#end

		persistentUpdate = persistentDraw = true;

		var yScroll:Float = 0.25;
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		for (num => option in optionShit)
		{
			var item:FlxSprite = createMenuItem(option, 0, (num * 140) + 90);
			item.y += (4 - optionShit.length) * 70; // Offsets for when you have anything other than 4 items
			item.screenCenter(X);
		}

		if (leftOption != null)
		{
			leftItem = createMenuItem(leftOption, 60, 450);
		}

		if (rightOption != null && rightOption.length > 0)
		{
			var spacing:Float = 84;
			var n:Int = rightOption.length;
			for (i in 0...n)
			{
				var name = rightOption[i];
				var yPos:Float = 490 - (n - 1 - i) * spacing; // stack so last entry sits at y=490
				var item:FlxSprite = createMenuItem(name, FlxG.width - 60, yPos);
				if (name != 'options_icon')
				{
					item.scale.set(0.6, 0.6);
					item.updateHitbox();
				}
				item.x -= item.width;
				rightItems.push(item);
			}
			var idx:Int = rightOption.indexOf('options_icon');
			curRightSelected = if (idx >= 0) idx else 0;
		}

		var nightVer:FlxText = new FlxText(12, FlxG.height - 64, 0, "Nightmare62107 Build " + nightmare62107BuildVersion, 12);
		nightVer.scrollFactor.set();
		nightVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(nightVer);
		var psychVer:FlxText = new FlxText(12, FlxG.height - 44, 0, "Psych Engine v" + psychEngineVersion, 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
		var fnfVer:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);
		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
		{
			Achievements.unlock('friday_night_play');
		}

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != psychEngineVersion)
		{
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		FlxG.camera.follow(camFollow, null, 0.15);
	}

	function createMenuItem(name:String, x:Float, y:Float):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite(x, y);
		menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
		menuItem.animation.addByPrefix('idle', '$name idle', 24, true);
		menuItem.animation.addByPrefix('selected', '$name selected', 24, true);
		menuItem.animation.play('idle');
		menuItem.updateHitbox();
		
		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		menuItems.add(menuItem);
		return menuItem;
	}

	var selectedSomethin:Bool = false;

	var timeNotMoving:Float = 0;
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		// Ignore all inputs if Alt+Enter is being pressed (for fullscreen)
		if(FlxG.keys.pressed.ALT && FlxG.keys.justPressed.ENTER)
		{
			super.update(elapsed);
			return;
		}

		#if debug
		#if ACHIEVEMENTS_ALLOWED
		// Unlock all achievements with P + L combo
		if (FlxG.keys.pressed.P && FlxG.keys.pressed.L)
		{
			trace('Unlocking all achievements!');
			for (achievement in Achievements.achievements.keys())
			{
				Achievements.unlock(achievement);
			}
		}
		#end
		#end

		if (FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);
		}

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
			{
				if (curColumn == RIGHT && rightItems.length > 0)
				{
					curRightSelected = FlxMath.wrap(curRightSelected - 1, 0, rightItems.length - 1);
					changeItem();
				}
				else
				{
					changeItem(-1);
				}
				holdTime = 0;
			}

			if (controls.UI_DOWN_P)
			{
				if (curColumn == RIGHT && rightItems.length > 0)
				{
					curRightSelected = FlxMath.wrap(curRightSelected + 1, 0, rightItems.length - 1);
					changeItem();
				}
				else
				{
					changeItem(1);
				}
				holdTime = 0;
			}

			if (controls.UI_UP || controls.UI_DOWN)
			{
				var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

				if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
				{
					var deltaAmount:Int = (checkNewHold - checkLastHold) * (controls.UI_UP ? -1 : 1);
					if (curColumn == RIGHT && rightItems.length > 0)
					{
						curRightSelected = FlxMath.wrap(curRightSelected + deltaAmount, 0, rightItems.length - 1);
						changeItem();
					}
					else
					{
						changeItem(deltaAmount);
					}
				}
			}

			if (FlxG.mouse.wheel != 0)
			{
				var delta:Int = -FlxG.mouse.wheel;
				if (curColumn == RIGHT && rightItems.length > 0)
				{
					curRightSelected = FlxMath.wrap(curRightSelected + delta, 0, rightItems.length - 1);
					changeItem();
				}
				else
				{
					changeItem(delta);
				}
			}

			var localAllowMouse:Bool = this.allowMouse;
			if (localAllowMouse && ((FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed)) //FlxG.mouse.deltaScreenX/Y checks is more accurate than FlxG.mouse.justMoved
			{
				localAllowMouse = false;
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:FlxSprite = null;
				switch(curColumn)
				{
					case CENTER:
					{
						selectedItem = menuItems.members[curSelected];
					}

					case LEFT:
					{
						selectedItem = leftItem;
					}

					case RIGHT:
					{
						if (rightItems.length > 0)
						{
							selectedItem = rightItems[curRightSelected];
						}
					}
				}

				// Check left item first
				if (leftItem != null && FlxG.mouse.overlaps(leftItem))
				{
					localAllowMouse = true;
					if (selectedItem != leftItem)
					{
						curColumn = LEFT;
						changeItem();
					}
				}
				else
				{
					// Then check right items (if any)
					var hitIndex:Int = -1;
					if (rightItems.length > 0)
					{
						for (j in 0...rightItems.length)
						{
							if (FlxG.mouse.overlaps(rightItems[j]))
							{
								hitIndex = j;
								break;
							}
						}
					}

					if (hitIndex != -1)
					{
						localAllowMouse = true;
						if (selectedItem != rightItems[hitIndex])
						{
							curColumn = RIGHT;
							curRightSelected = hitIndex;
							changeItem();
						}
					}
					else
					{
						// Finally check center menu items
						var dist:Float = -1;
						var distItem:Int = -1;
						for (i in 0...optionShit.length)
						{
							var memb:FlxSprite = menuItems.members[i];
							if (FlxG.mouse.overlaps(memb))
							{
								var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
								if (dist < 0 || distance < dist)
								{
									dist = distance;
									distItem = i;
									localAllowMouse = true;
								}
							}
						}

						if (distItem != -1 && selectedItem != menuItems.members[distItem])
						{
							curColumn = CENTER;
							curSelected = distItem;
							changeItem();
						}
					}
				}
			}
			else
			{
				timeNotMoving += elapsed;
				if (timeNotMoving > 2)
				{
					FlxG.mouse.visible = false;
				}
			}

			switch(curColumn)
			{
				case CENTER:
				{
					if (controls.UI_LEFT_P && leftOption != null)
					{
						curColumn = LEFT;
						changeItem();
					}
					else if (controls.UI_RIGHT_P && rightOption != null && rightOption.length > 0)
					{
						curColumn = RIGHT;
						changeItem();
					}
				}

				case LEFT:
				{
					if (controls.UI_RIGHT_P)
					{
						curColumn = CENTER;
						changeItem();
					}
				}

				case RIGHT:
				{
					if (controls.UI_LEFT_P)
					{
						curColumn = CENTER;
						changeItem();
					}
				}
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT || (FlxG.mouse.justPressed && localAllowMouse))
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				selectedSomethin = true;
				FlxG.mouse.visible = false;

				if (ClientPrefs.data.flashing)
				{
					FlxFlicker.flicker(magenta, 1.1, 0.15, false);
				}

				var item:FlxSprite;
				var option:String;
				switch(curColumn)
				{
					case CENTER:
					{
						option = optionShit[curSelected];
						item = menuItems.members[curSelected];
					}

					case LEFT:
					{
						option = leftOption;
						item = leftItem;
					}

					case RIGHT:
					{
						option = (rightOption != null && rightOption.length > 0) ? rightOption[curRightSelected] : null;
						item = (rightItems.length > 0) ? rightItems[curRightSelected] : null;
					}
				}

				FlxFlicker.flicker(item, 1, 0.06, false, false, function(flick:FlxFlicker)
				{
					switch (option)
					{
						case 'story_mode':
						{
							MusicBeatState.switchState(new StoryMenuState());
						}

						case 'freeplay':
						{
							MusicBeatState.switchState(new FreeplayState());
							FlxG.sound.playMusic(Paths.music('freeplayRandom'), 0.7);
						}

						#if MODS_ALLOWED
						case 'mods':
						{
							MusicBeatState.switchState(new ModsMenuState());
						}
						#end

						#if ACHIEVEMENTS_ALLOWED
						case 'achievements' | 'awards':
						{
							MusicBeatState.switchState(new AchievementsMenuState());
						}
						#end

						case 'credits':
						{
							MusicBeatState.switchState(new CreditsState());
						}

						case 'options_icon' | 'options_text':
						{
							MusicBeatState.switchState(new OptionsState());
							OptionsState.onPlayState = false;
							if (PlayState.SONG != null)
							{
								PlayState.SONG.arrowSkin = null;
								PlayState.SONG.splashSkin = null;
								PlayState.stageUI = 'normal';
							}
						}

						case 'donate':
						{
							CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
							selectedSomethin = false;
							item.visible = true;
							for (memb in menuItems)
							{
								if (memb == item)
								{
									continue;
								}
								memb.alpha = 1;
								memb.animation.play('idle');
							}
						}

						case 'merch':
						{
							CoolUtil.browserLoad('https://needlejuicerecords.com/en-ca/pages/friday-night-funkin');
							selectedSomethin = false;
							item.visible = true;
							for (memb in menuItems)
							{
								if (memb == item)
								{
									continue;
								}
								memb.alpha = 1;
								memb.animation.play('idle');
							}
						}

						case 'kickstarter':
						{
							CoolUtil.browserLoad('https://kck.st/2QeVe5N');
							selectedSomethin = false;
							item.visible = true;
							for (memb in menuItems)
							{
								if (memb == item)
								{
									continue;
								}
								memb.alpha = 1;
								memb.animation.play('idle');
							}
						}

						default:
						{
							trace('Menu Item ${option} doesn\'t do anything');
							selectedSomethin = false;
							item.visible = true;
							for (memb in menuItems)
							{
								if (memb == item)
								{
									continue;
								}
								memb.alpha = 1;
								memb.animation.play('idle');
							}
						}
					}
				});
				
				for (memb in menuItems)
				{
					if (memb == item)
					{
						continue;
					}

					FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
				}
			}
			
			#if desktop
			if (controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
		}

		super.update(elapsed);
	}

	function changeItem(change:Int = 0)
	{
		if (change != 0) curColumn = CENTER;
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));

		for (item in menuItems)
		{
			item.animation.play('idle');
			item.centerOffsets();
		}

		var selectedItem:FlxSprite = null;
		switch(curColumn)
		{
			case CENTER:
			{
				selectedItem = menuItems.members[curSelected];
			}

			case LEFT:
			{
				selectedItem = leftItem;
			}

			case RIGHT:
			{
				selectedItem = (rightItems.length > 0) ? rightItems[curRightSelected] : null;
			}
		}
		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
		camFollow.y = selectedItem.getGraphicMidpoint().y;
	}
}
