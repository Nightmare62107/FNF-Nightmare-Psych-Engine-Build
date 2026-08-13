#if !macro
//Discord API
#if DISCORD_ALLOWED
import backend.Discord;
#end

//Psych
#if LUA_ALLOWED
import llua.*;
import llua.Lua;
#end

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end

#if sys
import sys.*;
import sys.io.*;
#elseif js
import js.html.*;
#end

import debug.FPSCounter;

import backend.Paths;
import backend.Controls;
import backend.CoolUtil;
import backend.HelperFunctions;
import backend.MusicBeatState;
import backend.MusicBeatSubstate;
import backend.CustomFadeTransition;
import backend.ClientPrefs;
import backend.Conductor;
import backend.BaseStage;
import backend.Difficulty;
import backend.Mods;
import backend.Language;
import backend.Screenshot;
import backend.PsychCamera;
import backend.Song;
import backend.StageData;
import backend.WeekData;
import backend.Highscore;
import backend.Rating;
import backend.Native;

import backend.ui.*; //Psych-UI

import objects.Alphabet;
import objects.BGSprite;

import states.PlayState;
import states.LoadingState;
import states.CacheState;
import states.TitleState;
#if BALDIS_BASICS_IN_FUNKIN_FILES
import states.CreeperScreenState;
#end
import states.MainMenuState;
import states.InitState;

#if flxanimate
import flxanimate.*;
import flxanimate.PsychFlxAnimate as FlxAnimate;
#end

import animation.*;
import psychlua.*;
import shaders.*;

import openfl.display.BlendMode;
import haxe.Json;
import haxe.Timer;

//Flixel
import flixel.sound.FlxSound;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxAngle;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.transition.FlxTransitionableState;

using StringTools;
using flixel.util.FlxSpriteUtil;
using Lambda;
#end
