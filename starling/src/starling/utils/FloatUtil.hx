package starling.utils;

/**
 * ...
 * @author P.J.Shand
 */
class FloatUtil
{

	public function new() 
	{
		
	}
	
	/**
	 * Returns a string representation of the number <code>x</code> in fixed-point notation.
	 * @param decimalPlaces the number of decimal places.
	 */
	public static function toFixed(x:Float, decimalPlaces:Int):String
	{
		if (Math.isNaN(x))
			return "NaN";
		else
		{
			var t = exp(10, decimalPlaces);
			var s = Std.string(Std.int(x * t) / t);
			var i = s.indexOf(".");
			if (i != -1)
			{
				for (i in s.substr(i + 1).length...decimalPlaces)
					s += "0";
			}
			else
			{
				s += ".";
				for (i in 0...decimalPlaces)
					s += "0";
			}
			return s;
		}
	}
	
	/**
	 * Fast integer exponentiation for base <code>a</code> and exponent <code>n</code>.
	 */
	public static function exp(a:Int, n:Int):Int
	{
		var t = 1;
		var r = 0;
		while (true)
		{
			if (n & 1 != 0) t = a * t;
			n >>= 1;
			if (n == 0)
			{
				r = t;
				break;
			}
			else
				a *= a;
		}
		return r;
	}
}