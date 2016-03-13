// =================================================================================================
//
//  Starling Framework
//  Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.display;

import flash.errors.ArgumentError;
import openfl.errors.Error;

import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;

import starling.rendering.IndexData;
import starling.rendering.MeshStyle;
import starling.rendering.Painter;
import starling.rendering.VertexData;
import starling.rendering.VertexDataFormat;
import starling.textures.Texture;
import starling.utils.MeshUtil;



/** The base class for all tangible (non-container) display objects, spawned up by a number
 *  of triangles.
 *
 *  <p>Since Starling uses Stage3D for rendering, all rendered objects must be constructed
 *  from triangles. A mesh stores the information of its triangles through VertexData and
 *  IndexData structures. The default format stores position, color and texture coordinates
 *  for each vertex.</p>
 *
 *  <p>How a mesh is rendered depends on its style. Per default, this is an instance
 *  of the <code>MeshStyle</code> base class; however, subclasses may extend its behavior
 *  to add support for color transformations, normal mapping, etc.</p>
 *
 *  @see MeshBatch
 *  @see starling.rendering.MeshStyle
 *  @see starling.rendering.VertexData
 *  @see starling.rendering.IndexData
 */
class Mesh extends DisplayObject
{
    private var vertexData(get, never):VertexData;
    private var indexData(get, never):IndexData;
    public var style(get, set):MeshStyle;
    public var texture(get, set):Texture;
    public var color(get, set):Int;
    public var textureSmoothing(get, set):String;
    public var pixelSnapping(get, set):Bool;
    public var numVertices(get, set):Int;
    public var numIndices(get, set):Int;
    public var numTriangles(get, never):Int;
    public var vertexFormat(get, never):VertexDataFormat;
    public static var defaultStyle(get, set):Class<Dynamic>;

    /** @private */@:allow(starling.display)
    private var _style:MeshStyle;
    /** @private */@:allow(starling.display)
    private var _vertexData:VertexData;
    /** @private */@:allow(starling.display)
    private var _indexData:IndexData;
    
    private var _pixelSnapping:Bool;
    private static var sDefaultStyle:Class<Dynamic> = MeshStyle;
    
    /** Creates a new mesh with the given vertices and indices.
     *  If you don't pass a style, an instance of <code>MeshStyle</code> will be created
     *  for you. Note that the format of the vertex data will be matched to the
     *  given style right away. */
    public function new(vertexData:VertexData, indexData:IndexData, style:MeshStyle = null)
    {
        super();
        if (vertexData == null)             throw new ArgumentError("VertexData must not be null");
        if (indexData == null)             throw new ArgumentError("IndexData must not be null");
        
        _vertexData = vertexData;
        _indexData = indexData;
        _pixelSnapping = true;
        
        setStyle(style, false);
    }
    
    /** @inheritDoc */
    override public function dispose():Void
    {
        _vertexData.clear();
        _indexData.clear();
        
        super.dispose();
    }
    
    /** @inheritDoc */
    override public function hitTest(localPoint:Point):DisplayObject
    {
        if (!visible || !touchable || !hitTestMask(localPoint))             return null
        else return (MeshUtil.containsPoint(_vertexData, _indexData, localPoint)) ? this:null;
    }
    
    /** @inheritDoc */
    override public function getBounds(targetSpace:DisplayObject, out:Rectangle = null):Rectangle
    {
        return MeshUtil.calculateBounds(_vertexData, this, targetSpace, out);
    }
    
    /** @inheritDoc */
    override public function render(painter:Painter):Void
    {
        if (_pixelSnapping) 
            snapToPixels(painter.state.modelviewMatrix, painter.pixelSize);
        
        painter.batchMesh(this);
    }
    
