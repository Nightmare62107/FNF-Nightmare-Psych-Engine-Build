package states.stages;

import states.stages.objects.*;
import objects.Character;

enum HenchmenKillState
{
	WAIT;
	KILLING;
	SPEEDING_OFFSCREEN;
	SPEEDING;
	STOPPING;
}

class Limo extends BaseStage
{
	var phillyLightsColors:Array<FlxColor>;
	var curLight:Int = -1;

	//For Philly Glow events
	var blammedLightsBlack:FlxSprite;
	var phillyGlowGradient:PhillyGlowGradient;
	var phillyGlowParticles:FlxTypedGroup<PhillyGlowParticle>;
	var phillyWindowEvent:BGSprite;
	var curLightEvent:Int = -1;
	var phillyGlowPending:Bool = false;

	var grpLimoDancers:FlxTypedGroup<BackgroundDancer>;
	var fastCar:BGSprite;
	var fastCarCanDrive:Bool = true;

	// event
	var limoKillingState:HenchmenKillState = WAIT;
	var limoMetalPole:BGSprite;
	var limoLight:BGSprite;
	var limoCorpse:BGSprite;
	var limoCorpseTwo:BGSprite;
	var bgLimo:BGSprite;
	var limo:BGSprite;
	var grpLimoParticles:FlxTypedGroup<BGSprite>;
	var dancersDiff:Float = 320;

	override function create()
	{
		var skyBG:BGSprite = new BGSprite('limo/limoSunset', -120, -50, 0.1, 0.1);
		add(skyBG);

		phillyLightsColors = [0xFF31A2FD, 0xFF31FD8C, 0xFFFB33F5, 0xFFFD4531, 0xFFFBA633];

		if (!ClientPrefs.data.lowQuality)
		{
			limoMetalPole = new BGSprite('gore/metalPole', -500, 220, 0.4, 0.4);
			add(limoMetalPole);

			bgLimo = new BGSprite('limo/bgLimo', -150, 480, 0.4, 0.4, ['background limo pink'], true);
			add(bgLimo);

			limoCorpse = new BGSprite('gore/noooooo', -500, limoMetalPole.y - 130, 0.4, 0.4, ['Henchmen on rail'], true);
			add(limoCorpse);

			limoCorpseTwo = new BGSprite('gore/noooooo', -500, limoMetalPole.y, 0.4, 0.4, ['henchmen death'], true);
			add(limoCorpseTwo);

			grpLimoDancers = new FlxTypedGroup<BackgroundDancer>();
			add(grpLimoDancers);

			for (i in 0...5)
			{
				var dancer:BackgroundDancer = new BackgroundDancer((370 * i) + dancersDiff + bgLimo.x, bgLimo.y - 400);
				dancer.scrollFactor.set(0.4, 0.4);
				grpLimoDancers.add(dancer);
			}

			limoLight = new BGSprite('gore/coldHeartKiller', limoMetalPole.x - 180, limoMetalPole.y - 80, 0.4, 0.4);
			add(limoLight);

			grpLimoParticles = new FlxTypedGroup<BGSprite>();
			add(grpLimoParticles);

			//PRECACHE BLOOD
			var particle:BGSprite = new BGSprite('gore/stupidBlood', -400, -400, 0.4, 0.4, ['blood'], false);
			particle.alpha = 0.01;
			grpLimoParticles.add(particle);
			resetLimoKill();

			//PRECACHE SOUND
			Paths.sound('dancerdeath');
			setDefaultGF('gf-car');
		}

		fastCar = new BGSprite('limo/fastCarLol', -300, 160);
		fastCar.active = true;
	}
	
	override function createPost()
	{
		resetFastCar();
		addBehindGF(fastCar);

		limo = new BGSprite('limo/limoDrive', -120, 550, 1, 1, ['Limo stage'], true);
		addBeforeGF(limo); // Shitty layering but whatev it works LOL
		if (phillyGlowPending)
		{
			phillyGlowPending = false;
			setupPhillyGlow();
		}
	}

