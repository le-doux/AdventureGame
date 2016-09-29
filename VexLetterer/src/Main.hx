
import luxe.Input;
import luxe.Vector;
import luxe.Color;
import luxe.tween.Actuate;

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
	TypingTest;
}

class Main extends luxe.Game {

	var mode : EditorMode = EditorMode.FontView;


	//char edit mode
	var curChar : String = null;
	//character box
	var charBoxW = 300;
	var charBoxH = 550;
	var charBoxBaseline = 400;
	//strokes
	var isDrawing = false;
	var curStroke = [];
	var strokes : Array<Array<Vector>> = [];

	//font storage
	var fontMap : Map<String,VexJsonFormat> = new Map<String,VexJsonFormat>();

	//font view mode
	var fontVex : Array<Vex> = [];

	//typing test mode
	var typingCount = 0;
	var typingVex : Array<Vex> = [];

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

		/*
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
		*/

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
				//mode = EditorMode.FontView;
				switchMode(EditorMode.FontView);
			}
		}
		else if (mode == EditorMode.FontView) {
			if (e.keycode == Key.tab) {
				switchMode(EditorMode.TypingTest);
			}
		}
		else if (mode == EditorMode.TypingTest) {
			if (e.keycode == Key.tab) {
				switchMode(EditorMode.FontView);
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
		if (mode == EditorMode.FontView || mode == EditorMode.CharEdit) {
			if (curChar != nextChar) {

				//save current work
				if (mode == EditorMode.CharEdit) {
					if (strokes.length > 0) {
						saveChar(curChar, strokes);
					}
				}

				//set char
				curChar = nextChar;
				//set mode
				//mode = EditorMode.CharEdit;
				switchMode(EditorMode.CharEdit);
			}
		}
		else if (mode == EditorMode.TypingTest) {
			var scale = 0.1; //duped code
			var topLeft = Luxe.camera.pos.clone().add(new Vector(300 * scale * 0.5, 550 * scale * 0.5));
			if (fontMap.exists(nextChar)) {
				var v = new Vex(fontMap[nextChar]);
				v.pos = topLeft.clone().add( new Vector(300 * scale * typingCount, 0) );
				v.scale = new Vector(scale, scale, scale);
				typingVex.push(v);
				animateStrokes(v,0.3);
			}
			else {
				//ignore undefined characters
			}
			typingCount++;
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
		var topLeft = Luxe.camera.pos.clone().add(new Vector(300 * scale * 0.5, 550 * scale * 0.5));
		var vexCharacters = [];
		var i = 0;

		var keyArr = [];
		for (k in fontMap.keys()) {
			keyArr.push(k);
		}
		keyArr.sort( function(a:String, b:String):Int
		{
			//a = a.toLowerCase();
			//b = b.toLowerCase();
			if (a < b) return -1;
			if (a > b) return 1;
			return 0;
		} );

		for (k in keyArr) {
			var v = new Vex(fontMap[k]);
			v.pos = topLeft.clone().add( new Vector(300 * scale * i, 0) );
			v.scale = new Vector(scale, scale, scale);
			vexCharacters.push(v);
			i++;
		}
		return vexCharacters;
	}

	//this is hacky as heck but it's just a test really
	function animateStrokes(v:Vex, time:Float) {
		var strokes : Array<Array<Vector>> = v.properties.path.toMultiPath();

		var pointCounter = {
			count : 0
		};
		var totalLength = 0;
		for (s in strokes) {
			totalLength += s.length;
		}

		Actuate.tween(pointCounter, time, {count:totalLength-1})
			.onUpdate(function(){
				var curCount = pointCounter.count;
				var curStrokes = [];
				var curStrokeIndex = 0;
				while (strokes[curStrokeIndex].length < curCount) {
					var s = strokes[curStrokeIndex];
					curCount -= s.length;
					curStrokes.push(s);
					curStrokeIndex++;
				}
				if (curCount > 0 && curStrokeIndex < strokes.length) {
					curStrokes.push([]);
					for (i in 0 ... curCount) {
						curStrokes[curStrokeIndex].push( strokes[curStrokeIndex][i] );
					}
				}
				v.properties.path = curStrokes;
			});
	}

	function switchMode(nextMode) {
		//cleanup
		if (mode == EditorMode.FontView) {
			for (v in fontVex) {
				v.destroy();
			}
			fontVex = [];
		}
		else if (mode == EditorMode.CharEdit) {
			//todo save work here?
		}
		else if (mode == EditorMode.TypingTest) {
			for (v in typingVex) {
				v.destroy();
			}
			typingVex = [];
		}

		//init
		if (nextMode == EditorMode.FontView) {
			fontVex = drawFont();
		}
		else if (nextMode == EditorMode.CharEdit) {
			//clear strokes
			curStroke = [];
			strokes = [];
		}
		else if (nextMode == EditorMode.TypingTest) {
			typingVex = [];
			typingCount = 0;
		}

		mode = nextMode;
	}

} //Main
