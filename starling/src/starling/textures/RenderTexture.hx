// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.textures;

import openfl.display3D.Context3DProfile;
import openfl.display3D.Context3DTextureFormat;
import haxe.Constraints.Function;
import openfl.errors.Error;
import starling.textures.SubTexture;
import starling.textures.Texture;

import openfl.display3D.textures.TextureBase;
import openfl.errors.IllegalOperationError;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

import starling.core.Starling;
import starling.display.BlendMode;
import starling.display.DisplayObject;
import starling.display.Image;
import starling.filters.FragmentFilter;
import starling.rendering.Painter;
import starling.rendering.RenderState;
import starling.utils.Execute;

/** A RenderTexture is a dynamic texture onto which you can draw any display object.
 * 
 *  <p>After creating a render texture, just call the <code>drawObject</code> method to render 
 *  an object directly onto the texture. The object will be drawn onto the texture at its current
 *  position, adhering its current rotation, scale and alpha properties.</p> 
 *  
 *  <p>Drawing is done very efficiently, as it is happening directly in graphics memory. After 
 *  you have drawn objects onto the texture, the performance will be just like that of a normal 
 *  texture - no matter how many objects you have drawn.</p>
 *  
 *  <p>If you draw lots of objects at once, it is recommended to bundle the drawing calls in 
 *  a block via the <code>drawBundled</code> method, like shown below. That will speed it up 
 *  immensely, allowing you to draw hundreds of objects very quickly.</p>
 *  
 * 	<pre>
 *  renderTexture.drawBundled(function():void
 *  {
 *	 for (var i:int=0; i&lt;numDrawings; ++i)
 *	 {
 *		 image.rotation = (2 &#42; Math.PI / numDrawings) &#42; i;
 *		 renderTexture.draw(image);
 *	 }   
 *  });
 *  </pre>
 *  
 *  <p>To erase parts of a render texture, you can use any display object like a "rubber" by
 *  setting its blending mode to "BlendMode.ERASE".</p>
 * 
 *  <p>Beware that render textures can't be restored when the Starling's render context is lost.
 *  </p>
 *
 *  <strong>Persistence</strong>
 *
 *  <p>Older devices may require double buffering to support persistent render textures. Thus,
 *  you should disable the <code>persistent</code> parameter in the constructor if you only
 *  need to make one draw operation on the texture. The static <code>useDoubleBuffering</code>
 *  property allows you to customize if new textures will be created with or without double
 *  buffering.</p>
 */
class RenderTexture extends SubTexture
{
	private var isDoubleBuffered(get, never):Bool;
	public var isPersistent(get, never):Bool;
	public static var useDoubleBuffering(get, set):Bool;

	private static var USE_DOUBLE_BUFFERING_DATA_NAME:String = 
		"starling.textures.RenderTexture.useDoubleBuffering";
	
	private var _activeTexture:Texture;
	private var _bufferTexture:Texture;
	private var _helperImage:Image;
	private var _drawing:Bool;
	private var _bufferReady:Bool;
	private var _isPersistent:Bool;
	
	// helper object
	private static var sClipRect:Rectangle = new Rectangle();
	
	/** Creates a new RenderTexture with a certain size (in points). If the texture is
	 *  persistent, its contents remains intact after each draw call, allowing you to use the
	 *  texture just like a canvas. If it is not, it will be cleared before each draw call.
	 *
	 *  <p>Non-persistent textures can be used more efficiently on older devices; on modern
	 *  hardware, it does not make a difference. For more information, have a look at the
	 *  documentation of the <code>useDoubleBuffering</code> property.</p>
	 */
	public function new(width:Int, height:Int, persistent:Bool = true,
			scale:Float = -1, format:Context3DTextureFormat = null)
	{
		if (format == null) format = Context3DTextureFormat.BGRA;
		_isPersistent = persistent;
		_activeTexture = Texture.empty(width, height, true, false, true, scale, format);
		_activeTexture.root.onRestore = _activeTexture.root.clear;
		
		super(_activeTexture, new Rectangle(0, 0, width, height), true, null, false);
		
		if (persistent && useDoubleBuffering) 
		{
			_bufferTexture = Texture.empty(width, height, true, false, true, scale, format);
			_bufferTexture.root.onRestore = _bufferTexture.root.clear;
			_helperImage = new Image(_bufferTexture);
			_helperImage.textureSmoothing = TextureSmoothing.NONE;
		}
	}
	
	/** @inheritDoc */
	override public function dispose():Void
	{
		_activeTexture.dispose();
		
		if (isDoubleBuffered) 
		{
			_bufferTexture.dispose();
			_helperImage.dispose();
		}
		
		super.dispose();
	}
	
	/** Draws an object into the texture. Note that any filters on the object will currently
	 *  be ignored.
	 * 
	 *  @param object	   The object to draw.
	 *  @param matrix	   If 'matrix' is null, the object will be drawn adhering its 
	 *					  properties for position, scale, and rotation. If it is not null,
	 *					  the object will be drawn in the orientation depicted by the matrix.
	 *  @param alpha		The object's alpha value will be multiplied with this value.
	 *  @param antiAliasing Only supported on Desktop.
	 *					  Values range from 0 (no anti-aliasing) to 4 (best quality).
	 */
	public function draw(object:DisplayObject, matrix:Matrix = null, alpha:Float = 1.0,
			antiAliasing:Int = 0):Void
	{
		if (object == null)			 return;
		
		if (_drawing) 
			render(object, matrix, alpha)
		else 
		renderBundled(render, object, matrix, alpha, antiAliasing);
	}
	
