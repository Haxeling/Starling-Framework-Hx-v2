// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================


package starling.animation;

import flash.errors.ArgumentError;
import haxe.Constraints.Function;

import starling.events.Event;
import starling.events.EventDispatcher;

/** A Tween animates numeric properties of objects. It uses different transition functions
 *  to give the animations various styles.
 *  
 *  <p>The primary use of this class is to do standard animations like movement, fading, 
 *  rotation, etc. But there are no limits on what to animate; as long as the property you want
 *  to animate is numeric (<code>int, uint, Number</code>), the tween can handle it. For a list 
 *  of available Transition types, look at the "Transitions" class.</p> 
 *  
 *  <p>Here is an example of a tween that moves an object to the right, rotates it, and 
 *  fades it out:</p>
 *  
 *  <listing>
 *  var tween:Tween = new Tween(object, 2.0, Transitions.EASE_IN_OUT);
 *  tween.animate("x", object.x + 50);
 *  tween.animate("rotation", Deg2rad.call(45));
 *  tween.fadeTo(0);	// equivalent to 'animate("alpha", 0)'
 *  Starling.Juggler.add(tween);</listing> 
 *  
 *  <p>Note that the object is added to a juggler at the end of this sample. That's because a 
 *  tween will only be executed if its "advanceTime" method is executed regularly - the 
 *  juggler will do that for you, and will remove the tween when it is finished.</p>
 *  
 *  @see Juggler
 *  @see Transitions
 */
class Tween extends EventDispatcher implements IAnimatable
{
	public var isComplete(get, never):Bool;
	public var target(get, never):Dynamic;
	public var transition(get, set):String;
	public var transitionFunc(get, set):Function;
	public var totalTime(get, never):Float;
	public var currentTime(get, never):Float;
	public var progress(get, never):Float;
	public var delay(get, set):Float;
	public var repeatCount(get, set):Int;
	public var repeatDelay(get, set):Float;
	public var reverse(get, set):Bool;
	public var roundToInt(get, set):Bool;
	public var onStart(get, set):Function;
	public var onUpdate(get, set):Function;
	public var onRepeat(get, set):Function;
	public var onComplete(get, set):Function;
	public var onStartArgs(get, set):Array<Dynamic>;
	public var onUpdateArgs(get, set):Array<Dynamic>;
	public var onRepeatArgs(get, set):Array<Dynamic>;
	public var onCompleteArgs(get, set):Array<Dynamic>;
	public var nextTween(get, set):Tween;

	private static var HINT_MARKER:String = "#";
	
	private var _target:Dynamic;
	private var _transitionFunc:Function;
	private var _transitionName:String;
	
	private var _properties:Array<String>;
	private var _startValues:Array<Float>;
	private var _endValues:Array<Float>;
	private var _updateFuncs:Array<Function>;
	
	private var _onStart:Function;
	private var _onUpdate:Function;
	private var _onRepeat:Function;
	private var _onComplete:Function;
	
	private var _onStartArgs:Array<Dynamic>;
	private var _onUpdateArgs:Array<Dynamic>;
	private var _onRepeatArgs:Array<Dynamic>;
	private var _onCompleteArgs:Array<Dynamic>;
	
	private var _totalTime:Float;
	private var _currentTime:Float;
	private var _progress:Float;
	private var _delay:Float;
	private var _roundToInt:Bool;
	private var _nextTween:Tween;
	private var _repeatCount:Int;
	private var _repeatDelay:Float;
	private var _reverse:Bool;
	private var _currentCycle:Int;
	
	/** Creates a tween with a target, duration (in seconds) and a transition function.
	 *  @param target the object that you want to animate
	 *  @param time the duration of the Tween (in seconds)
	 *  @param transition can be either a String (e.g. one of the constants defined in the
	 *		 Transitions class) or a function. Look up the 'Transitions' class for a   
	 *		 documentation about the required function signature. */
	public function new(target:Dynamic, time:Float, transition:Dynamic = "linear")
	{
		super();
		reset(target, time, transition);
	}
	
