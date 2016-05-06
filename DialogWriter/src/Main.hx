import adventurlib.*;

import luxe.Input;
import luxe.Color;
import luxe.Visual;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Entity;
import luxe.options.EntityOptions;

//file IO
import sys.io.File;
import sys.io.FileOutput;
import sys.io.FileInput;
import haxe.Json;
import dialogs.Dialogs;

class Main extends luxe.Game {

	var baseline = 500;
	var topline = 300;
	var midline = 400;

	var curStroke : Array<Vector> = [];
	var curWord : Array<Polystroke> = [];
	var dialog : Dialog;

	var isPlayMode = false;
	var hasNextDialog = false;

	var insertIndex = -1;

	override function ready() {

		dialog = new Dialog({
			pos:new Vector(100,100)
		});

		Luxe.renderer.clear_color = new Color(0.3,0.5,1);

		Luxe.draw.line({
			p0: new Vector(0,baseline), p1: new Vector(Luxe.screen.width,baseline)
		});
		Luxe.draw.line({
			p0: new Vector(0,topline), p1: new Vector(Luxe.screen.width,topline)
		});
		Luxe.draw.line({
			p0: new Vector(0,midline), p1: new Vector(Luxe.screen.width,midline)
		});

	} //ready

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

		if (isPlayMode) {
			if (e.keycode == Key.down && !dialog.isAnimationInProgress) {
				if (hasNextDialog) {
					hasNextDialog = dialog.showNext();
				}
				else {
					isPlayMode = false;
					dialog.returnToEditing();
				}
			}
		}
		else {

			if (e.keycode == Key.space) { //new word

				dialog.insertWord(new Word({
						strokes:curWord,
						baseline:baseline, //this should really be preprocessed instead of part of the constructor
						topline:topline
					}),
					insertIndex
				);

				curWord = [];

				insertIndex++;
			}

			if (e.keycode == Key.enter) { //add new sentence
				dialog.newSentence();
				insertIndex = -1;
			}
			if (e.keycode == Key.rshift) { //test current sentence
				dialog.animateSentence(5);
			}
			if (e.keycode == Key.key_p) { //enter play mode
				isPlayMode = true;
				dialog.beginDialog();
				hasNextDialog = dialog.showNext();
			}
			//edit other words
			if (e.keycode == Key.up) {
				dialog.prevSentence();
				insertIndex = -1;
			}
			else if (e.keycode == Key.down) {
				dialog.nextSentence();
				insertIndex = -1;
			}
			else if (e.keycode == Key.left) {
				insertIndex--;
			}
			else if (e.keycode == Key.right) {
				insertIndex++;
			}
			else if (e.keycode == Key.backspace) {
				dialog.deleteWord(insertIndex);
				insertIndex--;
			}
		}

	} //onkeyup

	override function onkeydown(e:KeyEvent) {
		//save file
		if (e.keycode == Key.key_s && e.mod.meta) {
			//get path & open file
			var path = Dialogs.save("Save dialog");
			var output = File.write(path);

			//get data & write it
			var saveJson = dialog.toJson();
			var saveStr = Json.stringify(saveJson);//, null, "    ");
			output.writeString(saveStr);

			//close file
			output.close();
		}
		if (e.keycode == Key.key_o && e.mod.meta) {
			var path = Dialogs.open("Save dialog");
			var fileStr = File.getContent(path);
			var json = Json.parse(fileStr);
			dialog.destroy();
			dialog = new Dialog({pos:new Vector(100,100)}).fromJson(json);
		}

	}

	override function update(dt:Float) {

		//draw cur stroke
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

		if (!isPlayMode) {
			var ip = dialog.insertPoint(insertIndex);
			ip.add(dialog.pos);
			ip.x -= 15; //hack
			Luxe.draw.line({
					p0 : ip,
					p1 : new Vector(ip.x, ip.y - 50), //hack
					color : new Color(1,1,1),
					depth : 50,
					immediate : true
				});
		}

	} //update

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
			curStroke.push(world_point);

			var p = new Polystroke({
							color: new Color(1,1,1),
							batcher: Luxe.renderer.batcher
						}, curStroke);

			curWord.push(p);

		}
		curStroke = [];

	}


} //Main

