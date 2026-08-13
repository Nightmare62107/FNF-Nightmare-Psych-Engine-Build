package states;

import sys.io.File;

import backend.WeekData;

import flixel.input.keyboard.FlxKey;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.util.FlxDirectionFlags;
import haxe.Json;

import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

import shaders.ColorSwap;

import states.StoryMenuState;
import states.MainMenuState;
import states.PlayState;

typedef TitleData =
{
	var titlex:Float;
	var titley:Float;
	var startx:Float;
	var starty:Float;
	var gfx:Float;
	var gfy:Float;
	var backgroundSprite:String;
	var bpm:Float;
	
	@:optional var animation:String;
	@:optional var dance_left:Array<Int>;
	@:optional var dance_right:Array<Int>;
	@:optional var idle:Bool;
}

class TitleState extends MusicBeatState
{
	// public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	// public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	// public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;

	var credGroup:FlxGroup = new FlxGroup();
	var textGroup:FlxGroup = new FlxGroup();
	var blackScreen:FlxSprite;
	var credTextShit:Alphabet;
	var ngSpr:FlxSprite;
	
	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	var curWacky:Array<String> = [];

	var wackyImage:FlxSprite;

	var enterPressed:Bool = false;

	#if TITLE_SCREEN_EASTER_EGG
	// Special title flag (1 in 5 chance)
	var specialTitle:Bool = false;
	#end

	#if TITLE_SCREEN_EASTER_EGG
	final easterEggKeys:Array<String> = [
		'SHADOW', 'RIVEREN', 'SHUBS', 'BBPANZU', 'PESSY', 'LUDUMDARE'
	];
	final allowedKeys:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	var easterEggKeysBuffer:String = '';
	#end

