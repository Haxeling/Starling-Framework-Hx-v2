// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.display;

import starling.display.Quad;

import flash.geom.Rectangle;

import starling.rendering.IndexData;
import starling.rendering.VertexData;
import starling.textures.Texture;

/** An Image is a quad with a texture mapped onto it.
 *
 *  <p>Typically, the Image class will act as an equivalent of Flash's Bitmap class. Instead
 *  of BitmapData, Starling uses textures to represent the pixels of an image. To display a
 *  texture, you have to map it onto a quad - and that's what the Image class is for.</p>
 *
 *  <p>While the base class <code>Quad</code> already supports textures, the <code>Image</code>
 *  class adds some additional functionality.</p>
 *
 *  <p>First of all, it provides a convenient constructor that will automatically synchronize
 *  the size of the image with the displayed texture.</p>
 *
 *  <p>Furthermore, it adds support for a "Scale9" grid. This splits up the image into
 *  nine regions, the corners of which will always maintain their original aspect ratio.
 *  The center region stretches in both directions to fill the remaining space; the side
 *  regions will stretch accordingly in either horizontal or vertical direction.</p>
 *
 *  <p>Finally, you can repeat a texture horizontally and vertically within the image's region,
 *  just like the tiles of a wallpaper. Use the <code>tileGrid</code> property to do that.</p>
 *
 *  @see starling.textures.Texture
 *  @see Quad
 */
class Image extends Quad
{
    public var scale9Grid(get, set) : Rectangle;
    public var tileGrid(get, set) : Rectangle;

    private var _scale9Grid : Rectangle;
    private var _tileGrid : Rectangle;
    
    // helper objects
    private static var s9Grid : Rectangle = new Rectangle();
    private static var sBounds : Rectangle = new Rectangle();
    private static var sHorizSizes : Array<Float> = new Array<Float>();
    private static var sVertSizes : Array<Float> = new Array<Float>();
    
    /** Creates an image with a texture mapped onto it. */
    public function new(texture : Texture)
    {
        super(100, 100);
        this.texture = texture;
        readjustSize();
    }
    
    /** The current scaling grid that is in effect. If set to null, the image is scaled just
     *  like any other display object; assigning a rectangle will divide the image into a grid
     *  of nine regions, based on the center rectangle. The four corners of this grid will
     *  always maintain their original aspect ratio; the other regions will stretch accordingly
     *  (horizontally, vertically, or both) to fill the complete area.
     *
     *  <p>Notes:</p>
     *
     *  <ul>
     *  <li>Assigning a Scale9 rectangle will change the number of vertices to sixteen,
     *  and all vertices will be colored like vertex 0 (the top left vertex).</li>
     *  <li>An image can have either a <code>scale9Grid</code> or a <code>tileGrid</code>, but
     *  not both. Assigning one will delete the other.</li>
     *  <li>Changes will only be applied on assignment. To force an update, simply call
     *  <code>image.scale9Grid = image.scale9Grid</code>.</li>
     *  <li>Furthermore, with a Scale9 rectangle assigned, any change of the texture will
     *  implicitly call <code>readjustSize</code>.</li>
     *  </ul>
     *
     *  @default null
     */
    private function get_scale9Grid() : Rectangle{return _scale9Grid;
    }
    private function set_scale9Grid(value : Rectangle) : Rectangle
    {
        if (value != null) 
        {
            if (_scale9Grid == null)                 _scale9Grid = value.clone()
            else _scale9Grid.copyFrom(value);
            
            _tileGrid = null;
        }
        else _scale9Grid = null;
        
        setupVertices();
        return value;
    }
    
