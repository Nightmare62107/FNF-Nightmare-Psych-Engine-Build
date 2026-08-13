package backend;

class Highscore
{
	public static var weekScores:Map<String, Int> = new Map();
	public static var songScores:Map<String, Int> = new Map<String, Int>();
	public static var songRating:Map<String, Float> = new Map<String, Float>();
	public static var songRatingFC:Map<String, String> = new Map<String, String>();

	public static function resetSong(song:String, diff:Int = 0):Void
	{
		var daSong:String = formatSong(song, diff);
		setScore(daSong, 0);
		setRating(daSong, 0);
		setRatingFC(daSong, "");
	}

	public static function resetWeek(week:String, diff:Int = 0):Void
	{
		var daWeek:String = formatSong(week, diff);
		setWeekScore(daWeek, 0);
	}

	public static function saveScore(song:String, score:Int = 0, ?diff:Int = 0, ?rating:Float = -1, ?ratingFC:String = null):Void
	{
		if (song == null) return;
		var daSong:String = formatSong(song, diff);

		if (songScores.exists(daSong))
		{
			if (songScores.get(daSong) < score)
			{
				setScore(daSong, score);
				if (rating >= 0)
				{
					setRating(daSong, rating);
				}
				if (ratingFC != null)
				{
					setRatingFC(daSong, ratingFC);
				}
			}
		}
		else
		{
			setScore(daSong, score);
			if (rating >= 0)
			{
				setRating(daSong, rating);
			}
			if (ratingFC != null)
			{
				setRatingFC(daSong, ratingFC);
			}
		}
	}

	public static function saveWeekScore(week:String, score:Int = 0, ?diff:Int = 0):Void
	{
		var daWeek:String = formatSong(week, diff);

		if (weekScores.exists(daWeek))
		{
			if (weekScores.get(daWeek) < score)
			{
				setWeekScore(daWeek, score);
			}
		}
		else
		{
			setWeekScore(daWeek, score);
		}
	}

	/**
	 * YOU SHOULD FORMAT SONG WITH formatSong() BEFORE TOSSING IN SONG VARIABLE
	 */
	static function setScore(song:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songScores.set(song, score);
		FlxG.save.data.songScores = songScores;
		FlxG.save.flush();
	}
	static function setWeekScore(week:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		weekScores.set(week, score);
		FlxG.save.data.weekScores = weekScores;
		FlxG.save.flush();
	}

	static function setRating(song:String, rating:Float):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songRating.set(song, rating);
		FlxG.save.data.songRating = songRating;
		FlxG.save.flush();
	}

	static function setRatingFC(song:String, ratingFC:String):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songRatingFC.set(song, ratingFC);
		FlxG.save.data.songRatingFC = songRatingFC;
		FlxG.save.flush();
	}

	public static function getRatingFC(song:String, diff:Int):String
	{
		var daSong:String = formatSong(song, diff);
		if (!songRatingFC.exists(daSong))
		{
			setRatingFC(daSong, "");
		}

		return songRatingFC.get(daSong);
	}

	public static function formatSong(song:String, diff:Int):String
	{
		return Paths.formatToSongPath(song) + Difficulty.getFilePath(diff);
	}

	public static function getScore(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		if (!songScores.exists(daSong))
		{
			setScore(daSong, 0);
		}

		return songScores.get(daSong);
	}

	public static function getRating(song:String, diff:Int):Float
	{
		var daSong:String = formatSong(song, diff);
		if (!songRating.exists(daSong))
		{
			setRating(daSong, 0);
		}

		return songRating.get(daSong);
	}

	public static function getWeekScore(week:String, diff:Int):Int
	{
		var daWeek:String = formatSong(week, diff);
		if (!weekScores.exists(daWeek))
		{
			setWeekScore(daWeek, 0);
		}

		return weekScores.get(daWeek);
	}

	public static function load():Void
	{
		if (FlxG.save.data.weekScores != null)
		{
			weekScores = FlxG.save.data.weekScores;
		}

		if (FlxG.save.data.songScores != null)
		{
			songScores = FlxG.save.data.songScores;
		}

		if (FlxG.save.data.songRating != null)
		{
			songRating = FlxG.save.data.songRating;
		}

		if (FlxG.save.data.songRatingFC != null)
		{
			songRatingFC = FlxG.save.data.songRatingFC;
		}
	}
}
