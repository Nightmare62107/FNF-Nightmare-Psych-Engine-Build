package objects;

import flixel.FlxSprite;
import backend.animation.PsychAnimationController;
import backend.Paths;
import flixel.FlxG;
import backend.ClientPrefs;
import objects.Note;

class NoteHoldCover extends FlxSprite
{
    public var babyArrow:StrumNote;
    public var noteData:Int = 0;
    public var parentNote:Note;
    public var copyX:Bool = true;
    public var copyY:Bool = true;

    public function new()
    {
        super();
        animation = new PsychAnimationController(this);
        alive = false;
        visible = false;
    }

    public function spawnCover(x:Float, y:Float, data:Int, ?note:Note):Void
    {
        setPosition(x, y);
        noteData = data;
        parentNote = note;
        _animState = 0;
        alive = true;
        visible = true;
        alpha = 1;
        antialiasing = ClientPrefs.data.antialiasing;

        var colorName:String = 'Blue';
        if (data >= 0 && data < Note.colArray.length) colorName = Note.colArray[data].substr(0,1).toUpperCase() + Note.colArray[data].substr(1);

        var atlasKey:String = 'holdCover' + colorName;
        var frames = Paths.getSparrowAtlas(atlasKey);
        var startExists:Bool = false;
        var loopExists:Bool = false;
        var endExists:Bool = false;
        if (frames != null)
        {
            this.frames = frames;
            // Debug traces removed: previously listed frame names here
            // add animations by prefix (start, loop, end)
            try
            {
                animation.addByPrefix('holdCoverStart' + colorName, 'holdCoverStart' + colorName, 24, false);
                animation.addByPrefix('holdCover' + colorName, 'holdCover' + colorName, 24, true);
                animation.addByPrefix('holdCoverEnd' + colorName, 'holdCoverEnd' + colorName, 24, false);
            }
            catch(e:Dynamic) {}
            // build manual frame lists for start/loop/end by prefix
            try
            {
                startFrames = [];
                loopFrames = [];
                endFrames = [];
                var preStart = 'holdCoverStart' + colorName;
                var preLoop = 'holdCover' + colorName;
                var preEnd = 'holdCoverEnd' + colorName;
                for (i in 0...frames.frames.length)
                {
                    var f = frames.frames[i];
                    var fname = (f.name != null) ? f.name : '';
                    if (fname.indexOf(preStart) == 0) startFrames.push(i);
                    else if (fname.indexOf(preLoop) == 0) loopFrames.push(i);
                    else if (fname.indexOf(preEnd) == 0) endFrames.push(i);
                }
            }
            catch(e:Dynamic) {}
            startExists = startFrames.length > 0;
            loopExists = loopFrames.length > 0;
            endExists = endFrames.length > 0;
            // If a start animation exists, use manual animator to play it once then switch to loop.
            // If no start exists but a loop exists, play loop immediately.
            if (startExists)
            {
                _animState = 1;
                framePointer = 0;
                frameTimer = 0;
            }
            else if (loopExists)
            {
                _animState = 2;
                framePointer = 0;
                frameTimer = 0;
            }
            else if (!endExists)
            {
                // nothing to show, kill immediately to avoid lingering objects
                kill();
            }
        }
        if (startExists)
            playStart();
        else if (loopExists)
            playContinue();
        else if (!endExists)
            // nothing to show, kill immediately to avoid lingering objects
            kill();
        _ending = false;
    }

    var _lastAnimName:String = null;
    var _lastAnimFinished:Bool = false;
    var _ending:Bool = false;
    // 0 = idle, 1 = start, 2 = loop, 3 = end
    var _animState:Int = 0;
    // Manual frame animation data (indices into `frames.frames`)
    var startFrames:Array<Int> = [];
    var loopFrames:Array<Int> = [];
    var endFrames:Array<Int> = [];
    var frameTimer:Float = 0;
    var framePointer:Int = 0;
    var fps:Float = 24;
    var useManualAnim:Bool = true;

