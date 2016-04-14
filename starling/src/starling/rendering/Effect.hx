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

import haxe.Constraints.Function;
import starling.rendering.IndexData;
import starling.rendering.Painter;
import starling.rendering.Program;
import starling.rendering.VertexData;
import starling.rendering.VertexDataFormat;
import starling.utils.Execute;

import openfl.display3D.Context3D;
import openfl.display3D.Context3DProgramType;
import openfl.display3D.IndexBuffer3D;
import openfl.display3D.VertexBuffer3D;
import openfl.events.Event;
import openfl.geom.Matrix3D;


import starling.core.Starling;
import starling.errors.MissingContextError;
import starling.utils.Execute;

/** An effect encapsulates all steps of a Stage3D draw operation. It configures the
 *  render context and sets up shader programs as well as index- and vertex-buffers, thus
 *  providing the basic mechanisms of all low-level rendering.
 *
 *  <p><strong>Using the Effect class</strong></p>
 *
 *  <p>Effects are mostly used by the <code>MeshStyle</code> and <code>FragmentFilter</code>
 *  classes. When you extend those classes, you'll be required to provide a custom effect.
 *  Setting it up for rendering is done by the base class, though, so you rarely have to
 *  initiate the rendering yourself. Nevertheless, it's good to know how an effect is doing
 *  its work.</p>
 *
 *  <p>Using an effect always follows steps shown in the example below. You create the
 *  effect, configure it, upload vertex data and then: draw!</p>
 *
 *  <listing>
 *  // create effect
 *  var effect:MeshEffect = new MeshEffect();
 *  
 *  // configure effect
 *  effect.mvpMatrix3D = painter.state.mvpMatrix3D;
 *  effect.texture = getHeroTexture();
 *  effect.color = 0xf0f0f0;
 *  
 *  // upload vertex data
 *  effect.uploadIndexData(indexData);
 *  effect.uploadVertexData(vertexData);
 *  
 *  // draw!
 *  effect.render(0, numTriangles);</listing>
 *
 *  <p>Note that the <code>VertexData</code> being uploaded has to be created with the same
 *  format as the one returned by the effect's <code>vertexFormat</code> property.</p>
 *
 *  <p><strong>Extending the Effect class</strong></p>
 *
 *  <p>The base <code>Effect</code>-class can only render white triangles, which is not much
 *  use in itself. However, it is designed to be extended; subclasses can easily implement any
 *  kinds of shaders.</p>
 *
 *  <p>Normally, you won't extend this class directly, but either <code>FilterEffect</code>
 *  or <code>MeshEffect</code>, depending on your needs (i.e. if you want to create a new
 *  fragment filter or a new mesh style). Whichever base class you're extending, you should
 *  override the following methods:</p>
 *
 *  <ul>
 *	<li><code>createProgram():Program</code> — must create the actual program containing 
 *		vertex- and fragment-shaders. A program will be created only once for each render
 *		context; this is taken care of by the base class.</li>
 *	<li><code>get programVariantName():uint</code> (optional) — override this if your
 *		effect requires different programs, depending on its settings. The recommended
 *		way to do this is via a bit-mask that uniquely encodes the current settings.</li>
 *	<li><code>get vertexFormat():String</code> (optional) — must return the
 *		<code>VertexData</code> format that this effect requires for its vertices. If
 *		the effect does not require any special attributes, you can leave this out.</li>
 *	<li><code>beforeDraw(context:Context3D):void</code> — Set up your context by
 *		configuring program constants and buffer attributes.</li>
 *	<li><code>afterDraw(context:Context3D):void</code> — Will be called directly after
 *		<code>context.drawTriangles()</code>. Clean up any context configuration here.</li>
 *  </ul>
 *
 *  <p>Furthermore, you need to add properties that manage the data you require on rendering,
 *  e.g. the texture(s) that should be used, program constants, etc. I recommend looking at
 *  the implementations of Starling's <code>FilterEffect</code> and <code>MeshEffect</code>
 *  classes to see how to approach sub-classing.</p>
 *
 *  @see FilterEffect
 *  @see MeshEffect
 *  @see starling.rendering.MeshStyle
 *  @see starling.filters.FragmentFilter
 *  @see starling.utils.RenderUtil
 */
class Effect
{
	private var programVariantName(get, never):Int;
	private var programBaseName(get, set):String;
	private var programName(get, never):String;
	private var program(get, never):Program;
	public var onRestore(get, set):Function;
	public var vertexFormat(get, never):VertexDataFormat;
	public var mvpMatrix3D(get, set):Matrix3D;
	private var indexBuffer(get, never):IndexBuffer3D;
	private var indexBufferSize(get, never):Int;
	private var vertexBuffer(get, never):VertexBuffer3D;
	private var vertexBufferSize(get, never):Int;

