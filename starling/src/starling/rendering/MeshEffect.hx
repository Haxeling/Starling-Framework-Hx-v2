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

import flash.display3d.Context3D;
import flash.display3d.Context3DProgramType;

import starling.utils.RenderUtil;

/** An effect drawing a mesh of textured, colored vertices.
 *  This is the standard effect that is the base for all mesh styles;
 *  if you want to create your own mesh styles, you will have to extend this class.
 *
 *  <p>For more information about the usage and creation of effects, please have a look at
 *  the documentation of the root class, "Effect".</p>
 *
 *  @see Effect
 *  @see FilterEffect
 *  @see starling.rendering.MeshStyle
 */
class MeshEffect extends FilterEffect
{
    public var alpha(get, set) : Float;

    /** The vertex format expected by <code>uploadVertexData</code>:
     *  <code>"position:float2, texCoords:float2, color:bytes4"</code> */
    public static var VERTEX_FORMAT : VertexDataFormat = 
        VertexDataFormat.fromString("position:float2, texCoords:float2, color:bytes4");
    
    private var _alpha : Float;
    
    // helper objects
    private static var sRenderAlpha : Array<Float> = new Array<Float>();
    
    /** Creates a new MeshEffect instance. */
    public function new()
    {
        super();
        _alpha = 1.0;
    }
    
    /** @private */
    override private function createProgram() : Program
    {
        var vertexShader : String;
        var fragmentShader : String;
        
        if (texture != null) 
        {
            vertexShader =
                    "m44 op, va0, vc0 \n" +  // 4x4 matrix transform to output clip-space  
                    "mov v0, va1      \n" +  // pass texture coordinates to fragment program  
                    "mul v1, va2, vc4 \n";  // multiply alpha (vc4) with color (va2), pass to fp  
            
            fragmentShader =
                    RenderUtil.createAGALTexOperation("ft0", "v0", 0, texture) +
                    "mul oc, ft0, v1  \n";
        }
        else 
        {
            vertexShader =
                    "m44 op, va0, vc0 \n" +  // 4x4 matrix transform to output clipspace  
                    "mul v0, va2, vc4 \n";  // multiply alpha (vc4) with color (va2)  
            
            fragmentShader =
                    "mov oc, v0       \n";
        }
        
        return Program.fromSource(vertexShader, fragmentShader);
    }
    
    /** This method is called by <code>render</code>, directly before
     *  <code>context.drawTriangles</code>. It activates the program and sets up
     *  the context with the following constants and attributes:
     *
     *  <ul>
     *    <li><code>vc0-vc3</code> — MVP matrix</li>
     *    <li><code>vc4</code> — alpha value (same value for all components)</li>
     *    <li><code>va0</code> — vertex position (xy)</li>
     *    <li><code>va1</code> — texture coordinates (uv)</li>
     *    <li><code>va2</code> — vertex color (rgba), using premultiplied alpha</li>
     *    <li><code>fs0</code> — texture</li>
     *  </ul>
     */
    override private function beforeDraw(context : Context3D) : Void
    {
        super.beforeDraw(context);
        
        sRenderAlpha[0] = sRenderAlpha[1] = sRenderAlpha[2] = sRenderAlpha[3] = _alpha;
        context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 4, sRenderAlpha);
        vertexFormat.setVertexBufferAt(2, vertexBuffer, "color");
    }
    
    /** This method is called by <code>render</code>, directly after
     *  <code>context.drawTriangles</code>. Resets texture and vertex buffer attributes. */
    override private function afterDraw(context : Context3D) : Void
    {
        context.setVertexBufferAt(2, null);
        
        super.afterDraw(context);
    }
    
    /** The data format that this effect requires from the VertexData that it renders:
     *  <code>"position:float2, texCoords:float2, color:bytes4"</code> */
    override private function get_vertexFormat() : VertexDataFormat{return VERTEX_FORMAT;
    }
    
    /** The alpha value of the object rendered by the effect. Must be taken into account
     *  by all subclasses. */
    private function get_alpha() : Float{return _alpha;
    }
    private function set_alpha(value : Float) : Float{_alpha = value;
        return value;
    }
}

