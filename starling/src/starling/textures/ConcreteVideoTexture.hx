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


import flash.display3D.Context3DTextureFormat;
import flash.display3D.textures.TextureBase;
import flash.display3D.textures.VideoTexture;
import flash.events.Event;
import haxe.Constraints.Function;

import starling.core.Starling;
import starling.utils.Execute;

/** @private
 *
 *  A concrete texture that wraps a <code>VideoTexture</code> base.
 *  For internal use only. */
class ConcreteVideoTexture extends ConcreteTexture
{
    private var videoBase(get, never):VideoTexture;

    private var _textureReadyCallback:Function;
    
    /** Creates a new instance with the given parameters.
     *  <code>base</code> must be of type <code>flash.display3D.textures.VideoTexture</code>.
     */
    @:allow(starling.textures)
    private function new(base:VideoTexture, scale:Float = 1)
    {
        super(base, Context3DTextureFormat.BGRA, base.videoWidth, base.videoHeight, false,
                false, false, scale);
    }
    
    /** @inheritDoc */
    override public function dispose():Void
    {
        base.removeEventListener(Event.TEXTURE_READY, onTextureReady);
        super.dispose();
    }
    
    /** @inheritDoc */
    override private function createBase():TextureBase
    {
        return Starling.Context.createVideoTexture();
    }
    
    /** @private */
    @:allow(starling.textures)
    override private function attachVideo(type:String, attachment:Dynamic,
            onComplete:Function = null):Void
    {
        _textureReadyCallback = onComplete;
		var attachFunction:Function = Reflect.getProperty(base, "attach" + type);
		attachFunction(attachment);
        //base["attach" + type](attachment);
        base.addEventListener(Event.TEXTURE_READY, onTextureReady);
        
        setDataUploaded();
    }
    
    private function onTextureReady(event:Event):Void
    {
        base.removeEventListener(Event.TEXTURE_READY, onTextureReady);
        Execute.call(_textureReadyCallback, [this]);
        _textureReadyCallback = null;
    }
    
    /** The actual width of the video in pixels. */
    override private function get_nativeWidth():Float
    {
        return videoBase.videoWidth;
    }
    
    /** The actual height of the video in pixels. */
    override private function get_nativeHeight():Float
    {
        return videoBase.videoHeight;
    }
    
    /** @inheritDoc */
    override private function get_width():Float
    {
        return nativeWidth / scale;
    }
    
    /** @inheritDoc */
    override private function get_height():Float
    {
        return nativeHeight / scale;
    }
    
    private function get_videoBase():VideoTexture
    {
        return try cast(base, VideoTexture) catch(e:Dynamic) null;
    }
}

