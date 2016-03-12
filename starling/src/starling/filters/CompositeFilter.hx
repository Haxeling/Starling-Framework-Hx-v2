  // =================================================================================================  
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.filters;

import flash.errors.ArgumentError;
import starling.filters.FragmentFilter;
import starling.filters.ITexturePool;

import flash.geom.Point;

import starling.rendering.FilterEffect;
import starling.rendering.Painter;
import starling.textures.Texture;

/** The CompositeFilter class allows to combine several layers of textures into one texture.
 *  It's mainly used as a building block for more complex filters; e.g. the DropShadowFilter
 *  uses this class to draw the shadow (the result of a BlurFilter) behind an object.
 */

import flash.display3d.Context3D;
import flash.display3d.Context3DProgramType;

import starling.rendering.Program;

import starling.utils.Color;
import starling.utils.RenderUtil;
import starling.utils.StringUtil;

class CompositeFilter extends FragmentFilter
{
    private var compositeEffect(get, never) : CompositeEffect;

    /** Creates a new instance. */
    public function new()
    {
        super();
    }
    
    /** Combines up to four input textures into one new texture,
     *  adhering to the properties of each layer. */
    override public function process(painter : Painter, pool : ITexturePool,
            input0 : Texture = null, input1 : Texture = null,
            input2 : Texture = null, input3 : Texture = null) : Texture
    {
        compositeEffect.texture = input0;
        compositeEffect.getLayerAt(1).texture = input1;
        compositeEffect.getLayerAt(2).texture = input2;
        compositeEffect.getLayerAt(3).texture = input3;
        
        return super.process(painter, pool, input0, input1, input2, input3);
    }
    
    /** @private */
    override private function createEffect() : FilterEffect
    {
        return new CompositeEffect();
    }
    
    /** Returns the position (in points) at which a certain layer will be drawn. */
    public function getOffsetAt(layerID : Int, out : Point = null) : Point
    {
        if (out == null)             out = new Point();
        
        out.x = compositeEffect.getLayerAt(layerID).x;
        out.y = compositeEffect.getLayerAt(layerID).y;
        
        return out;
    }
    
    /** Indicates the position (in points) at which a certain layer will be drawn. */
    public function setOffsetAt(layerID : Int, x : Float, y : Float) : Void
    {
        compositeEffect.getLayerAt(layerID).x = x;
        compositeEffect.getLayerAt(layerID).y = y;
    }
    
    /** Returns the RGB color with which a layer is tinted when it is being drawn.
     *  @default 0xffffff */
    public function getColorAt(layerID : Int) : Int
    {
        return compositeEffect.getLayerAt(layerID).color;
    }
    
    /** Adjusts the RGB color with which a layer is tinted when it is being drawn.
     *  If <code>replace</code> is enabled, the pixels are not tinted, but instead
     *  the RGB channels will replace the texture's color entirely.
     */
    public function setColorAt(layerID : Int, color : Int, replace : Bool = false) : Void
    {
        compositeEffect.getLayerAt(layerID).color = color;
        compositeEffect.getLayerAt(layerID).replaceColor = replace;
    }
    
    /** Indicates the alpha value with which the layer is drawn.
     *  @default 1.0 */
    public function getAlphaAt(layerID : Int) : Float
    {
        return compositeEffect.getLayerAt(layerID).alpha;
    }
    
    /** Adjusts the alpha value with which the layer is drawn. */
    public function setAlphaAt(layerID : Int, alpha : Float) : Void
    {
        compositeEffect.getLayerAt(layerID).alpha = alpha;
    }
    
    private function get_compositeEffect() : CompositeEffect
    {
        return try cast(this.effect, CompositeEffect) catch(e:Dynamic) null;
    }
}




class CompositeEffect extends FilterEffect
{
    public var numLayers(get, never) : Int;

    private var _layers : Array<CompositeLayer>;
    
    private static var sLayers : Array<Dynamic> = [];
    private static var sOffset : Array<Float> = [0, 0, 0, 0];
    private static var sColor : Array<Float> = [0, 0, 0, 0];
    
    public function new(numLayers : Int = 4)
    {
        super();
        if (numLayers < 1 || numLayers > 4) 
            throw new ArgumentError("number of layers must be between 1 and 4");
        
        _layers = new Array<CompositeLayer>();
        
        for (i in 0...numLayers){_layers[i] = new CompositeLayer();
        }
    }
    
    public function getLayerAt(layerID : Int) : CompositeLayer
    {
        return _layers[layerID];
    }
    
    private function getUsedLayers(out : Array<Dynamic> = null) : Array<Dynamic>
    {
        if (out == null)             out = []
        else out.length = 0;
        
        for (layer in _layers)
        if (layer.texture)             out[out.length] = layer;
        
        return out;
    }
    
