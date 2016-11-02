import luxe.Vector;
import luxe.resource.Resource.JSONResource;
import luxe.utils.Maths;
import luxe.Input;
import luxe.tween.Actuate;
import luxe.Visual;
import luxe.Color;
import luxe.Camera;

import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import phoenix.Batcher;

import vexlib.Vex;
import vexlib.Palette;
import vexlib.VexPropertyInterface;
import vexlib.Stage;
import vexlib.Font;

/*
	//TODO by a new iphone charging cord (I guess I do have one in the car)

	What next?
	- options:
		- graphics glitches
		- responsive-ness of touch controls
		- improving usability of tools
		* make a tiny game
			- requires: exits, ?dialog, ?choices
			- need a script too
		* test on phone
		- big refactor of code-base
		- exits

	TODO
	X dialog boxes
	X pull tabs
	X helper size boxes in level editor
	- scale in level editor
	- parallax in level editor
	- drawing in level editor
	- clipboard support in editors
	- pull out a bunch of generic editor code into the lib
	X move path code into stage class
	X background color in stage class
	- move description code out of main
		- this is a harder problem than it looks
	X figure out world-space to UI-space transformation
		X ideal-screen-space to screen-space
	X bouncy arrows
	- stop immediate interaction with on-screen objects after leaving a dialog box
	- make transition between bouncy-arrow and player-swiped-arrow smoother
	- try everything on mobile
	- maybe think about: pull camera up when entering dialog box mode
		- think about: what's a good way to handle targeted camera positions and character positions in dialog mode
	- exits
		- are exits components?
		- are they attached to vex? or the scene?
		- what about left/right edge exits?
		- do we distinguish between up exits and down exits? (don't currently with dialog)
		- in general, how do we handle attached-to-level vs attached-to-vex and what is the relationship between the two modes?
			- need: generic pull-tab class, overall pull-tab handler in the game
				- tabs have an ?orientation, and position, and ?priority
				- only one can be drawn at a time (the game is responsible for doint that)
				- on pull, various things can be activated
					- components seem like a good way to specify this
					- what is a good way to have components all pile on the same pulltab?
					- need a callback function blah blah
				- this way, whatever editor/viewer it is can decide how / how-not to render the pull tabs (level editor vs level player)
	- readabilty of next arrows
	- trigger animations and other things on dialog / pull tab pull (generic pull tab thing?)
		- animation registration component
	- reconsider text update speed
	- camera that tracks interactables in the scene?
	- what's the actual framerate on the text?
	- movement still feels unresponsive, especially on tablet
	- lots of flickering going when animations are triggered

	TODO
	X re-implement ability for sudden stop
	- ? return coasting to universal joystick (haha oh boy, but it might simplify some things) [maybe later]
	- make y-axis pulling crisper somehow
	X make y-axis "lock" zone smaller than x-axis (probably except for when an interactive thing is there)
		- do I need to make swipe motions relative to the angle of the terrain?

	BACKLOG
	- walking particles
	- test different max swiping speeds
	- handle conflicting input types
	- can we constrain the window size?
	- animation queue? (this sort of works now but could be _much_ more robust / better designed)
	- stateful player redesign
	- EDITOR: hard to delete animation keyframes
		- more animation stuff
		- blending
		- composite-ing of multiple animations at once
	- TODOs consolidate into one file?
	- make this code not ugly anymore
	- figure out a more reliable way to load assets
	- better way to handle vex depth and internal, relative depth

	BUGS
	- flashing avatar at start of swipe action (what's the cause?)
	- flicker when switching from between animations (hello, stop)
	- BUG loading ref objects has a race condition?

*/

class Settings {
	public static var IDEAL_SCREEN_SIZE_W : Float = 800;
	public static var IDEAL_SCREEN_SIZE_H : Float = 450;
	/*
	public static var IDEAL_SCREEN_SIZE_W : Float = 1600;
	public static var IDEAL_SCREEN_SIZE_H : Float = 900;
	*/

	public static function IdealScreenSize() : Vector {
		return new Vector(IDEAL_SCREEN_SIZE_W, IDEAL_SCREEN_SIZE_H);
	}

	public static function StandardScreenSize() : Vector {
		return RealScreenPosToStandardScreenPos( Luxe.screen.size );
	}

	public static function StandardScreenRatio() : Vector {
		var ratio = new Vector(1,1);

		var realScreenSize = Luxe.screen.size;
		if (realScreenSize.x > realScreenSize.y) {
			var ratio_h = IDEAL_SCREEN_SIZE_H / realScreenSize.y;
			var ratio_w = (realScreenSize.x * ratio_h) / IDEAL_SCREEN_SIZE_W;
			ratio.x = ratio_h;
			ratio.y = ratio_w;
		}
		else {
			var ratio_w = IDEAL_SCREEN_SIZE_W / realScreenSize.x;
			var ratio_h = (realScreenSize.y * ratio_w) / IDEAL_SCREEN_SIZE_H;
			ratio.x = ratio_h;
			ratio.y = ratio_w;
		}

		return ratio;	
	}

	public static function RealScreenPosToStandardScreenPos( p:Vector ) : Vector {
		var ratio = StandardScreenRatio();
		return new Vector(p.x * ratio.x, p.y * ratio.y);
	}

}

//split this into multiple objects eventually
class Globals {
	public static var uiCam : Camera;
	public static function world_point_to_ui_point(p:Vector) {
		return uiCam.screen_point_to_world( Luxe.camera.world_point_to_screen( p ) );
	}
	public static function screen_point_to_ui_point(p:Vector) {
		return uiCam.screen_point_to_world( p );
	}
}

class Main extends luxe.Game {
	/* PALETTE */
	//public var paletteSrc = "assets/testpal2.vex";
	public var paletteSrc = "assets/testpal.vex";

