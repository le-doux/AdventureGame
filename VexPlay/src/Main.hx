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
	THIS WEEK
	- player movement animation
	- swipe control polish
	- universal joystick refactoring
	- screen size / camera standardization
	FOUND TODOS
	- animation queue? (this sort of works now but could be _much_ more robust / better designed)
	- fix the fact that maxScrollSpeed does not constrain scroll speed while touch is down

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

	/* STAGE */
	public var stageSrc = "assets/playgroundstage.vex";
	public var set : Vex;
	public var path : Array<Vector>;

	/* CAMERA */
	var cameraProps = {
		offsetX : 0.0,
		speedMult : 2.0,
		maxDistAheadOfPlayer : 200.0,
		edgeSpring : {
			maxDist : 200.0,
			springConstant : 50.0,
			velocityX : 0.0
		}
	};

	/* PULL UP DOWN */
	// TODO spend more time tuning this feature
	var pullDelta = 0.0;
	var pullMaxDistance : Float;
	var pullZoomDelta = 0.10; // is this even having an impact?

	override function ready() {

		Luxe.fixed_timestep = false;
		Luxe.fixed_frame_time = 0.5;

		/* INPUT */
		joystick = new UniversalJoystick();
		pullMaxDistance = Luxe.screen.height / 6;

		/* CAMERA */
		Luxe.camera.size = new Vector(800,450);
		Luxe.camera.center = new Vector(0,0);

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

			var loadPlayerAnim4 = Luxe.resources.load_json( "assets/kickfootanim1.vex" );
			loadPlayerAnim4.then(function(jsonRes : JSONResource) {
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

	override function onmousedown(e:MouseEvent) {

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

	}

	override function onmouseup(e:MouseEvent) {
	}

	override function update(dt:Float) {

		if (player != null && path != null) { //eventually need a smarter way to handle this
		
			/* PULL UP & DOWN */
			if ( joystick.yAxisHeld() ) {
				pullDelta += joystick.axis.y * Luxe.screen.h * dt;
				pullDelta = Maths.clamp(pullDelta, -pullMaxDistance, pullMaxDistance);
			}
			else {
				if (Math.abs(pullDelta) > 0) {
					pullDelta *= 0.8;
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

				waitCounter = 0;

				/*
				player.stopAnimation(); //not necessary yet (maybe later tho)
				var oldFacingScaleX = player.scale.x;
				player.resetToBasePose(); //this might overwrite things too often
				player.scale.x = oldFacingScaleX; //hack
				player.playAnimation("wait", 1.0).ease(luxe.tween.easing.Quad.easeInOut).reflect().repeat();
				*/
			}
			//walk animation
			if (absSpeed > 0 && !playerIsMovingBlockedDirection()) {
				trace("walk!");
				var maxPlayerSpeedPercent = absSpeed / joystick.maxScrollSpeed;
				var walkAnimSpeed = 0.5 + ( 1.5 * maxPlayerSpeedPercent );
				var nextWalkT = player.getAnimation("walk").t + ( walkAnimSpeed * dt );
				if (nextWalkT > 1.0) nextWalkT = 0; //there's a better smoother way to loop this than a hard cut off, but I'm too lazy
				player.getAnimation("walk").t = nextWalkT;				
			}

			if (playerProps.isWaiting) {
				waitCounter += dt;

				if (waitCounter > 10) {
					/*
					//boilerplate
					player.stopAnimation(); //not necessary yet (maybe later tho)
					var oldFacingScaleX = player.scale.x;
					player.resetToBasePose(); //this might overwrite things too often
					player.scale.x = oldFacingScaleX; //hack
					*/

					//TODO this kick animation isn't very good
					//HACK this animation takes advantage of accidentally being able to composite animations --- formalize this somehow?
					player.playAnimation("kick", 2.0).ease(luxe.tween.easing.Quad.easeInOut);

					//player.queueAnimation("wait", 1.0).ease(luxe.tween.easing.Quad.easeInOut).reflect().repeat();

					waitCounter = -2.0; //hack to delay counter start by 4 seconds
				}
			}

			//need to check if blocked to start blocked anim
			var prevBlocked = playerProps.blocked.left || playerProps.blocked.right;

			//connect input to player
			playerProps.velocity.x = joystick.axis.x * Luxe.screen.width;
			playerProps.stagePos += playerProps.velocity.x * dt;
			//keep player in bounds
			playerProps.blocked.left = (playerProps.stagePos <= 0);
			playerProps.blocked.right = (playerProps.stagePos >= pathLength(path));
			//update world pos
			playerProps.stagePos = Maths.clamp(playerProps.stagePos, 0, pathLength(path));
			player.pos = worldPosFromPathPos(path, playerProps.stagePos);

			//blocked stop animation
			var curBlocked = playerProps.blocked.left || playerProps.blocked.right;
			if (curBlocked && !prevBlocked) {
				trace("play blocked anim!");

				trace(absSpeed);

				if (absSpeed < 300) {
					//don't play animation
				}
				else {
					var maxPlayerSpeedPercent = absSpeed / joystick.maxScrollSpeed;
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
				var resistanceFactor = Math.max(0, 1 - Math.sqrt(distancePastEdge / cameraProps.edgeSpring.maxDist));
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
					joystick.stopCoasting(); //stop player from moving
				}
			}
			else {
				cameraProps.edgeSpring.velocityX = 0; //edge case protection
			}
			//keep camera attached to player
			var centerX = player.pos.x - 10 - (Luxe.screen.w/2);
			Luxe.camera.pos.x = centerX + cameraProps.offsetX;
			Luxe.camera.pos.y = player.pos.y - (Luxe.screen.height * 0.9) + (pullDelta * 0.5) + 150; //TODO *0.5 is a hack -- replace with proper percent to distance stuff
			//update camera zoom due to pull
			Luxe.camera.zoom = 1 - (pullZoomDelta * (pullDelta / pullMaxDistance));
		}
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