	/** The vertex format expected by <code>uploadVertexData</code>:
	 *  <code>"position:float2"</code> */
	public static var VERTEX_FORMAT:VertexDataFormat = 
		VertexDataFormat.fromString("position:float2");
	
	private var _indexBuffer:IndexBuffer3D;
	private var _indexBufferSize:Int = 0;  // in number of indices  
	private var _vertexBuffer:VertexBuffer3D;
	private var _vertexBufferSize:Int = 0;  // in blocks of 32 bits  
	
	private var _mvpMatrix3D:Matrix3D;
	private var _onRestore:Function;
	private var _programBaseName:String;
	
	// helper objects
	private static var sProgramNameCache = new Map<String, Map<Int, String>>();
	
	/** Creates a new effect. */
	public function new()
	{
		_mvpMatrix3D = new Matrix3D();
		_programBaseName = Type.getClassName(Type.getClass(this));
		
		var nameCache:Map<Int, String> = sProgramNameCache.get(programBaseName);
		
		if (nameCache == null) 
		{
			nameCache = new Map<Int, String>();
			sProgramNameCache.set(programBaseName, nameCache);
		}
		
		// Handle lost context (using conventional Flash event for weak listener support)
		Starling.Current.stage3D.addEventListener(Event.CONTEXT3D_CREATE,
				onContextCreated, false, 0, true);
	}
	
	/** Purges the index- and vertex-buffers. */
	public function dispose():Void
	{
		Starling.Current.stage3D.removeEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
		purgeBuffers();
	}
	
	private function onContextCreated(event:Event):Void
	{
		purgeBuffers();
		Execute.call(_onRestore, [this]);
	}
	
	/** Purges one or both of the index- and vertex-buffers. */
	public function purgeBuffers(indexBuffer:Bool = true, vertexBuffer:Bool = true):Void
	{
		if (_indexBuffer != null && indexBuffer) 
		{
			_indexBuffer.dispose();
			_indexBuffer = null;
		}
		
		if (_vertexBuffer != null && vertexBuffer) 
		{
			_vertexBuffer.dispose();
			_vertexBuffer = null;
		}
	}
	
	/** Uploads the given index data to the internal index buffer. If the buffer is too
	 *  small, a new one is created automatically. */
	public function uploadIndexData(indexData:IndexData):Void
	{
		if (_indexBuffer != null) 
		{
			if (indexData.numIndices <= _indexBufferSize) 
				indexData.uploadToIndexBuffer(_indexBuffer)
			else 
			purgeBuffers(true, false);
		}
		if (_indexBuffer == null) 
		{
			_indexBuffer = indexData.createIndexBuffer(true);
			_indexBufferSize = indexData.numIndices;
		}
	}
	
	/** Uploads the given vertex data to the internal vertex buffer. If the buffer is too
	 *  small, a new one is created automatically. */
	public function uploadVertexData(vertexData:VertexData):Void
	{
		if (_vertexBuffer != null) 
		{
			if (vertexData.sizeIn32Bits <= _vertexBufferSize) 
				vertexData.uploadToVertexBuffer(_vertexBuffer)
			else 
			purgeBuffers(false, true);
		}
		if (_vertexBuffer == null) 
		{
			_vertexBuffer = vertexData.createVertexBuffer(true);
			_vertexBufferSize = vertexData.sizeIn32Bits;
		}
	}
	
	// rendering
	
	/** Draws the triangles described by the index- and vertex-buffers, or a range of them.
	 *  This calls <code>beforeDraw</code>, <code>context.drawTriangles</code>, and
	 *  <code>afterDraw</code>, in this order. */
	public function render(firstIndex:Int = 0, numTriangles:Int = -1):Void
	{
		if (numTriangles < 0) numTriangles = Math.round(indexBufferSize / 3);
		if (numTriangles == 0) return;
		
		var context:Context3D = Starling.Context;
		if (context == null) throw new MissingContextError();
		
		beforeDraw(context);
		context.drawTriangles(indexBuffer, firstIndex, numTriangles);
		afterDraw(context);
	}
	
