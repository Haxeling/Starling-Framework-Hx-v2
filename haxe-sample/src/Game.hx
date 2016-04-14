package;

import openfl.system.System;
import openfl.ui.Keyboard;

import scenes.AnimationScene;
import scenes.BenchmarkScene;
import scenes.BlendModeScene;
import scenes.CustomHitTestScene;
import scenes.FilterScene;
import scenes.MaskScene;
import scenes.MovieScene;
import scenes.RenderTextureScene;
import scenes.Sprite3DScene;
import scenes.TextScene;
import scenes.TextureScene;
import scenes.TouchScene;

import scenes.Scene;

import starling.core.Starling;
import starling.display.Button;
import starling.display.Image;
import starling.display.Sprite;
import starling.events.Event;
import starling.events.KeyboardEvent;
import starling.utils.AssetManager;
import starling.display.Quad;
import starling.rendering.BatchToken;
import starling.textures.Texture;

class Game extends Sprite
{
	public static var assets(get, never):AssetManager;

	// Embed the Ubuntu Font. Beware: the 'embedAsCFF'-part IS REQUIRED!!!
	@:meta(Embed(source="../../demo/assets/fonts/Ubuntu-R.ttf",embedAsCFF="false",fontFamily="Ubuntu"))

	private static var UbuntuRegular:Class<Dynamic>;
	
	private var _mainMenu:MainMenu;
	private var _currentScene:Scene;
	
	private static var sAssets:AssetManager;
	
	private var sceneMap:Map<String, Class<Dynamic>>;
	
	public function new()
	{
		super();
		// nothing to do here -- Startup will call "start" immediately.
		
		sceneMap = new Map<String, Class<Dynamic>>();
		sceneMap["scenes.TextureScene"] = TextureScene;
		sceneMap["scenes.TouchScene"] = TouchScene;
		sceneMap["scenes.TextScene"] = TextScene;
		sceneMap["scenes.AnimationScene"] = AnimationScene;
		sceneMap["scenes.CustomHitTestScene"] = CustomHitTestScene;
		sceneMap["scenes.MovieScene"] = MovieScene;
		sceneMap["scenes.FilterScene"] = FilterScene;
		sceneMap["scenes.BlendModeScene"] = BlendModeScene;
		sceneMap["scenes.RenderTextureScene"] = RenderTextureScene;
		sceneMap["scenes.BenchmarkScene"] = BenchmarkScene;
		sceneMap["scenes.MaskScene"] = MaskScene;
		sceneMap["scenes.Sprite3DScene"] = Sprite3DScene;
	}
	
	public function start(assets:AssetManager):Void
	{
		sAssets = assets;
		
		var bgTexture:Texture = assets.getTexture("background");
		var bgImage:Image = new Image(bgTexture);
		addChild(bgImage);
		
		showMainMenu();
		
		addEventListener(Event.TRIGGERED, onButtonTriggered);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKey);
	}
	
	private function showMainMenu():Void
	{
		// now would be a good time for a clean-up
		#if flash
		System.pauseForGCIfCollectionImminent(0);
		#end
		System.gc();
		
		if (_mainMenu == null) 
			_mainMenu = new MainMenu();
		
		addChild(_mainMenu);
	}
	
	private function onKey(event:KeyboardEvent):Void
	{
		if (event.keyCode == Keyboard.SPACE) 
			Starling.Current.showStats = !Starling.Current.showStats
		else if (event.keyCode == Keyboard.X) 
			Starling.Context.dispose();
	}
	
	private function onButtonTriggered(event:Event):Void
	{
		var button:Button = cast(event.target, Button);
		
		if (button.name == "backButton") 
			closeScene()
		else 
		showScene(button.name);
	}
	
	private function closeScene():Void
	{
		_currentScene.removeFromParent(true);
		_currentScene.dispose();
		_currentScene = null;
		
		showMainMenu();
	}
	
	private function showScene(name:String):Void
	{
		if (name == null) return;
		var sceneClass:Class<Dynamic> = sceneMap.get(name);
		_currentScene = Type.createInstance(sceneClass, []);
		_mainMenu.removeFromParent();
		addChild(_currentScene);
	}
	
	private static function get_assets():AssetManager
	{
		return sAssets;
	}
}
