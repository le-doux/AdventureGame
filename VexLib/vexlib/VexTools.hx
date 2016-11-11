package vexlib;

import luxe.Vector;
import luxe.Transform;
import luxe.Color;
import luxe.utils.Maths;
import phoenix.geometry.Vertex;
import phoenix.geometry.Geometry;

/*
	Generally useful methods for manipulating parts of the vex format
*/

class VexTools {

	//TODO serializeVex, parseVex, serializeVPI, parseVPI
	//TODO rename all blankToBlank in form serialize*, parse*
	
	/*
		Wraps poly2tri library polygon-to-mesh algorithm
	*/
	public static function pathToMesh( path:Array<Vector> ) : {triangles:Array<Int>,vertices:Array<Float>} {
		//convert luxe vectors into poly2try points
		var p2tpath = [];
		for (v in path) {
			p2tpath.push( new org.poly2tri.Point(v.x, v.y) );
		}

		//get mesh data generated by poly2tri
		var p2t = new org.poly2tri.VisiblePolygon();
		p2t.addPolyline( p2tpath );
		p2t.performTriangulationOnce();
		var results = p2t.getVerticesAndTriangles();

		//return mesh data
		return results;
	}

	/*
		Adds mesh data to a geometry object and returns it
	*/
	public static function addTrianglesToGeometry( geometry:Geometry, mesh:{triangles:Array<Int>,vertices:Array<Float>} ) : Geometry {
		var i = 0;
		while (i < mesh.triangles.length) {
			for (j in i ... (i+3)) {
				var vIndex = mesh.triangles[j] * 3;

				var x = mesh.vertices[vIndex + 0];
				var y = mesh.vertices[vIndex + 1];
				var z = mesh.vertices[vIndex + 2];

				var vertex = new Vertex(new Vector(x, y, z));

				geometry.add(vertex); 
			}

			i += 3;
		}
		return geometry;
	}

	/*
		Adds an array of points to geometry and returns it
	*/
	public static function addLineToGeometry( geometry:Geometry, line:Array<Vector> ) : Geometry {
		for (i in 1 ... line.length) {
			geometry.add(new Vertex(line[i-1]));
			geometry.add(new Vertex(line[i-0]));
		}
		return geometry;
	}

	public static function addMultilineToGeometry( geometry:Geometry, multiline:Array<Array<Vector>> ) : Geometry {
		for (line in multiline) {
			geometry = addLineToGeometry(geometry, line);
		}
		return geometry;
	}

	//TODO not currently using this; should I remove it?
	/*
		Convert a line into vertices for a series of quads
	*/
	public static function lineToQuadMesh( line:Array<Vector>, width:Float ) {
		var quad = {
			vertices : []
		};

		if (line.length >= 2) {
			var left0 : Vector = null;
			var right0 : Vector = null;
			var left1 : Vector = null;
			var right1 : Vector = null;

			for (i in 2 ... line.length) {
				var p0 = line[i-2];
				var p1 = line[i-1];
				var p2 = line[i-0];

				var p0_to_p1 = Vector.Subtract(p1, p0);
				var p1_to_p2 = Vector.Subtract(p2, p1);
				var unitForward = Vector.Add( p0_to_p1.normalized, p1_to_p2.normalized ).normalized;
				var radiansForward = unitForward.angle2D;
				var degreesForward = Maths.degrees(radiansForward);
				var degreesRight = degreesForward + 90;
				var radiansRight = Maths.radians(degreesRight);
				var unitRight = (new Vector(1,0));
				unitRight.angle2D = radiansRight;
				var rightward = Vector.Multiply(unitRight, width);
				var leftward = Vector.Multiply(rightward, -1);

				//todo
				if (i-2 == 0) {
					// FIRST QUAD //
					var unitForward0 = p0_to_p1.normalized;
					var radiansForward0 = unitForward0.angle2D;
					var degreesForward0 = Maths.degrees(radiansForward0);
					var degreesRight0 = degreesForward0 + 90;
					var radiansRight0 = Maths.radians(degreesRight0);
					var unitRight0 = (new Vector(1,0));
					unitRight0.angle2D = radiansRight0;
					var rightward0 = Vector.Multiply(unitRight0, width);
					var leftward0 = Vector.Multiply(rightward0, -1);

					left0 = Vector.Add(p0, leftward0);
					right0 = Vector.Add(p0, rightward0);
				}
				else {
					// MIDDLE QUADS //
					left0 = left1;
					right0 = right1;
				}

				left1 = Vector.Add(p1, leftward);
				right1 = Vector.Add(p1, rightward);

				//line segment quad
				quad.vertices.push( left0 ); //left triangle
				quad.vertices.push( right0 );
				quad.vertices.push( left1 );
				quad.vertices.push( right0 ); //right triangle
				quad.vertices.push( left1 );
				quad.vertices.push( right1 );

				if (i == line.length-1) {
					// LAST QUAD //
					var unitForward2 = p1_to_p2.normalized;
					var radiansForward2 = unitForward2.angle2D;
					var degreesForward2 = Maths.degrees(radiansForward2);
					var degreesRight2 = degreesForward2 + 90;
					var radiansRight2 = Maths.radians(degreesRight2);
					var unitRight2 = (new Vector(1,0));
					unitRight2.angle2D = radiansRight2;
					var rightward2 = Vector.Multiply(unitRight2, width);
					var leftward2 = Vector.Multiply(rightward2, -1);

					var left2 = Vector.Add(p2, leftward2);
					var right2 = Vector.Add(p2, rightward2);

					//line segment quad
					quad.vertices.push( left1 ); //left triangle
					quad.vertices.push( right1 );
					quad.vertices.push( left2 );
					quad.vertices.push( right1 ); //right triangle
					quad.vertices.push( left2 );
					quad.vertices.push( right2 );
				}

			}
		}

		return quad;
	}

