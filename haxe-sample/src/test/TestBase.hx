package test;

import starling.display.Quad;
import starling.display.Sprite;

/**
 * ...
 * @author ...
 */
class TestBase extends Sprite
{

	public function new() 
	{
		super();
		var quad:Quad = new Quad(256, 256, 0xFFFF0000);
		addChild(quad);
	}
	
}