    /** The current tiling grid that is in effect. If set to null, the image is scaled just
     *  like any other display object; assigning a rectangle will divide the image into a grid
     *  displaying the current texture in each and every cell. The assigned rectangle points
     *  to the bounds of one cell; all other elements will be calculated accordingly. A zero
     *  or negative value for the rectangle's width or height will be replaced with the actual
     *  texture size. Thus, you can make a 2x2 grid simply like this:
     *
     *  <listing>
     *  var image:Image = new Image(texture);
     *  image.tileGrid = new Rectangle();
     *  image.scale = 2;</listing>
     *
     *  <p>Notes:</p>
     *
     *  <ul>
     *  <li>Assigning a tile rectangle will change the number of vertices to whatever is
     *  required by the grid. New vertices will be colored just like vertex 0 (the top left
     *  vertex).</li>
     *  <li>An image can have either a <code>scale9Grid</code> or a <code>tileGrid</code>, but
     *  not both. Assigning one will delete the other.</li>
     *  <li>Changes will only be applied on assignment. To force an update, simply call
     *  <code>image.tileGrid = image.tileGrid</code>.</li>
     *  </ul>
     *
     *  @default null
     */
    private function get_tileGrid() : Rectangle{return _tileGrid;
    }
    private function set_tileGrid(value : Rectangle) : Rectangle
    {
        if (value != null) 
        {
            if (_tileGrid == null)                 _tileGrid = value.clone()
            else _tileGrid.copyFrom(value);
            
            _scale9Grid = null;
        }
        else _tileGrid = null;
        
        setupVertices();
        return value;
    }
    
    /** @private */
    override private function setupVertices() : Void
    {
        if (texture != null && _scale9Grid != null)             setupScale9Grid()
        else if (texture != null && _tileGrid != null)             setupTileGrid()
        else super.setupVertices();
    }
    
    /** @private */
    override private function set_scaleX(value : Float) : Float
    {
        super.scaleX = value;
        if (texture != null && (_scale9Grid != null || _tileGrid != null))             setupVertices();
        return value;
    }
    
    /** @private */
    override private function set_scaleY(value : Float) : Float
    {
        super.scaleY = value;
        if (texture != null && (_scale9Grid != null || _tileGrid != null))             setupVertices();
        return value;
    }
    
    /** @private */
    override private function set_texture(value : Texture) : Texture
    {
        if (value != texture) 
        {
            super.texture = value;
            if (_scale9Grid != null && value != null)                 readjustSize();
        }
        return value;
    }
    
    // vertex setup
    