	/** This method is called by <code>render</code>, directly before
	 *  <code>context.drawTriangles</code>. It activates the program and sets up
	 *  the context with the following constants and attributes:
	 *
	 *  <ul>
	 *	<li><code>vc0-vc3</code> — MVP matrix</li>
	 *	<li><code>va0</code> — vertex position (xy)</li>
	 *  </ul>
	 */
	private function beforeDraw(context:Context3D):Void
	{
		program.activate(context);
		vertexFormat.setVertexBufferAt(0, vertexBuffer, "position");
		context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, mvpMatrix3D, true);
	}
	
	/** This method is called by <code>render</code>, directly after
	 *  <code>context.drawTriangles</code>. Resets vertex buffer attributes.
	 */
	private function afterDraw(context:Context3D):Void
	{
		context.setVertexBufferAt(0, null);
	}
	
	// program management
	
	/** Creates the program (a combination of vertex- and fragment-shader) used to render
	 *  the effect with the current settings. Override this method in a subclass to create
	 *  your shaders. This method will only be called once; the program is automatically stored
	 *  in the <code>Painter</code> and re-used by all instances of this effect.
	 *
	 *  <p>The basic implementation always outputs pure white.</p>
	 */
	private function createProgram():Program
	{
		var vertexShader:String = [
			"m44 op, va0, vc0", // 4x4 matrix transform to output clipspace
			"seq v0, va0, va0"  // this is a hack that always produces "1"
		].join("\n");

		var fragmentShader:String =
			"mov oc, v0";	   // output color: white

		return Program.fromSource(vertexShader, fragmentShader);
	}
	
	/** Override this method if the effect requires a different program depending on the
	 *  current settings. Ideally, you do this by creating a bit mask encoding all the options.
	 *  This method is called often, so do not allocate any temporary objects when overriding.
	 *
	 *  @default 0
	 */
	private function get_programVariantName():Int
	{
		return 0;
	}
	
	/** Returns the base name for the program.
	 *  @default the fully qualified class name
	 */
	private function get_programBaseName():String
	{
		return _programBaseName;
	}
	private function set_programBaseName(value:String):String
	{
		_programBaseName = value;
		return value;
	}
	
	/** Returns the full name of the program, which is used to register it at the current
	 *  <code>Painter</code>.
	 *
	 *  <p>The default implementation efficiently combines the program's base and variant
	 *  names (e.g. <code>LightEffect#42</code>). It shouldn't be necessary to override
	 *  this method.</p>
	 */
	private function get_programName():String
	{
		var nameCache:Map<Int, String> = sProgramNameCache.get(programBaseName);
		var name:String = nameCache.get(programVariantName);
		
		if (name == null) 
		{
			if (programVariantName != 0) {
				name = programBaseName + "#" + Std.string(programVariantName);
			}
			else name = programBaseName;
			
			nameCache.set(programVariantName, name);
		}
		
		return name;
	}
	
	/** Returns the current program, either by creating a new one (via
	 *  <code>createProgram</code>) or by getting it from the <code>Painter</code>.
	 *  Do not override this method! Instead, implement <code>createProgram</code>. */
	private function get_program():Program
	{
		var name:String = this.programName;
		var painter:Painter = Starling.Painter;
		var program:Program = painter.getProgram(name);
		
		if (program == null) 
		{
			program = createProgram();
			painter.registerProgram(name, program);
		}
		
		return program;
	}
	
	// properties
	
	/** The function that you provide here will be called after a context loss.
	 *  Call both "upload..." methods from within the callback to restore any vertex or
	 *  index buffers. The callback will be executed with the effect as its sole parameter. */
	private function get_onRestore():Function
	{
		return _onRestore;
	}
	
	private function set_onRestore(value:Function):Function{_onRestore = value;
		return value;
	}
	
	/** The data format that this effect requires from the VertexData that it renders:
	 *  <code>"position:float2"</code> */
	private function get_vertexFormat():VertexDataFormat
	{
		return VERTEX_FORMAT;
	}
	
	/** The MVP (modelview-projection) matrix transforms vertices into clipspace. */
	private function get_mvpMatrix3D():Matrix3D
	{
		return _mvpMatrix3D;
	}
	
	private function set_mvpMatrix3D(value:Matrix3D):Matrix3D{_mvpMatrix3D.copyFrom(value);
		return value;
	}
	
	/** The internally used index buffer used on rendering. */
	private function get_indexBuffer():IndexBuffer3D
	{
		return _indexBuffer;
	}
	
	/** The current size of the index buffer (in number of indices). */
	private function get_indexBufferSize():Int
	{
		return _indexBufferSize;
	}
	
	/** The internally used vertex buffer used on rendering. */
	private function get_vertexBuffer():VertexBuffer3D
	{
		return _vertexBuffer;
	}
	
	/** The current size of the vertex buffer (in blocks of 32 bits). */
	private function get_vertexBufferSize():Int
	{
		return _vertexBufferSize;
	}
}

