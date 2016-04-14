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


import openfl.display3D._shaders.Shader;

import openfl.display3D.Context3D;
import openfl.display3D.Context3DProgramType;
import openfl.display3D.Program3D;
import openfl.display3D._shaders.AGLSLShaderUtils;
import openfl.events.Event;
import openfl.utils.ByteArray;

import starling.core.Starling;
import starling.errors.MissingContextError;

/** A Program represents a pair of a fragment- and vertex-shader.
 *
 *  <p>This class is a convenient replacement for Stage3Ds "Program3D" class. Its main
 *  advantage is that it survives a context loss; furthermore, it makes it simple to
 *  create a program from AGAL source without having to deal with the assembler.</p>
 *
 *  <p>It is recommended to store programs in Starling's "Painter" instance via the methods
 *  <code>registerProgram</code> and <code>getProgram</code>. That way, your programs may
 *  be shared among different display objects or even Starling instances.</p>
 *
 *  @see Painter
 */
class Program
{
	#if flash
	private var _vertexShader:ByteArray;
	private var _fragmentShader:ByteArray;
	#else
	private var _vertexShader:Shader;
	private var _fragmentShader:Shader;
	#end
	
	private var _program3D:Program3D;
	
	/** Creates a program from the given AGAL (Adobe Graphics Assembly Language) bytecode. */
	#if flash
	public function new(vertexShader:ByteArray, fragmentShader:ByteArray)
	#else
	public function new(vertexShader:Shader, fragmentShader:Shader)
	#end
	{
		_vertexShader = vertexShader;
		_fragmentShader = fragmentShader;
		
		// Handle lost context (using conventional Flash event for weak listener support)
		Starling.Current.stage3D.addEventListener(Event.CONTEXT3D_CREATE,
				onContextCreated, false, 0, true);
	}
	
	
	
	/** Disposes the internal Program3D instance. */
	public function dispose():Void
	{
		Starling.Current.stage3D.removeEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
		disposeProgram();
	}
	
	/** Creates a new Program instance from AGAL assembly language. */
	public static function fromSource(vertexShaderStr:String, fragmentShaderStr:String, agalVersion:Int = 1):Program
	{
		#if flash
		var program = new Program(
			AGLSLShaderUtils.compile(cast Context3DProgramType.VERTEX, vertexShaderStr),
			AGLSLShaderUtils.compile(cast Context3DProgramType.FRAGMENT, fragmentShaderStr)
		);
		#else
		var program = new Program(
			AGLSLShaderUtils.createShader(cast Context3DProgramType.VERTEX, vertexShaderStr),
			AGLSLShaderUtils.createShader(cast Context3DProgramType.FRAGMENT, fragmentShaderStr)
		);
		#end
		return program;
	}
	
	/** Activates the program on the given context. If you don't pass a context, the current
	 *  Starling context will be used. */
	public function activate(context:Context3D = null):Void
	{
		if (context == null) 
		{
			context = Starling.Context;
			if (context == null) throw new MissingContextError();
		}
		
		if (_program3D == null) 
		{
			_program3D = context.createProgram();
			_program3D.upload(_vertexShader, _fragmentShader);
		}
		
		context.setProgram(_program3D);
	}
	
	private function onContextCreated(event:Event):Void
	{
		disposeProgram();
	}
	
	private function disposeProgram():Void
	{
		if (_program3D != null) 
		{
			_program3D.dispose();
			_program3D = null;
		}
	}
}

