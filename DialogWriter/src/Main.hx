import adventurlib.*;

import luxe.Input;
import luxe.Color;
import luxe.Visual;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.options.VisualOptions;

class Main extends luxe.Game {

	var baseline = 500;

	var dialogBox = {
		origin: new Vector(100, 100),
		width: 700,
		wordHeight: 50,
		spaceWidth: 20,
		curLine: 0 
	};

	var curStroke : Array<Vector> = [];
	var curWord : Array<Polystroke> = [];
	var curSentence : Array<Word> = [];

	var animateSentenceDelta = 0.0;

	override function ready() {

		Luxe.renderer.clear_color = new Color(0.3,0.5,1);

		Luxe.draw.line({
			p0: new Vector(0,baseline), p1: new Vector(Luxe.screen.width,baseline)
		});
	} //ready

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

		if (e.keycode == Key.space) { //new word

			var wordPos = new Vector(dialogBox.origin.x, dialogBox.origin.y);
			if (curSentence.length > 0) {
				var prevWord = curSentence[curSentence.length-1];
				wordPos = Vector.Add(prevWord.pos, new Vector(prevWord.width + dialogBox.spaceWidth, 0));
			}

			var newWord = new Word({
				pos:wordPos,
				strokes:curWord, 
				height:dialogBox.wordHeight, //should these go in the constructor?
				baseline:baseline //should these go in the constructor?
			});
			
			if (newWord.pos.x + newWord.width > dialogBox.origin.x + dialogBox.width) {
				dialogBox.curLine++;
				newWord.pos = new Vector(dialogBox.origin.x, dialogBox.origin.y + ((dialogBox.wordHeight + 20) * dialogBox.curLine));
			}

			curSentence.push(newWord);
			curWord = [];
		}

		if (e.keycode == Key.enter) {
			animateSentenceDelta = 0.0;
			Actuate.tween(this, 5, {animateSentenceDelta:1.0*curSentence.length})
				.onUpdate(function() {
					var curDelta = animateSentenceDelta;
					for (word in curSentence) {
						word.drawIncomplete(curDelta);
						curDelta -= 1.0;
					}
				});
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

typedef WordOptions = {
	> VisualOptions,
	var strokes : Array<Polystroke>;
	var height : Float;
	var baseline : Float;
}

class Word extends Visual {
	var strokes : Array<Polystroke>;
	public var width : Float; //computed
	var totalPoints : Int;

	public override function new (_options:WordOptions) {
		_options.no_geometry = true; //doesn't have its own geometry (switch to Entity?)
		super(_options);
		strokes = _options.strokes;

		var p0 = strokes[0].points[0];
		var p0_inWorld = (new Vector(p0.x,p0.y)).transform(strokes[0].transform.world.matrix);
		var topLeft = new Vector(p0_inWorld.x, p0_inWorld.y); //stops aliasing problem
		var bottomRight = new Vector(p0_inWorld.x, p0_inWorld.y);

		for (s in strokes) {
			for (p in s.points) {
				var p_inWorld = (new Vector(p.x,p.y)).transform(s.transform.world.matrix); //all this copying feels like a flaw in the framework
				if (p_inWorld.x < topLeft.x) topLeft.x = p_inWorld.x;
				if (p_inWorld.y < topLeft.y) topLeft.y = p_inWorld.y;
				if (p_inWorld.x > bottomRight.x) bottomRight.x = p_inWorld.x;
				if (p_inWorld.y > bottomRight.y) bottomRight.y = p_inWorld.y;
			}
		}

		var bounds = Vector.Subtract(bottomRight, topLeft);
		var boundsResizeRatio = _options.height / bounds.y; //should this resize operation really go in here?

		var heightAboveBaseline = _options.baseline - topLeft.y;

		width = bounds.x * boundsResizeRatio; //computed, but never updated so far

		for (s in strokes) {
			s.pos.subtract(topLeft); //align strokes with (0, 0) origin
			s.pos.y -= heightAboveBaseline; //then move above baseline
			s.parent = this;
			totalPoints += s.points.length;
		}
		scale.multiplyScalar(boundsResizeRatio); //fit word to current word height
	}

	public function drawIncomplete(delta:Float) {
		var curPoint = delta * totalPoints;
		for (s in strokes) {
			var d = curPoint / s.points.length;
			s.drawIncomplete(d);
			curPoint -= s.points.length;
		}
	}
}