	var limoSpeed:Float = 0;
	override function update(elapsed:Float)
	{
		if (phillyGlowParticles != null)
		{
			phillyGlowParticles.forEachAlive(function(particle:PhillyGlowParticle)
			{
				if (particle.alpha <= 0)
				{
					particle.kill();
				}
			});
		}

		if (!ClientPrefs.data.lowQuality)
		{
			grpLimoParticles.forEach(function(spr:BGSprite)
			{
				if (spr.animation.curAnim.finished)
				{
					spr.kill();
					grpLimoParticles.remove(spr, true);
					spr.destroy();
				}
			});

			switch(limoKillingState)
			{
				case KILLING:
				{
					limoMetalPole.x += 5000 * elapsed;
					limoLight.x = limoMetalPole.x - 180;
					limoCorpse.x = limoLight.x - 50;
					limoCorpseTwo.x = limoLight.x + 35;

					var dancers:Array<BackgroundDancer> = grpLimoDancers.members;
					for (i in 0...dancers.length)
					{
						if (dancers[i].x < FlxG.width * 1.5 && limoLight.x > (370 * i) + 170)
						{
							switch(i)
							{
								case 0 | 3:
								{
									if (i == 0)
									{
										FlxG.sound.play(Paths.sound('dancerdeath'), 0.5);
									}

									var diffStr:String = i == 3 ? ' 2 ' : ' ';
									var particle:BGSprite = new BGSprite('gore/noooooo', dancers[i].x + 200, dancers[i].y, 0.4, 0.4, ['hench leg spin' + diffStr + 'PINK'], false);
									grpLimoParticles.add(particle);
									var particle:BGSprite = new BGSprite('gore/noooooo', dancers[i].x + 160, dancers[i].y + 200, 0.4, 0.4, ['hench arm spin' + diffStr + 'PINK'], false);
									grpLimoParticles.add(particle);
									var particle:BGSprite = new BGSprite('gore/noooooo', dancers[i].x, dancers[i].y + 50, 0.4, 0.4, ['hench head spin' + diffStr + 'PINK'], false);
									grpLimoParticles.add(particle);

									var particle:BGSprite = new BGSprite('gore/stupidBlood', dancers[i].x - 110, dancers[i].y + 20, 0.4, 0.4, ['blood'], false);
									particle.flipX = true;
									particle.angle = -57.5;
									grpLimoParticles.add(particle);
								}

								case 1:
								{
									limoCorpse.visible = true;
								}

								case 2:
								{
									limoCorpseTwo.visible = true;
								}
							} //Note: Nobody cares about the fifth dancer because he is mostly hidden offscreen :(
							dancers[i].x += FlxG.width * 2;
						}
					}

					if (limoMetalPole.x > FlxG.width * 2)
					{
						resetLimoKill();
						limoSpeed = 800;
						limoKillingState = SPEEDING_OFFSCREEN;
					}
				}

				case SPEEDING_OFFSCREEN:
				{
					limoSpeed -= 4000 * elapsed;
					bgLimo.x -= limoSpeed * elapsed;
					if (bgLimo.x > FlxG.width * 1.5)
					{
						limoSpeed = 3000;
						limoKillingState = SPEEDING;
					}
				}

				case SPEEDING:
				{
					limoSpeed -= 2000 * elapsed;
					if (limoSpeed < 1000)
					{
						limoSpeed = 1000;
					}

					bgLimo.x -= limoSpeed * elapsed;
					if (bgLimo.x < -275)
					{
						limoKillingState = STOPPING;
						limoSpeed = 800;
					}
					dancersParenting();
				}

				case STOPPING:
				{
					bgLimo.x = FlxMath.lerp(-150, bgLimo.x, Math.exp(-elapsed * 9));
					if (Math.round(bgLimo.x) == -150)
					{
						bgLimo.x = -150;
						limoKillingState = WAIT;
					}
					dancersParenting();
				}

				default:
				{
					//nothing
				}
			}
		}
	}

