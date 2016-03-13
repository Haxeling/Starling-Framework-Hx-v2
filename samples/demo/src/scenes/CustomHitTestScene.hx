package scenes;

import scenes.Scene;

import starling.text.TextField;
import starling.utils.Align;

import utils.RoundButton;

class CustomHitTestScene extends Scene
{
	public function new()
	{
		super();
		var description:String = 
		"Pushing the bird only works when the touch occurs within a circle." +
		"This can be accomplished by overriding the method 'hitTest'.";
		
		var infoText:TextField = new TextField(300, 100, description);
		infoText.x = infoText.y = 10;
		infoText.format.verticalAlign = Align.TOP;
		infoText.format.horizontalAlign = Align.CENTER;
		addChild(infoText);
		
		// 'RoundButton' is a helper class of the Demo, not a part of Starling!
		// Have a look at its code to understand this sample.
		
		var button:RoundButton = new RoundButton(Game.assets.getTexture("starling_round"));
		button.x = Constants.CenterX - as3hx.Compat.parseInt(button.width / 2);
		button.y = 150;
		addChild(button);
	}
}
