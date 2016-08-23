import luxe.Vector;
import luxe.resource.Resource.JSONResource;
import luxe.utils.Maths;
import luxe.Input;
import luxe.tween.Actuate;
import luxe.Visual;
import luxe.Color;

import vexlib.Vex;
import vexlib.Palette;
import vexlib.VexPropertyInterface;

/*
	NEXT
	X y axis resistance
	X y axis coasting
	X revisit max coasting speed
	- extendable ground
	- revisit walking animation speed range
	TRY THIS
	X slow zoom out on idle (fast zoom in)
	X y axis camera floating into position when moving uphill/downhill [tried this but I don't like it yet]
	X max swiping speed
		- build into joystick??
	BUGS
	- flashing avatar at start of swipe action (what's the cause?)

	THIS WEEK
	X player movement animation
		X idle
		X edges
			- the speed control of this could be tweaked
			- I could take another go at the "sudden stop" version of this
		X boredom
			 - add variations in timing and animations later
		X hello [this animation can be improved later - also the input needs help]
		- particles? [save this for later]
	- swipe control polish
		- test variation in release speed max?
		X get rid of reliance on actuate for coasting
		X resistance on edges (both x and y axes)
		X test a universal maximum movement speed for player?
		X deadzone in center so player doesn't move at the slightest flick
		X keep x and y axis movement separate (can't do both) (should this be in joystick or not?)
		X stop instananeous speed from being so herky jerky
		X use timers? to keep from switching back and forth all the time
	- universal joystick refactoring
		X re-remove coasting from joystick (maybe?)
		X how to handle keyboard control speed at different screensizes?
		- how to handle multiple interacting input types?
		X events
		- distinguish between input types
	X screen size / camera standardization
		X how should screen resizing behave?
		X where should player be relative to the camera?
		- SOLUTION to bad screen sizes: extendable ground padding that grows to accomodate screensize
		- explore possible downsides of anchoring to bottom (zooming)
		- can we constrain the window size?
		- are there any acceptable solutons for centering the camera on the "iphone screen"? (letterboxing? special "floor geometry")
	FOUND TODOS + BUGS
	- animation queue? (this sort of works now but could be _much_ more robust / better designed)
	- fix the fact that maxScrollSpeed does not constrain scroll speed while touch is down
	- stateful player redesign
	- EDITOR: hard to delete animation keyframes
	- flicker when switching from between animations (hello, stop)

	TODO
	- additional animations for main character
		X idle animation
		- kick foot (boredom)
		- sudden stop / hit wall
	- particle effects for walking
		- todo: add typedef for options, particle system?, 
	X universal input manager
		- polish input manager
		- handle multiple input types at once
		- register type of input
		- isReverse movement?
		- remove coasting from input manager?
		- should keyboard controls be screen width independent?
	- polish swipe controls (bounciness, up/down axis)
	X weird double bounce on edges
	- more animation stuff
		- blending
		- composite-ing of multiple animations at once
	- TODOs consolidate into one file?

	TODO
	- quickly establish standard screen size
	- BUG loading ref objects has a race condition?
	- make this code not ugly anymore
	X BUG jittery movement bug again (check out the head)
	X walk animation needs to respond to player control
	- parallax
	X mushroom animations
	X pull up / down
	- input manager (THIS THIS THIS)
		- inputs: mouse, touch, keyboard, joystick
		- output: single vector X, Y
	- figure out a more reliable way to load assets
	- get rid of extraneous traces
*/

class Settings {
	public static var IDEAL_SCREEN_SIZE_W : Float = 800;
	public static var IDEAL_SCREEN_SIZE_H : Float = 450;

	public static function IdealScreenSize() : Vector {
		return new Vector(IDEAL_SCREEN_SIZE_W, IDEAL_SCREEN_SIZE_H);
	}