    private function snapToPixels(matrix:Matrix, pixelSize:Float):Void
    {
        // Snapping only makes sense if the object is unscaled and rotated only by
        // multiples of 90 degrees. If that's the case can be found out by looking
        // at the modelview matrix.
        
        var E:Float = 0.0001;
        
        var doSnap:Bool = false;
        var aSq:Float;
        var bSq:Float;
        var cSq:Float;
        var dSq:Float;
        
        if (matrix.b + E > 0 && matrix.b - E < 0 && matrix.c + E > 0 && matrix.c - E < 0) 
        {
            // what we actually want is 'Math.abs(matrix.a)', but squaring
            // the value works just as well for our needs & is faster.
            
            aSq = matrix.a * matrix.a;
            dSq = matrix.d * matrix.d;
            doSnap = aSq + E > 1 && aSq - E < 1 && dSq + E > 1 && dSq - E < 1;
        }
        else if (matrix.a + E > 0 && matrix.a - E < 0 && matrix.d + E > 0 && matrix.d - E < 0) 
        {
            bSq = matrix.b * matrix.b;
            cSq = matrix.c * matrix.c;
            doSnap = bSq + E > 1 && bSq - E < 1 && cSq + E > 1 && cSq - E < 1;
        }
        
        if (doSnap) 
        {
            matrix.tx = Math.round(matrix.tx / pixelSize) * pixelSize;
            matrix.ty = Math.round(matrix.ty / pixelSize) * pixelSize;
        }
    }
    
    /** Sets the style that is used to render the mesh. Styles (which are always subclasses of
     *  <code>MeshStyle</code>) provide a means to completely modify the way a mesh is rendered.
     *  For example, they may add support for color transformations or normal mapping.
     *
     *  <p>When assigning a new style, the vertex format will be changed to fit it.
     *  Do not use the same style instance on multiple objects! Instead, make use of
     *  <code>style.clone()</code> to assign an identical style to multiple meshes.</p>
     *
     *  @param meshStyle             the style to assign. If <code>null</code>, an instance of
     *                               a standard <code>MeshStyle</code> will be created.
     *  @param mergeWithPredecessor  if enabled, all attributes of the previous style will be
     *                               be copied to the new one, if possible.
     */
    public function setStyle(meshStyle:MeshStyle = null, mergeWithPredecessor:Bool = true):Void
    {
        if (meshStyle == null) meshStyle = try cast(Type.createInstance(sDefaultStyle, []), MeshStyle) catch(e:Dynamic) null
        else if (meshStyle == _style) return;
        else if (meshStyle.target != null) meshStyle.target.setStyle();
        
        if (_style != null) 
        {
            if (mergeWithPredecessor)                 meshStyle.copyFrom(_style);
            _style.setTarget(null);
        }
        
        _style = meshStyle;
        _style.setTarget(this, _vertexData, _indexData);
    }
    
    // vertex manipulation
    
    /** Returns the alpha value of the vertex at the specified index. */
    public function getVertexAlpha(vertexID:Int):Float
    {
        return _style.getVertexAlpha(vertexID);
    }
    
    /** Sets the alpha value of the vertex at the specified index to a certain value. */
    public function setVertexAlpha(vertexID:Int, alpha:Float):Void
    {
        _style.setVertexAlpha(vertexID, alpha);
    }
    
    /** Returns the RGB color of the vertex at the specified index. */
    public function getVertexColor(vertexID:Int):Int
    {
        return _style.getVertexColor(vertexID);
    }
    
    /** Sets the RGB color of the vertex at the specified index to a certain value. */
    public function setVertexColor(vertexID:Int, color:Int):Void
    {
        _style.setVertexColor(vertexID, color);
    }
    
    /** Returns the texture coordinates of the vertex at the specified index. */
    public function getTexCoords(vertexID:Int, out:Point = null):Point
    {
        return _style.getTexCoords(vertexID, out);
    }
    
    /** Sets the texture coordinates of the vertex at the specified index to the given values. */
    public function setTexCoords(vertexID:Int, u:Float, v:Float):Void
    {
        _style.setTexCoords(vertexID, u, v);
    }
    
