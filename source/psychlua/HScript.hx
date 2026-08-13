package psychlua;

import flixel.FlxBasic;
import objects.Character;
import psychlua.LuaUtils;
import psychlua.CustomSubstate;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;

import haxe.ValueException;

typedef HScriptInfos = {
	> haxe.PosInfos,
	var ?funcName:String;
	var ?showLine:Null<Bool>;
	#if LUA_ALLOWED
	var ?isLua:Null<Bool>;
	#end
}

class HScript extends Iris
{
	public var filePath:String;
	public var modFolder:String;
	public var returnValue:Dynamic;

	#if LUA_ALLOWED
	public var parentLua:FunkinLua;
	public static function initHaxeModule(parent:FunkinLua)
	{
		if(parent.hscript == null)
		{
			trace('initializing haxe interp for: ${parent.scriptName}');
			parent.hscript = new HScript(parent);
		}
	}

	public static function initHaxeModuleCode(parent:FunkinLua, code:String, ?varsToBring:Any = null)
	{
		var hs:HScript = try parent.hscript catch (e) null;
		if(hs == null)
		{
			trace('initializing haxe interp for: ${parent.scriptName}');
			try {
				parent.hscript = new HScript(parent, code, varsToBring);
			}
			catch(e:IrisError) {
				var pos:HScriptInfos = cast {fileName: parent.scriptName, isLua: true};
				if(parent.lastCalledFunction != '') pos.funcName = parent.lastCalledFunction;
				Iris.error(Printer.errorToString(e, false), pos);
				parent.hscript = null;
			}
		}
		else
		{
			try
			{
				hs.scriptCode = code;
				hs.varsToBring = varsToBring;
				hs.parse(true);
				var ret:Dynamic = hs.execute();
				hs.returnValue = ret;
			}
			catch(e:IrisError)
			{
				var pos:HScriptInfos = cast hs.interp.posInfos();
				pos.isLua = true;
				if(parent.lastCalledFunction != '') pos.funcName = parent.lastCalledFunction;
				Iris.error(Printer.errorToString(e, false), pos);
				hs.returnValue = null;
			}
		}
	}
	#end

	public var origin:String;
	override public function new(?parent:Dynamic, ?file:String, ?varsToBring:Any = null, ?manualRun:Bool = false)
	{
		if (file == null)
			file = '';

		filePath = file;
		if (filePath != null && filePath.length > 0)
		{
			this.origin = filePath;
			#if MODS_ALLOWED
			var myFolder:Array<String> = filePath.split('/');
			if(myFolder[0] + '/' == Paths.mods() && (Mods.currentModDirectory == myFolder[1] || Mods.getGlobalMods().contains(myFolder[1]))) //is inside mods folder
				this.modFolder = myFolder[1];
			#end
		}
		var scriptThing:String = file;
		var scriptName:String = null;
		if(parent == null && file != null)
		{
			var f:String = file.replace('\\', '/');
			if(f.contains('/') && !f.contains('\n')) {
				scriptThing = File.getContent(f);
				scriptName = f;
			}
		}
		#if LUA_ALLOWED
		if (scriptName == null && parent != null)
			scriptName = parent.scriptName;
		#end
		super(scriptThing, new IrisConfig(scriptName, false, false));
		var customInterp:CustomInterp = new CustomInterp();
		customInterp.parentInstance = FlxG.state;
		customInterp.showPosOnLog = false;
		this.interp = customInterp;
		#if LUA_ALLOWED
		parentLua = parent;
		if (parent != null)
		{
			this.origin = parent.scriptName;
			this.modFolder = parent.modFolder;
		}
		#end
		preset();
		this.varsToBring = varsToBring;
		if (!manualRun) {
			try {
				var ret:Dynamic = execute();
				returnValue = ret;
			} catch(e:IrisError) {
				returnValue = null;
				this.destroy();
				throw e;
			}
		}
	}

