package test;

import openfl.display3D.Context3DRenderMode;
import openfl.geom.Rectangle;

import openfl.events.Event;
import openfl.display.Sprite;
import openfl.display3D.Context3DProfile;
import openfl.Lib;

import starling.core.Starling;
import starling.events.Event;

/**
 * ...
 * @author P.J.Shand
 */

class TestMain extends Sprite 
{
	private var StageWidth:Int = Constants.GameWidth;
	private var StageHeight:Int = Constants.GameHeight;
	
	private var mStarling:Starling;
	
	public function new() 
	{
		super();
		
		if (stage != null) start();
		else addEventListener(openfl.events.Event.ADDED_TO_STAGE, onAddedToStage);
	}

	private function onAddedToStage(event:Dynamic):Void
	{
		removeEventListener(openfl.events.Event.ADDED_TO_STAGE, onAddedToStage);
		start();
	}

	private function start():Void
	{
		// We develop the game in a *fixed* coordinate system of 320x480. The game might
		// then run on a device with a different resolution; for that case, we zoom the
		// viewPort to the optimal size for any display and load the optimal textures.
		
		Starling.MultitouchEnabled = true; // for Multitouch Scene
		Starling.MultitouchEnabled = true; // recommended everywhere when using AssetManager
		//RenderTexture.optimizePersistentBuffers = true; // should be safe on Desktop
		
		var viewPort:Rectangle = new Rectangle(0, 0, StageWidth * 2, StageHeight * 2);
		var scaleFactor:Int = viewPort.width < (480) ? 1:2;  // midway between 320 and 640  
		
		mStarling = new Starling(TestBase, stage, viewPort, null,Context3DRenderMode.AUTO, [Context3DProfile.BASELINE]);
		mStarling.stage.stageWidth = StageWidth;  // <- same size on all devices!  
		mStarling.stage.stageHeight = StageHeight;  // <- same size on all devices!  
		mStarling.antiAliasing = 2;
		mStarling.simulateMultitouch = false;
		//mStarling.enableErrorChecking = Capabilities.isDebugger;
		mStarling.addEventListener(starling.events.Event.ROOT_CREATED, function():Void
		{
			//loadAssets(scaleFactor, startGame);
			//switchRendering();
		});
		
		mStarling.start();
	}
}