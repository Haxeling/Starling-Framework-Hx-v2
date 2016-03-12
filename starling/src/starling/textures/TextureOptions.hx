// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.textures;


import starling.core.Starling;

/** The TextureOptions class specifies options for loading textures with the
 *  <code>Texture.fromData</code> and <code>Texture.fromTextureBase</code> methods. */
class TextureOptions
{
    public var scale(get, set) : Float;
    public var format(get, set) : String;
    public var mipMapping(get, set) : Bool;
    public var optimizeForRenderToTexture(get, set) : Bool;
    public var onReady(get, set) : Function;
    public var premultipliedAlpha(get, set) : Bool;

    private var _scale : Float;
    private var _format : String;
    private var _mipMapping : Bool;
    private var _optimizeForRenderToTexture : Bool = false;
    private var _premultipliedAlpha : Bool;
    private var _onReady : Function = null;
    
    /** Creates a new instance with the given options. */
    public function new(scale : Float = 1.0, mipMapping : Bool = false,
            format : String = "bgra", premultipliedAlpha : Bool = true)
    {
        _scale = scale;
        _format = format;
        _mipMapping = mipMapping;
        _premultipliedAlpha = premultipliedAlpha;
    }
    
    /** Creates a clone of the TextureOptions object with the exact same properties. */
    public function clone() : TextureOptions
    {
        var clone : TextureOptions = new TextureOptions(_scale, _mipMapping, _format);
        clone._optimizeForRenderToTexture = _optimizeForRenderToTexture;
        clone._onReady = _onReady;
        return clone;
    }
    
    /** The scale factor, which influences width and height properties. If you pass '-1',
     *  the current global content scale factor will be used. @default 1.0 */
    private function get_scale() : Float{return _scale;
    }
    private function set_scale(value : Float) : Float
    {
        _scale = value > (0) ? value : Starling.contentScaleFactor;
        return value;
    }
    
    /** The <code>Context3DTextureFormat</code> of the underlying texture data. Only used
     *  for textures that are created from Bitmaps; the format of ATF files is set when they
     *  are created. @default BGRA */
    private function get_format() : String{return _format;
    }
    private function set_format(value : String) : String{_format = value;
        return value;
    }
    
    /** Indicates if the texture contains mip maps. @default false */
    private function get_mipMapping() : Bool{return _mipMapping;
    }
    private function set_mipMapping(value : Bool) : Bool{_mipMapping = value;
        return value;
    }
    
    /** Indicates if the texture will be used as render target. */
    private function get_optimizeForRenderToTexture() : Bool{return _optimizeForRenderToTexture;
    }
    private function set_optimizeForRenderToTexture(value : Bool) : Bool{_optimizeForRenderToTexture = value;
        return value;
    }
    
    /** A callback that is used only for ATF textures; if it is set, the ATF data will be
     *  decoded asynchronously. The texture can only be used when the callback has been
     *  executed. This property is ignored for all other texture types (they are ready
     *  immediately when the 'Texture.from...' method returns, anyway), and it's only used
     *  by the <code>Texture.fromData</code> factory method.
     *  
     *  <p>This is the expected function definition: 
     *  <code>function(texture:Texture):void;</code></p>
     *
     *  @default null
     */
    private function get_onReady() : Function{return _onReady;
    }
    private function set_onReady(value : Function) : Function{_onReady = value;
        return value;
    }
    
    /** Indicates if the alpha values are premultiplied into the RGB values. This is typically
     *  true for textures created from BitmapData and false for textures created from ATF data.
     *  This property will only be read by the <code>Texture.fromTextureBase</code> factory
     *  method. @default true */
    private function get_premultipliedAlpha() : Bool{return _premultipliedAlpha;
    }
    private function set_premultipliedAlpha(value : Bool) : Bool{_premultipliedAlpha = value;
        return value;
    }
}