	var varsToBring(default, set):Any = null;
	override function preset()
	{
		super.preset();

		// Some very commonly used classes
		set('Type', Type);
		#if sys
		set('File', File);
		set('FileSystem', FileSystem);
		#end
		set('FlxG', flixel.FlxG);
		set('FlxMath', flixel.math.FlxMath);
		set('FlxSprite', flixel.FlxSprite);
		set('FlxText', flixel.text.FlxText);
		set('FlxCamera', flixel.FlxCamera);
		set('PsychCamera', backend.PsychCamera);
		set('FlxTimer', flixel.util.FlxTimer);
		set('FlxTween', flixel.tweens.FlxTween);
		set('FlxEase', flixel.tweens.FlxEase);
		set('FlxColor', CustomFlxColor);
		set('Countdown', backend.BaseStage.Countdown);
		set('PlayState', PlayState);
		set('Screenshot', Screenshot);
		set('Paths', Paths);
		set('Conductor', Conductor);
		set('ClientPrefs', ClientPrefs);
		#if ACHIEVEMENTS_ALLOWED
		set('Achievements', Achievements);
		#end
		set('Character', Character);
		set('HealthIcon', objects.HealthIcon);
		set('Alphabet', Alphabet);
		set('Note', objects.Note);
		set('NoteSplash', objects.NoteSplash);
		set('CustomSubstate', CustomSubstate);
		#if (!flash && sys)
		set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		set('ErrorHandledRuntimeShader', shaders.ErrorHandledShader.ErrorHandledRuntimeShader);
		#end
		set('ShaderFilter', openfl.filters.ShaderFilter);
		set('StringTools', StringTools);
		#if flxanimate
		set('FlxAnimate', FlxAnimate);
		#end

        // New Additions from import.hx
		set('BlendMode', backend.MacroBridge.exposeAbstract('openfl.display.BlendMode'));
        set('Json', haxe.Json);
        set('Timer', haxe.Timer);
        set('FlxAngle', flixel.math.FlxAngle);
        set('FlxPoint', flixel.math.FlxBasePoint);
        set('FlxSpriteUtil', flixel.util.FlxSpriteUtil);
        set('Lambda', Lambda);

		// Functions & Variables
		set('setVar', function(name:String, value:Dynamic) {
			MusicBeatState.getVariables().set(name, value);
			return value;
		});
		set('getVar', function(name:String) {
			var result:Dynamic = null;
			if(MusicBeatState.getVariables().exists(name)) result = MusicBeatState.getVariables().get(name);
			return result;
		});
		set('removeVar', function(name:String)
		{
			if(MusicBeatState.getVariables().exists(name))
			{
				MusicBeatState.getVariables().remove(name);
				return true;
			}
			return false;
		});
		set('debugPrint', function(text:String, ?color:FlxColor = null) {
			if(color == null) color = FlxColor.WHITE;
			PlayState.instance.addTextToDebug(text, color);
		});
		set('getModSetting', function(saveTag:String, ?modName:String = null) {
			if(modName == null)
			{
				if(this.modFolder == null)
				{
					Iris.error('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', this.interp.posInfos());
					return null;
				}
				modName = this.modFolder;
			}
			return LuaUtils.getModSetting(saveTag, modName);
		});

		// Keyboard & Gamepads
		set('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		set('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		set('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		set('anyGamepadJustPressed', function(name:String) return FlxG.gamepads.anyJustPressed(name));
		set('anyGamepadPressed', function(name:String) FlxG.gamepads.anyPressed(name));
		set('anyGamepadReleased', function(name:String) return FlxG.gamepads.anyJustReleased(name));

		set('gamepadAnalogX', function(id:Int, ?leftStick:Bool = true)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadAnalogY', function(id:Int, ?leftStick:Bool = true)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadJustPressed', function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		set('gamepadPressed', function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.pressed, name) == true;
		});
		set('gamepadReleased', function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		set('keyJustPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_P;
				case 'down': return Controls.instance.NOTE_DOWN_P;
				case 'up': return Controls.instance.NOTE_UP_P;
				case 'right': return Controls.instance.NOTE_RIGHT_P;
				default: return Controls.instance.justPressed(name);
			}
			return false;
		});
		set('keyPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT;
				case 'down': return Controls.instance.NOTE_DOWN;
				case 'up': return Controls.instance.NOTE_UP;
				case 'right': return Controls.instance.NOTE_RIGHT;
				default: return Controls.instance.pressed(name);
			}
			return false;
		});
		set('keyReleased', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_R;
				case 'down': return Controls.instance.NOTE_DOWN_R;
				case 'up': return Controls.instance.NOTE_UP_R;
				case 'right': return Controls.instance.NOTE_RIGHT_R;
				default: return Controls.instance.justReleased(name);
			}
			return false;
		});

		// For adding your own callbacks
		// not very tested but should work
		#if LUA_ALLOWED
		set('createGlobalCallback', function(name:String, func:Dynamic)
		{
			for (script in PlayState.instance.luaArray)
				if(script != null && script.lua != null && !script.closed)
					Lua_helper.add_callback(script.lua, name, func);

			FunkinLua.customFunctions.set(name, func);
		});

		// this one was tested
		set('createCallback', function(name:String, func:Dynamic, ?funk:FunkinLua = null)
		{
			if(funk == null) funk = parentLua;
			
			if(funk != null) funk.addLocalCallback(name, func);
			else Iris.error('createCallback ($name): 3rd argument is null', this.interp.posInfos());
		});
		#end

		set('addHaxeLibrary', function(libName:String, ?libPackage:String = '') {
			try {
				var str:String = '';
				if(libPackage.length > 0)
					str = libPackage + '.';

				set(libName, Type.resolveClass(str + libName));
			}
			catch (e:IrisError) {
				Iris.error(Printer.errorToString(e, false), this.interp.posInfos());
			}
		});
		#if LUA_ALLOWED
		set('parentLua', parentLua);
		#else
		set('parentLua', null);
		#end
		set('this', this);
		set('game', FlxG.state);
		set('controls', Controls.instance);

		set('buildTarget', LuaUtils.getBuildTarget());
		set('customSubstate', CustomSubstate.instance);
		set('customSubstateName', CustomSubstate.name);

		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('Function_StopLua', LuaUtils.Function_StopLua); //doesnt do much cuz HScript has a lower priority than Lua
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
	}

	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua) {
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			initHaxeModuleCode(funk, codeToRun, varsToBring);
			if (funk.hscript != null)
			{
				final retVal:IrisCall = funk.hscript.call(funcToRun, funcArgs);
				if (retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
				else if (funk.hscript.returnValue != null)
				{
					return funk.hscript.returnValue;
				}
			}
			return null;
		});
		
		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			if (funk.hscript != null)
			{
				final retVal:IrisCall = funk.hscript.call(funcToRun, funcArgs);
				if (retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
			}
			else
			{
				var pos:HScriptInfos = cast {fileName: funk.scriptName, showLine: false};
				if (funk.lastCalledFunction != '') pos.funcName = funk.lastCalledFunction;
				Iris.error("runHaxeFunction: HScript has not been initialized yet! Use \"runHaxeCode\" to initialize it", pos);
			}
			return null;
		});
		// This function is unnecessary because import already exists in HScript as a native feature
		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			var str:String = '';
			if (libPackage.length > 0)
				str = libPackage + '.';
			else if (libName == null)
				libName = '';

			var c:Dynamic = Type.resolveClass(str + libName);
			if (c == null)
				c = Type.resolveEnum(str + libName);

			if (funk.hscript == null)
				initHaxeModule(funk);

			var pos:HScriptInfos = cast funk.hscript.interp.posInfos();
			pos.showLine = false;
			if (funk.lastCalledFunction != '')
				 pos.funcName = funk.lastCalledFunction;

			try {
				if (c != null)
					funk.hscript.set(libName, c);
			}
			catch (e:IrisError) {
				Iris.error(Printer.errorToString(e, false), pos);
			}
			FunkinLua.lastCalledScript = funk;
			if (FunkinLua.getBool('luaDebugMode') && FunkinLua.getBool('luaDeprecatedWarnings'))
				Iris.warn("addHaxeLibrary is deprecated! Import classes through \"import\" in HScript!", pos);
		});
	}
	#end

	override function call(funcToRun:String, ?args:Array<Dynamic>):IrisCall {
		if (funcToRun == null || interp == null) return null;

		if (!exists(funcToRun)) {
			Iris.error('No function named: $funcToRun', this.interp.posInfos());
			return null;
		}

		try {
			var func:Dynamic = interp.variables.get(funcToRun); // function signature
			final ret = Reflect.callMethod(null, func, args ?? []);
			return {funName: funcToRun, signature: func, returnValue: ret};
		}
		catch(e:IrisError) {
			var pos:HScriptInfos = cast this.interp.posInfos();
			pos.funcName = funcToRun;
			#if LUA_ALLOWED
			if (parentLua != null)
			{
				pos.isLua = true;
				if (parentLua.lastCalledFunction != '') pos.funcName = parentLua.lastCalledFunction;
			}
			#end
			Iris.error(Printer.errorToString(e, false), pos);
		}
		catch (e:ValueException) {
			var pos:HScriptInfos = cast this.interp.posInfos();
			pos.funcName = funcToRun;
			#if LUA_ALLOWED
			if (parentLua != null)
			{
				pos.isLua = true;
				if (parentLua.lastCalledFunction != '') pos.funcName = parentLua.lastCalledFunction;
			}
			#end
			Iris.error('$e', pos);
		}
		return null;
	}

	override public function destroy()
	{
		origin = null;
		#if LUA_ALLOWED parentLua = null; #end
		super.destroy();
	}

	function set_varsToBring(values:Any) {
		if (varsToBring != null)
			for (key in Reflect.fields(varsToBring))
				if (exists(key.trim()))
					interp.variables.remove(key.trim());

		if (values != null)
		{
			for (key in Reflect.fields(values))
			{
				key = key.trim();
				set(key, Reflect.field(values, key));
			}
		}

		return varsToBring = values;
	}
}

