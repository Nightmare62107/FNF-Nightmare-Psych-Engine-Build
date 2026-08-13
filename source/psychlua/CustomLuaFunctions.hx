package psychlua;

import flixel.FlxG;
import flixel.FlxSprite;
import psychlua.FunkinLua;
import psychlua.LuaUtils;
import states.PlayState;
import backend.ClientPrefs;

class CustomLuaFunctions 
{
    public static function implement(funk:FunkinLua) 
    {
        // Extract the explicit raw Lua State pointer matching ExtraFunctions.hx
        var lua = funk.lua;
        var game = PlayState.instance;
        if (game == null) return;

        // 1. isModifierActive(modifierName)
        Lua_helper.add_callback(lua, "isModifierActive", function(modifier:String):Bool {
            modifier = modifier.toLowerCase().trim();
            switch (modifier) {
                case 'botplay': return game.cpuControlled;
                case 'practice' | 'practicemode': return game.practiceMode;
                case 'ghosttapping': return ClientPrefs.data.ghostTapping;
                case 'downscroll': return ClientPrefs.data.downScroll;
                case 'middlescroll': return ClientPrefs.data.middleScroll;
                case 'instakillonmiss' | 'instakill': return game.instakillOnMiss;
                case 'randomizenotes': return game.randomizeNotes;
                case 'maxmisses': return game.maxMisses;
                case 'healthdrain': return game.healthDrain;
                case 'skipcountdown': return game.skipCountdown;
                case 'healthgain' | 'healthgainmult': return (game.healthGain != 1.0);
                case 'healthloss' | 'healthlossmult': return (game.healthLoss != 1.0);
                case 'speed' | 'rate' | 'playbackrate': return (game.playbackRate != 1.0);
                #if VS_SONIC_EXE_FILES
                case 'ringsystem': return game.ringSystem;
                #end
                #if MARIOS_MADNESS_FILES
                case 'sm64lifemeter': return game.sm64LifeMeterSystem;
                case 'sm64lifemetercoinspawning': return game.sm64LifeMeterCoinSpawning;
                #end
                default: return false;
            }
        });

        // 2. getPlayerAccuracyRange(min, max)
        Lua_helper.add_callback(lua, "getPlayerAccuracyRange", function(min:Float, max:Float):Bool {
            // Use a try-catch to guarantee it can never crash the script loop
            try {
                // If the game just started or ratingPercent is NaN, default to 0.0
                var currentPercent:Float = game.ratingPercent;
                if (Math.isNaN(currentPercent)) currentPercent = 0.0;

                var currentAccuracy:Float = currentPercent * 100.0;
                return (currentAccuracy >= min && currentAccuracy <= max);
            } 
            catch(e:Dynamic) {
                return false;
            }
        });

        // --- EXTRA CUSTOM LAYER CONTROLS (NATIVE OVERRIDE FIX) ---

        // Local helper to safely position a sprite behind or in front of an anchor group object
        function setRelativeLayer(spriteTag:String, anchorGroup:Dynamic, before:Bool) {
            var sprite = MusicBeatState.getVariables().get(spriteTag);
            if (sprite == null || anchorGroup == null) return;

            // Make sure the sprite is added to the active stage layer pool first
            if (!game.members.contains(sprite)) {
                game.add(sprite);
            }

            // Find the master layer index where the character group container is rendered
            var anchorIndex:Int = game.members.indexOf(anchorGroup);
            if (anchorIndex != -1) {
                // If before is true, drop it in front (index + 1), otherwise drop it behind (index)
                var targetIndex:Int = before ? (anchorIndex + 1) : anchorIndex;
                
                // Remove and re-insert directly into the game's master layout sorting array
                game.remove(sprite, true);
                game.insert(targetIndex, sprite);
            }
        }

        // 1. addBefore(tag, anchorTag)
        Lua_helper.add_callback(lua, "addBefore", function(tag:String, anchorTag:String) {
            var anchor = MusicBeatState.getVariables().get(anchorTag);
            setRelativeLayer(tag, anchor, true);
        });

        // 2. addBehind(tag, anchorTag)
        Lua_helper.add_callback(lua, "addBehind", function(tag:String, anchorTag:String) {
            var anchor = MusicBeatState.getVariables().get(anchorTag);
            setRelativeLayer(tag, anchor, false);
        });

        // 3. Character-Specific Layering Additions (Targeting the Group Containers directly)
        Lua_helper.add_callback(lua, "addBeforeBF", function(tag:String) {
            var targetGroup:Dynamic = (game.boyfriendGroup != null) ? game.boyfriendGroup : game.boyfriend;
            setRelativeLayer(tag, targetGroup, true);
        });

        Lua_helper.add_callback(lua, "addBehindBF", function(tag:String) {
            var targetGroup:Dynamic = (game.boyfriendGroup != null) ? game.boyfriendGroup : game.boyfriend;
            setRelativeLayer(tag, targetGroup, false);
        });

        Lua_helper.add_callback(lua, "addBeforeDad", function(tag:String) {
            var targetGroup:Dynamic = (game.dadGroup != null) ? game.dadGroup : game.dad;
            setRelativeLayer(tag, targetGroup, true);
        });

        Lua_helper.add_callback(lua, "addBehindDad", function(tag:String) {
            var targetGroup:Dynamic = (game.dadGroup != null) ? game.dadGroup : game.dad;
            setRelativeLayer(tag, targetGroup, false);
        });

        Lua_helper.add_callback(lua, "addBeforeGF", function(tag:String) {
            var targetGroup:Dynamic = (game.gfGroup != null) ? game.gfGroup : game.gf;
            setRelativeLayer(tag, targetGroup, true);
        });

        Lua_helper.add_callback(lua, "addBehindGF", function(tag:String) {
            var targetGroup:Dynamic = (game.gfGroup != null) ? game.gfGroup : game.gf;
            setRelativeLayer(tag, targetGroup, false);
        });

        // --- UNIVERSAL VECTOR DRAWING ENGINE ---
        // drawShape(tag, shapeType, width, height, colorHex, ?extraParam)
        Lua_helper.add_callback(lua, "drawShape", function(tag:String, shapeType:String, width:Int, height:Int, colorHex:String, ?extraParam:Float) {
            var sprite = MusicBeatState.getVariables().get(tag);
            if (sprite == null) return;

            // 1. Initialize a perfectly transparent background canvas sheet
            sprite.makeGraphic(width, height, flixel.util.FlxColor.TRANSPARENT, true);

            // 2. Parse the hex color string safely
            var color:flixel.util.FlxColor = flixel.util.FlxColor.fromString(colorHex);

            // 3. Setup structural boundaries (Flixel 6 passes colors directly, lineStyle is passed as a Null object)
            shapeType = shapeType.toLowerCase().trim();
            switch (shapeType)
            {
                case 'rectangle' | 'box' | 'square':
                    flixel.util.FlxSpriteUtil.drawRect(sprite, 0, 0, width, height, color, null);

                case 'circle':
                    var radius:Float = (extraParam != null && extraParam > 0) ? extraParam : (Math.min(width, height) / 2);
                    flixel.util.FlxSpriteUtil.drawCircle(sprite, width / 2, height / 2, radius, color, null);

                case 'ellipse' | 'oval':
                    flixel.util.FlxSpriteUtil.drawEllipse(sprite, 0, 0, width, height, color, null);

                case 'triangle':
                    // Uses flixel.math.FlxPoint pools to satisfy Flixel 6's strict macro data types
                    var vertices:Array<flixel.math.FlxPoint> = [
                        flixel.math.FlxPoint.get(width / 2, 0),         // Top point
                        flixel.math.FlxPoint.get(width, height),        // Bottom right
                        flixel.math.FlxPoint.get(0, height)             // Bottom left
                    ];
                    flixel.util.FlxSpriteUtil.drawPolygon(sprite, vertices, color, null);
                    
                    // Clear the points out of active CPU stack memory to prevent leaks
                    for (point in vertices) point.put();

                case 'line':
                    var thickness:Float = (extraParam != null && extraParam > 0) ? extraParam : 4.0;
                    var pathLine:flixel.util.FlxSpriteUtil.LineStyle = {thickness: thickness, color: color};
                    flixel.util.FlxSpriteUtil.drawLine(sprite, 0, 0, width, height, pathLine);
            }
            
            // Refreshes internal rendering frames to make the lines update live
            sprite.resetFrame();
        });
    }
}
