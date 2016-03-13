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

import starling.rendering.Program;
import starling.rendering.VertexDataFormat;

import flash.display3D.Context3D;

import starling.textures.Texture;
import starling.textures.TextureSmoothing;
import starling.utils.RenderUtil;

/** An effect drawing a mesh of textured vertices.
 *  This is the standard effect that is the base for all fragment filters;
 *  if you want to create your own fragment filters, you will have to extend this class.
 *
 *  <p>For more information about the usage and creation of effects, please have a look at
 *  the documentation of the parent class, "Effect".</p>
 *
 *  @see Effect
 *  @see MeshEffect
 *  @see starling.filters.FragmentFilter
 */
class FilterEffect extends Effect
{
	public var texture(get, set):Texture;
	public var textureSmoothing(get, set):String;
	public var textureRepeat(get, set):Bool;

	/** The vertex format expected by <code>uploadVertexData</code>:
	 *  <code>"position:float2, texCoords:float2"</code> */
	public static var VERTEX_FORMAT:VertexDataFormat = 
		VertexDataFormat.fromString("position:float2, texCoords:float2");
	
	/** The AGAL code for the standard vertex shader that most filters will use.
	 *  It simply transforms the vertex coordinates to clip-space and passes the texture
	 *  coordinates to the fragment program (as 'v0'). */
	public static var STD_VERTEX_SHADER:String = 
		"m44 op, va0, vc0 \n" +  // 4x4 matrix transform to output clip-space  
		"mov v0, va1";  // pass texture coordinates to fragment program  
	
	private var _texture:Texture;
	private var _textureSmoothing:String;
	private var _textureRepeat:Bool;
	
	/** Creates a new FilterEffect instance. */
	public function new()
	{
		super();
		_textureSmoothing = TextureSmoothing.BILINEAR;
	}
	
	/** Override this method if the effect requires a different program depending on the
	 *  current settings. Ideally, you do this by creating a bit mask encoding all the options.
	 *  This method is called often, so do not allocate any temporary objects when overriding.
	 *
	 *  <p>Reserve 4 bits for the variant name of the base class.</p>
	 */
	override private function get_programVariantName():Int
	{
		return RenderUtil.getTextureVariantBits(_texture);
	}
	
	/** @private */
	override private function createProgram():Program
	{
		if (_texture != null) 
		{
			var vertexShader:String = STD_VERTEX_SHADER;
			var fragmentShader:String = 
			RenderUtil.createAGALTexOperation("oc", "v0", 0, _texture);
			
			return Program.fromSource(vertexShader, fragmentShader);
		}
		else 
		{
			return super.createProgram();
		}
	}
	
	/** This method is called by <code>render</code>, directly before
	 *  <code>context.drawTriangles</code>. It activates the program and sets up
	 *  the context with the following constants and attributes:
	 *
	 *  <ul>
	 *	<li><code>vc0-vc3</code> — MVP matrix</li>
	 *	<li><code>va0</code> — vertex position (xy)</li>
	 *	<li><code>va1</code> — texture coordinates (uv)</li>
	 *	<li><code>fs0</code> — texture</li>
	 *  </ul>
	 */
	override private function beforeDraw(context:Context3D):Void
	{
		super.beforeDraw(context);
		
		if (_texture != null) 
		{
			RenderUtil.setSamplerStateAt(0, _texture.mipMapping, _textureSmoothing, _textureRepeat);
			context.setTextureAt(0, _texture.base);
			vertexFormat.setVertexBufferAt(1, vertexBuffer, "texCoords");
		}
	}
	
	/** This method is called by <code>render</code>, directly after
	 *  <code>context.drawTriangles</code>. Resets texture and vertex buffer attributes. */
	override private function afterDraw(context:Context3D):Void
	{
		if (_texture != null) 
		{
			context.setTextureAt(0, null);
			context.setVertexBufferAt(1, null);
		}
		
		super.afterDraw(context);
	}
	
	/** The data format that this effect requires from the VertexData that it renders:
	 *  <code>"position:float2, texCoords:float2"</code> */
	override private function get_vertexFormat():VertexDataFormat
	{
		return VERTEX_FORMAT;
	}
	
	/** The texture to be mapped onto the vertices. */
	private function get_texture():Texture
	{
		return _texture;
	}
	
	private function set_texture(value:Texture):Texture{_texture = value;
		return value;
	}
	
	/** The smoothing filter that is used for the texture. @default bilinear */
	private function get_textureSmoothing():String
	{
		return _textureSmoothing;
	}
	
	private function set_textureSmoothing(value:String):String{_textureSmoothing = value;
		return value;
	}
	
	/** Indicates how the pixels of the texture will be wrapped at the edge.
	 *  If enabled, the texture will produce a repeating pattern; otherwise, the outermost
	 *  pixels will repeat. Unfortunately, this only works for power-of-two textures.
	 *  @default false */
	private function get_textureRepeat():Bool
	{
		return _textureRepeat;
	}
	
	private function set_textureRepeat(value:Bool):Bool{_textureRepeat = value;
		return value;
	}
}

