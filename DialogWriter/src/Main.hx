import adventurlib.*;

import luxe.Input;
import luxe.Color;
import luxe.Visual;
import luxe.Vector;
import luxe.options.VisualOptions;

class Main extends luxe.Game {

	var baseline = 500;

	var dialogBox = {
		origin: new Vector(50, 50),
		width: 500,
		wordHeight: 50 
	};

	var curStroke : Array<Vector> = [];
	var curWord : Array<Polystroke> = [];
	var curSentence : Array<Word> = [];

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
        	var newWord = new Word({pos:new Vector(0, 0), size:new Vector(100,100), strokes:curWord, height:dialogBox.wordHeight});
        	curWord = [];
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
}

class Word extends Visual {
	var strokes : Array<Polystroke>;

	public override function new (_options:WordOptions) {
		_options.no_geometry = true; //doesn't have its own geometry (switch to Entity?)
		super(_options);
		strokes = _options.strokes;

		var topLeft = new Vector(strokes[0].points[0].x, strokes[0].points[0].y);
		var bottomRight = new Vector(strokes[0].points[0].x, strokes[0].points[0].y);
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
		//var boundsResized = Vector.Multiply(bounds, boundsResizeRatio);
		trace(topLeft);

		for (s in strokes) {
			s.pos.subtract(topLeft); //align strokes with (0, 0) origin
			//s.scale.multiplyScalar(boundsResizeRatio); //don't think this will work for real
			s.parent = this;
		}
	}
}