	/** Resets the tween to its default values. Useful for pooling tweens. */
	public function reset(target:Dynamic, time:Float, transition:Dynamic = "linear"):Tween
	{
		_target = target;
		_currentTime = 0.0;
		_totalTime = Math.max(0.0001, time);
		_progress = 0.0;
		_delay = _repeatDelay = 0.0;
		_onStart = _onUpdate = _onRepeat = _onComplete = null;
		_onStartArgs = _onUpdateArgs = _onRepeatArgs = _onCompleteArgs = null;
		_roundToInt = _reverse = false;
		_repeatCount = 1;
		_currentCycle = -1;
		_nextTween = null;
		
		
		if (Std.is(transition, String)) 
			this.transition = cast(transition, String);
		else if (Reflect.isFunction(transition)) 
			this.transitionFunc = cast(transition);
		else 
		throw new ArgumentError("Transition must be either a string or a function");
		
		if (_properties != null) _properties.splice(0, _properties.length);
		else _properties = [];
		if (_startValues != null) _startValues.splice(0, _startValues.length);
		else _startValues = [];
		if (_endValues != null) _endValues.splice(0, _endValues.length);
		else _endValues = [];
		if (_updateFuncs != null) _updateFuncs.splice(0, _updateFuncs.length);
		else _updateFuncs = [];
		
		return this;
	}
	
	/** Animates the property of the target to a certain value. You can call this method
	 *  multiple times on one tween.
	 *
	 *  <p>Some property types are handled in a special way:</p>
	 *  <ul>
	 *	<li>If the property contains the string <code>color</code> or <code>Color</code>,
	 *		it will be treated as an unsigned integer with a color value
	 *		(e.g. <code>0xff0000</code> for red). Each color channel will be animated
	 *		individually.</li>
	 *	<li>The same happens if you append the string <code>#rgb</code> to the name.</li>
	 *	<li>If you append <code>#rad</code>, the property is treated as an angle in radians,
	 *		making sure it always uses the shortest possible arc for the rotation.</li>
	 *	<li>The string <code>#deg</code> does the same for angles in degrees.</li>
	 *  </ul>
	 */
	public function animate(property:String, endValue:Float):Void
	{
		if (_target == null) return; // tweening null just does nothing.
		
		var pos:Int = _properties.length;
		var updateFunc:Function = getUpdateFuncFromProperty(property);
		
		_properties[pos] = getPropertyName(property);
		_startValues[pos] = Math.NaN;
		_endValues[pos] = endValue;
		_updateFuncs[pos] = updateFunc;
	}
	
	/** Animates the 'scaleX' and 'scaleY' properties of an object simultaneously. */
	public function scaleTo(factor:Float):Void
	{
		animate("scaleX", factor);
		animate("scaleY", factor);
	}
	
	/** Animates the 'x' and 'y' properties of an object simultaneously. */
	public function moveTo(x:Float, y:Float):Void
	{
		animate("x", x);
		animate("y", y);
	}
	
	/** Animates the 'alpha' property of an object to a certain target value. */
	public function fadeTo(alpha:Float):Void
	{
		animate("alpha", alpha);
	}
	
	/** Animates the 'rotation' property of an object to a certain target value, using the
	 *  smallest possible arc. 'type' may be either 'rad' or 'deg', depending on the unit of
	 *  measurement. */
	public function rotateTo(angle:Float, type:String = "rad"):Void
	{
		animate("rotation#" + type, angle);
	}
	