	//TODO can be used for other classes; rename?
	public static function jsonToComponent(json:Dynamic) {
		var classType = Type.resolveClass( json.type );
		var componentInstance = Type.createInstance( classType, [json] );
		return componentInstance;
	}

	public static function vectorToString(v:Vector) : String {
		return v.x + "," + v.y;
	}

	public static function stringToVector(str:String) : Vector {
		var coords = str.split(",");
		var x = Std.parseFloat(coords[0]);
		var y = Std.parseFloat(coords[1]);
		return new Vector(x,y);
	}

	public static function pathToString(path:Array<Vector>) : String {
		var pathStr = "";
		for (i in 0 ... path.length) {
			var p = path[i];
			pathStr += vectorToString(p);
			if (i < path.length - 1) {
				pathStr += " ";
			}
		}
		return pathStr;
	}

	public static function stringToPath(str:String) : Array<Vector> {
		if (str.indexOf("Z") != -1) { //if it has a Z, it's really a multipath; return the first path
			return stringToMultipath(str)[0]; //kind of hacky, but works nice as a fallback
		}

		var path : Array<Vector> = [];
		var points = str.split(" ");
		for (p in points) {
			path.push( stringToVector(p) );
		}
		return path;
	}

	public static function multipathToString(multipath:Array<Array<Vector>>) : String {
		var multipathStr = "";
		for (path in multipath) {
			multipathStr += pathToString(path);
			multipathStr += " Z ";
		}
		return multipathStr;
	}

	public static function stringToMultipath(str:String) : Array<Array<Vector>> {
		var multipath : Array<Array<Vector>> = [];
		var paths = str.split("Z");
		for (p in paths) {
			multipath.push( stringToPath(p) );
		}
		return multipath;
	}

	public static function stringToHexColor(str:String) : Color {
		//hack off the #
		if (str.charAt(0) == "#") {
			str = str.substring(1);
		}

		//build a haxe-compatible hex format string from the input string 
		var hexStr = "0x";
		if (str.length == 3) {
			//double the compressed hex code (e.g. #fa0 -> #ffaa00)
			hexStr += str.charAt(0) + str.charAt(0) + 
						str.charAt(1) + str.charAt(1) +
						str.charAt(2) + str.charAt(2);
		}
		else if (str.length == 6) {
			//uncompressed hex code
			hexStr += str;
		}
		else {
			//fallback to magenta (an obvious color) if it isn't valid
			hexStr += "ff00ff";
		}

		//convert hex string into RGB values
		var hexInt = Std.parseInt( hexStr );
		var r = ( (hexInt >> 16) & 0xff ) / 255;
		var g = ( (hexInt >>  8) & 0xff ) / 255;
		var b = ( (hexInt >>  0) & 0xff ) / 255;

		return new Color(r,g,b);
	}

	//TODO assumes the palette is initialized
	//TODO I should create some kind of Color sub-class that is a palette color & handles palette change events & missing palettes
	public static function stringToPaletteColor(str:String) : Color {
		var paletteIndex = Std.parseInt( str );
		return Palette.Colors[ paletteIndex ];
	}