    private function setupScale9Grid() : Void
    {
        s9Grid.copyFrom(_scale9Grid);
        
        var texture : Texture = this.texture;
        var frame : Rectangle = texture.frame;
        var absScaleX : Float = scaleX > (0) ? scaleX : -scaleX;
        var absScaleY : Float = scaleY > (0) ? scaleY : -scaleY;
        var invScaleX : Float = 1.0 / absScaleX;
        var invScaleY : Float = 1.0 / absScaleY;
        var vertexData : VertexData = this.vertexData;
        var indexData : IndexData = this.indexData;
        var prevNumVertices : Int = vertexData.numVertices;
        var startX : Float = 0.0;
        var startY : Float = 0.0;
        var col : Float;
        var row : Float;
        var correction : Float;
        
        indexData.numIndices = 0;
        vertexData.numVertices = 16;
        
        // calculate 3x3 grid according to texture and scale9 properties,
        // taking special care about the texture frame (headache included)
        
        if (frame != null) 
        {
            s9Grid.x += frame.x;
            s9Grid.y += frame.y;
            startX = invScaleX * -frame.x;
            startY = invScaleY * -frame.y;
        }
        
        sHorizSizes[0] = s9Grid.x * invScaleX;
        sHorizSizes[1] = texture.frameWidth - (texture.frameWidth - s9Grid.width) * invScaleX;
        sHorizSizes[2] = (texture.width - s9Grid.right) * invScaleX;
        
        sVertSizes[0] = s9Grid.y * invScaleY;
        sVertSizes[1] = texture.frameHeight - (texture.frameHeight - s9Grid.height) * invScaleY;
        sVertSizes[2] = (texture.height - s9Grid.bottom) * invScaleY;
        
        // if the total width / height becomes smaller than the outer columns / rows,
        // we hide the center column / row and scale the rest normally.
        
        if (sHorizSizes[1] < 0) 
        {
            correction = texture.frameWidth / (texture.frameWidth - s9Grid.width) * absScaleX;
            startX *= correction;
            sHorizSizes[0] *= correction;
            sHorizSizes[1] = 0;
            sHorizSizes[2] *= correction;
        }
        
        if (sVertSizes[1] < 0) 
        {
            correction = texture.frameHeight / (texture.frameHeight - s9Grid.height) * absScaleY;
            startY *= correction;
            sVertSizes[0] *= correction;
            sVertSizes[1] = 0;
            sVertSizes[2] *= correction;
        }  // set the vertex positions according to the values calculated above  
        
        
        
        
        var posX : Float;
        var posY : Float = startY;
        var vertexID : Int = 0;
        
        for (row in 0...4){
            posX = startX;
            
            for (col in 0...4){
                vertexData.setPoint(vertexID++, "position", posX, posY);
                if (col != 3)                     posX += sHorizSizes[col];
            }
            
            if (row != 3)                 posY += sVertSizes[row];
        }  // now set the texture coordinates  
        
        
        
        
        var paddingLeft : Float = (frame != null) ? -frame.x : 0;
        var paddingTop : Float = (frame != null) ? -frame.y : 0;
        
        sHorizSizes[0] = (_scale9Grid.x - paddingLeft) / texture.width;
        sHorizSizes[1] = _scale9Grid.width / texture.width;
        sHorizSizes[2] = 1.0 - sHorizSizes[0] - sHorizSizes[1];
        
        sVertSizes[0] = (_scale9Grid.y - paddingTop) / texture.height;
        sVertSizes[1] = _scale9Grid.height / texture.height;
        sVertSizes[2] = 1.0 - sVertSizes[0] - sVertSizes[1];
        
        posX = posY = vertexID = 0;
        
        for (row in 0...4){
            posX = 0.0;
            
            for (col in 0...4){
                texture.setTexCoords(vertexData, vertexID++, "texCoords", posX, posY);
                if (col != 3)                     posX += sHorizSizes[col];
            }
            
            if (row != 3)                 posY += sVertSizes[row];
        }  // update indices  
        
        
        
        
        indexData.addQuad(0, 1, 4, 5);
        indexData.addQuad(1, 2, 5, 6);
        indexData.addQuad(2, 3, 6, 7);
        indexData.addQuad(4, 5, 8, 9);
        indexData.addQuad(5, 6, 9, 10);
        indexData.addQuad(6, 7, 10, 11);
        indexData.addQuad(8, 9, 12, 13);
        indexData.addQuad(9, 10, 13, 14);
        indexData.addQuad(10, 11, 14, 15);
        
        // if we just switched from a normal to a scale9 image, all vertices are colorized
        // just like the first one; we also trim the data instances to optimize memory usage.
        
        if (prevNumVertices != vertexData.numVertices) 
        {
            var color : Int = (prevNumVertices != 0) ? vertexData.getColor(0) : 0xffffff;
            var alpha : Float = (prevNumVertices != 0) ? vertexData.getAlpha(0) : 1.0;
            
            vertexData.colorize("color", color, alpha);
            vertexData.trim();
            indexData.trim();
        }
        
        setRequiresRedraw();
    }
    
