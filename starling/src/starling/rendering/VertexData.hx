// =================================================================================================
//
//  Starling Framework
//  Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.rendering;

import flash.display3D.Context3DBufferUsage;
import flash.display3D.Context3DVertexBufferFormat;
import flash.errors.ArgumentError;
import starling.rendering.VertexDataAttribute;
import starling.rendering.VertexDataFormat;

import flash.display3D.Context3D;
import flash.display3D.VertexBuffer3D;
import flash.errors.IllegalOperationError;
import flash.geom.Matrix;
import flash.geom.Matrix3D;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.geom.Vector3D;
import flash.utils.ByteArray;
import flash.utils.Endian;

import starling.core.Starling;
import starling.errors.MissingContextError;
import starling.utils.MathUtil;
import starling.utils.MatrixUtil;
import starling.utils.StringUtil;

/** The VertexData class manages a raw list of vertex information, allowing direct upload
 *  to Stage3D vertex buffers. <em>You only have to work with this class if you're writing
 *  your own rendering code (e.g. if you create custom display objects).</em>
 *
 *  <p>To render objects with Stage3D, you have to organize vertices and indices in so-called
 *  vertex- and index-buffers. Vertex buffers store the coordinates of the vertices that make
 *  up an object; index buffers reference those vertices to determine which vertices spawn
 *  up triangles. Those buffers reside in graphics memory and can be accessed very
 *  efficiently by the GPU.</p>
 *
 *  <p>Before you can move data into the buffers, you have to set it up in conventional
 *  memory — that is, in a Vector or a ByteArray. Since it's quite cumbersome to manually
 *  create and manipulate those data structures, the IndexData and VertexData classes provide
 *  a simple way to do just that. The data is stored in a ByteArray (one index or vertex after
 *  the other) that can easily be uploaded to a buffer.</p>
 *
 *  <strong>Vertex Format</strong>
 *
 *  <p>The VertexData class requires a custom format string on initialization, or an instance
 *  of the VertexDataFormat class. Here is an example:</p>
 *
 *  <listing>
 *  vertexData = new VertexData("position:float2, color:bytes4");
 *  vertexData.setPoint(0, "position", 320, 480);
 *  vertexData.setColor(0, "color", 0xff00ff);</listing>
 *
 *  <p>This instance is set up with two attributes: "position" and "color". The keywords
 *  after the colons depict the format and size of the data that each property uses; in this
 *  case, we store two floats for the position (for the x- and y-coordinates) and four
 *  bytes for the color. Please refer to the VertexDataFormat documentation for details.</p>
 *
 *  <p>The attribute names are then used to read and write data to the respective positions
 *  inside a vertex. Furthermore, they come in handy when copying data from one VertexData
 *  instance to another: attributes with equal name and data format may be transferred between
 *  different VertexData objects, even when they contain different sets of attributes or have
 *  a different layout.</p>
 *
 *  <strong>Colors</strong>
 *
 *  <p>Always use the format <code>bytes4</code> for color data. The color access methods
 *  expect that format, since it's the most efficient way to store color data. Furthermore,
 *  you should always include the string "color" (or "Color") in the name of color data;
 *  that way, it will be recognized as such and will always have its alpha value pre-filled
 *  with the value "1.0".</p>
 *
 *  <strong>Premultiplied Alpha</strong>
 *
 *  <p>Per default, color values are stored with premultiplied alpha values, which
 *  means that the <code>rgb</code> values were multiplied with the <code>alpha</code> values
 *  before saving them. You can change this behavior with the <code>premultipliedAlpha</code>
 *  property.</p>
 *
 *  <p>Beware: with premultiplied alpha, the alpha value always effects the resolution of
 *  the RGB channels. A small alpha value results in a lower accuracy of the other channels,
 *  and if the alpha value reaches zero, the color information is lost altogether.</p>
 *
 *  @see VertexDataFormat
 *  @see IndexData
 */
class VertexData
{
    public var premultipliedAlpha(get, set):Bool;
    public var numVertices(get, set):Int;
    public var rawData(get, never):ByteArray;
    public var format(get, set):VertexDataFormat;
    public var formatString(get, never):String;
    public var vertexSizeInBytes(get, never):Int;
    public var vertexSizeIn32Bits(get, never):Int;
    public var sizeInBytes(get, never):Int;
    public var sizeIn32Bits(get, never):Int;

    private var _rawData:ByteArray;
    private var _numVertices:Int;
    private var _format:VertexDataFormat;
    private var _attributes:Array<VertexDataAttribute>;
    private var _numAttributes:Int;
    private var _premultipliedAlpha:Bool;
    
    private var _posOffset:Int;  // in bytes  
    private var _colOffset:Int;  // in bytes  
    private var _vertexSize:Int;  // in bytes  
    
    // helper objects
    private static var sHelperPoint:Point = new Point();
    private static var sHelperPoint3D:Vector3D = new Vector3D();
    private static var sBytes:ByteArray = new ByteArray();
    
