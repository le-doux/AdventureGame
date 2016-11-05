package vexlib;

import luxe.Vector;
import luxe.Color;
import luxe.Visual;
import luxe.utils.Maths;

import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import phoenix.Batcher;

typedef VexJsonFormat = { //TODO rename?
	@:optional public var type 		: Property;
	@:optional public var id 		: Property;
	@:optional public var pos 		: Property;
	@:optional public var origin 	: Property;
	@:optional public var scale 	: Property;
	@:optional public var rot 		: Property;
	@:optional public var depth		: Property;
	@:optional public var color 	: Property;
	@:optional public var path 		: Property;
	@:optional public var weight	: Property; //only for lines
	@:optional public var src 		: Property;
	@:optional public var children 	: Array<VexJsonFormat>;

	@:optional public var components : Array<ComponentJsonFormat>;

	//render time options (todo is this the right place for this? I might need to rethink the whole set up I have)
	@:optional public var batcher : Batcher;
}

typedef ComponentJsonFormat = { //TODO rename?
	> luxe.options.ComponentOptions,
	public var type : String;
}

class VexPropertyInterface {
	public var type 	(default, set) : Null<Property>;
	public var id 		(default, set) : Null<Property>;
	public var pos 		(default, set) : Null<Property>;
	public var origin 	(default, set) : Null<Property>;
	public var scale 	(default, set) : Null<Property>;
	public var rot 		(default, set) : Null<Property>;
	public var depth	(default, set) : Null<Property>;
	public var color 	(default, set) : Null<Property>;
	public var path 	(default, set) : Null<Property>;
	public var weight	(default, set) : Null<Property>;
	public var src 		(default, set) : Null<Property>;

	public var components (default, set) : Null<Array<ComponentJsonFormat>>;

	var visual : Visual;
	var batch : Batcher; //hack

	public function new(v:Visual) {
		visual = v;
	}

	public function serialize() : VexJsonFormat {
		var json : VexJsonFormat = {};
		if (type != null) 	json.type = type;
		if (id != null) 	json.id = id;
		if (pos != null) 	json.pos = pos;
		if (origin != null) json.origin = origin;
		if (scale != null) 	json.scale = scale;
		if (rot != null) 	json.rot = rot;
		if (depth != null)	json.depth = depth;
		if (color != null) 	json.color = color;
		if (weight != null) json.weight = weight;
		if (path != null) 	json.path = path;
		if (src != null) 	json.src = src;

		if (components != null) json.components = components;

		return json;
	}

	public function deserialize(json:VexJsonFormat) {
		
		batch = json.batcher; //hack

		if (json.type != null) 		type = json.type;
		if (json.id != null) 		id = json.id;
		if (json.pos != null) 		pos = json.pos;
		if (json.origin != null) 	origin = json.origin;
		if (json.scale != null) 	scale = json.scale;
		if (json.rot != null) 		rot = json.rot;
		if (json.depth != null)		depth = json.depth;
		if (json.weight != null)	weight = json.weight;
		if (json.path != null) 		path = json.path;
		if (json.color != null) 	color = json.color;
		if (json.src != null) 		src = json.src;

		if (json.components != null) components = json.components;

	}

	public function deserializeRef(json:VexJsonFormat) {
		// Properties that will be saved
		// id
		if (json.id != null && id == null) id = json.id; //is this really a good idea?

		// Properties that will NOT be saved
		// pos
		if (json.pos != null && pos == null) {
			visual.pos = json.pos;
		}
		// origin
		if (json.origin != null && origin == null) {
			visual.origin = json.origin;
		}
		// scale
		if (json.scale != null && scale == null) {
			visual.scale = json.scale;
		}
		// rot
		if (json.rot != null && rot == null) {
			visual.rotation_z = json.rot;
		}

		// Properties currently not accounted for (probably not needed at all for ref objects)
		// type
		// color
		// path
		// src
		// depth
	}

	function set_type(prop:Property) : Property {
		return type = prop;
	}

