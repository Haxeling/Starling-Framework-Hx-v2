package utils;


import flash.geom.Rectangle;
import starling.textures.Texture;
import starling.utils.AssetManager;

import starling.display.Button;

/** A simple button that uses "scale9grid" with a single texture. */
class MenuButton extends Button
{
	public function new(text:String, width:Float = 128, height:Float = 32)
	{
		var assets:AssetManager = Game.assets;
		var upState:Texture = assets.getTexture("button");
		super(upState, text);
		
		this.scale9Grid = new Rectangle(12.5, 12.5, 20, 20);
		this.width = width;
		this.height = height;
	}
}