	/* PLAYER */
	public var playerSrc = "assets/girl.vex";
	public var player : Vex;
	public var playerProps = {
		//stagePos : 300.0,
		stagePos : 150.0,
		velocity : new Vector(0,0),
		blocked : {
			left : false,
			right : false
		},
		isCoasting : false,
		isWaiting : false
	};
	var joystick : UniversalJoystick;
	var waitCounter = 0.0;
	// coasting friction - controls how speed decreases after lifting the "joystick"
	var coastingFrictionConstant = 4.0;
	var coastingFrictionForce = 0.0;
	var coastingFrictionAcceleration = 0.0;
	var coastingFriction = 0.0;
	// new max scroll spped
	var maxScrollSpeed = Settings.IDEAL_SCREEN_SIZE_W * 2.0;

	/* STAGE */
	public var stageSrc = "assets/stage2.vex";
	public var stage : Stage;

	/* CAMERA */
	var cameraProps = {
		offsetX : 0.0,
		speedMult : 2.0,
		maxDistAheadOfPlayer : Settings.IDEAL_SCREEN_SIZE_W * 0.25,
		edgeSpring : {
			maxDist : Settings.IDEAL_SCREEN_SIZE_W * 0.2,
			springConstant : 50.0,
			velocityX : 0.0
		}
	};
	var cameraMaxYDist = Settings.IDEAL_SCREEN_SIZE_H * 0.25;
	var curCamCenterY = 0.0;
	var idleZoom = 1.0;
	var idleZoomTimeCounter = 0.0;

	public var uiCam : Camera;
	public var uiScreenBatcher : Batcher;

	/* PULL UP DOWN */
	// TODO spend more time tuning this feature
	var pullVelocity = 0.0;
	public static var pullDelta = 0.0; //todo should not be public or static
	var pullMaxDistance = Settings.IDEAL_SCREEN_SIZE_H / 3;
	var pullZoomDelta = 0.10; // is this even having an impact?
	var pullFrictionConstant = 30.0;
	var pullFrictionForce = 0.0;
	var pullFriction = 0.0;
	var pullDeltaMax = 0.0; //track how far up or down we went in a single pull
	var maxPullSpeed = Settings.IDEAL_SCREEN_SIZE_H * 1.0;

	/* PARALLAX */
	var parallaxOrigin = new Vector(0,-1000);
	var bg1_batch : Batcher;
	var bg1_cam : Camera;
	var bg1_parallax = 0.5;

	var bg2_batch : Batcher;
	var bg2_cam : Camera;
	var bg2_parallax = 0.25;

	var fg1_batch : Batcher; //foreground 1 is the default luxe camera
	var fg1_cam : Camera;

	var fg2_batch : Batcher;
	var fg2_cam : Camera;
	var fg2_parallax = 1.5;


	/* DIALOG & FONT */
	var fontSrc = "assets/sysfont.vex";
	var font : Font;
	//settings
	var charWidth = 25;
	var charHeight = 50;
	var charactersPerLine = 24;
	var linesPerPage = 2;
	var charTypeSpeed = 0.1;
	var charDrawSpeed = 0.3;
	//constants
	var defaultCharBox = { //the arbitrariness bothers me
		width: 300,
		height: 550,
		baseline: 400
	};
	//derived values
	var charWidthScale : Float;
	var charHeightScale : Float;
	var textBoxWidth : Float;
	var textBoxHeight : Float;
	var textBoxX : Float;
	var textBoxY : Float;
	var textBoxPadX = 30;
	var textBoxPadY = 20;
	//geometry
	var descriptionVex = [];
	var descriptionBox : Geometry = null;
	//cur dialog state
	var curDialogStr = "";
	var isWaitingToContinueCurDialog = false;
	var curDialogRow = 0;
	var curDialogMaxRow = 0;
	var curDescription : Description = null;
	var dialogArrowBounce = {
		y:0
	};