    /** Creates an empty VertexData object with the given format and initial capacity.
     *
     *  @param format
     *
     *  Either a VertexDataFormat instance or a String that describes the data format.
     *  Refer to the VertexDataFormat class for more information. If you don't pass a format,
     *  the default <code>MeshStyle.VERTEX_FORMAT</code> will be used.
     *
     *  @param initialCapacity
     *
     *  The initial capacity affects just the way the internal ByteArray is allocated, not the
     *  <code>numIndices</code> value, which will always be zero when the constructor returns.
     *  The reason for this behavior is the peculiar way in which ByteArrays organize their
     *  memory:
     *
     *  <p>The first time you set the length of a ByteArray, it will adhere to that:
     *  a ByteArray with length 20 will take up 20 bytes (plus some overhead). When you change
     *  it to a smaller length, it will stick to the original value, e.g. with a length of 10
     *  it will still take up 20 bytes. However, now comes the weird part: change it to
     *  anything above the original length, and it will allocate 4096 bytes!</p>
     *
     *  <p>Thus, be sure to always make a generous educated guess, depending on the planned
     *  usage of your VertexData instances.</p>
     */
    public function new(format:Dynamic = null, initialCapacity:Int = 32)
    {
        if (format == null)             _format = MeshStyle.VERTEX_FORMAT
        else if (Std.is(format, VertexDataFormat))             _format = format
        else if (Std.is(format, String))             _format = VertexDataFormat.fromString(try cast(format, String) catch(e:Dynamic) null)
        else throw new ArgumentError("'format' must be String or VertexDataFormat");
        
        _attributes = _format.attributes;
        _numAttributes = _attributes.length;
        _posOffset = (_format.hasAttribute("position")) ? _format.getOffsetInBytes("position"):0;
        _colOffset = (_format.hasAttribute("color")) ? _format.getOffsetInBytes("color"):0;
        _vertexSize = _format.vertexSizeInBytes;
        _numVertices = 0;
        _premultipliedAlpha = true;
        _rawData = new ByteArray();
        _rawData.endian = sBytes.endian = Endian.LITTLE_ENDIAN;
        _rawData.length = initialCapacity * _vertexSize;  // just for the initial allocation  
        _rawData.length = 0;
    }
    
    /** Explicitly frees up the memory used by the ByteArray. */
    public function clear():Void
    {
        _rawData.clear();
        _numVertices = 0;
    }
    
    /** Creates a duplicate of the vertex data object. */
    public function clone():VertexData
    {
        var clone:VertexData = new VertexData(_format, _numVertices);
        clone._rawData.writeBytes(_rawData);
        clone._numVertices = _numVertices;
        clone._premultipliedAlpha = _premultipliedAlpha;
        return clone;
    }
    
    /** Copies the vertex data (or a range of it, defined by 'vertexID' and 'numVertices')
     *  of this instance to another vertex data object, starting at a certain target index.
     *  If the target is not big enough, it will be resized to fit all the new vertices.
     *
     *  <p>If you pass a non-null matrix, the 2D position of each vertex will be transformed
     *  by that matrix before storing it in the target object. (The position being either an
     *  attribute with the name "position" or, if such an attribute is not found, the first
     *  attribute of each vertex. It must consist of two float values containing the x- and
     *  y-coordinates of the vertex.)</p>
     *
     *  <p>Source and target do not need to have the exact same format. Only properties that
     *  exist in the target will be copied; others will be ignored. If a property with the
     *  same name but a different format exists in the target, an exception will be raised.
     *  Beware, though, that the copy-operation becomes much more expensive when the formats
     *  differ.</p>
     */
    public function copyTo(target:VertexData, targetVertexID:Int = 0, matrix:Matrix = null,
            vertexID:Int = 0, numVertices:Int = -1):Void
    {
        if (numVertices < 0 || vertexID + numVertices > _numVertices) 
            numVertices = _numVertices - vertexID;
        
        if (_format == target._format) 
        {
            if (target._numVertices < targetVertexID + numVertices) 
                target._numVertices = targetVertexID + numVertices;
			
			// and then overwrite only the transformed positions.    // In this case, it's fastest to copy the complete range in one call  ;
            var targetRawData:ByteArray = target._rawData;
            targetRawData.position = targetVertexID * _vertexSize;
            targetRawData.writeBytes(_rawData, vertexID * _vertexSize, numVertices * _vertexSize);
            
            if (matrix != null) 
            {
                var x:Float;
                var y:Float;
                var position:Int = targetVertexID * _vertexSize + _posOffset;
                var endPosition:Int = position + (numVertices * _vertexSize);
                
                while (position < endPosition)
                {
                    targetRawData.position = position;
                    x = targetRawData.readFloat();
                    y = targetRawData.readFloat();
                    
                    targetRawData.position = position;
                    targetRawData.writeFloat(matrix.a * x + matrix.c * y + matrix.tx);
                    targetRawData.writeFloat(matrix.d * y + matrix.b * x + matrix.ty);
                    
                    position += _vertexSize;
                }
            }
        }
        else 
        {
            if (target._numVertices < targetVertexID + numVertices) 
                target.numVertices = targetVertexID + numVertices;
			
			// ensure correct alphas!
            for (i in 0..._numAttributes){
                var srcAttr:VertexDataAttribute = _attributes[i];
                var tgtAttr:VertexDataAttribute = target.getAttribute(srcAttr.name);
                
                if (tgtAttr != null)   // only copy attributes that exist in the target, as well  
                {
                    if (srcAttr.offset == _posOffset) 
                        copyAttributeTo_internal(target, targetVertexID, matrix,
                            srcAttr, tgtAttr, vertexID, numVertices)
                    else 
                    copyAttributeTo_internal(target, targetVertexID, null,
                            srcAttr, tgtAttr, vertexID, numVertices);
                }
            }
        }
    }
    