class CustomFlxColor
{
	public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
	public static var BLACK(default, null):Int = FlxColor.BLACK;
	public static var WHITE(default, null):Int = FlxColor.WHITE;
	public static var GRAY(default, null):Int = FlxColor.GRAY;

	public static var GREEN(default, null):Int = FlxColor.GREEN;
	public static var LIME(default, null):Int = FlxColor.LIME;
	public static var YELLOW(default, null):Int = FlxColor.YELLOW;
	public static var ORANGE(default, null):Int = FlxColor.ORANGE;
	public static var RED(default, null):Int = FlxColor.RED;
	public static var PURPLE(default, null):Int = FlxColor.PURPLE;
	public static var BLUE(default, null):Int = FlxColor.BLUE;
	public static var BROWN(default, null):Int = FlxColor.BROWN;
	public static var PINK(default, null):Int = FlxColor.PINK;
	public static var MAGENTA(default, null):Int = FlxColor.MAGENTA;
	public static var CYAN(default, null):Int = FlxColor.CYAN;

	// Adding EVERY official standardized CSS color name that is not already present in HaxeFlixel's list.
	// I edited my flixel haxelib in order to add these. Unless you do the same, this won't work if you simply build the game. Add them in manually. FlxColor.hx is the name of the file.
	public static var ALICEBLUE(default, null):Int = FlxColor.ALICEBLUE;
	public static var ANTIQUEWHITE(default, null):Int = FlxColor.ANTIQUEWHITE;
	public static var AQUA(default, null):Int = FlxColor.AQUA;
	public static var AQUAMARINE(default, null):Int = FlxColor.AQUAMARINE;
	public static var AZURE(default, null):Int = FlxColor.AZURE;
	public static var BEIGE(default, null):Int = FlxColor.BEIGE;
	public static var BISQUE(default, null):Int = FlxColor.BISQUE;
	public static var BLANCHEDALMOND(default, null):Int = FlxColor.BLANCHEDALMOND;
	public static var BLUEVIOLET(default, null):Int = FlxColor.BLUEVIOLET;
	public static var BURLYWOOD(default, null):Int = FlxColor.BURLYWOOD;
	public static var CADETBLUE(default, null):Int = FlxColor.CADETBLUE;
	public static var CHARTREUSE(default, null):Int = FlxColor.CHARTREUSE;
	public static var CHOCOLATE(default, null):Int = FlxColor.CHOCOLATE;
	public static var CORAL(default, null):Int = FlxColor.CORAL;
	public static var CORNFLOWERBLUE(default, null):Int = FlxColor.CORNFLOWERBLUE;
	public static var CORNSILK(default, null):Int = FlxColor.CORNSILK;
	public static var CRIMSON(default, null):Int = FlxColor.CRIMSON;
	public static var DARKBLUE(default, null):Int = FlxColor.DARKBLUE;
	public static var DARKCYAN(default, null):Int = FlxColor.DARKCYAN;
	public static var DARKGOLDENROD(default, null):Int = FlxColor.DARKGOLDENROD;
	public static var DARKGRAY(default, null):Int = FlxColor.DARKGRAY;
	public static var DARKGREY(default, null):Int = FlxColor.DARKGREY;
	public static var DARKGREEN(default, null):Int = FlxColor.DARKGREEN;
	public static var DARKKHAKI(default, null):Int = FlxColor.DARKKHAKI;
	public static var DARKMAGENTA(default, null):Int = FlxColor.DARKMAGENTA;
	public static var DARKOLIVEGREEN(default, null):Int = FlxColor.DARKOLIVEGREEN;
	public static var DARKORANGE(default, null):Int = FlxColor.DARKORANGE;
	public static var DARKORCHID(default, null):Int = FlxColor.DARKORCHID;
	public static var DARKRED(default, null):Int = FlxColor.DARKRED;
	public static var DARKSALMON(default, null):Int = FlxColor.DARKSALMON;
	public static var DARKSEAGREEN(default, null):Int = FlxColor.DARKSEAGREEN;
	public static var DARKSLATEBLUE(default, null):Int = FlxColor.DARKSLATEBLUE;
	public static var DARKSLATEGRAY(default, null):Int = FlxColor.DARKSLATEGRAY;
	public static var DARKSLATEGREY(default, null):Int = FlxColor.DARKSLATEGREY;
	public static var DARKTURQUOISE(default, null):Int = FlxColor.DARKTURQUOISE;
	public static var DARKVIOLET(default, null):Int = FlxColor.DARKVIOLET;
	public static var DEEPPINK(default, null):Int = FlxColor.DEEPPINK;
	public static var DEEPSKYBLUE(default, null):Int = FlxColor.DEEPSKYBLUE;
	public static var DIMGRAY(default, null):Int = FlxColor.DIMGRAY;
	public static var DIMGREY(default, null):Int = FlxColor.DIMGREY;
	public static var DODGERBLUE(default, null):Int = FlxColor.DODGERBLUE;
	public static var FIREBRICK(default, null):Int = FlxColor.FIREBRICK;
	public static var FLORALWHITE(default, null):Int = FlxColor.FLORALWHITE;
	public static var FORESTGREEN(default, null):Int = FlxColor.FORESTGREEN;
	public static var FUCHSIA(default, null):Int = FlxColor.FUCHSIA;
	public static var GAINSBORO(default, null):Int = FlxColor.GAINSBORO;
	public static var GHOSTWHITE(default, null):Int = FlxColor.GHOSTWHITE;
	public static var GOLD(default, null):Int = FlxColor.GOLD;
	public static var GOLDENROD(default, null):Int = FlxColor.GOLDENROD;
	public static var GREENYELLOW(default, null):Int = FlxColor.GREENYELLOW;
	public static var GREY(default, null):Int = FlxColor.GREY;
	public static var HONEYDEW(default, null):Int = FlxColor.HONEYDEW;
	public static var HOTPINK(default, null):Int = FlxColor.HOTPINK;
	public static var INDIANRED(default, null):Int = FlxColor.INDIANRED;
	public static var INDIGO(default, null):Int = FlxColor.INDIGO;
	public static var IVORY(default, null):Int = FlxColor.IVORY;
	public static var KHAKI(default, null):Int = FlxColor.KHAKI;
	public static var LAVENDER(default, null):Int = FlxColor.LAVENDER;
	public static var LAVENDERBLUSH(default, null):Int = FlxColor.LAVENDERBLUSH;
	public static var LAWNGREEN(default, null):Int = FlxColor.LAWNGREEN;
	public static var LEMONCHIFFON(default, null):Int = FlxColor.LEMONCHIFFON;
	public static var LIGHTBLUE(default, null):Int = FlxColor.LIGHTBLUE;
	public static var LIGHTCORAL(default, null):Int = FlxColor.LIGHTCORAL;
	public static var LIGHTCYAN(default, null):Int = FlxColor.LIGHTCYAN;
	public static var LIGHTGOLDENRODYELLOW(default, null):Int = FlxColor.LIGHTGOLDENRODYELLOW;
	public static var LIGHTGRAY(default, null):Int = FlxColor.LIGHTGRAY;
	public static var LIGHTGREY(default, null):Int = FlxColor.LIGHTGREY;
	public static var LIGHTGREEN(default, null):Int = FlxColor.LIGHTGREEN;
	public static var LIGHTPINK(default, null):Int = FlxColor.LIGHTPINK;
	public static var LIGHTSALMON(default, null):Int = FlxColor.LIGHTSALMON;
	public static var LIGHTSEAGREEN(default, null):Int = FlxColor.LIGHTSEAGREEN;
	public static var LIGHTSKYBLUE(default, null):Int = FlxColor.LIGHTSKYBLUE;
	public static var LIGHTSLATEGRAY(default, null):Int = FlxColor.LIGHTSLATEGRAY;
	public static var LIGHTSLATEGREY(default, null):Int = FlxColor.LIGHTSLATEGREY;
	public static var LIGHTSTEELBLUE(default, null):Int = FlxColor.LIGHTSTEELBLUE;
	public static var LIGHTYELLOW(default, null):Int = FlxColor.LIGHTYELLOW;
	public static var LIMEGREEN(default, null):Int = FlxColor.LIMEGREEN;
	public static var LINEN(default, null):Int = FlxColor.LINEN;
	public static var MEDIUMAQUAMARINE(default, null):Int = FlxColor.MEDIUMAQUAMARINE;
	public static var MEDIUMBLUE(default, null):Int = FlxColor.MEDIUMBLUE;
	public static var MEDIUMORCHID(default, null):Int = FlxColor.MEDIUMORCHID;
	public static var MEDIUMPURPLE(default, null):Int = FlxColor.MEDIUMPURPLE;
	public static var MEDIUMSEAGREEN(default, null):Int = FlxColor.MEDIUMSEAGREEN;
	public static var MEDIUMSLATEBLUE(default, null):Int = FlxColor.MEDIUMSLATEBLUE;
	public static var MEDIUMSPRINGGREEN(default, null):Int = FlxColor.MEDIUMSPRINGGREEN;
	public static var MEDIUMTURQUOISE(default, null):Int = FlxColor.MEDIUMTURQUOISE;
	public static var MEDIUMVIOLETRED(default, null):Int = FlxColor.MEDIUMVIOLETRED;
	public static var MIDNIGHTBLUE(default, null):Int = FlxColor.MIDNIGHTBLUE;
	public static var MINTCREAM(default, null):Int = FlxColor.MINTCREAM;
	public static var MISTYROSE(default, null):Int = FlxColor.MISTYROSE;
	public static var MOCCASIN(default, null):Int = FlxColor.MOCCASIN;
	public static var NAVAJOWHITE(default, null):Int = FlxColor.NAVAJOWHITE;
	public static var OLDLACE(default, null):Int = FlxColor.OLDLACE;
	public static var OLIVEDRAB(default, null):Int = FlxColor.OLIVEDRAB;
	public static var ORANGERED(default, null):Int = FlxColor.ORANGERED;
	public static var ORCHID(default, null):Int = FlxColor.ORCHID;
	public static var PALEGOLDENROD(default, null):Int = FlxColor.PALEGOLDENROD;
	public static var PALEGREEN(default, null):Int = FlxColor.PALEGREEN;
	public static var PALETURQUOISE(default, null):Int = FlxColor.PALETURQUOISE;
	public static var PALEVIOLETRED(default, null):Int = FlxColor.PALEVIOLETRED;
	public static var PAPAYAWHIP(default, null):Int = FlxColor.PAPAYAWHIP;
	public static var PEACHPUFF(default, null):Int = FlxColor.PEACHPUFF;
	public static var PERU(default, null):Int = FlxColor.PERU;
	public static var POWDERBLUE(default, null):Int = FlxColor.POWDERBLUE;
	public static var REBECCAPURPLE(default, null):Int = FlxColor.REBECCAPURPLE;
	public static var ROSYBROWN(default, null):Int = FlxColor.ROSYBROWN;
	public static var ROYALBLUE(default, null):Int = FlxColor.ROYALBLUE;
	public static var SADDLEBROWN(default, null):Int = FlxColor.SADDLEBROWN;
	public static var SANDYBROWN(default, null):Int = FlxColor.SANDYBROWN;
	public static var SEAGREEN(default, null):Int = FlxColor.SEAGREEN;
	public static var SEASHELL(default, null):Int = FlxColor.SEASHELL;
	public static var SIENNA(default, null):Int = FlxColor.SIENNA;
	public static var SILVER(default, null):Int = FlxColor.SILVER;
	public static var SKYBLUE(default, null):Int = FlxColor.SKYBLUE;
	public static var SLATEBLUE(default, null):Int = FlxColor.SLATEBLUE;
	public static var SLATEGRAY(default, null):Int = FlxColor.SLATEGRAY;
	public static var SLATEGREY(default, null):Int = FlxColor.SLATEGREY;
	public static var SNOW(default, null):Int = FlxColor.SNOW;
	public static var SPRINGGREEN(default, null):Int = FlxColor.SPRINGGREEN;
	public static var STEELBLUE(default, null):Int = FlxColor.STEELBLUE;
	public static var TAN(default, null):Int = FlxColor.TAN;
	public static var THISTLE(default, null):Int = FlxColor.THISTLE;
	public static var TOMATO(default, null):Int = FlxColor.TOMATO;
	public static var TURQUOISE(default, null):Int = FlxColor.TURQUOISE;
	public static var VIOLET(default, null):Int = FlxColor.VIOLET;
	public static var WHEAT(default, null):Int = FlxColor.WHEAT;
	public static var WHITESMOKE(default, null):Int = FlxColor.WHITESMOKE;
	public static var YELLOWGREEN(default, null):Int = FlxColor.YELLOWGREEN;

