import adventurlib.*;

import luxe.Vector;

using adventurlib.VectorExtender;
using TerrainEditor;

class TerrainEditor {

	static public var MinimumEditDistance : Float = 20;

	static public function removeEndPoint(t : Terrain) : Terrain {
		t.points.remove( t.points[t.points.length - 1] );
		return t;
	}	

	static public function removeStartPoint(t : Terrain) : Terrain {
		t.points.remove( t.points[0] );
		return t;
	}

	static public function addPoint(t : Terrain, p : Vector) : Terrain {
		if (p.x > t.points[t.points.length - 1].x) {
			t.points.push(p); //insert at end
		}
		else if (p.x < t.points[0].x) {
			t.points.insert(0, p); //insert at beginning
		}
		else {
			trace("error - point would be inside existing terrain");
		}
		return t;
	}

	static public function buildTerrain(t : Terrain, p : Vector) : Terrain {
		var i = t.closestIndexHorizontally(p.x);
		var xDist = Math.abs(t.points[i].x - p.x);
		if (xDist < TerrainEditor.MinimumEditDistance) {
			t.points[i].y = p.y; //only change height
		}
		else {
			t.addPoint(p);
		}
		return t;
	}

	static public function buildTerrainAlongLine(t : Terrain, p0 : Vector, p1 : Vector) : Terrain {
		var deltaV = Vector.Subtract(p1, p0);
		var steps = Math.ceil( Math.abs(p0.x - p1.x) / MinimumEditDistance );
		for (i in 0 ... steps) {
			var d = i / cast(steps, Float);
			var p = Vector.Add(p0, Vector.Multiply(deltaV, d));
			t.buildTerrain(p);
		}
		t.buildTerrain(p1);
		return t;
	}

	//equivalent function for when you only have one point (ex: on mouse down)
	static public function buildTerrainToPoint(t : Terrain, p : Vector) : Terrain {		
		var p0 = p;
		if (p.x > t.points[t.points.length - 1].x) {
			p0 = t.points[t.points.length - 1];
		}
		else if (p.x < t.points[0].x) {
			p0 = t.points[0];
		}

		t.buildTerrainAlongLine(p0, p);

		return t;
	}
}