	function set_src(prop:Property) : Property {
		return src = prop; //this setter may not be necessary?
	}

	function set_id(prop:Property) : Property {
		return id = prop;
	}

	function set_pos(prop:Property) : Property {
		pos = prop;
		visual.pos = pos;
		return pos;
	}

	function set_origin(prop:Property) : Property {
		origin = prop;
		visual.origin = origin;
		return origin;
	}

	function set_scale(prop:Property) : Property {
		scale = prop;
		visual.scale = scale;
		visual.scale.z = 1; //hack to keep inverse() valid
		return scale;
	}

	function set_rot(prop:Property) : Property {
		rot = prop;
		visual.rotation_z = rot;
		return rot;
	}

	function set_depth(prop:Property) : Property {
		depth = prop;
		if (visual.parent != null) {
			var vexParent : Vex = cast(visual.parent);
			visual.depth = vexParent.depth + depth.toFloat(); //TODO toFloat() necessary?
		}
		else {
			visual.depth = depth;
		}
		return depth;
	}

	function set_color(prop:Property) : Property {
		color = prop;
		visual.color = color;
		return color;
	}

	function set_weight(prop:Property) : Property {
		return weight = prop;
	}

	function set_path(prop:Property) : Property {
		//trace(prop);
		path = prop;
		if (visual != null) {
			if (type == "poly") {

				//TODO replace VexTools

				//trace(batch.name);
				visual.geometry = new Geometry({
						primitive_type: PrimitiveType.triangles,
						//batcher: Luxe.renderer.batcher
						batcher: batch
					});

				var p2tpath = [];
				var pathAsVectors : Array<Vector> = path;
				for (v in pathAsVectors) {
					p2tpath.push( new org.poly2tri.Point(v.x, v.y) );
				}

				var p2t = new org.poly2tri.VisiblePolygon();
				p2t.addPolyline( p2tpath );
				p2t.performTriangulationOnce();
				var results = p2t.getVerticesAndTriangles();

				//TODO replace VexTools

				var i = 0;
				while (i < results.triangles.length) {
					for (j in i ... (i+3)) {
						var vIndex = results.triangles[j] * 3;

						var x = results.vertices[vIndex + 0];
						var y = results.vertices[vIndex + 1];
						var z = results.vertices[vIndex + 2];

						var vertex = new Vertex(new Vector(x, y, z));

						visual.geometry.add(vertex); 
					}

					i += 3;
				}

				//trace( visual.geometry.vertices );
			}
			else if (type == "line") { //best name? other options: stroke, outline
				/* MESH LINES */
				//multipath version
				var lines : Array<Array<Vector>> = path;

				//just make the damn geometry, it can be empty for all I care

				
				//old approach
				visual.geometry = new Geometry({
					primitive_type: PrimitiveType.lines,
					//batcher: Luxe.renderer.batcher
					batcher: batch
				});
				
				
				//new approach
				/*
				visual.geometry = new Geometry({
					primitive_type: PrimitiveType.triangles,
					batcher: Luxe.renderer.batcher
				});
				*/
				

				for (l in lines) {
					add_line_geometry(l);
				}
			}
		}
		return path;
	}

