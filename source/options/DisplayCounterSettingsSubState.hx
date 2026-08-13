package options;

class DisplayCounterSettingsSubState extends BaseOptionsMenu
{
	var colorOption:Option;

	public function new()
	{
		title = 'Display Counter Settings';
		rpcTitle = 'Display Counter Settings Menu'; //for Discord Rich Presence

		var option:Option = new Option('Show Display Counter',
			'If checked, displays the counter in the top-left corner.',
			'showFPS',
			BOOL);
		addOption(option);
        option.onChange = onChangeFPSCounter;

		var option:Option = new Option('Display FPS',
			'If checked, displays the FPS in the counter.',
			'displayFPS',
			BOOL);
		addOption(option);

		var option:Option = new Option('Display Memory',
			'If checked, displays memory usage in the counter.',
			'displayMemory',
			BOOL);
		addOption(option);

		var option:Option = new Option('Display Date',
			'If checked, displays the current date in the counter.',
			'displayDate',
			BOOL);
		addOption(option);

		var option:Option = new Option('Display Time',
			'If checked, displays the current time in the counter.',
			'displayTime',
			BOOL);
		addOption(option);

		var option:Option = new Option('Display Timezone',
			'If checked, displays the timezone in the time (only if Time is enabled).',
			'displayTimezone',
			BOOL);
		addOption(option);

		var option:Option = new Option('Display Battery',
			'If checked, displays battery percentage in the counter.',
			'displayBattery',
			BOOL);
		addOption(option);

		colorOption = new Option('Display Counter Color',
			'Change the color of the display counter text.',
			'fpsColor',
			STRING,
			['White']);
		colorOption.displayFormat = '';
		addOption(colorOption);

		super();
	}

	function onChangeFPSCounter()
	{
		if (Main.fpsVar != null)
		{
			Main.fpsVar.visible = ClientPrefs.data.showFPS;
		}
	}

	override function update(elapsed:Float)
	{
		var isColorOption:Bool = curOption == colorOption;

		// Preserve the color option's current selection/value in case
		// `super.update` tries to change it via left/right.
		var prevCurOpt:Int = colorOption != null ? colorOption.curOption : 0;
		var prevVal:Dynamic = colorOption != null ? colorOption.getValue() : null;

		// Let the base menu run normally so mouse movement, wheel and
		// holding logic still work. We'll then revert left/right changes
		// for the color option and handle Accept as a button.
		super.update(elapsed);

		if (isColorOption)
		{
			// If super accidentally changed the string selection, restore it.
			if (colorOption.curOption != prevCurOpt || colorOption.getValue() != prevVal)
			{
				colorOption.curOption = prevCurOpt;
				colorOption.setValue(prevVal);
				updateTextFrom(colorOption);
			}

			if (controls.ACCEPT)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
				openSubState(new DisplayCounterColorSubState(this, colorOption));
			}
		}

		if (colorOption.child != null)
		{
			var attached:objects.AttachedText = cast colorOption.child;
			if (attached != null && attached.sprTracker != null)
			{
				var optLabel:Alphabet = cast attached.sprTracker;
				if (optLabel != null)
				{
					optLabel.text = isColorOption ? ("> " + colorOption.name + " <") : colorOption.name;
				}
			}
			attached.text = '';
		}
	}
}
