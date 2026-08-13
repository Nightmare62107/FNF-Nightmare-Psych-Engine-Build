package shaders;

import flixel.system.FlxAssets.FlxShader;
import openfl.filters.ShaderFilter;

class Anaglyph3DEffect {
    public var filter(default, null):ShaderFilter;
    public var shader(default, null):Anaglyph3DShader;

    public var depth(default, set):Float = 0.008;
    public var mode(default, set):Int = 0; // 0 = Cross-Eye, 1 = Anaglyph Red/Cyan

    public function new(initialDepth:Float = 0.008, initialMode:Int = 0) {
        shader = new Anaglyph3DShader();
        filter = new ShaderFilter(shader);
        this.mode = initialMode;
        this.depth = initialDepth;
    }

    private function set_depth(value:Float):Float {
        depth = value;
        shader.offset.value = [depth];
        return value;
    }

    private function set_mode(value:Int):Int {
        mode = value;
        shader.mode.value = [mode];
        return value;
    }
}

class Anaglyph3DShader extends FlxShader {
    @:glFragmentSource('
        #pragma header

        uniform float offset;
        uniform int mode; // 0 = Cross-Eye SBS, 1 = Anaglyph Red/Cyan

        void main() {
            vec2 uv = openfl_TextureCoordv;

            if (mode == 1) {
                // ANAGLYPH RED/CYAN
                vec4 leftColor = texture2D(bitmap, vec2(uv.x - offset, uv.y));
                vec4 rightColor = texture2D(bitmap, vec2(uv.x + offset, uv.y));
                gl_FragColor = vec4(leftColor.r, rightColor.g, rightColor.b, max(leftColor.a, rightColor.a));
            } else {
                // CROSS-EYE SIDE-BY-SIDE (Letterboxed to fix aspect ratio)
                // Scale Y into middle 50% (0.25 to 0.75) to match 16:9 ratio
                float scaledY = (uv.y - 0.25) * 2.0;

                if (scaledY < 0.0 || scaledY > 1.0) {
                    // Top and bottom black bars
                    gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                } else {
                    vec2 sampleUV;
                    if (uv.x < 0.5) {
                        sampleUV = vec2((uv.x * 2.0) + offset, scaledY);
                    } else {
                        sampleUV = vec2(((uv.x - 0.5) * 2.0) - offset, scaledY);
                    }
                    gl_FragColor = texture2D(bitmap, sampleUV);
                }
            }
        }
    ')
    public function new() {
        super();
        offset.value = [0.008];
        mode.value = [0];
    }
}