	/** @inheritDoc */
	public function advanceTime(time:Float):Void
	{
		if (time == 0 || (_repeatCount == 1 && _currentTime == _totalTime))	return;
		
		var i:Int;
		var previousTime:Float = _currentTime;
		var restTime:Float = _totalTime - _currentTime;
		var carryOverTime:Float = time > restTime ? time - restTime : 0.0;
		
		_currentTime += time;
		
		if (_currentTime <= 0) return;
			
		// the delay is not over yet
		else if (_currentTime > _totalTime) 
			_currentTime = _totalTime;
		
		if (_currentCycle < 0 && previousTime <= 0 && _currentTime > 0) 
		{
			_currentCycle++;
			if (_onStart != null)				 _onStart(_onStartArgs);
		}
		
		var ratio:Float = _currentTime / _totalTime;
		var reversed:Bool = _reverse && (_currentCycle % 2 == 1);
		var numProperties:Int = _startValues.length;
		_progress = (reversed) ? _transitionFunc(1.0 - ratio):_transitionFunc(ratio);
		
		for (i in 0...numProperties){
			if (_startValues[i] != _startValues[i])				   // isNaN check - "isNaN" causes allocation!  
			_startValues[i] = cast(Reflect.field(_target, Std.string(_properties[i])), Float);
			
			var updateFunc:Function = _updateFuncs[i];
			updateFunc(_properties[i], _startValues[i], _endValues[i]);
		}
		
		if (_onUpdate != null) {
			_onUpdate(_onUpdateArgs);
		}
		
		if (previousTime < _totalTime && _currentTime >= _totalTime) 
		{
			if (_repeatCount == 0 || _repeatCount > 1) 
			{
				_currentTime = -_repeatDelay;
				_currentCycle++;
				if (_repeatCount > 1)					 _repeatCount--;
				if (_onRepeat != null)					 _onRepeat(_onRepeatArgs);
			}
			else 
			{
				// save callback & args: they might be changed through an event listener
				var onComplete:Function = _onComplete;
				var onCompleteArgs:Array<Dynamic> = _onCompleteArgs;
				
				// in the 'onComplete' callback, people might want to call "tween.reset" and
				// add it to another juggler; so this event has to be dispatched *before*
				// executing 'onComplete'.
				dispatchEventWith(Event.REMOVE_FROM_JUGGLER);
				if (onComplete != null) onComplete(onCompleteArgs);
			}
		}
		
		if (carryOverTime != 0) 
			advanceTime(carryOverTime);
	}
	
	// animation hints
	
	private function getUpdateFuncFromProperty(property:String):Function
	{
		var updateFunc:Function;
		var hint:String = getPropertyHint(property);
		
		switch (hint)
		{
			case null:updateFunc = updateStandard;
			case "rgb":updateFunc = updateRgb;
			case "rad":updateFunc = updateRad;
			case "deg":updateFunc = updateDeg;
			default:
				trace("[Starling] Ignoring unknown property hint:", hint);
				updateFunc = updateStandard;
		}
		
		return updateFunc;
	}
	
	/** @private */
	@:allow(starling.animation)
	private static function getPropertyHint(property:String):String
	{
		// colorization is special; it does not require a hint marker, just the word 'color'.
		if (property.indexOf("color") != -1 || property.indexOf("Color") != -1) 
			return "rgb";
		
		var hintMarkerIndex:Int = property.indexOf(HINT_MARKER);
		if (hintMarkerIndex != -1)			 return property.substr(hintMarkerIndex + 1)
		else return null;
	}
	
	/** @private */
	@:allow(starling.animation)
	private static function getPropertyName(property:String):String
	{
		var hintMarkerIndex:Int = property.indexOf(HINT_MARKER);
		if (hintMarkerIndex != -1)			 return property.substring(0, hintMarkerIndex)
		else return property;
	}
	
	private function updateStandard(property:String, startValue:Float, endValue:Float):Void
	{
		var newValue:Float = startValue + _progress * (endValue - startValue);
		if (_roundToInt)			 newValue = Math.round(newValue);
		Reflect.setField(_target, property, newValue);
	}
	