	override function beatHit()
	{
		if (!ClientPrefs.data.lowQuality)
		{
			grpLimoDancers.forEach(function(dancer:BackgroundDancer)
			{
				dancer.dance();
			});
		}

		if (FlxG.random.bool(10) && fastCarCanDrive)
		{
			fastCarDrive();
		}
	}
	
	// Substates for pausing/resuming tweens and timers
	override function closeSubState()
	{
		if (paused)
		{
			if (carTimer != null)
			{
				carTimer.active = true;
			}
		}
	}

	override function openSubState(SubState:flixel.FlxSubState)
	{
		if (paused)
		{
			if (carTimer != null)
			{
				carTimer.active = false;
			}
		}
	}

	override function eventPushed(event:objects.Note.EventNote)
	{
		switch(event.event)
		{
			case "Philly Glow":
			{
				if (limo == null || gfGroup == null || members.indexOf(gfGroup) < 0)
				{
					phillyGlowPending = true;
					return;
				}

				setupPhillyGlow();
			}
		}
	}

	function setupPhillyGlow():Void
	{
		blammedLightsBlack = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5).makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
		blammedLightsBlack.visible = false;
		insert(members.indexOf(gfGroup), blammedLightsBlack);

		phillyWindowEvent = new BGSprite('limo/bgLimoWindows', bgLimo.x, bgLimo.y, 0.4, 0.4);
		phillyWindowEvent.visible = false;
		insert(members.indexOf(blammedLightsBlack) + 1, phillyWindowEvent);

		phillyGlowGradient = new PhillyGlowGradient(-400, 425);
		phillyGlowGradient.visible = false;
		insert(members.indexOf(phillyWindowEvent) + 1, phillyGlowGradient);
		if (!ClientPrefs.data.flashing) phillyGlowGradient.intendedAlpha = 0.7;

