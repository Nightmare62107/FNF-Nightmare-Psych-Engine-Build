package backend.ui;

import backend.ui.PsychUIBox.UIStyleData;

class PsychUIDropLeftMenu extends PsychUIInputText
{
    public static final CLICK_EVENT = "dropleft_click";

    public var list(default, set):Array<String> = [];
    public var button:FlxSprite;
    public var onSelect:Int->String->Void;

    public var selectedIndex(default, set):Int = -1;
    public var selectedLabel(default, set):String = null;

    var _curFilter:Array<String>;
    var _itemWidth:Float = 0;
    public function new(x:Float, y:Float, list:Array<String>, callback:Int->String->Void, ?width:Float = 100)
    {
        super(x, y);
        if(list == null) list = [];

        _itemWidth = width - 2;
        setGraphicSize(width, 20);
        updateHitbox();
        textObj.y += 2;

        button = new FlxSprite(behindText.width + 1, 0).loadGraphic(Paths.image('psych-ui/dropleft_button', 'embed'), true, 20, 20);
        button.animation.add('normal', [0], false);
        button.animation.add('pressed', [1], false);
        button.animation.play('normal', true);
        add(button);

        onSelect = callback;

        onChange = function(old:String, cur:String)
        {
            if(old != cur)
            {
                _curFilter = this.list.filter(function(str:String) return str.startsWith(cur));
                showDropLeft(true, 0, _curFilter);
            }
        }
        unfocus = function()
        {
            showDropLeftClickFix();
            showDropLeft(false);
        }

        for (option in list)
            addOption(option);

        selectedIndex = 0;
        showDropLeft(false);
    }

    function set_selectedIndex(v:Int)
    {
        selectedIndex = v;
        if(selectedIndex < 0 || selectedIndex >= list.length) selectedIndex = -1;

        @:bypassAccessor selectedLabel = list[selectedIndex];
        text = (selectedLabel != null) ? selectedLabel : '';
        return selectedIndex;
    }

    function set_selectedLabel(v:String)
    {
        var id:Int = list.indexOf(v);
        if(id >= 0)
        {
            @:bypassAccessor selectedIndex = id;
            selectedLabel = v;
            text = selectedLabel;
        }
        else
        {
            @:bypassAccessor selectedIndex = -1;
            selectedLabel = null;
            text = '';
        }
        return selectedLabel;
    }

    var _items:Array<PsychUIDropLeftItem> = [];
    public var curScroll:Int = 0;
    override function update(elapsed:Float)
    {
        var lastFocus = PsychUIInputText.focusOn;
        super.update(elapsed);
        if(FlxG.mouse.justPressed)
        {
            if(FlxG.mouse.overlaps(button, camera))
            {
                button.animation.play('pressed', true);
                if(lastFocus != this)
                    PsychUIInputText.focusOn = this;
                else if(PsychUIInputText.focusOn == this)
                    PsychUIInputText.focusOn = null;
            }
        }
        else if(FlxG.mouse.released && button.animation.curAnim != null && button.animation.curAnim.name != 'normal') button.animation.play('normal', true);

        if(lastFocus != PsychUIInputText.focusOn)
        {
            showDropLeft(PsychUIInputText.focusOn == this);
        }
        else if(PsychUIInputText.focusOn == this)
        {
            var wheel:Int = FlxG.mouse.wheel;
            if(FlxG.keys.justPressed.UP) wheel++;
            if(FlxG.keys.justPressed.DOWN) wheel--;
            if(wheel != 0) showDropLeft(true, curScroll + wheel, _curFilter);
        }
    }

    private function showDropLeftClickFix()
    {
        if(FlxG.mouse.justPressed)
        {
            for (item in _items)
                if(item != null && item.active && item.visible)
                    item.update(0);
        }
    }

    public function showDropLeft(vis:Bool = true, scroll:Int = 0, onlyAllowed:Array<String> = null)
    {
        if(!vis)
        {
            text = selectedLabel;
            _curFilter = null;
        }

        curScroll = Std.int(Math.max(0, Math.min(onlyAllowed != null ? (onlyAllowed.length - 1) : (list.length - 1), scroll)));
        if(vis)
        {
            var n:Int = 0;
            for (item in _items)
            {
                if(onlyAllowed != null)
                {
                    if(onlyAllowed.contains(item.label))
                    {
                        item.active = item.visible = (n >= curScroll);
                        n++;
                    }
                    else item.active = item.visible = false;
                }
                else
                {
                    item.active = item.visible = (n >= curScroll);
                    n++;
                }
            }

            // Drop LEFT: stack items to the left of the input box
            var txtX:Float = behindText.x - 1;
            for (num => item in _items)
            {
                if(!item.visible) continue;
                item.y = behindText.y;
                txtX -= item.width;
                item.x = txtX;
                item.forceNextUpdate = true;
            }
            bg.scale.x = behindText.x - txtX + 2;
            bg.x = txtX;
            bg.updateHitbox();
        }
        else
        {
            for (item in _items)
                item.active = item.visible = false;

            bg.scale.x = 20;
            bg.updateHitbox();
        }
    }

