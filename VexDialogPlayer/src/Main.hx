
import luxe.Input;
import luxe.Vector;
import luxe.tween.Actuate;
import luxe.resource.Resource.JSONResource;

import vexlib.Font;
import vexlib.Vex;

/*
TODO THIS WEEK
X new dialog project
X move font into vexlib
- basic dialog file format
- progressive dialog rendering
	- with word wrap
- pull to advance

GOALS for dialog prototype (in priority order)
1. test interactions for next dialog & choices (on mobile)
2. prototype I can get feedback on (need prototype dialog)
3. test "dialog effects" (speed, colors, bounce, etc)
4. shareable vignette (requires dialog I'm proud of... related to final game?)
THIS WEEK
- v1 of dialog player
- more writing practice
*/

class Main extends luxe.Game {

	//settings
	var charWidth = 48;
	var charHeight = 96;
	var charactersPerLine = 16;
	var linesPerPage = 4;
	//var charTypeSpeed = 0.1;
	//var charDrawSpeed = 0.3;
	var charTypeSpeed = 0.3;
	var charDrawSpeed = 0.5;

	//constants
	var defaultCharBox = { //the arbitrariness bothers me
		width: 300,
		height: 550,
		baseline: 400
	};

	//derived values
	var charWidthScale : Float;
	var charHeightScale : Float;
	var textBoxWidth : Float;
	var textBoxHeight : Float;
	var textBoxX : Float;
	var textBoxY : Float;

	//storage
	var font : Font;

	//debug
	var debugDialog = ["Hello world", "This is some test dialog. Isn't it nice? It sure is nice. Yes it is.", "Ok, goodbye ya'll."];
	var pageIndex = 0;
	var isWaiting = false;
	var pageVex = [];

	override function ready() {
		textBoxWidth = charWidth * charactersPerLine;
		textBoxHeight = charHeight * linesPerPage;
		textBoxX = (Luxe.screen.w/2) - (textBoxWidth/2);
		textBoxY = (Luxe.screen.h/2) - (textBoxHeight/2);

		trace(textBoxX + " " + textBoxY);
		trace(textBoxWidth + " " + textBoxHeight);
		trace(Luxe.screen.size);

		//debug draw text box
		Luxe.draw.rectangle({x:textBoxX,y:textBoxX,w:textBoxWidth,h:textBoxHeight});

		charWidthScale = charWidth / defaultCharBox.width;
		charHeightScale = charHeight / defaultCharBox.height;

		//debug draw char box size
		Luxe.draw.rectangle({x:textBoxX,y:textBoxX,w:charWidth,h:charHeight});

		//load the system font (aka the default font I made)
		var load = Luxe.resources.load_json("assets/sysfont.vex");
		load.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			font = new Font(json);
			trace("font loaded! " + font.id);

			/*
			//start dialog
			writeText( debugDialog[pageIndex], function() {
					isWaiting = true;
				});
			*/
			isWaiting = true;
		});

	} //ready

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function update(dt:Float) {
		if (isWaiting) {
			//draw next arrow
			Luxe.draw.line({
					p0: new Vector(textBoxX + (textBoxWidth/2), textBoxY + textBoxHeight + charHeight),
					p1: new Vector(textBoxX + (textBoxWidth/2) - charWidth, textBoxY + textBoxHeight + 2),
					immediate: true
				});
			Luxe.draw.line({
					p0: new Vector(textBoxX + (textBoxWidth/2), textBoxY + textBoxHeight + charHeight),
					p1: new Vector(textBoxX + (textBoxWidth/2) + charWidth, textBoxY + textBoxHeight + 2),
					immediate: true
				});
		}
	} //update

	override function onmousedown(e:MouseEvent) {
		if (isWaiting) {
			clearPage();
			isWaiting = false;
			if (pageIndex < debugDialog.length) {
				writeText( debugDialog[pageIndex], function() {
						isWaiting = true;
						pageIndex++;
					});
			}
		}
	}

	function clearPage() {
		for (v in pageVex) {
			cast(v,Vex).destroy(true);
		}
		pageVex = [];
	}

	function writeText(text:String, ?onComplete:Dynamic) {
		var count = 0;
		var typeTimer : snow.api.Timer = null;

		var typeNext = function() {

			//calculate row & column position of character
			var row : Int = cast(count / charactersPerLine); //arbitary line width
			var col : Int = count - (row * charactersPerLine);

			if (row > linesPerPage) trace("OH NO too many characters on this page");

			//create vex representation of character
			var nextChar = text.charAt(count);
			var tweenNextChar = null;
			if (font.exists(nextChar)) { //skip undefined characters
				var v = new Vex(font.get(nextChar));
				//scale character
				v.scale.x = charWidthScale;
				v.scale.y = charHeightScale;
				//position character
				v.pos.x = textBoxX + (col * charWidth) + (charWidth/2);
				v.pos.y = textBoxY + (row * charHeight); //why isn't the height/2 needed?

				//start character animation
				tweenNextChar = animateStrokes(v, charDrawSpeed);

				pageVex.push(v); //keep track of all the vex objects used to create this page (TODO maybe use vex instead of a list?)		
			}

			//increment count and look for end of page
			count++;
			if (count >= text.length) {
				typeTimer.stop();

				if (onComplete != null) {
					if (tweenNextChar != null) {
						//if there's a character drawing, wait until it finishes to launch oncomplete
						tweenNextChar.onComplete(function() {
								onComplete();
							});
					}
					else {
						//or just do it now (will this ever happen?)
						onComplete();
					}
				}
			}
		};

		typeTimer = Luxe.timer.schedule(charTypeSpeed, typeNext, true);
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

		return Actuate.tween(pointCounter, time, {count:totalLength-1}).ease(luxe.tween.easing.Quad.easeIn)
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


} //Main
