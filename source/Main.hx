package;

import openfl.events.UncaughtErrorEvent;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.Lib;
import flixel.FlxGame;
import flixel.FlxState;

using StringTools;

class Main extends Sprite
{
	// Base game resolution
	static final GAME_WIDTH:Int  = 1280;
	static final GAME_HEIGHT:Int = 720;

	// Target framerates per platform
	#if web
	static final FRAMERATE:Int = 60;
	#elseif mobile
	static final FRAMERATE:Int = 60;
	#else
	static final FRAMERATE:Int = 144;
	#end

	/** The first FlxState loaded on startup. */
	var initialState:Class<FlxState> = TitleState;

	/** Zoom level; -1 = auto-fit to window. */
	var zoom:Float = -1;

	var skipSplash:Bool    = true;
	var startFullscreen:Bool = false;

	// Runtime dimensions (may differ from base res after zoom calc)
	var gameWidth:Int  = GAME_WIDTH;
	var gameHeight:Int = GAME_HEIGHT;

	// ---------------------------------------------------------------

	public static var fpsCounter:FPS;

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		// Hook global uncaught error handler before anything else
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(
			UncaughtErrorEvent.UNCAUGHT_ERROR,
			onUncaughtError
		);

		if (stage != null)
			init();
		else
			addEventListener(Event.ADDED_TO_STAGE, init);
	}

	// ---------------------------------------------------------------
	//  Init
	// ---------------------------------------------------------------

	private function init(?e:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
			removeEventListener(Event.ADDED_TO_STAGE, init);

		setupGame();
	}

	private function setupGame():Void
	{
		var stageWidth:Int  = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		// Auto-calculate zoom to letterbox the base resolution
		if (zoom == -1)
		{
			var ratioX:Float = stageWidth  / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom       = Math.min(ratioX, ratioY);
			gameWidth  = Math.ceil(stageWidth  / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}

		addChild(new FlxGame(gameWidth, gameHeight, initialState, FRAMERATE, FRAMERATE, skipSplash, startFullscreen));

		// FPS counter — desktop/web only; not shown on mobile
		#if !mobile
		fpsCounter = new FPS(10, 3, 0xFFFFFF);
		addChild(fpsCounter);
		#end
	}

	// ---------------------------------------------------------------
	//  Error handling
	// ---------------------------------------------------------------

	private function onUncaughtError(e:UncaughtErrorEvent):Void
	{
		e.preventDefault();

		var message:String = (e.error is String)
			? cast(e.error, String)
			: Std.string(e.error);

		// Surface a visible alert so the error isn't silently swallowed
		lime.app.Application.current.window.alert('Uncaught error:\n$message', 'Error');
	}
}
