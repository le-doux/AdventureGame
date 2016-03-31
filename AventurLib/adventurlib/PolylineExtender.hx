package adventurlib;

import luxe.Vector;
import luxe.Transform;
import luxe.utils.Maths;
import luxe.collision.shapes.Polygon in PolygonCollisionShape;

using adventurlib.VectorExtender;
using adventurlib.PolylineExtender;

class PolylineExtender {
	static public function closestIndex(points:Array<Vector>, otherPoint:Vector) : Int {
		var closestIndex = 0;
		for (i in 0 ... points.length) {
			if (otherPoint.distance(points[i]) < otherPoint.distance(points[closestIndex])) {
				closestIndex = i;
			}
		}
		return closestIndex;
	}

	static public function closestVertex(points:Array<Vector>, otherPoint:Vector) : Vector {
		return points[points.closestIndex(otherPoint)];
	}

	static public function closestPoint(points:Array<Vector>, otherPoint:Vector) : Vector {

		var closestPoint = points[0].clone();

		for (i in 0 ... points.length - 1) {

			var a = points[i];
			var b = points[i+1];

			var p = otherPoint.closestPointOnLine( a, b );

			if ( otherPoint.distance(p) < otherPoint.distance(closestPoint) ) {
				closestPoint = p;
			}
		}

		return closestPoint;

	}

	static public function clone(points:Array<Vector>) : Array<Vector> {
		var polylineClone = [];
		for (p in points) {
			polylineClone.push(p.clone());
		}
		return polylineClone;
	}

	static public function makeCirclePolyline(points:Array<Vector>, center:Vector, radius:Float, ?steps:Int) {
		points = [];
		if (steps == null) steps = 60;
		for (i in 0 ... steps) {
			var degrees : Float = (i / steps) * 360.0;
			var pDir = (new Vector()).setFromAngle(Maths.radians(degrees));
			var p = Vector.Add(center, pDir.multiplyScalar(radius));
			points.push(p);
		}
		return points;
	}

	static public function toLocalSpace(points:Array<Vector>, t:Transform) : Array<Vector> {
		return points.clone().map( function(p) { return p.toLocalSpace(t); } );
	}

	static public function toWorldSpace(points:Array<Vector>, t:Transform) : Array<Vector> {
		return points.clone().map( function(p) { return p.toWorldSpace(t); } );
	}

	//what is this doing in polyline extender?
	static public function testLineIntersection(a:Vector, b:Vector, c:Vector, d:Vector) {
		var p = a;
		var q = c;

		var r = Vector.Subtract(b, a);
		var s = Vector.Subtract(d, c);

		var qMinusP = Vector.Subtract(q, p);

		var rCrossS = r.cross2D(s);

		if (rCrossS != 0) {
			var t = qMinusP.cross2D(s) / rCrossS;
			var u = qMinusP.cross2D(r) / rCrossS;

			if (t <= 1 && t >= 0 && u <= 1 && u >= 0) {
				var rTimesT = Vector.Multiply(r, t);
				var result = Vector.Add(p, rTimesT);
				return {intersects: true, intersectionPoint: result};
			}
		}

		return {intersects: false, intersectionPoint: null};
	}

	static public function polylineIntersections(points:Array<Vector>) {
		var intersectionList = [];

		if (points.length >= 2) {
			for (i in 0 ... (points.length - 1)) {
				var a = points[i];
				var b = points[i+1];

				for (j in (i+2) ... (points.length - 1)) { //(i+2) is a hack to avoid colliding with next connected line segment
					var c = points[j];
					var d = points[j+1];

					var test = testLineIntersection(a,b,c,d);
					if (test.intersects) {
						intersectionList.push({point: test.intersectionPoint, lineIndex1: i, lineIndex2: j});
					}
				}
			}
		}

		return {intersects: intersectionList.length > 0, intersectionList: intersectionList};
	}

	static public function polylineSplit(points:Array<Vector>, intersection:{point:Vector, lineIndex1:Int, lineIndex2:Int}) {
		//construct closed loop created by intersection
		var closedLoop = points.slice(intersection.lineIndex1+1, intersection.lineIndex2+1);
		closedLoop.push(intersection.point);

		//construct remaining open line
		var openLine = points.slice(0, intersection.lineIndex1+1);
		openLine.push(intersection.point);
		openLine.concat(points.slice(intersection.lineIndex2+1));

		//return the two new lines
		return {openLine: openLine, closedLine: closedLoop};
	}

	static public function polylineCenter(points:Array<Vector>) {
		var center = new Vector(0,0);
		for (p in points) {
			center.add(p);
		}
		if (points.length > 0) center.divideScalar(points.length);
		return center;
	}

	static public function collisionShape(points:Array<Vector>, pos:Vector) {
		return new PolygonCollisionShape(pos.x, pos.y, points.clone());
	}

	//is this function still necessary with toJson?
	static public function toFloatArray(points:Array<Vector>) : Array<Float> {
		var arr = [];
		for (p in points) {
			arr.push(p.x);
			arr.push(p.y);
		}
		return arr;
	}

	static public function toJson(points:Array<Vector>) {
		var arr = [];
		for (p in points) {
			arr.push(p.toJson());
		}
		return arr;
	}

	static public function fromJson(points:Array<Vector>, json : Array<Dynamic>) : Array<Vector> {
		points = [];
		for (j in json) {
			var v = (new Vector()).fromJson(j);
			points.push( v );
		}
		return points;
	}
}