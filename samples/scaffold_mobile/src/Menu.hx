
import starling.display.Button;
import starling.display.Sprite;
import starling.events.Event;
import starling.text.BitmapFont;
import starling.text.TextField;
import starling.text.TextFormat;

/** The Menu shows the logo of the game and a start button that will, once triggered, 
 *  start the actual game. In a real game, it will probably contain several buttons and
 *  link to several screens (e.g. a settings screen or the credits). If your menu contains
 *  a lot of logic, you could use the "Feathers" library to make your life easier. */
class Menu extends Sprite
{
	public static var START_GAME:String = "startGame";
	
	public function new()
	{
		super();
		init();
	}
	
	private function init():Void
	{
		var textField:TextField = new TextField(250, 50, "Game Scaffold");
		textField.format = new TextFormat("Desyrel", BitmapFont.NATIVE_SIZE, 0xffffff);
		textField.x = (Constants.STAGE_WIDTH - textField.width) / 2;
		textField.y = 50;
		addChild(textField);
		
		var button:Button = new Button(Root.assets.getTexture("button_normal"), "Start");
		button.textFormat.font = "Ubuntu";
		button.textFormat.size = 16;
		button.x = (Constants.STAGE_WIDTH - button.width) / 2;
		button.y = Constants.STAGE_HEIGHT * 0.75;
		button.addEventListener(Event.TRIGGERED, onButtonTriggered);
		addChild(button);
	}
	
	private function onButtonTriggered():Void
	{
		dispatchEventWith(START_GAME, true, "classic");
	}
}
