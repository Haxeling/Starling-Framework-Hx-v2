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

import flash.display3D.Context3DTextureFormat;
import starling.textures.Texture;

import flash.display3D.textures.TextureBase;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;

/** A SubTexture represents a section of another texture. This is achieved solely by
 *  manipulation of texture coordinates, making the class very efficient. 
 *
 *  <p><em>Note that it is OK to create subtextures of subtextures.</em></p>
 */
class SubTexture extends Texture
{
    public var parent(get, never):Texture;
    public var ownsParent(get, never):Bool;
    public var rotated(get, never):Bool;
    public var region(get, never):Rectangle;

    private var _parent:Texture;
    private var _ownsParent:Bool;
    private var _region:Rectangle;
    private var _frame:Rectangle;
    private var _rotated:Bool;
    private var _width:Float;
    private var _height:Float;
    private var _transformationMatrix:Matrix;
    private var _transformationMatrixToRoot:Matrix;
    
    /** Creates a new SubTexture containing the specified region of a parent texture.
     *
     *  @param parent     The texture you want to create a SubTexture from.
     *  @param region     The region of the parent texture that the SubTexture will show
     *                    (in points). If <code>null</code>, the complete area of the parent.
     *  @param ownsParent If <code>true</code>, the parent texture will be disposed
     *                    automatically when the SubTexture is disposed.
     *  @param frame      If the texture was trimmed, the frame rectangle can be used to restore
     *                    the trimmed area.
     *  @param rotated    If true, the SubTexture will show the parent region rotated by
     *                    90 degrees (CCW).
     */
    public function new(parent:Texture, region:Rectangle = null,
            ownsParent:Bool = false, frame:Rectangle = null,
            rotated:Bool = false)
    {
        super();
        // TODO: in a future version, the order of arguments of this constructor should
        //       be fixed ('ownsParent' at the very end).
        
        _parent = parent;
        _region = (region != null) ? region.clone():new Rectangle(0, 0, parent.width, parent.height);
        _frame = (frame != null) ? frame.clone():null;
        _ownsParent = ownsParent;
        _rotated = rotated;
        _width = (rotated) ? _region.height:_region.width;
        _height = (rotated) ? _region.width:_region.height;
        _transformationMatrixToRoot = new Matrix();
        _transformationMatrix = new Matrix();
        
        if (rotated) 
        {
            _transformationMatrix.translate(0, -1);
            _transformationMatrix.rotate(Math.PI / 2.0);
        }
        
        if (_frame != null && (_frame.x > 0 || _frame.y > 0 ||
            _frame.right < _width || _frame.bottom < _height)) 
        {
            trace("[Starling] Warning: frames inside the texture's region are unsupported.");
        }
        
        _transformationMatrix.scale(_region.width / _parent.width,
                _region.height / _parent.height);
        _transformationMatrix.translate(_region.x / _parent.width,
                _region.y / _parent.height);
        
        var texture:SubTexture = this;
        while (texture != null)
        {
            _transformationMatrixToRoot.concat(texture._transformationMatrix);
            texture = try cast(texture.parent, SubTexture) catch(e:Dynamic) null;
        }
    }
    
    /** Disposes the parent texture if this texture owns it. */
    override public function dispose():Void
    {
        if (_ownsParent)             _parent.dispose();
        super.dispose();
    }
    
    /** The texture which the SubTexture is based on. */
    private function get_parent():Texture
	{
		return _parent;
    }
    
    /** Indicates if the parent texture is disposed when this object is disposed. */
    private function get_ownsParent():Bool
	{
		return _ownsParent;
    }
    
    /** If true, the SubTexture will show the parent region rotated by 90 degrees (CCW). */
    private function get_rotated():Bool
	{
		return _rotated;
    }
    
    /** The region of the parent texture that the SubTexture is showing (in points).
     *
     *  <p>CAUTION: not a copy, but the actual object! Do not modify!</p> */
    private function get_region():Rectangle
	{
		return _region;
    }
    
    /** @inheritDoc */
    override private function get_transformationMatrix():Matrix
	{
		return _transformationMatrix;
    }
    
    /** @inheritDoc */
    override private function get_transformationMatrixToRoot():Matrix
	{
		return _transformationMatrixToRoot;
    }
    
    /** @inheritDoc */
    override private function get_base():TextureBase
	{
		return _parent.base;
    }
    
    /** @inheritDoc */
    override private function get_root():ConcreteTexture
	{
		return _parent.root;
    }
    
    /** @inheritDoc */
    override private function get_format():Context3DTextureFormat
	{
		return _parent.format;
    }
    
    /** @inheritDoc */
    override private function get_width():Float
	{
		return _width;
    }
    
    /** @inheritDoc */
    override private function get_height():Float
	{
		return _height;
    }
    
    /** @inheritDoc */
    override private function get_nativeWidth():Float
	{
		return _width * scale;
    }
    
    /** @inheritDoc */
    override private function get_nativeHeight():Float
	{
		return _height * scale;
    }
    
    /** @inheritDoc */
    override private function get_mipMapping():Bool
	{
		return _parent.mipMapping;
    }
    
    /** @inheritDoc */
    override private function get_premultipliedAlpha():Bool
	{
		return _parent.premultipliedAlpha;
    }
    
    /** @inheritDoc */
    override private function get_scale():Float
	{
		return _parent.scale;
    }
    
    /** @inheritDoc */
    override private function get_frame():Rectangle
	{
		return _frame;
    }
}