	override function ready() {

		Luxe.fixed_timestep = false;
		Luxe.fixed_frame_time = 0.5;

		/* INPUT */
		joystick = new UniversalJoystick();
		//pullMaxDistance = Luxe.screen.height / 6;
		Luxe.events.listen("joystick.pressed", on_joystick_pressed);
		Luxe.events.listen("joystick.released", on_joystick_released);

		/* CAMERA */
		Luxe.camera.size = new Vector(Settings.IDEAL_SCREEN_SIZE_W, Settings.IDEAL_SCREEN_SIZE_H);
		Luxe.camera.size_mode = luxe.Camera.SizeMode.fit;

		/* PALETTE */
		Palette.StartBlank(); //rename
		var loadPalette = Luxe.resources.load_json( paletteSrc );
		loadPalette.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			Palette.Load(json);
			Palette.Swap("test");
		});

		/* PARALLAX */
		bg1_cam = new Camera({name:"bg1_cam"});
		bg1_cam.size = new Vector(Settings.IDEAL_SCREEN_SIZE_W, Settings.IDEAL_SCREEN_SIZE_H);
		bg1_cam.size_mode = luxe.Camera.SizeMode.fit;
		bg1_batch = Luxe.renderer.create_batcher({name:"bg1_batch", layer:-10, camera:bg1_cam.view});

		bg2_cam = new Camera({name:"bg2_cam"});
		bg2_cam.size = new Vector(Settings.IDEAL_SCREEN_SIZE_W, Settings.IDEAL_SCREEN_SIZE_H);
		bg2_cam.size_mode = luxe.Camera.SizeMode.fit;
		bg2_batch = Luxe.renderer.create_batcher({name:"bg2_batch", layer:-20, camera:bg2_cam.view});

		fg2_cam = new Camera({name:"fg2_cam"});
		fg2_cam.size = new Vector(Settings.IDEAL_SCREEN_SIZE_W, Settings.IDEAL_SCREEN_SIZE_H);
		fg2_cam.size_mode = luxe.Camera.SizeMode.fit;
		fg2_batch = Luxe.renderer.create_batcher({name:"fg2_batch", layer:10, camera:fg2_cam.view});

		//foreground test
		/*
		Luxe.draw.box({
				x : 1500, y : -2000,
				w : 100, h : 4000,
				color : Palette.Colors[6],
				batcher : fg2_batch
			});
		Luxe.draw.box({
				x : 1800, y : -2000,
				w : 50, h : 4000,
				color : Palette.Colors[6],
				batcher : fg2_batch
			});
		Luxe.draw.box({
				x : 2400, y : -2000,
				w : 100, h : 4000,
				color : Palette.Colors[6],
				batcher : fg2_batch
			});
		Luxe.draw.box({
				x : 3000, y : -2000,
				w : 120, h : 4000,
				color : Palette.Colors[6],
				batcher : fg2_batch
			});
		*/
		Luxe.draw.box({
				x : 3500, y : -2000,
				w : 50, h : 4000,
				color : Palette.Colors[6],
				batcher : fg2_batch
			});
		Luxe.draw.box({
				x : 3800, y : -2000,
				w : 150, h : 4000,
				color : Palette.Colors[6],
				batcher : fg2_batch
			});
		Luxe.draw.box({
				x : 4400, y : -2000,
				w : 60, h : 4000,
				color : Palette.Colors[6],
				batcher : fg2_batch
			});
		Luxe.draw.box({
				x : 5000, y : -2000,
				w : 100, h : 4000,
				color : Palette.Colors[6],
				batcher : fg2_batch
			});

		/* PLAYER */
		var loadPlayer = Luxe.resources.load_json( playerSrc );
		loadPlayer.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			player = new Vex(json);
			player.properties.scale = new Vector(0.3,0.3);
			
			var loadPlayerAnim = Luxe.resources.load_json( "assets/walkanim0.vex" );
			loadPlayerAnim.then(function(jsonRes : JSONResource) {
				var json = jsonRes.asset.json;
				player.addAnimation(json);
			});

			//todo learn to use parcels to load these in bulk?
			var loadPlayerAnim2 = Luxe.resources.load_json( "assets/waitanim1_half.vex" );
			loadPlayerAnim2.then(function(jsonRes : JSONResource) {
				var json = jsonRes.asset.json;
				player.addAnimation(json);
				playerProps.isWaiting = true;
				player.playAnimation("wait", 1.0).ease(luxe.tween.easing.Quad.easeInOut).reflect().repeat();
			});
			
			var loadPlayerAnim3 = Luxe.resources.load_json( "assets/stopanim2.vex" );
			loadPlayerAnim3.then(function(jsonRes : JSONResource) {
				var json = jsonRes.asset.json;
				player.addAnimation(json);
			});

			var loadPlayerAnim4 = Luxe.resources.load_json( "assets/boredanim1.vex" );
			loadPlayerAnim4.then(function(jsonRes : JSONResource) {
				var json = jsonRes.asset.json;
				player.addAnimation(json);
			});

			var loadPlayerAnim5 = Luxe.resources.load_json( "assets/helloanim2.vex" );
			loadPlayerAnim5.then(function(jsonRes : JSONResource) {
				var json = jsonRes.asset.json;
				player.addAnimation(json);
			});

		});

		/* STAGE */
		/*
		var loadStage = Luxe.resources.load_json( stageSrc );
		loadStage.then(function(jsonRes : JSONResource) {
			var json : StageFormat = jsonRes.asset.json;
			Luxe.renderer.clear_color = json.background;
			path = json.path;

			var setSrc : String = json.set;

			var loadSet = Luxe.resources.load_json( setSrc );
			loadSet.then(function(jsonRes : JSONResource) {
				var json = jsonRes.asset.json;
				set = new Vex(json);
				//set.depth = 0; //TODO this IS broken...

				// PARALLAX //yo this is pretty hacky and doesn't handle children
				var bg1 = set.find("bg1")[0];
				Luxe.renderer.batcher.remove(bg1.geometry);
				bg1_batch.add(bg1.geometry);

				var bg2 = set.find("bg2")[0];
				Luxe.renderer.batcher.remove(bg2.geometry);
				bg2_batch.add(bg2.geometry);

				
				//var fg2 = set.find("fg2")[0];
				//Luxe.renderer.batcher.remove(fg2.geometry);
				//fg2_batch.add(fg2.geometry);
				
			});
		});
		*/

		/* UI BATCHER */
		uiCam = new Camera({name:"uiCam"});
		uiCam.size = new Vector(Settings.IDEAL_SCREEN_SIZE_W, Settings.IDEAL_SCREEN_SIZE_H);
		uiCam.size_mode = luxe.Camera.SizeMode.fit;
		uiScreenBatcher = Luxe.renderer.create_batcher({name:"uiScreenBatcher", layer:10, camera:uiCam.view});
		Description.uiBatcher = uiScreenBatcher;
		Globals.uiCam = uiCam; //hacky af

		/* NEW STAGE */
		var loadStage = Luxe.resources.load_json( stageSrc );
		loadStage.then(function(jsonRes : JSONResource) {
			var json : StageFormat = jsonRes.asset.json;
			stage = new Stage(json);
			Luxe.renderer.clear_color = stage.background; //Palette.Colors[0]; //hack
			Description.uiBatcher = uiScreenBatcher;
			Description.player = player;
		});

		/* DESCRIPTION */
		Luxe.events.listen("description", start_description);

		/* DIALOG BOX*/
		//load the system font (aka the default font I made)
		var loadFont = Luxe.resources.load_json( fontSrc );
		loadFont.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			font = new Font(json);
			trace("font loaded! " + font.id);
			//isWaiting = true;
		});
		textBoxWidth = (charWidth * charactersPerLine) + (textBoxPadX*2);
		textBoxHeight = (charHeight * linesPerPage) + (textBoxPadY*2);
		textBoxX = (Settings.IDEAL_SCREEN_SIZE_W - textBoxWidth)/2; // = 70
		textBoxY = 20;
		charWidthScale = charWidth / defaultCharBox.width;
		charHeightScale = charHeight / defaultCharBox.height;
		trace(textBoxWidth);
		trace("&&&&&&&&&&&");
	}

	/* DESCRIPTION */
	var isDescriptionMode = false;
	function start_description(d:Description) {
		isDescriptionMode = true;

		/*
		descriptionBox = Luxe.draw.box({
				x:50, y:20,
				w:700, h:100,
				color: new Color(0,0,0),
				batcher: uiBatcher
			});
		*/
		curDescription = d;

		descriptionBox = Luxe.draw.box({
				x:textBoxX, y:textBoxY,
				w:textBoxWidth, h:textBoxHeight,
				color: new Color(0,0,0),
				batcher: uiScreenBatcher,
				depth: -100 //force it to the back
			});

		descriptionVex = [];
		curDialogStr = d.text;
		curDialogRow = 0;
		isWaitingToContinueCurDialog = false;

		writeText( curDialogStr ).onComplete = function(row,maxRow) {
			curDialogRow = row;
			curDialogMaxRow = maxRow;
			isWaitingToContinueCurDialog = true;

			//bouncy arrow
			dialogArrowBounce.y = 0;
			//Actuate.tween(dialogArrowBounce,1,{y:30}).ease(luxe.tween.easing.Quad.easeInOut).delay(0.3).repeat();
			Actuate.tween(dialogArrowBounce,1,{y:30}).ease(luxe.tween.easing.Quad.easeInOut).reflect().repeat();
		};
	}

	function nextDialogPage() {
		Actuate.stop(dialogArrowBounce); //stop bouncy arrow

		isWaitingToContinueCurDialog = false;
		clearDescription();
		if (curDialogRow >= curDialogMaxRow) {
			uiScreenBatcher.remove(descriptionBox); //awkward way to destroy description box
			isDescriptionMode = false; //todo settle on "description" or "dialog"
			curDescription.isDescribing = false; //todo need a better name for this variable (encapsulate in method?)
			curDescription = null;
			pullDelta = 0;
		}
		else {
			//next page of dialog
			writeText( curDialogStr, curDialogRow ).onComplete = function(row,maxRow) {
				curDialogRow = row;
				curDialogMaxRow = maxRow;
				isWaitingToContinueCurDialog = true;
				
				//bouncy arrow
				dialogArrowBounce.y = 0;
				//Actuate.tween(dialogArrowBounce,1,{y:30}).ease(luxe.tween.easing.Quad.easeInOut).delay(0.3).repeat();
				Actuate.tween(dialogArrowBounce,1,{y:30}).ease(luxe.tween.easing.Quad.easeInOut).reflect().repeat();
			};
		}
		
	}

	function on_joystick_pressed( axis:Vector ) {
		trace("PRESSED");
		playerProps.velocity.x = Maths.clamp(axis.x * Settings.IDEAL_SCREEN_SIZE_W, -maxScrollSpeed, maxScrollSpeed);
		pullVelocity = Maths.clamp(axis.y * Settings.IDEAL_SCREEN_SIZE_H, -maxPullSpeed, maxPullSpeed);

		pullDeltaMax = 0;

		idleZoomTimeCounter = 0;
	}

	var testCoastingTimer = 0.0;
	function on_joystick_released( axis:Vector ) {
		trace("RELEASED");

		//x
		playerProps.velocity.x = Maths.clamp(axis.x * Settings.IDEAL_SCREEN_SIZE_W, -maxScrollSpeed, maxScrollSpeed);
		trace(playerProps.velocity.x);
		coastingFrictionForce = playerProps.velocity.x * coastingFrictionConstant;
		coastingFrictionAcceleration = 0;
		coastingFriction = 0;
		testCoastingTimer = 0.0;

		//y
		if (joystick.source != UniversalJoystick.InputSource.Keyboard) {
			trace("pull release mouse");
			pullVelocity = Maths.clamp(axis.y * Settings.IDEAL_SCREEN_SIZE_H, -maxPullSpeed, maxPullSpeed);
			pullFrictionForce = pullVelocity * pullFrictionConstant;
			pullFriction = 0;
			trace(pullVelocity);
			trace(pullFrictionForce);
		}
		else {
			pullVelocity = 0;
			pullFrictionForce = 0;
			pullFriction = 0;
		}
	}

	override function onkeydown( e:KeyEvent ) {
		//nothin' right now
		if (e.keycode == Key.key_9) {
			Luxe.camera.zoom -= 0.1;
		}
		else if (e.keycode == Key.key_0) {
			Luxe.camera.zoom += 0.1;
		}
	}

	override function onmousedown(e:MouseEvent) {
	}

	override function onmouseup(e:MouseEvent) {
	}

	function on_pull_complete() {

		trace("PULL COMPLETE");

		/*
		if (pullDeltaMax / pullMaxDistance > 0.5) {
			//boilerplate to stop animation
			player.stopAnimation();
			var oldFacingScaleX = player.scale.x;
			player.resetToBasePose(); //this might overwrite things too often
			player.scale.x = oldFacingScaleX; //hack
			playerProps.isWaiting = false; //yet another hack - this time to tell waiting anim it needs to resume (I really need to state-ify this code)

			player.playAnimation("hello", 1.5);

		}
		*/

		pullDeltaMax = 0;
	}

	override function update(dt:Float) {

		//if (player != null && path != null) { //eventually need a smarter way to handle this
		if (player != null && stage != null) {

			/* DESCRIPTION MODE */
			//todo make a real state
			if (isDescriptionMode) {

				if (isWaitingToContinueCurDialog) {
					//draw next arrow
					var pull = Math.abs( Main.pullDelta );
					var anchorPoint = Globals.screen_point_to_ui_point( Luxe.screen.mid );
					if ( Luxe.input.mousedown(1) || pull > 0 ) { //joystick.yAxisHeld() ) { //need a generic joystick.inputHeld()
						anchorPoint.y += pull;
					}
					else {
						anchorPoint.y += dialogArrowBounce.y;
					}
					Luxe.draw.line({
							p0: anchorPoint,
							p1: anchorPoint.clone().add( new Vector(-30,-30) ),
							immediate: true,
							batcher: uiScreenBatcher
						});
					Luxe.draw.line({
							p0: anchorPoint,
							p1: anchorPoint.clone().add( new Vector(30,-30) ),
							immediate: true,
							batcher: uiScreenBatcher
						});

					if (pull >= 60) {
						nextDialogPage();
					}
				}

				//stop player from moving during dialog mode (hacky)
				playerProps.velocity.x = 0;
			}
		
			/* PULL UP & DOWN */
			if ( joystick.yAxisHeld() ) {
				pullVelocity = Maths.clamp(joystick.axis.y * Settings.IDEAL_SCREEN_SIZE_H, -maxPullSpeed, maxPullSpeed);
			}
			else if ( Math.abs(pullVelocity) > 0 ) {
				pullFriction += pullFrictionForce * dt;
				pullVelocity -= pullFriction * dt;

				var hasSignSwitched = (pullVelocity < 0) != (pullFrictionForce < 0);
				if ( hasSignSwitched ) {
					trace("friction done!");
					pullVelocity = 0;
					pullFriction = 0;
					pullFrictionForce = 0;
				}
			}

			if ( Math.abs(pullVelocity) > 0 ) {
				var pullResistance = 1.0;
				if ( (pullVelocity > 0) == (pullDelta > 0) ) {
					pullResistance = Math.pow( 1 - (Math.abs(pullDelta) / pullMaxDistance), 2 );
				}
				pullDelta += pullVelocity * pullResistance * dt;
				pullDelta = Maths.clamp(pullDelta, -pullMaxDistance, pullMaxDistance);
				if (Math.abs(pullDelta) > pullDeltaMax) pullDeltaMax = Math.abs(pullDelta);
			}
			else if (Math.abs(pullDelta) > 0) {
				pullDelta -= (pullDelta * 5) * dt;
				if (Math.abs(pullDelta) < 5) {
					pullDelta = 0;
					on_pull_complete();
				}
			}

			/* PLAYER */
			//keep player facing the right direction
			if (playerProps.velocity.x > 0 && player.scale.x < 0) player.scale.x *= -1;
			if (playerProps.velocity.x < 0 && player.scale.x > 0) player.scale.x *= -1;
			
			//update player animations
			var absSpeed = Math.abs(playerProps.velocity.x);
			//waiting animation
			if ( playerProps.isWaiting && (absSpeed > 0 && !playerIsMovingBlockedDirection()) ) {
				var oldpos = player.pos.clone();

				playerProps.isWaiting = false;
				player.stopAnimation(); //todo ... stop by name?
				player.resetToBasePose();	//todo why is this also resetting base position? this method sucks man!

				//TODO in progress
				//hack to test particles
				/*
				spawnDustParticles(	10, //count
									oldpos, //pos
									6, 60, //speed
									-90, -120, //angle
									10, 20, //rot speed
									3, 10, //scale
									0.3, 1, //scale speed
									0.5, 1.5 //lifetime
								);
				*/
			}
			else if ( !playerProps.isWaiting && (absSpeed == 0 || playerIsMovingBlockedDirection()) ) {
				trace("play wait anim!");
				playerProps.isWaiting = true;
				player.queueAnimation("wait", 1.0).ease(luxe.tween.easing.Quad.easeInOut).reflect().repeat();
				waitCounter = 0; //counter to trakc when to play boredom animation (kick foot)
			}
			//walk animation
			if (absSpeed > 0 && !playerIsMovingBlockedDirection()) {
				var maxPlayerSpeedPercent = absSpeed / maxScrollSpeed;
				var walkAnimSpeed = 0.5 + ( 1.0 * maxPlayerSpeedPercent );
				var nextWalkT = player.getAnimation("walk").t + ( walkAnimSpeed * dt );
				if (nextWalkT > 1.0) nextWalkT = 0; //there's a better smoother way to loop this than a hard cut off, but I'm too lazy
				player.getAnimation("walk").t = nextWalkT;				
			}

			if (playerProps.isWaiting) {
				waitCounter += dt;

				var animTime = 1.5;
				var animWaitTime = 10;
				if (waitCounter > animWaitTime) {
					//HACK this animation takes advantage of accidentally being able to composite animations --- formalize this somehow?
					player.playAnimation("bored", animTime).ease(luxe.tween.easing.Quad.easeInOut);

					//below line is necessary if not using compositing hack (but I am --- keeping this as a note)
					//player.queueAnimation("wait", 1.0).ease(luxe.tween.easing.Quad.easeInOut).reflect().repeat();

					waitCounter = -animTime; //hack to delay counter start so animation lines up
				}
			}

			//need to check if blocked to start blocked anim
			var prevBlocked = playerProps.blocked.left || playerProps.blocked.right;

			//connect input to player
			if (isDescriptionMode) {
				playerProps.velocity.x = 0; //hacky
			}
			else if ( joystick.isDown() ) {
				playerProps.velocity.x = Maths.clamp(joystick.axis.x * Settings.IDEAL_SCREEN_SIZE_W, -maxScrollSpeed, maxScrollSpeed);
			}
			else if ( Math.abs(playerProps.velocity.x) > 0 ) {
				//coasting
				testCoastingTimer += dt;
				coastingFriction += coastingFrictionForce * dt;
				playerProps.velocity.x -= coastingFriction * dt; 

				var hasVelocitySignSwitched = (playerProps.velocity.x < 0) != (coastingFrictionForce < 0);
				if ( hasVelocitySignSwitched ) {
					playerProps.velocity.x = 0;
					coastingFrictionForce = 0; //stop coasting
					coastingFriction = 0;
					coastingFrictionAcceleration = 0; //not currently being used TODO remove?
					trace("COASTING TOTAL TIME " + testCoastingTimer);
					testCoastingTimer = 0;
				}

			}
			playerProps.stagePos += playerProps.velocity.x * dt;

			//keep player in bounds
			playerProps.blocked.left = stage.edgeCollisionLeft( playerProps.stagePos );
			playerProps.blocked.right = stage.edgeCollisionRight( playerProps.stagePos );
			//update world pos
			playerProps.stagePos = stage.clampToStage( playerProps.stagePos );
			player.pos = stage.worldPos( playerProps.stagePos );

			//blocked stop animation
			var curBlocked = playerProps.blocked.left || playerProps.blocked.right;
			if (curBlocked && !prevBlocked) {
				trace("play blocked anim!");

				trace(absSpeed);

				if (absSpeed < 300) {
					//don't play animation
				}
				else {
					var maxPlayerSpeedPercent = absSpeed / maxScrollSpeed;
					var animTime = 1.0 - ( 0.5 * maxPlayerSpeedPercent );
					if (animTime < 0.5) animTime = 0.5; //hack because velocity is too big sometimes

					trace("???");
					trace(animTime);

					//boilerplate to stop animation
					player.stopAnimation();
					var oldFacingScaleX = player.scale.x;
					player.resetToBasePose(); //this might overwrite things too often
					player.scale.x = oldFacingScaleX; //hack

					player.playAnimation("stop", animTime);
				}
			}

			/* CAMERA */
			//calc camera distance this frame
			var cameraDistance = playerProps.velocity.x * cameraProps.speedMult * dt;
			//find bounds of normal camera movement
			var leftDistMax = Math.min(0, -cameraProps.maxDistAheadOfPlayer - cameraProps.offsetX);
			var rightDistMax = Math.max(0, cameraProps.maxDistAheadOfPlayer - cameraProps.offsetX);
			var cameraDistanceInBounds = Maths.clamp(cameraDistance, leftDistMax, rightDistMax);
			var cameraDistancePastBounds = cameraDistance - cameraDistanceInBounds;
			//update camera base offset
			cameraProps.offsetX += cameraDistanceInBounds;
			//move camera past the edge if the player is blocked
			if (playerIsMovingBlockedDirection() && Math.abs(cameraDistancePastBounds) > 0) {
				var distancePastEdge = Math.max(0, Math.abs(cameraProps.offsetX) - cameraProps.maxDistAheadOfPlayer);
				var percentOfMaxDistPastEdge = Math.min( distancePastEdge / cameraProps.edgeSpring.maxDist, 1.0 );
				var resistanceFactor = Math.pow( Math.max( 0, 1 - percentOfMaxDistPastEdge ), 3 );
				cameraDistancePastBounds *= resistanceFactor;
				cameraProps.offsetX += cameraDistancePastBounds;
				var maxTotalOffset = cameraProps.maxDistAheadOfPlayer + cameraProps.edgeSpring.maxDist;
				cameraProps.offsetX = Maths.clamp(cameraProps.offsetX, -maxTotalOffset, maxTotalOffset);
			}
			//use spring to keep camera in its proper bounds
			if (!joystick.xAxisHeld() && Math.abs(cameraProps.offsetX) > cameraProps.maxDistAheadOfPlayer) {
				var dir = cameraProps.offsetX > 0 ? 1 : -1;
				var dif = Math.abs(cameraProps.offsetX) - cameraProps.maxDistAheadOfPlayer;
				var springForce = dif * cameraProps.edgeSpring.springConstant;
				cameraProps.edgeSpring.velocityX += -dir * springForce * dt;
				cameraProps.offsetX += cameraProps.edgeSpring.velocityX * dt;
				//stop using spring when it brings you back from the edge
				if (Math.abs(cameraProps.offsetX) < cameraProps.maxDistAheadOfPlayer) {
					cameraProps.offsetX = dir * cameraProps.maxDistAheadOfPlayer; //put camera at resting place
					cameraProps.edgeSpring.velocityX = 0; //stop spring motion
					playerProps.velocity.x = 0; //stop player from moving
				}
			}
			else {
				cameraProps.edgeSpring.velocityX = 0; //edge case protection
			}
			//keep camera attached to player
			//x
			Luxe.camera.center.x = player.pos.x + cameraProps.offsetX;
			//y
			var yOffsetToPutPlayerCloserToScreenBottom = Settings.IDEAL_SCREEN_SIZE_H * 0.25; //75; //TODO rename this?
			var totalYOffset = -yOffsetToPutPlayerCloserToScreenBottom;
			//curCamCenterY = Maths.clamp( curCamCenterY, player.pos.y + totalYOffset - cameraMaxYDist, player.pos.y + totalYOffset + cameraMaxYDist );
			var camCenterYGoal = player.pos.y + totalYOffset;
			//var camCenterYDist = camCenterYGoal - curCamCenterY;
			//curCamCenterY += camCenterYDist * 0.8 * dt; //float towards correct y pos [this didn't work how I wanted]
			curCamCenterY = camCenterYGoal;
			//Luxe.camera.center.y = curCamCenterY + pullDelta; // * 0.5); //what's the 0.5 for? I forgot
			Luxe.camera.center.y = curCamCenterY;

			//zoom stuff
			if (!joystick.isDown() && Math.abs(playerProps.velocity.x) <= 0) {
				idleZoomTimeCounter += dt;
			}

			if (idleZoomTimeCounter > 12) {
				idleZoom = 1 - (0.75 * Math.min( (idleZoomTimeCounter - 12) / 20, 1 ));
			}
			else if (joystick.isDown()) {
				idleZoom += 2 * dt;
				if (idleZoom > 1) idleZoom = 1;
			}

			//update camera zoom due to pull
			/*
			Luxe.camera.zoom = 1 - (pullZoomDelta * (pullDelta / pullMaxDistance));
			Luxe.camera.zoom *= idleZoom;
			*/

			/* PARALLAX */
			var parallaxDisplacement = Vector.Subtract(Luxe.camera.center, parallaxOrigin);

			var bg1_parallaxDisplacement = Vector.Multiply(parallaxDisplacement, bg1_parallax);
			bg1_cam.center = parallaxOrigin.clone().add(bg1_parallaxDisplacement);

			var bg2_parallaxDisplacement = Vector.Multiply(parallaxDisplacement, bg2_parallax);
			bg2_cam.center = parallaxOrigin.clone().add(bg2_parallaxDisplacement);

			var fg2_parallaxDisplacement = Vector.Multiply(parallaxDisplacement, fg2_parallax);
			fg2_cam.center = parallaxOrigin.clone().add(fg2_parallaxDisplacement);
		}
	}

	override function onwindowresized(e:luxe.Screen.WindowEvent) {

	}

	/* PLAYER */
	public function playerIsMovingBlockedDirection() : Bool {
		return (playerProps.blocked.left && playerProps.velocity.x <= 0) || (playerProps.blocked.right && playerProps.velocity.x >= 0);
	}

	/* DUST PARTICLE */
	/*
	function spawnDustParticles(count, pos, minSpeed, maxSpeed, minAngle, maxAngle, minRotSpd, maxRotSpd, minScale, maxScale, minScaleSpd, maxScaleSpd, minLife, maxLife) {
		for (i in 0 ... count) {

			var speed = Luxe.utils.random.float(minSpeed, maxSpeed);
			var angle = Maths.radians( Luxe.utils.random.float(minAngle, maxAngle) );
			var direction = new Vector(Math.cos(angle), Math.sin(angle));
			var velocity = Vector.Multiply( direction, speed );
			var rotSpd = Luxe.utils.random.float(minRotSpd, maxRotSpd);
			var scale = Luxe.utils.random.float(minScale, maxScale);
			var scaleSpd = Luxe.utils.random.float(minScaleSpd, maxScaleSpd);
			var life = Luxe.utils.random.float(minLife, maxLife);

			var particle = new Visual({
					color: new Color(1,1,1,1),
					pos: pos.clone(),
					size: new Vector(1, 1),
					origin: new Vector(0.5, 0.5),
					scale: new Vector(scale, scale),
					batcher: Luxe.renderer.batcher,
					depth: 100
				});

			particle.add(
				new DustParticle({
					name: "dust_particle_comp",
					velocity: velocity,
					rotSpeed: rotSpd,
					scaleSpeed: scaleSpd,
					lifetime: life
				})
			);
		}
	}
	*/

	//todo move into its own class or some shit
	/* DIALOG */
	//todo use clearDescription and make it more complete
	function clearDescription() {
		for (v in descriptionVex) {
			cast(v,Vex).destroy(true);
		}
		descriptionVex = [];
	}

	/*
	typedef DialogReturn = {
		public var onComplete : Dynamic<Int -> Void>
	}
	*/

	function writeText(text:String, ?row:Int) {
		//var count = 0;
		var typeTimer : snow.api.Timer = null;

		var textLines = preprocessText(text);
		//var row = 0;
		if (row == null) row = 0;
		var startingRow = row;
		var maxRow = textLines.length;
		var col = 0;

		var returnObj = {
			onComplete : null
		};

		trace("WRITE TEXT");
		trace(startingRow);
		trace(maxRow);

		var typeNext = function() {

			var localRow = (row-startingRow); //row count local to this page todo needs better name

			//calculate row & column position of character
			if (localRow >= linesPerPage) {
				//page is finished!
				trace("page is DONE");
				typeTimer.stop();
				if (returnObj.onComplete != null) returnObj.onComplete(row,maxRow);
				return;
			}

			//create vex representation of character
			//var nextChar = text.charAt(count);
			var nextChar = textLines[row].charAt(col);
			trace(nextChar);
			var tweenNextChar = null;
			if (font.exists(nextChar)) { //skip undefined characters
				var json = font.get(nextChar);
				json.batcher = uiScreenBatcher; //hacky way to force characters to draw on the ui layer
				var v = new Vex(json); //TODO define font.getVex
				//scale character
				v.scale.x = charWidthScale;
				v.scale.y = charHeightScale;
				//position character
				v.pos.x = textBoxX + textBoxPadX + (col * charWidth) + (charWidth/2);
				v.pos.y = textBoxY + textBoxPadY + (localRow * charHeight) + (charHeight/2);

				//start character animation
				tweenNextChar = animateStrokes(v, charDrawSpeed);

				descriptionVex.push(v); //keep track of all the vex objects used to create this description (TODO maybe use vex instead of a list?)		
			}

			//increment col and look for end of page
			col++;
			if (col >= textLines[row].length) {
				//go to next row
				col = 0;
				row++;

				if (row >= textLines.length) {
					//dialog is finished!
					typeTimer.stop();

					if (returnObj.onComplete != null) {
						if (tweenNextChar != null) {
							//if there's a character drawing, wait until it finishes to launch oncomplete
							tweenNextChar.onComplete(function() {
									//onComplete();
									trace("B");
									returnObj.onComplete(row,maxRow);
								});
						}
						else {
							//or just do it now (will this ever happen?)
							//onComplete();
							trace("C");
							returnObj.onComplete(row,maxRow);
						}
					}
				}
			}
		};

		typeTimer = Luxe.timer.schedule(charTypeSpeed, typeNext, true);

		return returnObj;
	}

	function preprocessText(text:String) : Array<String> {
		//splits page into lines and does word wrap
		var textLines = [];
		textLines.push(""); //newline
		var lineIndex = 0;
		for (word in text.split(" ")) {
			trace(word);
			//word
			if (textLines[lineIndex].length + word.length > charactersPerLine) {
				textLines.push(""); //newline
				lineIndex++;
			}
			textLines[lineIndex] += word;

			//space after word
			if (textLines[lineIndex].length + 1 > charactersPerLine) {
				textLines.push(""); //newline
				lineIndex++;
			}
			else {
				//add space
				textLines[lineIndex] += " ";
			}
		}
		return textLines;
	}

	//this is hacky as heck but it's just a test really
	function animateStrokes(v:Vex, time:Float) {
		var strokes : Array<Array<Vector>> = v.properties.path.toMultiPath();

		var pointCounter = {
			count : 0
		};
		var totalLength = 0;
		for (s in strokes) {
			totalLength += s.length;
		}

		return Actuate.tween(pointCounter, time, {count:totalLength-1}).ease(luxe.tween.easing.Quad.easeIn)
			.onUpdate(function(){
				var curCount = pointCounter.count;
				var curStrokes = [];
				var curStrokeIndex = 0;
				while (strokes[curStrokeIndex].length < curCount) {
					var s = strokes[curStrokeIndex];
					curCount -= s.length;
					curStrokes.push(s);
					curStrokeIndex++;
				}
				if (curCount > 0 && curStrokeIndex < strokes.length) {
					curStrokes.push([]);
					for (i in 0 ... curCount) {
						curStrokes[curStrokeIndex].push( strokes[curStrokeIndex][i] );
					}
				}
				v.properties.path = curStrokes;
			});
	}

}

