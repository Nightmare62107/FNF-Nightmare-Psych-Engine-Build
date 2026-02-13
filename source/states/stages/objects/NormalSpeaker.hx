package states.stages.objects;

import objects.Character;
import backend.Conductor;

class NormalSpeaker extends FlxSpriteGroup
{
	public var speaker:Character;
	public var danceEveryNumBeats:Int = 1;
	private var beatCounter:Int = 0;

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);
		
		speaker = new Character(0, 0, 'speakers');
		speaker.visible = true;
		add(speaker);
	}

	public function beatHit()
	{
		beatCounter++;
		if (beatCounter % danceEveryNumBeats == 0)
		{
			speaker.dance();
		}
	}
}
