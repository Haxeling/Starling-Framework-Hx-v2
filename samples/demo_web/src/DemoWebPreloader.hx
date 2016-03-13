import StartupClass;
import flash.errors.Error;

import flash.display.DisplayObject;
import flash.display.MovieClip;
import flash.display.Shape;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.events.Event;


import starling.utils.Color;

// To show a Preloader while the SWF is being transferred from the server,
// set this class as your 'default application' and add the following
// compiler argument: '-frame StartupFrame Demo_Web'

@:meta(SWF(width="320",height="480",frameRate="60",backgroundColor="#222222"))

class DemoWebPreloader extends MovieClip
{
    private var STARTUP_CLASS:String = "Demo_Web";
    
    private var _progressIndicator:Shape;
    private var _frameCount:Int = 0;
    
    public function new()
    {
        super();
        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        stop();
    }
    
    private function onAddedToStage(event:Event):Void
    {
        stage.scaleMode = StageScaleMode.SHOW_ALL;
        stage.align = StageAlign.TOP_LEFT;
        
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
    }
    
    private function onEnterFrame(event:Event):Void
    {
        var bytesLoaded:Int = root.loaderInfo.bytesLoaded;
        var bytesTotal:Int = root.loaderInfo.bytesTotal;
        
        if (bytesLoaded >= bytesTotal) 
        {
            dispose();
            run();
        }
        else 
        {
            if (_progressIndicator == null) 
            {
                _progressIndicator = createProgressIndicator();
                _progressIndicator.x = stage.stageWidth / 2;
                _progressIndicator.y = stage.stageHeight / 2;
                addChild(_progressIndicator);
            }
            else 
            {
                if (_frameCount++ % 5 == 0) 
                    _progressIndicator.rotation -= 45;
            }
        }
    }
    
    private function createProgressIndicator(radius:Float = 12, elements:Int = 8):Shape
    {
        var shape:Shape = new Shape();
        var angleDelta:Float = Math.PI * 2 / elements;
        var x:Float;
        var y:Float;
        var innerRadius:Float = radius / 4;
        var color:Int;
        
        for (i in 0...elements){
            x = Math.cos(angleDelta * i) * radius;
            y = Math.sin(angleDelta * i) * radius;
            color = (i + 1) / elements * 255;
            
            shape.graphics.beginFill(Color.rgb(color, color, color));
            shape.graphics.drawCircle(x, y, innerRadius);
            shape.graphics.endFill();
        }
        
        return shape;
    }
    
    private function dispose():Void
    {
        removeEventListener(Event.ENTER_FRAME, onEnterFrame);
        
        if (_progressIndicator != null) 
            removeChild(_progressIndicator);
        
        _progressIndicator = null;
    }
    
    private function run():Void
    {
        nextFrame();
        
        var startupClass:Class<Dynamic> = Type.getClass(Type.resolveClass(STARTUP_CLASS));
        if (startupClass == null) 
            throw new Error("Invalid Startup class in Preloader: " + STARTUP_CLASS);
        
        var startupObject:DisplayObject = try cast(Type.createInstance(startupClass, []), DisplayObject) catch(e:Dynamic) null;
        if (startupObject == null) 
            throw new Error("Startup class needs to inherit from Sprite or MovieClip.");
        
        addChildAt(startupObject, 0);
    }
}