/* STAGE */
/*
typedef StageFormat = {
	@:optional public var type : Property;
	@:optional public var id : Property;
	@:optional public var set : Property;
	@:optional public var background : Property;
	@:optional public var path : Property;
}
*/

/* RESPONSIVE GROUND */
//TODO what about horizontal responsiveness?
//TODO can I make this just update on start and on screen size change
class ResponsiveGround extends luxe.Component {
	var vex : Vex;

	var startPoint : Vector;
	var endPoint : Vector;
	var curBottomY : Float;
	var screenBottomY : Float;
	var geo : Geometry = null;

	override public function init() {
		vex = cast(this.entity);

		var points : Array<Vector> = vex.getPathInWorldSpace();

		startPoint = points[0];
		endPoint = points[points.length-1];

		curBottomY = (startPoint.y < endPoint.y) ? startPoint.y : endPoint.y;
	}

	override public function update(dt:Float) {
		screenBottomY = Luxe.camera.screen_point_to_world( Luxe.screen.size ).y;

		if (screenBottomY > curBottomY) {
			curBottomY = screenBottomY;

			if (geo != null) {
				Luxe.renderer.batcher.remove(geo);
			}

			geo = new Geometry({
						primitive_type: PrimitiveType.triangles,
						batcher: Luxe.renderer.batcher
					});

			var startToBottom = new Vector(startPoint.x, curBottomY);
			var endToBottom = new Vector(endPoint.x, curBottomY);

			geo.add( new Vertex(startPoint, vex.color) );
			geo.add( new Vertex(endPoint, vex.color) );
			geo.add( new Vertex(startToBottom, vex.color) );
			geo.add( new Vertex(endPoint, vex.color) );
			geo.add( new Vertex(endToBottom, vex.color) );
			geo.add( new Vertex(startToBottom, vex.color) );
		}
	}

}

