import adventurlib.*;

import luxe.Input;
import luxe.Color;
import luxe.Camera;
import luxe.Vector;
import luxe.Entity;
import luxe.utils.Maths;
import luxe.resource.Resource.JSONResource;
import luxe.tween.Actuate;

/*
//file IO
import sys.io.File;
import sys.io.FileOutput;
import sys.io.FileInput;
import haxe.Json;
*/

using adventurlib.ColorExtender;

/*
TODO DEMO:
- create more levels
	X- the street
	X- bagel entrance
	X- bagel back
	- old world house
	***
	- old world town
- create dialog
	- hello? is anyone there?
- specialized level logic
	- match in old world house
- polish
	X- player sometimes stops abruptly
	X- scale of player vs environment
	- player sprite?
	X- only switch button frame at 100%
	X- button 2nd frame always pause on pull
	- nicer pull on dialog (momentum?)
		X- easier to see
		X- other polish
		- easier to pull
X- pro / cons for different vector graphics approaches
	- SVG
	- build own editor & format
	- something else?
- consistent sizing between platforms
	X- camera resizing settings
	- make ground stick near ground?
*/


/*
TODO NEW:
- erase strokes (level, button, dialog)
*/


/*
	TODO:
	- tune camera variables
	- add back slope resistance
	- pull up / down
	- get screen view constant stuff working
	- create camera control class that wraps camera stuffs
	- need to share file IO stuff
*/

class Main extends luxe.Game {

	public static var instance : Main;

	/*
	//level
	var curTerrain : Terrain;
	var scenery : Array<Polystroke> = [];
	var actionButtons : Array<ActionButton> = [];
	*/
	var curLevel : Level;

	//input
	var scrollInput : ScrollInputHandler;
	var maxScrollSpeed = 1200;

	//player
	public var player : Avatar;

	//dialog
	var curDialog : Dialog;
	var dialogPullDist = 0.0;
	var isDialogMode = false;
	var dialogPullArrowBounce = 0.0;

	//camera
	var camera = {
		offsetX : 0.0,
		speedMult : 2.0,
		maxDistAheadOfPlayer : 200.0,
		edgeSpring : {
			maxDist : 200.0,
			springConstant : 50.0,
			velocityX : 0.0
		}
	};

	//screen ratio stuff
	var wRatio = 16.0;
	var hRatio = 9.0;
	var widthInWorldPixels = 1200.0; //looks good for proto but inconsistent!!
	var widthToHeight : Float; //calculated
	var heightInWorldPixels : Float; //calculated (expected = 450px)
	var zoomForCorrectWidth : Float;

	override function ready() {
		instance = this;

		scrollInput = new ScrollInputHandler();

		player = new Avatar({
			size : new Vector(40, 100),
			color : new Color(0,0,0),
			depth : 100
		});
		player.pos = new Vector(0,0);

		widthToHeight = hRatio / wRatio;
		heightInWorldPixels = widthInWorldPixels * widthToHeight;
		zoomForCorrectWidth = Luxe.screen.width / widthInWorldPixels;

		Luxe.camera.size = new Vector(widthInWorldPixels,heightInWorldPixels);
		Luxe.camera.size_mode = luxe.SizeMode.fit;


		//
		var level1 : Level = null;
		var level2 : Level = null;
		level1 = new Level({
				filename: "1_theOtherKidsFled",
				onLevelInit : function() {

					cast(level1.levelScene.get("button_openDoorCautiously"), ActionButton)
						.onCompleteCallback = function() {
							curLevel.hideLevel();
							curLevel = level2;
							curLevel.showLevel();
							player.curTerrain = curLevel.terrain;
							player.terrainPos = curLevel.terrain.length - 100;
						}

					curLevel = level1;
					curLevel.showLevel();
					player.curTerrain = curLevel.terrain;
					player.terrainPos = 150;
					Luxe.camera.pos.x = curLevel.terrain.points[0].x;
					
				}
			});

		level2 = new Level({
				filename: "2_mahjongApt",
				onLevelInit : function() {

					var ladyDialogButton = cast(level2.levelScene.get("button_comeCloser"), ActionButton);

					ladyDialogButton.onCompleteCallback = function() {
							var focusPos = Vector.Add(ladyDialogButton.pos, new Vector(100,100));
							enterDialog("dialog_ladies", focusPos);
						};

				}
			});


		//Probably a stupid hack
		Actuate.tween(this, 0.6, {dialogPullArrowBounce:10}).repeat().reflect();
	} //ready

