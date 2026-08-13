package options;

import objects.Note;
import objects.StrumNote;
import objects.NoteSplash;
import objects.Alphabet;
import shaders.ColorFilters;

class VisualsSettingsSubState extends BaseOptionsMenu
{
	var noteOptionID:Int = -1;
	var notes:FlxTypedGroup<StrumNote>;
	var splashes:FlxTypedGroup<NoteSplash>;
	var noteY:Float = 90;
	public function new()
	{
		title = Language.getPhrase('visuals_menu', 'Visuals Settings');
		rpcTitle = 'Visuals Settings Menu'; //for Discord Rich Presence

		// for note skins and splash skins
		notes = new FlxTypedGroup<StrumNote>();
		splashes = new FlxTypedGroup<NoteSplash>();
		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.colArray.length) * i, -200, i, 0);
			changeNoteSkin(note);
			notes.add(note);
			
			var splash:NoteSplash = new NoteSplash(0, 0, NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix());
			splash.inEditor = true;
			splash.babyArrow = note;
			splash.ID = i;
			splash.kill();
			splashes.add(splash);
		}

		// options
		var noteSkins:Array<String> = Mods.mergeAllTextsNamed('images/noteSkins/list.txt');
		if (noteSkins.length > 0)
		{
			if (!noteSkins.contains(ClientPrefs.data.noteSkin))
			{
				ClientPrefs.data.noteSkin = ClientPrefs.defaultData.noteSkin; //Reset to default if saved noteskin couldnt be found
			}

			noteSkins.insert(0, ClientPrefs.defaultData.noteSkin); //Default skin always comes first
			var option:Option = new Option('Note Skins:',
				"Select your prefered Note skin.",
				'noteSkin',
				STRING,
				noteSkins);
			addOption(option);
			option.onChange = onChangeNoteSkin;
			noteOptionID = optionsArray.length - 1;
		}
		
		var noteSplashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt');
		if (noteSplashes.length > 0)
		{
			if (!noteSplashes.contains(ClientPrefs.data.splashSkin))
			{
				ClientPrefs.data.splashSkin = ClientPrefs.defaultData.splashSkin; //Reset to default if saved splashskin couldnt be found
			}

			noteSplashes.insert(0, ClientPrefs.defaultData.splashSkin); //Default skin always comes first
			var option:Option = new Option('Note Splashes:',
				"Select your prefered Note Splash variation.",
				'splashSkin',
				STRING,
				noteSplashes);
			addOption(option);
			option.onChange = onChangeSplashSkin;
		}

		var option:Option = new Option('Note Splash Opacity',
			'How much transparent should the Note Splashes be.',
			'splashAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		option.onChange = playNoteSplashes;

		var option:Option = new Option('Hide HUD',
			'If checked, hides all HUD elements.',
			'hideHud',
			BOOL);
		addOption(option);
		
		var option:Option = new Option('Time Bar:',
			"What should the Time Bar display?",
			'timeBarType',
			STRING,
			['Time Left', 'Time Elapsed', 'Time Duration', 'Elapsed / Left', 'Elapsed / Duration', 'Duration / Left', 'Elapsed / Duration / Left', 'Song Name', 'No Text', 'Disabled']);
		addOption(option);

		var option:Option = new Option('Flashing Lights',
			"Uncheck this if you're sensitive to flashing lights!",
			'flashing',
			BOOL);
		addOption(option);

		var option:Option = new Option('Camera Zooms',
			"If unchecked, the camera won't zoom in on a beat hit.",
			'camZooms',
			BOOL);
		addOption(option);

		var option:Option = new Option('Score Text Grow on Hit',
			"If unchecked, disables the Score text growing\neverytime you hit a note.",
			'scoreZoom',
			BOOL);
		addOption(option);

		var option:Option = new Option('Score & Mechanics During Botplay',
			'If checked, score text and mechanics will work normally during botplay.\n Good for gameplay showcases and videos.',
			'scoreMechanicsBotplay',
			BOOL);
		addOption(option);

		var option:Option = new Option('Health Bar Opacity',
			'How much transparent should the health bar and icons be.',
			'healthBarAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Health Bar BG Opacity',
			'How much transparent should the health bar background be.',
			'healthBarBGAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Player/Opponent Health %',
			"If checked, adds health tracking %\non each side of the health bar.",
			'showHealthPercent',
			BOOL);
		addOption(option);

		var option:Option = new Option('Pixel Border',
			'If checked, shows a Pixel Border around the screen in Pixel Stages.',
			'pixelBorder',
			BOOL);
		addOption(option);
		
		//Moved this to Display Counter Settings.
		/*
		#if !mobile
		var option:Option = new Option('FPS Counter',
			'If unchecked, hides FPS Counter.',
			'showFPS',
			BOOL);
		addOption(option);
		option.onChange = onChangeFPSCounter;
		#end
		*/
		
		var option:Option = new Option('Pause Music:',
			"What song do you prefer for the Pause Screen?",
			'pauseMusic',
			STRING,
			['None', 'Tea Time', 'Breakfast' #if BASE_GAME_FILES , 'Breakfast Pixel', 'Breakfast Pico' #end]);
		addOption(option);
		option.onChange = onChangePauseMusic;

		var option:Option = new Option('Pause Music Changes',
			'If checked, the Pause Music will change using the one from the chart file.\nThis only works when \"Breakfast\" is chosen.',
			'pauseMusicChanges',
			BOOL);
		addOption(option);
		
		#if CHECK_FOR_UPDATES
		var option:Option = new Option('Check for Updates',
			'On Release builds, turn this on to check for updates when you start the game.',
			'checkForUpdates',
			BOOL);
		addOption(option);
		#end

		#if DISCORD_ALLOWED
		var option:Option = new Option('Discord Rich Presence',
			"Uncheck this to prevent accidental leaks, it will hide the Application from your \"Playing\" box on Discord.",
			'discordRPC',
			BOOL);
		addOption(option);
		#end

		var option:Option = new Option('Combo Stacking',
			"If unchecked, Ratings and Combo won't stack, saving on System Memory and making them easier to read.",
			'comboStacking',
			BOOL);
		addOption(option);

		var option:Option = new Option('Combo Color Change',
			"If checked, Ratings and Combo will change color based on the note color.",
			'comboColorChange',
			BOOL);
		addOption(option);

		var option:Option = new Option('Trim Combo Leading Zeros',
			'If checked, combo numbers will not show leading zeros\n(e.g. 7 instead of 0 0 7).',
			'comboTrimLeadingZeros',
			BOOL);
		addOption(option);

		var option:Option = new Option('Color Filter:',
			'Apply a color filter to the game (has colorblind modes).',
			'colorFilter',
			STRING,
			['None', 'Deuteranopia', 'Protanopia', 'Tritanopia', 'Greyscale', 'Inverted']);
		option.onChange = ColorFilters.applyFiltersOnGame;
		addOption(option);

		var option:Option = new Option('3D Filter:',
			'Choose a stereoscopic 3D rendering mode.',
			'threeDMode',
			STRING,
			['None', 'Cross-Eye 3D', 'Anaglyph (Red/Cyan)']);
		addOption(option);

		option = new Option('3D Depth Intensity:',
			'How strong the 3D depth effect is.',
			'threeDIntensity',
			FLOAT);
		option.scrollSpeed = 0.001;
		option.minValue = 0.001;
		option.maxValue = 0.015;
		option.changeValue = 0.001;
		option.decimals = 3;
		addOption(option);

		option = new Option('UI Parallax Separation:',
			'Adjusts the 3D depth gap between the stage and the HUD/notes.',
			'threeDSeparation',
			FLOAT);
		option.scrollSpeed = 0.1;
		option.minValue = 0.0; // 0.0 = completely flat together
		option.maxValue = 2.0; // 2.0 = maximum layer separation
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		super();
		add(notes);
		add(splashes);
	}

	var notesShown:Bool = false;
	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		
		switch(curOption.variable)
		{
			case 'noteSkin', 'splashSkin', 'splashAlpha':
			{
				if (!notesShown)
				{
					for (note in notes.members)
					{
						FlxTween.cancelTweensOf(note);
						FlxTween.tween(note, {y: noteY}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
					}
				}
				notesShown = true;
				if (curOption.variable.startsWith('splash') && Math.abs(notes.members[0].y - noteY) < 25)
				{
					playNoteSplashes();
				}
			}

			default:
			{
				if (notesShown) 
				{
					for (note in notes.members)
					{
						FlxTween.cancelTweensOf(note);
						FlxTween.tween(note, {y: -200}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
					}
				}
				notesShown = false;
			}
		}
	}

	var changedMusic:Bool = false;
	function onChangePauseMusic()
	{
		if (ClientPrefs.data.pauseMusic == 'None')
		{
			FlxG.sound.music.volume = 0;
		}
		else
		{
			FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)));
		}

		changedMusic = true;
	}

	function onChangeNoteSkin()
	{
		notes.forEachAlive(function(note:StrumNote)
		{
			changeNoteSkin(note);
			note.centerOffsets();
			note.centerOrigin();
		});
	}

	function changeNoteSkin(note:StrumNote)
	{
		var skin:String = Note.defaultNoteSkin;
		var customSkin:String = skin + Note.getNoteSkinPostfix();
		if (Paths.fileExists('images/$customSkin.png', IMAGE))
		{
			skin = customSkin;
		}

		note.texture = skin; //Load texture and anims
		note.reloadNote();
		note.playAnim('static');
	}

	function onChangeSplashSkin()
	{
		var skin:String = NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix();
		for (splash in splashes)
		{
			splash.loadSplash(skin);
		}

		playNoteSplashes();
	}

	function playNoteSplashes()
	{
		var rand:Int = 0;
		if (splashes.members[0] != null && splashes.members[0].maxAnims > 1)
		{
			rand = FlxG.random.int(0, splashes.members[0].maxAnims - 1); //For playing the same random animation on all 4 splashes
		}

		for (splash in splashes)
		{
			splash.revive();

			splash.spawnSplashNote(0, 0, splash.ID, null, false);
			if (splash.maxAnims > 1)
			{
				splash.noteData = splash.noteData % Note.colArray.length + (rand * Note.colArray.length);
			}

			var anim:String = splash.playDefaultAnim();
			var conf = splash.config.animations.get(anim);
			var offsets:Array<Float> = [0, 0];

			var minFps:Int = 22;
			var maxFps:Int = 26;
			if (conf != null)
			{
				offsets = conf.offsets;

				minFps = conf.fps[0];
				if (minFps < 0)
				{
					minFps = 0;
				}

				maxFps = conf.fps[1];
				if (maxFps < 0)
				{
					maxFps = 0;
				}
			}

			splash.offset.set(10, 10);
			if (offsets != null)
			{
				splash.offset.x += offsets[0];
				splash.offset.y += offsets[1];
			}

			if (splash.animation.curAnim != null)
			{
				splash.animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);
			}
		}
	}

	override function destroy()
	{
		if (changedMusic && !OptionsState.onPlayState)
		{
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7, true);
		}
		Note.globalRgbShaders = [];
		super.destroy();
	}

	#if !mobile
	function onChangeFPSCounter()
	{
		if (Main.fpsVar != null)
		{
			Main.fpsVar.visible = ClientPrefs.data.showFPS;
		}
	}
	#end
}
