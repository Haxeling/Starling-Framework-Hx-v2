package scenes;

import scenes.Scene;

import flash.display.BitmapData;
import flash.display.BitmapDataChannel;

import starling.core.Starling;
import starling.display.Button;
import starling.display.Image;
import starling.events.Event;
import starling.filters.BlurFilter;
import starling.filters.ColorMatrixFilter;
import starling.filters.DisplacementMapFilter;
import starling.filters.DropShadowFilter;
import starling.filters.FilterChain;
import starling.filters.FragmentFilter;
import starling.filters.GlowFilter;
import starling.text.TextField;
import starling.textures.Texture;

import utils.MenuButton;

class FilterScene extends Scene
{
	private var _button:Button;
	private var _image:Image;
	private var _infoText:TextField;
	private var _filterInfos:Array<Dynamic>;
	private var _displacementMap:Texture;
	
	public function new()
	{
		super();
		_button = new MenuButton("Switch Filter");
		_button.x = as3hx.Compat.parseInt(Constants.CenterX - _button.width / 2);
		_button.y = 15;
		_button.addEventListener(Event.TRIGGERED, onButtonTriggered);
		addChild(_button);
		
		_image = new Image(Game.assets.getTexture("starling_rocket"));
		_image.x = as3hx.Compat.parseInt(Constants.CenterX - _image.width / 2);
		_image.y = 170;
		addChild(_image);
		
		_infoText = new TextField(300, 32);
		_infoText.format.size = 19;
		_infoText.x = 10;
		_infoText.y = 330;
		addChild(_infoText);
		
		initFilters();
		onButtonTriggered();
	}
	
	override public function dispose():Void
	{
		_displacementMap.dispose();
		super.dispose();
	}
	
	private function onButtonTriggered():Void
	{
		var filterInfo:Array<Dynamic> = try cast(_filterInfos.shift(), Array</*AS3HX WARNING no type*/>) catch(e:Dynamic) null;
		_filterInfos.push(filterInfo);
		
		_infoText.text = filterInfo[0];
		_image.filter = filterInfo[1];
	}
	
	private function initFilters():Void
	{
		_filterInfos = [
				["Identity", new FragmentFilter()], 
				["Blur", new BlurFilter()], 
				["Drop Shadow", new DropShadowFilter()], 
				["Glow", new GlowFilter()]];
		
		_displacementMap = createDisplacementMap(_image.width, _image.height);
		
		var displacementFilter:DisplacementMapFilter = new DisplacementMapFilter(
		_displacementMap, null, BitmapDataChannel.RED, BitmapDataChannel.GREEN, 25, 25);
		_filterInfos.push(["Displacement Map", displacementFilter]);
		
		var invertFilter:ColorMatrixFilter = new ColorMatrixFilter();
		invertFilter.invert();
		_filterInfos.push(["Invert", invertFilter]);
		
		var grayscaleFilter:ColorMatrixFilter = new ColorMatrixFilter();
		grayscaleFilter.adjustSaturation(-1);
		_filterInfos.push(["Grayscale", grayscaleFilter]);
		
		var saturationFilter:ColorMatrixFilter = new ColorMatrixFilter();
		saturationFilter.adjustSaturation(1);
		_filterInfos.push(["Saturation", saturationFilter]);
		
		var contrastFilter:ColorMatrixFilter = new ColorMatrixFilter();
		contrastFilter.adjustContrast(0.75);
		_filterInfos.push(["Contrast", contrastFilter]);
		
		var brightnessFilter:ColorMatrixFilter = new ColorMatrixFilter();
		brightnessFilter.adjustBrightness(-0.25);
		_filterInfos.push(["Brightness", brightnessFilter]);
		
		var hueFilter:ColorMatrixFilter = new ColorMatrixFilter();
		hueFilter.adjustHue(1);
		_filterInfos.push(["Hue", hueFilter]);
		
		var chain:FilterChain = new FilterChain(hueFilter, new DropShadowFilter());
		_filterInfos.push(["Hue + Shadow", chain]);
	}
	
	private function createDisplacementMap(width:Float, height:Float):Texture
	{
		var scale:Float = Starling.ContentScaleFactor;
		var map:BitmapData = new BitmapData(width * scale, height * scale, false);
		map.perlinNoise(20 * scale, 20 * scale, 3, 5, false, true);
		var texture:Texture = Texture.fromBitmapData(map, false, false, scale);
		return texture;
	}
}
