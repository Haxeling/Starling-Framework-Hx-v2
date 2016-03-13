// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.text;

import flash.errors.ArgumentError;
import starling.text.ITextCompositor;
import starling.text.TextFormat;
import starling.text.TextOptions;

import flash.geom.Rectangle;
import flash.utils.Dictionary;

import starling.display.Image;
import starling.display.MeshBatch;
import starling.display.Sprite;
import starling.textures.Texture;
import starling.textures.TextureSmoothing;
import starling.utils.Align;
import starling.utils.StringUtil;

/** The BitmapFont class parses bitmap font files and arranges the glyphs
 *  in the form of a text.
 *
 *  The class parses the XML format as it is used in the 
 *  <a href="http://www.angelcode.com/products/bmfont/">AngelCode Bitmap Font Generator</a> or
 *  the <a href="http://glyphdesigner.71squared.com/">Glyph Designer</a>. 
 *  This is what the file format looks like:
 *
 *  <pre> 
 *  &lt;font&gt;
 *    &lt;info face="BranchingMouse" size="40" /&gt;
 *    &lt;common lineHeight="40" /&gt;
 *    &lt;pages&gt;  &lt;!-- currently, only one page is supported --&gt;
 *      &lt;page id="0" file="texture.png" /&gt;
 *    &lt;/pages&gt;
 *    &lt;chars&gt;
 *      &lt;char id="32" x="60" y="29" width="1" height="1" xoffset="0" yoffset="27" xadvance="8" /&gt;
 *      &lt;char id="33" x="155" y="144" width="9" height="21" xoffset="0" yoffset="6" xadvance="9" /&gt;
 *    &lt;/chars&gt;
 *    &lt;kernings&gt; &lt;!-- Kerning is optional --&gt;
 *      &lt;kerning first="83" second="83" amount="-4"/&gt;
 *    &lt;/kernings&gt;
 *  &lt;/font&gt;
 *  </pre>
 *  
 *  Pass an instance of this class to the method <code>registerBitmapFont</code> of the
 *  TextField class. Then, set the <code>fontName</code> property of the text field to the 
 *  <code>name</code> value of the bitmap font. This will make the text field use the bitmap
 *  font.  
 */

import starling.text.BitmapChar;

class BitmapFont implements ITextCompositor
{
    public var name(get, never):String;
    public var size(get, never):Float;
    public var lineHeight(get, set):Float;
    public var smoothing(get, set):String;
    public var baseline(get, set):Float;
    public var offsetX(get, set):Float;
    public var offsetY(get, set):Float;
    public var texture(get, never):Texture;

    /** Use this constant for the <code>fontSize</code> property of the TextField class to 
     *  render the bitmap font in exactly the size it was created. */
    public static var NATIVE_SIZE:Int = -1;
    
    /** The font name of the embedded minimal bitmap font. Use this e.g. for debug output. */
    public static var MINI:String = "mini";
    
    private static var CHAR_SPACE:Int = 32;
    private static var CHAR_TAB:Int = 9;
    private static var CHAR_NEWLINE:Int = 10;
    private static var CHAR_CARRIAGE_RETURN:Int = 13;
    
    private var _texture:Texture;
    private var _chars:Map<Int, BitmapChar>;
    private var _name:String;
    private var _size:Float;
    private var _lineHeight:Float;
    private var _baseline:Float;
    private var _offsetX:Float;
    private var _offsetY:Float;
    private var _helperImage:Image;
    
    // helper objects
    private static var sLines:Array<Dynamic> = [];
    private static var sDefaultOptions:TextOptions = new TextOptions();
    
    /** Creates a bitmap font by parsing an XML file and uses the specified texture. 
     *  If you don't pass any data, the "mini" font will be created. */
    public function new(texture:Texture = null, fontXml:Xml=null)
    {
        // if no texture is passed in, we create the minimal, embedded font
        if (texture == null && fontXml == null) 
        {
            texture = MiniBitmapFont.texture;
            fontXml = MiniBitmapFont.xml;
        }
        else if (texture != null && fontXml == null) 
        {
            throw new ArgumentError("fontXml cannot be null!");
        }
        
        _name = "unknown";
        _lineHeight = _size = _baseline = 14;
        _offsetX = _offsetY = 0.0;
        _texture = texture;
        _chars = new Map<Int, BitmapChar>();
        _helperImage = new Image(texture);
        
        parseFontXml(fontXml);
    }
    
