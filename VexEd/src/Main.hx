
import luxe.Input;
import luxe.Visual;
import luxe.Vector;
import luxe.Color;
import vexlib.Vex;
import vexlib.Vex.Palette;

import sys.io.File;
//import sys.io.FileOutput;
//import sys.io.FileInput;

import haxe.Json;
import dialogs.Dialogs;

class Main extends luxe.Game {

	var drawingPath = [];
	var distToClosePath = 16;

	var root : Vex;
	var selected : Vex = null;

	var count = 0;

	var isEditingId = false;

	override function ready() {
		Luxe.camera.pos.subtract(Luxe.screen.mid); //put 0,0 in the center of the camera

		//init drawing
		root = new Vex({
				type: "group",
				origin: [0,0],
				pos: [0,0]
			});

		//draw origin
		Luxe.draw.line({
				p0: new Vector(-Luxe.screen.width/2, 0),
				p1: new Vector(Luxe.screen.width/2, 0)
			});
		Luxe.draw.line({
				p0: new Vector(0, -Luxe.screen.height/2),
				p1: new Vector(0, Luxe.screen.height/2)
			});
	} //ready

	override function ontextinput(e:TextEvent) {
		if (isEditingId) {
			selected.attributes.id += e.text;
		}
	}

	override function onkeydown( e:KeyEvent ) {

		//test animation
		if (e.keycode == Key.key_a) {
			root.animate({
					animations : [{
						target : ".world",
						rot : [
							{t : 0.60, d : [0]},
							{t : 1.00, d : [90]}
						]
					}]
				}, 1.2);
		}

		//delete selected element
		if (e.keycode == Key.backspace) {
			if (selected != null) {
				selected.destroy(true);
				selected = null; //for now (need a stack?)
			}
		}

		//edit id
		if (e.keycode == Key.key_i && e.mod.meta) {
			trace("1");
			if (selected != null) {
				trace("2");
				isEditingId = !isEditingId;
				if (isEditingId) selected.attributes.id = "";
			}
		}

		//open
		if (e.keycode == Key.key_o && e.mod.meta ) {

			//load file
			var path = Dialogs.open("Open dialog");
			var fileStr = File.getContent(path);
			var json = Json.parse(fileStr);

			//destroy current image
			root.destroy();

			//load new image
			root = new Vex(json);

		}

		//save
		if (e.keycode == Key.key_s && e.mod.meta ) {
			//get path & open file
			var path = Dialogs.save("Save dialog");
			var output = File.write(path);

			//get data & write it
			var saveJson = root.attributes;
			var saveStr = Json.stringify(saveJson);//, null, "    ");
			output.writeString(saveStr);

			//close file
			output.close();
		}

	}

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function onmousedown( e:MouseEvent ) {

		var p = Luxe.camera.screen_point_to_world(e.pos);

		//is the path closed?
		var isPathClosed = false;
		if (drawingPath.length > 2) {
			var startPos = new Vector(drawingPath[0], drawingPath[1]);
			var nextPos = new Vector(p.x, p.y);
			if ( nextPos.subtract(startPos).length < distToClosePath ) {
				isPathClosed = true;
			}
		}

		if (isPathClosed) {
			//create new vex
			selected = new Vex({
				type: "poly",
				path: drawingPath,
				id: "poly" + count
			});
			//selected.parent = root;
			root.addChild(selected);
			//clear drawing path
			drawingPath = [];

			count++;
		}
		else {
			//add new point
			drawingPath.push(p.x);
			drawingPath.push(p.y);
		}
	}

	override function onmousewheel(e:MouseEvent) {
		//zoom on scroll
		Luxe.camera.zoom += e.yrel * 0.1;
	}

	override function update(dt:Float) {
		renderDrawingPath();

		if (selected != null) {
			Luxe.draw.text({
					text: "id: " + selected.attributes.id,
					point_size: 16,
					pos: Vector.Multiply( Luxe.screen.mid, -1),
					immediate: true
				});
		}
	} //update

	function renderDrawingPath() {
		if (drawingPath.length > 0) {

			//start circle
			Luxe.draw.ring({
				x: drawingPath[0],
				y: drawingPath[1],
				r: distToClosePath,
				immediate: true 
			});

			//draw path
			if (drawingPath.length > 2) {
				var i = 3;
				while (i < drawingPath.length) {
					Luxe.draw.line({
							p0: new Vector(drawingPath[i-3], drawingPath[i-2]),
							p1: new Vector(drawingPath[i-1], drawingPath[i-0]),
							immediate: true
						});
					i += 2;
				}
			}

		}
	}


} //Main

