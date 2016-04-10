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

import openfl.display3D.Context3DTextureFormat;
import openfl.errors.ArgumentError;
import haxe.Constraints.Function;
import starling.textures.ConcreteTexture;

import openfl.display.BitmapData;
import openfl.display3D.textures.TextureBase;
import openfl.events.Event;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;

import starling.core.Starling;
import starling.utils.MathUtil;
import starling.utils.Execute;

/** @private
 *
 *  A concrete texture that wraps a <code>Texture</code> base.
 *  For internal use only. */
class ConcretePotTexture extends ConcreteTexture
{
	private var potBase(get, never):openfl.display3D.textures.Texture;

	private var _textureReadyCallback:Function;
	
	private static var sMatrix:Matrix = new Matrix();
	private static var sRectangle:Rectangle = new Rectangle();
	private static var sOrigin:Point = new Point();
	
	/** Creates a new instance with the given parameters. */
	@:allow(starling.textures)
	private function new(base:openfl.display3D.textures.Texture, format:Context3DTextureFormat,
			width:Int, height:Int, mipMapping:Bool,
			premultipliedAlpha:Bool,
			optimizedForRenderTexture:Bool = false, scale:Float = 1)
	{
		super(base, format, width, height, mipMapping, premultipliedAlpha,
				optimizedForRenderTexture, scale);
		
		if (width != MathUtil.getNextPowerOfTwo(width)) 
			throw new ArgumentError("width must be a power of two");
		
		if (height != MathUtil.getNextPowerOfTwo(height)) 
			throw new ArgumentError("height must be a power of two");
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
		return Starling.Context.createTexture(
				untyped nativeWidth, untyped nativeHeight, format, optimizedForRenderTexture);
	}
	
	/** @inheritDoc */
	override public function uploadBitmapData(data:BitmapData):Void
	{
		potBase.uploadFromBitmapData(data);
		
		var buffer:BitmapData = null;
		
		if (data.width != nativeWidth || data.height != nativeHeight) 
		{
			buffer = new BitmapData(untyped nativeWidth, untyped nativeHeight, true, 0);
			buffer.copyPixels(data, data.rect, sOrigin);
			data = buffer;
		}
		
		if (mipMapping && data.width > 1 && data.height > 1) 
		{
			var currentWidth:Int = data.width >> 1;
			var currentHeight:Int = data.height >> 1;
			var level:Int = 1;
			var canvas:BitmapData = new BitmapData(currentWidth, currentHeight, true, 0);
			var bounds:Rectangle = sRectangle;
			var matrix:Matrix = sMatrix;
			matrix.setTo(0.5, 0.0, 0.0, 0.5, 0.0, 0.0);
			
			while (currentWidth >= 1 || currentHeight >= 1)
			{
				bounds.setTo(0, 0, currentWidth, currentHeight);
				canvas.fillRect(bounds, 0);
				canvas.draw(data, matrix, null, null, null, true);
				potBase.uploadFromBitmapData(canvas, level++);
				matrix.scale(0.5, 0.5);
				currentWidth = currentWidth >> 1;
				currentHeight = currentHeight >> 1;
			}
			
			canvas.dispose();
		}
		
		if (buffer != null)			 buffer.dispose();
		
		setDataUploaded();
	}
	
	/** @inheritDoc */
	override public function uploadAtfData(data:ByteArray, offset:Int = 0, async:Dynamic = null):Void
	{
		var isAsync:Bool = Reflect.isFunction(async) || async == true;
		
		if (Reflect.isFunction(async)) 
		{
			_textureReadyCallback = untyped async;
			base.addEventListener(Event.TEXTURE_READY, onTextureReady);
		}
		
		potBase.uploadCompressedTextureFromByteArray(data, offset, isAsync);
		setDataUploaded();
	}
	
	private function onTextureReady(event:Event):Void
	{
		base.removeEventListener(Event.TEXTURE_READY, onTextureReady);
		Execute.call(_textureReadyCallback, [this]);
		_textureReadyCallback = null;
	}
	
	private function get_potBase():openfl.display3D.textures.Texture
	{
		return cast(base, openfl.display3D.textures.Texture);
	}
}