    /** Disposes the texture of the bitmap font! */
    public function dispose():Void
    {
        if (_texture != null) 
            _texture.dispose();
    }
    
    private function parseFontXml(fontXml:Xml):Void
    {
        var scale:Float = texture.scale;
		var frame:Rectangle = texture.frame;
		var frameX:Float = frame != null ? frame.x : 0;
		var frameY:Float = frame != null ? frame.y : 0;
		
		for (font in fontXml.elementsNamed("font")) {
			if (font.nodeType == Xml.Element ) {
				for (info in font.elementsNamed("info")) {
					if (info.nodeType == Xml.Element ) {
						_name = info.get("face");
						_size = Std.parseFloat(info.get("size")) / scale;
						//mSize = Std.parseFloat(info.get("bold")) / scale;
						//mSize = Std.parseFloat(info.get("italic")) / scale;
						if (info.get("smooth") == "0") smoothing = TextureSmoothing.NONE;
						if (_size <= 0)
						{
							trace("[Starling] Warning: invalid font size in '" + _name + "' font.");
							_size = (_size == 0.0 ? 16.0 : _size * -1.0);
						}
					}
				}
				for (common in font.elementsNamed("common")) {
					if (common.nodeType == Xml.Element ) {
						_lineHeight = Std.parseFloat(common.get("lineHeight")) / scale;
						_baseline = Std.parseFloat(common.get("base")) / scale;
						//mBaseline = Std.parseFloat(common.get("scaleW")) / scale;
						//mBaseline = Std.parseFloat(common.get("scaleH")) / scale;
						//mBaseline = Std.parseFloat(common.get("pages")) / scale;
						//mBaseline = Std.parseFloat(common.get("packed")) / scale;
						
					}
				}
				for (chars in font.elementsNamed("chars")) {
					if (chars.nodeType == Xml.Element ) {
						for (char in chars.elementsNamed("char")) {
							if (char.nodeType == Xml.Element ) {
								
								var id:Int = Std.parseInt(char.get("id"));
								
								var xOffset:Float  = Std.parseFloat(char.get("xoffset"))  / scale;
								var yOffset:Float  = Std.parseFloat(char.get("yoffset"))  / scale;
								var xAdvance:Float = Std.parseFloat(char.get("xadvance")) / scale;
								
								var region:Rectangle = new Rectangle();
								region.x = Std.parseFloat(char.get("x")) / scale + frameX;
								region.y = Std.parseFloat(char.get("y")) / scale + frameY;
								region.width  = Std.parseFloat(char.get("width"))  / scale;
								region.height = Std.parseFloat(char.get("height")) / scale;
								
								var texture:Texture = Texture.fromTexture(_texture, region);
								var bitmapChar:BitmapChar = new BitmapChar(id, texture, xOffset, yOffset, xAdvance); 
								addChar(id, bitmapChar);
							}
						}
					}
				}
				for (kernings in font.elementsNamed("kernings")) {
					if (kernings.nodeType == Xml.Element ) {
						for (kerning in kernings.elementsNamed("kerning")) {
							if (kerning.nodeType == Xml.Element ) {
								
								var first:Int  = Std.parseInt(kerning.get("first"));
								var second:Int = Std.parseInt(kerning.get("second"));
								var amount:Float = Std.parseFloat(kerning.get("amount")) / scale;
								if (_chars.exists(second)) {
									getChar(second).addKerning(first, amount);
								}
							}
						}
					}
				}
			}
		}
    }
    
    /** Returns a single bitmap char with a certain character ID. */
    public function getChar(charID:Int):BitmapChar
    {
        return _chars.get(charID);
    }
    
