package adventurlib;

import luxe.Vector;
import luxe.Transform;
import luxe.utils.Maths;

class VectorExtender {
	static public function distance(pos1:Vector, pos2:Vector) : Float {
		return Vector.Subtract(pos1, pos2).length;
	}

	static public function cross2D(v1:Vector, v2:Vector) : Float {
		return (v1.x * v2.y) - (v1.y * v2.x);
	}

	//these two functions are probably unnecessary
	static public function toLocalSpace(v:Vector, t:Transform) : Vector {
		var localV : Vector;
		localV = v.clone().transform(t.world.matrix.inverse());
		return localV;
	}

	static public function toWorldSpace(v:Vector, t:Transform) : Vector {
		var worldV : Vector;
		worldV = v.clone().transform(t.world.matrix);
		return worldV;
	}

	static public function absolute(v:Vector) : Vector {
		return new Vector(Math.abs(v.x), Math.abs(v.y));
	}

	static public function setFromAngle(v:Vector, radians:Float) : Vector {
		v = new Vector(Math.cos(radians), Math.sin(radians));
		return v;
	}

	static public function tangent2D(v:Vector) : Vector {
		return new Vector(-v.y, v.x);
	}

	static public function closestPointOnLine(v:Vector, a:Vector, b:Vector) : Vector {
		var ab = Vector.Subtract(b, a);
		var av = Vector.Subtract(v, a);

		var d = Maths.clamp(av.dot(ab.normalized), 0.0, ab.length);

		return Vector.Add( a, Vector.Multiply(ab.normalized, d) );
	}

	static public function fromJson(v:Vector, json) : Vector {
		v = new Vector(json.x, json.y);
		return v;
	}

	static public function toJson(v:Vector) {
		return {
			x : v.x,
			y : v.y
		};
	}
}