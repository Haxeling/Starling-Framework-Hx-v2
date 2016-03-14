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
import starling.animation.Tween;

import flash.utils.Dictionary;

import starling.events.Event;
import starling.events.EventDispatcher;

/** The Juggler takes objects that implement IAnimatable (like Tweens) and executes them.
 * 
 *  <p>A juggler is a simple object. It does no more than saving a list of objects implementing 
 *  "IAnimatable" and advancing their time if it is told to do so (by calling its own 
 *  "advanceTime"-method). When an animation is completed, it throws it away.</p>
 *  
 *  <p>There is a default juggler available at the Starling class:</p>
 *  
 *  <pre>
 *  var juggler:Juggler = Starling.Juggler;
 *  </pre>
 *  
 *  <p>You can create juggler objects yourself, just as well. That way, you can group 
 *  your game into logical components that handle their animations independently. All you have
 *  to do is call the "advanceTime" method on your custom juggler once per frame.</p>
 *  
 *  <p>Another handy feature of the juggler is the "delayCall"-method. Use it to 
 *  execute a function at a later time. Different to conventional approaches, the method
 *  will only be called when the juggler is advanced, giving you perfect control over the 
 *  call.</p>
 *  
 *  <pre>
 *  juggler.delayCall(object.removeFromParent, 1.0);
 *  juggler.delayCall(object.addChild, 2.0, theChild);
 *  juggler.delayCall(function():void { rotation += 0.1; }, 3.0);
 *  </pre>
 * 
 *  @see Tween
 *  @see DelayedCall 
 */
class Juggler implements IAnimatable
{
	public var elapsedTime(get, never):Float;
	private var objects(get, never):Array<IAnimatable>;

	private var _objects:Array<IAnimatable>;
	private var _objectIDs:Map<IAnimatable, Int>;
	private var _elapsedTime:Float;
	
	private static var sCurrentObjectID:Int;
	
	private static var tweenSetters:Array<String> = null;
	