//todo move into its own file
/* DESCRIPTION */
typedef DescriptionOptions = {
	> luxe.options.ComponentOptions,
	@:optional public var text : String; 
}

class Description extends luxe.Component {
	public var text : String;
	public var vex : Vex;
	public var isEditorMode = false; //obviously not true in the future

	public static var uiBatcher : Batcher; //hacky
	public static var player : Vex; //also hacky

	public var isDescribing = false;

	var bouncyArrow = {
		y: 0
	};
	var wasVisible = false;

	override public function new(?options:DescriptionOptions) {
		super(options);
		if (options.text != null) text = options.text;
		//Main.Instance.stage.registerDescription(this); //TODO this is probably a terrible way to to do this
	}

	override public function init() {
		vex = cast(this.entity);
	}

	override public function update(dt:Float) {
		if (isEditorMode) {
			drawArrow();
		}
		else {
			var isVisible = isArrowVisible();

			//hacky state-change events
			if (isVisible && !wasVisible) {
				//start bouncy arrow
				bouncyArrow.y = -20;
				Actuate.tween(bouncyArrow, 1, {y:0}).ease(luxe.tween.easing.Quad.easeInOut).reflect().repeat();
			}
			else if (!isVisible && wasVisible) {
				//stop bouncy arrow
				Actuate.stop(bouncyArrow);
				bouncyArrow.y = 0;
			}


			if (isVisible) {
				//draw arrow
				drawArrow();
				if (Math.abs( Main.pullDelta ) > 60) {
					Luxe.events.fire("description", this);
					startDescription();
				}
			}

			wasVisible = isVisible;
		}
	}