    public override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (!useManualAnim)
        {
            var cur = animation.curAnim;
            if (cur != null)
            {
                if (cur.name != _lastAnimName)
                {
                    _lastAnimName = cur.name;
                    _lastAnimFinished = cur.finished;
                }
                else
                {
                    if (cur.finished && !_lastAnimFinished)
                        onAnimationFinished(cur.name);
                    _lastAnimFinished = cur.finished;
                }
            }
            else
            {
                _lastAnimName = null;
                _lastAnimFinished = false;
            }
        }
        else
        {
            // Manual animator: advance whichever state we're in
            var dt:Float = elapsed;
            frameTimer += dt;
            var interval:Float = 1.0 / fps;
            if (_animState == 1)
            {
                if (startFrames.length > 0)
                {
                    while (frameTimer >= interval)
                    {
                        frameTimer -= interval;
                        framePointer++;
                        if (framePointer >= startFrames.length)
                        {
                            // start finished -> enter loop
                            framePointer = 0;
                            _animState = 2;
                            break;
                        }
                    }
                    if (startFrames.length > 0)
                        frame = this.frames.frames[startFrames[Std.int(Math.min(framePointer, startFrames.length - 1))]];
                }
                else
                {
                    // no start frames -> go to loop
                    _animState = 2;
                    framePointer = 0;
                }
            }
            else if (_animState == 2)
            {
                if (loopFrames.length > 0)
                {
                    while (frameTimer >= interval)
                    {
                        frameTimer -= interval;
                        framePointer = (framePointer + 1) % loopFrames.length;
                    }
                    frame = this.frames.frames[loopFrames[Std.int(Math.max(0, Math.min(framePointer, loopFrames.length - 1)))] ];
                }
            }
            else if (_animState == 3)
            {
                if (endFrames.length > 0)
                {
                    while (frameTimer >= interval)
                    {
                        frameTimer -= interval;
                        framePointer++;
                        if (framePointer >= endFrames.length)
                        {
                            visible = false;
                            kill();
                            return;
                        }
                    }
                    frame = this.frames.frames[endFrames[Std.int(Math.min(framePointer, endFrames.length - 1))]];
                }
                else
                {
                    visible = false;
                    kill();
                    return;
                }
            }
        }

        if (babyArrow != null)
        {
            if (copyX)
                x = babyArrow.x - Note.swagWidth * 0.95;
            if (copyY)
                y = babyArrow.y - Note.swagWidth;
        }

        // If the parent note was removed/died, ensure we transition to end animation
        if (!_ending && (parentNote == null || !parentNote.alive))
        {
            _ending = true;
            playEnd();
        }
    }

    public function playStart():Void
    {
        if (_animState == 1) return;
        _animState = 1;
        var colorName:String = noteData >= 0 && noteData < Note.colArray.length ? Note.colArray[noteData].substr(0,1).toUpperCase() + Note.colArray[noteData].substr(1) : 'Blue';
        var animName = 'holdCoverStart' + colorName;
        // manual animator will handle playback; ensure controller is stopped
        if (animation.exists(animName)) { /* no-op */ }
    }

    public function playContinue():Void
    {
        if (_animState == 2) return;
        _animState = 2;
        var colorName:String = noteData >= 0 && noteData < Note.colArray.length ? Note.colArray[noteData].substr(0,1).toUpperCase() + Note.colArray[noteData].substr(1) : 'Blue';
        var animName = 'holdCover' + colorName;
        if (animation.exists(animName)) { /* no-op */ }
    }

    public function playEnd():Void
    {
        if (_animState == 3) return;
        _animState = 3;
        _ending = true;
        // switch to manual end playback
        framePointer = 0;
        frameTimer = 0;
        // if useManualAnim, we expect endFrames to be populated; play handled in update
    }

    public function onAnimationFinished(animName:String):Void
    {
        if (animName.startsWith('holdCoverStart') && _animState == 1)
        {
            playContinue();
        }
        else if (animName.startsWith('holdCoverEnd') && _animState == 3)
        {
            visible = false;
            kill();
        }
    }

    public override function kill():Void
    {
        super.kill();
        visible = false;
        alive = false;
        parentNote = null;
        _ending = false;
        _animState = 0;
    }

    public override function revive():Void
    {
        super.revive();
        visible = true;
        alive = true;
        _ending = false;
        _animState = 0;
    }
}
