import Game;

import flash.display.Bitmap;
import flash.display.Sprite;
import flash.system.Capabilities;
import flash.system.System;
import flash.utils.SetTimeout;

import starling.core.Starling;
import starling.events.Event;
import starling.utils.AssetManager;

import utils.ProgressBar;

// If you set this class as your 'default application', it will run without a preloader.
// To use a preloader, see 'Demo_Web_Preloader.as'.

// This project requires the sources of the "demo" project. Add them either by
// referencing the "demo/src" directory as a "source path", or by copying the files.
// The "media" folder of this project has to be added to its "source paths" as well,
// to make sure the icon and startup images are added to the compiled mobile app.

@:meta(SWF(width="320",height="480",frameRate="60",backgroundColor="#222222"))

class DemoWeb extends Sprite
{
	private var _starling:Starling;
	private var _background:Bitmap;
	private var _progressBar:ProgressBar;
	
	public function new()
	{
		super();
		if (stage)			 start()
		else addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
	}
	
	private function onAddedToStage(event:Dynamic):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		start();
	}
	
	private function start():Void
	{
		// We develop the game in a *fixed* coordinate system of 320x480. The game might
		// then run on a device with a different resolution; for that case, we zoom the
		// viewPort to the optimal size for any display and load the optimal textures.
		
		Starling.multitouchEnabled = true;  // for Multitouch Scene  
		
		_starling = new Starling(Game, stage, null, null, "auto", "auto");
		_starling.simulateMultitouch = true;
		_starling.enableErrorChecking = Capabilities.isDebugger;
		_starling.addEventListener(Event.ROOT_CREATED, function():Void
				{
					loadAssets(startGame);
				});
		
		_starling.start();
		initElements();
	}
	
	private function loadAssets(onComplete:Function):Void
	{
		// Our assets are loaded and managed by the 'AssetManager'. To use that class,
		// we first have to enqueue pointers to all assets we want it to load.
		
		var assets:AssetManager = new AssetManager();
		
		assets.verbose = Capabilities.isDebugger;
		assets.enqueue(EmbeddedAssets);
		
		// Now, while the AssetManager now contains pointers to all the assets, it actually
		// has not loaded them yet. This happens in the "loadQueue" method; and since this
		// will take a while, we'll update the progress bar accordingly.
		
		assets.loadQueue(function(ratio:Float):Void
				{
					_progressBar.ratio = ratio;
					if (ratio == 1) 
					{
						// now would be a good time for a clean-up
						System.pauseForGCIfCollectionImminent(0);
						System.gc();
						
						onComplete(assets);
					}
				});
	}
	
	private function startGame(assets:AssetManager):Void
	{
		var game:Game = try cast(_starling.root, Game) catch(e:Dynamic) null;
		game.start(assets);
		setTimeout(removeElements, 150);
	}
	
	private function initElements():Void
	{
		// Add background image.
		
		_background = new embeddedassets.Background();
		_background.smoothing = true;
		addChild(_background);
		
		// While the assets are loaded, we will display a progress bar.
		
		_progressBar = new ProgressBar(175, 20);
		_progressBar.x = (_background.width - _progressBar.width) / 2;
		_progressBar.y = _background.height * 0.7;
		addChild(_progressBar);
	}
	
	private function removeElements():Void
	{
		if (_background != null) 
		{
			removeChild(_background);
			_background = null;
		}
		
		if (_progressBar != null) 
		{
			removeChild(_progressBar);
			_progressBar = null;
		}
	}
}
