// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.display;

import openfl.errors.ArgumentError;
import starling.display.DisplayObjectContainer;
import starling.display.Image;
import starling.display.Sprite;

import openfl.geom.Rectangle;
import flash.ui.Mouse;
import flash.ui.MouseCursor;

import starling.events.Event;
import starling.events.Touch;
import starling.events.TouchEvent;
import starling.events.TouchPhase;
import starling.text.TextField;
import starling.text.TextFormat;
import starling.textures.Texture;
import starling.utils.RectangleUtil;

/** Dispatched when the user triggers the button. Bubbles. */
@:meta(Event(name="triggered",type="starling.events.Event"))


/** A simple button composed of an image and, optionally, text.
 *  
 *  <p>You can use different textures for various states of the button. If you're providing
 *  only an up state, the button is simply scaled a little when it is touched.</p>
 *
 *  <p>In addition, you can overlay text on the button. To customize the text, you can use
 *  properties equivalent to those of the TextField class. Move the text to a certain position
 *  by updating the <code>textBounds</code> property.</p>
 *  
 *  <p>To react on touches on a button, there is special <code>Event.TRIGGERED</code> event.
 *  Use this event instead of normal touch events. That way, users can cancel button
 *  activation by moving the mouse/finger away from the button before releasing.</p>
 */
class Button extends DisplayObjectContainer
{
	public var state(get, set):String;
	public var scaleWhenDown(get, set):Float;
	public var scaleWhenOver(get, set):Float;
	public var alphaWhenDown(get, set):Float;
	public var alphaWhenDisabled(get, set):Float;
	public var enabled(get, set):Bool;
	public var text(get, set):String;
	public var textFormat(get, set):TextFormat;
	public var upState(get, set):Texture;
	public var downState(get, set):Texture;
	public var overState(get, set):Texture;
	public var disabledState(get, set):Texture;
	public var textBounds(get, set):Rectangle;
	public var color(get, set):Int;
	public var textureSmoothing(get, set):String;
	public var overlay(get, never):Sprite;
	public var scale9Grid(get, set):Rectangle;

	private static var MAX_DRAG_DIST:Float = 50;
	
	private var _upState:Texture;
	private var _downState:Texture;
	private var _overState:Texture;
	private var _disabledState:Texture;
	
	private var _contents:Sprite;
	private var _body:Image;
	private var _textField:TextField;
	private var _textBounds:Rectangle;
	private var _overlay:Sprite;
	
	private var _scaleWhenDown:Float;
	private var _scaleWhenOver:Float;
	private var _alphaWhenDown:Float;
	private var _alphaWhenDisabled:Float;
	private var _enabled:Bool;
	private var _state:String;
	private var _triggerBounds:Rectangle;
	
	/** Creates a button with a set of state-textures and (optionally) some text.
	 *  Any state that is left 'null' will display the up-state texture. Beware that all
	 *  state textures should have the same dimensions. */
	public function new(upState:Texture, text:String = "", downState:Texture = null,
			overState:Texture = null, disabledState:Texture = null)
	{
		super();
		if (upState == null) throw new ArgumentError("Texture 'upState' cannot be null");
		
		_upState = upState;
		_downState = downState;
		_overState = overState;
		_disabledState = disabledState;
		
		_state = ButtonState.UP;
		_body = new Image(upState);
		_scaleWhenDown = (downState != null) ? 1.0:0.9;
		_scaleWhenOver = _alphaWhenDown = 1.0;
		_alphaWhenDisabled = (disabledState != null) ? 1.0:0.5;
		_enabled = true;
		_useHandCursor = true;
		_textBounds = new Rectangle(0, 0, _body.width, _body.height);
		_triggerBounds = new Rectangle();
		
		_contents = new Sprite();
		_contents.addChild(_body);
		addChild(_contents);
		addEventListener(TouchEvent.TOUCH, onTouch);
		
		this.touchGroup = true;
		this.text = text;
	}
	
	/** @inheritDoc */
	override public function dispose():Void
	{
		// text field might be disconnected from parent, so we have to dispose it manually
		if (_textField != null) 
			_textField.dispose();
		
		super.dispose();
	}
	
	/** Readjusts the dimensions of the button according to its current state texture.
	 *  Call this method to synchronize button and texture size after assigning a texture
	 *  with a different size. */
	public function readjustSize():Void
	{
		var prevWidth:Float = _body.width;
		var prevHeight:Float = _body.height;
		
		_body.readjustSize();
		
		var scaleX:Float = _body.width / prevWidth;
		var scaleY:Float = _body.height / prevHeight;
		
		_textBounds.x *= scaleX;
		_textBounds.y *= scaleY;
		_textBounds.width *= scaleX;
		_textBounds.height *= scaleY;
		
		if (_textField != null) createTextField();
	}
	
	private function createTextField():Void
	{
		if (_textField == null) 
		{
			_textField = new TextField(untyped _textBounds.width, untyped _textBounds.height);
			_textField.touchable = false;
			_textField.autoScale = true;
			_textField.batchable = true;
		}
		
		_textField.width = _textBounds.width;
		_textField.height = _textBounds.height;
		_textField.x = _textBounds.x;
		_textField.y = _textBounds.y;
	}
	
