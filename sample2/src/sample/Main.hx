package sample;

#if air
import flash.desktop.NativeApplication;
#end
import flash.display.Bitmap;
import flash.display.Loader;
import flash.display.Sprite;
import flash.display3D.Context3DProfile;
import flash.display3D.Context3DRenderMode;
import flash.events.Event;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.geom.Rectangle;
import flash.system.Capabilities;
import flash.system.System;
import flash.utils.ByteArray;
import haxe.Constraints.Function;
import haxe.Timer;

import starling.core.Starling;
import starling.events.Event;
import starling.textures.RenderTexture;
import starling.utils.AssetManager;
import starling.utils.RectangleUtil;
import starling.utils.ScaleMode;
import starling.utils.StringUtil;
import starling.utils.SystemUtil;

import utils.ProgressBar;

/**
 * ...
 * @author P.J.Shand
 */
class Main extends Sprite
{
	private var StageWidth:Int = 320;
	private var StageHeight:Int = 480;
	
	private var _starling:Starling;
	private var _background:Loader;
	private var _progressBar:ProgressBar;
	
	public function new()
	{
		super();
		// We develop the game in a *fixed* coordinate system of 320x480. The game might
		// then run on a device with a different resolution; for that case, we zoom the
		// viewPort to the optimal size for any display and load the optimal textures.
		
		var iOS:Bool = SystemUtil.platform == "IOS";
		var stageSize:Rectangle = new Rectangle(0, 0, StageWidth, StageHeight);
		var screenSize:Rectangle = new Rectangle(0, 0, stage.fullScreenWidth, stage.fullScreenHeight);
		var viewPort:Rectangle = RectangleUtil.fit(stageSize, screenSize, ScaleMode.SHOW_ALL, iOS);
		var scaleFactor:Int = viewPort.width < (480) ? 1:2;  // midway between 320 and 640  
		
		Starling.MultitouchEnabled = true;  // useful on mobile devices  
		
		_starling = new Starling(Game, stage, viewPort, null, Context3DRenderMode.AUTO, [Context3DProfile.BASELINE]);
		_starling.stage.stageWidth = StageWidth;  // <- same size on all devices!  
		_starling.stage.stageHeight = StageHeight;  // <- same size on all devices!  
		_starling.enableErrorChecking = Capabilities.isDebugger;
		_starling.simulateMultitouch = false;
		_starling.addEventListener(starling.events.Event.ROOT_CREATED, function():Void
		{
			loadAssets(scaleFactor, startGame);
		});
		
		_starling.start();
		initElements(scaleFactor);
		
		// When the game becomes inactive, we pause Starling; otherwise, the enter frame event
		// would report a very long 'passedTime' when the app is reactivated.
		
		if (!SystemUtil.isDesktop) 
		{
			#if air
			NativeApplication.nativeApplication.addEventListener(
					flash.events.Event.ACTIVATE, function(e:Dynamic):Void{_starling.start();
					});
			NativeApplication.nativeApplication.addEventListener(
					flash.events.Event.DEACTIVATE, function(e:Dynamic):Void{_starling.stop(true);
					});
			#end
		}
	}
	
	private function loadAssets(scaleFactor:Int, onComplete:Function):Void
	{
		// Our assets are loaded and managed by the 'AssetManager'. To use that class,
		// we first have to enqueue pointers to all assets we want it to load.
		
		var appDir:File = File.applicationDirectory;
		var assets:AssetManager = new AssetManager(scaleFactor);
		
		assets.verbose = Capabilities.isDebugger;
		assets.enqueue(appDir.resolvePath("audio"));
		assets.enqueue(appDir.resolvePath(StringUtil.format("fonts/{0}x", [scaleFactor])));
		assets.enqueue(appDir.resolvePath(StringUtil.format("textures/{0}x", [scaleFactor])));
		
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
		var game:Game = cast(_starling.root, Game);
		game.start(assets);
		Timer.delay(removeElements, 150);
	}
	
	private function initElements(scaleFactor:Int):Void
	{
		// Add background image. By using "loadBytes", we can avoid any flickering.
		
		var bgPath:String = StringUtil.format("textures/{0}x/background.jpg", [scaleFactor]);
		trace("bgPath = " + bgPath);
		var bgFile:File = File.applicationDirectory.resolvePath(bgPath);
		var bytes:ByteArray = new ByteArray();
		var stream:FileStream = new FileStream();
		stream.open(bgFile, FileMode.READ);
		stream.readBytes(bytes, 0, stream.bytesAvailable);
		stream.close();
		
		_background = new Loader();
		_background.loadBytes(bytes);
		_background.scaleX = 1.0 / scaleFactor;
		_background.scaleY = 1.0 / scaleFactor;
		_starling.nativeOverlay.addChild(_background);
		
		_background.contentLoaderInfo.addEventListener(flash.events.Event.COMPLETE,
				function(e:Dynamic):Void
				{
					cast(_background.content, Bitmap).smoothing = true;
				});
		
		// While the assets are loaded, we will display a progress bar.
		
		_progressBar = new ProgressBar(175, 20);
		_progressBar.x = (StageWidth - _progressBar.width) / 2;
		_progressBar.y = StageHeight * 0.7;
		_starling.nativeOverlay.addChild(_progressBar);
	}
	
	private function removeElements():Void
	{
		if (_background != null) 
		{
			_starling.nativeOverlay.removeChild(_background);
			_background = null;
		}
		
		if (_progressBar != null) 
		{
			_starling.nativeOverlay.removeChild(_progressBar);
			_progressBar = null;
		}
	}
}