    /** Copies a specific attribute of all contained vertices (or a range of them, defined by
     *  'vertexID' and 'numVertices') to another VertexData instance. Beware that both name
     *  and format of the attribute must be identical in source and target.
     *  If the target is not big enough, it will be resized to fit all the new vertices.
     *
     *  <p>If you pass a non-null matrix, the specified attribute will be transformed by
     *  that matrix before storing it in the target object. It must consist of two float
     *  values.</p>
     */
    public function copyAttributeTo(target:VertexData, targetVertexID:Int, attrName:String,
            matrix:Matrix = null, vertexID:Int = 0, numVertices:Int = -1):Void
    {
        var sourceAttribute:VertexDataAttribute = getAttribute(attrName);
        var targetAttribute:VertexDataAttribute = target.getAttribute(attrName);
        
        if (sourceAttribute == null) 
            throw new ArgumentError("Attribute '" + attrName + "' not found in source data");
        
        if (targetAttribute == null) 
            throw new ArgumentError("Attribute '" + attrName + "' not found in target data");
        
        copyAttributeTo_internal(target, targetVertexID, matrix,
                sourceAttribute, targetAttribute, vertexID, numVertices);
    }
    
    private function copyAttributeTo_internal(
            target:VertexData, targetVertexID:Int, matrix:Matrix,
            sourceAttribute:VertexDataAttribute, targetAttribute:VertexDataAttribute,
            vertexID:Int, numVertices:Int):Void
    {
        if (sourceAttribute.format != targetAttribute.format) 
            throw new IllegalOperationError("Attribute formats differ between source and target");
        
        if (numVertices < 0 || vertexID + numVertices > _numVertices) 
            numVertices = _numVertices - vertexID;
        
        if (target._numVertices < targetVertexID + numVertices) 
            target._numVertices = targetVertexID + numVertices;
        
        var i:Int;
        var j:Int;
        var x:Float;
        var y:Float;
        var sourceData:ByteArray = _rawData;
        var targetData:ByteArray = target._rawData;
        var sourceDelta:Int = _vertexSize - sourceAttribute.size;
        var targetDelta:Int = target._vertexSize - targetAttribute.size;
        var attributeSizeIn32Bits:Int = untyped sourceAttribute.size / 4;
        
        sourceData.position = vertexID * _vertexSize + sourceAttribute.offset;
        targetData.position = targetVertexID * target._vertexSize + targetAttribute.offset;
        
        if (matrix != null) 
        {
            for (i in 0...numVertices){
                x = sourceData.readFloat();
                y = sourceData.readFloat();
                
                targetData.writeFloat(matrix.a * x + matrix.c * y + matrix.tx);
                targetData.writeFloat(matrix.d * y + matrix.b * x + matrix.ty);
                
                sourceData.position += sourceDelta;
                targetData.position += targetDelta;
            }
        }
        else 
        {
            for (i in 0...numVertices){
                for (j in 0...attributeSizeIn32Bits){targetData.writeUnsignedInt(sourceData.readUnsignedInt());
                }
                
                sourceData.position += sourceDelta;
                targetData.position += targetDelta;
            }
        }
    }
    
    /** Optimizes the ByteArray so that it has exactly the required capacity, without
     *  wasting any memory. If your VertexData object grows larger than the initial capacity
     *  you passed to the constructor, call this method to avoid the 4k memory problem. */
    public function trim():Void
    {
        sBytes.length = _rawData.length;
        sBytes.position = 0;
        sBytes.writeBytes(_rawData);
        
        _rawData.clear();
        _rawData.length = sBytes.length;
        _rawData.writeBytes(sBytes);
        
        sBytes.clear();
    }
    
    /** Returns a string representation of the VertexData object,
     *  describing both its format and size. */
    public function toString():String
    {
        return StringTools.format(
			"[VertexData format=\"{0}\" numVertices={1}]",
            [_format.formatString, _numVertices]
		);
    }
    
    // read / write attributes
    
    /** Reads a float value from the specified vertex and attribute. */
    public function getFloat(vertexID:Int, attrName:String):Float
    {
        _rawData.position = vertexID * _vertexSize + getAttribute(attrName).offset;
        return _rawData.readFloat();
    }
    
    /** Writes a float value to the specified vertex and attribute. */
    public function setFloat(vertexID:Int, attrName:String, value:Float):Void
    {
        if (_numVertices < vertexID + 1) 
            numVertices = vertexID + 1;
        
        _rawData.position = vertexID * _vertexSize + getAttribute(attrName).offset;
        _rawData.writeFloat(value);
    }
    