	override private function onTouch(event:TouchEvent):Void
	{
		Mouse.cursor = ((_useHandCursor && _enabled && event.interactsWith(this))) ? 
				MouseCursor.BUTTON:MouseCursor.AUTO;
		
		var touch:Touch = event.getTouch(this);
		var isWithinBounds:Bool;
		
		if (!_enabled) 
		{
			return;
		}
		else if (touch == null) 
		{
			state = ButtonState.UP;
		}
		else if (touch.phase == TouchPhase.HOVER) 
		{
			state = ButtonState.OVER;
		}
		else if (touch.phase == TouchPhase.BEGAN && _state != ButtonState.DOWN) 
		{
			_triggerBounds = getBounds(stage, _triggerBounds);
			_triggerBounds.inflate(MAX_DRAG_DIST, MAX_DRAG_DIST);
			
			state = ButtonState.DOWN;
		}
		else if (touch.phase == TouchPhase.MOVED) 
		{
			isWithinBounds = _triggerBounds.contains(touch.globalX, touch.globalY);
			
			if (_state == ButtonState.DOWN && !isWithinBounds) 
			{
				// reset button when finger is moved too far away ...
				state = ButtonState.UP;
			}
			else if (_state == ButtonState.UP && isWithinBounds) 
			{
				// ... and reactivate when the finger moves back into the bounds.
				state = ButtonState.DOWN;
			}
		}
		else if (touch.phase == TouchPhase.ENDED && _state == ButtonState.DOWN) 
		{
			state = ButtonState.UP;
			if (!touch.cancelled)				 dispatchEventWith(Event.TRIGGERED, true);
		}
	}
	
	/** The current state of the button. The corresponding strings are found
	 *  in the ButtonState class. */
	private function get_state():String
	{
		return _state;
	}
	
	private function set_state(value:String):String
	{
		_state = value;
		_contents.x = _contents.y = 0;
		_contents.scaleX = _contents.scaleY = _contents.alpha = 1.0;
		
		switch (_state)
		{
			case ButtonState.DOWN:
				setStateTexture(_downState);
				_contents.alpha = _alphaWhenDown;
				_contents.scaleX = _contents.scaleY = _scaleWhenDown;
				_contents.x = (1.0 - _scaleWhenDown) / 2.0 * _body.width;
				_contents.y = (1.0 - _scaleWhenDown) / 2.0 * _body.height;
			case ButtonState.UP:
				setStateTexture(_upState);
			case ButtonState.OVER:
				setStateTexture(_overState);
				_contents.scaleX = _contents.scaleY = _scaleWhenOver;
				_contents.x = (1.0 - _scaleWhenOver) / 2.0 * _body.width;
				_contents.y = (1.0 - _scaleWhenOver) / 2.0 * _body.height;
			case ButtonState.DISABLED:
				setStateTexture(_disabledState);
				_contents.alpha = _alphaWhenDisabled;
			default:
				throw new ArgumentError("Invalid button state: " + _state);
		}
		return value;
	}
	
	private function setStateTexture(texture:Texture):Void
	{
		_body.texture = (texture != null) ? texture:_upState;
	}
	
	/** The scale factor of the button on touch. Per default, a button without a down state
	 *  texture will be made slightly smaller, while a button with a down state texture
	 *  remains unscaled. */
	private function get_scaleWhenDown():Float
	{
		return _scaleWhenDown;
	}
	
	private function set_scaleWhenDown(value:Float):Float
	{
		_scaleWhenDown = value;
		return value;
	}
	
	/** The scale factor of the button while the mouse cursor hovers over it. @default 1.0 */
	private function get_scaleWhenOver():Float
	{
		return _scaleWhenOver;
	}
	
	private function set_scaleWhenOver(value:Float):Float
	{
		_scaleWhenOver = value;
		return value;
	}
	
	/** The alpha value of the button on touch. @default 1.0 */
	private function get_alphaWhenDown():Float
	{
		return _alphaWhenDown;
	}
	
	private function set_alphaWhenDown(value:Float):Float
	{
		_alphaWhenDown = value;
		return value;
	}
	
	/** The alpha value of the button when it is disabled. @default 0.5 */
	private function get_alphaWhenDisabled():Float
	{
		return _alphaWhenDisabled;
	}
	
	private function set_alphaWhenDisabled(value:Float):Float
	{
		_alphaWhenDisabled = value;
		return value;
	}
	
	/** Indicates if the button can be triggered. */
	private function get_enabled():Bool
	{
		return _enabled;
	}
	
	private function set_enabled(value:Bool):Bool
	{
		if (_enabled != value) 
		{
			_enabled = value;
			state = (value) ? ButtonState.UP:ButtonState.DISABLED;
		}
		return value;
	}
	
	/** The text that is displayed on the button. */
	private function get_text():String
	{
		return (_textField != null) ? _textField.text:"";
	}
	