	function enterDialog(dialogFile:String, focusPos:Vector) {
		Actuate.tween(Luxe.camera, 1.0, {zoom:1.5});
		var load = Luxe.resources.load_json('assets/' + dialogFile);
		load.then(function(jsonRes : JSONResource) {
				Actuate.tween(Luxe.camera.pos, 1.0, {x:focusPos.x - Luxe.screen.w/2, y:focusPos.y - Luxe.screen.h/2})
					.onComplete(function() {
						var json = jsonRes.asset.json;
						var worldPos = Luxe.camera.screen_point_to_world(new Vector(100,150));
						trace(worldPos);
						curDialog = new Dialog({
							pos: worldPos,
							dialogWidth: widthInWorldPixels-250,
							wordHeight: 65,
							scale: new Vector(0.66,0.66)
						}).fromJson(json);

						curDialog.beginDialog();
						isDialogMode = curDialog.showNext();
					});
			});
	}

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function onwindowresized(e) { //TODO: this shit is broke
		/*
		trace(e);
		//trace(Luxe.screen.width);
		//trace(Luxe.camera.viewport.w);
		zoomForCorrectWidth = Luxe.screen.width / widthInWorldPixels;
		//Luxe.camera.zoom = zoomForCorrectWidth;
		
		var newW = Luxe.screen.w;
		var newH = Luxe.screen.w * widthToHeight;
		Luxe.camera.viewport.w = newW;
		Luxe.camera.viewport.h = Luxe.screen.h;

		var playerH = 0.0;
		if (curTerrain != null) {
			playerH = curTerrain.points[0].y;
		}
		var heightAbovePlayer = newH * 0.66;
		//Luxe.camera.pos.y = newH;
		//Luxe.camera.pos.y = -(Luxe.screen.h) + newH;
		trace(Luxe.camera.pos.y);
		*/
	}


	override function onkeydown( e:KeyEvent ) {

		//open file [THIS NEEDS TO BE SHARED]
		/*
		if (e.keycode == Key.key_o && e.mod.meta ) {
			var path = Luxe.core.app.io.module.dialog_open();
			var fileStr = File.getContent(path);
			var json = Json.parse(fileStr);

			//rehydrate colors
			var backgroundColor = (new Color()).fromJson(json.backgroundColor);
			var terrainColor = (new Color()).fromJson(json.terrainColor);
			var sceneryColor = (new Color()).fromJson(json.sceneryColor);
			Luxe.renderer.clear_color = backgroundColor;

			//rehydrate terrain
			if (curTerrain != null) curTerrain.clear();
			curTerrain = new Terrain();
			curTerrain.fromJson(json.terrain);
			curTerrain.draw(terrainColor);

			//rehydrate scenery
			for (s in scenery) {
				s.destroy();
			}
			scenery = [];
			for (s in cast(json.scenery, Array<Dynamic>)) {
				var p = new Polystroke({color : sceneryColor, batcher : Luxe.renderer.batcher}, []);
				p.fromJson(s);
				scenery.push(p); //feels hacky
			}

			Luxe.camera.pos.x = curTerrain.points[0].x;

			player.curTerrain = curTerrain;
		}
		*/

		/*
		if (isDialogMode && e.keycode == Key.down) {
			isDialogMode = curDialog.showNext();
		}
		*/
	}

	override function onmousedown(e:MouseEvent) {
		//TODO: fix sudden stop bug
		//player.changeVelocity(0); //just in case to stop weird always scrolling bug (is this really the problem?)
	}

	
	override function onmouseup(e:MouseEvent) {

		if (curLevel != null && !curLevel.anyButtonsTouched() && !isDialogMode) {

			//if (Math.abs(scrollInput.releaseVelocity.x) > 0) {
				var scrollSpeed = Maths.clamp(scrollInput.releaseVelocity.x, -maxScrollSpeed, maxScrollSpeed);
				player.coast(scrollSpeed, 0.75); //on release, coast for 3/4 of a second
			//}
			//else {
				//TODO: fix sudden stop bug
				//player.changeVelocity(0); //just in case to stop weird always scrolling bug (is this really the problem?)
			//}

		}

		if (isDialogMode) {
			if (!curDialog.isAnimationInProgress) {
				dialogPullDist = 0;
			}
		}

	}

	override function update(dt:Float) {

		if (curLevel != null && !curLevel.anyButtonsTouched() && !isDialogMode) {
		
			//connect input to player
			if (Luxe.input.mousedown(1)) {
				//trace("scroll velocity!");
				player.changeVelocity(scrollInput.touchDelta.x / dt); //force velocity to match scrolling
			}
		
		}

		if (isDialogMode) {
			dialogLogic();
		}

		if (!isDialogMode) cameraLogic(dt);

		/*
		//draw screen box
		Luxe.draw.rectangle({
			x : ((Luxe.screen.width - (widthInWorldPixels/Luxe.camera.zoom) ) / 2) + Luxe.camera.pos.x,
			y : ((Luxe.screen.height - (heightInWorldPixels/Luxe.camera.zoom) ) / 2) + Luxe.camera.pos.y,
			w : widthInWorldPixels/Luxe.camera.zoom,
			h : heightInWorldPixels/Luxe.camera.zoom,
			immediate : true
		});
		*/

	} //update