    private function setupTileGrid() : Void
    {
        // calculate the grid of vertices simulating a repeating / tiled texture.
        // again, texture frames make this somewhat more complicated than one would think.
        
        var texture : Texture = this.texture;
        var frame : Rectangle = texture.frame;
        var vertexData : VertexData = this.vertexData;
        var indexData : IndexData = this.indexData;
        var bounds : Rectangle = getBounds(this, sBounds);
        var prevNumVertices : Int = vertexData.numVertices;
        var color : Int = (prevNumVertices != 0) ? vertexData.getColor(0) : 0xffffff;
        var alpha : Float = (prevNumVertices != 0) ? vertexData.getAlpha(0) : 1.0;
        var invScaleX : Float = scaleX > (0) ? 1.0 / scaleX : -1.0 / scaleX;
        var invScaleY : Float = scaleY > (0) ? 1.0 / scaleY : -1.0 / scaleY;
        var frameWidth : Float = _tileGrid.width > (0) ? _tileGrid.width : texture.frameWidth;
        var frameHeight : Float = _tileGrid.height > (0) ? _tileGrid.height : texture.frameHeight;
        
        frameWidth *= invScaleX;
        frameHeight *= invScaleY;
        
        var tileX : Float = (frame != null) ? -frame.x * (frameWidth / frame.width) : 0;
        var tileY : Float = (frame != null) ? -frame.y * (frameHeight / frame.height) : 0;
        var tileWidth : Float = texture.width * (frameWidth / texture.frameWidth);
        var tileHeight : Float = texture.height * (frameHeight / texture.frameHeight);
        var modX : Float = (_tileGrid.x * invScaleX) % frameWidth;
        var modY : Float = (_tileGrid.y * invScaleY) % frameHeight;
        
        if (modX < 0)             modX += frameWidth;
        if (modY < 0)             modY += frameHeight;
        
        var startX : Float = modX + tileX;
        var startY : Float = modY + tileY;
        
        if (startX > (frameWidth - tileWidth))             startX -= frameWidth;
        if (startY > (frameHeight - tileHeight))             startY -= frameHeight;
        
        var posLeft : Float;
        var posRight : Float;
        var posTop : Float;
        var posBottom : Float;
        var texLeft : Float;
        var texRight : Float;
        var texTop : Float;
        var texBottom : Float;
        var posAttrName : String = "position";
        var texAttrName : String = "texCoords";
        var currentX : Float;
        var currentY : Float = startY;
        var vertexID : Int = 0;
        
        indexData.numIndices = 0;
        
        while (currentY < bounds.height)
        {
            currentX = startX;
            
            while (currentX < bounds.width)
            {
                indexData.addQuad(vertexID, vertexID + 1, vertexID + 2, vertexID + 3);
                
                posLeft = currentX < (0) ? 0 : currentX;
                posTop = currentY < (0) ? 0 : currentY;
                posRight = currentX + tileWidth > (bounds.width) ? bounds.width : currentX + tileWidth;
                posBottom = currentY + tileHeight > (bounds.height) ? bounds.height : currentY + tileHeight;
                
                vertexData.setPoint(vertexID, posAttrName, posLeft, posTop);
                vertexData.setPoint(vertexID + 1, posAttrName, posRight, posTop);
                vertexData.setPoint(vertexID + 2, posAttrName, posLeft, posBottom);
                vertexData.setPoint(vertexID + 3, posAttrName, posRight, posBottom);
                
                texLeft = (posLeft - currentX) / tileWidth;
                texTop = (posTop - currentY) / tileHeight;
                texRight = (posRight - currentX) / tileWidth;
                texBottom = (posBottom - currentY) / tileHeight;
                
                texture.setTexCoords(vertexData, vertexID, texAttrName, texLeft, texTop);
                texture.setTexCoords(vertexData, vertexID + 1, texAttrName, texRight, texTop);
                texture.setTexCoords(vertexData, vertexID + 2, texAttrName, texLeft, texBottom);
                texture.setTexCoords(vertexData, vertexID + 3, texAttrName, texRight, texBottom);
                
                currentX += frameWidth;
                vertexID += 4;
            }
            
            currentY += frameHeight;
        }  // trim to actual size  
        
        
        
        vertexData.numVertices = vertexID;
        
        for (i in prevNumVertices...vertexID){
            vertexData.setColor(i, "color", color);
            vertexData.setAlpha(i, "color", alpha);
        }
        
        setRequiresRedraw();
    }
}

