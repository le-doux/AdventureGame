import adventurlib.*;

import luxe.Input;
import luxe.Color;
import luxe.Visual;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Entity;
import luxe.options.EntityOptions;

class Main extends luxe.Game {

	var baseline = 500;
	var topline = 300;
	var midline = 400;

	var curStroke : Array<Vector> = [];
	var curWord : Array<Polystroke> = [];
	var dialog : Dialog;

	var isPlayMode = false;
	var hasNextDialog = false;

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

		if (e.keycode == Key.space) { //new word

			dialog.addWord(new Word({
					strokes:curWord,
					baseline:baseline, //this should really be preprocessed instead of part of the constructor
					topline:topline
				}));

			curWord = [];
		}

		if (isPlayMode) {
			if (e.keycode == Key.down) {
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
			if (e.keycode == Key.enter) { //add new sentence
				dialog.newSentence();
			}
			if (e.keycode == Key.rshift) { //test current sentence
				dialog.animateSentence(5);
			}
			if (e.keycode == Key.key_p) { //enter play mode
				isPlayMode = true;
				dialog.beginDialog();
				hasNextDialog = dialog.showNext();
			}
		}

	} //onkeyup

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

/*
typedef DialogOptions = {
	> EntityOptions,
	@:optional var words : Array<Word>;
}
*/

//TOOD: make this a real class
class Dialog extends Entity {
	public var curSentence (get,null) : Array<Word>;
	var sentences : Array<Array<Word>> = [];
	var sentenceIndex = 0;

	var dialogWidth = 650;
	var wordHeight = 50;
	var spaceWidth = 20;

	public override function new(options:EntityOptions) {
		super(options);
		sentences.push([]);
	}

	public function addWord(w:Word) {
		w.parent = this;
		w.height = wordHeight;
		w.pos = new Vector(0,0);

		var wordPos = new Vector(0, 0);
		if (curSentence.length > 0) {
			var prevWord = curSentence[curSentence.length-1];
			if (prevWord.pos.x + w.width > dialogWidth) {
				w.pos.y = prevWord.pos.y + (wordHeight + 20);
			}
			else {
				w.pos.y = prevWord.pos.y;
				w.pos.x = prevWord.pos.x + prevWord.width + spaceWidth;
			}
		}

		curSentence.push(w);
	}

	//seems dumb
	public function returnToEditing() {
		sentenceIndex = sentences.length - 1;
		showSentence(sentenceIndex);
	}

	public function beginDialog() {
		var i = 0;
		for (s in sentences) {
			hideSentence(i);
			i++;
		}
		sentenceIndex = -1;
	}

	public function showNext() : Bool {
		if (sentenceIndex >= 0) hideSentence(sentenceIndex);
		sentenceIndex++;
		if (sentenceIndex < sentences.length) {
			showSentence(sentenceIndex);
			animateSentence(5);
		}
		return sentenceIndex < sentences.length;
	}

	//includes some assumptions for the editor
	public function newSentence() {
		hideSentence(sentenceIndex);
		sentences.push([]);
		sentenceIndex++;
	}

	function showSentence(i:Int) {
		for (w in sentences[i]) {
			w.visible = true;
		}
	}

	function hideSentence(i:Int) {
		for (w in sentences[i]) {
			w.visible = false;
		}
	}

	public function animateSentence(t:Float) {
		var animateSentenceControl = {
			delta : 0.0
		};
		Actuate.tween(animateSentenceControl, t, {delta:1.0*curSentence.length})
			.onUpdate(function() {
				var curDelta = animateSentenceControl.delta;
				for (word in curSentence) {
					word.drawIncomplete(curDelta);
					curDelta -= 1.0;
				}
			});
	}

	public function get_curSentence() : Array<Word> {
		return sentences[sentenceIndex];
	}
}

