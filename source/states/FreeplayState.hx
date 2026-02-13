package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;

import openfl.utils.Assets;

import haxe.Json;

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	// difficulties gathered from all freeplay songs (used for the Random slot)
	private var randomDifficulties:Array<String> = null;
	private var difficultySongMap:Map<String, Array<Int>> = null;

	var bg:FlxSprite;
	var intendedColor:Int;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var showingMissingPopup:Bool = false;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	override function create()
	{
		//Paths.clearStoredMemory();
		//Paths.clearUnusedMemory();
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		// If `randomDifficulties` was populated earlier (e.g., hot-reload),
		// deduplicate by normalized key. Guard against null to avoid crashes.
		if (randomDifficulties != null)
		{
			var seenGuard:Map<String,Bool> = new Map<String,Bool>();
			var dedupedGuard:Array<String> = [];
			for (d in randomDifficulties)
			{
				var k = Paths.formatToSongPath(d);
				if (!seenGuard.exists(k))
				{
					seenGuard.set(k, true);
					dedupedGuard.push(d);
				}
			}
			randomDifficulties = dedupedGuard;
		}

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Freeplay Menu", null);
		#end

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		// Add a special slot that represents a random pick (not present in week files)
		addSong('Random', -1, '', FlxColor.fromRGB(253, 232, 113));

		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		Mods.loadTopMod();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.targetY = i;
			grpSongs.add(songText);

			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			Mods.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = null;
			// ensure every songText starts hidden/inactive (including Random)
			songText.visible = songText.active = songText.isMenuItem = false;
			// For the programmatically added 'Random' slot we don't create an icon
			if (songs[i].songName != null && songs[i].songName.toLowerCase() != 'random')
			{
				icon = new HealthIcon(songs[i].songCharacter);
				icon.sprTracker = songText;

				// too laggy with a lot of songs, so i had to recode the logic for it
				icon.visible = icon.active = false;

				// using a FlxGroup is too much fuss!
				add(icon);
			}

			// keep indexing stable by pushing the icon (or null) placeholder
			iconArray.push(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}
		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);


		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if(curSelected >= songs.length) curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		var leText:String = Language.getPhrase("freeplay_tip", "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.");
		bottomString = leText;
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);
		
		player = new MusicPlayer(this);
		add(player);
		
		// Build the merged difficulty list for the Random slot
		buildRandomDifficulties();
		changeSelection();
		updateTexts();
		super.create();
	}

	/**
	 * Pick a random song index. If `diff` is provided, pick only from songs
	 * that have that difficulty (checked via `difficultySongMap`).
	 */
	private function pickRandomSong(?diff:String):Int
	{
		var choices:Array<Int> = [];
		// normalize diff key for lookup
		var diffKey:String = null;
		if (diff != null) diffKey = Paths.formatToSongPath(diff);
		if (diffKey != null && difficultySongMap != null && difficultySongMap.exists(diffKey))
		{
			var list:Array<Int> = difficultySongMap.get(diffKey);
			for (idx in list) if(idx >= 0 && idx < songs.length) choices.push(idx);
		}
		else
		{
			for (i in 0...songs.length)
			{
				if (songs[i] != null && songs[i].songName != null && Std.string(songs[i].songName).toLowerCase() != 'random')
					choices.push(i);
			}
		}
		if (choices.length == 0) return curSelected;
		return choices[FlxG.random.int(0, choices.length - 1)];
	}

	/**
	 * Scan all songs (including mods) and collect all difficulty identifiers
	 * found in song chart filenames. Results are human-friendly names.
	 */
	private function buildRandomDifficulties():Void
	{
		randomDifficulties = [];
		difficultySongMap = [];
		// track normalized keys we've already added to avoid duplicates
		var seenKeys:Map<String,Bool> = new Map<String,Bool>();
		// Start with the default difficulties so we preserve common names
		for (d in Difficulty.defaultList)
		{
			var dk = Paths.formatToSongPath(d);
			if (!seenKeys.exists(dk))
			{
				seenKeys.set(dk, true);
				randomDifficulties.push(d);
			}
		}

		// First, gather difficulties declared in week files (including mods)
		for (w in WeekData.weeksList)
		{
			var wk:WeekData = WeekData.weeksLoaded.get(w);
			if (wk == null) continue;
			if (wk.difficulties != null && wk.difficulties.length > 0)
			{
				var diffs:Array<String> = wk.difficulties.split(',');
				for (d in diffs)
				{
					var dn:String = d.trim();
					if(dn.length == 0) continue;
					var dkn = Paths.formatToSongPath(dn);
					if(!seenKeys.exists(dkn)) { seenKeys.set(dkn, true); randomDifficulties.push(dn); }
					// ensure map key exists (normalized)
					var key:String = Paths.formatToSongPath(dn);
					if(!difficultySongMap.exists(key)) difficultySongMap.set(key, []);
				}
			}
		}

		// Map songs to week-declared difficulties and also scan individual chart files
		for (i in 0...songs.length)
		{
			var s = songs[i];
			if (s == null || s.songName == null) continue;
			var base:String = Paths.formatToSongPath(s.songName);
			if(base.length == 0) continue;

			// If the song belongs to a known week, add that week's difficulties for this song
			if (s.week >= 0 && s.week < WeekData.weeksList.length)
			{
				var wkName = WeekData.weeksList[s.week];
				var wkData:WeekData = WeekData.weeksLoaded.get(wkName);
				if (wkData != null && wkData.difficulties != null && wkData.difficulties.length > 0)
				{
					var diffs:Array<String> = wkData.difficulties.split(',');
					for (d in diffs)
					{
						var dn:String = d.trim();
						if(dn.length == 0) continue;
						var dkn = Paths.formatToSongPath(dn);
						if(!seenKeys.exists(dkn)) { seenKeys.set(dkn, true); randomDifficulties.push(dn); }
						var key:String = Paths.formatToSongPath(dn);
						if(!difficultySongMap.exists(key)) difficultySongMap.set(key, []);
						var idxList = difficultySongMap.get(key);
						if(!idxList.contains(i)) idxList.push(i);
					}
				}
			}

			var folders:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'songs/' + base + '/');
			for (folder in folders)
			{
				try
				{
					for (file in FileSystem.readDirectory(folder))
					{
						if (!file.toLowerCase().endsWith('.json')) continue;
						var nameNoExt = file.substr(0, file.length - 5);
						if (!nameNoExt.startsWith(base)) continue;
						var postfix:String = '';
						if (nameNoExt.length > base.length) // has suffix like '-hard'
							postfix = nameNoExt.substr(base.length + (nameNoExt.charAt(base.length) == '-' ? 1 : 0));
						var diffName:String;
						if (postfix.length == 0)
							diffName = Difficulty.getDefault();
						else
						{
							// convert 'hard_mode' or 'hard-mode' into 'Hard Mode'
							var parts:Array<String> = postfix.split('-').join(' ').split('_').join(' ').split(' ');
							for (p in 0...parts.length) if(parts[p].length > 0) parts[p] = parts[p].substr(0,1).toUpperCase() + parts[p].substr(1);
							diffName = parts.join(' ').trim();
						}
						if(diffName.length > 0)
						{
							var dkn = Paths.formatToSongPath(diffName);
							if(!seenKeys.exists(dkn)) { seenKeys.set(dkn, true); randomDifficulties.push(diffName); }
						}
						if(diffName.length > 0)
						{
							var key:String = Paths.formatToSongPath(diffName);
							if(!difficultySongMap.exists(key)) difficultySongMap.set(key, []);
							var idxList = difficultySongMap.get(key);
							if(!idxList.contains(i)) idxList.push(i);
						}
					}
				} catch(e:Dynamic) {
					// ignore read errors per-folder
				}
			}
		}
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;

	var stopMusicPlay:Bool = false;
	override function update(elapsed:Float)
	{
		if(WeekData.weeksList.length < 1)
			return;

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) //No decimals, add an empty space
			ratingSplit.push('');
		
		while(ratingSplit[1].length < 2) //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';

		// If the missing/chart error popup is shown, only allow BACK to close it
		if (showingMissingPopup)
		{
			if (controls.BACK)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				missingText.visible = false;
				missingTextBG.visible = false;
				showingMissingPopup = false;
			}
			super.update(elapsed);
			return;
		}

		var shiftMult:Int = 1;
		if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

		if (!player.playingMusic)
		{
			scoreText.text = Language.getPhrase('personal_best', 'PERSONAL BEST: {1} ({2}%)', [lerpScore, ratingSplit.join('.')]);
			positionHighscore();
			
			if(songs.length > 1)
			{
				if(FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;	
				}
				else if(FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;	
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if(FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_LEFT_P)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}
		}

		if (controls.BACK)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				FlxG.sound.playMusic(Paths.music('freeplayRandom'), 0.7);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else 
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7);
			}
		}

		if(FlxG.keys.justPressed.CONTROL && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if(FlxG.keys.justPressed.SPACE)
		{
			if(instPlaying != curSelected && !player.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.currentModDirectory = songs[curSelected].folder;
				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
				if (PlayState.SONG.needsVoices)
				{
					vocals = new FlxSound();
					try
					{
						var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
						if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song);
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							vocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(vocals);
							vocals.persist = vocals.looped = true;
							vocals.volume = 0.8;
							vocals.play();
							vocals.pause();
						}
						else vocals = FlxDestroyUtil.destroy(vocals);
					}
					catch(e:Dynamic)
					{
						vocals = FlxDestroyUtil.destroy(vocals);
					}
					
					opponentVocals = new FlxSound();
					try
					{
						//trace('please work...');
						var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							opponentVocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(opponentVocals);
							opponentVocals.persist = opponentVocals.looped = true;
							opponentVocals.volume = 0.8;
							opponentVocals.play();
							opponentVocals.pause();
							//trace('yaaay!!');
						}
						else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
					catch(e:Dynamic)
					{
						//trace('FUUUCK');
						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
				}

				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
				FlxG.sound.music.pause();
				instPlaying = curSelected;

				player.playingMusic = true;
				player.curTime = 0;
				player.switchPlayMusic();
				player.pauseOrResume(true);
			}
			else if (instPlaying == curSelected && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if (controls.ACCEPT && !player.playingMusic)
		{
			persistentUpdate = false;
			// If the selected entry is the special "Random" entry, pick a real random song
			if (songs[curSelected].songName.toLowerCase() == 'random')
			{
				var diffName:String = null;
				if (Difficulty.list != null && curDifficulty >= 0 && curDifficulty < Difficulty.list.length)
					diffName = Difficulty.list[curDifficulty];
				// Try a few times to pick a song that actually has a chart for the chosen difficulty
				var attempts:Int = 0;
				var maxAttempts:Int = if (songs.length * 2 > 10) songs.length * 2 else 10;
				var tried:Array<Int> = [];
				var picked:Int = -1;
				while (attempts < maxAttempts)
				{
					var candidate:Int = (diffName != null) ? pickRandomSong(diffName) : pickRandomSong();
					if (candidate < 0 || candidate >= songs.length) { attempts++; continue; }
					if (tried.contains(candidate)) { attempts++; continue; }
					tried.push(candidate);
					try
					{
						var candidateName:String = Paths.formatToSongPath(songs[candidate].songName);
						var formatted:String = Highscore.formatSong(candidateName, curDifficulty);
						var chart = Song.getChart(formatted, candidateName);
						if (chart != null)
						{
							picked = candidate;
							break;
						}
					}
					catch(e:Dynamic)
					{
						// treat any error as missing chart and try another
					}
					attempts++;
				}
				if (picked >= 0)
				{
					curSelected = picked;
					changeSelection(0, false);
				}
				else
				{
					// Fallback: try any song sequentially that has a chart for this difficulty
					for (i in 0...songs.length)
					{
						if (songs[i] == null || songs[i].songName == null) continue;
						try
						{
							var n:String = Paths.formatToSongPath(songs[i].songName);
							var f:String = Highscore.formatSong(n, curDifficulty);
							if (Song.getChart(f, n) != null)
							{
								curSelected = i;
								changeSelection(0, false);
								break;
							}
						}
						catch(e:Dynamic) {}
					}
				}
			}

			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

			try
			{
				Song.loadFromJson(poop, songLowercase);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;

				trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
			}
			catch(e:haxe.Exception)
			{
				trace('ERROR! ${e.message}');

				var errorStr:String = e.message;
				if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
				else errorStr += '\n\n' + e.stack;

				missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;
				showingMissingPopup = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));

				updateTexts(elapsed);
				super.update(elapsed);
				return;
			}

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
			stopMusicPlay = true;

			destroyFreeplayVocals();
			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else if(controls.RESET && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		updateTexts(elapsed);
		super.update(elapsed);
	}
	
	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		if (Difficulty.list.length > 1)
			diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
		else
			diffText.text = displayDiff.toUpperCase();

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
		showingMissingPopup = false;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
		_updateSongLastDifficulty();
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var newColor:Int = songs[curSelected].color;
		if(newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpSongs.members)
		{
			if (item == null) continue;
			var icon:HealthIcon = (num < iconArray.length) ? iconArray[num] : null;
			item.alpha = 0.6;
			if (icon != null) icon.alpha = 0.6;
			if (item.targetY == curSelected)
			{
				item.alpha = 1;
				if (icon != null) icon.alpha = 1;
			}
		}

		// Switch selected song icons to their "losing" frame (right half of image)
		for (num => item in grpSongs.members)
		{
			if (item == null) continue;
			var icon2:HealthIcon = (num < iconArray.length) ? iconArray[num] : null;
			if (icon2 == null) continue;
			try
			{
				if (item.targetY == curSelected)
				{
					// frame index 1 = losing icon (right 150px); 0 = normal
					icon2.animation.frameIndex = 1;
				}
				else
				{
					icon2.animation.frameIndex = 0;
				}
			}
			catch(e:Dynamic){}
		}
		
		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		// If Random slot selected, use collected difficulties
		if (songs[curSelected] != null && Std.string(songs[curSelected].songName).toLowerCase() == 'random' && randomDifficulties != null && randomDifficulties.length > 0)
		{
			Difficulty.copyFrom(randomDifficulties);
		}
		else
		{
			Difficulty.loadFromWeek();
		}
		
		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if(savedDiff != null && !Difficulty.list.contains(savedDiff) && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if(lastDiff > -1)
			curDifficulty = lastDiff;
		else if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
	}

	inline private function _updateSongLastDifficulty()
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);

	private function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		for (i in _lastVisibles)
		{
			var gItem:Alphabet = (i < grpSongs.members.length) ? grpSongs.members[i] : null;
			if (gItem != null) gItem.visible = gItem.active = false;
			var oldIcon:HealthIcon = (i < iconArray.length) ? iconArray[i] : null;
			if (oldIcon != null) oldIcon.visible = oldIcon.active = false;
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			var item:Alphabet = grpSongs.members[i];
			item.visible = item.active = true;
			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

			var icon:HealthIcon = (i < iconArray.length) ? iconArray[i] : null;
			if (icon != null) icon.visible = icon.active = true;
			_lastVisibles.push(i);
		}
	}

	override function destroy():Void
	{
		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freeplayRandom'));
	}	
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}