    /** Reads a Point from the specified vertex and attribute. */
    public function getPoint(vertexID:Int, attrName:String, out:Point = null):Point
    {
        if (out == null)             out = new Point();
        
        var offset:Int = attrName == ("position") ? _posOffset:getAttribute(attrName).offset;
        _rawData.position = vertexID * _vertexSize + offset;
        out.x = _rawData.readFloat();
        out.y = _rawData.readFloat();
        
        return out;
    }
    
    /** Writes the given coordinates to the specified vertex and attribute. */
    public function setPoint(vertexID:Int, attrName:String, x:Float, y:Float):Void
    {
        if (_numVertices < vertexID + 1) 
            numVertices = vertexID + 1;
        
        var offset:Int = attrName == ("position") ? _posOffset:getAttribute(attrName).offset;
        _rawData.position = vertexID * _vertexSize + offset;
        _rawData.writeFloat(x);
        _rawData.writeFloat(y);
    }
    
    /** Reads a Vector3D from the specified vertex and attribute.
     *  The 'w' property of the Vector3D is ignored. */
    public function getPoint3D(vertexID:Int, attrName:String, out:Vector3D = null):Vector3D
    {
        if (out == null)             out = new Vector3D();
        
        _rawData.position = vertexID * _vertexSize + getAttribute(attrName).offset;
        out.x = _rawData.readFloat();
        out.y = _rawData.readFloat();
        out.z = _rawData.readFloat();
        
        return out;
    }
    
    /** Writes the given coordinates to the specified vertex and attribute. */
    public function setPoint3D(vertexID:Int, attrName:String, x:Float, y:Float, z:Float):Void
    {
        if (_numVertices < vertexID + 1) 
            numVertices = vertexID + 1;
        
        _rawData.position = vertexID * _vertexSize + getAttribute(attrName).offset;
        _rawData.writeFloat(x);
        _rawData.writeFloat(y);
        _rawData.writeFloat(z);
    }
    
    /** Reads a Vector3D from the specified vertex and attribute, including the fourth
     *  coordinate ('w'). */
    public function getPoint4D(vertexID:Int, attrName:String, out:Vector3D = null):Vector3D
    {
        if (out == null)             out = new Vector3D();
        
        _rawData.position = vertexID * _vertexSize + getAttribute(attrName).offset;
        out.x = _rawData.readFloat();
        out.y = _rawData.readFloat();
        out.z = _rawData.readFloat();
        out.w = _rawData.readFloat();
        
        return out;
    }
    
    /** Writes the given coordinates to the specified vertex and attribute. */
    public function setPoint4D(vertexID:Int, attrName:String,
            x:Float, y:Float, z:Float, w:Float = 1.0):Void
    {
        if (_numVertices < vertexID + 1) 
            numVertices = vertexID + 1;
        
        _rawData.position = vertexID * _vertexSize + getAttribute(attrName).offset;
        _rawData.writeFloat(x);
        _rawData.writeFloat(y);
        _rawData.writeFloat(z);
        _rawData.writeFloat(w);
    }
    
    /** Reads an RGB color from the specified vertex and attribute (no alpha). */
    public function getColor(vertexID:Int, attrName:String = "color"):Int
    {
        var offset:Int = attrName == ("color") ? _colOffset:getAttribute(attrName).offset;
        _rawData.position = vertexID * _vertexSize + offset;
        var rgba:Int = switchEndian(_rawData.readUnsignedInt());
        if (_premultipliedAlpha)             rgba = unmultiplyAlpha(rgba);
        return (rgba >> 8) & 0xffffff;
    }
    
    /** Writes the RGB color to the specified vertex and attribute (alpha is not changed). */
    public function setColor(vertexID:Int, attrName:String, color:Int):Void
    {
        if (_numVertices < vertexID + 1) 
            numVertices = vertexID + 1;
        
        var alpha:Float = getAlpha(vertexID, attrName);
        colorize(attrName, color, alpha, vertexID, 1);
    }
    
    /** Reads the alpha value from the specified vertex and attribute. */
    public function getAlpha(vertexID:Int, attrName:String = "color"):Float
    {
        var offset:Int = attrName == ("color") ? _colOffset:getAttribute(attrName).offset;
        _rawData.position = vertexID * _vertexSize + offset;
        var rgba:Int = switchEndian(_rawData.readUnsignedInt());
        return (rgba & 0xff) / 255.0;
    }
    
    /** Writes the given alpha value to the specified vertex and attribute (range 0-1). */
    public function setAlpha(vertexID:Int, attrName:String, alpha:Float):Void
    {
        if (_numVertices < vertexID + 1) 
            numVertices = vertexID + 1;
        
        var color:Int = getColor(vertexID, attrName);
        colorize(attrName, color, alpha, vertexID, 1);
    }
    
    // bounds helpers
    
