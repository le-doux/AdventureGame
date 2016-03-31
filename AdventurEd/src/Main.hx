import adventurlib.*;

import luxe.Input;
import luxe.Color;
import luxe.Vector;

import sys.io.File;
import sys.io.FileOutput;
import sys.io.FileInput;

import haxe.Json;

using TerrainEditor;
using adventurlib.ColorExtender;
using adventurlib.PolylineExtender;

/* TODO
	- circle brush editor
*/

class Main extends luxe.Game {

	var terrainColor : Color;
	var backgroundColor : Color;
	var sceneryColor : Color;

	var curTerrain : Terrain;

	var mode = 0;
	/*
	 0 = terrain
	 1 = scenery
	 2 = action buttons
	*/

	var zoomIncrement = 0.2;
	var panIncrement = 20;

	var prevCursorPos = null;

	var tmpStroke : Array<Vector> = [];
	var scenery : Array<Polystroke> = [];

	var actionButtons : Array<ActionButton> = [];
	var curButton : ActionButton;

	//screen ratio stuff
	var wRatio = 16.0;
	var hRatio = 9.0;
	var widthInWorldPixels = 800.0;
	var widthToHeight : Float; //calculated
	var heightInWorldPixels : Float; //calculated

	override function ready() {
		widthToHeight = hRatio / wRatio;
		heightInWorldPixels = widthInWorldPixels * widthToHeight;
		trace(widthInWorldPixels + " x " + heightInWorldPixels);

		terrainColor = new Color(1,1,1);
		sceneryColor = new Color(1,0,0);
		backgroundColor = new Color(0,0,0);
		Luxe.renderer.clear_color = backgroundColor;

		curTerrain = new Terrain();
		curTerrain.draw(terrainColor);
	} //ready

	override function onkeydown( e:KeyEvent ) {

		//hack
		if (e.keycode == Key.key_1) mode = 0; //terrain
		if (e.keycode == Key.key_2) mode = 1; //scenery
		if (e.keycode == Key.key_3 && actionButtons.length > 0) mode = 2; //action button (might have to add more here)

		//open file
		if (e.keycode == Key.key_o && e.mod.meta ) {
			var path = Luxe.core.app.io.module.dialog_open();
			var fileStr = File.getContent(path);
			var json = Json.parse(fileStr);

			if (json.type == "level") { 
				openLevel(json); //need level class, need to abstract this shit
			}
			else if (json.type == "action") {
				curButton = (new ActionButton({})).fromJson(json);
				curButton.terrain = curTerrain;
				curButton.editStart(); //there has to be a better way to do this
				//curButton.draw();
				actionButtons.push(curButton);
				mode = 2;
			}
		}

		//save file
		if (e.keycode == Key.key_s && e.mod.meta) {
			//get path & open file
			var path = Luxe.core.app.io.module.dialog_save();
			var output = File.write(path);

			//get data & write it
			var saveJson = {
				type : "level",
				backgroundColor : backgroundColor.toJson(),
				terrainColor : terrainColor.toJson(),
				sceneryColor : sceneryColor.toJson(),
				terrain : curTerrain.toJson(),
				scenery : [],
				buttons : []
			};
			for (s in scenery) {
				saveJson.scenery.push(s.toJson());
			}
			for (b in actionButtons) {
				saveJson.buttons.push(b.toJson());
			}

			var saveStr = Json.stringify(saveJson, null, "    ");
			output.writeString(saveStr);

			//close file
			output.close();
		}

		//delete hack
		if (mode == 0 && e.keycode == Key.key_d && curTerrain.points.length > 2) {
			if (e.mod.meta) {
				curTerrain.removeStartPoint();
			}
			else {
				curTerrain.removeEndPoint();
			}
			curTerrain.redraw(terrainColor);
		}

		//move action button height
		if (mode == 2) {
			if (e.keycode == Key.key_w) {
				curButton.height += 10;
			}
			else if (e.keycode == Key.key_s) {
				curButton.height -= 10;
			}
			else if (e.keycode == Key.key_q) {
				//curButton.startSize += 5;
				curButton.curSize += 0.1;
			}
			else if (e.keycode == Key.key_a) {
				//curButton.startSize -= 5;
				curButton.curSize -= 0.1;
			}
			//hacky redraw (use dynamic instead?)
			//curButton.clear();
			//curButton.draw();

			if (e.keycode == Key.key_e) {
				var i = actionButtons.indexOf(curButton);
				i--;
				if (i < 0) i = actionButtons.length - 1;
				curButton = actionButtons[i];
				curButton.editStart();
			}
			else if (e.keycode == Key.key_r) {
				var i = actionButtons.indexOf(curButton);
				i++;
				if (i >= actionButtons.length) i = 0;
				curButton = actionButtons[i];
				curButton.editStart();
			}

			if (e.keycode == Key.key_d && e.mod.meta) {
				var i = actionButtons.indexOf(curButton);
				i++;
				if (i >= actionButtons.length) i = 0;
				var nextButton = actionButtons[i];

				//curButton.clear(); //if this was an Entity or a Visual, we could use remove! (next round of coding)
				Luxe.scene.remove(curButton);
				curButton.destroy();
				actionButtons.remove(curButton);

				if (actionButtons.length <= 0) {
					mode = 0;
					curButton = null;
				}
				else {
					curButton = nextButton;
					curButton.editStart();
				}
			}
		}

		panScene(e);
		zoomScene(e);

	}

