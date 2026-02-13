package states;

import flixel.FlxG;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;

class InitState extends MusicBeatState
{
    public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
    public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
    public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];
   
    override public function create():Void
    {

        super.create();
        
        ClientPrefs.loadPrefs();
		Language.reloadPhrases();

        // Immediately switch to CacheState
        FlxG.switchState(new CacheState());

        // This is the state that opens when the game is launched.
        // Opens ClientPrefs before anything else (I did this for color filters).
    }
}