		Paths.image('limo/particle'); //precache philly glow particle image
		phillyGlowParticles = new FlxTypedGroup<PhillyGlowParticle>();
		phillyGlowParticles.visible = false;
		insert(members.indexOf(phillyGlowGradient) + 1, phillyGlowParticles);
	}

	override function eventCalled(eventName:String, value1:String, value2:String, value3:String, value4:String, value5:String, flValue1:Null<Float>, flValue2:Null<Float>, flValue3:Null<Float>, flValue4:Null<Float>, flValue5:Null<Float>, strumTime:Float)
	{
		switch(eventName)
		{
			case "Kill Henchmen":
			{
				killHenchmen();
			}

			case "Philly Glow":
			{
				if (flValue1 == null || flValue1 <= 0) flValue1 = 0;
				var lightId:Int = Math.round(flValue1);

				var chars:Array<Character> = [boyfriend, gf, dad];
				switch(lightId)
				{
					case 0:
					{
						if (phillyGlowGradient.visible)
						{
							doFlash();
							if (ClientPrefs.data.camZooms)
							{
								FlxG.camera.zoom += 0.5;
								camHUD.zoom += 0.1;
							}

							blammedLightsBlack.visible = false;
							phillyWindowEvent.visible = false;
							phillyGlowGradient.visible = false;
							phillyGlowParticles.visible = false;
							curLightEvent = -1;

							for (who in chars)
							{
								who.color = FlxColor.WHITE;
							}
							limo.color = FlxColor.WHITE;
						}
					}

					case 1: //turn on
					{
						curLightEvent = FlxG.random.int(0, phillyLightsColors.length-1, [curLightEvent]);
						var color:FlxColor = phillyLightsColors[curLightEvent];

						if (!phillyGlowGradient.visible)
						{
							doFlash();
							if (ClientPrefs.data.camZooms)
							{
								FlxG.camera.zoom += 0.5;
								camHUD.zoom += 0.1;
							}

							blammedLightsBlack.visible = true;
							blammedLightsBlack.alpha = 1;
							phillyWindowEvent.visible = true;
							phillyGlowGradient.visible = true;
							phillyGlowParticles.visible = true;
						}
						else if (ClientPrefs.data.flashing)
						{
							var colorButLower:FlxColor = color;
							colorButLower.alphaFloat = 0.25;
							FlxG.camera.flash(colorButLower, 0.5, null, true);
						}

						var charColor:FlxColor = color;
						if (!ClientPrefs.data.flashing) charColor.saturation *= 0.5;
						else charColor.saturation *= 0.75;

						for (who in chars)
						{
							who.color = charColor;
						}
						phillyGlowParticles.forEachAlive(function(particle:PhillyGlowParticle)
						{
							particle.color = color;
						});
						phillyGlowGradient.color = color;
						phillyWindowEvent.color = color;

						color.brightness *= 0.5;
						limo.color = color;
					}

					case 2: // spawn particles
					{
						if (!ClientPrefs.data.lowQuality)
						{
							var particlesNum:Int = FlxG.random.int(8, 12);
							var width:Float = (2000 / particlesNum);
							var color:FlxColor = phillyLightsColors[curLightEvent];
							for (j in 0...3)
							{
								for (i in 0...particlesNum)
								{
									var particle:PhillyGlowParticle = phillyGlowParticles.recycle(PhillyGlowParticle);
									particle.x = -400 + width * i + FlxG.random.float(-width / 5, width / 5);
									particle.y = phillyGlowGradient.originalY + 200 + (FlxG.random.float(0, 125) + j * 40);
									particle.color = color;
									particle.start();
									phillyGlowParticles.add(particle);
								}
							}
						}
						phillyGlowGradient.bop();
					}
				}
			}
		}
	}

	function dancersParenting()
	{
		var dancers:Array<BackgroundDancer> = grpLimoDancers.members;
		for (i in 0...dancers.length)
		{
			dancers[i].x = (370 * i) + dancersDiff + bgLimo.x;
		}
	}
	
	function resetLimoKill():Void
	{
		limoMetalPole.x = -500;
		limoMetalPole.visible = false;
		limoLight.x = -500;
		limoLight.visible = false;
		limoCorpse.x = -500;
		limoCorpse.visible = false;
		limoCorpseTwo.x = -500;
		limoCorpseTwo.visible = false;
	}

	function resetFastCar():Void
	{
		fastCar.x = -12600;
		fastCar.y = FlxG.random.int(140, 250);
		fastCar.velocity.x = 0;
		fastCarCanDrive = true;
	}

	var carTimer:FlxTimer;
	function fastCarDrive()
	{
		//trace('Car drive');
		FlxG.sound.play(Paths.soundRandom('carPass', 0, 1), 0.7);

		fastCar.velocity.x = FlxG.random.int(30600, 39600);
		fastCarCanDrive = false;
		carTimer = new FlxTimer().start(2, function(tmr:FlxTimer)
		{
			resetFastCar();
			carTimer = null;
		});
	}

	function killHenchmen():Void
	{
		if (!ClientPrefs.data.lowQuality)
		{
			if (limoKillingState == WAIT)
			{
				limoMetalPole.x = -400;
				limoMetalPole.visible = true;
				limoLight.visible = true;
				limoCorpse.visible = false;
				limoCorpseTwo.visible = false;
				limoKillingState = KILLING;

				#if ACHIEVEMENTS_ALLOWED
				var kills = Achievements.addScore("roadkill_enthusiast");
				FlxG.log.add('Henchmen kills: $kills');
				#end
			}
		}
	}

	function doFlash()
	{
		var color:FlxColor = FlxColor.WHITE;
		if(!ClientPrefs.data.flashing) color.alphaFloat = 0.5;

		FlxG.camera.flash(color, 0.15, null, true);
	}
}
