// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.utils;


/**
 * Class for Deg2rad.call
 */
@:final class Deg2rad
{
	/** Converts an angle from degrees into radians. */
	public static inline function call(deg:Float):Float
	{
		return deg / 180.0 * Math.PI;
	}

	public function new() { }	
}