	public static function StandardScreenSize() : Vector {
		/*
		var realScreenSize = Luxe.screen.size;
		var standardizedScreenSize = new Vector(0,0);

		if (realScreenSize.x > realScreenSize.y) {
			standardizedScreenSize.y = IDEAL_SCREEN_SIZE_H;
			var ratio = IDEAL_SCREEN_SIZE_H / realScreenSize.y;
			standardizedScreenSize.x = realScreenSize.x * ratio;
		}
		else {
			standardizedScreenSize.x = IDEAL_SCREEN_SIZE_W;
			var ratio = IDEAL_SCREEN_SIZE_W / realScreenSize.x;
			standardizedScreenSize.y = realScreenSize.y * ratio;
		}

		return standardizedScreenSize;
		*/
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
	public var paletteSrc = "assets/testpal.vex";

	/* PLAYER */
	public var playerSrc = "assets/girl.vex";
	public var player : Vex;
	public var playerProps = {
		stagePos : 300.0,
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
	public var stageSrc = "assets/playgroundstage.vex";
	public var set : Vex;
	public var path : Array<Vector>;

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
	var cameraTopOffset = 0.0;
	var cameraMaxYDist = Settings.IDEAL_SCREEN_SIZE_H * 0.25;
	var curCamCenterY = 0.0;
	var idleZoom = 1.0;
	var idleZoomTimeCounter = 0.0;

	/* PULL UP DOWN */
	// TODO spend more time tuning this feature
	var pullVelocity = 0.0;
	var pullDelta = 0.0;
	var pullMaxDistance = Settings.IDEAL_SCREEN_SIZE_H / 3;
	var pullZoomDelta = 0.10; // is this even having an impact?
	var pullFrictionConstant = 4.0;
	var pullFrictionForce = 0.0;
	var pullFriction = 0.0;
	var pullDeltaMax = 0.0; //track how far up or down we went in a single pull

	var shouldAnchorToBottom = true;

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

		//some weird mathy-ness
		var topLeft = Luxe.camera.screen_point_to_world( new Vector(0,0) );
		var bottomRight = Luxe.camera.screen_point_to_world( Luxe.screen.size );
		var width = bottomRight.x - topLeft.x;
		var height = bottomRight.y - topLeft.y;
		var leftoverHeight = height - 450;
		cameraTopOffset = leftoverHeight/2; //assumes no zooming

		/* PALETTE */
		Palette.StartBlank(); //rename
		var loadPalette = Luxe.resources.load_json( paletteSrc );
		loadPalette.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			Palette.Load(json);
			Palette.Swap("test");
		});

