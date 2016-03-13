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

import flash.display3D.Context3DVertexBufferFormat;
import openfl.errors.ArgumentError;

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
	private static var _FORMAT_SIZES:Map<Context3DVertexBufferFormat, Int>;
	private static var FORMAT_SIZES(get, null):Map<Context3DVertexBufferFormat, Int>;

	public var name:String;
	public var format:Context3DVertexBufferFormat;
	public var isColor:Bool;
	public var offset:Int; // in bytes
	public var size:Int;   // in bytes

	/** Creates a new instance with the given properties. */
	public function new(name:String, format:Context3DVertexBufferFormat, offset:Int)
	{
		if (!FORMAT_SIZES.exists(format))
			throw new ArgumentError(
				"Invalid attribute format: " + format + ". " +
				"Use one of the following: 'float1'-'float4', 'bytes4'");

		this.name = name;
		this.format = format;
		this.offset = offset;
		this.size = FORMAT_SIZES.get(format);
		this.isColor = name.indexOf("color") != -1 || name.indexOf("Color") != -1;
	}
	
	static function get_FORMAT_SIZES():Map<Context3DVertexBufferFormat, Int>
	{
		if (_FORMAT_SIZES == null) {
			_FORMAT_SIZES = new Map<Context3DVertexBufferFormat, Int>();
			_FORMAT_SIZES.set(Context3DVertexBufferFormat.BYTES_4, 4);
			_FORMAT_SIZES.set(Context3DVertexBufferFormat.FLOAT_1, 4);
			_FORMAT_SIZES.set(Context3DVertexBufferFormat.FLOAT_2, 8);
			_FORMAT_SIZES.set(Context3DVertexBufferFormat.FLOAT_3, 12);
			_FORMAT_SIZES.set(Context3DVertexBufferFormat.FLOAT_4, 16);
		}
		return _FORMAT_SIZES;
	}
}