	function startDescription() {
		isDescribing = true;
		/*
		Luxe.draw.box({
				x:50, y:20,
				w:700, h:100,
				color: new Color(0,0,0),
				batcher: uiBatcher
			});
			*/
	}

	function isArrowVisible() {
		return !isDescribing && ( Math.abs(player.pos.x - vex.pos.x) < 300 ); //todo should reall be "is it on screen?"
	}

	function drawArrow() {
		//draw pull tab
		var bounds = vex.boundsWorld();
		var topY = bounds[0].y;
		var midX = bounds[0].x + ((bounds[1].x - bounds[0].x)/2);

		var anchorPoint = new Vector(midX,topY);
		//anchorPoint = Luxe.camera.world_point_to_screen( anchorPoint );
		anchorPoint = Globals.world_point_to_ui_point( anchorPoint );
		anchorPoint.y -= 30;
		if (!isEditorMode) {
			if (Luxe.input.mousedown(1) || Math.abs( Main.pullDelta ) > 0 ) { //todo replace w/ something in joystick class
				anchorPoint.y += Math.abs( Main.pullDelta );
			}
			else {
				anchorPoint.y += bouncyArrow.y;
			}
		}

		Luxe.draw.line({
				p0: anchorPoint,
				p1: anchorPoint.clone().add(new Vector(-30,-30)),
				immediate: true,
				batcher: uiBatcher
			});
		Luxe.draw.line({
				p0: anchorPoint,
				p1: anchorPoint.clone().add(new Vector(30,-30)),
				immediate: true,
				batcher: uiBatcher
			});
	}
}