	private function updateRgb(property:String, startValue:Float, endValue:Float):Void
	{
		var startColor:Int = cast(startValue, Int);
		var endColor:Int = cast(endValue, Int);
		
		var startA:Int = (startColor >> 24) & 0xff;
		var startR:Int = (startColor >> 16) & 0xff;
		var startG:Int = (startColor >> 8) & 0xff;
		var startB:Int = (startColor) & 0xff;
		
		var endA:Int = (endColor >> 24) & 0xff;
		var endR:Int = (endColor >> 16) & 0xff;
		var endG:Int = (endColor >> 8) & 0xff;
		var endB:Int = (endColor) & 0xff;
		
		var newA:Int = untyped startA + (endA - startA) * _progress;
		var newR:Int = untyped startR + (endR - startR) * _progress;
		var newG:Int = untyped startG + (endG - startG) * _progress;
		var newB:Int = untyped startB + (endB - startB) * _progress;
		
		Reflect.setField(_target, property, (newA << 24) | (newR << 16) | (newG << 8) | newB);
	}
	
	private function updateRad(property:String, startValue:Float, endValue:Float):Void
	{
		updateAngle(Math.PI, property, startValue, endValue);
	}
	
	private function updateDeg(property:String, startValue:Float, endValue:Float):Void
	{
		updateAngle(180, property, startValue, endValue);
	}
	
	private function updateAngle(pi:Float, property:String, startValue:Float, endValue:Float):Void
	{
		while (Math.abs(endValue - startValue) > pi)
		{
			if (startValue < endValue)				 endValue -= 2.0 * pi
			else endValue += 2.0 * pi;
		}
		
		updateStandard(property, startValue, endValue);
	}
	
	/** The end value a certain property is animated to. Throws an ArgumentError if the 
	 *  property is not being animated. */
	public function getEndValue(property:String):Float
	{
		var index:Int = Lambda.indexOf(_properties, property);
		if (index == -1)			 throw new ArgumentError("The property '" + property + "' is not animated")
		else return cast(_endValues[index], Float);
	}
	
	/** Indicates if the tween is finished. */
	private function get_isComplete():Bool
	{
		return _currentTime >= _totalTime && _repeatCount == 1;
	}
	
	/** The target object that is animated. */
	private function get_target():Dynamic
	{
		return _target;
	}
	
	/** The transition method used for the animation. @see Transitions */
	private function get_transition():String
	{
		return _transitionName;
	}
	
	private function set_transition(value:String):String
	{
		_transitionName = value;
		_transitionFunc = Transitions.getTransition(value);
		
		if (_transitionFunc == null) 
			throw new ArgumentError("Invalid transiton: " + value);
		return value;
	}
	
	/** The actual transition function used for the animation. */
	private function get_transitionFunc():Function
	{
		return _transitionFunc;
	}
	
	private function set_transitionFunc(value:Function):Function
	{
		_transitionName = "custom";
		_transitionFunc = value;
		return value;
	}
	
	/** The total time the tween will take per repetition (in seconds). */
	private function get_totalTime():Float
	{
		return _totalTime;
	}
	
	/** The time that has passed since the tween was created (in seconds). */
	private function get_currentTime():Float
	{
		return _currentTime;
	}
	
	/** The current progress between 0 and 1, as calculated by the transition function. */
	private function get_progress():Float
	{
		return _progress;
	}
	
	/** The delay before the tween is started (in seconds). @default 0 */
	private function get_delay():Float
	{
		return _delay;
	}
	
	private function set_delay(value:Float):Float
	{
		_currentTime = _currentTime + _delay - value;
		_delay = value;
		return value;
	}
	
	/** The number of times the tween will be executed. 
	 *  Set to '0' to tween indefinitely. @default 1 */
	private function get_repeatCount():Int
	{
		return _repeatCount;
	}
	
	private function set_repeatCount(value:Int):Int
	{
		_repeatCount = value;
		return value;
	}
	
	/** The amount of time to wait between repeat cycles (in seconds). @default 0 */
	private function get_repeatDelay():Float
	{
		return _repeatDelay;
	}
	
	private function set_repeatDelay(value:Float):Float
	{
		_repeatDelay = value;
		return value;
	}
	
	/** Indicates if the tween should be reversed when it is repeating. If enabled, 
	 *  every second repetition will be reversed. @default false */
	private function get_reverse():Bool
	{
		return _reverse;
	}
	
