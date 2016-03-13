import MainMenu;
import SceneClass;

import flash.system.System;
import flash.ui.Keyboard;


import scenes.Scene;

import starling.core.Starling;
import starling.display.Button;
import starling.display.Image;
import starling.display.Sprite;
import starling.events.Event;
import starling.events.KeyboardEvent;
import starling.utils.AssetManager;

class Game extends Sprite
{
    public static var assets(get, never):AssetManager;

    // Embed the Ubuntu Font. Beware: the 'embedAsCFF'-part IS REQUIRED!!!
    @:meta(Embed(source="../../demo/assets/fonts/Ubuntu-R.ttf",embedAsCFF="false",fontFamily="Ubuntu"))

    private static var UbuntuRegular:Class<Dynamic>;
    
    private var _mainMenu:MainMenu;
    private var _currentScene:Scene;
    
    private static var sAssets:AssetManager;
    
    public function new()
    {
        super();
        // nothing to do here -- Startup will call "start" immediately.
        
    }
    
    public function start(assets:AssetManager):Void
    {
        sAssets = assets;
        addChild(new Image(assets.getTexture("background")));
        showMainMenu();
        
        addEventListener(Event.TRIGGERED, onButtonTriggered);
        stage.addEventListener(KeyboardEvent.KEY_DOWN, onKey);
    }
    
    private function showMainMenu():Void
    {
        // now would be a good time for a clean-up
        System.pauseForGCIfCollectionImminent(0);
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
        var button:Button = try cast(event.target, Button) catch(e:Dynamic) null;
        
        if (button.name == "backButton") 
            closeScene()
        else 
        showScene(button.name);
    }
    
    private function closeScene():Void
    {
        _currentScene.removeFromParent(true);
        _currentScene = null;
        showMainMenu();
    }
    
    private function showScene(name:String):Void
    {
        if (_currentScene != null)             return;
        
        var sceneClass:Class<Dynamic> = Type.getClass(Type.resolveClass(name));
        _currentScene = try cast(Type.createInstance(sceneClass, []), Scene) catch(e:Dynamic) null;
        _mainMenu.removeFromParent();
        addChild(_currentScene);
    }
    
    private static function get_assets():AssetManager
	{
		return sAssets;
    }
}
