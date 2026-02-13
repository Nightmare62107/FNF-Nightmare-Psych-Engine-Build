package states;

import backend.Highscore;
import backend.StageData;
import backend.WeekData;
import backend.Song;
import backend.Rating;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.animation.FlxAnimationController;
import flixel.effects.FlxFlicker;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import openfl.events.KeyboardEvent;
import haxe.Json;

import cutscenes.DialogueBoxPsych;

import states.StoryMenuState;
import states.FreeplayState;
import states.editors.ChartingState;
import states.editors.CharacterEditorState;

import substates.PauseSubState;
import substates.GameOverSubstate;

#if !flash
import openfl.filters.ShaderFilter;
#end

import shaders.ErrorHandledShader;

import objects.VideoSprite;
import objects.Note.EventNote;
import objects.*;
import states.stages.*;
import states.stages.objects.*;

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript.HScriptInfos;
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
#end

/**
 * This is where all the Gameplay stuff happens and is managed
 *
 * here's some useful tips if you are making a mod in source:
 *
 * If you want to add your stage to the game, copy states/stages/Template.hx,
 * and put your stage code there, then, on PlayState, search for
 * "switch (curStage)", and add your stage to that list.
 *
 * If you want to code Events, you can either code it on a Stage file or on PlayState, if you're doing the latter, search for:
 *
 * "function eventPushed" - Only called *one time* when the game loads, use it for precaching events that use the same assets, no matter the values
 * "function eventPushedUnique" - Called one time per event, use it for precaching events that uses different assets based on its values
 * "function eventEarlyTrigger" - Used for making your event start a few MILLISECONDS earlier
 * "function triggerEvent" - Called when the song hits your event's timestamp, this is probably what you were looking for
**/
class PlayState extends MusicBeatState
{
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;

	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], //From 0% to 19%
		['Shit', 0.4], //From 20% to 39%
		['Bad', 0.5], //From 40% to 49%
		['Bruh', 0.6], //From 50% to 59%
		['Meh', 0.69], //From 60% to 68%
		['Nice', 0.7], //69%
		['Good', 0.8], //From 70% to 79%
		['Great', 0.9], //From 80% to 89%
		['Sick!', 1], //From 90% to 99%
		['Perfect!!', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];

	//event variables
	private var isCameraOnForcedPos:Bool = false;

	public var boyfriendMap:Map<String, Character> = new Map<String, Character>();
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	public var gfMap:Map<String, Character> = new Map<String, Character>();

	#if HSCRIPT_ALLOWED
	public var hscriptArray:Array<HScript> = [];
	#end

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;

	public var playbackRate(default, set):Float = 1;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public static var curStage:String = '';
	public static var stageUI(default, set):String = "normal";
	public static var uiPrefix:String = "";
	public static var uiPostfix:String = "";
	public static var isPixelStage(get, never):Bool;

	@:noCompletion
	static function set_stageUI(value:String):String
	{
		uiPrefix = uiPostfix = "";
		if (value != "normal")
		{
			uiPrefix = value.split("-pixel")[0].trim();
			if (value == "pixel" || value.endsWith("-pixel")) uiPostfix = "-pixel";
		}
		return stageUI = value;
	}

	@:noCompletion
	static function get_isPixelStage():Bool
		return stageUI == "pixel" || stageUI.endsWith("-pixel");

	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public var spawnTime:Float = 2000;

	public var inst:FlxSound;
	public var vocals:FlxSound;
	public var opponentVocals:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	public var camFollow:FlxObject;
	private static var prevCamFollow:FlxObject;

	#if BALDIS_BASICS_IN_FUNKIN_FILES
	private var screenShake:Bool = false;
	#end

	public var strumLineNotes:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var opponentStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var playerStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash> = new FlxTypedGroup<NoteSplash>();

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;
	private var curSong:String = "";

	public var gfSpeed:Int = 1;
	public var health(default, set):Float = 1;
	public var combo:Int = 0;

	public var healthBar:Bar;
	public var healthBarBG:FlxSprite;
	public var timeBar:Bar;
	var songPercent:Float = 0;

	public var ratingsData:Array<Rating> = Rating.loadDefault();

	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	private var updateTime:Bool = true;
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	//Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var healthDrain:Bool = false;

	public var guitarHeroSustains:Bool = false;
	#if VS_SONIC_EXE_FILES
	public var ringSystem:Bool = false;
	#end
	public var maxMisses:Bool = false;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;
	public var pressMissDamage:Float = 0.05;

	public var botplaySine:Float = 180;
	public var botplayTxt:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	#if BASE_GAME_FILES
	// Characters for which pressing NINE will change the player icon to 'bf-old'.
	public static var allowedP1Characters:Array<String> = [
		'bf',
		'bf-opponent',
		'bf-pixel',
		'bf-pixel-opponent',
		'bf-christmas',
		'bf-car',
		'bf-holding-gf'
	];
	// Call this from mods/scripts to add characters one-by-one (e.g. addAllowedPlayerCharacter('bf'))
	public static function addAllowedPlayerCharacter(name:String):Void
	{
		if (name == null) return;
		var key:String = name.toLowerCase();
		if (allowedP1Characters.indexOf(key) == -1) allowedP1Characters.push(key);
	}

	// Toggle state for bf-old switch (pressing NINE again restores previous icon/color)
	private var bfOldToggled:Bool = false;
	private var bfOldLastCharacter:String = null;
	#end
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var maxSongMisses:Int = 10;
	public var scoreTxt:FlxText;
	public var maxMissTxt:FlxText;
	public var maxMissAD:FlxText;
	#if VS_SONIC_EXE_FILES
	public var ringCounter:FlxSprite;
	public var counterNum:FlxText;
	public var cNum:Int = 0;
	#end
	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom:Float = 1.05;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;
	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;
	var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	#if DISCORD_ALLOWED
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	//Achievement shit
	var keysPressed:Array<Int> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	// Lua shit
	public static var instance:PlayState;
	#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	private var luaDebugGroup:FlxTypedGroup<psychlua.DebugLuaText>;
	#end
	public var introSoundsSuffix:String = '';

	// Less laggy controls
	private var keysArray:Array<String>;
	public var songName:String;

	// Callbacks for stages
	public var startCallback:Void->Void = null;
	public var endCallback:Void->Void = null;

	private static var _lastLoadedModDirectory:String = '';
	public static var nextReloadAll:Bool = false;
	override public function create()
	{
		//trace('Playback Rate: ' + playbackRate);
		_lastLoadedModDirectory = Mods.currentModDirectory;
		Paths.clearStoredMemory();
		if (nextReloadAll)
		{
			Paths.clearUnusedMemory();
			Language.reloadPhrases();
		}
		nextReloadAll = false;

		startCallback = startCountdown;
		endCallback = endSong;

		// for lua
		instance = this;

		PauseSubState.songName = null; //Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed');

		keysArray = [
			'note_left',
			'note_down',
			'note_up',
			'note_right'
		];

		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
		}

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain');
		healthLoss = ClientPrefs.getGameplaySetting('healthloss');
		healthDrain = ClientPrefs.getGameplaySetting('healthdrain');
		skipCountdown = ClientPrefs.getGameplaySetting('skipcountdown');
		#if VS_SONIC_EXE_FILES
		ringSystem = ClientPrefs.getGameplaySetting('ringsystem');
		#end
		maxMisses = ClientPrefs.getGameplaySetting('maxmisses');
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill');
		practiceMode = ClientPrefs.getGameplaySetting('practice');
		cpuControlled = ClientPrefs.getGameplaySetting('botplay');
		guitarHeroSustains = ClientPrefs.data.guitarHeroSustains;

		// var gameCam:FlxCamera = FlxG.camera;
		camGame = initPsychCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		persistentUpdate = true;
		persistentDraw = true;

		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;

		#if DISCORD_ALLOWED
		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		storyDifficultyText = Difficulty.getString();

		if (isStoryMode)
		{
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		}
		else
		{
			detailsText = "Freeplay";
		}

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		PauseSubState.resetVariables();
		songName = Paths.formatToSongPath(SONG.song);
		if (SONG.stage == null || SONG.stage.length < 1)
		{
			SONG.stage = StageData.vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));
		}

		curStage = SONG.stage;

		var stageData:StageFile = StageData.getStageFile(curStage);
		defaultCamZoom = stageData.defaultZoom;

		stageUI = "normal";
		if (stageData.stageUI != null && stageData.stageUI.trim().length > 0)
		{
			stageUI = stageData.stageUI;
		}
		else if (stageData.isPixelStage == true) //Backward compatibility
		{
			stageUI = "pixel";
		}

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if (stageData.camera_speed != null)
		{
			cameraSpeed = stageData.camera_speed;
		}

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if (boyfriendCameraOffset == null) //Fucks sake should have done it since the start :rolling_eyes:
		{
			boyfriendCameraOffset = [0, 0];
		}

		opponentCameraOffset = stageData.camera_opponent;
		if (opponentCameraOffset == null)
		{
			opponentCameraOffset = [0, 0];
		}

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if (girlfriendCameraOffset == null)
		{
			girlfriendCameraOffset = [0, 0];
		}

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		switch (curStage)
		{
			case 'stage': new StageWeek1(); 			//Test + Tutorial + Week 1 - Bopeebo, Fresh, Dad Battle
			case 'spooky': new Spooky();				//Week 2 - Spookeez, South, Monster
			case 'philly': new Philly();				//Week 3 - Pico, Philly Nice, Blammed
			case 'limo': new Limo();					//Week 4 - Satin Panties, High, Milf
			case 'mall': new Mall();					//Week 5 - Cocoa, Eggnog
			case 'mallEvil': new MallEvil();			//Week 5 - Winter Horrorland
			case 'school': new School();				//Week 6 - Senpai, Roses
			case 'schoolErect': new SchoolErect();		//Week 6 Erect - Senpai Erect, Roses Erect
			case 'schoolEvil': new SchoolEvil();		//Week 6 - Thorns
			case 'tank': new Tank();					//Week 7 - Ugh, Guns, Stress
			case 'phillyStreets': new PhillyStreets(); 	//Weekend 1 - Darnell, Lit Up, 2Hot
			case 'phillyBlazin': new PhillyBlazin();	//Weekend 1 - Blazin
		}
		if (isPixelStage) introSoundsSuffix = '-pixel';

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		luaDebugGroup = new FlxTypedGroup<psychlua.DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		if (!stageData.hide_girlfriend)
		{
			if (SONG.gfVersion == null || SONG.gfVersion.length < 1) SONG.gfVersion = 'gf'; //Fix for the Chart Editor
			gf = new Character(0, 0, SONG.gfVersion);
			startCharacterPos(gf);
			gfGroup.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);

		boyfriend = new Character(0, 0, SONG.player1, true);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		
		if (stageData.objects != null && stageData.objects.length > 0)
		{
			var list:Map<String, FlxSprite> = StageData.addObjectsToState(stageData.objects, !stageData.hide_girlfriend ? gfGroup : null, dadGroup, boyfriendGroup, this);
			for (key => spr in list)
			{
				if (!StageData.reservedNames.contains(key))
				{
					variables.set(key, spr);
				}
			}
		}
		else
		{
			add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);
		}
		
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		// "SCRIPTS FOLDER" SCRIPTS
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts/'))
		{
			for (file in FileSystem.readDirectory(folder))
			{
				#if LUA_ALLOWED
				if (file.toLowerCase().endsWith('.lua'))
				{
					new FunkinLua(folder + file);
				}
				#end

				#if HSCRIPT_ALLOWED
				if (file.toLowerCase().endsWith('.hx'))
				{
					initHScript(folder + file);
				}
				#end
			}
		}
		#end
			
		var camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if (gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if (dad.curCharacter.startsWith('gf'))
		{
			dad.setPosition(GF_X, GF_Y);
			if (gf != null)
			{
				gf.visible = false;
			}
		}
		
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		// STAGE SCRIPTS
		#if LUA_ALLOWED startLuasNamed('stages/' + curStage + '.lua'); #end
		#if HSCRIPT_ALLOWED startHScriptsNamed('stages/' + curStage + '.hx'); #end

		// CHARACTER SCRIPTS
		if (gf != null) startCharacterScripts(gf.curCharacter);
		startCharacterScripts(dad.curCharacter);
		startCharacterScripts(boyfriend.curCharacter);
		#end

		uiGroup = new FlxSpriteGroup();
		comboGroup = new FlxSpriteGroup();
		noteGroup = new FlxTypedGroup<FlxBasic>();
		add(comboGroup);
		add(uiGroup);
		add(noteGroup);

		Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		var showTime:Bool = (ClientPrefs.data.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = updateTime = showTime;
		if (ClientPrefs.data.downScroll) timeTxt.y = FlxG.height - 44;
		if (ClientPrefs.data.timeBarType == 'Song Name') timeTxt.text = SONG.song;
		if (ClientPrefs.data.timeBarType == 'No Text')
		{
			timeTxt.text = '';
		}

		timeBar = new Bar(0, timeTxt.y + (timeTxt.height / 4), 'timeBar', function() return songPercent, 0, 1);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		uiGroup.add(timeBar);
		uiGroup.add(timeTxt);

		noteGroup.add(strumLineNotes);

		if (ClientPrefs.data.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		generateSong();

		noteGroup.add(grpNoteSplashes);

		camFollow = new FlxObject();
		camFollow.setPosition(camPos.x, camPos.y);
		camPos.put();

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.snapToTarget();

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		moveCameraSection();

		healthBar = new Bar(0, FlxG.height * (!ClientPrefs.data.downScroll ? 0.89 : 0.11), 'healthBar', function() return health, 0, 2);
		healthBar.screenCenter(X);
		healthBar.leftToRight = false;
		healthBar.scrollFactor.set();
		healthBar.visible = !ClientPrefs.data.hideHud;
		healthBar.alpha = ClientPrefs.data.healthBarAlpha;
		reloadHealthBarColors();

		healthBarBG = new FlxSprite().loadGraphic(Paths.image('healthBarBG'));
		healthBarBG.y = healthBar.y - 20;
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();
		healthBarBG.visible = !ClientPrefs.data.hideHud;
		healthBarBG.alpha = ClientPrefs.data.healthBarBGAlpha * ClientPrefs.data.healthBarAlpha;

		//Add BG First so the actual bar is on top of it
		uiGroup.add(healthBarBG);
		uiGroup.add(healthBar);

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.data.hideHud;
		iconP1.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.data.hideHud;
		iconP2.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP2);

		scoreTxt = new FlxText(0, healthBar.y + 40, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		uiGroup.add(scoreTxt);

		maxMissAD = new FlxText(0, healthBar.y + 36, FlxG.width, "", 20);
		maxMissAD.setFormat(Paths.font("vcr.ttf"), 50, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		maxMissAD.scrollFactor.set();
		maxMissAD.screenCenter();
		maxMissAD.borderSize = 1.25;
		maxMissAD.visible = false;
		if (maxMisses)
		{
			uiGroup.add(maxMissAD);
		}

		maxMissTxt = new FlxText(470, healthBar.y - 7, FlxG.width, "", 20);
		maxMissTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		maxMissTxt.scrollFactor.set();
		maxMissTxt.borderSize = 1.25;
		maxMissTxt.visible = false;
		if (maxMisses)
		{
			uiGroup.add(maxMissTxt);
		}

		if (maxMisses && instakillOnMiss)
		{
			maxSongMisses = 1;
		}

		#if VS_SONIC_EXE_FILES
		if (!isPixelStage)
		{
			ringCounter = new FlxSprite(0, 0).loadGraphic(Paths.image('ringcounter'));
		}
		else
		{
			ringCounter = new FlxSprite(0, 0).loadGraphic(Paths.image('pixelUI/ringcounter-pixel'));
		}
		if (!PlayState.isPixelStage)
		{
			ringCounter.x = 1133;
		}
		else
		{
			ringCounter.x = 1113;
		}
		if (maxMisses)
		{
			if (ClientPrefs.data.downScroll)
			{
				if (!PlayState.isPixelStage)
				{
					ringCounter.y = 30 + 100;
				}
				else
				{
					ringCounter.y = 20 + 100;
				}
			}
			else
			{
				if (!PlayState.isPixelStage)
				{
					ringCounter.y = 610 - 80;
				}
				else
				{
					ringCounter.y = 600 - 80;
				}
			}
		}
		else
		{
			if (ClientPrefs.data.downScroll)
			{
				if (!PlayState.isPixelStage)
				{
					ringCounter.y = 30;
				}
				else
				{
					ringCounter.y = 20;
				}
			}
			else
			{
				if (!PlayState.isPixelStage)
				{
					ringCounter.y = 610;
				}
				else
				{
					ringCounter.y = 600;
				}
			}
		}

		if (PlayState.isPixelStage)
		{
			ringCounter.setGraphicSize(Std.int(ringCounter.width * daPixelZoom * 0.45));
			ringCounter.updateHitbox();
		}

		if (ringSystem)
		{
			uiGroup.add(ringCounter);
		}

		counterNum = new FlxText(0, 0, FlxG.width, '0', 10);
		if (!isPixelStage)
		{
			counterNum.setFormat("EurostileTBla.ttf", 32, FlxColor.fromRGB(255, 204, 51), FlxTextBorderStyle.OUTLINE, FlxColor.fromRGB(204, 102, 0));
			counterNum.setBorderStyle(OUTLINE, FlxColor.fromRGB(204, 102, 0), 3, 1);
		}
		else
		{
			counterNum.setFormat("pixel-latin.ttf", 24, FlxColor.fromRGB(255, 204, 51), FlxTextBorderStyle.OUTLINE, FlxColor.fromRGB(204, 102, 0));
			counterNum.setBorderStyle(OUTLINE, FlxColor.fromRGB(151, 76, 0), 3, 1);
		}
		if (!isPixelStage)
		{
			counterNum.x = ringCounter.x + 74;
			counterNum.y = ringCounter.y + 20;
		}
		else
		{
			counterNum.x = ringCounter.x + 85;
			counterNum.y = ringCounter.y + 36;
		}
		if (ringSystem)
		{
			uiGroup.add(counterNum);
		}
		#end

		botplayTxt = new FlxText(400, timeBar.y + 55, FlxG.width - 805, Language.getPhrase("Botplay").toUpperCase(), 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		uiGroup.add(botplayTxt);
		if (ClientPrefs.data.middleScroll)
		{
			if (ClientPrefs.data.downScroll)
			{
				botplayTxt.y = healthBar.y + 70;
			}
			else
			{
				botplayTxt.y = healthBar.y - 90;
			}
		}
		else
		{
			if (ClientPrefs.data.downScroll)
			{
				botplayTxt.y = timeBar.y - 75;
			}
		}

		uiGroup.cameras = [camHUD];
		noteGroup.cameras = [camHUD];
		comboGroup.cameras = [camHUD];

		startingSong = true;

		#if LUA_ALLOWED
		for (notetype in noteTypes)
		{
			startLuasNamed('custom_notetypes/' + notetype + '.lua');
		}
		for (event in eventsPushed)
		{
			startLuasNamed('custom_events/' + event + '.lua');
		}
		#end

		#if HSCRIPT_ALLOWED
		for (notetype in noteTypes)
		{
			startHScriptsNamed('custom_notetypes/' + notetype + '.hx');
		}
		for (event in eventsPushed)
		{
			startHScriptsNamed('custom_events/' + event + '.hx');
		}
		#end
		noteTypes = null;
		eventsPushed = null;

		// SONG SPECIFIC SCRIPTS
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/$songName/'))
		{
			for (file in FileSystem.readDirectory(folder))
			{
				#if LUA_ALLOWED
				if (file.toLowerCase().endsWith('.lua'))
				{
					new FunkinLua(folder + file);
				}
				#end

				#if HSCRIPT_ALLOWED
				if (file.toLowerCase().endsWith('.hx'))
				{
					initHScript(folder + file);
				}
				#end
			}
		}
		#end

		if (eventNotes.length > 0)
		{
			for (event in eventNotes)
			{
				event.strumTime -= eventEarlyTrigger(event);
			}
			eventNotes.sort(sortByTime);
		}

		startCallback();
		RecalculateRating(false, false);

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		// PRECACHING THINGS THAT GET USED FREQUENTLY TO AVOID LAGSPIKES
		if (ClientPrefs.data.hitsoundVolume > 0) Paths.sound('hitsound');
		if (/*!ClientPrefs.data.ghostTapping &&*/ ClientPrefs.data.missSounds) for (i in 1...4) Paths.sound('missnote$i');
		Paths.image('alphabet');

		if (PauseSubState.songName != null)
		{
			Paths.music(PauseSubState.songName);
		}
		else if (Paths.formatToSongPath(ClientPrefs.data.pauseMusic) != 'none')
		{
			if (ClientPrefs.data.pauseMusic == 'Breakfast')
			{
				if (ClientPrefs.data.pauseMusicChanges == true)
				{
					Paths.music(Paths.formatToSongPath(PauseSubState.pauseBreakfastName));
				}
				else
				{
					Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic));
				}
			}
			else
			{
				Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic));
			}
		}

		resetRPC();

		stagesFunc(function(stage:BaseStage) stage.createPost());
		callOnScripts('onCreatePost');
		
		var splash:NoteSplash = new NoteSplash();
		grpNoteSplashes.add(splash);
		splash.alpha = 0.000001; // cant make it invisible or it won't allow precaching

		super.create();
		Paths.clearUnusedMemory();

		cacheCountdown();
		cachePopUpScore();

		if (eventNotes.length < 1)
		{
			checkEventNote();
		}
	}

	function set_songSpeed(value:Float):Float
	{
		if (generatedMusic)
		{
			var ratio:Float = value / songSpeed; // funny word huh
			if (ratio != 1)
			{
				for (note in notes.members)
				{
					note.resizeByRatio(ratio);
				}

				for (note in unspawnNotes)
				{
					note.resizeByRatio(ratio);
				}
			}
		}
		songSpeed = value;
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);
		return value;
	}

	function set_playbackRate(value:Float):Float
	{
		#if FLX_PITCH
		if (generatedMusic)
		{
			vocals.pitch = value;
			opponentVocals.pitch = value;
			FlxG.sound.music.pitch = value;

			var ratio:Float = playbackRate / value; // funny word huh
			if (ratio != 1)
			{
				for (note in notes.members)
				{
					note.resizeByRatio(ratio);
				}

				for (note in unspawnNotes)
				{
					note.resizeByRatio(ratio);
				}
			}
		}
		playbackRate = value;
		FlxG.animationTimeScale = value;
		Conductor.offset = Reflect.hasField(PlayState.SONG, 'offset') ? (PlayState.SONG.offset / value) : 0;
		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames / 60) * 1000 * value;
		#if VIDEOS_ALLOWED
		if (videoCutscene != null && videoCutscene.videoSprite != null) videoCutscene.videoSprite.bitmap.rate = value;
		#end
		setOnScripts('playbackRate', playbackRate);
		#else
		playbackRate = 1.0; // ensuring -Crow
		#end
		return playbackRate;
	}

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	public function addTextToDebug(text:String, color:FlxColor)
	{
		var newText:psychlua.DebugLuaText = luaDebugGroup.recycle(psychlua.DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);

		luaDebugGroup.forEachAlive(function(spr:psychlua.DebugLuaText)
		{
			spr.y += newText.height + 2;
		});
		luaDebugGroup.add(newText);

		Sys.println(text);
	}
	#end

	public function reloadHealthBarColors()
	{
		healthBar.setColors(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]), FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));
	}

	public function addCharacterToList(newCharacter:String, type:Int)
	{
		switch(type)
		{
			case 0:
			{
				if (!boyfriendMap.exists(newCharacter))
				{
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterScripts(newBoyfriend.curCharacter);
				}
			}

			case 1:
			{
				if (!dadMap.exists(newCharacter))
				{
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScripts(newDad.curCharacter);
				}
			}

			case 2:
			{
				if (gf != null && !gfMap.exists(newCharacter))
				{
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterScripts(newGf.curCharacter);
				}
			}
		}
	}

	function startCharacterScripts(name:String)
	{
		// Lua
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/$name.lua';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(luaFile);
		if (FileSystem.exists(replacePath))
		{
			luaFile = replacePath;
			doPush = true;
		}
		else
		{
			luaFile = Paths.getSharedPath(luaFile);
			if (FileSystem.exists(luaFile))
			{
				doPush = true;
			}
		}
		#else
		luaFile = Paths.getSharedPath(luaFile);
		if (Assets.exists(luaFile))
		{
			doPush = true;
		}
		#end

		if (doPush)
		{
			for (script in luaArray)
			{
				if (script.scriptName == luaFile)
				{
					doPush = false;
					break;
				}
			}

			if (doPush)
			{
				new FunkinLua(luaFile);
			}
		}
		#end

		// HScript
		#if HSCRIPT_ALLOWED
		var doPush:Bool = false;
		var scriptFile:String = 'characters/' + name + '.hx';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(scriptFile);
		if (FileSystem.exists(replacePath))
		{
			scriptFile = replacePath;
			doPush = true;
		}
		else
		{
		#end
			scriptFile = Paths.getSharedPath(scriptFile);
			if (FileSystem.exists(scriptFile))
			{
				doPush = true;
			}
		#if MODS_ALLOWED
		}
		#end

		if (doPush)
		{
			if (Iris.instances.exists(scriptFile))
			{
				doPush = false;
			}

			if (doPush)
			{
				initHScript(scriptFile);
			}
		}
		#end
	}

	public function getLuaObject(tag:String):Dynamic
	{
		return variables.get(tag);
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false)
	{
		if (gfCheck && char.curCharacter.startsWith('gf')) //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
		{
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public var videoCutscene:VideoSprite = null;
	public function startVideo(name:String, forMidSong:Bool = false, canSkip:Bool = true, loop:Bool = false, playOnLoad:Bool = true)
	{
		#if VIDEOS_ALLOWED
		inCutscene = !forMidSong;
		canPause = forMidSong;

		var foundFile:Bool = false;
		var fileName:String = Paths.video(name);

		#if sys
		if (FileSystem.exists(fileName))
		#else
		if (OpenFlAssets.exists(fileName))
		#end
		foundFile = true;

		if (foundFile)
		{
			videoCutscene = new VideoSprite(fileName, forMidSong, canSkip, loop);
			if (forMidSong)
			{
				videoCutscene.videoSprite.bitmap.rate = playbackRate;
			}

			// Finish callback
			if (!forMidSong)
			{
				function onVideoEnd()
				{
					if (!isDead && generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null && !endingSong && !isCameraOnForcedPos)
					{
						moveCameraSection();
						FlxG.camera.snapToTarget();
					}
					videoCutscene = null;
					canPause = true;
					inCutscene = false;
					startAndEnd();
				}
				videoCutscene.finishCallback = onVideoEnd;
				videoCutscene.onSkip = onVideoEnd;
			}

			if (GameOverSubstate.instance != null && isDead)
			{
				GameOverSubstate.instance.add(videoCutscene);
			}
			else
			{
				add(videoCutscene);
			}

			if (playOnLoad)
			{
				videoCutscene.play();
			}

			return videoCutscene;
		}
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		else
		{
			addTextToDebug("Video not found: " + fileName, FlxColor.RED);
		}
		#else
		else
		{
			FlxG.log.error("Video not found: " + fileName);
		}
		#end
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd();
		#end
		return null;
	}

	function startAndEnd()
	{
		if (endingSong)
		{
			endSong();
		}
		else
		{
			startCountdown();
		}
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(DialogueBoxPsych.parseDialogue(Paths.json(songName + '/dialogue')))" and it should load dialogue.json
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if (psychDialogue != null)
		{
			return;
		}

		if (dialogueFile.dialogue.length > 0)
		{
			inCutscene = true;
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if (endingSong)
			{
				psychDialogue.finishThing = function()
				{
					psychDialogue = null;
					endSong();
				}
			}
			else
			{
				psychDialogue.finishThing = function()
				{
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		}
		else
		{
			FlxG.log.warn('Your dialogue file is badly formatted!');
			startAndEnd();
		}
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;
	public static var startOnTime:Float = 0;

	function cacheCountdown()
	{
		var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
		var introImagesArray:Array<String> = switch(stageUI)
		{
			case "pixel":
			{
				['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel'];
			}

			case "normal":
			{
				["ready", "set" ,"go"];
			}

			default:
			{
				['${uiPrefix}UI/ready${uiPostfix}', '${uiPrefix}UI/set${uiPostfix}', '${uiPrefix}UI/go${uiPostfix}'];
			}
		}
		introAssets.set(stageUI, introImagesArray);
		var introAlts:Array<String> = introAssets.get(stageUI);
		for (asset in introAlts)
		{
			Paths.image(asset);
		}

		Paths.sound('intro3' + introSoundsSuffix);
		Paths.sound('intro2' + introSoundsSuffix);
		Paths.sound('intro1' + introSoundsSuffix);
		Paths.sound('introGo' + introSoundsSuffix);
	}

	public function startCountdown()
	{
		if (startedCountdown)
		{
			callOnScripts('onStartCountdown');
			return false;
		}

		seenCutscene = true;
		inCutscene = false;
		var ret:Dynamic = callOnScripts('onStartCountdown', null, true);
		if (ret != LuaUtils.Function_Stop)
		{
			if (skipCountdown || startOnTime > 0)
			{
				skipArrowStartTween = true;
			}

			canPause = true;
			generateStaticArrows(0);
			generateStaticArrows(1);

			for (i in 0...playerStrums.length)
			{
				setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}

			for (i in 0...opponentStrums.length)
			{
				setOnScripts('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				//if (ClientPrefs.data.middleScroll) opponentStrums.members[i].visible = false;
			}

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted');

			var swagCounter:Int = 0;
			if (startOnTime > 0)
			{
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return true;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return true;
			}
			moveCameraSection();

			startTimer = new FlxTimer().start(Conductor.crochet / 1000 / playbackRate, function(tmr:FlxTimer)
			{
				characterBopper(tmr.loopsLeft);

				var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
				var introImagesArray:Array<String> = switch(stageUI)
				{
					case "pixel":
					{
						['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel'];
					}

					case "normal":
					{
						["ready", "set" ,"go"];
					}
					
					default:
					{
						['${uiPrefix}UI/ready${uiPostfix}', '${uiPrefix}UI/set${uiPostfix}', '${uiPrefix}UI/go${uiPostfix}'];
					}
				}
				introAssets.set(stageUI, introImagesArray);

				var introAlts:Array<String> = introAssets.get(stageUI);
				var antialias:Bool = (ClientPrefs.data.antialiasing && !isPixelStage);
				var tick:Countdown = THREE;

				switch (swagCounter)
				{
					case 0:
					{
						FlxG.sound.play(Paths.sound('intro3' + introSoundsSuffix), 0.6);
						tick = THREE;
					}

					case 1:
					{
						countdownReady = createCountdownSprite(introAlts[0], antialias);
						FlxG.sound.play(Paths.sound('intro2' + introSoundsSuffix), 0.6);
						tick = TWO;
					}

					case 2:
					{
						countdownSet = createCountdownSprite(introAlts[1], antialias);
						FlxG.sound.play(Paths.sound('intro1' + introSoundsSuffix), 0.6);
						tick = ONE;
					}

					case 3:
					{
						countdownGo = createCountdownSprite(introAlts[2], antialias);
						FlxG.sound.play(Paths.sound('introGo' + introSoundsSuffix), 0.6);
						tick = GO;
					}

					case 4:
					{
						tick = START;
					}
				}

				if (!skipArrowStartTween)
				{
					notes.forEachAlive(function(note:Note) {
						if (ClientPrefs.data.opponentStrums || note.mustPress)
						{
							note.copyAlpha = false;
							note.alpha = note.multAlpha;
							if (ClientPrefs.data.middleScroll && !note.mustPress)
							{
								note.alpha *= 0.35;
							}
						}
					});
				}

				stagesFunc(function(stage:BaseStage) stage.countdownTick(tick, swagCounter));
				callOnLuas('onCountdownTick', [swagCounter]);
				callOnHScript('onCountdownTick', [tick, swagCounter]);

				swagCounter += 1;
			}, 5);
		}
		return true;
	}

	inline private function createCountdownSprite(image:String, antialias:Bool):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(image));
		spr.cameras = [camHUD];
		spr.scrollFactor.set();
		spr.updateHitbox();

		if (PlayState.isPixelStage)
		{
			spr.setGraphicSize(Std.int(spr.width * daPixelZoom));
		}

		spr.screenCenter();
		spr.antialiasing = antialias;
		insert(members.indexOf(noteGroup), spr);
		FlxTween.tween(spr, {/*y: spr.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				remove(spr);
				spr.destroy();
			}
		});
		return spr;
	}

	public function addBehindGF(obj:FlxBasic)
	{
		insert(members.indexOf(gfGroup), obj);
	}

	public function addBehindBF(obj:FlxBasic)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}

	public function addBehindDad(obj:FlxBasic)
	{
		insert(members.indexOf(dadGroup), obj);
	}
	
	public function addBeforeGF(obj:FlxBasic)
	{
		insert(members.indexOf(gfGroup) + 1, obj);
	}

	public function addBeforeBF(obj:FlxBasic)
	{
		insert(members.indexOf(boyfriendGroup) + 1, obj);
	}

	public function addBeforeDad(obj:FlxBasic)
	{
		insert(members.indexOf(dadGroup) + 1, obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0)
		{
			var daNote:Note = unspawnNotes[i];
			if (daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0)
		{
			var daNote:Note = notes.members[i];
			if (daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;
				invalidateNote(daNote);
			}
			--i;
		}
	}

	// fun fact: Dynamic Functions can be overriden by just doing this
	// `updateScore = function(miss:Bool = false) { ... }
	// its like if it was a variable but its just a function!
	// cool right? -Crow
	public dynamic function updateScore(miss:Bool = false, scoreBop:Bool = true)
	{
		var ret:Dynamic = callOnScripts('preUpdateScore', [miss], true);
		if (ret == LuaUtils.Function_Stop)
		{
			return;
		}

		updateScoreText();
		if (!miss && !cpuControlled && scoreBop)
		{
			doScoreBop();
		}

		callOnScripts('onUpdateScore', [miss]);
	}

	public dynamic function updateScoreText()
	{
		var str:String = Language.getPhrase('rating_$ratingName', ratingName);
		if (totalPlayed != 0)
		{
			var percent:Float = CoolUtil.floorDecimal(ratingPercent * 100, 2);
			str += ' (${percent}%) - ' + Language.getPhrase(ratingFC);
		}

		var tempScore:String;
		if (!instakillOnMiss)
		{
			tempScore = Language.getPhrase('score_text', 'Score: {1} | Misses: {2} | Rating: {3}', [songScore, songMisses, str]);
		}
		else
		{
			tempScore = Language.getPhrase('score_text_instakill', 'Score: {1} | Rating: {2}', [songScore, str]);
		}
		scoreTxt.text = tempScore;
	}

	public dynamic function fullComboFunction()
	{
		var sicks:Int = ratingsData[0].hits;
		var goods:Int = ratingsData[1].hits;
		var bads:Int = ratingsData[2].hits;
		var shits:Int = ratingsData[3].hits;

		ratingFC = "";
		if (songMisses == 0)
		{
			if (bads > 0 || shits > 0)
			{
				ratingFC = 'FC';
			}
			else if (goods > 0)
			{
				ratingFC = 'GFC';
			}
			else if (sicks > 0)
			{
				ratingFC = 'SFC';
			}
		}
		else
		{
			if (songMisses < 10)
			{
				ratingFC = 'SDCB';
			}
			else
			{
				ratingFC = 'Clear';
			}
		}
	}

	public function doScoreBop():Void
	{
		if (!ClientPrefs.data.scoreZoom)
		{
			return;
		}

		if (scoreTxtTween != null)
		{
			scoreTxtTween.cancel();
		}

		scoreTxt.scale.x = 1.075;
		scoreTxt.scale.y = 1.075;
		scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
			onComplete: function(twn:FlxTween) {
				scoreTxtTween = null;
			}
		});
	}

	public function setSongTime(time:Float)
	{
		FlxG.sound.music.pause();
		vocals.pause();
		opponentVocals.pause();

		FlxG.sound.music.time = time - Conductor.offset;
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.play();

		if (Conductor.songPosition < vocals.length)
		{
			vocals.time = time - Conductor.offset;
			#if FLX_PITCH vocals.pitch = playbackRate; #end
			vocals.play();
		}
		else
		{
			vocals.pause();
		}

		if (Conductor.songPosition < opponentVocals.length)
		{
			opponentVocals.time = time - Conductor.offset;
			#if FLX_PITCH opponentVocals.pitch = playbackRate; #end
			opponentVocals.play();
		}
		else
		{
			opponentVocals.pause();
		}
		Conductor.songPosition = time;
	}

	public function startNextDialogue()
	{
		dialogueCount++;
		callOnScripts('onNextDialogue', [dialogueCount]);
	}

	public function skipDialogue()
	{
		callOnScripts('onSkipDialogue', [dialogueCount]);
	}

	function startSong():Void
	{
		startingSong = false;

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.onComplete = finishSong.bind();
		vocals.play();
		opponentVocals.play();

		setSongTime(Math.max(0, startOnTime - 500) + Conductor.offset);
		startOnTime = 0;

		if (paused)
		{
			// trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}

		stagesFunc(function(stage:BaseStage) stage.startSong());

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		if (maxMisses)
		{
			FlxFlicker.flicker(maxMissAD, 1.5, 0.1, false, false, function(flick:FlxFlicker)
			{
				maxMissAD.destroy();
				FlxFlicker.flicker(maxMissTxt, 1.2, 0.1, false, false, function(flick:FlxFlicker)
				{
					maxMissTxt.visible = true;
				});
			});
		}

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence (with Time Left)
		if (autoUpdateRPC)
		{
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		}
		#end
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');
	}

	private var noteTypes:Array<String> = [];
	private var eventsPushed:Array<String> = [];
	private var totalColumns: Int = 4;

	private function generateSong():Void
	{
		// FlxG.log.add(ChartParser.parse());
		songSpeed = PlayState.SONG.speed;
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype');
		switch(songSpeedType)
		{
			case "multiplicative":
			{
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');
			}

			case "constant":
			{
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
			}
		}

		var songData = SONG;
		Conductor.bpm = songData.bpm;

		curSong = songData.song;

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			if (songData.needsVoices)
			{
				var playerVocals = Paths.voices(songData.song, (boyfriend.vocalsFile == null || boyfriend.vocalsFile.length < 1) ? 'Player' : boyfriend.vocalsFile);
				vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(songData.song));
				
				var oppVocals = Paths.voices(songData.song, (dad.vocalsFile == null || dad.vocalsFile.length < 1) ? 'Opponent' : dad.vocalsFile);
				if (oppVocals != null && oppVocals.length > 0)
				{
					opponentVocals.loadEmbedded(oppVocals);
				}
			}
		}
		catch (e:Dynamic) {}

		#if FLX_PITCH
		vocals.pitch = playbackRate;
		opponentVocals.pitch = playbackRate;
		#end
		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);

		inst = new FlxSound();
		try
		{
			inst.loadEmbedded(Paths.inst(songData.song));
		}
		catch (e:Dynamic) {}
		FlxG.sound.list.add(inst);

		notes = new FlxTypedGroup<Note>();
		noteGroup.add(notes);

		try
		{
			var eventsChart:SwagSong = Song.getChart('events', songName);
			if (eventsChart != null)
			{
				for (event in eventsChart.events) // Event Notes
				{
					for (i in 0...event[1].length)
					{
						makeEvent(event, i);
					}
				}
			}
		}
		catch(e:Dynamic) {}

		var oldNote:Note = null;
		var sectionsData:Array<SwagSection> = PlayState.SONG.notes;
		var ghostNotesCaught:Int = 0;
		var daBpm:Float = Conductor.bpm;
	
		for (section in sectionsData)
		{
			if (section.changeBPM != null && section.changeBPM && section.bpm != null && daBpm != section.bpm)
			{
				daBpm = section.bpm;
			}

			for (i in 0...section.sectionNotes.length)
			{
				final songNotes: Array<Dynamic> = section.sectionNotes[i];
				var spawnTime: Float = songNotes[0];
				var noteColumn: Int = Std.int(songNotes[1] % totalColumns);
				var holdLength: Float = songNotes[2];
				var noteType: String = !Std.isOfType(songNotes[3], String) ? Note.defaultNoteTypes[songNotes[3]] : songNotes[3];
				if (Math.isNaN(holdLength))
				{
					holdLength = 0.0;
				}

				var gottaHitNote:Bool = (songNotes[1] < totalColumns);

				if (i != 0)
				{
					// CLEAR ANY POSSIBLE GHOST NOTES
					for (evilNote in unspawnNotes)
					{
						var matches: Bool = (noteColumn == evilNote.noteData && gottaHitNote == evilNote.mustPress && evilNote.noteType == noteType);
						if (matches && Math.abs(spawnTime - evilNote.strumTime) < flixel.math.FlxMath.EPSILON)
						{
							if (evilNote.tail.length > 0)
							{
								for (tail in evilNote.tail)
								{
									tail.destroy();
									unspawnNotes.remove(tail);
								}
							}
							evilNote.destroy();
							unspawnNotes.remove(evilNote);
							ghostNotesCaught++;
							// continue;
						}
					}
				}

				var swagNote:Note = new Note(spawnTime, noteColumn, oldNote);
				var isAlt: Bool = section.altAnim && !gottaHitNote;
				swagNote.gfNote = (section.gfSection && gottaHitNote == section.mustHitSection);
				swagNote.animSuffix = isAlt ? "-alt" : "";
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = holdLength;
				swagNote.noteType = noteType;

				swagNote.scrollFactor.set();
				unspawnNotes.push(swagNote);

				var curStepCrochet:Float = 60 / daBpm * 1000 / 4.0;
				final roundSus:Int = Math.round(swagNote.sustainLength / curStepCrochet);
				if (roundSus > 0)
				{
					for (susNote in 0...roundSus)
					{
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = new Note(spawnTime + (curStepCrochet * susNote), noteColumn, oldNote, true);
						sustainNote.animSuffix = swagNote.animSuffix;
						sustainNote.mustPress = swagNote.mustPress;
						sustainNote.gfNote = swagNote.gfNote;
						sustainNote.playerNote = swagNote.playerNote;
						sustainNote.opponentNote = swagNote.opponentNote;
						sustainNote.gfPlayerNote = swagNote.gfPlayerNote;
						sustainNote.gfOpponentNote = swagNote.gfOpponentNote;
						sustainNote.playerOpponentNote = swagNote.playerOpponentNote;
						sustainNote.playerOpponentGFNote = swagNote.playerOpponentGFNote;
						sustainNote.noteType = swagNote.noteType;
						sustainNote.scrollFactor.set();
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);
						swagNote.tail.push(sustainNote);

						sustainNote.correctionOffset = swagNote.height / 2;
						if (!PlayState.isPixelStage)
						{
							if (oldNote.isSustainNote)
							{
								oldNote.scale.y *= Note.SUSTAIN_SIZE / oldNote.frameHeight;
								oldNote.scale.y /= playbackRate;
								oldNote.resizeByRatio(curStepCrochet / Conductor.stepCrochet);
							}

							if (ClientPrefs.data.downScroll)
							{
								sustainNote.correctionOffset = 0;
							}
						}
						else if (oldNote.isSustainNote)
						{
							oldNote.scale.y /= playbackRate;
							oldNote.resizeByRatio(curStepCrochet / Conductor.stepCrochet);
						}

						if (sustainNote.mustPress)
						{
							sustainNote.x += FlxG.width / 2; // general offset
						}
						else if (ClientPrefs.data.middleScroll)
						{
							sustainNote.x += 310;
							if (noteColumn > 1) // Up and Right
							{
								sustainNote.x += FlxG.width / 2 + 25;
							}
						}
					}
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else if (ClientPrefs.data.middleScroll)
				{
					swagNote.x += 310;
					if (noteColumn > 1) //Up and Right
					{
						swagNote.x += FlxG.width / 2 + 25;
					}
				}

				if (!noteTypes.contains(swagNote.noteType))
				{
					noteTypes.push(swagNote.noteType);
				}

				oldNote = swagNote;
			}
		}
		trace('["${SONG.song.toUpperCase()}" CHART INFO]: Ghost Notes Cleared: $ghostNotesCaught');
		for (event in songData.events) //Event Notes
		{
			for (i in 0...event[1].length)
			{
				makeEvent(event, i);
			}
		}

		unspawnNotes.sort(sortByTime);
		generatedMusic = true;
	}

	// called only once per different event (Used for precaching)
	function eventPushed(event:EventNote)
	{
		eventPushedUnique(event);
		if (eventsPushed.contains(event.event))
		{
			return;
		}

		stagesFunc(function(stage:BaseStage) stage.eventPushed(event));
		eventsPushed.push(event.event);
	}

	// called by every event with the same name
	function eventPushedUnique(event:EventNote)
	{
		switch(event.event)
		{
			case "Change Character":
			{
				var charType:Int = 0;
				switch(event.value1.toLowerCase())
				{
					case 'gf' | 'girlfriend':
					{
						charType = 2;
					}

					case 'dad' | 'opponent':
					{
						charType = 1;
					}

					case 'bf' | 'boyfriend' | 'player':
					{
						charType = 0;
					}

					default:
					{
						var val1:Int = Std.parseInt(event.value1);
						if (Math.isNaN(val1))
						{
							val1 = 0;
						}
						charType = val1;
					}
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);
			}

			case 'Play Sound':
			{
				Paths.sound(event.value1); // Precache sound
			}
		}
		stagesFunc(function(stage:BaseStage) stage.eventPushedUnique(event));
	}

	function eventEarlyTrigger(event:EventNote):Float
	{
		var returnedValue:Null<Float> = callOnScripts('eventEarlyTrigger', [event.event, event.value1, event.value2, event.value3, event.value4, event.value5, event.strumTime], true);
		if (returnedValue != null && returnedValue != 0)
		{
			return returnedValue;
		}

		switch(event.event)
		{
			case 'Kill Henchmen': // Better timing so that the kill sound matches the beat intended
			{
				return 280; // Plays 280ms before the actual position
			}
		}
		return 0;
	}

	public static function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);
	}

	function makeEvent(event:Array<Dynamic>, i:Int)
	{
		var subEvent:EventNote = {
			strumTime: event[0] + ClientPrefs.data.noteOffset,
			event: event[1][i][0],
			value1: event[1][i][1],
			value2: event[1][i][2],
			value3: event[1][i][1],
			value4: event[1][i][1],
			value5: event[1][i][1]
		};
		eventNotes.push(subEvent);
		eventPushed(subEvent);
		callOnScripts('onEventPushed', [subEvent.event, subEvent.value1 != null ? subEvent.value1 : '', subEvent.value2 != null ? subEvent.value2 : '', subEvent.value3 != null ? subEvent.value3 : '', subEvent.value4 != null ? subEvent.value4 : '', subEvent.value5 != null ? subEvent.value5 : '', subEvent.strumTime]);
	}

	public var skipArrowStartTween:Bool = false; // for lua
	private function generateStaticArrows(player:Int):Void
	{
		var strumLineX:Float = ClientPrefs.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
		var strumLineY:Float = ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50;
		for (i in 0...4)
		{
			// FlxG.log.add(i);
			var targetAlpha:Float = 1;
			if (player < 1)
			{
				if (!ClientPrefs.data.opponentStrums)
				{
					targetAlpha = 0;
				}
				else if (ClientPrefs.data.middleScroll)
				{
					targetAlpha = 0.35;
				}
			}

			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = ClientPrefs.data.downScroll;
			if (!isStoryMode && !skipArrowStartTween)
			{
				// babyArrow.y -= 10;
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {/*y: babyArrow.y + 10,*/ alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
			else babyArrow.alpha = targetAlpha;

			if (player == 1)
			{
				playerStrums.add(babyArrow);
			}
			else
			{
				if (ClientPrefs.data.middleScroll)
				{
					babyArrow.x += 310;
					if (i > 1) // Up and Right
					{
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.playerPosition();
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		stagesFunc(function(stage:BaseStage) stage.openSubState(SubState));
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
				opponentVocals.pause();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if (!tmr.finished) tmr.active = false);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if (!twn.finished) twn.active = false);
		}

		super.openSubState(SubState);
	}

	public var canResync:Bool = true;
	override function closeSubState()
	{
		super.closeSubState();
		
		stagesFunc(function(stage:BaseStage) stage.closeSubState());
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong && canResync)
			{
				resyncVocals();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if (!tmr.finished) tmr.active = true);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if (!twn.finished) twn.active = true);

			paused = false;
			callOnScripts('onResume');
			resetRPC(startTimer != null && startTimer.finished);
		}
	}

	#if DISCORD_ALLOWED
	override public function onFocus():Void
	{
		super.onFocus();
		if (!paused && health > 0)
		{
			resetRPC(Conductor.songPosition > 0.0);
		}
	}

	override public function onFocusLost():Void
	{
		super.onFocusLost();
		if (!paused && health > 0 && autoUpdateRPC)
		{
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		}
	}
	#end

	// Updating Discord Rich Presence.
	public var autoUpdateRPC:Bool = true; //performance setting for custom RPC things
	function resetRPC(?showTime:Bool = false)
	{
		#if DISCORD_ALLOWED
		if (!autoUpdateRPC)
		{
			return;
		}

		if (showTime)
		{
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.data.noteOffset);
		}
		else
		{
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		}
		#end
	}

	function resyncVocals():Void
	{
		if (finishTimer != null)
		{
			return;
		}

		trace('resynced vocals at ' + Math.floor(Conductor.songPosition));

		FlxG.sound.music.play();
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		var checkVocals = [vocals, opponentVocals];
		for (voc in checkVocals)
		{
			if (FlxG.sound.music.time < vocals.length)
			{
				voc.time = FlxG.sound.music.time;
				#if FLX_PITCH voc.pitch = playbackRate; #end
				voc.play();
			}
			else
			{
				voc.pause();
			}
		}
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	public var canBotplay:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var freezeCamera:Bool = false;
	var allowDebugKeys:Bool = true;

	override public function update(elapsed:Float)
	{
		#if VS_SONIC_EXE_FILES
		if (ringSystem)
		{
			counterNum.text = Std.string(cNum);
		}
		#end
		if (maxSongMisses == 0 && maxMisses) health = 0;

		#if BALDIS_BASICS_IN_FUNKIN_FILES
		if (screenShake)
		{
			FlxG.camera.shake(0.005, 0.10);
		}
		#end

		if (!inCutscene && !paused && !freezeCamera)
		{
			FlxG.camera.followLerp = 0.04 * cameraSpeed * playbackRate;
			var idleAnim:Bool = (boyfriend.getAnimationName().startsWith('idle') || boyfriend.getAnimationName().startsWith('danceLeft') || boyfriend.getAnimationName().startsWith('danceRight'));
			if (!startingSong && !endingSong && idleAnim)
			{
				boyfriendIdleTime += elapsed;
				if (boyfriendIdleTime >= 0.15) // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
				{
					boyfriendIdled = true;
				}
			}
			else
			{
				boyfriendIdleTime = 0;
			}
		}
		else
		{
			FlxG.camera.followLerp = 0;
		}
		callOnScripts('onUpdate', [elapsed]);

		super.update(elapsed);

		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);

		if (maxMisses)
		{
			maxMissTxt.text = 'MAX MISSES: ' + maxSongMisses;
			maxMissAD.text = 'MAX MISSES: ' + maxSongMisses;
		}
		else
		{
			maxMissTxt.text = 'MAX MISSES: ' + maxSongMisses;
			maxMissAD.text = 'MAX MISSES: ' + maxSongMisses;
		}

		if (cpuControlled && botplayTxt != null && botplayTxt.visible)
		{
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (controls.PAUSE && startedCountdown && canPause)
		{
			var ret:Dynamic = callOnScripts('onPause', null, true);
			if (ret != LuaUtils.Function_Stop)
			{
				openPauseMenu();
			}
		}

		if (!endingSong && !inCutscene && allowDebugKeys)
		{
			if (controls.justPressed('debug_1'))
			{
				openChartEditor();
			}
			else if (controls.justPressed('debug_2'))
			{
				openCharacterEditor();
			}
		}

		if (healthBar.bounds.max != null && health > healthBar.bounds.max)
		{
			health = healthBar.bounds.max;
		}

		updateIconsScale(elapsed);
		updateIconsPosition();

		if (startedCountdown && !paused)
		{
			Conductor.songPosition += elapsed * 1000 * playbackRate;
			if (Conductor.songPosition >= Conductor.offset)
			{
				Conductor.songPosition = FlxMath.lerp(FlxG.sound.music.time + Conductor.offset, Conductor.songPosition, Math.exp(-elapsed * 5));
				var timeDiff:Float = Math.abs((FlxG.sound.music.time + Conductor.offset) - Conductor.songPosition);
				if (timeDiff > 1000 * playbackRate)
				{
					Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);
				}
			}
		}

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= Conductor.offset)
			{
				startSong();
			}
			else if (!startedCountdown)
			{
				Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
			}
		}
		else if (!paused && updateTime)
		{
			var curTime:Float = Math.max(0, Conductor.songPosition - ClientPrefs.data.noteOffset);
			songPercent = (curTime / songLength);

			var songCalc:Float = (songLength - curTime);
			if (ClientPrefs.data.timeBarType == 'Time Elapsed') songCalc = curTime;

			var secondsTotal:Int = Math.floor(songCalc / 1000);
			if (secondsTotal < 0) secondsTotal = 0;

			if (ClientPrefs.data.timeBarType != 'Song Name' && ClientPrefs.data.timeBarType != 'No Text')
			{
				if (ClientPrefs.data.timeBarType == 'Elapsed / Left')
				{
					timeTxt.text = '${FlxStringUtil.formatTime(Math.floor(curTime / 1000), false)} / ${FlxStringUtil.formatTime(Math.floor((songLength - curTime) / 1000), false)}';
				}
				else if (ClientPrefs.data.timeBarType == 'Elapsed / Duration / Left')
				{
					timeTxt.text = '${FlxStringUtil.formatTime(Math.floor(curTime / 1000), false)} / ${FlxStringUtil.formatTime(Math.floor(songLength / 1000), false)} / ${FlxStringUtil.formatTime(Math.floor((songLength - curTime) / 1000), false)}';
				}
				else if (ClientPrefs.data.timeBarType == 'Time Duration')
				{
					timeTxt.text = FlxStringUtil.formatTime(Math.floor(songLength / 1000), false);
				}
				else if (ClientPrefs.data.timeBarType == 'Duration / Left')
				{
					timeTxt.text = '${FlxStringUtil.formatTime(Math.floor(songLength / 1000), false)} / ${FlxStringUtil.formatTime(Math.floor((songLength - curTime) / 1000), false)}';
				}
				else if (ClientPrefs.data.timeBarType == 'Elapsed / Duration')
				{
					timeTxt.text = '${FlxStringUtil.formatTime(Math.floor(curTime / 1000), false)} / ${FlxStringUtil.formatTime(Math.floor(songLength / 1000), false)}';
				}
				else
				{
					timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
				}
			}
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
		}

		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.data.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
		{
			health = 0;
			trace("RESET = True");
		}
		doDeathCheck();

		// BOTPLAY = Quick Botplay Toggle
		if (!ClientPrefs.data.noBotplay && controls.BOTPLAY && canBotplay && !inCutscene && startedCountdown && !endingSong)
		{
			if (cpuControlled == true)
			{
				cpuControlled = false;
				botplayTxt.visible = false;
				trace("BOTPLAY = False");
			}
			else if (cpuControlled == false)
			{
				cpuControlled = true;
				botplayTxt.visible = true;
				botplaySine = 180;
				trace("BOTPLAY = True");
			}
		}

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime * playbackRate;
			if (songSpeed < 1) time /= songSpeed;
			if (unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote, dunceNote.strumTime]);
				callOnHScript('onSpawnNote', [dunceNote]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			if (!inCutscene)
			{
				if (!cpuControlled)
				{
					keysCheck();
				}
				else
				{
					playerDance();
				}

				if (notes.length > 0)
				{
					if (startedCountdown)
					{
						var fakeCrochet:Float = (60 / SONG.bpm) * 1000;
						var i:Int = 0;
						while(i < notes.length)
						{
							var daNote:Note = notes.members[i];
							if (daNote == null) continue;

							var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
							if (!daNote.mustPress) strumGroup = opponentStrums;

							var strum:StrumNote = strumGroup.members[daNote.noteData];
							daNote.followStrumNote(strum, fakeCrochet, songSpeed / playbackRate);

							if (daNote.mustPress)
							{
								if (cpuControlled && !daNote.blockHit && daNote.canBeHit && (daNote.isSustainNote || daNote.strumTime <= Conductor.songPosition))
								{
									goodNoteHit(daNote);
								}
							}
							else if (daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
							{
								opponentNoteHit(daNote);
							}

							if (daNote.isSustainNote && strum.sustainReduce) daNote.clipToStrumNote(strum);

							// Kill extremely late notes and cause misses
							if (Conductor.songPosition - daNote.strumTime > noteKillOffset)
							{
								if (daNote.mustPress && !cpuControlled && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
								{
									noteMiss(daNote);
								}

								daNote.active = daNote.visible = false;
								invalidateNote(daNote);
							}

							if (daNote.exists) i++;
						}
					}
					else
					{
						notes.forEachAlive(function(daNote:Note)
						{
							daNote.canBeHit = false;
							daNote.wasGoodHit = false;
						});
					}
				}
			}
			checkEventNote();
		}

		#if debug
		if (!endingSong && !startingSong)
		{
		
			if (FlxG.keys.justPressed.ONE)
			{
				KillNotes();
				FlxG.sound.music.onComplete();
			}

			if (FlxG.keys.justPressed.TWO) //Go 10 seconds into the future :O
			{
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end

		#if BASE_GAME_FILES
		// Press NINE to force the player icon to 'bf-old' when the current player character
		// is listed in `allowedP1Characters`. Use `PlayState.addAllowedPlayerCharacter(name)`
		// to add characters one-by-one (from mods/scripts).
		if (!endingSong && !startingSong)
		{
			// Reset bf-old toggle if the current boyfriend character changed mid-song
			if (boyfriend != null && boyfriend.curCharacter != null)
			{
				if (bfOldLastCharacter == null) bfOldLastCharacter = boyfriend.curCharacter;
				else if (bfOldLastCharacter != boyfriend.curCharacter)
				{
					if (bfOldToggled)
					{
						// restore by reading the current character JSON (same logic as restore on second NINE press)
						var origJson:Dynamic = null;
						try
						{
							var charPathR:String = 'characters/' + boyfriend.curCharacter + '.json';
							var pR:String = Paths.getPath(charPathR, TEXT);
							#if MODS_ALLOWED
							if (FileSystem.exists(pR)) origJson = haxe.Json.parse(File.getContent(pR));
							#else
							if (Assets.exists(pR)) origJson = haxe.Json.parse(Assets.getText(pR));
							#end
						}
						catch(e:Dynamic) { origJson = null; }

						if (origJson != null)
						{
							var origIconR:String = (origJson.healthicon != null && origJson.healthicon.length > 0) ? origJson.healthicon : boyfriend.healthIcon;
							if (origIconR != null && iconP1 != null) iconP1.changeIcon(origIconR);
							if (origJson.healthbar_colors != null && origJson.healthbar_colors.length > 2)
							{
								boyfriend.healthColorArray = [origJson.healthbar_colors[0], origJson.healthbar_colors[1], origJson.healthbar_colors[2]];
							}
						}
						else
						{
							if (iconP1 != null) iconP1.changeIcon(boyfriend.healthIcon);
						}
						bfOldToggled = false;
						reloadHealthBarColors();
					}
					bfOldLastCharacter = boyfriend.curCharacter;
				}
			}
			if (FlxG.keys.justPressed.NINE)
			{
				if (boyfriend != null && boyfriend.curCharacter != null)
				{
					var cur:String = boyfriend.curCharacter.toLowerCase();
					if (allowedP1Characters.indexOf(cur) != -1)
					{
						var usePixel:Bool = false;
						if (boyfriend.imageFile != null) usePixel = boyfriend.imageFile.toLowerCase().indexOf('pixel') != -1;
						else usePixel = cur.indexOf('pixel') != -1 || cur == 'bf-pixel-opponent';
						var iconName:String = usePixel ? 'bf-old-pixel' : 'bf-old';
						if (!bfOldToggled)
						{
							// determine whether the icon was showing the losing/death frame
							var wasDeath:Bool = false;
							if (iconP1 != null && iconP1.animation.curAnim != null) wasDeath = (iconP1.animation.curAnim.curFrame == 1);
							else if (healthBar != null) wasDeath = (healthBar.percent < 20);
							// apply new icon and color (don't store originals — they'll be read from the current character JSON on restore)
							if (iconP1 != null) iconP1.changeIcon(iconName);
							// if the previous icon was the death frame, force the new icon to death frame immediately
							if (wasDeath && iconP1 != null && iconP1.animation.curAnim != null) iconP1.animation.curAnim.curFrame = 1;
							if (usePixel)
							{
								boyfriend.healthColorArray = [255, 249, 99];
							}
							else
							{
								boyfriend.healthColorArray = [233, 255, 72];
							}
							bfOldToggled = true;
							reloadHealthBarColors();
						}
						else
						{
							// restore previous icon and color by reading the current character's JSON
							var origJson:Dynamic = null;
							try
							{
								var charPath:String = 'characters/' + boyfriend.curCharacter + '.json';
								var p:String = Paths.getPath(charPath, TEXT);
								#if MODS_ALLOWED
								if (FileSystem.exists(p)) origJson = haxe.Json.parse(File.getContent(p));
								#else
								if (Assets.exists(p)) origJson = haxe.Json.parse(Assets.getText(p));
								#end
							}
							catch(e:Dynamic) { origJson = null; }

							if (origJson != null)
							{
								var origIcon:String = (origJson.healthicon != null && origJson.healthicon.length > 0) ? origJson.healthicon : boyfriend.healthIcon;
								if (origIcon != null && iconP1 != null) iconP1.changeIcon(origIcon);
								// If health is low, force the restored icon to the death frame immediately
								if (healthBar != null && healthBar.percent < 20 && iconP1 != null && iconP1.animation.curAnim != null) iconP1.animation.curAnim.curFrame = 1;
								if (origJson.healthbar_colors != null && origJson.healthbar_colors.length > 2)
								{
									boyfriend.healthColorArray = [origJson.healthbar_colors[0], origJson.healthbar_colors[1], origJson.healthbar_colors[2]];
								}
							}
							else
							{
								// fallback: restore to the Character object's current properties
								if (iconP1 != null) iconP1.changeIcon(boyfriend.healthIcon);
								if (healthBar != null && healthBar.percent < 20 && iconP1 != null && iconP1.animation.curAnim != null) iconP1.animation.curAnim.curFrame = 1;
								// boyfriend.healthColorArray is already a best-effort fallback
							}
							bfOldToggled = false;
							reloadHealthBarColors();
						}
					}
				}
			}
		}
		#end

		setOnScripts('botPlay', cpuControlled);
		callOnScripts('onUpdatePost', [elapsed]);
	}

	// Health icon updaters
	public dynamic function updateIconsScale(elapsed:Float)
	{
		var mult:Float = FlxMath.lerp(1, iconP1.scale.x, Math.exp(-elapsed * 9 * playbackRate));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(1, iconP2.scale.x, Math.exp(-elapsed * 9 * playbackRate));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();
	}

	public dynamic function updateIconsPosition()
	{
		var iconOffset:Int = 26;
		iconP1.x = healthBar.barCenter + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = healthBar.barCenter - (150 * iconP2.scale.x) / 2 - iconOffset * 2;
	}

	var iconsAnimations:Bool = true;
	function set_health(value:Float):Float // You can alter how icon animations work here
	{
		value = FlxMath.roundDecimal(value, 5); //Fix Float imprecision
		if (!iconsAnimations || healthBar == null || !healthBar.enabled || healthBar.valueFunction == null)
		{
			health = value;
			return health;
		}

		// update health bar
		health = value;
		var newPercent:Null<Float> = FlxMath.remapToRange(FlxMath.bound(healthBar.valueFunction(), healthBar.bounds.min, healthBar.bounds.max), healthBar.bounds.min, healthBar.bounds.max, 0, 100);
		healthBar.percent = (newPercent != null ? newPercent : 0);

		iconP1.animation.curAnim.curFrame = (healthBar.percent < 20) ? 1 : 0; //If health is under 20%, change player icon to frame 1 (losing icon), otherwise, frame 0 (normal)
		iconP2.animation.curAnim.curFrame = (healthBar.percent > 80) ? 1 : 0; //If health is over 80%, change opponent icon to frame 1 (losing icon), otherwise, frame 0 (normal)
		return health;
	}

	function openPauseMenu()
	{
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;

		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}

		if (!cpuControlled)
		{
			for (note in playerStrums)
			{
				if (note.animation.curAnim != null && note.animation.curAnim.name != 'static')
				{
					note.playAnim('static');
					note.resetAnim = 0;
				}
			}
		}
		openSubState(new PauseSubState());

		#if DISCORD_ALLOWED
		if (autoUpdateRPC) DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	function openChartEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		chartingMode = true;
		paused = true;

		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
		}

		if (vocals != null)
		{
			vocals.pause();
		}

		if (opponentVocals != null)
		{
			opponentVocals.pause();
		}

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", null, null, true);
		DiscordClient.resetClientID();
		#end

		MusicBeatState.switchState(new ChartingState());
	}

	function openCharacterEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		paused = true;

		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
		}

		if (vocals != null)
		{
			vocals.pause();
		}

		if (opponentVocals != null)
		{
			opponentVocals.pause();
		}

		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
	}

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	public var gameOverTimer:FlxTimer;
	function doDeathCheck(?skipHealthCheck:Bool = false)
	{
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead && gameOverTimer == null)
		{
			var ret:Dynamic = callOnScripts('onGameOver', null, true);
			if (ret != LuaUtils.Function_Stop)
			{
				FlxG.animationTimeScale = 1;
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;
				canResync = false;
				canPause = false;
				#if VIDEOS_ALLOWED
				if (videoCutscene != null)
				{
					videoCutscene.destroy();
					videoCutscene = null;
				}
				#end

				persistentUpdate = false;
				persistentDraw = false;
				FlxTimer.globalManager.clear();
				FlxTween.globalManager.clear();
				FlxG.camera.setFilters([]);

				if (GameOverSubstate.deathDelay > 0)
				{
					gameOverTimer = new FlxTimer().start(GameOverSubstate.deathDelay, function(_)
					{
						vocals.stop();
						opponentVocals.stop();
						FlxG.sound.music.stop();
						openSubState(new GameOverSubstate(boyfriend));
						gameOverTimer = null;
					});
				}
				else
				{
					vocals.stop();
					opponentVocals.stop();
					FlxG.sound.music.stop();
					openSubState(new GameOverSubstate(boyfriend));
				}

				// MusicBeatState.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

				#if DISCORD_ALLOWED
				// Game Over doesn't get his its variable because it's only used here
				if (autoUpdateRPC)
				{
					var deathIconKey:String = iconP1.getCharacter() + "-dead";
					/*if (!Paths.fileExists('images/icons/' + deathIconKey + '.png', IMAGE))
					{
						deathIconKey = 'face-dead';
					}*/
					DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", deathIconKey);
				}
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote()
	{
		while(eventNotes.length > 0)
		{
			var leStrumTime:Float = eventNotes[0].strumTime;
			if (Conductor.songPosition < leStrumTime)
			{
				return;
			}

			var value1:String = '';
			if (eventNotes[0].value1 != null)
			{
				value1 = eventNotes[0].value1;
			}

			var value2:String = '';
			if (eventNotes[0].value2 != null)
			{
				value2 = eventNotes[0].value2;
			}

			var value3:String = '';
			if (eventNotes[0].value3 != null)
			{
				value3 = eventNotes[0].value3;
			}

			var value4:String = '';
			if (eventNotes[0].value4 != null)
			{
				value4 = eventNotes[0].value4;
			}

			var value5:String = '';
			if (eventNotes[0].value5 != null)
			{
				value5 = eventNotes[0].value5;
			}

			triggerEvent(eventNotes[0].event, value1, value2, value3, value4, value5, leStrumTime);
			eventNotes.shift();
		}
	}

	public function triggerEvent(eventName:String, value1:String, value2:String, value3:String, value4:String, value5:String, strumTime:Float)
	{
		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);
		var flValue3:Null<Float> = Std.parseFloat(value3);
		var flValue4:Null<Float> = Std.parseFloat(value4);
		var flValue5:Null<Float> = Std.parseFloat(value5);
		if (Math.isNaN(flValue1)) flValue1 = null;
		if (Math.isNaN(flValue2)) flValue2 = null;
		if (Math.isNaN(flValue3)) flValue3 = null;
		if (Math.isNaN(flValue4)) flValue4 = null;
		if (Math.isNaN(flValue5)) flValue5 = null;

		switch(eventName)
		{
			case 'Hey!':
			{
				var value:Int = 3;
				switch(value1.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend' | 'player' | '0':
					{
						value = 0;
					}

					case 'gf' | 'girlfriend' | '1':
					{
						value = 1;
					}

					case 'dad' | 'opponent' | '2':
					{
						value = 2;
					}
				}

				if (flValue2 == null || flValue2 <= 0)
				{
					flValue2 = 0.6;
				}

				if (value != 0 && value != 2)
				{
					if (dad.curCharacter.startsWith('gf')) //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
					{
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = flValue2;
					}
					else if (gf != null)
					{
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = flValue2;
					}
				}

				if (value != 1 && value != 2)
				{
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = flValue2;
				}

				if (value != 0 && value != 1)
				{
					dad.playAnim('hey', true);
					dad.specialAnim = true;
					dad.heyTimer = flValue2;
				}
			}

			case 'Set GF Speed':
			{
				if (flValue1 == null || flValue1 < 1)
				{
					flValue1 = 1;
				}
				gfSpeed = Math.round(flValue1);
			}

			case 'Add Camera Zoom':
			{
				if (ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35)
				{
					if (flValue1 == null) flValue1 = 0.015;
					if (flValue2 == null) flValue2 = 0.03;

					FlxG.camera.zoom += flValue1;
					camHUD.zoom += flValue2;
				}
			}

			case 'Play Animation':
			{
				// trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch(value2.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend' | 'player':
					{
						char = boyfriend;
					}

					case 'gf' | 'girlfriend':
					{
						char = gf;
					}

					case 'dad' | 'opponent':
					{
						char = dad;
					}

					default:
					{
						if (flValue2 == null)
						{
							flValue2 = 0;
						}

						switch(Math.round(flValue2))
						{
							case 1:
							{
								char = boyfriend;
							}

							case 2:
							{
								char = gf;
							}

							case 3:
							{
								char = dad;
							}
						}
					}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}
			}

			case 'Camera Follow Pos':
			{
				if (camFollow != null)
				{
					isCameraOnForcedPos = false;
					if (flValue1 != null || flValue2 != null)
					{
						isCameraOnForcedPos = true;
						if (flValue1 == null) flValue1 = 0;
						if (flValue2 == null) flValue2 = 0;
						camFollow.x = flValue1;
						camFollow.y = flValue2;
					}
				}
			}

			case 'Alt Idle Animation':
			{
				var char:Character = dad;
				switch(value1.toLowerCase().trim())
				{
					case 'boyfriend' | 'bf' | 'player':
					{
						char = boyfriend;
					}

					case 'gf' | 'girlfriend':
					{
						char = gf;
					}

					case 'dad' | 'opponent':
					{
						char = dad;
					}

					default:
					{
						var val:Int = Std.parseInt(value1);
						if (Math.isNaN(val))
						{
							val = 0;
						}

						switch(val)
						{
							case 1:
							{
								char = boyfriend;
							}

							case 2:
							{
								char = gf;
							}

							case 3:
							{
								char = dad;
							}
						}
					}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}
			}

			case 'Screen Shake':
			{
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length)
				{
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if (split[0] != null) duration = Std.parseFloat(split[0].trim());
					if (split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if (Math.isNaN(duration)) duration = 0;
					if (Math.isNaN(intensity)) intensity = 0;

					if (duration > 0 && intensity != 0)
					{
						targetsArray[i].shake(intensity, duration);
					}
				}
			}

			case 'Camera Flash':
			{
				var valuesArray:Array<String> = [value1, value2];
				var split:Array<String> = valuesArray[0].split(',');
				var flashTime:Float = 0;
				if (split.length == 0 || split[0] == null || split[0].trim().length == 0)
				{
					flashTime = 0.5;
				}
				else
				{
					flashTime = Std.parseFloat(split[0].trim());
				}

				var flashColor:Int = FlxColor.WHITE;
				// Try to find a 6-digit hex color in split[1] first, then in value2
				var hexCandidate:String = null;
				if (split.length > 1 && split[1] != null && split[1].trim().length > 0)
				{
					hexCandidate = split[1].trim();
				}

				if (hexCandidate == null || hexCandidate.length == 0)
				{
					if (value2 != null && value2.trim().length > 0) hexCandidate = value2.trim();
				}

				if (hexCandidate != null)
				{
					if (hexCandidate.charAt(0) == '#') hexCandidate = hexCandidate.substr(1);
					var HEX_RE:EReg = ~/^[A-Fa-f0-9]{6}$/;
					if (HEX_RE.match(hexCandidate))
					{
						var r:Int = 255;
						var g:Int = 255;
						var b:Int = 255;
						var parsedR:Null<Int> = Std.parseInt('0x' + hexCandidate.substr(0, 2));
						var parsedG:Null<Int> = Std.parseInt('0x' + hexCandidate.substr(2, 2));
						var parsedB:Null<Int> = Std.parseInt('0x' + hexCandidate.substr(4, 2));
						if (parsedR != null) r = parsedR;
						if (parsedG != null) g = parsedG;
						if (parsedB != null) b = parsedB;
						flashColor = FlxColor.fromRGB(r, g, b);
					}
				}
				FlxG.camera.flash(flashColor, flashTime);
			}
			
			case 'Arrow Spin':
			{
				var arrowSpinDirection:String = value1;
				var arrowSpinNumber:Float = 0;

				if (arrowSpinDirection == 'right')
				{
					arrowSpinNumber = 360;
				}
				else if (arrowSpinDirection == 'left')
				{
					arrowSpinNumber = -360;
				}
				else
				{
					arrowSpinDirection = null;
				}

				if (arrowSpinDirection != null)
				{
					arrowSpinDirection = 'right';
				}

				//I stole this part from VS Sonic.exe 2.0's source code LOL
				strumLineNotes.forEach(function(tospin:FlxSprite)
				{
					FlxTween.angle(tospin, 0, arrowSpinNumber, 0.35, {ease: FlxEase.quintOut});
				});
			}

			case 'Change Character':
			{
				var charType:Int = 0;
				switch(value1.toLowerCase().trim())
				{
					case 'boyfriend' | 'bf' | 'player':
					{
						charType = 0;
					}

					case 'gf' | 'girlfriend':
					{
						charType = 2;
					}

					case 'dad' | 'opponent':
					{
						charType = 1;
					}

					default:
					{
						charType = Std.parseInt(value1);
						if (Math.isNaN(charType))
						{
							charType = 0;
						}
					}
				}

				switch(charType)
				{
					case 0:
					{
						if (boyfriend.curCharacter != value2)
						{
							if (!boyfriendMap.exists(value2))
							{
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = 0.00001;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						setOnScripts('boyfriendName', boyfriend.curCharacter);
					}

					case 1:
					{
						if (dad.curCharacter != value2)
						{
							if (!dadMap.exists(value2))
							{
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf-') || dad.curCharacter == 'gf';
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if (!dad.curCharacter.startsWith('gf-') && dad.curCharacter != 'gf')
							{
								if (wasGf && gf != null)
								{
									gf.visible = true;
								}
							}
							else if (gf != null)
							{
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
						}
						setOnScripts('dadName', dad.curCharacter);
					}

					case 2:
					{
						if (gf != null)
						{
							if (gf.curCharacter != value2)
							{
								if (!gfMap.exists(value2))
								{
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							setOnScripts('gfName', gf.curCharacter);
						}
					}
				}
				reloadHealthBarColors();
			}

			case 'Change Scroll Speed':
			{
				if (songSpeedType != "constant")
				{
					if (flValue1 == null) flValue1 = 1;
					if (flValue2 == null) flValue2 = 0;

					var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;
					if (flValue2 <= 0)
					{
						songSpeed = newValue;
					}
					else
					{
						songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, flValue2 / playbackRate,
						{
							ease: FlxEase.linear, onComplete:
							function (twn:FlxTween)
							{
								songSpeedTween = null;
							}
						});
					}
				}
			}

			case 'Set Property':
			{
				try
				{
					var trueValue:Dynamic = value2.trim();
					if (trueValue == 'true' || trueValue == 'false') trueValue = trueValue == 'true';
					else if (flValue2 != null) trueValue = flValue2;
					else trueValue = value2;

					var split:Array<String> = value1.split('.');
					if (split.length > 1)
					{
						LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1], trueValue);
					}
					else
					{
						LuaUtils.setVarInArray(this, value1, trueValue);
					}
				}
				catch(e:Dynamic)
				{
					var len:Int = e.message.indexOf('\n') + 1;
					if (len <= 0) len = e.message.length;
					#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
					addTextToDebug('ERROR ("Set Property" Event) - ' + e.message.substr(0, len), FlxColor.RED);
					#else
					FlxG.log.warn('ERROR ("Set Property" Event) - ' + e.message.substr(0, len));
					#end
				}
			}

			case 'Play Sound':
			{
				if (flValue2 == null) flValue2 = 1;
				FlxG.sound.play(Paths.sound(value1), flValue2);
			}
		}

		stagesFunc(function(stage:BaseStage) stage.eventCalled(eventName, value1, value2, value3, value4, value5, flValue1, flValue2, flValue3, flValue4, flValue5, strumTime));
		callOnScripts('onEvent', [eventName, value1, value2, value3, value4, value5, strumTime]);
	}

	public function moveCameraSection(?sec:Null<Int>):Void
	{
		if (sec == null) sec = curSection;
		if (sec < 0) sec = 0;

		if (SONG.notes[sec] == null) return;

		if (gf != null && SONG.notes[sec].gfSection)
		{
			moveCameraToGirlfriend();
			callOnScripts('onMoveCamera', ['gf']);
			return;
		}

		var isDad:Bool = (SONG.notes[sec].mustHitSection != true);
		moveCamera(isDad);
		if (isDad)
		{
			callOnScripts('onMoveCamera', ['dad']);
		}
		else
		{
			callOnScripts('onMoveCamera', ['boyfriend']);
		}
	}
	
	public function moveCameraToGirlfriend()
	{
		camFollow.setPosition(gf.getMidpoint().x, gf.getMidpoint().y);
		camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
		camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
		tweenCamIn();
	}

	var cameraTwn:FlxTween;
	public function moveCamera(isDad:Bool)
	{
		if (isDad)
		{
			if (dad == null) return;
			camFollow.setPosition(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
			camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
			tweenCamIn();
		}
		else
		{
			if (boyfriend == null) return;
			camFollow.setPosition(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

			if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
			{
				cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000),
				{
					ease: FlxEase.elasticInOut, onComplete:
					function (twn:FlxTween)
					{
						cameraTwn = null;
					}
				});
			}
		}
	}

	public function tweenCamIn()
	{
		if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3)
		{
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000),
			{
				ease: FlxEase.elasticInOut, onComplete:
				function (twn:FlxTween)
				{
					cameraTwn = null;
				}
			});
		}
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		updateTime = false;
		FlxG.sound.music.volume = 0;

		vocals.volume = 0;
		vocals.pause();
		opponentVocals.volume = 0;
		opponentVocals.pause();

		if (ClientPrefs.data.noteOffset <= 0 || ignoreNoteOffset)
		{
			endCallback();
		}
		else
		{
			finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset / 1000, function(tmr:FlxTimer)
			{
				endCallback();
			});
		}
	}


	public var transitioning = false;
	public function endSong()
	{
		//Should kill you if you tried to cheat
		if (!startingSong)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset)
				{
					health -= 0.05 * healthLoss;
				}
			});

			for (daNote in unspawnNotes)
			{
				if (daNote != null && daNote.strumTime < songLength - Conductor.safeZoneOffset)
				{
					health -= 0.05 * healthLoss;
				}
			}

			if (doDeathCheck())
			{
				return false;
			}
		}

		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		var weekNoMiss:String = WeekData.getWeekFileName() + '_nomiss';
		checkForAchievement([weekNoMiss, 'ur_bad', 'ur_good', 'hype', 'two_keys', 'toastie' #if BASE_GAME_FILES, 'debugger' #end]);
		#end

		var ret:Dynamic = callOnScripts('onEndSong', null, true);
		if (ret != LuaUtils.Function_Stop && !transitioning)
		{
			#if !switch
			var percent:Float = ratingPercent;
			if (Math.isNaN(percent)) percent = 0;
			Highscore.saveScore(Song.loadedSongName, songScore, storyDifficulty, percent);
			#end
			playbackRate = 1;

			if (chartingMode)
			{
				openChartEditor();
				return false;
			}

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					Mods.loadTopMod();
					FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
					#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

					canResync = false;
					MusicBeatState.switchState(new StoryMenuState());

					// if ()
					if (!ClientPrefs.getGameplaySetting('practice') && !ClientPrefs.getGameplaySetting('botplay'))
					{
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);
						Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = Difficulty.getFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					prevCamFollow = camFollow;

					Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);
					FlxG.sound.music.stop();

					canResync = false;
					LoadingState.prepareToSong();
					LoadingState.loadAndSwitchState(new PlayState(), false, false);
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				Mods.loadTopMod();
				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

				canResync = false;
				MusicBeatState.switchState(new FreeplayState());
				FlxG.sound.playMusic(Paths.music('freeplayRandom'), 0.7);
				changedDifficulty = false;
			}
			transitioning = true;
		}
		return true;
	}

	public function KillNotes()
	{
		while(notes.length > 0)
		{
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;
			invalidateNote(daNote);
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;

	public var showCombo:Bool = false;
	public var showComboNum:Bool = true;
	public var showRating:Bool = true;

	// Stores Ratings and Combo Sprites in a group
	public var comboGroup:FlxSpriteGroup;
	// Stores HUD Objects in a Group
	public var uiGroup:FlxSpriteGroup;
	// Stores Note Objects in a Group
	public var noteGroup:FlxTypedGroup<FlxBasic>;

	private function cachePopUpScore()
	{
		var uiFolder:String = "";
		if (stageUI != "normal")
		{
			uiFolder = uiPrefix + "UI/";
		}

		for (rating in ratingsData)
		{
			Paths.image(uiFolder + rating.image + uiPostfix);
		}

		for (i in 0...10)
		{
			Paths.image(uiFolder + 'num' + i + uiPostfix);
		}
	}

	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);
		vocals.volume = 1;

		if (!ClientPrefs.data.comboStacking && comboGroup.members.length > 0)
		{
			for (spr in comboGroup)
			{
				if (spr == null)
				{
					continue;
				}

				comboGroup.remove(spr);
				spr.destroy();
			}
		}

		var placement:Float = FlxG.width * 0.35;
		var rating:FlxSprite = new FlxSprite();
		var score:Int = 350;

		//tryna do MS based judgment due to popular demand
		var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff / playbackRate);

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if (!note.ratingDisabled) daRating.hits++;
		note.rating = daRating.name;
		score = daRating.score;

		if (daRating.noteSplash && !note.noteSplashData.disabled)
		{
			spawnNoteSplashOnNote(note);
		}

		if (!cpuControlled)
		{
			songScore += score;
			if (!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				RecalculateRating(false);
			}
		}

		var uiFolder:String = "";
		var antialias:Bool = ClientPrefs.data.antialiasing;
		if (stageUI != "normal")
		{
			uiFolder = uiPrefix + "UI/";
			antialias = !isPixelStage;
		}

		rating.loadGraphic(Paths.image(uiFolder + daRating.image + uiPostfix));
		rating.screenCenter();
		rating.x = placement - 40;
		rating.y -= 60;
		rating.acceleration.y = 550 * playbackRate * playbackRate;
		rating.velocity.y -= FlxG.random.int(140, 175) * playbackRate;
		rating.velocity.x -= FlxG.random.int(0, 10) * playbackRate;
		rating.visible = (!ClientPrefs.data.hideHud && showRating);
		rating.x += ClientPrefs.data.comboOffset[0];
		rating.y -= ClientPrefs.data.comboOffset[1];
		rating.antialiasing = antialias;

		var primaryColor:FlxColor = 0;
		if (ClientPrefs.data.comboColorChange)
		{
			// determine primary color for this popup: prefer the note's comboColor if available, then rgbShader, otherwise fall back to arrowRGB
			if (note != null)
			{
				if (note.comboColor != 0)
				{
					primaryColor = note.comboColor;
				}
				else if (note.rgbShader != null)
				{
					primaryColor = note.rgbShader.r;
				}

				if (primaryColor == 0)
				{
					var _arr:Array<FlxColor> = (!PlayState.isPixelStage) ? ClientPrefs.data.arrowRGB[note.noteData % Note.colArray.length] : ClientPrefs.data.arrowRGBPixel[note.noteData % Note.colArray.length];
					if (_arr != null && _arr.length > 0) primaryColor = _arr[0];
				}
			}
			if (primaryColor != 0) rating.color = primaryColor;
		}

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(uiFolder + 'combo' + uiPostfix));
		comboSpr.screenCenter();
		comboSpr.x = placement;
		comboSpr.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
		comboSpr.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
		comboSpr.visible = (!ClientPrefs.data.hideHud && showCombo);
		comboSpr.x += ClientPrefs.data.comboOffset[0];
		comboSpr.y -= ClientPrefs.data.comboOffset[1];
		comboSpr.antialiasing = antialias;

		if (ClientPrefs.data.comboColorChange)
		{
			// tint combo sprite with the chosen primary color
			if (primaryColor != 0) comboSpr.color = primaryColor;
		}
		comboSpr.y += 60;
		comboSpr.velocity.x += FlxG.random.int(1, 10) * playbackRate;
		comboGroup.add(rating);

		if (!PlayState.isPixelStage)
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.85));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.85));
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();

		var daLoop:Int = 0;
		var xThing:Float = 0;
		if (showCombo)
		{
			comboGroup.add(comboSpr);
		}

		var separatedScore:String = Std.string(combo).lpad('0', 3);
		var trimmedScore:String = separatedScore;
		if (ClientPrefs.data.comboTrimLeadingZeros) {
			trimmedScore = Std.string(Std.parseInt(separatedScore));
		}
		// Calculate offset so numbers are always centered as if 3 digits
		var numDigits = trimmedScore.length;
		var totalDigits = 3;
		var digitWidth = PlayState.isPixelStage ? 48 : 43; // wider pixel stage spacing
		var baseOffset = PlayState.isPixelStage ? -70 + ClientPrefs.data.comboOffset[2] : -90 + ClientPrefs.data.comboOffset[2];
		// Shift so the rightmost digit is always in the same place as if it were 3 digits
		var offset = baseOffset + digitWidth * (totalDigits - numDigits);
		for (i in 0...trimmedScore.length)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(uiFolder + 'num' + Std.parseInt(trimmedScore.charAt(i)) + uiPostfix));
			numScore.screenCenter();
			numScore.x = placement + (digitWidth * daLoop) + offset;
			numScore.y += 80 - ClientPrefs.data.comboOffset[3];

			if (!PlayState.isPixelStage) numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			else numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
			numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
			numScore.velocity.x = FlxG.random.float(-5, 5) * playbackRate;
			numScore.visible = !ClientPrefs.data.hideHud;
			numScore.antialiasing = antialias;

			if (ClientPrefs.data.comboColorChange)
			{
				// tint the individual combo number with the chosen primary color
				if (primaryColor != 0) numScore.color = primaryColor;
			}

			if (showComboNum)
			{
				comboGroup.add(numScore);
			}

			FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate,
			{
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.crochet * 0.002 / playbackRate
			});

			daLoop++;
			if (numScore.x > xThing) xThing = numScore.x;
		}
		comboSpr.x = xThing + 50;
		FlxTween.tween(rating, {alpha: 0}, 0.2 / playbackRate,
		{
			startDelay: Conductor.crochet * 0.001 / playbackRate
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2 / playbackRate,
		{
			onComplete: function(tween:FlxTween)
			{
				comboSpr.destroy();
				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.002 / playbackRate
		});
	}

	public var strumsBlocked:Array<Bool> = [];
	private function onKeyPress(event:KeyboardEvent):Void
	{

		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode)
		{
			#if debug
			//Prevents crash specifically on debug without needing to try catch shit
			@:privateAccess if (!FlxG.keys._keyListMap.exists(eventKey)) return;
			#end

			if (FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressed(key);
		}
	}

	private function keyPressed(key:Int)
	{
		if (cpuControlled || paused || inCutscene || key < 0 || key >= playerStrums.length || !generatedMusic || endingSong || boyfriend.stunned) return;

		var ret:Dynamic = callOnScripts('onKeyPressPre', [key]);
		if (ret == LuaUtils.Function_Stop) return;

		// more accurate hit time for the ratings?
		var lastTime:Float = Conductor.songPosition;
		if (Conductor.songPosition >= 0) Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		// obtain notes that the player can hit
		var plrInputNotes:Array<Note> = notes.members.filter(function(n:Note):Bool
		{
			var canHit:Bool = n != null && !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit;
			return canHit && !n.isSustainNote && n.noteData == key;
		});
		plrInputNotes.sort(sortHitNotes);

		if (plrInputNotes.length != 0) // slightly faster than doing `> 0` lol
		{
			var funnyNote:Note = plrInputNotes[0]; // front note

			if (plrInputNotes.length > 1)
			{
				var doubleNote:Note = plrInputNotes[1];

				if (doubleNote.noteData == funnyNote.noteData)
				{
					// if the note has a 0ms distance (is on top of the current note), kill it
					if (Math.abs(doubleNote.strumTime - funnyNote.strumTime) < 1.0)
					{
						invalidateNote(doubleNote);
					}
					else if (doubleNote.strumTime < funnyNote.strumTime)
					{
						// replace the note if its ahead of time (or at least ensure "doubleNote" is ahead)
						funnyNote = doubleNote;
					}
				}
			}
			goodNoteHit(funnyNote);
		}
		else
		{
			if (ClientPrefs.data.ghostTapping)
			{
				callOnScripts('onGhostTap', [key]);
			}
			else
			{
				noteMissPress(key);
			}
		}

		// Needed for the  "Just the Two of Us" achievement.
		//									- Shadow Mario
		if (!keysPressed.contains(key)) keysPressed.push(key);

		//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
		Conductor.songPosition = lastTime;

		var spr:StrumNote = playerStrums.members[key];
		if (strumsBlocked[key] != true && spr != null && spr.animation.curAnim.name != 'confirm')
		{
			spr.playAnim('pressed');
			spr.resetAnim = 0;
		}
		callOnScripts('onKeyPress', [key]);
	}

	public static function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority)
		{
			return 1;
		}
		else if (!a.lowPriority && b.lowPriority)
		{
			return -1;
		}

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);
		if (!controls.controllerMode && key > -1) keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
		if (cpuControlled || !startedCountdown || paused || key < 0 || key >= playerStrums.length) return;

		var ret:Dynamic = callOnScripts('onKeyReleasePre', [key]);
		if (ret == LuaUtils.Function_Stop) return;

		var spr:StrumNote = playerStrums.members[key];
		if (spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
		}
		callOnScripts('onKeyRelease', [key]);
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int
	{
		if (key != NONE)
		{
			for (i in 0...arr.length)
			{
				var note:Array<FlxKey> = Controls.instance.keyboardBinds[arr[i]];
				for (noteKey in note)
				{
					if (key == noteKey)
					{
						return i;
					}
				}
			}
		}
		return -1;
	}

	// Hold notes
	private function keysCheck():Void
	{
		// HOLDING
		var holdArray:Array<Bool> = [];
		var pressArray:Array<Bool> = [];
		var releaseArray:Array<Bool> = [];
		for (key in keysArray)
		{
			holdArray.push(controls.pressed(key));
			pressArray.push(controls.justPressed(key));
			releaseArray.push(controls.justReleased(key));
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if (controls.controllerMode && pressArray.contains(true))
		{
			for (i in 0...pressArray.length)
			{
				if (pressArray[i] && strumsBlocked[i] != true)
				{
					keyPressed(i);
				}
			}
		}

		if (startedCountdown && !inCutscene && !boyfriend.stunned && generatedMusic)
		{
			if (notes.length > 0)
			{
				for (n in notes) // I can't do a filter here, that's kinda awesome
				{
					var canHit:Bool = (n != null && !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit);

					if (guitarHeroSustains)
					{
						canHit = canHit && n.parent != null && n.parent.wasGoodHit;
					}

					if (canHit && n.isSustainNote)
					{
						var released:Bool = !holdArray[n.noteData];

						if (!released)
						{
							goodNoteHit(n);
						}
					}
				}
			}

			if (!holdArray.contains(true) || endingSong)
			{
				playerDance();
			}
			#if ACHIEVEMENTS_ALLOWED
			else checkForAchievement(['oversinging']);
			#end
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if ((controls.controllerMode || strumsBlocked.contains(true)) && releaseArray.contains(true))
		{
			for (i in 0...releaseArray.length)
			{
				if (releaseArray[i] || strumsBlocked[i] == true)
				{
					keyReleased(i);
				}
			}
		}
	}

	function noteMiss(daNote:Note):Void //You didn't hit the key and let it go offscreen, also used by Hurt Notes
	{
		//Dupe note remove
		notes.forEachAlive(function(note:Note)
		{
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1)
			{
				invalidateNote(note);
			}
		});

		#if BOBS_ONSLAUGHT_FILES
		if (daNote.noteType == 'Lavender Onslaught Note')
		{
			HealthDrain();
		}
		#end

		#if INDIE_CROSS_FILES
		if (daNote.noteType == 'Orange Bones Note')
		{
			if (boyfriend.hasAnimation('hurt'))
			{
				boyfriend.playAnim('hurt', true);
				boyfriend.specialAnim = true;
			}
		}
		#end

		noteMissCommon(daNote.noteData, daNote);
		if (ClientPrefs.data.missSounds) FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		stagesFunc(function(stage:BaseStage) stage.noteMiss(daNote));
		var result:Dynamic = callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		if (result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('noteMiss', [daNote]);
	}

	function noteMissPress(direction:Int = 1):Void //You pressed a key when there was no notes to press for this key
	{
		if (ClientPrefs.data.ghostTapping) return; //fuck it

		noteMissCommon(direction);
		if (ClientPrefs.data.missSounds) FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		stagesFunc(function(stage:BaseStage) stage.noteMissPress(direction));
		callOnScripts('noteMissPress', [direction]);
	}

	function noteMissCommon(direction:Int, note:Note = null)
	{
		// score and data
		var subtract:Float = pressMissDamage;
		if (note != null) subtract = note.missHealth;

		// GUITAR HERO SUSTAIN CHECK LOL!!!!
		if (note != null && guitarHeroSustains && note.parent == null)
		{
			if (note.tail.length > 0)
			{
				note.alpha = 0.35;
				for (childNote in note.tail)
				{
					childNote.alpha = note.alpha;
					childNote.missed = true;
					childNote.canBeHit = false;
					childNote.ignoreNote = true;
					childNote.tooLate = true;
				}
				note.missed = true;
				note.canBeHit = false;

				//subtract += 0.385; // you take more damage if playing with this gameplay changer enabled.
				// i mean its fair :p -Crow
				subtract *= note.tail.length + 1;
				// i think it would be fair if damage multiplied based on how long the sustain is -[REDACTED]
			}

			if (note.missed)
			{
				return;
			}
		}

		if (note != null && guitarHeroSustains && note.parent != null && note.isSustainNote)
		{
			if (note.missed)
			{
				return;
			}

			var parentNote:Note = note.parent;
			if (parentNote.wasGoodHit && parentNote.tail.length > 0)
			{
				for (child in parentNote.tail) if (child != note)
				{
					child.missed = true;
					child.canBeHit = false;
					child.ignoreNote = true;
					child.tooLate = true;
				}
			}
		}

		#if VS_SONIC_EXE_FILES
		if (ringSystem)
		{
			// If the player has rings, consume one and prevent the miss from counting
			if (cNum > 0)
			{
				cNum--;
				if (counterNum != null) counterNum.text = Std.string(cNum);
				// Optional: play a ring-loss sound if available
				// Prevent the rest of the miss logic (instakill/max misses/health loss, etc.)
				return;
			}
		}
		#end

		if (instakillOnMiss && !practiceMode)
		{
			vocals.volume = 0;
			opponentVocals.volume = 0;
			doDeathCheck(true);
		}

		if (maxMisses)
		{
			if (maxSongMisses == 0 || maxSongMisses <= 0)
			{
				maxSongMisses == 0;
			}
			else
			{
				maxSongMisses--;
			}
		}

		var lastCombo:Int = combo;
		combo = 0;

		// Show combo break popup with minus sign if combo was > 0
		if (lastCombo > 0 && showComboNum && !ClientPrefs.data.hideHud)
		{
			var uiFolder:String = (stageUI != "normal") ? (uiPrefix + "UI/") : "";
			var antialias:Bool = (stageUI != "normal") ? !isPixelStage : ClientPrefs.data.antialiasing;
			var placement:Float = FlxG.width * 0.35;
			var digitWidth = PlayState.isPixelStage ? 48 : 43;
			var totalDigits = 4;
			var baseOffset = PlayState.isPixelStage ? -70 + ClientPrefs.data.comboOffset[2] : -90 + ClientPrefs.data.comboOffset[2];
			var offset = baseOffset;
			var comboStr = Std.string(lastCombo).lpad('0', 3);
			if (ClientPrefs.data.comboTrimLeadingZeros) {
				comboStr = Std.string(Std.parseInt(comboStr));
			}
			// Add minus as the first "digit"
			var displayStr = "-" + comboStr;
			// Align so the rightmost digit (number) is always in the same place as normal combo popup
			// (minus sign is treated as an extra digit to the left)
			var numDigits = displayStr.length;
			offset += digitWidth * (totalDigits - numDigits - 1); // -1 because of the minus sign being an extra character
			// Determine color
			var primaryColor:FlxColor = 0;
			if (ClientPrefs.data.comboColorChange)
			{
				if (note != null)
				{
					if (note.comboColor != 0)
						primaryColor = note.comboColor;
					else if (note.rgbShader != null)
						primaryColor = note.rgbShader.r;
					if (primaryColor == 0)
					{
						var _arr:Array<FlxColor> = (!PlayState.isPixelStage) ? ClientPrefs.data.arrowRGB[note.noteData % Note.colArray.length] : ClientPrefs.data.arrowRGBPixel[note.noteData % Note.colArray.length];
						if (_arr != null && _arr.length > 0) primaryColor = _arr[0];
					}
				}
			}
			for (i in 0...displayStr.length)
			{
				var char = displayStr.charAt(i);
				var imgName = (char == "-") ? "minus" : ("num" + char);
				var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(uiFolder + imgName + uiPostfix));
				numScore.screenCenter();
				numScore.x = placement + (digitWidth * i) + offset;
				numScore.y += 80 - ClientPrefs.data.comboOffset[3];
				if (!PlayState.isPixelStage) numScore.setGraphicSize(Std.int(numScore.width * 0.5));
				else numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
				numScore.updateHitbox();
				numScore.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
				numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
				numScore.velocity.x = FlxG.random.float(-5, 5) * playbackRate;
				numScore.visible = true;
				numScore.antialiasing = antialias;
				if (ClientPrefs.data.comboColorChange && primaryColor != 0) numScore.color = primaryColor;
				comboGroup.add(numScore);
				FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate, {
					onComplete: function(tween:FlxTween) {
						numScore.destroy();
					},
					startDelay: Conductor.crochet * 0.002 / playbackRate
				});
			}
		}

		health -= subtract * healthLoss;
		songScore -= 10;
		if (!endingSong) songMisses++;
		totalPlayed++;
		RecalculateRating(true);

		// play character anims
		var char:Character = boyfriend;
		if ((note != null && note.gfNote) || (SONG.notes[curSection] != null && SONG.notes[curSection].gfSection)) char = gf;

		if (char != null && (note == null || !note.noMissAnimation) && char.hasMissAnimations)
		{
			var postfix:String = '';
			if (note != null) postfix = note.animSuffix;

			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, direction)))] + 'miss' + postfix;
			char.playAnim(animToPlay, true);

			if (char != gf && lastCombo > 5 && gf != null && gf.hasAnimation('sad'))
			{
				gf.playAnim('sad');
				gf.specialAnim = true;
			}
		}
		vocals.volume = 0;
	}

	function opponentNoteHit(note:Note):Void
	{
		var result:Dynamic = callOnLuas('opponentNoteHitPre', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if (result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript('opponentNoteHitPre', [note]);

		if (result == LuaUtils.Function_Stop) return;

		if (songName != 'tutorial')
		{
			camZooming = true;
		}

		if (note.noteType == 'Hey!' && dad.hasAnimation('hey'))
		{
			dad.playAnim('hey', true);
			dad.specialAnim = true;
			dad.heyTimer = 0.6;
		}
		else if (!note.noAnimation)
		{
			var char:Character = dad;
			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, note.noteData)))] + note.animSuffix;
			if (note.gfNote) char = gf;
			if (note.playerNote) char = boyfriend;
			if (note.opponentNote) char = dad;
			if (note.playerOpponentNote) char = dad;
			if (note.gfOpponentNote) char = dad;
			if (note.gfPlayerNote) char = boyfriend;
			if (note.playerOpponentGFNote) char = dad;

			if (char != null)
			{
				var canPlay:Bool = true;
				if (note.isSustainNote)
				{
					var holdAnim:String = animToPlay + '-hold';
					if (char.animation.exists(holdAnim)) animToPlay = holdAnim;
					if (char.getAnimationName() == holdAnim || char.getAnimationName() == holdAnim + '-loop') canPlay = false;
				
					if (note.playerOpponentNote || note.playerOpponentGFNote)
					{
						var holdAnim:String = animToPlay + '-hold';
						if (boyfriend.animation.exists(holdAnim)) animToPlay = holdAnim;
						if (boyfriend.getAnimationName() == holdAnim || boyfriend.getAnimationName() == holdAnim + '-loop') canPlay = false;
					}

					if (note.gfOpponentNote || note.gfPlayerNote || note.playerOpponentGFNote)
					{
						var holdAnim:String = animToPlay + '-hold';
						if (gf.animation.exists(holdAnim)) animToPlay = holdAnim;
						if (gf.getAnimationName() == holdAnim || gf.getAnimationName() == holdAnim + '-loop') canPlay = false;
					}
				}

				if (canPlay) char.playAnim(animToPlay, true);
				if (note.playerOpponentNote || note.playerOpponentGFNote) if (canPlay) boyfriend.playAnim(animToPlay, true);
				if (note.gfOpponentNote || note.gfPlayerNote || note.playerOpponentGFNote) if (canPlay) gf.playAnim(animToPlay, true);
				char.holdTimer = 0;
				if (note.playerOpponentNote || note.playerOpponentGFNote) boyfriend.holdTimer = 0;
				if (note.gfOpponentNote || note.gfPlayerNote || note.playerOpponentGFNote) gf.holdTimer = 0;
			}
		}

		if (opponentVocals.length <= 0) vocals.volume = 1;
		strumPlayAnim(true, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
		note.hitByOpponent = true;
		
		stagesFunc(function(stage:BaseStage) stage.opponentNoteHit(note));
		var result:Dynamic = callOnLuas('opponentNoteHit', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if (result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('opponentNoteHit', [note]);

		if (!note.isSustainNote) invalidateNote(note);

		if (guitarHeroSustains)
		{
			if (!note.isSustainNote && healthDrain && health > 0.03)
			{
				health -= note.hitHealth * healthGain;
			}
		}
		else
		{
			if (healthDrain && health > 0.03)
			{
				health -= note.hitHealth * healthGain;
			}
		}
	}

	public function goodNoteHit(note:Note):Void
	{
		if (note.wasGoodHit) return;
		#if VS_SONIC_EXE_FILES
		if (cpuControlled && note.ignoreNote && note.noteType != 'Ring Note') return;
		#end
		#if BOBS_ONSLAUGHT_FILES
		//if (cpuControlled && note.ignoreNote && note.noteType != 'Lavender Onslaught Note') return;
		#end

		var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
		var leData:Int = Math.round(Math.abs(note.noteData));
		var leType:String = note.noteType;

		var result:Dynamic = callOnLuas('goodNoteHitPre', [notes.members.indexOf(note), leData, leType, isSus]);
		if (result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript('goodNoteHitPre', [note]);

		if (result == LuaUtils.Function_Stop) return;

		note.wasGoodHit = true;

		if (note.hitsoundVolume > 0 && !note.hitsoundDisabled)
		{
			FlxG.sound.play(Paths.sound(note.hitsound), note.hitsoundVolume);
		}

		if (!note.hitCausesMiss) //Common notes
		{
			if (!note.noAnimation)
			{
				var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, note.noteData)))] + note.animSuffix;

				var char:Character = boyfriend;
				var animCheck:String = 'hey';
				if (note.gfNote)
				{
					char = gf;
					animCheck = 'cheer';
				}
				if (note.playerNote)
				{
					char = boyfriend;
					animCheck = 'hey';
				}
				if (note.opponentNote)
				{
					char = dad;
					animCheck = 'hey';
				}
				if (note.playerOpponentNote)
				{
					char = boyfriend;
					animCheck = 'hey';
				}
				if (note.gfOpponentNote)
				{
					char = dad;
					animCheck = 'hey';
				}
				if (note.gfPlayerNote)
				{
					char = boyfriend;
					animCheck = 'hey';
				}
				if (note.playerOpponentGFNote)
				{
					char = boyfriend;
					animCheck = 'hey';
				}

				if (char != null)
				{
					var canPlay:Bool = true;
					if (note.isSustainNote)
					{
						var holdAnim:String = animToPlay + '-hold';
						if (char.animation.exists(holdAnim)) animToPlay = holdAnim;
						if (char.getAnimationName() == holdAnim || char.getAnimationName() == holdAnim + '-loop') canPlay = false;
					
						if (note.playerOpponentNote || note.playerOpponentGFNote)
						{
							var holdAnim:String = animToPlay + '-hold';
							if (dad.animation.exists(holdAnim)) animToPlay = holdAnim;
							if (dad.getAnimationName() == holdAnim || dad.getAnimationName() == holdAnim + '-loop') canPlay = false;
						}

						if (note.gfPlayerNote || note.gfOpponentNote || note.playerOpponentGFNote)
						{
							var holdAnim:String = animToPlay + '-hold';
							if (gf.animation.exists(holdAnim)) animToPlay = holdAnim;
							if (gf.getAnimationName() == holdAnim || gf.getAnimationName() == holdAnim + '-loop') canPlay = false;
						}
					}
	
					if (canPlay) char.playAnim(animToPlay, true);
					if (note.playerOpponentNote || note.playerOpponentGFNote) if (canPlay) dad.playAnim(animToPlay, true);
					if (note.gfPlayerNote || note.gfOpponentNote || note.playerOpponentGFNote) if (canPlay) gf.playAnim(animToPlay, true);
					char.holdTimer = 0;
					if (note.playerOpponentNote || note.playerOpponentGFNote) dad.holdTimer = 0;
					if (note.gfPlayerNote || note.gfOpponentNote || note.playerOpponentGFNote) gf.holdTimer = 0;

					if (note.noteType == 'Hey!')
					{
						if (char.hasAnimation(animCheck))
						{
							char.playAnim(animCheck, true);
							char.specialAnim = true;
							char.heyTimer = 0.6;
						}
					}

					#if VS_SONIC_EXE_FILES
					// Make 'Ring Note' a must-press note only when cpuControlled is active
					/*if (note.noteType == 'Ring Note')
					{
						note.mustPress = cpuControlled;
						note.isSustainNote = cpuControlled;
					}*/

					if (note.noteType == 'Ring Note' && !note.isSustainNote)
					{
						if (ringSystem)
						{
							cNum += 1;
						}
						FlxG.sound.play(Paths.sound('ring'));
					}
					#end

					#if BALDIS_BASICS_IN_FUNKIN_FILES
					if (note.noteType == 'Piracy Note')
					{
						trace("YOU HIT THE PIRACY NOTE DUMBASS");
						FlxG.sound.play(Paths.sound('creeperCrash'));
						vocals.stop();
						opponentVocals.stop();
						FlxG.sound.music.stop();
						#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
						//FlxG.switchState(new CreeperScreenState());
						MusicBeatState.switchState(new CreeperScreenState());
					}
					#end
				}
			}

			if (!cpuControlled)
			{
				var spr = playerStrums.members[note.noteData];
				if (spr != null)
				{
					spr.playAnim('confirm', true);
				}
			}
			else
			{
				strumPlayAnim(false, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
			}
			vocals.volume = 1;

			if (!note.isSustainNote)
			{
				combo++;
				if (combo > 9999)
				{
					combo = 9999;
				}
				popUpScore(note);
			}
			var gainHealth:Bool = true; // prevent health gain, *if* sustains are treated as a singular note
			if (guitarHeroSustains && note.isSustainNote) gainHealth = false;
			if (gainHealth) health += note.hitHealth * healthGain;

		}
		else //Notes that count as a miss if you hit them (Hurt notes for example)
		{
			if (!note.noMissAnimation)
			{
				switch(note.noteType)
				{
					case 'Hurt Note':
					{
						if (boyfriend.hasAnimation('hurt'))
						{
							boyfriend.playAnim('hurt', true);
							boyfriend.specialAnim = true;
						}
					}

					#if BALDIS_BASICS_IN_FUNKIN_FILES
					case 'Ruler Note':
					{
						if (boyfriend.hasAnimation('hurt'))
						{
							boyfriend.playAnim('hurt', true);
							boyfriend.specialAnim = true;
						}
						FlxG.sound.play(Paths.sound('rulerSlap'));

						screenShake = true;

						new FlxTimer().start(0.1, function(tmr:FlxTimer)
						{
							screenShake = false;
						});
					}
					#end

					#if BOBS_ONSLAUGHT_FILES
					case 'Black Onslaught Note':
					{
						HealthDrain();
					}
					#end

					#if INDIE_CROSS_FILES
					case 'Blue Bones Note':
					{
						if (boyfriend.hasAnimation('hurt'))
						{
							boyfriend.playAnim('hurt', true);
							boyfriend.specialAnim = true;
						}
					}
					#end
				}
			}

			noteMiss(note);
			if (!note.noteSplashData.disabled && !note.isSustainNote) spawnNoteSplashOnNote(note);
		}

		stagesFunc(function(stage:BaseStage) stage.goodNoteHit(note));
		var result:Dynamic = callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);
		if (result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('goodNoteHit', [note]);
		if (!note.isSustainNote) invalidateNote(note);
	}

	public function invalidateNote(note:Note):Void
	{
		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	public function spawnNoteSplashOnNote(note:Note)
	{
		if (note != null)
		{
			var strum:StrumNote = playerStrums.members[note.noteData];
			if (strum != null)
			{
				spawnNoteSplash(strum.x, strum.y, note.noteData, note, strum);
			}
		}
	}

	public function spawnNoteSplash(x:Float = 0, y:Float = 0, ?data:Int = 0, ?note:Note, ?strum:StrumNote)
	{
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.babyArrow = strum;
		splash.spawnSplashNote(x, y, data, note);
		grpNoteSplashes.add(splash);
	}

	override function destroy()
	{
		if (psychlua.CustomSubstate.instance != null)
		{
			closeSubState();
			resetSubState();
		}

		#if LUA_ALLOWED
		for (lua in luaArray)
		{
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = null;
		FunkinLua.customFunctions.clear();
		#end

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
		{
			if (script != null)
			{
				if (script.exists('onDestroy')) script.call('onDestroy');
				script.destroy();
			}
		}

		hscriptArray = null;
		#end
		stagesFunc(function(stage:BaseStage) stage.destroy());

		#if VIDEOS_ALLOWED
		if (videoCutscene != null)
		{
			videoCutscene.destroy();
			videoCutscene = null;
		}
		#end

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		FlxG.camera.setFilters([]);

		#if FLX_PITCH FlxG.sound.music.pitch = 1; #end
		FlxG.animationTimeScale = 1;

		Note.globalRgbShaders = [];
		backend.NoteTypesConfig.clearNoteTypesData();

		NoteSplash.configs.clear();
		instance = null;
		super.destroy();
	}

	#if BOBS_ONSLAUGHT_FILES
	function HealthDrain():Void
	{
		FlxG.sound.play(Paths.sound("BoomCloud"), 1);
		if (boyfriend.hasAnimation('hurt'))
		{
			boyfriend.playAnim('hurt', true);
			boyfriend.specialAnim = true;
		}
		FlxG.camera.zoom -= 0.02;
		new FlxTimer().start(0.3, function(tmr:FlxTimer)
		{
			boyfriend.playAnim('idle', true);
		});
		new FlxTimer().start(0.01, function(tmr:FlxTimer)
		{
			health -= 0.005;
		}, 300);
	}
	#end

	var lastStepHit:Int = -1;
	override function stepHit()
	{
		super.stepHit();

		if (curStep == lastStepHit)
		{
			return;
		}

		lastStepHit = curStep;
		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
	}

	var lastBeatHit:Int = -1;

	override function beatHit()
	{
		if (lastBeatHit >= curBeat)
		{
			//trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}

		if (generatedMusic)
		{
			notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}

		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		characterBopper(curBeat);

		super.beatHit();
		lastBeatHit = curBeat;

		setOnScripts('curBeat', curBeat);
		callOnScripts('onBeatHit');
	}

	public function characterBopper(beat:Int):Void
	{
		if (gf != null && beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && !gf.getAnimationName().startsWith('sing') && !gf.stunned)
		{
			gf.dance();
		}

		if (boyfriend != null && beat % boyfriend.danceEveryNumBeats == 0 && !boyfriend.getAnimationName().startsWith('sing') && !boyfriend.stunned)
		{
			boyfriend.dance();
		}

		if (dad != null && beat % dad.danceEveryNumBeats == 0 && !dad.getAnimationName().startsWith('sing') && !dad.stunned)
		{
			dad.dance();
		}
	}

	public function playerDance():Void
	{
		var anim:String = boyfriend.getAnimationName();
		if (boyfriend.holdTimer > Conductor.stepCrochet * (0.0016 #if FLX_PITCH / FlxG.sound.music.pitch #end) * boyfriend.singDuration && anim.startsWith('sing') && !anim.endsWith('miss'))
		{
			boyfriend.dance();
		}
	}

	override function sectionHit()
	{
		if (SONG.notes[curSection] != null)
		{
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
			{
				moveCameraSection();
			}

			if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.data.camZooms)
			{
				FlxG.camera.zoom += 0.015 * camZoomingMult;
				camHUD.zoom += 0.03 * camZoomingMult;
			}

			if (SONG.notes[curSection].changeBPM)
			{
				Conductor.bpm = SONG.notes[curSection].bpm;
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
			}
			setOnScripts('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnScripts('altAnim', SONG.notes[curSection].altAnim);
			setOnScripts('gfSection', SONG.notes[curSection].gfSection);
		}
		super.sectionHit();

		setOnScripts('curSection', curSection);
		callOnScripts('onSectionHit');
	}

	#if LUA_ALLOWED
	public function startLuasNamed(luaFile:String)
	{
		#if MODS_ALLOWED
		var luaToLoad:String = Paths.modFolders(luaFile);
		if (!FileSystem.exists(luaToLoad))
		{
			luaToLoad = Paths.getSharedPath(luaFile);
		}

		if (FileSystem.exists(luaToLoad))
		#elseif sys
		var luaToLoad:String = Paths.getSharedPath(luaFile);
		if (OpenFlAssets.exists(luaToLoad))
		#end
		{
			for (script in luaArray)
			{
				if (script.scriptName == luaToLoad) return false;
			}

			new FunkinLua(luaToLoad);
			return true;
		}
		return false;
	}
	#end

	#if HSCRIPT_ALLOWED
	public function startHScriptsNamed(scriptFile:String)
	{
		#if MODS_ALLOWED
		var scriptToLoad:String = Paths.modFolders(scriptFile);
		if (!FileSystem.exists(scriptToLoad))
		{
			scriptToLoad = Paths.getSharedPath(scriptFile);
		}
		#else
		var scriptToLoad:String = Paths.getSharedPath(scriptFile);
		#end

		if (FileSystem.exists(scriptToLoad))
		{
			if (Iris.instances.exists(scriptToLoad)) return false;

			initHScript(scriptToLoad);
			return true;
		}
		return false;
	}

	public function initHScript(file:String)
	{
		var newScript:HScript = null;
		try
		{
			newScript = new HScript(null, file);
			if (newScript.exists('onCreate')) newScript.call('onCreate');
			trace('initialized hscript interp successfully: $file');
			hscriptArray.push(newScript);
		}
		catch(e:IrisError)
		{
			var pos:HScriptInfos = cast {fileName: file, showLine: false};
			Iris.error(Printer.errorToString(e, false), pos);
			var newScript:HScript = cast (Iris.instances.get(file), HScript);
			if (newScript != null)
			{
				newScript.destroy();
			}
		}
	}
	#end

	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic
	{
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		if (args == null) args = [];
		if (exclusions == null) exclusions = [];
		if (excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var result:Dynamic = callOnLuas(funcToCall, args, ignoreStops, exclusions, excludeValues);
		if (result == null || excludeValues.contains(result)) result = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);
		return result;
	}

	public function callOnLuas(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		#if LUA_ALLOWED
		if (args == null) args = [];
		if (exclusions == null) exclusions = [];
		if (excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var arr:Array<FunkinLua> = [];
		for (script in luaArray)
		{
			if (script.closed)
			{
				arr.push(script);
				continue;
			}

			if (exclusions.contains(script.scriptName))
			{
				continue;
			}

			var myValue:Dynamic = script.call(funcToCall, args);
			if ((myValue == LuaUtils.Function_StopLua || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
			{
				returnVal = myValue;
				break;
			}

			if (myValue != null && !excludeValues.contains(myValue))
			{
				returnVal = myValue;
			}

			if (script.closed) arr.push(script);
		}

		if (arr.length > 0)
		{
			for (script in arr)
			{
				luaArray.remove(script);
			}
		}
		#end
		return returnVal;
	}

	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?ignoreStops:Bool = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic
	{
		var returnVal:Dynamic = LuaUtils.Function_Continue;

		#if HSCRIPT_ALLOWED
		if (exclusions == null) exclusions = new Array();
		if (excludeValues == null) excludeValues = new Array();
		excludeValues.push(LuaUtils.Function_Continue);

		var len:Int = hscriptArray.length;
		if (len < 1)
		{
			return returnVal;
		}

		for (script in hscriptArray)
		{
			@:privateAccess
			if (script == null || !script.exists(funcToCall) || exclusions.contains(script.origin))
			{
				continue;
			}

			var callValue = script.call(funcToCall, args);
			if (callValue != null)
			{
				var myValue:Dynamic = callValue.returnValue;

				if ((myValue == LuaUtils.Function_StopHScript || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
				{
					returnVal = myValue;
					break;
				}

				if (myValue != null && !excludeValues.contains(myValue))
				{
					returnVal = myValue;
				}
			}
		}
		#end

		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		if (exclusions == null) exclusions = [];
		setOnLuas(variable, arg, exclusions);
		setOnHScript(variable, arg, exclusions);
	}

	public function setOnLuas(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		#if LUA_ALLOWED
		if (exclusions == null) exclusions = [];
		for (script in luaArray)
		{
			if (exclusions.contains(script.scriptName))
			{
				continue;
			}

			script.set(variable, arg);
		}
		#end
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		#if HSCRIPT_ALLOWED
		if (exclusions == null) exclusions = [];
		for (script in hscriptArray)
		{
			if (exclusions.contains(script.origin))
			{
				continue;
			}

			script.set(variable, arg);
		}
		#end
	}

	function strumPlayAnim(isDad:Bool, id:Int, time:Float)
	{
		var spr:StrumNote = null;
		if (isDad)
		{
			spr = opponentStrums.members[id];
		}
		else
		{
			spr = playerStrums.members[id];
		}

		if (spr != null)
		{
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;
	public function RecalculateRating(badHit:Bool = false, scoreBop:Bool = true)
	{
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);
		setOnScripts('combo', combo);

		var ret:Dynamic = callOnScripts('onRecalculateRating', null, true);
		if (ret != LuaUtils.Function_Stop)
		{
			ratingName = '?';
			if (totalPlayed != 0) //Prevent divide by 0
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				//trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
				if (ratingPercent < 1)
				{
					for (i in 0...ratingStuff.length-1)
					{
						if (ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
					}
				}
			}
			fullComboFunction();
		}
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
		setOnScripts('totalPlayed', totalPlayed);
		setOnScripts('totalNotesHit', totalNotesHit);
		updateScore(badHit, scoreBop); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce
	}

	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null)
	{
		if (chartingMode) return;

		var usedPractice:Bool = ClientPrefs.getGameplaySetting('practice');
		var usedBotplay:Bool = ClientPrefs.getGameplaySetting('botplay');
		if (cpuControlled) return;

		for (name in achievesToCheck)
		{
			if (!Achievements.exists(name))
			{
				continue;
			}

			var unlock:Bool = false;
			if (name != WeekData.getWeekFileName() + '_nomiss') // common achievements
			{
				switch(name)
				{
					case 'ur_bad':
						unlock = (ratingPercent < 0.2 && !practiceMode && !usedBotplay);

					case 'ur_good':
						unlock = (ratingPercent >= 1 && !usedPractice && !usedBotplay);

					case 'oversinging':
						unlock = (boyfriend.holdTimer >= 10 && !usedPractice && !usedBotplay);

					case 'hype':
						unlock = (!boyfriendIdled && !usedPractice && !usedBotplay);

					case 'two_keys':
						unlock = (!usedPractice && !usedBotplay && keysPressed.length <= 2);

					case 'toastie':
						unlock = (!ClientPrefs.data.cacheOnGPU && !ClientPrefs.data.shaders && ClientPrefs.data.lowQuality && !ClientPrefs.data.antialiasing);

					#if BASE_GAME_FILES
					case 'debugger':
						unlock = (songName == 'test' && !usedPractice && !usedBotplay);
					#end
				}
			}
			else // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
			{
				if (isStoryMode && campaignMisses + songMisses < 1 && Difficulty.getString().toUpperCase() == 'HARD' && storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice && !usedBotplay)
				{
					unlock = true;
				}
			}

			if (unlock)
			{
				Achievements.unlock(name);
			}
		}
	}
	#end

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	#end
	public function createRuntimeShader(shaderName:String):ErrorHandledRuntimeShader
	{
		#if (!flash && sys)
		if (!ClientPrefs.data.shaders) return new ErrorHandledRuntimeShader(shaderName);

		if (!runtimeShaders.exists(shaderName) && !initLuaShader(shaderName))
		{
			FlxG.log.warn('Shader $shaderName is missing!');
			return new ErrorHandledRuntimeShader(shaderName);
		}

		var arr:Array<String> = runtimeShaders.get(shaderName);
		return new ErrorHandledRuntimeShader(shaderName, arr[0], arr[1]);
		#else
		FlxG.log.warn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	public function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if (!ClientPrefs.data.shaders) return false;

		#if (!flash && sys)
		if (runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'shaders/'))
		{
			var frag:String = folder + name + '.frag';
			var vert:String = folder + name + '.vert';
			var found:Bool = false;
			if (FileSystem.exists(frag))
			{
				frag = File.getContent(frag);
				found = true;
			}
			else
			{
				frag = null;
			}

			if (FileSystem.exists(vert))
			{
				vert = File.getContent(vert);
				found = true;
			}
			else
			{
				vert = null;
			}

			if (found)
			{
				runtimeShaders.set(name, [frag, vert]);
				//trace('Found shader $name!');
				return true;
			}
		}
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			addTextToDebug('Missing shader $name .frag AND .vert files!', FlxColor.RED);
			#else
			FlxG.log.warn('Missing shader $name .frag AND .vert files!');
			#end
		#else
		FlxG.log.warn('This platform doesn\'t support Runtime Shaders!');
		#end
		return false;
	}
}