	/** Bundles several calls to <code>draw</code> together in a block. This avoids buffer 
	 *  switches and allows you to draw multiple objects into a non-persistent texture.
	 *  Note that the 'antiAliasing' setting provided here overrides those provided in
	 *  individual 'draw' calls.
	 *  
	 *  @param drawingBlock  a callback with the form: <pre>function():void;</pre>
	 *  @param antiAliasing  Only supported beginning with AIR 13, and only on Desktop.
	 *					   Values range from 0 (no antialiasing) to 4 (best quality). */
	public function drawBundled(drawingBlock:Function, antiAliasing:Int = 0):Void
	{
		renderBundled(drawingBlock, null, null, 1.0, antiAliasing);
	}
	
	private function render(object:DisplayObject, matrix:Matrix = null, alpha:Float = 1.0):Void
	{
		var painter:Painter = Starling.Painter;
		var state:RenderState = painter.state;
		var filter:FragmentFilter = object.filter;
		var mask:DisplayObject = object.mask;
		
		painter.pushState();
		
		state.alpha *= alpha;
		state.setModelviewMatricesToIdentity();
		state.blendMode = object.blendMode == (BlendMode.AUTO) ? 
				BlendMode.NORMAL:object.blendMode;
		
		if (matrix != null)			 state.transformModelviewMatrix(matrix)
		else state.transformModelviewMatrix(object.transformationMatrix);
		
		if (mask != null)			 painter.drawMask(mask);
		
		if (filter != null)			 filter.render(painter)
		else object.render(painter);
		
		if (mask != null)			 painter.eraseMask(mask);
		
		painter.popState();
	}
	
	private function renderBundled(renderBlock:Function, object:DisplayObject = null,
			matrix:Matrix = null, alpha:Float = 1.0,
			antiAliasing:Int = 0):Void
	{
		var painter:Painter = Starling.Painter;
		var state:RenderState = painter.state;
		
		if (!Starling.Current.contextValid)			 return;  // switch buffers
		
		if (isDoubleBuffered) 
		{
			var tmpTexture:Texture = _activeTexture;
			_activeTexture = _bufferTexture;
			_bufferTexture = tmpTexture;
			_helperImage.texture = _bufferTexture;
		}
		
		painter.pushState();
		
		var rootTexture:Texture = _activeTexture.root;
		state.setProjectionMatrix(0, 0, rootTexture.width, rootTexture.height, width, height);
		
		// limit drawing to relevant area
		sClipRect.setTo(0, 0, _activeTexture.width, _activeTexture.height);
		
		state.clipRect = sClipRect;
		state.setRenderTarget(_activeTexture, true, antiAliasing);
		painter.prepareToDraw();
		
		if (isDoubleBuffered || !isPersistent || !_bufferReady) 
			painter.clear();  // draw buffer
		
		if (isDoubleBuffered && _bufferReady) 
			_helperImage.render(painter)
		else 
		_bufferReady = true;
		
		try
		{
			_drawing = true;
			Execute.call(renderBlock, [object, matrix, alpha]);
		}
		catch (e:Error) {
			
		}
		
		_drawing = false;
		painter.popState();
	}
	
	/** Clears the render texture with a certain color and alpha value. Call without any
	 *  arguments to restore full transparency. */
	public function clear(color:Int = 0, alpha:Float = 0.0):Void
	{
		_activeTexture.root.clear(color, alpha);
		_bufferReady = true;
	}
	
	// properties
	
	/** Indicates if the render texture is using double buffering. This might be necessary for
	 *  persistent textures, depending on the runtime version and the value of
	 *  'forceDoubleBuffering'. */
	private function get_isDoubleBuffered():Bool
	{
		return _bufferTexture != null;
	}
	
	/** Indicates if the texture is persistent over multiple draw calls. */
	private function get_isPersistent():Bool
	{
		return _isPersistent;
	}
	
	/** @inheritDoc */
	override private function get_base():TextureBase
	{
		return _activeTexture.base;
	}
	
	/** @inheritDoc */
	override private function get_root():ConcreteTexture
	{
		return _activeTexture.root;
	}
	
	/** Indicates if new persistent textures should use double buffering. Single buffering
	 *  is faster and requires less memory, but is not supported on all hardware.
	 *
	 *  <p>By default, applications running with the profile "baseline" or "baselineConstrained"
	 *  will use double buffering; all others use just a single buffer. You can override this
	 *  behavior, though, by assigning a different value at runtime.</p>
	 *
	 *  @default true for "baseline" and "baselineConstrained", false otherwise
	 */
	private static function get_useDoubleBuffering():Bool
	{
		if (Starling.Current != null) 
		{
			var painter:Painter = Starling.Painter;
			var sharedData:Map<String, Dynamic> = painter.sharedData;
			
			if (sharedData.exists(USE_DOUBLE_BUFFERING_DATA_NAME)) 
			{
				return sharedData.get(USE_DOUBLE_BUFFERING_DATA_NAME);
			}
			else 
			{
				var profile:Context3DProfile = (painter.profile != null) ? painter.profile:Context3DProfile.BASELINE;
				var value:Bool = profile == Context3DProfile.BASELINE || profile == Context3DProfile.BASELINE_CONSTRAINED;
				sharedData.set(USE_DOUBLE_BUFFERING_DATA_NAME, value);
				return value;
			}
		}
		else return false;
	}
	
	private static function set_useDoubleBuffering(value:Bool):Bool
	{
		if (Starling.Current == null) 
			throw new IllegalOperationError("Starling not yet initialized")
		else 
		Starling.Painter.sharedData.set(USE_DOUBLE_BUFFERING_DATA_NAME, value);
		return value;
	}
}
