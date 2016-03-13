package scenes;


import starling.display.Image;
import starling.text.TextField;
import starling.utils.Deg2rad;

import utils.TouchSheet;

class TouchScene extends Scene
{
    public function new()
    {
        super();
        var description:String = "[use Ctrl/Cmd & Shift to simulate multi-touch]";
        
        var infoText:TextField = new TextField(300, 25, description);
        infoText.x = infoText.y = 10;
        addChild(infoText);
        
        // to find out how to react to touch events have a look at the TouchSheet class!
        // It's part of the demo.
        
        var sheet:TouchSheet = new TouchSheet(new Image(Game.assets.getTexture("starling_sheet")));
        sheet.x = Constants.CenterX;
        sheet.y = Constants.CenterY;
        sheet.rotation = deg2rad(10);
        addChild(sheet);
    }
}