    // properties
    
    /** The vertex data describing all vertices of the mesh.
     *  Any change requires a call to <code>setRequiresRedraw</code>. */
    private function get_vertexData():VertexData
	{
		return _vertexData;
    }
    
    /** The index data describing how the vertices are interconnected.
     *  Any change requires a call to <code>setRequiresRedraw</code>. */
    private function get_indexData():IndexData
	{
		return _indexData;
    }
    
    /** The style that is used to render the mesh. Styles (which are always subclasses of
     *  <code>MeshStyle</code>) provide a means to completely modify the way a mesh is rendered.
     *  For example, they may add support for color transformations or normal mapping.
     *
     *  <p>The setter will simply forward the assignee to <code>setStyle(value)</code>.</p>
     *
     *  @default MeshStyle
     */
    private function get_style():MeshStyle
	{
		return _style;
    }
	
    private function set_style(value:MeshStyle):MeshStyle
    {
        setStyle(value);
        return value;
    }
    
    /** The texture that is mapped to the mesh (or <code>null</code>, if there is none). */
    private function get_texture():Texture
	{
		return _style.texture;
    }
	
    private function set_texture(value:Texture):Texture
	{
		_style.texture = value;
        return value;
    }
    
    /** Changes the color of all vertices to the same value.
     *  The getter simply returns the color of the first vertex. */
    private function get_color():Int
	{
		return _style.color;
    }
	
    private function set_color(value:Int):Int
	{
		_style.color = value;
        return value;
    }
    
    /** The smoothing filter that is used for the texture.
     *  @default bilinear */
    private function get_textureSmoothing():String
	{
		return _style.textureSmoothing;
    }
	
    private function set_textureSmoothing(value:String):String
	{
		_style.textureSmoothing = value;
        return value;
    }
    
    /** Controls whether or not the mesh object is snapped to the nearest pixel. This
     *  can prevent the object from looking blurry when it's not exactly aligned with the
     *  pixels of the screen. For this to work, the object must be unscaled and may only
     *  be rotated by multiples of 90 degrees. @default true */
    private function get_pixelSnapping():Bool
	{
		return _pixelSnapping;
    }
	
    private function set_pixelSnapping(value:Bool):Bool
	{
		_pixelSnapping = value;
        return value;
    }
    
    /** The total number of vertices in the mesh. */
    private function get_numVertices():Int {
		return _vertexData.numVertices;
    }
    
    /** The total number of indices referencing vertices. */
    private function get_numIndices():Int {
		return _indexData.numIndices;
    }
	
	/** The total number of vertices in the mesh. If you change this to a smaller value,
     *  the surplus will be deleted. Make sure that no indices reference those deleted
     *  vertices! */
    private function set_numVertices(value:Int):Int
    {
        throw new Error("Only available in MeshBatch");
        return 0;
    }
    
    /** The total number of indices in the mesh. If you change this to a smaller value,
     *  the surplus will be deleted. Always make sure that the number of indices
     *  is a multiple of three! */
    private function set_numIndices(value:Int):Int
    {
         throw new Error("Only available in MeshBatch");
        return 0;
    }
    
    /** The total number of triangles in this mesh.
     *  (In other words: the number of indices divided by three.) */
    private function get_numTriangles():Int
	{
		return _indexData.numTriangles;
    }
    
    /** The format used to store the vertices. */
    private function get_vertexFormat():VertexDataFormat
	{
		return _style.vertexFormat;
    }
    
    // static properties
    
    /** The default style used for meshes if no specific style is provided. The default is
     *  <code>starling.rendering.MeshStyle</code>, and any assigned class must be a subclass
     *  of the same. */
    private static function get_defaultStyle():Class<Dynamic>
	{
		return sDefaultStyle;
    }
	
    private static function set_defaultStyle(value:Class<Dynamic>):Class<Dynamic>
    {
        sDefaultStyle = value;
        return value;
    }
}