		/* PLAYER */
		var loadPlayer = Luxe.resources.load_json( playerSrc );
		loadPlayer.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			player = new Vex(json);
			player.properties.scale = new Vector(0.3,0.3);
			//player.scale = new Vector(0.3,0.3,1);
			
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
				set.depth = 0; //TODO this is likely broken...
			});
		});
	}

	function on_joystick_pressed( axis:Vector ) {
		trace("PRESSED");
		playerProps.velocity.x = Math.min(maxScrollSpeed, axis.x * Settings.IDEAL_SCREEN_SIZE_W);
		pullVelocity = axis.y * Settings.IDEAL_SCREEN_SIZE_H;

		pullDeltaMax = 0;

		idleZoomTimeCounter = 0;
	}

	var testCoastingTimer = 0.0;
	function on_joystick_released( axis:Vector ) {
		trace("RELEASED");

		//x
		playerProps.velocity.x = Math.min(maxScrollSpeed, axis.x * Settings.IDEAL_SCREEN_SIZE_W);
		coastingFrictionForce = playerProps.velocity.x * coastingFrictionConstant;
		coastingFrictionAcceleration = 0;
		coastingFriction = 0;
		testCoastingTimer = 0.0;

		//y
		pullVelocity = axis.y * Settings.IDEAL_SCREEN_SIZE_H;
		pullFrictionForce = pullVelocity * pullFrictionConstant;
		pullFriction = 0;
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

		trace(e.pos);

		//removed because it causes flashing on mobile (too much animation interruption)
		//TODO this could be fixed 
		/*
		//on sudden stops add an animation
		//TODO this doesn't seem to add much -- possible remove or modify in some way?
		//TODO her leg gets stuck in its "walk" position - how come?
		if (Math.abs(playerProps.velocity.x) > 200) { //arbitrary speed for now
			trace("play blocked anim!");

			//boilerplate to stop animation
			player.stopAnimation();
			var oldFacingScaleX = player.scale.x;
			player.resetToBasePose(); //this might overwrite things too often
			player.scale.x = oldFacingScaleX; //hack

			player.playAnimation("stop", 0.5);
		}
		*/

	}

	override function onmouseup(e:MouseEvent) {
	}

	function on_pull_complete() {

		trace("PULL COMPLETE");

		if (pullDeltaMax / pullMaxDistance > 0.5) {
			//boilerplate to stop animation
			player.stopAnimation();
			var oldFacingScaleX = player.scale.x;
			player.resetToBasePose(); //this might overwrite things too often
			player.scale.x = oldFacingScaleX; //hack
			playerProps.isWaiting = false; //yet another hack - this time to tell waiting anim it needs to resume (I really need to state-ify this code)

			player.playAnimation("hello", 1.5);

		}

		pullDeltaMax = 0;
	}

	override function update(dt:Float) {

		//some weird mathy-ness
		var topLeft = Luxe.camera.screen_point_to_world( new Vector(0,0) );
		var bottomRight = Luxe.camera.screen_point_to_world( Luxe.screen.size );
		var width = bottomRight.x - topLeft.x;
		var height = bottomRight.y - topLeft.y;
		var leftOverWidth = width - 800;
		var leftoverHeight = height - 450;

		/*
		//test for screen size
		Luxe.draw.rectangle({
				x: topLeft.x + (leftOverWidth/2) + 1,
				y: bottomRight.y - 450 + 1,
				w: 800 - 1,
				h: 450 - 1,
				immediate: true,
				depth: 500
			});
		*/

		/*
		Luxe.draw.rectangle({
				x: topLeft.x + (leftOverWidth/2) + 1,
				y: topLeft.y + (leftoverHeight/2) + 1,
				w: 800 - 1,
				h: 450 - 1,
				immediate: true,
				depth: 500
			});
		*/

		/*
		//camera y
		Luxe.draw.circle({
				x: Luxe.camera.center.x,
				y: Luxe.camera.center.y,
				r: 20,
				immediate: true,
				depth: 500
			});
		*/

		if (player != null && path != null) { //eventually need a smarter way to handle this
		
			/* PULL UP & DOWN */
			if ( joystick.yAxisHeld() ) {
				pullVelocity = joystick.axis.y * Settings.IDEAL_SCREEN_SIZE_H;
			}
			else if ( Math.abs(pullVelocity) > 0 )  {
				//todo coasting
				pullFriction += pullFrictionForce * dt;
				pullVelocity -= pullFriction * dt;

				var hasSignSwitched = (pullVelocity < 0) != (pullFrictionForce < 0);
				if ( hasSignSwitched ) {
					pullVelocity = 0;
					pullFriction = 0;
					pullFrictionForce = 0;
				}
			}

			if ( Math.abs(pullVelocity) > 0 ) {
				var pullResistance = Math.pow( 1 - (Math.abs(pullDelta) / pullMaxDistance), 3 );
				pullDelta += pullVelocity * pullResistance * dt;
				pullDelta = Maths.clamp(pullDelta, -pullMaxDistance, pullMaxDistance);

				if (Math.abs(pullDelta) > pullDeltaMax) pullDeltaMax = Math.abs(pullDelta);
			}
			else {
				if (Math.abs(pullDelta) > 0) {
					pullDelta *= 0.8;
					if (Math.abs(pullDelta) < 5) {
						pullDelta = 0;
						on_pull_complete();
					}
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
				var walkAnimSpeed = 0.5 + ( 1.5 * maxPlayerSpeedPercent );
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
			//playerProps.velocity.x = joystick.axis.x * Luxe.screen.width;

			if ( joystick.isDown() ) {
				playerProps.velocity.x = Math.min(maxScrollSpeed, joystick.axis.x * Settings.IDEAL_SCREEN_SIZE_W);
			}
			else if ( Math.abs(playerProps.velocity.x) > 0 ) {
				//coasting
				//trace(coastingFriction);
				testCoastingTimer += dt;
				//coastingFrictionAcceleration += coastingFrictionForce * dt;
				//coastingFriction += coastingFrictionAcceleration * dt;
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

				/*
				playerProps.velocity.x -= (playerProps.velocity.x * 5.0 * dt);
				testCoastingTimer += dt;
				if ( Math.abs(playerProps.velocity.x) < 10 ) {
					playerProps.velocity.x = 0;
					trace("COASTING TOTAL TIME " + testCoastingTimer);
					testCoastingTimer = 0;
				}
				*/
				//TODO "3.0" and "10" need to be made into variables
			}
			playerProps.stagePos += playerProps.velocity.x * dt;

			//keep player in bounds
			playerProps.blocked.left = (playerProps.stagePos <= 0);
			playerProps.blocked.right = (playerProps.stagePos >= pathLength(path));
			//update world pos
			playerProps.stagePos = Maths.clamp(playerProps.stagePos, 0, pathLength(path));
			player.pos = worldPosFromPathPos(path, playerProps.stagePos);
			//temp hack
			player.pos.y += 25; //keep feet in ground until I have a path editor for levels

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
			var zoomAdjustedCameraTopOffset = cameraTopOffset / Luxe.camera.zoom;
			var yOffsetToPutPlayerCloserToScreenBottom = Settings.IDEAL_SCREEN_SIZE_H * 0.25; //75; //TODO rename this?
			var totalYOffset = - ( (shouldAnchorToBottom) ? zoomAdjustedCameraTopOffset : 0 ) - yOffsetToPutPlayerCloserToScreenBottom;
			curCamCenterY = Maths.clamp( curCamCenterY, player.pos.y + totalYOffset - cameraMaxYDist, player.pos.y + totalYOffset + cameraMaxYDist );
			var camCenterYGoal = player.pos.y + totalYOffset;
			var camCenterYDist = camCenterYGoal - curCamCenterY;
			//curCamCenterY += camCenterYDist * 0.8 * dt; //float towards correct y pos [this didn't work how I wanted]
			curCamCenterY = camCenterYGoal;
			Luxe.camera.center.y = curCamCenterY + (pullDelta * 0.5); //what's the 0.5 for? I forgot

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
			Luxe.camera.zoom = 1 - (pullZoomDelta * (pullDelta / pullMaxDistance));
			Luxe.camera.zoom *= idleZoom;
		}
	}

	override function onwindowresized(e:luxe.Screen.WindowEvent) {
		trace(Luxe.screen.size);
		trace("!!");

		trace(e);
		trace(Luxe.camera.size);
		trace(Luxe.camera.viewport);

		//some weird mathy-ness
		var topLeft = Luxe.camera.screen_point_to_world( new Vector(0,0) );
		var bottomRight = Luxe.camera.screen_point_to_world( Luxe.screen.size );
		var width = bottomRight.x - topLeft.x;
		var height = bottomRight.y - topLeft.y;
		var leftoverHeight = height - 450;
		cameraTopOffset = (leftoverHeight/2); //doesn't account for zooming

		trace(height);
		trace(cameraTopOffset);

		//Luxe.camera.view.scale = new Vector(1,1);

		/*
		Luxe.camera.viewport.w = Luxe.screen.w;
		Luxe.camera.viewport.h = Luxe.screen.h;
		Luxe.camera.viewport.x = 0;
		Luxe.camera.viewport.y = 0;
		*/
	}

	/* PLAYER */
	public function playerIsMovingBlockedDirection() : Bool {
		return (playerProps.blocked.left && playerProps.velocity.x <= 0) || (playerProps.blocked.right && playerProps.velocity.x >= 0);
	}

	/* CAMERA */
	/* crazy old terrain stuff */
	public function worldPosFromPathPos(path:Array<Vector>, pos : Float) : Vector {
		var segIndex = closestIndexToLeft(path, pos);

		//capture edge cases
		if (segIndex < 0) {
			return new Vector(path[0].x, path[0].y);
		}
		if (segIndex >= path.length-1) {
			return new Vector(path[path.length-1].x, path[path.length-1].y);
		}

		var leftoverDist = (pos - pathLengthToPoint(path, segIndex));
		var leftoverDistPercent = leftoverDist / xDistToNextPoint(path, segIndex);
		var seg0 = path[segIndex];
		var seg1 = path[segIndex+1];
		var segDelt = Vector.Subtract(seg1, seg0);
		var segDeltPercent = Vector.Multiply(segDelt, leftoverDistPercent);

		var worldPos = Vector.Add(seg0, segDeltPercent);

		//hack
		worldPos.add(new Vector(-0.746,-1262.069)); //hack specific to playground (need to adjust for space)

		return worldPos;
	}

	function pathLength(path:Array<Vector>) {
		return pathLengthToPoint(path, path.length-1);
	}

	function pathLengthToPoint(path : Array<Vector>, i : Int) : Float {
		var startX = path[0].x;
		return (path[i].x - startX);
	}

	function xDistToNextPoint(path:Array<Vector>, i : Int) : Float {
		return Math.abs(path[i].x - path[i+1].x);
	}

	//needs a better name
	//also: inefficient as fuck
	public function closestIndexToLeft(path:Array<Vector>, x : Float) : Int {
		var startX = path[0].x; //feels pretty hacky
		var closestIndex = 0;
		for (i in 1 ... path.length) {
			var dist = x - (path[i].x - startX);
			var prevDist = x - (path[closestIndex].x - startX);
			if ( dist > 0 && dist < prevDist ) {
				closestIndex = i;
			}
		}
		return closestIndex;
	}
	//////


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
typedef StageFormat = {
	@:optional public var type : Property;
	@:optional public var id : Property;
	@:optional public var set : Property;
	@:optional public var background : Property;
	@:optional public var path : Property;
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