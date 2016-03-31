import adventurlib.*;

import luxe.Input;
import luxe.Vector;
import luxe.Color;

import adventurlib.ActionButton.Direction;
import adventurlib.ActionButton.OutroAnimation;

using adventurlib.PolylineExtender;

//file IO
import sys.io.File;
import sys.io.FileOutput;
import sys.io.FileInput;
import haxe.Json;


class Main extends luxe.Game {

	var button : ActionButton;
	var curStroke : Array<Vector> = [];

    override function ready() {
    	button = (new ActionButton({
    			/*color : new Color(0,0,1),*/
    			pos : Luxe.screen.mid
    		}))
			.fromJson({
				backgroundColor : {r:0,g:0,b:1},
				illustrationColor : {r:1,g:1,b:1},
				terrainPos : 0,
				height : 0,
				startSize : 1,
				endSize : 2,
				pullDir : "Down",
				outro : "FillScreen",
				illustration1: [],
				illustration2: [],
				name: "useless_name"
			});

		button.editStart();
    } //ready

	override function onkeydown(e:KeyEvent) {

		
		//switch edit modes
		if (e.keycode == Key.key_1) {
			button.editStart();
		}
		else if (e.keycode == Key.key_2) {
			button.editEnd();
		}

		//preview animations
		if (e.keycode == Key.key_3) {
			button.animateAppear();
		}
		else if (e.keycode == Key.key_4) {
			button.animatePull();
		}
		else if (e.keycode == Key.key_5) {
			button.animateOutro();
		}
		else if (e.keycode == Key.key_6) {
			button.animateSequence();
		}

		//change size
		if (e.keycode == Key.key_q) {
			button.curSize += 0.1;
		}
		else if (e.keycode == Key.key_a) {
			button.curSize -= 0.1;
		}

		//change outro style
		if (e.keycode == Key.key_z) {
			var i = button.outro.getIndex();
			i = (i + 1) % OutroAnimation.getConstructors().length;
			button.outro = OutroAnimation.createByIndex(i);
		}

		//change pull dir
		if (e.keycode == Key.left) {
			button.pullDir = Direction.Left;
		}
		else if (e.keycode == Key.right) {
			button.pullDir = Direction.Right;
		}
		else if (e.keycode == Key.up) {
			button.pullDir = Direction.Up;
		}
		else if (e.keycode == Key.down) {
			button.pullDir = Direction.Down;
		}

		//save file
		if (e.keycode == Key.key_s && e.mod.meta) {
			//get path & open file
			var path = Luxe.core.app.io.module.dialog_save();
			var output = File.write(path);

			//get data & write it
			button.name = path.split("/")[path.split("/").length-1];
			var saveJson = button.toJson();
			var saveStr = Json.stringify(saveJson, null, "    ");
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

		var screen_point = e.pos;
		var world_point = Luxe.camera.screen_point_to_world( screen_point );

		curStroke = [];
		curStroke.push(world_point);

	}

	override function onmousemove( e:MouseEvent ) {

		var screen_point = e.pos;
		var world_point = Luxe.camera.screen_point_to_world( screen_point );

		if (Luxe.input.mousedown(1)) {
			curStroke.push(world_point);
		}
	}

	override function onmouseup( e:MouseEvent ) {

		var screen_point = e.pos;
		var world_point = Luxe.camera.screen_point_to_world( screen_point );

		if (curStroke.length > 0) {
			var shiftedStroke = [];
			for (point in curStroke) {
				point.subtract(button.pos).divideScalar(button.scale.x);
				shiftedStroke.push(point);
			}

			var p = new Polystroke({color : new Color(1,1,1), batcher : Luxe.renderer.batcher, depth: 50}, shiftedStroke /*curStroke*/);
			button.addStrokeToIllustration(p);
		}
		curStroke = [];

	}

    override function update(dt:Float) {
    	Luxe.draw.text({
    		pos: new Vector(0,0),
    		point_size: 20,
    		text: "outro: " + button.outro.getName(),
    		immediate: true
    	});

    	//button.drawImmediate();

    	//draw tmp drawing
		for (i in 1 ... curStroke.length) {
			var p0 = curStroke[i-1];
			var p1 = curStroke[i];
			Luxe.draw.line({
				p0 : p0,
				p1 : p1,
				color : new Color(1,1,1),
				depth : 50,
				immediate : true
			});
		}
    } //update


} //Main
