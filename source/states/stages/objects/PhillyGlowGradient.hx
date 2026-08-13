package states.stages.objects;

import states.PlayState;

class PhillyGlowGradient extends FlxSprite
{
	public var originalY:Float;
	public var originalHeight:Int = 400;
	public var intendedAlpha:Float = 1;
	public function new(x:Float, y:Float)
	{
		super(x, y);
		originalY = y;

		var currentStage:String = PlayState.SONG != null ? PlayState.SONG.stage : null;
		switch(currentStage)
		{
			case 'philly': loadGraphic(Paths.image('philly/gradient')); //This shit was refusing to properly load FlxGradient so fuck it
			case 'limo': loadGraphic(Paths.image('limo/gradient'));
			default: loadGraphic(Paths.image('philly/gradient'));
		}
		
		scrollFactor.set(0, 0.75);
		setGraphicSize(2000, originalHeight);
		updateHitbox();
		antialiasing = ClientPrefs.data.antialiasing;
	}

	override function update(elapsed:Float)
	{
		var newHeight:Int = Math.round(height - 1000 * elapsed);
		if(newHeight > 0)
		{
			alpha = intendedAlpha;
			setGraphicSize(2000, newHeight);
			updateHitbox();
			y = originalY + (originalHeight - height);
		}
		else
		{
			alpha = 0;
			y = -5000;
		}

		super.update(elapsed);
	}

	public function bop()
	{
		setGraphicSize(2000, originalHeight);
		updateHitbox();
		y = originalY;
		alpha = intendedAlpha;
	}
}
