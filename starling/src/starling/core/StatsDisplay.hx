// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.core;


import openfl.system.System;
import starling.utils.FloatUtil;

import starling.display.BlendMode;
import starling.display.Quad;
import starling.display.Sprite;
import starling.events.EnterFrameEvent;
import starling.events.Event;
import starling.rendering.Painter;
import starling.text.BitmapFont;
import starling.text.TextField;
import starling.text.TextFormat;
import starling.utils.Align;

/** A small, lightweight box that displays the current framerate, memory consumption and
 *  the number of draw calls per frame. The display is updated automatically once per frame. */
class StatsDisplay extends Sprite
{
	public var drawCount(get, set):Int;
	public var fps(get, set):Float;
	public var memory(get, set):Float;

	private var UPDATE_INTERVAL:Float = 0.5;
	
	private var _background:Quad;
	private var _textField:TextField;
	
	private var _frameCount:Int = 0;
	private var _totalTime:Float = 0;
	
	private var _fps:Float = 0;
	private var _memory:Float = 0;
	private var _drawCount:Int = 0;
	
	/** Creates a new Statistics Box. */
	@:allow(starling.core)
	private function new()
	{
		super();
		var format:TextFormat = new TextFormat(BitmapFont.MINI, BitmapFont.NATIVE_SIZE, 
		0xffffff, Align.LEFT, Align.TOP);
		
		_background = new Quad(50, 25, 0x0);
		_textField = new TextField(48, 25, "", format);
		_textField.x = 2;
		
		addChild(_background);
		addChild(_textField);
		
		blendMode = BlendMode.NONE;
		
		addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
	}
	
	private function onAddedToStage():Void
	{
		addEventListener(Event.ENTER_FRAME, onEnterFrame);
		_totalTime = _frameCount = 0;
		update();
	}
	
	private function onRemovedFromStage():Void
	{
		removeEventListener(Event.ENTER_FRAME, onEnterFrame);
	}
	
	private function onEnterFrame(event:EnterFrameEvent):Void
	{
		_totalTime += event.passedTime;
		_frameCount++;
		
		if (_totalTime > UPDATE_INTERVAL) 
		{
			update();
			_frameCount = untyped _totalTime = 0;
		}
	}
	
	/** Updates the displayed values. */
	public function update():Void
	{
		_fps = _totalTime > (0) ? _frameCount / _totalTime:0;
		_memory = System.totalMemory * 0.000000954;  // 1.0 / (1024*1024) to convert to MB  
		
		
		_textField.text = "FPS: " + FloatUtil.toFixed(_fps, _fps < (100) ? 1:0) +
				"\nMEM: " + FloatUtil.toFixed(_memory, _memory < (100) ? 1:0) +
				"\nDRW: " + (_totalTime > (0) ? _drawCount - 2:_drawCount);
	}
	
	override public function render(painter:Painter):Void
	{
		// By calling "finishQuadBatch" here, we can make sure that the stats display is
		// always rendered with exactly two draw calls. That is taken into account when showing
		// the drawCount value (see 'ignore self' comment above)
		
		painter.finishMeshBatch();
		super.render(painter);
	}
	
	/** The number of Stage3D draw calls per second. */
	private function get_drawCount():Int
	{
		return _drawCount;
	}
	
	private function set_drawCount(value:Int):Int
	{
		_drawCount = value;
		return value;
	}
	
	/** The current frames per second (updated twice per second). */
	private function get_fps():Float
	{
		return _fps;
	}
	
	private function set_fps(value:Float):Float
	{
		_fps = value;
		return value;
	}
	
	/** The currently required system memory in MB. */
	private function get_memory():Float
	{
		return _memory;
	}
	
	private function set_memory(value:Float):Float
	{
		_memory = value;
		return value;
	}
}
