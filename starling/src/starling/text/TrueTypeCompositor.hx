// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.text;


import flash.display3D.Context3DTextureFormat;
import flash.geom.Matrix;
import flash.text.AntiAliasType;
import flash.text.TextField;

import starling.display.MeshBatch;
import starling.display.Quad;
import starling.textures.Texture;
import starling.utils.Align;

/** @private
 *
 *  <p>This text compositor uses a Flash TextField to render system- or embedded fonts into
 *  a texture.</p>
 */

import flash.display.BitmapData;

class TrueTypeCompositor implements ITextCompositor
{
	// helpers
	private static var sHelperMatrix:Matrix = new Matrix();
	private static var sHelperQuad:Quad = new Quad(100, 100);
	private static var sNativeTextField:flash.text.TextField = new flash.text.TextField();
	private static var sNativeFormat:flash.text.TextFormat = new flash.text.TextFormat();
	
	/** Creates a new TrueTypeCompositor instance. */
	@:allow(starling.text)
	private function new()
	{
	}
	
	/** @inheritDoc */
	public function fillMeshBatch(meshBatch:MeshBatch, width:Float, height:Float, text:String,
			format:TextFormat, options:TextOptions = null):Void
	{
		if (text == null || text == "")			 return;
		
		var texture:Texture;
		var textureFormat:Context3DTextureFormat = options.textureFormat;
		var bitmapData:BitmapDataEx = renderText(width, height, text, format, options);
		
		texture = Texture.fromBitmapData(bitmapData, false, false, bitmapData.scale, textureFormat);
		texture.root.onRestore = function():Void
				{
					bitmapData = renderText(width, height, text, format, options);
					texture.root.uploadBitmapData(bitmapData);
					bitmapData.dispose();
					bitmapData = null;
				};
		
		bitmapData.dispose();
		bitmapData = null;
		
		sHelperQuad.texture = texture;
		sHelperQuad.readjustSize();
		
		if (format.horizontalAlign == Align.LEFT) sHelperQuad.x = 0
		else if (format.horizontalAlign == Align.CENTER) sHelperQuad.x = untyped ((width - texture.width) / 2)
		else sHelperQuad.x = width - texture.width;
		
		if (format.verticalAlign == Align.TOP) sHelperQuad.y = 0
		else if (format.verticalAlign == Align.CENTER) sHelperQuad.y = untyped ((height - texture.height) / 2)
		else sHelperQuad.y = height - texture.height;
		
		meshBatch.addMesh(sHelperQuad);
		
		sHelperQuad.texture = null;
	}
	
	/** @inheritDoc */
	public function clearMeshBatch(meshBatch:MeshBatch):Void
	{
		meshBatch.clear();
		if (meshBatch.texture != null) meshBatch.texture.dispose();
	}
	
	private function renderText(width:Float, height:Float, text:String,
			format:TextFormat, options:TextOptions):BitmapDataEx
	{
		var scaledWidth:Float = width * options.textureScale;
		var scaledHeight:Float = height * options.textureScale;
		var hAlign:String = format.horizontalAlign;
		
		format.toNativeFormat(sNativeFormat);
		
		sNativeFormat.size = untyped sNativeFormat.size * options.textureScale;
		sNativeTextField.defaultTextFormat = sNativeFormat;
		sNativeTextField.width = scaledWidth;
		sNativeTextField.height = scaledHeight;
		sNativeTextField.antiAliasType = AntiAliasType.ADVANCED;
		sNativeTextField.selectable = false;
		sNativeTextField.multiline = true;
		sNativeTextField.wordWrap = options.wordWrap;
		
		if (options.isHtmlText)			 sNativeTextField.htmlText = text
		else sNativeTextField.text = text;
		
		sNativeTextField.embedFonts = true;
		
		// we try embedded fonts first, non-embedded fonts are just a fallback
		if (sNativeTextField.textWidth == 0.0 || sNativeTextField.textHeight == 0.0) 
			sNativeTextField.embedFonts = false;
		
		if (options.autoScale) 
			autoScaleNativeTextField(sNativeTextField, sNativeFormat,
				untyped scaledWidth, untyped scaledHeight, text, options.isHtmlText);
		
		var textWidth:Float = sNativeTextField.textWidth;
		var textHeight:Float = sNativeTextField.textHeight;
		var bitmapWidth:Int = Math.ceil(textWidth) + 4;
		var bitmapHeight:Int = Math.ceil(textHeight) + 4;
		var maxTextureSize:Int = Texture.maxSize;
		var minTextureSize:Int = 1;
		
		// check for invalid texture sizes
		if (bitmapWidth < minTextureSize)			 bitmapWidth = 1;
		if (bitmapHeight < minTextureSize)			 bitmapHeight = 1;
		if (bitmapHeight > maxTextureSize || bitmapWidth > maxTextureSize) 
		{
			options.textureScale *= maxTextureSize / Math.max(bitmapWidth, bitmapHeight);
			return renderText(width, height, text, format, options);
		}
		else 
		{
			var offsetX:Float = 0.0;
			
			if (hAlign == Align.RIGHT)				 offsetX = scaledWidth - textWidth - 4
			// finally: draw TextField to bitmap data
			else if (hAlign == Align.CENTER)				 offsetX = (scaledWidth - textWidth - 4) / 2.0;
			
			
			
			var bitmapData:BitmapDataEx = new BitmapDataEx(bitmapWidth, bitmapHeight);
			sHelperMatrix.setTo(1, 0, 0, 1, -offsetX, 0);
			bitmapData.draw(sNativeTextField, sHelperMatrix);
			bitmapData.scale = options.textureScale;
			sNativeTextField.text = "";
			return bitmapData;
		}
	}
	
	private function autoScaleNativeTextField(textField:flash.text.TextField,
			textFormat:flash.text.TextFormat,
			maxTextWidth:Int, maxTextHeight:Int,
			text:String, isHtmlText:Bool):Void
	{
		var size:Float = untyped textFormat.size;
		
		while (textField.textWidth > maxTextWidth || textField.textHeight > maxTextHeight)
		{
			if (size <= 4)				 break;
			
			textFormat.size = size--;
			textField.defaultTextFormat = textFormat;
			
			if (isHtmlText)				 textField.htmlText = text
			else textField.text = text;
		}
	}
}



class BitmapDataEx extends BitmapData
{
	public var scale(get, set):Float;

	private var _scale:Float = 1.0;
	
	private function new(width:Int, height:Int, transparent:Bool = true, fillColor:Int = 0x0)
	{
		super(width, height, transparent, fillColor);
	}
	
	private function get_scale():Float
	{
		return _scale;
	}
	private function set_scale(value:Float):Float{_scale = value;
		return value;
	}
}