	function openLevel(json) {
		//rehydrate colors
		backgroundColor = (new Color()).fromJson(json.backgroundColor);
		terrainColor = (new Color()).fromJson(json.terrainColor);
		sceneryColor = (new Color()).fromJson(json.sceneryColor);
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
			//b.clear();
			Luxe.scene.remove(b);
			b.destroy();
		}
		actionButtons = [];
		for (b in cast(json.buttons, Array<Dynamic>)) {
			var a = (new ActionButton({})).fromJson(b);
			a.terrain = curTerrain;
			//a.draw();
			actionButtons.push(a);
			curButton = a; //hacky
		}
	}

	/*
	override function onwindowresized(e) {
		trace(Luxe.camera.size);
	}
	*/

	function panScene(e : KeyEvent) {
		if (e.keycode == Key.left) {
			Luxe.camera.pos.add(new Vector(-panIncrement, 0));
		}
		else if (e.keycode == Key.right) {
			Luxe.camera.pos.add(new Vector(panIncrement, 0));
		}

		if (e.keycode == Key.up) {
			Luxe.camera.pos.add(new Vector(0, -panIncrement));
		}
		else if (e.keycode == Key.down) {
			Luxe.camera.pos.add(new Vector(0, panIncrement));
		}
	}

	function zoomScene(e : KeyEvent) {
		if (e.keycode == Key.minus) {
			Luxe.camera.zoom -= zoomIncrement;
		}
		else if (e.keycode == Key.equals) {
			Luxe.camera.zoom += zoomIncrement;
		}
	}

	override function onkeyup( e:KeyEvent ) {

	    if (e.keycode == Key.escape) {
	        Luxe.shutdown();
	    }

	} //onkeyup

	override function onmousedown( e:MouseEvent ) {

		var screen_point = e.pos;
		var world_point = Luxe.camera.screen_point_to_world( screen_point );

		if (mode == 0) {
			if (Luxe.input.keydown(Key.lctrl)) {
				var prevSize = curTerrain.points.length;
				curTerrain.buildTerrainToPoint(world_point);
				if (prevSize != curTerrain.points.length) curTerrain.redraw(terrainColor);

				prevCursorPos = screen_point;
			}
		}
		else if (mode == 1) {
			tmpStroke = [];
			tmpStroke.push(world_point);
		}
		else if (mode == 2) {
			//move the action button around
			var i = curTerrain.closestIndexHorizontally(Luxe.camera.screen_point_to_world(e.pos).x);
			//curButton.clear();
			curButton.terrainPos = curTerrain.points[i].x - curTerrain.points[0].x; //turn this into a real function or something
			//curButton.draw();
		}
	}

	override function onmousemove(e:MouseEvent) {
		//TODO move stuff here
		if (Luxe.input.mousedown(1)) {

			var screen_point = Luxe.screen.cursor.pos;
			var world_point = Luxe.camera.screen_point_to_world( screen_point );

			if (mode == 0) {
				if (Luxe.input.keydown(Key.lctrl)) {
					var prevSize = curTerrain.points.length;
					var prev_world_point = Luxe.camera.screen_point_to_world( prevCursorPos );

					curTerrain.buildTerrainAlongLine(prev_world_point, world_point);
					if (prevSize != curTerrain.points.length) curTerrain.redraw(terrainColor);

					prevCursorPos = screen_point;
				}
			}
			else if (mode == 1) {
				tmpStroke.push(world_point);
			}
		}
	}

	override function onmouseup( e:MouseEvent ) {
		prevCursorPos = null;

		if (tmpStroke.length > 0) {
			var p = new Polystroke({color : sceneryColor, batcher : Luxe.renderer.batcher}, tmpStroke.clone());
			scenery.push(p);
		}
		tmpStroke = [];
	}

	override function update(dt:Float) {

		//draw tmp drawing
		for (i in 1 ... tmpStroke.length) {
			var p0 = tmpStroke[i-1];
			var p1 = tmpStroke[i];
			Luxe.draw.line({
				p0 : p0,
				p1 : p1,
				color : sceneryColor,
				immediate : true
			});
		}

		//draw screen box
		Luxe.draw.rectangle({
			x : ((Luxe.screen.width - widthInWorldPixels) / 2) + Luxe.camera.pos.x,
			y : ((Luxe.screen.height - heightInWorldPixels) / 2) + Luxe.camera.pos.y,
			w : widthInWorldPixels,
			h : heightInWorldPixels,
			immediate : true
		});

		/*
		if (mode == 2) {
			curButton.drawUI();
		}
		*/

	} //update


} //Main