    /** Adds a bitmap char with a certain character ID. */
    public function addChar(charID:Int, bitmapChar:BitmapChar):Void
    {
        _chars.set(charID, bitmapChar);
    }
    
    /** Returns a vector containing all the character IDs that are contained in this font. */
    public function getCharIDs(result:Array<Int> = null):Array<Int>
    {
        if (result == null) result = new Array<Int>();
		
		var keys = _chars.keys();
		for (k in keys) {
			var key:Int = k;
			result[result.length] = key;
		}

		return result;
    }
    
    /** Checks whether a provided string can be displayed with the font. */
    public function hasChars(text:String):Bool
    {
        if (text == null) return true;
        
        var charID:Int;
        var numChars:Int = text.length;
        
        for (i in 0...numChars){
            charID = text.charCodeAt(i);
            
            if (charID != CHAR_SPACE && charID != CHAR_TAB && charID != CHAR_NEWLINE &&
                charID != CHAR_CARRIAGE_RETURN && getChar(charID) == null) 
            {
                return false;
            }
        }
        
        return true;
    }
    
    /** Creates a sprite that contains a certain text, made up by one image per char. */
    public function createSprite(width:Float, height:Float, text:String,
            format:TextFormat, options:TextOptions = null):Sprite
    {
        var charLocations:Array<CharLocation> = arrangeChars(width, height, text, format, options);
        var numChars:Int = charLocations.length;
        var sprite:Sprite = new Sprite();
        
        for (i in 0...numChars){
            var charLocation:CharLocation = charLocations[i];
            var char:Image = charLocation.char.createImage();
            char.x = charLocation.x;
            char.y = charLocation.y;
            char.scale = charLocation.scale;
            char.color = format.color;
            sprite.addChild(char);
        }
        
        CharLocation.rechargePool();
        return sprite;
    }
    
    /** Draws text into a QuadBatch. */
    public function fillMeshBatch(meshBatch:MeshBatch, width:Float, height:Float, text:String,
            format:TextFormat, options:TextOptions = null):Void
    {
        var charLocations:Array<CharLocation> = arrangeChars(
                width, height, text, format, options);
        var numChars:Int = charLocations.length;
        _helperImage.color = format.color;
        
        for (i in 0...numChars){
            var charLocation:CharLocation = charLocations[i];
            _helperImage.texture = charLocation.char.texture;
            _helperImage.readjustSize();
            _helperImage.x = charLocation.x;
            _helperImage.y = charLocation.y;
            _helperImage.scale = charLocation.scale;
            meshBatch.addMesh(_helperImage);
        }
        
        CharLocation.rechargePool();
    }
    
    /** @inheritDoc */
    public function clearMeshBatch(meshBatch:MeshBatch):Void
    {
        meshBatch.clear();
    }
    