    /** Calculates the bounds of the 2D vertex positions identified by the given name.
     *  The positions may optionally be transformed by a matrix before calculating the bounds.
     *  If you pass an 'out' Rectangle, the result will be stored in this rectangle
     *  instead of creating a new object. To use all vertices for the calculation, set
     *  'numVertices' to '-1'. */
    public function getBounds(attrName:String = "position", matrix:Matrix = null,
            vertexID:Int = 0, numVertices:Int = -1, out:Rectangle = null):Rectangle
    {
        if (out == null)             out = new Rectangle();
        if (numVertices < 0 || vertexID + numVertices > _numVertices) 
            numVertices = _numVertices - vertexID;
        
        if (numVertices == 0) 
        {
            if (matrix == null) 
                out.setEmpty()
            else 
            {
                MatrixUtil.transformCoords(matrix, 0, 0, sHelperPoint);
                out.setTo(sHelperPoint.x, sHelperPoint.y, 0, 0);
            }
        }
        else 
        {
            var minX:Float = Math.POSITIVE_INFINITY;
            var maxX:Float = Math.NEGATIVE_INFINITY;
            var minY:Float = Math.POSITIVE_INFINITY;
            var maxY:Float = Math.NEGATIVE_INFINITY;
            var offset:Int = attrName == ("position") ? _posOffset:getAttribute(attrName).offset;
            var position:Int = vertexID * _vertexSize + offset;
            var x:Float;
            var y:Float;
            var i:Int;
            
            if (matrix == null) 
            {
                for (i in 0...numVertices){
                    _rawData.position = position;
                    x = _rawData.readFloat();
                    y = _rawData.readFloat();
                    position += _vertexSize;
                    
                    if (minX > x)                         minX = x;
                    if (maxX < x)                         maxX = x;
                    if (minY > y)                         minY = y;
                    if (maxY < y)                         maxY = y;
                }
            }
            else 
            {
                for (i in 0...numVertices){
                    _rawData.position = position;
                    x = _rawData.readFloat();
                    y = _rawData.readFloat();
                    position += _vertexSize;
                    
                    MatrixUtil.transformCoords(matrix, x, y, sHelperPoint);
                    
                    if (minX > sHelperPoint.x)                         minX = sHelperPoint.x;
                    if (maxX < sHelperPoint.x)                         maxX = sHelperPoint.x;
                    if (minY > sHelperPoint.y)                         minY = sHelperPoint.y;
                    if (maxY < sHelperPoint.y)                         maxY = sHelperPoint.y;
                }
            }
            
            out.setTo(minX, minY, maxX - minX, maxY - minY);
        }
        
        return out;
    }
    
    /** Calculates the bounds of the 2D vertex positions identified by the given name,
     *  projected into the XY-plane of a certain 3D space as they appear from the given
     *  camera position. Note that 'camPos' is expected in the target coordinate system
     *  (the same that the XY-plane lies in).
     *
     *  <p>If you pass an 'out' Rectangle, the result will be stored in this rectangle
     *  instead of creating a new object. To use all vertices for the calculation, set
     *  'numVertices' to '-1'.</p> */
    public function getBoundsProjected(attrName:String, matrix:Matrix3D,
            camPos:Vector3D, vertexID:Int = 0, numVertices:Int = -1,
            out:Rectangle = null):Rectangle
    {
        if (out == null)             out = new Rectangle();
        if (camPos == null)             throw new ArgumentError("camPos must not be null");
        if (numVertices < 0 || vertexID + numVertices > _numVertices) 
            numVertices = _numVertices - vertexID;
        
        if (numVertices == 0) 
        {
            if (matrix != null) 
                MatrixUtil.transformCoords3D(matrix, 0, 0, 0, sHelperPoint3D)
            else 
            sHelperPoint3D.setTo(0, 0, 0);
            
            MathUtil.intersectLineWithXYPlane(camPos, sHelperPoint3D, sHelperPoint);
            out.setTo(sHelperPoint.x, sHelperPoint.y, 0, 0);
        }
        else 
        {
            var minX:Float = Math.POSITIVE_INFINITY;
            var maxX:Float = Math.NEGATIVE_INFINITY;
            var minY:Float = Math.POSITIVE_INFINITY;
            var maxY:Float = Math.NEGATIVE_INFINITY;
            var offset:Int = attrName == ("position") ? _posOffset:getAttribute(attrName).offset;
            var position:Int = vertexID * _vertexSize + offset;
            var x:Float;
            var y:Float;
            var i:Int;
            
            for (i in 0...numVertices){
                _rawData.position = position;
                x = _rawData.readFloat();
                y = _rawData.readFloat();
                position += _vertexSize;
                
                if (matrix != null) 
                    MatrixUtil.transformCoords3D(matrix, x, y, 0, sHelperPoint3D)
                else 
                sHelperPoint3D.setTo(x, y, 0);
                
                MathUtil.intersectLineWithXYPlane(camPos, sHelperPoint3D, sHelperPoint);
                
                if (minX > sHelperPoint.x)                     minX = sHelperPoint.x;
                if (maxX < sHelperPoint.x)                     maxX = sHelperPoint.x;
                if (minY > sHelperPoint.y)                     minY = sHelperPoint.y;
                if (maxY < sHelperPoint.y)                     maxY = sHelperPoint.y;
            }
            
            out.setTo(minX, minY, maxX - minX, maxY - minY);
        }
        
        return out;
    }
    