	//todo improve width at joints
	function add_line_geometry(line:Array<Vector>) {

		var pathAsVectors : Array<Vector> = line;

		//TODO replace VexTools
		//old approach
		for (i in 1 ... pathAsVectors.length) {
			visual.geometry.add(new Vertex(pathAsVectors[i-1]));
			visual.geometry.add(new Vertex(pathAsVectors[i-0]));
		}
		

		//new approach
		// MESH LINES //
		/*
		var linewidth = 1.0;
		if (weight == "regular") linewidth = 2.0; //better way to control this?
		if (weight == "thick") linewidth = 4.0;
		*/
		
		/*
		var linewidth = weight;

		if (pathAsVectors.length >= 2) {
			var left0 : Vector = null;
			var right0 : Vector = null;
			var left1 : Vector = null;
			var right1 : Vector = null;

			for (i in 2 ... pathAsVectors.length) {
				var p0 = pathAsVectors[i-2];
				var p1 = pathAsVectors[i-1];
				var p2 = pathAsVectors[i-0];

				var p0_to_p1 = Vector.Subtract(p1, p0);
				var p1_to_p2 = Vector.Subtract(p2, p1);
				var unitForward = Vector.Add( p0_to_p1.normalized, p1_to_p2.normalized ).normalized;
				var radiansForward = unitForward.angle2D;
				var degreesForward = Maths.degrees(radiansForward);
				var degreesRight = degreesForward + 90;
				var radiansRight = Maths.radians(degreesRight);
				var unitRight = (new Vector(1,0));
				unitRight.angle2D = radiansRight;
				var rightward = Vector.Multiply(unitRight, linewidth);
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
					var rightward0 = Vector.Multiply(unitRight0, linewidth);
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
				visual.geometry.add(new Vertex(left0)); //left triangle
				visual.geometry.add(new Vertex(right0));
				visual.geometry.add(new Vertex(left1));
				visual.geometry.add(new Vertex(right0)); //right triangle
				visual.geometry.add(new Vertex(left1));
				visual.geometry.add(new Vertex(right1));

				if (i == pathAsVectors.length-1) {
					// LAST QUAD //
					var unitForward2 = p1_to_p2.normalized;
					var radiansForward2 = unitForward2.angle2D;
					var degreesForward2 = Maths.degrees(radiansForward2);
					var degreesRight2 = degreesForward2 + 90;
					var radiansRight2 = Maths.radians(degreesRight2);
					var unitRight2 = (new Vector(1,0));
					unitRight2.angle2D = radiansRight2;
					var rightward2 = Vector.Multiply(unitRight2, linewidth);
					var leftward2 = Vector.Multiply(rightward2, -1);

					var left2 = Vector.Add(p2, leftward2);
					var right2 = Vector.Add(p2, rightward2);

					//line segment quad
					visual.geometry.add(new Vertex(left1)); //left triangle
					visual.geometry.add(new Vertex(right1));
					visual.geometry.add(new Vertex(left2));
					visual.geometry.add(new Vertex(right1)); //right triangle
					visual.geometry.add(new Vertex(left2));
					visual.geometry.add(new Vertex(right2));
				}

			}
		}
		*/

	}

	function set_components(componentData:Array<ComponentJsonFormat>) : Array<ComponentJsonFormat> {
		components = componentData;

		//TODO replace VexTools
		for (c in components) {
			//trace("!!!!!!");
			//trace(Type.resolveClass("AnotherTestComp"));
			//trace(c);
			var rc = Type.resolveClass(c.type);
			//trace(rc);
			var ci = Type.createInstance( rc, [c] );
			visual.add( ci );
		}

		return components;
	}

	//is this really the best way to do this?
	public function AddComponent(options:Dynamic) {
		//TODO replace VexTools
		var rc = Type.resolveClass(options.type);
		var ci = Type.createInstance( rc, [options] );
		visual.add( ci );
		if (components == null) {
			components = [];
		}
		components.push(options);
	}
}