/* DUST PARTICLE 
	- spin
	- size
	- alpha
	- time alive
*/
/*
typedef DustParticleOptions = {
	> luxe.options.ComponentOptions,
	public var velocity : Vector;
	public var rotSpeed : Float;
	public var scaleSpeed : Float;
	public var lifetime : Float;
}

class DustParticle extends luxe.Component {
	public var visual : Visual;

	public var velocity : Vector;
	public var rotSpeed : Float;
	public var scaleSpeed : Float;
	public var lifetime : Float;
	var time = 0.0;

	override public function new (_options:DustParticleOptions) {
		super(_options);

		velocity = _options.velocity;
		rotSpeed = _options.rotSpeed;
		scaleSpeed = _options.scaleSpeed;
		lifetime = _options.lifetime;
	}

	override public function init() {
		visual = cast( this.entity );
	}

	override public function update(dt:Float) {
		time += dt;

		visual.pos.add( Vector.Multiply(velocity, dt) );
		visual.rotation_z += rotSpeed * dt;
		visual.scale.add( new Vector(scaleSpeed * dt, scaleSpeed * dt) );
		visual.color.a = 1.0 - (time / lifetime);

		if (time >= lifetime) {
			entity.destroy();
			//entity.remove(this.name);
		}
	}


}
*/