	public static function fromInt(Value:Int):Int 
		return cast FlxColor.fromInt(Value);

	public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int = 255):Int
		return cast FlxColor.fromRGB(Red, Green, Blue, Alpha);

	public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromRGBFloat(Red, Green, Blue, Alpha);

	public static inline function fromCMYK(Cyan:Float, Magenta:Float, Yellow:Float, Black:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromCMYK(Cyan, Magenta, Yellow, Black, Alpha);

	public static function fromHSB(Hue:Float, Sat:Float, Brt:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSB(Hue, Sat, Brt, Alpha);

	public static function fromHSL(Hue:Float, Sat:Float, Light:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSL(Hue, Sat, Light, Alpha);

	public static function fromString(str:String):Int
		return cast FlxColor.fromString(str);
}

class CustomInterp extends crowplexus.hscript.Interp
{
	public var parentInstance(default, set):Dynamic = [];
	private var _instanceFields:Array<String>;
	function set_parentInstance(inst:Dynamic):Dynamic
	{
		parentInstance = inst;
		if(parentInstance == null)
		{
			_instanceFields = [];
			return inst;
		}
		_instanceFields = Type.getInstanceFields(Type.getClass(inst));
		return inst;
	}

	public function new()
	{
		super();
	}

	override function fcall(o:Dynamic, funcToRun:String, args:Array<Dynamic>):Dynamic {
		for (_using in usings) {
			var v = _using.call(o, funcToRun, args);
			if (v != null)
				return v;
		}

		var f = get(o, funcToRun);

		if (f == null) {
			Iris.error('Tried to call null function $funcToRun', posInfos());
			return null;
		}

		return Reflect.callMethod(o, f, args);
	}

	override function resolve(id: String): Dynamic {
		if (locals.exists(id)) {
			var l = locals.get(id);
			return l.r;
		}

		if (variables.exists(id)) {
			var v = variables.get(id);
			return v;
		}

		if (imports.exists(id)) {
			var v = imports.get(id);
			return v;
		}

		if(parentInstance != null && _instanceFields.contains(id)) {
			var v = Reflect.getProperty(parentInstance, id);
			return v;
		}

		error(EUnknownVariable(id));

		return null;
	}
}
#else
class HScript
{
	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua) {
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			PlayState.instance.addTextToDebug('HScript is not supported on this platform!', FlxColor.RED);
			return null;
		});
		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			PlayState.instance.addTextToDebug('HScript is not supported on this platform!', FlxColor.RED);
			return null;
		});
		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			PlayState.instance.addTextToDebug('HScript is not supported on this platform!', FlxColor.RED);
			return null;
		});
	}
	#end
}
#end