    override private function createProgram() : Program
    {
        var layers : Array<Dynamic> = getUsedLayers(sLayers);
        var numLayers : Int = layers.length;
        var i : Int;
        
        if (numLayers != 0) 
        {
            var vertexShader : Array<Dynamic> = ["m44 op, va0, vc0"];  // transform position to clip-space  
            var layer : CompositeLayer = _layers[0];
            
            for (i in 0...numLayers){vertexShader.push(
                        StringTools.format("sub v{0}, va1, vc{1} \n", i, i + 4)  // v0-4 -> texture coords  
                        );
            }
            
            var fragmentShader : Array<Dynamic> = [
            "seq ft5, v0, v0"  // ft5 -> 1, 1, 1, 1  ];
            
            for (i in 0...numLayers){
                var fti : String = "ft" + i;
                var fci : String = "fc" + i;
                var vi : String = "v" + i;
                
                layer = _layers[i];
                
                fragmentShader.push(
                        tex(fti, vi, i, layers[i].texture)  // fti => texture i color  
                        );
                
                if (layer.replaceColor) 
                    fragmentShader.push(
                        "mul " + fti + ".w,   " + fti + ".w,   " + fci + ".w",
                        "mul " + fti + ".xyz, " + fci + ".xyz, " + fti + ".www"
                        )
                else 
                fragmentShader.push(
                        "mul " + fti + ", " + fti + ", " +fci  // fti *= color  
                        );
                
                if (i != 0) 
                {
                    // "normal" blending: src × ONE + dst × ONE_MINUS_SOURCE_ALPHA
                    fragmentShader.push(
                            "sub ft4, ft5, " + fti + ".wwww",  // ft4 => 1 - src.alpha  
                            "mul ft0, ft0, ft4",  // ft0 => dst * (1 - src.alpha)  
                            "add ft0, ft0, " +fti  // ft0 => src + (dst * 1 - src.alpha)  
                            );
                }
            }
            
            fragmentShader.push("mov oc ft0");  // done! :)  
            
            return Program.fromSource(vertexShader.join("\n"), fragmentShader.join("\n"));
        }
        else 
        {
            return super.createProgram();
        }
    }
    
    override private function get_programVariantName() : Int
    {
        var bits : Int;
        var totalBits : Int = 0;
        var layer : CompositeLayer;
        var layers : Array<Dynamic> = getUsedLayers(sLayers);
        var numLayers : Int = layers.length;
        
        for (i in 0...numLayers){
            layer = layers[i];
            bits = RenderUtil.getTextureVariantBits(layer.texture) | (as3hx.Compat.parseInt(layer.replaceColor) << 3);
            totalBits |= bits << (i * 4);
        }
        
        return totalBits;
    }
    
    /** vc0-vc3 — MVP matrix
     *  vc4-vc7 - layer offsets
     *  fs0-fs3 — input textures
     *  fc0-fc3 - input colors (RGBA+pma)
     *  va0 — vertex position (xy)
     *  va1 — texture coordinates
     *  v0-v4 - texture coordinates with offset
     */
    override private function beforeDraw(context : Context3D) : Void
    {
        var layers : Array<Dynamic> = getUsedLayers(sLayers);
        var numLayers : Int = layers.length;
        
        if (numLayers != 0) 
        {
            for (i in 0...numLayers){
                var layer : CompositeLayer = layers[i];
                var texture : Texture = layer.texture;
                var alphaFactor : Float = (layer.replaceColor) ? 1.0 : layer.alpha;
                
                sOffset[0] = layer.x / texture.root.width;
                sOffset[1] = layer.y / texture.root.height;
                sColor[0] = Color.getRed(layer.color) * alphaFactor / 255.0;
                sColor[1] = Color.getGreen(layer.color) * alphaFactor / 255.0;
                sColor[2] = Color.getBlue(layer.color) * alphaFactor / 255.0;
                sColor[3] = layer.alpha;
                
                context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, i + 4, sOffset);
                context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, i, sColor);
                context.setTextureAt(i, texture.base);
                RenderUtil.setSamplerStateAt(i, texture.mipMapping, textureSmoothing);
            }
        }
        
        super.beforeDraw(context);
    }
    
    override private function afterDraw(context : Context3D) : Void
    {
        for (i in 0...len){context.setTextureAt(i, null);
        }
    }
    
    private static function tex(resultReg : String, uvReg : String, sampler : Int, texture : Texture) : String
    {
        return RenderUtil.createAGALTexOperation(resultReg, uvReg, sampler, texture);
    }
    
    // properties
    
    private function get_numLayers() : Int{return _layers.length;
    }
    
    override private function set_texture(value : Texture) : Texture
    {
        _layers[0].texture = value;
        super.texture = value;
        return value;
    }
}

class CompositeLayer
{
    public var texture : Texture;
    public var x : Float;
    public var y : Float;
    public var color : Int;
    public var alpha : Float;
    public var replaceColor : Bool;
    
    public function new()
    {
        x = y = 0;
        alpha = 1.0;
        color = 0xffffff;
    }
}