	override public function create():Void
	{
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Title Screen", null);
		#end

		#if VS_SONIC_EXE_FILES
		var path = "assets/shared/images/noteSkins/list.txt";

		if (FileSystem.exists(path)) {
			var content = File.getContent(path);
			var lines:Array<String> = (content == null) ? [] : content.split("\n");
			var found:Bool = false;
			for (line in lines) {
				if (line != null && line.trim() == "Ring") {
					found = true;
					break;
				}
			}
			if (!found) {
				lines.push("Ring");
				File.saveContent(path, lines.join("\n"));
				trace("Added 'Ring' to list.txt");
			}
		}
		#else
		var path = "assets/shared/images/noteSkins/list.txt";

		if (FileSystem.exists(path)) {
			var content = File.getContent(path);
			var lines:Array<String> = (content == null) ? [] : content.split("\n");
			var newLines:Array<String> = [];
			var removed:Bool = false;
			for (line in lines) {
				if (line != null && line.trim() == "Ring") {
					removed = true;
					continue;
				}
				if (line != null) newLines.push(line);
			}
			if (removed) {
				File.saveContent(path, newLines.join("\n"));
				trace("Removed 'Ring' from list.txt");
			}
		}
		#end

		Paths.clearStoredMemory();
		super.create();
		Paths.clearUnusedMemory();

		if(!initialized)
		{
			ClientPrefs.loadPrefs();
			Language.reloadPhrases();
		}

		curWacky = FlxG.random.getObject(getIntroTextShit());

		if(!initialized)
		{
			if(FlxG.save.data != null && FlxG.save.data.fullscreen)
			{
				FlxG.fullscreen = FlxG.save.data.fullscreen;
				//trace('LOADED FULLSCREEN SETTING!!');
			}
			persistentUpdate = true;
			persistentDraw = true;
		}

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		FlxG.mouse.visible = false;
		#if FREEPLAY
		MusicBeatState.switchState(new FreeplayState());
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#else
		if(FlxG.save.data.flashing == null && !FlashingState.leftState)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
		}
		else
			startIntro();
		#end
	}

	#if TITLE_SCREEN_EASTER_EGG
	var logoBlAlt:FlxSprite;
	var logoAlt:FlxSprite;
	var bg:FlxSprite;
	#end

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;

	function startIntro()
	{
		persistentUpdate = true;
		#if TITLE_SCREEN_EASTER_EGG
		//if (FlxG.random.int(0, 4) == 0)
		// Was originally a 1 out of 5 chance to play, but I changed it to be triggered by a code.
		// Special title now triggers from the Easter egg key name 'LUDUMDARE'
		if (FlxG.save.data.psychDevsEasterEgg != null && FlxG.save.data.psychDevsEasterEgg.toUpperCase() == 'LUDUMDARE')
		{
			specialTitle = true;
			skippedIntro = true;
		}

		if (specialTitle)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.stop();
			}
			FlxG.sound.playMusic(Paths.music('title'), 0);
			FlxG.sound.music.fadeIn(4, 0, 0.7);
		}
		else if (!initialized && FlxG.sound.music == null)
		{
			#end
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
			FlxG.sound.music.fadeIn(4, 0, 0.7);
			#if TITLE_SCREEN_EASTER_EGG
		}
		#end

		loadJsonData();
		#if TITLE_SCREEN_EASTER_EGG if (specialTitle == false) easterEggData(); #end
		Conductor.bpm = musicBPM;

		#if TITLE_SCREEN_EASTER_EGG
		if (specialTitle == true)
		{
			// Create BG
			bg = new FlxSprite().loadGraphic(Paths.image('stageback'));
			bg.antialiasing = ClientPrefs.data.antialiasing;
			bg.setGraphicSize(Std.int(bg.width * 0.6));
			bg.updateHitbox();
		}
		#end

		logoBl = new FlxSprite(logoPosition.x, logoPosition.y);
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');
		logoBl.antialiasing = ClientPrefs.data.antialiasing;

		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();

		#if TITLE_SCREEN_EASTER_EGG
		if (specialTitle == true)
		{
			// Logo black and logo
			logoBlAlt = new FlxSprite().loadGraphic(Paths.image('logo'));
			logoBlAlt.screenCenter();
			logoBlAlt.color = FlxColor.BLACK;

			logoAlt = new FlxSprite().loadGraphic(Paths.image('logo'));
			logoAlt.screenCenter();
			logoAlt.antialiasing = true;
		}
		#end

		gfDance = new FlxSprite(gfPosition.x, gfPosition.y);
		gfDance.antialiasing = ClientPrefs.data.antialiasing;
		
		gfDance.frames = Paths.getSparrowAtlas(characterImage);
		if(!useIdle)
		{
			gfDance.animation.addByIndices('danceLeft', animationName, danceLeftFrames, "", 24, false);
			gfDance.animation.addByIndices('danceRight', animationName, danceRightFrames, "", 24, false);
			gfDance.animation.play('danceRight');
		}
		else
		{
			gfDance.animation.addByPrefix('idle', animationName, 24, false);
			gfDance.animation.play('idle');
		}

		var animFrames:Array<FlxFrame> = [];
		titleText = new FlxSprite(enterPosition.x + 39, enterPosition.y); // Added 39 to x to center it better.
		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		@:privateAccess
		{
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}
		
		if (newTitle = animFrames.length > 0)
		{
			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', ClientPrefs.data.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		}
		else
		{
			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}
		titleText.animation.play('idle');
		titleText.updateHitbox();

		if(ClientPrefs.data.shaders)
		{
			swagShader = new ColorSwap();
			gfDance.shader = swagShader.shader;
			logoBl.shader = swagShader.shader;
			titleText.shader = swagShader.shader;
			#if TITLE_SCREEN_EASTER_EGG
			if (specialTitle == true)
			{
				logoBlAlt.shader = swagShader.shader;
				logoAlt.shader = swagShader.shader;
				bg.shader = swagShader.shader;
			}
			#end
		}

		blackScreen = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		blackScreen.scale.set(FlxG.width, FlxG.height);
		blackScreen.updateHitbox();
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();
		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = ClientPrefs.data.antialiasing;

		#if TITLE_SCREEN_EASTER_EGG
		if (specialTitle == false)
		{
			#end
			add(gfDance);
			add(logoBl); //FNF Logo
			add(titleText); //"Press Enter to Begin" text
			add(credGroup);
			add(ngSpr);
			#if TITLE_SCREEN_EASTER_EGG
		}
		else
		{
			add(bg);
			add(logoBlAlt);
			add(logoAlt);
			FlxTween.tween(logoBlAlt, {y: logoBlAlt.y + 50}, 0.6, {ease: FlxEase.quadInOut, type: PINGPONG});
			FlxTween.tween(logoAlt, {y: logoBlAlt.y + 50}, 0.6, {ease: FlxEase.quadInOut, type: PINGPONG, startDelay: 0.1});
		}
		#end

		if (initialized)
			skipIntro();
		else
			initialized = true;

		// credGroup.add(credTextShit);
	}

	// JSON data
	var characterImage:String = 'gfDanceTitle';
	var animationName:String = 'gfDance';

	var gfPosition:FlxPoint = FlxPoint.get(512, 40);
	var logoPosition:FlxPoint = FlxPoint.get(-150, -100);
	var enterPosition:FlxPoint = FlxPoint.get(100, 576);
	
	var useIdle:Bool = false;
	var musicBPM:Float = 102;
	var danceLeftFrames:Array<Int> = [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29];
	var danceRightFrames:Array<Int> = [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];

	function loadJsonData()
	{
		if(Paths.fileExists('images/gfDanceTitle.json', TEXT))
		{
			var titleRaw:String = Paths.getTextFromFile('images/gfDanceTitle.json');
			if(titleRaw != null && titleRaw.length > 0)
			{
				try
				{
					var titleJSON:TitleData = tjson.TJSON.parse(titleRaw);
					gfPosition.set(titleJSON.gfx, titleJSON.gfy);
					logoPosition.set(titleJSON.titlex, titleJSON.titley);
					enterPosition.set(titleJSON.startx, titleJSON.starty);
					musicBPM = titleJSON.bpm;
					
					if(titleJSON.animation != null && titleJSON.animation.length > 0) animationName = titleJSON.animation;
					if(titleJSON.dance_left != null && titleJSON.dance_left.length > 0) danceLeftFrames = titleJSON.dance_left;
					if(titleJSON.dance_right != null && titleJSON.dance_right.length > 0) danceRightFrames = titleJSON.dance_right;
					useIdle = (titleJSON.idle == true);
	
					if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.trim().length > 0)
					{
						var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image(titleJSON.backgroundSprite));
						bg.antialiasing = ClientPrefs.data.antialiasing;
						add(bg);
					}
				}
				catch(e:haxe.Exception)
				{
					trace('[WARN] Title JSON might broken, ignoring issue...\n${e.details()}');
				}
			}
			else
			{
				trace('[WARN] No Title JSON detected, using default values.');
			}
		}
		//else trace('[WARN] No Title JSON detected, using default values.');
	}

	#if TITLE_SCREEN_EASTER_EGG
	function easterEggData()
	{
		if (FlxG.save.data.psychDevsEasterEgg == null) FlxG.save.data.psychDevsEasterEgg = ''; //Crash prevention
		var easterEgg:String = FlxG.save.data.psychDevsEasterEgg;
		switch(easterEgg.toUpperCase())
		{
			case 'SHADOW':
				characterImage = 'ShadowBump';
				animationName = 'Shadow Title Bump';
				gfPosition.x += 210;
				gfPosition.y += 40;
				useIdle = true;
			case 'RIVEREN':
				characterImage = 'ZRiverBump';
				animationName = 'River Title Bump';
				gfPosition.x += 180;
				gfPosition.y += 40;
				useIdle = true;
			case 'SHUBS':
				characterImage = 'ShubBump';
				animationName = 'Shubs Title Bump';
				gfPosition.x += 160;
				gfPosition.y -= 10;
				useIdle = true;
			case 'BBPANZU':
				characterImage = 'BBBump';
				animationName = 'BB Title Bump';
				danceLeftFrames = [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27];
				danceRightFrames = [27, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
				gfPosition.x += 45;
				gfPosition.y += 100;
			case 'PESSY':
				characterImage = 'PessyBump';
				animationName = 'Pessy Title Bump';
				gfPosition.x += 165;
				gfPosition.y += 60;
				danceLeftFrames = [29, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
				danceRightFrames = [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28];
		}
	}
	#end

	function getIntroTextShit():Array<Array<String>>
	{
		#if MODS_ALLOWED
		var firstArray:Array<String> = Mods.mergeAllTextsNamed('data/introText.txt');
		#else
		var fullText:String = Assets.getText(Paths.txt('introText'));
		var firstArray:Array<String> = fullText.split('\n');
		#end
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;
	private static var playJingle:Bool = false;
	
	var newTitle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
		{
			Conductor.songPosition = FlxG.sound.music.time;
		}
		// FlxG.watch.addQuick('amp', FlxG.sound.music.amplitude);

		#if windows
		// Pressing BACK on the title screen should close the game.
		// This lets you exit without leaving fullscreen mode.
		// Only applicable on windows.
		if (controls.BACK)
		{
			openfl.Lib.application.window.close();
		}
		#end

		// Ignore Alt+Enter (fullscreen) as a normal Enter press
		var pressedEnter:Bool = (FlxG.keys.justPressed.ENTER && !FlxG.keys.pressed.ALT) || controls.ACCEPT;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
			{
				pressedEnter = true;
			}

			#if switch
			if (gamepad.justPressed.B)
			{
				pressedEnter = true;
			}
			#end
		}

		#if TITLE_SCREEN_EASTER_EGG
		// Special-title enter handling: act like the normal Enter press (go to MainMenu)
		// but play the titleShoot sound for effect.
		if (specialTitle && pressedEnter && !transitioning)
		{
			if (titleText != null) titleText.animation.play('press');
			FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
			//FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
			transitioning = true;
			new FlxTimer().start(1, function(tmr:FlxTimer)
			{
				MusicBeatState.switchState(new MainMenuState());
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
				closedState = true;
			});
			try { FlxG.sound.play(Paths.music('titleShoot'), 0.7); } catch(e:Dynamic) {}
			return;
		}
		#end

		if (pressedEnter && transitioning && skippedIntro && !enterPressed)
		{
			MusicBeatState.switchState(new MainMenuState());
			if (FlxG.sound.music == null || Reflect.field(FlxG.sound.music, "_sound") != Paths.music('freakyMenu'))
			{
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
			}
			closedState = true;
			enterPressed = true;
		}
		
		if (newTitle)
		{
			titleTimer += FlxMath.bound(elapsed, 0, 1);
			if (titleTimer > 2) titleTimer -= 2;
		}

		// EASTER EGG

		if (initialized && !transitioning && skippedIntro)
		{
			if (newTitle && !pressedEnter)
			{
				var timer:Float = titleTimer;
				if (timer >= 1)
				{
					timer = (-timer) + 2;
				}
				
				timer = FlxEase.quadInOut(timer);
				
				titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
				titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
			}
			
			if (pressedEnter)
			{
				titleText.color = FlxColor.WHITE;
				titleText.alpha = 1;
				
				if (titleText != null) titleText.animation.play('press');

				FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;
				// FlxG.sound.music.stop();

				new FlxTimer().start(1, function(tmr:FlxTimer)
				{
					MusicBeatState.switchState(new MainMenuState());
					#if TITLE_SCREEN_EASTER_EGG
					if (cheatActive)
					{
						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
						FlxG.sound.music.fadeIn(4, 0, 1);
						cheatActive = false;
					}
					#end
					closedState = true;
				});
				// FlxG.sound.play(Paths.music('titleShoot'), 0.7);
			}
			#if TITLE_SCREEN_EASTER_EGG
			else if (FlxG.keys.firstJustPressed() != FlxKey.NONE)
			{
				var keyPressed:FlxKey = FlxG.keys.firstJustPressed();
				var keyName:String = Std.string(keyPressed);
				if (allowedKeys.contains(keyName))
				{
					easterEggKeysBuffer += keyName;
					if (easterEggKeysBuffer.length >= 32) easterEggKeysBuffer = easterEggKeysBuffer.substring(1);
					//trace('Test! Allowed Key pressed!!! Buffer: ' + easterEggKeysBuffer);

					for (wordRaw in easterEggKeys)
					{
						var word:String = wordRaw.toUpperCase(); //just for being sure you're doing it right
						if (easterEggKeysBuffer.contains(word))
						{
							//trace('YOOO! ' + word);
							if (FlxG.save.data.psychDevsEasterEgg == word)
							{
								FlxG.save.data.psychDevsEasterEgg = '';
							}
							else
							{
								FlxG.save.data.psychDevsEasterEgg = word;
							}
							FlxG.save.flush();

							FlxG.sound.play(Paths.sound('secret'));

							var black:FlxSprite = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.BLACK);
							black.scale.set(FlxG.width, FlxG.height);
							black.updateHitbox();
							black.alpha = 0;
							add(black);

							FlxTween.tween(black, {alpha: 1}, 1, {onComplete:
								function(twn:FlxTween)
								{
									FlxTransitionableState.skipNextTransIn = true;
									FlxTransitionableState.skipNextTransOut = true;
									MusicBeatState.switchState(new TitleState());
								}
							});
							FlxG.sound.music.fadeOut();
							if (FreeplayState.vocals != null)
							{
								FreeplayState.vocals.fadeOut();
							}
							closedState = true;
							transitioning = true;
							cheatActive = false;
							playJingle = true;
							easterEggKeysBuffer = '';
							break;
						}
					}
				}
			}
			#end
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		if (swagShader != null)
		{
			if (controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if (controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		#if TITLE_SCREEN_EASTER_EGG
		if (!cheatActive && skippedIntro && !transitioning) cheatCodeShit();
		#end
		
		super.update(elapsed);
	}

	#if TITLE_SCREEN_EASTER_EGG
	var cheatArray:Array<Int> = [0x0001, 0x0010, 0x0001, 0x0010, 0x0100, 0x1000, 0x0100, 0x1000];
	var curCheatPos:Int = 0;
	var cheatActive:Bool = false;

	function cheatCodeShit():Void
	{
		if (FlxG.keys.justPressed.ANY)
		{
			if (controls.NOTE_DOWN_P || controls.UI_DOWN_P) codePress(FlxDirectionFlags.DOWN);
			if (controls.NOTE_UP_P || controls.UI_UP_P) codePress(FlxDirectionFlags.UP);
			if (controls.NOTE_LEFT_P || controls.UI_LEFT_P) codePress(FlxDirectionFlags.LEFT);
			if (controls.NOTE_RIGHT_P || controls.UI_RIGHT_P) codePress(FlxDirectionFlags.RIGHT);
		}
	}

	function codePress(input:Int)
	{
		if (input == cheatArray[curCheatPos])
		{
			curCheatPos += 1;
			if (curCheatPos >= cheatArray.length) startCheat();
		}
		else
		{
			curCheatPos = 0;
		}

		trace(input);
	}

	function startCheat():Void
	{
		cheatActive = true;

		FlxG.sound.playMusic(Paths.music('girlfriendsRingtone'), 0);
		Conductor.bpm = 160;

		FlxG.sound.music.fadeIn(4, 0, 1);

		FlxG.camera.flash(FlxColor.WHITE, 1);
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
	}
	#end

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			if (textArray[i] == null) continue;
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if (credGroup != null && textGroup != null)
			{
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if (text == null || textGroup == null || credGroup == null)
		{
			return;
		}
		var coolText:Alphabet = new Alphabet(0, 0, text, true);
		coolText.screenCenter(X);
		coolText.y += (textGroup.length * 60) + 200 + offset;
		credGroup.add(coolText);
		textGroup.add(coolText);
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var sickBeats:Int = 0; //Basically curBeat but won't be skipped if you hold the tab or resize the screen
	public static var closedState:Bool = false;
	override function beatHit()
	{
		super.beatHit();

		#if TITLE_SCREEN_EASTER_EGG
		if (cheatActive && curBeat % 2 == 0) swagShader.hue += 0.125;
		#end

		if (logoBl != null)
		{
			logoBl.animation.play('bump', true);
		}

		if (gfDance != null)
		{
			danceLeft = !danceLeft;
			if (!useIdle)
			{
				if (danceLeft)
				{
					gfDance.animation.play('danceRight');
				}
				else
				{
					gfDance.animation.play('danceLeft');
				}
			}
			else if (curBeat % 2 == 0)
			{
				gfDance.animation.play('idle', true);
			}
		}

		if (!closedState && !specialTitle)
		{
			sickBeats++;
			switch (sickBeats)
			{
				case 1:
				{
					//FlxG.sound.music.stop();
					FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
					FlxG.sound.music.fadeIn(4, 0, 0.7);
				}

				case 2:
				{
					createCoolText(['Psych Engine by'], 40);
				}

				case 4:
				{
					addMoreText('Shadow Mario', 40);
					addMoreText('Riveren', 40);
				}

				case 5:
				{
					deleteCoolText();
				}

				case 6:
				{
					createCoolText(['Not associated', 'with'], -40);
				}

				case 8:
				{
					addMoreText('newgrounds', -40);
					ngSpr.visible = true;
				}

				case 9:
				{
					deleteCoolText();
					ngSpr.visible = false;
				}

				case 10:
				{
					createCoolText([curWacky[0]]);
				}

				case 12:
				{
					addMoreText(curWacky[1]);
				}

				case 13:
				{
					deleteCoolText();
				}

				case 14:
				{
					addMoreText('Friday');
				}

				case 15:
				{
					addMoreText('Night');
				}

				case 16:
				{
					addMoreText('Funkin'); // credTextShit.text += '\nFunkin';
				}

				case 17:
				{
					skipIntro();
				}
			}
		}
	}

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;
	function skipIntro():Void
	{
		#if TITLE_SCREEN_EASTER_EGG
		if (specialTitle) return;
		#end
		if (!skippedIntro)
		{
			#if TITLE_SCREEN_EASTER_EGG
			if (playJingle) //Ignore deez
			{
				playJingle = false;
				var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
				if (easteregg == null) easteregg = '';
				easteregg = easteregg.toUpperCase();

				var sound:FlxSound = null;
				switch(easteregg)
				{
					case 'RIVEREN':
					{
						sound = FlxG.sound.play(Paths.sound('JingleRiver'));
					}

					case 'SHUBS':
					{
						sound = FlxG.sound.play(Paths.sound('JingleShubs'));
					}

					case 'SHADOW':
					{
						FlxG.sound.play(Paths.sound('JingleShadow'));
					}

					case 'BBPANZU':
					{
						sound = FlxG.sound.play(Paths.sound('JingleBB'));
					}

					case 'PESSY':
					{
						sound = FlxG.sound.play(Paths.sound('JinglePessy'));
					}

					default: //Go back to normal ugly ass boring GF
					{
						remove(ngSpr);
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 2);
						skippedIntro = true;

						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						return;
					}
				}

				transitioning = true;
				if (easteregg == 'SHADOW')
				{
					new FlxTimer().start(3.2, function(tmr:FlxTimer)
					{
						remove(ngSpr);
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 0.6);
						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
						transitioning = false;
					});
				}
				else
				{
					if (ngSpr != null) remove(ngSpr);
					remove(credGroup);
					FlxG.camera.flash(FlxColor.WHITE, 3);
					sound.onComplete = function()
					{
						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						transitioning = false;
						#if ACHIEVEMENTS_ALLOWED
						if (easteregg == 'PESSY') Achievements.unlock('pessy_easter_egg');
						#end
					};
				}
			}
			else #end //Default! Edit this one!!
			{
				remove(ngSpr);
				remove(credGroup);
				FlxG.camera.flash(FlxColor.WHITE, 4);

				#if TITLE_SCREEN_EASTER_EGG
				var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
				if (easteregg == null) easteregg = '';
				easteregg = easteregg.toUpperCase();
				if (easteregg == 'SHADOW')
				{
					FlxG.sound.music.fadeOut();
					if (FreeplayState.vocals != null)
					{
						FreeplayState.vocals.fadeOut();
					}
				}
				#end
			}
			skippedIntro = true;
		}
	}
}