	private function set_text(value:String):String
	{
		if (value.length == 0) 
		{
			if (_textField != null) 
			{
				_textField.text = value;
				_textField.removeFromParent();
			}
		}
		else 
		{
			createTextField();
			_textField.text = value;
			
			if (_textField.parent == null) 
				_contents.addChild(_textField);
		}
		return value;
	}
	
	/** The format of the button's TextField. */
	private function get_textFormat():TextFormat
	{
		if (_textField == null) createTextField();
		return _textField.format;
	}
	
	private function set_textFormat(value:TextFormat):TextFormat
	{
		if (_textField == null)	createTextField();
		_textField.format = value;
		return value;
	}
	
	/** The texture that is displayed when the button is not being touched. */
	private function get_upState():Texture
	{
		return _upState;
	}
	
	private function set_upState(value:Texture):Texture
	{
		if (value == null) 
			throw new ArgumentError("Texture 'upState' cannot be null");
		
		if (_upState != value) 
		{
			_upState = value;
			if (_state == ButtonState.UP ||
				(_state == ButtonState.DISABLED && _disabledState == null) ||
				(_state == ButtonState.DOWN && _downState == null) ||
				(_state == ButtonState.OVER && _overState == null)) 
			{
				setStateTexture(value);
			}
		}
		return value;
	}
	
	/** The texture that is displayed while the button is touched. */
	private function get_downState():Texture
	{
		return _downState;
	}
	
	private function set_downState(value:Texture):Texture
	{
		if (_downState != value) 
		{
			_downState = value;
			if (_state == ButtonState.DOWN) setStateTexture(value);
		}
		return value;
	}
	
	/** The texture that is displayed while mouse hovers over the button. */
	private function get_overState():Texture
	{
		return _overState;
	}
	
	private function set_overState(value:Texture):Texture
	{
		if (_overState != value) 
		{
			_overState = value;
			if (_state == ButtonState.OVER) setStateTexture(value);
		}
		return value;
	}
	
	/** The texture that is displayed when the button is disabled. */
	private function get_disabledState():Texture
	{
		return _disabledState;
	}
	
	private function set_disabledState(value:Texture):Texture
	{
		if (_disabledState != value) 
		{
			_disabledState = value;
			if (_state == ButtonState.DISABLED) setStateTexture(value);
		}
		return value;
	}
	
	/** The bounds of the button's TextField. Allows moving the text to a custom position.
	 *  CAUTION: not a copy, but the actual object! Text will only update on re-assignment.
	 */
	private function get_textBounds():Rectangle
	{
		return _textBounds;
	}
	
	private function set_textBounds(value:Rectangle):Rectangle
	{
		_textBounds.copyFrom(value);
		createTextField();
		return value;
	}
	
	/** The color of the button's state image. Just like every image object, each pixel's
	 *  color is multiplied with this value. @default white */
	private function get_color():Int
	{
		return _body.color;
	}
	
	private function set_color(value:Int):Int
	{
		_body.color = value;
		return value;
	}
	
	/** The smoothing type used for the button's state image. */
	private function get_textureSmoothing():String
	{
		return _body.textureSmoothing;
	}
	
	private function set_textureSmoothing(value:String):String
	{
		_body.textureSmoothing = value;
		return value;
	}
	
	/** The overlay sprite is displayed on top of the button contents. It scales with the
	 *  button when pressed. Use it to add additional objects to the button (e.g. an icon). */
	private function get_overlay():Sprite
	{
		if (_overlay == null) 
			_overlay = new Sprite();
		
		_contents.addChild(_overlay);  // make sure it's always on top  
		return _overlay;
	}
	
	/** Indicates if the mouse cursor should transform into a hand while it's over the button. 
	 *  @default true */
	override private function get_useHandCursor():Bool
	{
		return _useHandCursor;
	}
	
	override private function set_useHandCursor(value:Bool):Bool
	{
		_useHandCursor = value;
		return value;
	}
	
	/** @private */
	override private function set_width(value:Float):Float
	{
		var scaleX:Float = value / _body.width;
		
		_body.width = value;
		_textBounds.x *= scaleX;
		_textBounds.width *= scaleX;
		
		if (_textField != null) _textField.width = value;
		return value;
	}
	
	override private function set_height(value:Float):Float
	{
		var scaleY:Float = value / _body.height;
		
		_body.height = value;
		_textBounds.y *= scaleY;
		_textBounds.height *= scaleY;
		
		if (_textField != null) _textField.height = value;
		return value;
	}
	
	/** The current scaling grid used for the button's state image. Use this property to create
	 *  buttons that resize in a smart way, i.e. with the four corners keeping the same size
	 *  and only stretching the center area.
	 *
	 *  @see Image#scale9Grid
	 *  @default null
	 */
	private function get_scale9Grid():Rectangle
	{
		return _body.scale9Grid;
	}
	
	private function set_scale9Grid(value:Rectangle):Rectangle{_body.scale9Grid = value;
		return value;
	}
}
