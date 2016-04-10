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
import haxe.Constraints.Function;


/**
 * Class for execute
 */
@:final class Execute
{
	/** Executes a function with the specified arguments. If the argument count does not match
	 *  the function, the argument list is cropped / filled up with <code>null</code> values. */
	public static function call(func:Function, args:Array<Dynamic>):Void
	{
		if (func != null) 
		{
			var maxNumArgs:Int = 0;
			#if flash
				maxNumArgs = Reflect.getProperty(func, "length");
			#else 
				maxNumArgs = args.length;
			#end
			if (args != null) {				
				for (i in args.length...maxNumArgs)
					args[i] = null;
			}
			// In theory, the 'default' case would always work,
			// but we want to avoid the 'slice' allocations.
			
			switch (maxNumArgs)
			{
				case 0:func();
				case 1:func(args[0]);
				case 2:func(args[0], args[1]);
				case 3:func(args[0], args[1], args[2]);
				case 4:func(args[0], args[1], args[2], args[3]);
				case 5:func(args[0], args[1], args[2], args[3], args[4]);
				case 6:func(args[0], args[1], args[2], args[3], args[4], args[5]);
				case 7:func(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
			}
		}
	}

	public function new()
	{
	}
}

