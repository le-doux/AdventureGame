
import luxe.Input;
import luxe.Vector;
import luxe.tween.Actuate;
import luxe.resource.Resource.JSONResource;
import luxe.Color;
import luxe.Visual;
import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import phoenix.Batcher; //for primitivetypes

import vexlib.Font;
import vexlib.Vex;

/*
TODO
X dialog choice prototype
X grid movement prototype

TODO THIS WEEK
X new dialog project
X move font into vexlib
- basic dialog file format
X progressive dialog rendering
	X with word wrap
X pull to advance
X restart dialog
- adjustable box size
- adjustable char size
X perf and visual test on mobile
	NOTES (with quad rendering)
	- size is small on retina screens (needs to be adaptive)
	- perf suffers with two many characters (too much geometry) on screen; is ok for small amounts
	NOTES (with regular line rendering)
	- it's a lot faster
- floaty effect (for fun)
X write up learnings from bitsy engine

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
	var charWidth = 32;
	var charHeight = 64;
	var charactersPerLine = 24;
	var linesPerPage = 4;
	var charTypeSpeed = 0.1;
	var charDrawSpeed = 0.3;

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

	//page data
	var pages = ["Hello world", "This is some test dialog. Isn't it nice?"];
	var pageIndex = 0;
	var isWaiting = false;
	var pageVex = [];

	//pull tab
	var pullDistY:Float = 0;
	var minPullDist = 128;
	var maxPullDist = 200;

	//choice prototype
	var isChoiceMode = false;
	var choiceA = "Choice A";
	var choiceB = "Choice B";
	var dialogA = ["You've chosen Choice A! How nice of you.", "Ok, goodbye ya'll."];
	var dialogB = ["Choice B, huh? What do you think that says about you?", "Bye now!"];
	var choiceAViz : Visual;
	var choiceBViz : Visual;
	var pullDistX : Float = 0;

	override function ready() {
		textBoxWidth = charWidth * charactersPerLine;
		textBoxHeight = charHeight * linesPerPage;
		textBoxX = 100; //(Luxe.screen.w/2) - (textBoxWidth/2);
		textBoxY = 200; //(Luxe.screen.h/2) - (textBoxHeight/2);

		charWidthScale = charWidth / defaultCharBox.width;
		charHeightScale = charHeight / defaultCharBox.height;

		/*
		trace(textBoxX + " " + textBoxY);
		trace(textBoxWidth + " " + textBoxHeight);
		trace(Luxe.screen.size);
		//debug draw text box
		Luxe.draw.rectangle({x:textBoxX,y:textBoxY,w:textBoxWidth,h:textBoxHeight});
		//debug draw char box size
		Luxe.draw.rectangle({x:textBoxX,y:textBoxY,w:charWidth,h:charHeight});
		*/

		//set the screen size
		Luxe.camera.size = new Vector(textBoxWidth + 200, textBoxHeight + 400);

		//load the system font (aka the default font I made)
		var load = Luxe.resources.load_json("assets/sysfont.vex");
		load.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			font = new Font(json);
			trace("font loaded! " + font.id);
			isWaiting = true;
		});

	} //ready

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

		if (e.keycode == Key.key_r) {
			//restart
			restart();
		}

	} //onkeyup

	function restart() {
		clearPage(); 
		pageIndex = 0;
		isWaiting = true;
	}

	override function update(dt:Float) {
		if (isChoiceMode) {
			//todo
		}
		else if (isWaiting) {
			//draw next arrow
			var arrowBottom = new Vector(textBoxX + (textBoxWidth/2), textBoxY + textBoxHeight + charHeight + pullDistY);
			Luxe.draw.line({
					p0: arrowBottom,
					p1: arrowBottom.clone().add(new Vector(-charWidth,-charHeight/2)),
					immediate: true
				});
			Luxe.draw.line({
					p0: arrowBottom,
					p1: arrowBottom.clone().add(new Vector(charWidth,-charHeight/2)),
					immediate: true
				});
		}
	} //update

	override function onmousedown(e:MouseEvent) {
		if (isChoiceMode) {
			pullDistX = 0;
		}
		else if (isWaiting) {
			pullDistY = 0;
		}
		else {
			restart();
		}
	}

	override function onmousemove(e:MouseEvent) {
		if (Luxe.input.mousedown(1)) {	
			if (isChoiceMode) {
				pullDistX += e.xrel;
				choiceAViz.pos.x += e.xrel;
				choiceBViz.pos.x += e.xrel;
			}
			else if (isWaiting) {
				pullDistY += e.yrel;
				pullDistY = Math.max(0, pullDistY);

				if (pullDistY > maxPullDist) {
					pullDistY = 0;
					doNextPage();
				}
			}
		}
	}

	override function onmouseup(e:MouseEvent) {
		if (isChoiceMode) {
			onChoiceMouseUp();
		}
		else if (isWaiting) {
			if (pullDistY > minPullDist) {
				doNextPage();
			}
			pullDistY = 0;
		}
	}

	//todo rename
	function onChoiceMouseUp() {
		if (pullDistX > 100) {
			Actuate.tween(choiceBViz.pos, 1, {x:Luxe.camera.size.x * 2});
			Actuate.tween(choiceAViz.pos, 1, {x:(Luxe.camera.size.x/2) - (charWidth*4)})
				.onComplete(function() {
						//todo wrap in function
						choiceAViz.destroy();
						choiceBViz.destroy();
						isChoiceMode = false;
						pullDistX = 0;

						pages = dialogA;
						pageIndex = 0;
						isWaiting = false;
						doNextPage();
					});
		}
		else if (pullDistX < -100) {
			Actuate.tween(choiceAViz.pos, 1, {x:-1 * Luxe.camera.size.x * 2});
			Actuate.tween(choiceBViz.pos, 1, {x:(Luxe.camera.size.x/2) + (charWidth*4)})
				.onComplete(function() {
						choiceAViz.destroy();
						choiceBViz.destroy();
						isChoiceMode = false;
						pullDistX = 0;

						pages = dialogB;
						pageIndex = 0;
						isWaiting = false;
						doNextPage();
					});
		}
		else {
			Actuate.tween(choiceAViz.pos, 0.5, {x:charWidth*2});
			Actuate.tween(choiceBViz.pos, 0.5, {x:Luxe.camera.size.x-(charWidth*2)});
		}
	}

	function startChoiceMode() {
		isChoiceMode = true;

		//choice A arrow
		var choiceAGeomArrow = new Geometry({
						primitive_type: PrimitiveType.line_strip,
						batcher: Luxe.renderer.batcher
					});
		choiceAGeomArrow.vertices.push(new Vertex(new Vector(0,charHeight/2)));
		choiceAGeomArrow.vertices.push(new Vertex(new Vector(charWidth,0)));
		choiceAGeomArrow.vertices.push(new Vertex(new Vector(0,-charHeight/2)));

		choiceAViz = new Visual({
				pos: new Vector(charWidth*2,(Luxe.camera.size.y/2)),
				geometry: choiceAGeomArrow
			});

		//choice A text
		for (i in 0 ... choiceA.length) {
			var ch = choiceA.charAt(i);
			if (font.exists( ch )) {
				var v = new Vex( font.get(ch) );
				//scale character
				v.scale.x = charWidthScale;
				v.scale.y = charHeightScale;
				//position character
				v.pos.x = (i+1.7) * charWidth;
				v.pos.y = 0;
				//parent
				v.parent = choiceAViz;
			}
		}

		//choice B arrow
		var choiceBGeomArrow = new Geometry({
						primitive_type: PrimitiveType.line_strip,
						batcher: Luxe.renderer.batcher
					});
		choiceBGeomArrow.vertices.push(new Vertex(new Vector(0,charHeight/2)));
		choiceBGeomArrow.vertices.push(new Vertex(new Vector(-charWidth,0)));
		choiceBGeomArrow.vertices.push(new Vertex(new Vector(0,-charHeight/2)));

		choiceBViz = new Visual({
				pos: new Vector(Luxe.camera.size.x - (charWidth*2),(Luxe.camera.size.y/2)),
				geometry: choiceBGeomArrow
			});

		//choice B text
		var reverseArr = choiceB.split(''); 
		reverseArr.reverse(); 
		var choiceBReverse = reverseArr.join('');
		for (i in 0 ... choiceBReverse.length) {
			var ch = choiceBReverse.charAt(i);
			if (font.exists( ch )) {
				var v = new Vex( font.get(ch) );
				//scale character
				v.scale.x = charWidthScale;
				v.scale.y = charHeightScale;
				//position character
				v.pos.x = -1 * (i+1.7) * charWidth;
				v.pos.y = 0;
				//parent
				v.parent = choiceBViz;
			}
		}
	}

	function doNextPage() {
		clearPage();
		isWaiting = false;
		if (pageIndex < pages.length) {
			writeText( pages[pageIndex], function() {
					isWaiting = true;
					pageIndex++;
				});
		}
		else {
			//hack to start choice mode
			startChoiceMode();
		}
	}

	function clearPage() {
		for (v in pageVex) {
			cast(v,Vex).destroy(true);
		}
		pageVex = [];
	}

	function writeText(text:String, ?onComplete:Dynamic) {
		//var count = 0;
		var typeTimer : snow.api.Timer = null;

		var textLines = preprocessText(text);
		var row = 0;
		var col = 0;

		var typeNext = function() {

			//calculate row & column position of character
			/*
			var row : Int = cast(count / charactersPerLine); //arbitary line width
			var col : Int = count - (row * charactersPerLine);
			*/
			trace(row);

			if (row > linesPerPage) trace("OH NO too many characters on this page");

			//create vex representation of character
			//var nextChar = text.charAt(count);
			var nextChar = textLines[row].charAt(col);
			var tweenNextChar = null;
			if (font.exists(nextChar)) { //skip undefined characters
				var v = new Vex(font.get(nextChar)); //TODO define font.getVex
				//scale character
				v.scale.x = charWidthScale;
				v.scale.y = charHeightScale;
				//position character
				v.pos.x = textBoxX + (col * charWidth) + (charWidth/2);
				v.pos.y = textBoxY + (row * charHeight) + (charHeight/2);

				//start character animation
				tweenNextChar = animateStrokes(v, charDrawSpeed);

				pageVex.push(v); //keep track of all the vex objects used to create this page (TODO maybe use vex instead of a list?)		
			}

			//increment count and look for end of page
			/*
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
			*/
			//increment col and look for end of page
			col++;
			if (col >= textLines[row].length) {
				//go to next row
				col = 0;
				row++;

				if (row >= textLines.length) {
					//page is finished!
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
			}
		};

		typeTimer = Luxe.timer.schedule(charTypeSpeed, typeNext, true);
	}

	function preprocessText(text:String) : Array<String> {
		//splits page into lines and does word wrap
		var textLines = [];
		textLines.push(""); //newline
		var lineIndex = 0;
		for (word in text.split(" ")) {
			trace(word);
			//word
			if (textLines[lineIndex].length + word.length > charactersPerLine) {
				textLines.push(""); //newline
				lineIndex++;
			}
			textLines[lineIndex] += word;

			//space after word
			if (textLines[lineIndex].length + 1 > charactersPerLine) {
				textLines.push(""); //newline
				lineIndex++;
			}
			else {
				//add space
				textLines[lineIndex] += " ";
			}
		}
		return textLines;
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