    /** Indicates if color attributes should be stored premultiplied with the alpha value.
     *  Changing this value does <strong>not</strong> modify any existing color data.
     *  If you want that, use the <code>setPremultipliedAlpha</code> method instead.
     *  @default true */
    private function get_premultipliedAlpha():Bool
	{
		return _premultipliedAlpha;
    }
	
    private function set_premultipliedAlpha(value:Bool):Bool
    {
        setPremultipliedAlpha(value, false);
        return value;
    }
    
    /** Changes the way alpha and color values are stored. Optionally updates all existing
     *  vertices. */
    public function setPremultipliedAlpha(value:Bool, updateData:Bool):Void
    {
        if (updateData && value != _premultipliedAlpha) 
        {
            for (i in 0..._numAttributes){
                var attribute:VertexDataAttribute = _attributes[i];
                if (attribute.isColor) 
                {
                    var offset:Int = attribute.offset;
                    var oldColor:Int;
                    var newColor:Int;
                    
                    for (j in 0..._numVertices){
                        _rawData.position = offset;
                        oldColor = switchEndian(_rawData.readUnsignedInt());
                        newColor = (value) ? premultiplyAlpha(oldColor):unmultiplyAlpha(oldColor);
                        
                        _rawData.position = offset;
                        _rawData.writeUnsignedInt(switchEndian(newColor));
                        
                        offset += _vertexSize;
                    }
                }
            }
        }
        
        _premultipliedAlpha = value;
    }
    
    /** Indicates if any vertices have a non-white color or are not fully opaque. */
    public function isTinted(attrName:String = "color"):Bool
    {
        var offset:Int = attrName == ("color") ? _colOffset:getAttribute(attrName).offset;
        
        for (i in 0..._numVertices){
            _rawData.position = offset;
            
            if (_rawData.readUnsignedInt() != 0xffffffff) 
                return true;
            
            offset += _vertexSize;
        }
        
        return false;
    }
    
    // modify multiple attributes
    
    /** Transforms the 2D positions of subsequent vertices by multiplication with a
     *  transformation matrix. */
    public function transformPoints(attrName:String, matrix:Matrix,
            vertexID:Int = 0, numVertices:Int = -1):Void
    {
        if (numVertices < 0 || vertexID + numVertices > _numVertices) 
            numVertices = _numVertices - vertexID;
        
        var x:Float;
        var y:Float;
        var offset:Int = attrName == ("position") ? _posOffset:getAttribute(attrName).offset;
        var position:Int = vertexID * _vertexSize + offset;
        var endPosition:Int = position + (numVertices * _vertexSize);
        
        while (position < endPosition)
        {
            _rawData.position = position;
            x = _rawData.readFloat();
            y = _rawData.readFloat();
            
            _rawData.position = position;
            _rawData.writeFloat(matrix.a * x + matrix.c * y + matrix.tx);
            _rawData.writeFloat(matrix.d * y + matrix.b * x + matrix.ty);
            
            position += _vertexSize;
        }
    }
    
    /** Translates the 2D positions of subsequent vertices by a certain offset. */
    public function translatePoints(attrName:String, deltaX:Float, deltaY:Float,
            vertexID:Int = 0, numVertices:Int = -1):Void
    {
        if (numVertices < 0 || vertexID + numVertices > _numVertices) 
            numVertices = _numVertices - vertexID;
        
        var x:Float;
        var y:Float;
        var offset:Int = attrName == ("position") ? _posOffset:getAttribute(attrName).offset;
        var position:Int = vertexID * _vertexSize + offset;
        var endPosition:Int = position + (numVertices * _vertexSize);
        
        while (position < endPosition)
        {
            _rawData.position = position;
            x = _rawData.readFloat();
            y = _rawData.readFloat();
            
            _rawData.position = position;
            _rawData.writeFloat(x + deltaX);
            _rawData.writeFloat(y + deltaY);
            
            position += _vertexSize;
        }
    }
    
    /** Multiplies the alpha values of subsequent vertices by a certain factor. */
    public function scaleAlphas(attrName:String, factor:Float,
            vertexID:Int = 0, numVertices:Int = -1):Void
    {
        if (factor == 1.0)             return;
        if (numVertices < 0 || vertexID + numVertices > _numVertices) 
            numVertices = _numVertices - vertexID;
        
        var i:Int;
        var offset:Int = attrName == ("color") ? _colOffset:getAttribute(attrName).offset;
        var colorPos:Int = vertexID * _vertexSize + offset;
        var alphaPos:Int;
        var alpha:Float;
        var rgba:Int;
        
        for (i in 0...numVertices){
            alphaPos = colorPos + 3;
            alpha = _rawData[alphaPos] / 255.0 * factor;
            
            if (alpha > 1.0)                 alpha = 1.0
            else if (alpha < 0.0)                 alpha = 0.0;
            
            if (alpha == 1.0 || !_premultipliedAlpha) 
            {
                _rawData[alphaPos] = cast(alpha * 255.0, Int);
            }
            else 
            {
                _rawData.position = colorPos;
                rgba = unmultiplyAlpha(switchEndian(_rawData.readUnsignedInt()));
                rgba = (rgba & 0xffffff00) | (cast (alpha * 255.0, Int) & 0xff);
                rgba = premultiplyAlpha(rgba);
                
                _rawData.position = colorPos;
                _rawData.writeUnsignedInt(switchEndian(rgba));
            }
            
            colorPos += _vertexSize;
        }
    }
    
