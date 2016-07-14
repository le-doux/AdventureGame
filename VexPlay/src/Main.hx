import luxe.Vector;
import luxe.resource.Resource.JSONResource;
import luxe.utils.Maths;
import luxe.Input;
import luxe.tween.Actuate;

import vexlib.Vex;
import vexlib.Palette;
import vexlib.VexPropertyInterface;

/*
	TODO
	- quickly establish standard screen size
	- BUG loading ref objects has a race condition?
	- make this code not ugly anymore
	- jittery movement bug again?
	- walk animation needs to respond to player control
*/

class Main extends luxe.Game {
	/* PALETTE */
	public var paletteSrc = "assets/defaultpal.vex";

	/* PLAYER */
	var scrollInput : ScrollInputHandler;
	var maxScrollSpeed = 1200;
	public var playerSrc = "assets/guy.vex";
	public var player : Vex;
	public var playerProps = {
		stagePos : 300.0,
		velocity : new Vector(0,0),
		blocked : {
			left : false,
			right : false
		},
		isCoasting : false
	};

	/* STAGE */
	public var stageSrc = "assets/shroomstage.vex";
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

	override function ready() {
		scrollInput = new ScrollInputHandler();

		Luxe.camera.size = new Vector(800,450);
		Luxe.camera.center = new Vector(0,0);

		Palette.StartBlank();

		var loadPalette = Luxe.resources.load_json( paletteSrc );
		loadPalette.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			Palette.Load(json);
			Palette.Swap("default");
		});

		var loadPlayer = Luxe.resources.load_json( playerSrc );
		loadPlayer.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			player = new Vex(json);
			player.scale = new Vector(0.3,0.3);
			player.depth = 1;
		});
		var loadPlayerAnim = Luxe.resources.load_json( "assets/guy_walk.vex" );
		loadPlayerAnim.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			player.addAnimation(json);
			player.playAnimation("walk", 2.0).repeat();
		});

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
				set.depth = 0;
			});
		});
	}

	override function onmouseup(e:MouseEvent) {
		var scrollSpeed = Maths.clamp(scrollInput.releaseVelocity.x, -maxScrollSpeed, maxScrollSpeed);
		playerCoast(scrollSpeed, 0.75);
	}

	override function update(dt:Float) {
		if (player != null && path != null) { //eventually need a smarter way to handle this
			/* PLAYER */
			//keep player facing the right direction
			if (playerProps.velocity.x > 0 && player.scale.x < 0) player.scale.x *= -1;
			if (playerProps.velocity.x < 0 && player.scale.x > 0) player.scale.x *= -1;
			//connect input to player
			if (Luxe.input.mousedown(1)) playerChangeVelocity(scrollInput.touchDelta.x / dt); //force velocity to match scrolling
			//update terrain pos
			playerProps.stagePos += playerProps.velocity.x * dt;
			//keep player in bounds
			playerProps.blocked.left = playerProps.stagePos <= 0;
			playerProps.blocked.right = playerProps.stagePos >= pathLength(path);
			playerProps.stagePos = Maths.clamp(playerProps.stagePos, 0, pathLength(path));
			//update world pos
			playerProps.stagePos = Maths.clamp(playerProps.stagePos, 0, pathLength(path));
			player.pos = worldPosFromPathPos(path, playerProps.stagePos);

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
			if (!Luxe.input.mousedown(1) && Math.abs(cameraProps.offsetX) > cameraProps.maxDistAheadOfPlayer) {
				var dir = cameraProps.offsetX > 0 ? 1 : -1;
				var dif = Math.abs(cameraProps.offsetX) - cameraProps.maxDistAheadOfPlayer;
				var springForce = dif * cameraProps.edgeSpring.springConstant;
				cameraProps.edgeSpring.velocityX += -dir * springForce * dt;
				cameraProps.offsetX += cameraProps.edgeSpring.velocityX * dt;
				//stop using spring when it brings you back from the edge
				if (Math.abs(cameraProps.offsetX) < cameraProps.maxDistAheadOfPlayer) {
					cameraProps.offsetX = dir * cameraProps.maxDistAheadOfPlayer; //put camera at resting place
					cameraProps.edgeSpring.velocityX = 0; //stop sprint motion
					playerChangeVelocity(0); //stop player from moving
				}
			}
			else {
				cameraProps.edgeSpring.velocityX = 0; //edge case protection
			}
			//keep camera attached to player
			var centerX = player.pos.x - 10 - (Luxe.screen.w/2);
			Luxe.camera.pos.x = centerX + cameraProps.offsetX;
			Luxe.camera.pos.y = player.pos.y - (Luxe.screen.height * 0.9);
		}
	}

	/* PLAYER */
	public function playerCoast(velocityX : Float, time : Float) {
		//trace("start coasting!");
		playerProps.velocity.x = velocityX;
		playerProps.isCoasting = true;
		Actuate.tween(playerProps.velocity, time, {x: 0}).ease(luxe.tween.easing.Quad.easeOut)
			.onComplete(function() { 
							playerProps.velocity.x = 0;
							playerProps.isCoasting = false; 
						});
	}

	//replace with velocity setter?
	public function playerChangeVelocity(velocityX) {
		if (playerProps.isCoasting) {
			playerProps.isCoasting = false;
			Actuate.stop(playerProps.velocity); //stop "animating" the velocity
		}
		playerProps.velocity.x = velocityX;
	}

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

		return Vector.Add(seg0, segDeltPercent);
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
}

/* STAGE */
typedef StageFormat = {
	@:optional public var type : Property;
	@:optional public var id : Property;
	@:optional public var set : Property;
	@:optional public var background : Property;
	@:optional public var path : Property;
}