	function dialogLogic() {
		if (!curDialog.isAnimationInProgress) {
			//draw down arrow
			var s = 1.0;
			if (Luxe.input.mousedown(1)) s = 2.0;
			var arrowPos = Luxe.camera.screen_point_to_world(Luxe.screen.mid);
			arrowPos.y -= dialogPullDist;

			if (!Luxe.input.mousedown(1)) {
				arrowPos.y += dialogPullArrowBounce;
			}

			Luxe.draw.poly({
					solid: true,
					pos: arrowPos,
					points: [
						new Vector(0,8),
						new Vector(-16, -8),
						new Vector(16, -8)
					],
					color: new Color(0,0,0),
					depth: 200,
					scale: new Vector(s,s),
					immediate: true
				});

			//down arrow logic
			var maxDownDist = 100;
			if (Luxe.input.mousedown(1)) {
				dialogPullDist += scrollInput.touchDelta.y;
				if (dialogPullDist > 0) dialogPullDist = 0;

				if (dialogPullDist < -maxDownDist) {
					dialogPullDist = 0;
					isDialogMode = curDialog.showNext();
					if (!isDialogMode) {
						Actuate.tween(Luxe.camera, 0.5, {zoom:1.0});
					}
				}

				var s = 0.75 + ( (dialogPullDist / -maxDownDist) * 0.3 );
				curDialog.scale.y = s;
				//curDialog.scale.x = 0.75 + ( (dialogPullDist / -50) * 0.3 );
			}
		}
	}

	function cameraLogic(dt : Float) {
		//CAMERA LOGIC
		//calc camera distance this frame
		//var directionOfMovement = player.velocity.x / Math.abs(player.velocity.x);
		var cameraDistance = player.velocity.x * camera.speedMult * dt;

		//find bounds of normal camera movement
		var leftDistMax = Math.min(0, -camera.maxDistAheadOfPlayer - camera.offsetX);
		var rightDistMax = Math.max(0, camera.maxDistAheadOfPlayer - camera.offsetX);
		var cameraDistanceInBounds = Maths.clamp(cameraDistance, leftDistMax, rightDistMax);
		var cameraDistancePastBounds = cameraDistance - cameraDistanceInBounds;

		//update camera base offset
		camera.offsetX += cameraDistanceInBounds;

		//move camera past the edge if the player is blocked
		if (player.movingBlockedDirection() && Math.abs(cameraDistancePastBounds) > 0) {
			var distancePastEdge = Math.max(0, Math.abs(camera.offsetX) - camera.maxDistAheadOfPlayer);
			//var resistanceFactor = Math.max(0, 1 - Math.pow(distancePastEdge / camera.edgeSpring.maxDist, 2));
			//var resistanceFactor = 1 - (distancePastEdge / camera.edgeSpring.maxDist);
			var resistanceFactor = Math.max(0, 1 - Math.sqrt(distancePastEdge / camera.edgeSpring.maxDist));
			cameraDistancePastBounds *= resistanceFactor;
			
			camera.offsetX += cameraDistancePastBounds;
			var maxTotalOffset = camera.maxDistAheadOfPlayer + camera.edgeSpring.maxDist;
			camera.offsetX = Maths.clamp(camera.offsetX, -maxTotalOffset, maxTotalOffset);
		}

		//use spring to keep camera in its proper bounds
		if (!Luxe.input.mousedown(1) && Math.abs(camera.offsetX) > camera.maxDistAheadOfPlayer) {
			var dir = camera.offsetX > 0 ? 1 : -1;
			var dif = Math.abs(camera.offsetX) - camera.maxDistAheadOfPlayer;
			var springForce = dif * camera.edgeSpring.springConstant;

			camera.edgeSpring.velocityX += -dir * springForce * dt;
			camera.offsetX += camera.edgeSpring.velocityX * dt;

			//stop using spring when it brings you back from the edge
			if (Math.abs(camera.offsetX) < camera.maxDistAheadOfPlayer) {
				camera.offsetX = dir * camera.maxDistAheadOfPlayer; //put camera at resting place
				camera.edgeSpring.velocityX = 0; //stop sprint motion
				player.changeVelocity(0); //stop player from moving
			}
		}
		else {
			camera.edgeSpring.velocityX = 0; //edge case protection
		}

		//keep camera attached to player
		var centerX = player.pos.x - 10 - (Luxe.screen.w/2);
		Luxe.camera.pos.x = centerX + camera.offsetX;
		Luxe.camera.pos.y = (player.pos.y + 60) - (Luxe.screen.height * 0.66);
	}


} //Main