    /** Arranges the characters of a text inside a rectangle, adhering to the given settings. 
     *  Returns a Vector of CharLocations. */
    private function arrangeChars(width:Float, height:Float, text:String,
            format:TextFormat, options:TextOptions):Array<CharLocation>
    {
        if (text == null || text.length == 0)             return CharLocation.vectorFromPool();
        if (options == null)             options = sDefaultOptions;
        
        var kerning:Bool = format.kerning;
        var leading:Float = format.leading;
        var hAlign:String = format.horizontalAlign;
        var vAlign:String = format.verticalAlign;
        var fontSize:Float = format.size;
        var autoScale:Bool = options.autoScale;
        var wordWrap:Bool = options.wordWrap;
        
        var finished:Bool = false;
        var charLocation:CharLocation;
        var numChars:Int;
        var containerWidth:Float;
        var containerHeight:Float;
        var scale:Float;
        var i:Int;
        var j:Int;
        
        if (fontSize < 0)             fontSize *= -_size;
        
        while (!finished)
        {
            sLines.splice(0, sLines.length);
            scale = fontSize / _size;
            containerWidth = width / scale;
            containerHeight = height / scale;
            
            if (_lineHeight <= containerHeight) 
            {
                var lastWhiteSpace:Int = -1;
                var lastCharID:Int = -1;
                var currentX:Float = 0;
                var currentY:Float = 0;
                var currentLine:Array<CharLocation> = CharLocation.vectorFromPool();
                
                numChars = text.length;
				trace("Check for loop to while");
				var i:Int = 0;
				while (i < numChars) {
                //for (i in 0...numChars){
                    var lineFull:Bool = false;
                    var charID:Int = text.charCodeAt(i);
                    var char:BitmapChar = getChar(charID);
                    
                    if (charID == CHAR_NEWLINE || charID == CHAR_CARRIAGE_RETURN) 
                    {
                        lineFull = true;
                    }
                    else if (char == null) 
                    {
                        trace("[Starling] Missing character: " + charID);
                    }
                    else 
                    {
                        if (charID == CHAR_SPACE || charID == CHAR_TAB) 
                            lastWhiteSpace = i;
                        
                        if (kerning) 
                            currentX += char.getKerning(lastCharID);
                        
                        charLocation = CharLocation.instanceFromPool(char);
                        charLocation.x = currentX + char.xOffset;
                        charLocation.y = currentY + char.yOffset;
                        currentLine[currentLine.length] = charLocation;  // push  
                        
                        currentX += char.xAdvance;
                        lastCharID = charID;
                        
                        if (charLocation.x + char.width > containerWidth) 
                        {
                            if (wordWrap) 
                            {
                                // when autoscaling, we must not split a word in half -> restart
                                if (autoScale && lastWhiteSpace == -1) 
                                    break;
								
								// remove characters and add them again to next line  ;
                                var numCharsToRemove:Int = lastWhiteSpace == -(1) ? 1:i - lastWhiteSpace;
                                
                                for (j in 0...numCharsToRemove){  // faster than 'splice'  
                                    currentLine.pop();
                                }
                                
                                if (currentLine.length == 0) 
                                    break;
                                
                                i -= numCharsToRemove;
                            }
                            else 
                            {
                                if (autoScale) break;
                                currentLine.pop();
                                
                                // continue with next line, if there is one
                                while (i < numChars - 1 && text.charCodeAt(i) != CHAR_NEWLINE)
                                ++i;
                            }
                            
                            lineFull = true;
                        }
                    }
                    
                    if (i == numChars - 1) 
                    {
                        sLines[sLines.length] = currentLine;  // push  
                        finished = true;
                    }
                    else if (lineFull) 
                    {
                        sLines[sLines.length] = currentLine;  // push  
                        
                        if (lastWhiteSpace == i) 
                            currentLine.pop();
                        
                        if (currentY + leading + 2 * _lineHeight <= containerHeight) 
                        {
                            currentLine = CharLocation.vectorFromPool();
                            currentX = 0;
                            currentY += _lineHeight + leading;
                            lastWhiteSpace = -1;
                            lastCharID = -1;
                        }
                        else 
                        {
                            break;
                        }
                    }
					i++;
                }  // for each char  
            }  // if (_lineHeight <= containerHeight)  
            
            if (autoScale && !finished && fontSize > 3) 
                fontSize -= 1
            else 
            finished = true;
        }  // while (!finished)  
        
        var finalLocations:Array<CharLocation> = CharLocation.vectorFromPool();
        var numLines:Int = sLines.length;
        var bottom:Float = untyped currentY + _lineHeight;
        var yOffset:Int = 0;
        
        if (vAlign == Align.BOTTOM) yOffset = untyped containerHeight - bottom;
        else if (vAlign == Align.CENTER) yOffset = untyped (containerHeight - bottom) / 2;
        
        for (lineID in 0...numLines){
            var line:Array<CharLocation> = sLines[lineID];
            numChars = line.length;
            
            if (numChars == 0) {
				trace("check comment out doesn't break something");
				//++lineID;
				continue;
            };
            
            var xOffset:Int = 0;
            var lastLocation:CharLocation = line[line.length - 1];
            var right:Float = lastLocation.x - lastLocation.char.xOffset + lastLocation.char.xAdvance;
            
            if (hAlign == Align.RIGHT) xOffset = untyped containerWidth - right
            else if (hAlign == Align.CENTER) xOffset = untyped (containerWidth - right) / 2;
            
            for (c in 0...numChars){
                charLocation = line[c];
                charLocation.x = scale * (charLocation.x + xOffset + _offsetX);
                charLocation.y = scale * (charLocation.y + yOffset + _offsetY);
                charLocation.scale = scale;
                
                if (charLocation.char.width > 0 && charLocation.char.height > 0) 
                    finalLocations[finalLocations.length] = charLocation;
            }
        }
        
        return finalLocations;
    }
    