	public static function stringToRgbColor(str:String) : Color {
		var rgbArray = str.split(",");
		var r = Std.parseFloat( rgbArray[0] );
		var g = Std.parseFloat( rgbArray[1] );
		var b = Std.parseFloat( rgbArray[2] );
		var color = new Color(r/255, g/255, b/255);
		if (rgbArray.length > 3) {
			var a = Std.parseFloat( rgbArray[3] );
			color.a = a;
		}
		return color;
	}

	public static function stringToHslColor(str:String) : Color {
		var hslArray = str.split(",");
		var h = Std.parseFloat( hslArray[0] );
		var s = Std.parseFloat( hslArray[1] );
		var l = Std.parseFloat( hslArray[2] );
		var color = new ColorHSL(h/255, s/255, l/255);
		if (hslArray.length > 3) {
			var a = Std.parseFloat( hslArray[3] );
			color.a = a;
		}
		return color;
	}

	public static function stringToColor(str:String) : Color {
		/* HEX COLOR */
		if (str.charAt(0) == "#") {
			return stringToHexColor( str );
		}

		var r = ~/[\(\)]/;
		var colorArguments = r.split( str );
		var formatStr = colorArguments[0];
		var colorStr = colorArguments[1];

		/* PALETTE COLOR */
		if (formatStr == "pal") {
			return stringToPaletteColor( colorStr );
		}
		/* RGB COLOR */
		else if (formatStr == "rgb") { 
			return stringToRgbColor( colorStr );
		}
		/* HSL COLOR */
		else if (formatStr == "hsl") {
			return stringToHslColor( colorStr );
		}

		/* DEFAULT COLOR */
		return new Color(1,0,1); //magenta
	}

	//TODO make compatible with palette colors too (override a toString method?)
	public static function colorToString(color:Color) : String {
		return "rgb(" + color.r + "," + color.g + "," + color.b + ")";
	}

	public static function findBoundingBox(path:Array<Vector>) : Array<Vector> {
		if (path.length > 0) {
			var xMin = path[0].x;
			var xMax = path[0].x;
			var yMin = path[0].y;
			var yMax = path[0].y;
			for (p in path) {
				if (p.x < xMin) xMin = p.x;
				if (p.x > xMax) xMax = p.x;
				if (p.y < yMin) yMin = p.y;
				if (p.y > yMax) yMax = p.y;
			}

			var x = xMin;
			var y = yMin;
			var w = xMax - xMin;
			var h = yMax - yMin;
			var vertices:Array<Vector> = [];
			vertices.push( new Vector(x,y) );
			vertices.push( new Vector(x+w,y) );
			vertices.push( new Vector(x+w,y+h) );
			vertices.push( new Vector(x,y+h) );

			return vertices;
		}
		return [new Vector(0,0), new Vector(0,0), new Vector(0,0), new Vector(0,0)]; //degenerate case
	}

	public static function getVexChildren(parent:Vex) : Array<Vex> {
		var vexChildren = [];
		//find children that are of type Vex
		if (parent.children != null && parent.children.length > 0) {
			for (c in parent.children) {
				if (Std.is(c, Vex)) {
					vexChildren.push( cast(c,Vex) );
				}
			}
		}
		//sort by depth
		vexChildren.sort(
			function(a,b) {
				if (a.depth > b.depth) return -1;
				if (a.depth < b.depth) return 1;
				return 0;
			});
		return vexChildren;
	}

	public static function findVexById(root:Vex, id:String) : Array<Vex> {
		var results = [];
		if (root.properties.id == id) {
			results.push( root );
		}
		for (c in getVexChildren(root)) {
			results = results.concat( findVexById(c,id) );
		}
		return results;
	}

	//TODO do these belong in a dedicated vector or transform extension?
	public static function vectorToLocalSpace(t:Transform, p:Vector) : Vector {
		return p.clone().applyProjection( t.world.matrix.inverse() );
	}

	public static function vectorToWorldSpace(t:Transform, p:Vector) : Vector {
		return p.clone().applyProjection( t.world.matrix );
	}

	public static function vectorToParentSpace(t:Transform, p:Vector) : Vector {
		return p.clone().applyProjection( t.local.matrix );
	}


	public static function pathToWorldSpace(t:Transform, pathArray:Array<Vector>) : Array<Vector> {
		var worldPath = [];
		for (p in pathArray) {
			worldPath.push( vectorToWorldSpace(t,p) );
		}
		return worldPath;
	}

	public static function pathToParentSpace(t:Transform, pathArray:Array<Vector>) : Array<Vector> {
		var worldPath = [];
		for (p in pathArray) {
			worldPath.push( vectorToParentSpace(t,p) );
		}
		return worldPath;
	}

	//TODO Vex.isPointInside 

}