
import luxe.Input;
import luxe.Vector;
import luxe.Color;

import vexlib.Vex;
import vexlib.VexPropertyInterface;

/*
	TODO
	- instant replay
	- font-view
	- save font
	- save characters
	- switch font
*/

enum EditorMode {
	FontView;
	CharEdit;
	CharReplay;
}

class Main extends luxe.Game {

	var mode : EditorMode = EditorMode.FontView;

	var curChar : String = null;

	//character box
	var charBoxW = 300;
	var charBoxH = 550;
	var charBoxBaseline = 400;

	//strokes
	var isDrawing = false;
	var curStroke = [];
	var strokes : Array<Array<Vector>> = [];

	var fontMap : Map<String,VexJsonFormat> = new Map<String,VexJsonFormat>();

	override function ready() {

		Luxe.camera.pos.subtract(Luxe.screen.mid); //put 0,0 in the center of the camera
		//TODO size mode not working???

	} //ready

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function onkeydown( e:KeyEvent ) {
		//hack
		if (e.keycode == Key.key_p) {
			Luxe.camera.zoom += 0.1;
		}
		else if (e.keycode == Key.key_o) {
			Luxe.camera.zoom -= 0.1;
		}
		if (mode == EditorMode.FontView) {
			if (e.keycode == Key.key_f) {
				drawFont();
			}
		}
		//hack

		if (mode == EditorMode.CharEdit){
			if (e.keycode == Key.backspace) {
				if (e.mod.lmeta || e.mod.rmeta) {
					//clear all strokes
					strokes = [];
				}
				else {
					//delete last stroke
					if (strokes.length > 0) {
						strokes.remove( strokes[strokes.length-1] );
					}
				}
			}
			else if (e.keycode == Key.enter) {
				//save char and return to font view
				if (strokes.length > 0) {
					saveChar(curChar, strokes);
				}
				mode = EditorMode.FontView;
			}
		}
	}

	
	override function onmousedown( e:MouseEvent ) {
		if (mode != EditorMode.CharEdit) return;
		isDrawing = true;
		curStroke = [];
		var p = Luxe.camera.screen_point_to_world(e.pos);
		curStroke.push(p);
	}

	override function onmousemove( e:MouseEvent ) {
		if (!isDrawing) return;
		var p = Luxe.camera.screen_point_to_world(e.pos);
		curStroke.push(p);
	}

	override function onmouseup( e:MouseEvent ) {
		if (!isDrawing) return;
		var p = Luxe.camera.screen_point_to_world(e.pos);
		curStroke.push(p);
		strokes.push(curStroke);
		curStroke = [];
		isDrawing = false;
	}
	

	/*
	//testing more deliberate drawing
	override function onmousedown( e:MouseEvent ) {
		if (mode != EditorMode.CharEdit) return;
		trace(e);
		if (e.button == luxe.Input.MouseButton.left) {
			if (!isDrawing) {
				isDrawing = true;
				curStroke = [];
			}
			var p = Luxe.camera.screen_point_to_world(e.pos);
			curStroke.push(p);
		}
		else if (e.button == luxe.Input.MouseButton.right) {
			if (isDrawing) {
				isDrawing = false;
				strokes.push(curStroke);
				curStroke = [];
			}
		}
	}
	*/
	

	override function update(dt:Float) {

		if (mode == EditorMode.CharEdit) {
			drawCharBox();
			drawCharStrokes();
		}

	} //update

	//todo make non-immediate
	function drawCharBox() {
		//cur char text
		Luxe.draw.text({
				text: curChar,
				pos: new Vector((-charBoxW/2)-30,(-charBoxH/2)),
				immediate: true
			});

		//draw character box
		Luxe.draw.rectangle({
				x: -charBoxW/2, 	y: -charBoxH/2,
				w: charBoxW, 		h: charBoxH,
				color: new Color(1,1,1,0.5),
				immediate: true
			});
		//baseline
		Luxe.draw.line({
				p0: new Vector(-charBoxW/2,	(-charBoxH/2)+charBoxBaseline),
				p1: new Vector(charBoxW/2,	(-charBoxH/2)+charBoxBaseline),
				color: new Color(1,1,1,0.75),
				immediate: true
			});
		//midline
		Luxe.draw.line({
				p0: new Vector(-charBoxW/2,	(-charBoxH/2)+(charBoxBaseline/2)),
				p1: new Vector(charBoxW/2,	(-charBoxH/2)+(charBoxBaseline/2)),
				color: new Color(1,1,1,0.25),
				immediate: true
			});
	}

	function drawCharStrokes() {
		//draw strokes
		for (i in 1 ... curStroke.length) {
			Luxe.draw.line({
					p0: curStroke[i-1],
					p1: curStroke[i-0],
					immediate: true
				});
		}
		for (s in strokes) {			
			for (i in 1 ... s.length) {
				Luxe.draw.line({
						p0: s[i-1],
						p1: s[i-0],
						immediate: true
					});
			}
		}
	}

	override function ontextinput(e:TextEvent) {
		var nextChar = e.text.charAt(0); //grab first char as current char
		if (curChar != nextChar) {

			//save current work
			if (mode == EditorMode.CharEdit) {
				if (strokes.length > 0) {
					saveChar(curChar, strokes);
				}
			}

			//set char
			curChar = nextChar;
			//clear strokes
			curStroke = [];
			strokes = [];
			//set mode
			mode = EditorMode.CharEdit;
		}
	}

	function saveChar(char, strokes) {
		fontMap[char] = {
				id: char,
				type: "line",
				path: strokes,
				weight: "10" //testing
			};
	}

	function drawFont() {
		var scale = 0.1;
		var vexCharacters = [];
		var i = 0;
		for (k in fontMap.keys()) {
			var v = new Vex(fontMap[k]);
			v.pos = new Vector(300 * scale * i, 0);
			v.scale = new Vector(scale, scale, scale);
			vexCharacters.push(v);
			i++;
		}
		return vexCharacters;
	}

} //Main