	/** Create an empty juggler. */
	public function new()
	{
		_elapsedTime = 0;
		_objects = [];
		_objectIDs = new Map<IAnimatable, Int>();
		
		if (tweenSetters == null) {
			// Get all of the setters in the Tween class.
			tweenSetters = new Array<String>();
			for (field in Type.getInstanceFields(Tween)) {
				if (field.indexOf("set_") == 0) {
					tweenSetters.push(field.substr(4));
				}
			}
			tweenSetters.sort(function(a, b) return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
		}
	}
	
	/** Adds an object to the juggler.
	 *
	 *  @return Unique numeric identifier for the animation. This identifier may be used
	 *		  to remove the object via <code>removeByID()</code>.
	 */
	public function add(object:IAnimatable):Int
	{
		return addWithID(object, getNextID());
	}
	
	private function addWithID(object:IAnimatable, objectID:Int):Int
	{
		if (object != null && !contains(object)) 
		{
			var dispatcher:EventDispatcher = cast(object, EventDispatcher);
			if (dispatcher != null) dispatcher.addEventListener(Event.REMOVE_FROM_JUGGLER, onRemove);
			
			_objects[_objects.length] = object;
			_objectIDs.set(object, objectID);
			
			return objectID;
		}
		else return 0;
	}
	
	/** Determines if an object has been added to the juggler. */
	public function contains(object:IAnimatable):Bool
	{
		return _objectIDs.exists(object);
	}
	
	/** Removes an object from the juggler.
	 *
	 *  @return The (now meaningless) unique numeric identifier for the animation, or zero
	 *		  if the object was not found.
	 */
	public function remove(object:IAnimatable):Int
	{
		var objectID:Int = 0;
		
		if (object != null && contains(object)) 
		{
			var dispatcher:EventDispatcher = cast(object, EventDispatcher);
			if (dispatcher != null)	dispatcher.removeEventListener(Event.REMOVE_FROM_JUGGLER, onRemove);
			
			for (i in 0..._objects.length) 
			{
				if (_objects[i] == object) {
					_objects[i] = null;
					_objects.splice(i, 0);
				}
			}
			objectID = _objectIDs.get(object);
			_objectIDs.remove(object);
		}
		
		return objectID;
	}
	
	/** Removes an object from the juggler, identified by the unique numeric identifier you
	 *  received when adding it.
	 *
	 *  <p>It's not uncommon that an animatable object is added to a juggler repeatedly,
	 *  e.g. when using an object-pool. Thus, when using the <code>remove</code> method,
	 *  you might accidentally remove an object that has changed its context. By using
	 *  <code>removeByID</code> instead, you can be sure to avoid that, since the objectID
	 *  will always be unique.</p>
	 *
	 *  @return if successful, the passed objectID; if the object was not found, zero.
	 */
	public function removeByID(objectID:Int):Int
	{
		var i:Int = _objects.length - 1;
		while (i >= 0){
			var object:IAnimatable = _objects[i];
			
			if (_objectIDs.get(object) == objectID) 
			{
				remove(object);
				return objectID;
			}
			--i;
		}
		
		return 0;
	}
	
	/** Removes all tweens with a certain target. */
	public function removeTweens(target:Dynamic):Void
	{
		if (target == null)	return;
		
		var i:Int = _objects.length - 1;
		while (i >= 0){
			var tween:Tween = cast(_objects[i], Tween);
			if (tween != null && tween.target == target) 
			{
				tween.removeEventListener(Event.REMOVE_FROM_JUGGLER, onRemove);
				_objects[i] = null;
				_objectIDs.remove(tween);
			}
			--i;
		}
	}
	
	/** Removes all delayed and repeated calls with a certain callback. */
	public function removeDelayedCalls(callback:Function):Void
	{
		if (callback == null) return;
		
		var i:Int = _objects.length - 1;
		while (i >= 0){
			var delayedCall:DelayedCall = cast(_objects[i], DelayedCall);
			if (delayedCall != null && delayedCall.callback == callback) 
			{
				delayedCall.removeEventListener(Event.REMOVE_FROM_JUGGLER, onRemove);
				_objects[i] = null;
				_objectIDs.remove(delayedCall);
			}
			--i;
		}
	}
	
	/** Figures out if the juggler contains one or more tweens with a certain target. */
	public function containsTweens(target:Dynamic):Bool
	{
		if (target != null) 
		{
			var i:Int = _objects.length - 1;
			while (i >= 0){
				var tween:Tween = cast(_objects[i], Tween);
				if (tween != null && tween.target == target) return true;
				--i;
			}
		}
		
		return false;
	}
	
	/** Figures out if the juggler contains one or more delayed calls with a certain callback. */
	public function containsDelayedCalls(callback:Function):Bool
	{
		if (callback != null) 
		{
			var i:Int = _objects.length - 1;
			while (i >= 0){
				var delayedCall:DelayedCall = cast(_objects[i], DelayedCall);
				if (delayedCall != null && delayedCall.callback == callback) return true;
				--i;
			}
		}
		
		return false;
	}
	
	/** Removes all objects at once. */
	public function purge():Void
	{
		// the object vector is not purged right away, because if this method is called
		// from an 'advanceTime' call, this would make the loop crash. Instead, the
		// vector is filled with 'null' values. They will be cleaned up on the next call
		// to 'advanceTime'.
		
		var i:Int = _objects.length - 1;
		while (i >= 0){
			var object:IAnimatable = _objects[i];
			var dispatcher:EventDispatcher = cast(object, EventDispatcher);
			if (dispatcher != null) dispatcher.removeEventListener(Event.REMOVE_FROM_JUGGLER, onRemove);
			_objects[i] = null;
			_objectIDs.remove(object);
			--i;
		}
	}
	
	/** Delays the execution of a function until <code>delay</code> seconds have passed.
	 *  This method provides a convenient alternative for creating and adding a DelayedCall
	 *  manually.
	 *
	 *  @return Unique numeric identifier for the delayed call. This identifier may be used
	 *		  to remove the object via <code>removeByID()</code>.
	 */
	public function delayCall(call:Function, delay:Float, args:Array<Dynamic> = null):Int
	{
		if (call == null)			 throw new ArgumentError("call must not be null");
		
		var delayedCall:DelayedCall = DelayedCall.fromPool(call, delay, args);
		delayedCall.addEventListener(Event.REMOVE_FROM_JUGGLER, onPooledDelayedCallComplete);
		return add(delayedCall);
	}
	
	/** Runs a function at a specified interval (in seconds). A 'repeatCount' of zero
	 *  means that it runs indefinitely.
	 *
	 *  @return Unique numeric identifier for the delayed call. This identifier may be used
	 *		  to remove the object via <code>removeByID()</code>.
	 */
	public function repeatCall(call:Function, interval:Float, repeatCount:Int = 0, args:Array<Dynamic> = null):Int
	{
		if (call == null)			 throw new ArgumentError("call must not be null");
		
		var delayedCall:DelayedCall = DelayedCall.fromPool(call, interval, args);
		delayedCall.repeatCount = repeatCount;
		delayedCall.addEventListener(Event.REMOVE_FROM_JUGGLER, onPooledDelayedCallComplete);
		return add(delayedCall);
	}
	
	private function onPooledDelayedCallComplete(event:Event):Void
	{
		DelayedCall.toPool(cast(event.target, DelayedCall));
	}
	
	/** Utilizes a tween to animate the target object over <code>time</code> seconds. Internally,
	 *  this method uses a tween instance (taken from an object pool) that is added to the
	 *  juggler right away. This method provides a convenient alternative for creating 
	 *  and adding a tween manually.
	 *  
	 *  <p>Fill 'properties' with key-value pairs that describe both the 
	 *  tween and the animation target. Here is an example:</p>
	 *  
	 *  <pre>
	 *  juggler.tween(object, 2.0, {
	 *	  transition: Transitions.EASE_IN_OUT,
	 *	  delay: 20, // -> tween.delay = 20
	 *	  x: 50	  // -> tween.animate("x", 50)
	 *  });
	 *  </pre> 
	 *
	 *  <p>To cancel the tween, call 'Juggler.removeTweens' with the same target, or pass
	 *  the returned 'IAnimatable' instance to 'Juggler.remove()'. Do not use the returned
	 *  IAnimatable otherwise; it is taken from a pool and will be reused.</p>
	 *
	 *  <p>Note that some property types may be animated in a special way:</p>
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
	public function tween(target:Dynamic, time:Float, properties:Dynamic):Int
	{
		if (target == null)			 throw new ArgumentError("target must not be null");
		
		var tween:Tween = Tween.fromPool(target, time);
		
		for (property in Reflect.fields(properties))
		{
			var value:Dynamic = Reflect.field(properties, property);
			if (tweenSetters.indexOf(property) >= 0) {
				Reflect.setProperty(tween, property, value);
			} else {
				var currentValue:Dynamic = Reflect.getProperty(target, property);
				if (currentValue == null) {
					throw new ArgumentError("Invalid property: " + property);
				}
				tween.animate(property, cast value);
			}
		}
		
		tween.addEventListener(Event.REMOVE_FROM_JUGGLER, onPooledTweenComplete);
		return add(tween);
	}
	
	private function onPooledTweenComplete(event:Event):Void
	{
		Tween.toPool(cast(event.target, Tween));
	}
	
	/** Advances all objects by a certain time (in seconds). */
	public function advanceTime(time:Float):Void
	{
		var numObjects:Int = _objects.length;
		var currentIndex:Int = 0;
		var i:Int;
		
		_elapsedTime += time;
		if (numObjects == 0) return;
		
		// there is a high probability that the "advanceTime" function modifies the list  ;
		// of animatables. we must not process new objects right now (they will be processed	
		// in the next frame), and we need to clean up any empty slots in the list.	
		
		var i:Int = 0;
		for (i in 0...numObjects){
			var object:IAnimatable = _objects[i];
			if (object != null) 
			{
				// shift objects into empty slots along the way
				if (currentIndex != i) 
				{
					_objects[currentIndex] = object;
					_objects[i] = null;
				}
				
				object.advanceTime(time);
				++currentIndex;
			}
		}
		
		if (currentIndex != i) 
		{
			numObjects = _objects.length;  // count might have changed!  
			
			while (i < numObjects)
			_objects[cast(currentIndex++, Int)] = _objects[cast(i++, Int)];
			
			_objects.splice(currentIndex, _objects.length - currentIndex);
		}
	}
	
	private function onRemove(event:Event):Void
	{
		var objectID:Int = remove(cast(event.target, IAnimatable));
		
		if (objectID != 0) 
		{
			var tween:Tween = cast(event.target, Tween);
			if (tween != null && tween.isComplete) 
				addWithID(tween.nextTween, objectID);
		}
	}
	
	private static function getNextID():Int
	{
		return ++sCurrentObjectID;
	}
	
	/** The total life time of the juggler (in seconds). */
	private function get_elapsedTime():Float
	{
		return _elapsedTime;
	}
	
	/** The actual vector that contains all objects that are currently being animated. */
	private function get_objects():Array<IAnimatable>
	{
		return _objects;
	}
}

