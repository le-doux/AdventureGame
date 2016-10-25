package vexlib;

import luxe.Vector;
import luxe.utils.Maths;

import vexlib.Vex;
import vexlib.VexPropertyInterface;

/* STAGE */
typedef ExitFormat = {
	public var pos : Property;
	public var destination : Property;
}

typedef StageFormat = {
	@:optional public var type : Property;
	@:optional public var id : Property;
	@:optional public var path : Property;
	@:optional public var exits : Array<ExitFormat>;
	@:optional public var background : Property;
	@:optional public var scenery : VexJsonFormat;
	//todo sceneryRef (rename?)
}

class Stage {
	public var id : Null<Property>;
	public var path : Property;
	public var scenery : Vex;
	public var background : Null<Property>;

	public function new(?json:StageFormat) {
		if (json != null) {
			//load stage from json
			deserialize(json);
		}
		else {
			//empty stage
			scenery = new Vex({
					type: "group",
					origin: "0,0",
					pos: "0,0"
				});
		}
	}

	//todo make real
	public function registerDescription( d : luxe.Component ) {
		//TODO make this a real and better thing
		//TODO actually can't the description handle all this logic? maybe not?
		trace("description registered!");
	}

	public function deserialize(json:StageFormat) {
		if (json.id != null) id = json.id;
		if (json.path != null) path = json.path;
		//todo exits
		
		trace("STAAAAGE BG");
		trace(json.background);
		if (json.background != null) background = json.background;
		trace(background);
		trace("STAAAAGE BG");

		if (json.scenery != null) {
			scenery = new Vex(json.scenery);
		}
	}

	public function serialize() : StageFormat {
		var json : StageFormat = {};
		json.type = "stage"; //always the same type
		if (id != null) json.id = id;
		json.path = path;
		//todo exits
		if (background != null) json.background = background;
		json.scenery = scenery.serialize();
		return json;
	}


	public function edgeCollisionLeft(x:Float) {
		return x <= 0;	
	}

	public function edgeCollisionRight(x:Float) {
		return x >= pathLength(path);
	}

	public function clampToStage(x:Float) {
		return Maths.clamp(x, 0, pathLength(path));
	}

	public function worldPos(x:Float) {
		return worldPosFromPathPos(path, x);
	}



	/* crazy old terrain stuff */
	function worldPosFromPathPos(path:Array<Vector>, pos : Float) : Vector {
		var segIndex = closestIndexToLeft(path, pos);

		//capture edge cases
		if (segIndex < 0) {
			return new Vector(path[0].x, path[0].y);
		}
		if (segIndex >= path.length-1) {
			return new Vector(path[path.length-1].x, path[path.length-1].y);
		}

		var leftoverDist = (pos - pathLengthToPoint(path, segIndex));
		var leftoverDistPercent = leftoverDist / xDistToNextPoint(path, segIndex);
		var seg0 = path[segIndex];
		var seg1 = path[segIndex+1];
		var segDelt = Vector.Subtract(seg1, seg0);
		var segDeltPercent = Vector.Multiply(segDelt, leftoverDistPercent);

		var worldPos = Vector.Add(seg0, segDeltPercent);

		return worldPos;
	}

	function pathLength(path:Array<Vector>) {
		return pathLengthToPoint(path, path.length-1);
	}

	function pathLengthToPoint(path : Array<Vector>, i : Int) : Float {
		var startX = path[0].x;
		return (path[i].x - startX);
	}

	function xDistToNextPoint(path:Array<Vector>, i : Int) : Float {
		return Math.abs(path[i].x - path[i+1].x);
	}

	//needs a better name
	//also: inefficient as fuck
	function closestIndexToLeft(path:Array<Vector>, x : Float) : Int {
		var startX = path[0].x; //feels pretty hacky
		var closestIndex = 0;
		for (i in 1 ... path.length) {
			var dist = x - (path[i].x - startX);
			var prevDist = x - (path[closestIndex].x - startX);
			if ( dist > 0 && dist < prevDist ) {
				closestIndex = i;
			}
		}
		return closestIndex;
	}

}