    public var broadcastDropLeftEvent:Bool = true;
    function clickedOn(num:Int, label:String)
    {
        selectedIndex = num;
        showDropLeft(false);
        if(onSelect != null) onSelect(num, label);
        if(broadcastDropLeftEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
    }

    function addOption(option:String)
    {
        @:bypassAccessor list.push(option);
        var curID:Int = list.length - 1;
        var item:PsychUIDropLeftItem = cast recycle(PsychUIDropLeftItem, () -> new PsychUIDropLeftItem(1, 1, this._itemWidth), true);
        item.cameras = cameras;
        item.label = option;
        item.visible = item.active = false;
        item.onClick = function() clickedOn(curID, option);
        item.forceNextUpdate = true;
        _items.push(item);
        insert(1, item);
    }

    function set_list(v:Array<String>)
    {
        var selected:String = selectedLabel;
        showDropLeft(false);

        for (item in _items)
            item.kill();

        _items = [];
        list = [];
        for (option in v)
            addOption(option);

        if(selectedLabel != null) selectedLabel = selected;
        return v;
    }
}

class PsychUIDropLeftItem extends FlxSpriteGroup
{
    public var hoverStyle:UIStyleData = {
        bgColor: 0xFF0066FF,
        textColor: FlxColor.WHITE,
        bgAlpha: 1
    };
    public var normalStyle:UIStyleData = {
        bgColor: FlxColor.WHITE,
        textColor: FlxColor.BLACK,
        bgAlpha: 1
    };

    public var bg:FlxSprite;
    public var text:FlxText;
    var initWidth:Float;
    public function new(x:Float = 0, y:Float = 0, width:Float = 100)
    {
        super(x, y);
        bg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
        initWidth = width;
        bg.setGraphicSize(initWidth, 20);
        bg.updateHitbox();
        add(bg);

        text = new FlxText(0, 0, initWidth, 8);
        text.color = FlxColor.BLACK;
        add(text);
    }

    public var onClick:Void->Void;
    public var forceNextUpdate:Bool = false;
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        if(FlxG.mouse.justMoved || FlxG.mouse.justPressed || forceNextUpdate)
        {
            var overlapped:Bool = (FlxG.mouse.overlaps(bg, camera));

            var style = overlapped ? hoverStyle : normalStyle;
            bg.color = style.bgColor;
            text.color = style.textColor;
            bg.alpha = style.bgAlpha;
            forceNextUpdate = false;

            if(overlapped && FlxG.mouse.justPressed)
                onClick();
        }
        
        text.x = bg.x;
        // Keep runtime position consistent with set_label (top-aligned)
        text.y = bg.y + 1;
    }

    public var label(default, set):String;
    function set_label(v:String)
    {
        label = v;
        var maxRows:Int = 17;
        var len = v.length;
        var cols = Std.int(Math.ceil(len / Math.max(1, maxRows)));
        if(cols <= 1)
        {
            var vert:String = "";
            for(i in 0...len)
                vert += v.charAt(i) + (i < len - 1 ? "\n" : "");
            text.width = initWidth;
            // Set the text, then measure a consistent 17-line height so all short items match exactly.
            text.text = vert;

            // Measure height of 17 lines using a fixed marker so it's identical across items.
            var marker:String = "A";
            var markerLines:String = marker;
            for(m in 1...maxRows) markerLines += "\n" + marker;
            // Temporarily set to marker to measure exact 17-line height, then restore.
            var prevText:String = text.text;
            text.text = markerLines;
            var height17:Float = text.height;
            text.text = prevText;

            var finalHeight:Int = Std.int(height17 + 6);
            bg.setGraphicSize(initWidth, finalHeight);
        }
        else
        {
            var lines:Array<String> = [];
            for(r in 0...maxRows)
            {
                var rowStr:String = "";
                for(c in 0...cols)
                {
                    var idx = c * maxRows + r;
                    var ch = (idx < len) ? v.charAt(idx) : ' ';
                    rowStr += ch + (c < cols - 1 ? '   ' : '');
                }
                lines.push(rowStr);
            }
            var multi:String = lines.join('\n');
            text.width = Std.int(initWidth * cols);
            text.text = multi;

            bg.setGraphicSize(text.width, Std.int(text.height + 6));
        }

        bg.updateHitbox();

        // Top-align text inside the box with minimal padding so first character appears on the first row
        text.y = bg.y + 1;
        return v;
    }
}