	private function set_reverse(value:Bool):Bool
	{
		_reverse = value;
		return value;
	}
	
	/** Indicates if the numeric values should be cast to Integers. @default false */
	private function get_roundToInt():Bool
	{
		return _roundToInt;
	}
	
	private function set_roundToInt(value:Bool):Bool
	{
		_roundToInt = value;
		return value;
	}
	
	/** A function that will be called when the tween starts (after a possible delay). */
	private function get_onStart():Function
	{
		return _onStart;
	}
	
	private function set_onStart(value:Function):Function
	{
		_onStart = value;
		return value;
	}
	
	/** A function that will be called each time the tween is advanced. */
	private function get_onUpdate():Function
	{
		return _onUpdate;
	}
	
	private function set_onUpdate(value:Function):Function
	{
		_onUpdate = value;
		return value;
	}
	
	/** A function that will be called each time the tween finishes one repetition
	 *  (except the last, which will trigger 'onComplete'). */
	private function get_onRepeat():Function
	{
		return _onRepeat;
	}
	
	private function set_onRepeat(value:Function):Function
	{
		_onRepeat = value;
		return value;
	}
	
	/** A function that will be called when the tween is complete. */
	private function get_onComplete():Function
	{
		return _onComplete;
	}
	
	private function set_onComplete(value:Function):Function
	{
		_onComplete = value;
		return value;
	}
	
	/** The arguments that will be passed to the 'onStart' function. */
	private function get_onStartArgs():Array<Dynamic>
	{
		return _onStartArgs;
	}
	
	private function set_onStartArgs(value:Array<Dynamic>):Array<Dynamic>
	{
		_onStartArgs = value;
		return value;
	}
	
	/** The arguments that will be passed to the 'onUpdate' function. */
	private function get_onUpdateArgs():Array<Dynamic>
	{
		return _onUpdateArgs;
	}
	
	private function set_onUpdateArgs(value:Array<Dynamic>):Array<Dynamic>
	{
		_onUpdateArgs = value;
		return value;
	}
	
	/** The arguments that will be passed to the 'onRepeat' function. */
	private function get_onRepeatArgs():Array<Dynamic>
	{
		return _onRepeatArgs;
	}
	
	private function set_onRepeatArgs(value:Array<Dynamic>):Array<Dynamic>
	{
		_onRepeatArgs = value;
		return value;
	}
	
	/** The arguments that will be passed to the 'onComplete' function. */
	private function get_onCompleteArgs():Array<Dynamic>
	{
		return _onCompleteArgs;
	}
	
	private function set_onCompleteArgs(value:Array<Dynamic>):Array<Dynamic>
	{
		_onCompleteArgs = value;
		return value;
	}
	
	/** Another tween that will be started (i.e. added to the same juggler) as soon as 
	 *  this tween is completed. */
	private function get_nextTween():Tween
	{
		return _nextTween;
	}
	
	private function set_nextTween(value:Tween):Tween
	{
		_nextTween = value;
		return value;
	}
	
	// tween pooling
	
	private static var sTweenPool:Array<Tween> = [];
	
	/** @private */
	@:allow(starling.animation)
	private static function fromPool(target:Dynamic, time:Float, transition:Dynamic = "linear"):Tween
	{
		if (sTweenPool.length > 0) return sTweenPool.pop().reset(target, time, transition)
		else return new Tween(target, time, transition);
	}
	
	/** @private */
	@:allow(starling.animation)
	private static function toPool(tween:Tween):Void
	{
		// reset any object-references, to make sure we don't prevent any garbage collection
		tween._onStart = tween._onUpdate = tween._onRepeat = tween._onComplete = null;
		tween._onStartArgs = tween._onUpdateArgs = tween._onRepeatArgs = tween._onCompleteArgs = null;
		tween._target = null;
		tween._transitionFunc = null;
		tween.removeEventListeners();
		sTweenPool.push(tween);
	}
}

