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

/*
	TODO
	- dialog boxes
	X pull tabs
	- helper size boxes in level editor
	- scale in level editor
	X move path code into stage class
	X background color in stage class
	- move description code out of main


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
	//old stage
	/*
	public var stageSrc = "assets/playgroundstage.vex";
	public var set : Vex;
	public var path : Array<Vector>;
	*/
	//new stage
	public var stageSrc = "assets/stage2.vex";
	public var stage : Stage;
	public var uiScreenBatcher : Batcher;

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
		var uiCam = new Camera({name:"uiCam"});
		uiScreenBatcher = Luxe.renderer.create_batcher({name:"uiScreenBatcher", layer:10, camera:uiCam.view});
		Description.uiBatcher = uiScreenBatcher;

		/* NEW STAGE */
		var loadStage = Luxe.resources.load_json( stageSrc );
		loadStage.then(function(jsonRes : JSONResource) {
			var json : StageFormat = jsonRes.asset.json;
			stage = new Stage(json);
			Luxe.renderer.clear_color = stage.background; //Palette.Colors[0]; //hack
			Description.uiBatcher = uiScreenBatcher;
			Description.player = player;
		});
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
			if ( joystick.isDown() ) {
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
			if (isArrowVisible()) { 
				drawArrow();
				if (Math.abs( Main.pullDelta ) > 60) {
					trace("pull!");
					trace(text);
				}
			}
		}
	}

	function isArrowVisible() {
		return ( Math.abs(player.pos.x - vex.pos.x) < 300 ); //todo should reall be "is it on screen?"
	}

	function drawArrow() {
		//draw pull tab
		var bounds = vex.boundsWorld();
		var topY = bounds[0].y;
		var midX = bounds[0].x + ((bounds[1].x - bounds[0].x)/2);

		var anchorPoint = new Vector(midX,topY);
		anchorPoint = Luxe.camera.world_point_to_screen( anchorPoint );
		anchorPoint.y -= 30;
		if (!isEditorMode) {
			anchorPoint.y += Math.abs( Main.pullDelta );
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