    /** Writes the given RGB and alpha values to the specified vertices. */
    public function colorize(attrName:String, color:Int, alpha:Float = 1.0,
            vertexID:Int = 0, numVertices:Int = -1):Void
    {
        if (numVertices < 0 || vertexID + numVertices > _numVertices) 
            numVertices = _numVertices - vertexID;
        
        var offset:Int = attrName == ("color") ? _colOffset:getAttribute(attrName).offset;
        var position:Int = vertexID * _vertexSize + offset;
        var endPosition:Int = position + (numVertices * _vertexSize);
        
        if (alpha > 1.0)             alpha = 1.0
        else if (alpha < 0.0)             alpha = 0.0;
        
        var rgba:Int = ((color << 8) & 0xffffff00) | (cast(alpha * 255.0, Int) & 0xff);
        if (_premultipliedAlpha && alpha != 1.0)             rgba = premultiplyAlpha(rgba);
        
        _rawData.position = vertexID * _vertexSize + offset;
        _rawData.writeUnsignedInt(switchEndian(rgba));
        
        while (position < endPosition)
        {
            _rawData.position = position;
            _rawData.writeUnsignedInt(switchEndian(rgba));
            position += _vertexSize;
        }
    }
    
    // format helpers
    
    /** Returns the format of a certain vertex attribute, identified by its name.
      * Typical values: <code>float1, float2, float3, float4, bytes4</code>. */
    public function getFormat(attrName:String):Context3DVertexBufferFormat
    {
        return getAttribute(attrName).format;
    }
    
    /** Returns the size of a certain vertex attribute in bytes. */
    public function getSizeInBytes(attrName:String):Int
    {
        return getAttribute(attrName).size;
    }
    
    /** Returns the size of a certain vertex attribute in 32 bit units. */
    public function getSizeIn32Bits(attrName:String):Int
    {
        return untyped getAttribute(attrName).size / 4;
    }
    
    /** Returns the offset (in bytes) of an attribute within a vertex. */
    public function getOffsetInBytes(attrName:String):Int
    {
        return getAttribute(attrName).offset;
    }
    
    /** Returns the offset (in 32 bit units) of an attribute within a vertex. */
    public function getOffsetIn32Bits(attrName:String):Int
    {
        return untyped getAttribute(attrName).offset / 4;
    }
    
    /** Indicates if the VertexData instances contains an attribute with the specified name. */
    public function hasAttribute(attrName:String):Bool
    {
        return getAttribute(attrName) != null;
    }
    
    // VertexBuffer helpers
    
    /** Creates a vertex buffer object with the right size to fit the complete data.
     *  Optionally, the current data is uploaded right away. */
    public function createVertexBuffer(upload:Bool = false,
            bufferUsage:Context3DBufferUsage = null):VertexBuffer3D
    {
		if (bufferUsage == null) bufferUsage = Context3DBufferUsage.STATIC_DRAW;
        var context:Context3D = Starling.Context;
        if (context == null)             throw new MissingContextError();
        if (_numVertices == 0)             return null;
        
        var buffer:VertexBuffer3D = context.createVertexBuffer(
                _numVertices, untyped _vertexSize / 4, bufferUsage);
        
        if (upload)             uploadToVertexBuffer(buffer);
        return buffer;
    }
    
    /** Uploads the complete data (or a section of it) to the given vertex buffer. */
    public function uploadToVertexBuffer(buffer:VertexBuffer3D, vertexID:Int = 0, numVertices:Int = -1):Void
    {
        if (numVertices < 0 || vertexID + numVertices > _numVertices) 
            numVertices = _numVertices - vertexID;
        
        if (numVertices > 0) 
            buffer.uploadFromByteArray(_rawData, 0, vertexID, numVertices);
    }
    
    @:meta(Inline())

    @:final private function getAttribute(attrName:String):VertexDataAttribute
    {
        var i:Int;
        var attribute:VertexDataAttribute;
        
        for (i in 0..._numAttributes){
            attribute = _attributes[i];
            if (attribute.name == attrName) return attribute;
        }
        
        return null;
    }
    
    @:meta(Inline())

    private static function switchEndian(value:Int):Int
    {
        return (value & 0xff) << 24 |
        ((value >> 8) & 0xff) << 16 |
        ((value >> 16) & 0xff) << 8 |
        ((value >> 24) & 0xff);
    }
    