abstract Property(String) from String to String {
	inline public function new(str:String) {
		this = str;
	}

	@:from
	static public function fromVector(v:Vector) {
		//TODO replace VexTools
		return new Property(v.x + "," + v.y);
	}

	@:to
	public function toVector() : Vector {
		//TODO replace VexTools
		var coords = this.split(",");
		var x = Std.parseFloat(coords[0]);
		var y = Std.parseFloat(coords[1]);
		return new Vector(x,y);
	}

	@:from
	static public function fromPath(path:Array<Vector>) {
		//TODO replace VexTools
		var pathStr = "";
		for (i in 0 ... path.length) {
			var p = path[i];
			var pointProp : Property = p;
			pathStr += pointProp;
			if (i < path.length - 1) {
				pathStr += " ";
			}
		}
		return new Property(pathStr);
	}

	@:to
	public function toPath() : Array<Vector> {
		if (this.indexOf("Z") != -1) { //if it has a Z, it's really a multipath
			//hacky solution for now
			return toMultiPath()[0];
		}

		var path : Array<Vector> = [];
		var points = this.split(" ");
		for (p in points) {
			var pointProp : Property = p;
			path.push(pointProp);
		}
		return path;
	}

	@:from
	static public function fromMultiPath(multipath:Array<Array<Vector>>) {
		var multiPathStr = "";
		for (p in multipath) {
			var prop : Property = p;
			multiPathStr += prop;
			multiPathStr += " Z ";
		}
		return new Property(multiPathStr);
	}

	@:to
	public function toMultiPath() : Array<Array<Vector>> {
		var multipath : Array<Array<Vector>> = [];
		var paths = this.split("Z"); //todo is this a good path end marker?
		for (p in paths) {
			p = StringTools.trim(p);
			var prop : Property = p;
			multipath.push( prop.toPath() );
		}
		return multipath;
	}

	/*
	@:from
	static public function fromColor(c:Color) {}
	*/

	@:to
	public function toColor() : Color {

		/* HEX COLOR */
		if (this.charAt(0) == "#") {
			var hexStr = "0x";
			var hexCharSubStr = this.substring(1); //hack off the #
			if (hexCharSubStr.length == 3) {
				//double the compressed hex code (e.g. #fa0 -> #ffaa00)
				hexStr += hexCharSubStr.charAt(0) + hexCharSubStr.charAt(0) + 
							hexCharSubStr.charAt(1) + hexCharSubStr.charAt(1) +
							hexCharSubStr.charAt(2) + hexCharSubStr.charAt(2);
			}
			else if (hexCharSubStr.length == 6) {
				//uncompressed hex code
				hexStr += hexCharSubStr;
			}
			else {
				//you're fucked
			}
			//trace("HEXXXX!!!");
			//trace(hexStr);
			var hexInt = Std.parseInt( hexStr );
			var r = ( (hexInt >> 16) & 0xff ) / 255;
			var g = ( (hexInt >>  8) & 0xff ) / 255;
			var b = ( (hexInt >>  0) & 0xff ) / 255;
			//trace(r);
			//trace(g);
			//trace(b);
			return new Color(r,g,b);
		}

		var r = ~/[\(\)]/;
		//trace(this);
		var colorArguments = r.split(this);
		var formatStr = colorArguments[0];

		/* PALETTE COLOR */
		if (formatStr == "pal") {
			var paletteIndex = Std.parseInt(colorArguments[1]);
			return Palette.Colors[paletteIndex];
		}
		/* RGB COLOR */
		else if (formatStr == "rgb") { 
			var rgbArr = colorArguments[1].split(",");
			var r = Std.parseFloat( rgbArr[0] );
			var g = Std.parseFloat( rgbArr[1] );
			var b = Std.parseFloat( rgbArr[2] );
			var color = new Color(r/255, g/255, b/255);
			if (rgbArr.length > 3) {
				var a = Std.parseFloat(rgbArr[3]);
				color.a = a;
			}
			return color;
		}
		/* HSL COLOR */
		else if (formatStr == "hsl") {
			var hslArr = colorArguments[1].split(",");
			var h = Std.parseFloat( hslArr[0] );
			var s = Std.parseFloat( hslArr[1] );
			var l = Std.parseFloat( hslArr[2] );
			var color = new ColorHSL(h/255, s/255, l/255);
			if (hslArr.length > 3) {
				var a = Std.parseFloat(hslArr[3]);
				color.a = a;
			}
			return color;
		}

		/* DEFAULT COLOR */
		return new Color(0,0,0);

	}

	@:from
	static public function fromFloat(f:Float) {
		return new Property("" + f);
	}

	@:to
	public function toFloat() : Float {
		return Std.parseFloat(this);
	}
}