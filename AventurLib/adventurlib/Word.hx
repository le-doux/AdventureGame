package adventurlib;
import luxe.Visual;
import luxe.Vector;
import luxe.options.VisualOptions;
using adventurlib.PolylineExtender;

typedef WordOptions = {
	> VisualOptions,
	@:optional var strokes : Array<Polystroke>;
	@:optional var baseline : Float;
	@:optional var topline : Float;
}

class Word extends Visual {
	var strokes : Array<Polystroke>;
	var totalPoints : Int;
	var initialBounds : Vector;

	public var width (default, null) : Float; //computed
	public var height (default, set) : Float;

	public override function new (_options:WordOptions) {
		_options.no_geometry = true; //doesn't have its own geometry (switch to Entity?)
		super(_options);
		if (_options.strokes != null) initStrokes(_options);
	}

	//hacky way to reuse code
	function initStrokes(_options:WordOptions) {
		strokes = _options.strokes;
		//calculations need to find bounds of the strokes
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

		if (_options.baseline != null && _options.topline != null) { //case 1: strokes need to be realigned
			topLeft.y = _options.topline;
			initialBounds = Vector.Subtract(bottomRight, topLeft);
			var heightAboveBaseline = _options.baseline - topLeft.y;

			for (s in strokes) {
				s.pos.subtract(topLeft); //align strokes with (0, 0) origin
				s.pos.y -= heightAboveBaseline; //then move above baseline
				s.parent = this;
				totalPoints += s.points.length;
			}
		}
		else { //case 2: strokes already correctly positioned relative to parent
			initialBounds = Vector.Subtract(bottomRight, topLeft);
			for (s in strokes) {
				s.parent = this;
				totalPoints += s.points.length;
			}
		}
	}

	public function set_height(h:Float) : Float {
		height = h;
		var boundsResizeRatio = height / initialBounds.y;
		width = initialBounds.x * boundsResizeRatio;
		scale.multiplyScalar(boundsResizeRatio); //fit word to current word height
		return height;
	}

	public function drawIncomplete(delta:Float) { //weird function name
		var curPoint = delta * totalPoints;
		for (s in strokes) {
			var d = curPoint / s.points.length;
			s.drawIncomplete(d);
			curPoint -= s.points.length;
		}
	}

	public function drawComplete() {
		drawIncomplete(1.0);
	}

	override public function set_visible(v:Bool) : Bool {
		visible = v;
		for (s in strokes) {
			s.visible = v;
		}
		return visible;
	}

	public function toJson() {
		var jsonStrokes = [];
		for (s in strokes) {
			jsonStrokes.push(s.toJson());
		}
		return {
			strokes : jsonStrokes
		};
	}

	public function fromJson(json) : Word {
		var jsonStrokes = [];
		for (j in cast(json.strokes, Array<Dynamic>)) {
			var p = new Polystroke(
							{
								batcher:Luxe.renderer.batcher,
								depth:50 //arbitrary
							},
						[]).fromJson(j);
			jsonStrokes.push(p);
		}
		initStrokes({
			strokes: jsonStrokes
		});
		return this;
	}
}