    private static function premultiplyAlpha(rgba:Int):Int
    {
        var alpha:Int = rgba & 0xff;
        
        if (alpha == 0xff)             return rgba
        else 
        {
            var factor:Float = alpha / 255.0;
            var r:Int = untyped ((rgba >> 24) & 0xff) * factor;
            var g:Int = untyped ((rgba >> 16) & 0xff) * factor;
            var b:Int = untyped ((rgba >> 8) & 0xff) * factor;
            
            return (r & 0xff) << 24 |
            (g & 0xff) << 16 |
            (b & 0xff) << 8 | alpha;
        }
    }
    
    private static function unmultiplyAlpha(rgba:Int):Int
    {
        var alpha:Int = rgba & 0xff;
        
        if (alpha == 0xff || alpha == 0x0)             return rgba
        else 
        {
            var factor:Float = alpha / 255.0;
            var r:Int = untyped ((rgba >> 24) & 0xff) / factor;
            var g:Int = untyped ((rgba >> 16) & 0xff) / factor;
            var b:Int = untyped ((rgba >> 8) & 0xff) / factor;
            
            return (r & 0xff) << 24 |
            (g & 0xff) << 16 |
            (b & 0xff) << 8 | alpha;
        }
    }
    
    // properties
    
    /** The total number of vertices. If you make the object bigger, it will be filled up with
     *  <code>1.0</code> for all alpha values and zero for everything else. */
    private function get_numVertices():Int
	{
		return _numVertices;
    }
	
    private function set_numVertices(value:Int):Int
    {
        if (_numVertices == value) return value;
        
        _rawData.length = value * _vertexSize;
        
        for (i in 0..._numAttributes){
            var attribute:VertexDataAttribute = _attributes[i];
            if (attribute.isColor) 
            {
                // alpha values of all color-properties must be initialized with "1.0"
                var offset:Int = attribute.offset + 3;
                for (j in _numVertices...value){_rawData[j * _vertexSize + offset] = 0xff;
                }
            }
        }
        
        _numVertices = value;
        return value;
    }
    
    /** The raw vertex data; not a copy! */
    private function get_rawData():ByteArray
    {
        return _rawData;
    }
    
    /** The format that describes the attributes of each vertex.
     *  When you assign a different format, the raw data will be converted accordingly,
     *  i.e. attributes with the same name will still point to the same data.
     *  New properties will be filled up with zeros (except for colors, which will be
     *  initialized with an alpha value of 1.0). As a side-effect, the instance will also
     *  be trimmed. */
    private function get_format():VertexDataFormat
    {
        return _format;
    }
    
    private function set_format(value:VertexDataFormat):VertexDataFormat
    {
        if (_format == value) return value;
        
        var a:Int;
        var i:Int;
        var srcVertexSize:Int = _format.vertexSizeInBytes;
        var tgtVertexSize:Int = value.vertexSizeInBytes;
        var numAttributes:Int = value.numAttributes;
        
        sBytes.length = value.vertexSizeInBytes * _numVertices;
        
        for (a in 0...numAttributes){
            var tgtAttr:VertexDataAttribute = value.attributes[a];
            var srcAttr:VertexDataAttribute = getAttribute(tgtAttr.name);
            
            if (srcAttr != null)   // copy attributes that exist in both targets  
            {
                for (i in 0..._numVertices){
                    sBytes.position = tgtVertexSize * i + tgtAttr.offset;
                    sBytes.writeBytes(_rawData, srcVertexSize * i + srcAttr.offset, srcAttr.size);
                }
            }
            else if (tgtAttr.isColor)   // initialize color values with an alpha of "1.0"  
            {
                var offset:Int = tgtAttr.offset + 3;
                for (i in 0..._numVertices){sBytes[tgtVertexSize * i + offset] = 0xff;
                }
            }
        }
        
        _rawData.clear();
        _rawData.length = sBytes.length;
        _rawData.writeBytes(sBytes);
        sBytes.clear();
        
        _format = value;
        _attributes = _format.attributes;
        _numAttributes = _attributes.length;
        _vertexSize = _format.vertexSizeInBytes;
        _posOffset = (_format.hasAttribute("position")) ? _format.getOffsetInBytes("position"):0;
        _colOffset = (_format.hasAttribute("color")) ? _format.getOffsetInBytes("color"):0;
        return value;
    }
    
    /** The format string that describes the attributes of each vertex. */
    private function get_formatString():String
    {
        return _format.formatString;
    }
    
    /** The size (in bytes) of each vertex. */
    private function get_vertexSizeInBytes():Int
    {
        return _vertexSize;
    }
    
    /** The size (in 32 bit units) of each vertex. */
    private function get_vertexSizeIn32Bits():Int
    {
        return untyped _vertexSize / 4;
    }
    
    /** The size (in bytes) of the raw vertex data. */
    private function get_sizeInBytes():Int
    {
        return _numVertices * _vertexSize;
    }
    
    /** The size (in 32 bit units) of the raw vertex data. */
    private function get_sizeIn32Bits():Int
    {
        return untyped _numVertices * _vertexSize / 4;
    }
}

