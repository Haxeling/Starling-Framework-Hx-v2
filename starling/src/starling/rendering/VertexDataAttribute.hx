// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.rendering;

import openfl.display3D.Context3DVertexBufferFormat;
import openfl.errors.ArgumentError;
import openfl.errors.Error;

/** Holds the properties of a single attribute in a VertexDataFormat instance.
 *  The member variables must never be changed; they are only <code>public</code>
 *  for performance reasons. */
class VertexDataAttribute
{
	/*private static var FORMAT_SIZES = {
		"bytes4": 4,
		"float1": 4,
		"float2": 8,
		"float3": 12,
		"float4": 16
	};*/
	private static var _FORMAT_SIZES:FormatSizes;
	private static var FORMAT_SIZES(get, null):FormatSizes;
	
	//private static var _FORMAT_SIZES:Map<Context3DVertexBufferFormat, Int>;
	//private static var FORMAT_SIZES(get, null):Map<Context3DVertexBufferFormat, Int>;

	public var name:String;
	public var format:Context3DVertexBufferFormat;
	public var isColor:Bool = false;
	public var offset:Int = 0; // in bytes
	public var size:Int = 0;   // in bytes

	/** Creates a new instance with the given properties. */
	public function new(name:String, format:Context3DVertexBufferFormat, offset:Int)
	{
		trace("set format = " + format);
		try {
			var i:Int = untyped VertexDataAttribute.FORMAT_SIZES[format];
		}
		catch (e:Error) {
			trace("Error: " + e);
			throw new ArgumentError(
				"Invalid attribute format: " + format + ". " +
				"Use one of the following: 'float1'-'float4', 'bytes4'");
		}
		
		this.name = name;
		this.format = format;
		this.offset = offset;
		
		//trace("FORMAT_SIZES = " + FORMAT_SIZES);
		//trace("format = " + format);
		//trace(untyped FORMAT_SIZES[format]);
		
		if (format == Context3DVertexBufferFormat.BYTES_4) this.size = 4;
		else if (format == Context3DVertexBufferFormat.FLOAT_1) this.size = 4;
		else if (format == Context3DVertexBufferFormat.FLOAT_2) this.size = 8;
		else if (format == Context3DVertexBufferFormat.FLOAT_3) this.size = 12;
		else if (format == Context3DVertexBufferFormat.FLOAT_4) this.size = 16;
		
		//this.size = untyped FORMAT_SIZES[format];
		this.isColor = name.indexOf("color") != -1 || name.indexOf("Color") != -1;
	}
	
	static function get_FORMAT_SIZES():FormatSizes
	{
		if (_FORMAT_SIZES == null) {
			_FORMAT_SIZES = new FormatSizes();
		}
		return _FORMAT_SIZES;
	}
}

class FormatSizes
{
	
	public var bytes4:Int = 4;
	public var float1:Int = 4;
	public var float2:Int = 8;
	public var float3:Int = 12;
	public var float4:Int = 16;
	
	@:allow(starling.rendering.VertexDataAttribute)
	private function new ():Void
	{
		
	}
}