    /** The name of the font as it was parsed from the font file. */
    private function get_name():String
	{
		return _name;
    }
    
    /** The native size of the font. */
    private function get_size():Float
	{
		return _size;
    }
    
    /** The height of one line in points. */
    private function get_lineHeight():Float
	{
		return _lineHeight;
    }
	
    private function set_lineHeight(value:Float):Float
	{
		_lineHeight = value;
        return value;
    }
    
    /** The smoothing filter that is used for the texture. */
    private function get_smoothing():String
	{
		return _helperImage.textureSmoothing;
    }
	
    private function set_smoothing(value:String):String
	{
		_helperImage.textureSmoothing = value;
        return value;
    }
    
    /** The baseline of the font. This property does not affect text rendering;
     *  it's just an information that may be useful for exact text placement. */
    private function get_baseline():Float
	{
		return _baseline;
    }
	
    private function set_baseline(value:Float):Float
	{
		_baseline = value;
        return value;
    }
    
    /** An offset that moves any generated text along the x-axis (in points).
     *  Useful to make up for incorrect font data. @default 0. */
    private function get_offsetX():Float
	{
		return _offsetX;
    }
	
    private function set_offsetX(value:Float):Float
	{
		_offsetX = value;
        return value;
    }
    
    /** An offset that moves any generated text along the y-axis (in points).
     *  Useful to make up for incorrect font data. @default 0. */
    private function get_offsetY():Float
	{
		return _offsetY;
    }
	
    private function set_offsetY(value:Float):Float
	{
		_offsetY = value;
        return value;
    }
    
    /** The underlying texture that contains all the chars. */
    private function get_texture():Texture
	{
		return _texture;
    }
}



class CharLocation
{
    public var char:BitmapChar;
    public var scale:Float;
    public var x:Float;
    public var y:Float;
    
    public function new(char:BitmapChar)
    {
        reset(char);
    }
    
    private function reset(char:BitmapChar):CharLocation
    {
        this.char = char;
        return this;
    }
    
    // pooling
    
    private static var sInstancePool:Array<CharLocation> = [];
    private static var sVectorPool:Array<Dynamic> = [];
    
    private static var sInstanceLoan:Array<CharLocation> = [];
    private static var sVectorLoan:Array<Dynamic> = [];
    
    public static function instanceFromPool(char:BitmapChar):CharLocation
    {
        var instance:CharLocation = sInstancePool.length > (0) ? 
        sInstancePool.pop():new CharLocation(char);
        
        instance.reset(char);
        sInstanceLoan[sInstanceLoan.length] = instance;
        
        return instance;
    }
    
    public static function vectorFromPool():Array<CharLocation>
    {
        var vector:Array<CharLocation> = sVectorPool.length > (0) ? 
        sVectorPool.pop():[];
        
        vector.splice(0, vector.length);
        sVectorLoan[sVectorLoan.length] = vector;
        
        return vector;
    }
    
    public static function rechargePool():Void
    {
        var instance:CharLocation;
        var vector:Array<CharLocation>;
        
        while (sInstanceLoan.length > 0)
        {
            instance = sInstanceLoan.pop();
            instance.char = null;
            sInstancePool[sInstancePool.length] = instance;
        }
        
        while (sVectorLoan.length > 0)
        {
            vector = sVectorLoan.pop();
            vector.splice(0, vector.length);
            sVectorPool[sVectorPool.length] = vector;
        }
    }
}