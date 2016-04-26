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
	TODO:
	- BUG: left overs from action button after scene change
	- BUG: why is player so jittery???
	- BUG: where sometimes player never stops moving!!!
	- tune camera variables
	- add back slope resistance
	- pull up / down
	- get screen view constant stuff working
	- create camera control class that wraps camera stuffs
	- need shared lib / classes
	- need to share file IO stuff
	- need to create a shared "level" class that wraps some things
	- UPDATE LUXE STUFF (get up to date w/ community???)
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
	var widthInWorldPixels = 800.0;
	var widthToHeight : Float; //calculated
	var heightInWorldPixels : Float; //calculated (expected = 450px)
	var zoomForCorrectWidth : Float;

	override function ready() {
		instance = this;

		scrollInput = new ScrollInputHandler();

		player = new Avatar({
			size : new Vector(20, 60),
			color : new Color(1,0,0),
			depth : 100
		});
		player.pos = new Vector(0,0);

		widthToHeight = hRatio / wRatio;
		heightInWorldPixels = widthInWorldPixels * widthToHeight;
		zoomForCorrectWidth = Luxe.screen.width / widthInWorldPixels;

		var level2 = new Level({
			filename : "leveltest_whoa",
			onLevelInit : function() {
				trace("we did it!");
			}
		});

		//loadLevel('leveltest_buttonnames');
		curLevel = new Level({
				filename : "leveltest_buttonnames",
				onLevelInit : function() {
					trace("level ready!");
					curLevel.showLevel();
					player.curTerrain = curLevel.terrain;
					Luxe.camera.pos.x = curLevel.terrain.points[0].x; //kind of a hack (unecessary too?)

					//TODO attach behaviors to buttons, attach component to level possibly??
					cast(curLevel.levelScene.get("button_name_1"), ActionButton)
						.onCompleteCallback = function() {
							trace("button 1!!");
							//startDialogTest();
							enterDialog("helloworld");
						};
					cast(curLevel.levelScene.get("button_name_2"), ActionButton)
						.onCompleteCallback = function() {
							trace("button 2????");
							curLevel.hideLevel();
							curLevel = level2;
							curLevel.showLevel();
							player.curTerrain = curLevel.terrain;
							player.terrainPos = 10;
							//Luxe.camera.pos.x = curLevel.terrain.points[0].x;
						};


				}
			});

		/*
		//hack to auto open test file
			var path = "/Users/adamrossledoux/Code/Haxe/AdventurEd/assets/leveltest7";
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

			//rehydrate action buttons
			for (b in actionButtons) {
				b.clear();
			}
			actionButtons = [];
			for (b in cast(json.buttons, Array<Dynamic>)) {
				trace(b);
				var a = (new ActionButton()).fromJson(b);
				a.terrain = curTerrain;
				a.curSize = 0; //start invisible
				actionButtons.push(a);
			}

			Luxe.camera.pos.x = curTerrain.points[0].x;

			player.curTerrain = curTerrain;
		//hack to auto open test file
		*/
	} //ready

	function enterDialog(dialogFile:String) {
		Actuate.tween(Luxe.camera, 1.0, {zoom:1.5}).onComplete(function() {
				var load = Luxe.resources.load_json('assets/' + dialogFile);
				load.then(function(jsonRes : JSONResource) {
						var json = jsonRes.asset.json;
						var worldPos = Luxe.camera.screen_point_to_world(new Vector(100,100));
						trace(worldPos);
						curDialog = new Dialog({pos:worldPos,scale:new Vector(0.75,0.75)}).fromJson(json);
						curDialog.beginDialog();
						isDialogMode = curDialog.showNext();
						//trace(isDialogMode);
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
		player.changeVelocity(0); //just in case to stop weird always scrolling bug (is this really the problem?)
	}

	
	override function onmouseup(e:MouseEvent) {

		if (curLevel != null && !curLevel.anyButtonsTouched() && !isDialogMode) {

			if (Math.abs(scrollInput.releaseVelocity.x) > 0) {
				var scrollSpeed = Maths.clamp(scrollInput.releaseVelocity.x, -maxScrollSpeed, maxScrollSpeed);
				player.coast(scrollSpeed, 0.75); //on release, coast for 3/4 of a second
			}
			else {
				player.changeVelocity(0); //just in case to stop weird always scrolling bug (is this really the problem?)
			}

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
				player.changeVelocity(scrollInput.touchDelta.x / dt); //force velocity to match scrolling
			}
		
		}

		if (isDialogMode) {
			if (!curDialog.isAnimationInProgress) {
				//draw down arrow
				var arrowBottom = Luxe.camera.screen_point_to_world(Luxe.screen.mid);
				arrowBottom.y -= dialogPullDist;
				Luxe.draw.line({
						p0: arrowBottom,
						p1: new Vector(arrowBottom.x-15, arrowBottom.y-15),
						immediate: true
					});
				Luxe.draw.line({
						p0: arrowBottom,
						p1: new Vector(arrowBottom.x+15, arrowBottom.y-15),
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

					curDialog.scale.y = 0.75 + ( (dialogPullDist / -maxDownDist) * 0.3 );
					//curDialog.scale.x = 0.75 + ( (dialogPullDist / -50) * 0.3 );
				}
			}

			
		}

		cameraLogic(dt);

	} //update

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
