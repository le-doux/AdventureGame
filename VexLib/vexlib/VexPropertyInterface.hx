package vexlib;

import luxe.Vector;
import luxe.Color;
import luxe.Visual;

import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import phoenix.Batcher;

typedef VexJsonFormat = {
	@:optional public var type 		: Property;
	@:optional public var id 		: Property;
	@:optional public var pos 		: Property;
	@:optional public var origin 	: Property;
	@:optional public var scale 	: Property;
	@:optional public var rot 		: Property;
	@:optional public var color 	: Property;
	@:optional public var path 		: Property;
	@:optional public var children 	: Array<VexJsonFormat>;
}

class VexPropertyInterface {
	public var type 	(default, set) : Null<Property>;
	public var id 		(default, set) : Null<Property>;
	public var pos 		(default, set) : Null<Property>;
	public var origin 	(default, set) : Null<Property>;
	public var scale 	(default, set) : Null<Property>;
	public var rot 		(default, set) : Null<Property>;
	public var color 	(default, set) : Null<Property>;
	public var path 	(default, set) : Null<Property>;

	var visual : Visual;

	public function new(v:Visual) {
		visual = v;
	}

	public function serialize() : VexJsonFormat {
		var json : VexJsonFormat = {};
		if (type != null) json.type = type;
		if (id != null) json.id = id;
		if (pos != null) json.pos = pos;
		if (origin != null) json.origin = origin;
		if (scale != null) json.scale = scale;
		if (rot != null) json.rot = rot;
		if (color != null) json.color = color;
		if (path != null) json.path = path;
		return json;
	}

	public function deserialize(json:VexJsonFormat) {
		if (json.type != null) type = json.type;
		if (json.id != null) id = json.id;
		if (json.pos != null) pos = json.pos;
		if (json.origin != null) origin = json.origin;
		if (json.scale != null) scale = json.scale;
		if (json.rot != null) rot = json.rot;
		if (json.path != null) path = json.path;
		if (json.color != null) color = json.color;
	}

	function set_type(prop:Property) : Property {
		return type = prop;
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
		return scale;
	}

	function set_rot(prop:Property) : Property {
		rot = prop;
		visual.rotation_z = rot;
		return rot;
	}

	function set_color(prop:Property) : Property {
		color = prop;
		visual.color = color;
		return color;
	}

	function set_path(prop:Property) : Property {
		path = prop;
		if (visual != null) {
			if (type == "poly") {
				visual.geometry = new Geometry({
						primitive_type: PrimitiveType.triangles,
						batcher: Luxe.renderer.batcher
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
			}
		}
		return path;
	}
}

abstract Property(String) from String to String {
	inline public function new(str:String) {
		this = str;
	}

	@:from
	static public function fromVector(v:Vector) {
		return new Property(v.x + "," + v.y);
	}

	@:to
	public function toVector() : Vector {
		var coords = this.split(",");
		var x = Std.parseFloat(coords[0]);
		var y = Std.parseFloat(coords[1]);
		return new Vector(x,y);
	}

	@:from
	static public function fromPath(path:Array<Vector>) {
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
		var path : Array<Vector> = [];
		var points = this.split(" ");
		for (p in points) {
			var pointProp : Property = p;
			path.push(pointProp);
		}
		return path;
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
			var hexInt = Std.parseInt( hexStr );
			var r = ( (hexInt >> 0xf) & 0xff ) / 255;
			var g = ( (hexInt >> 0x8) & 0xff ) / 255;
			var b = ( (hexInt >> 0x0) & 0xff ) / 255;
			return new Color(r,g,b);
		}

		var r = ~/[\(\)]/;
		var colorArguments = r.split(this);
		var formatStr = colorArguments[0];

		/* PALETTE COLOR */
		if (formatStr == "pal") {
			var paletteIndex = Std.parseInt(colorArguments[1]);
			return Palette.Colors[paletteIndex];
		}
		/* RGB COLOR */
		else if (formatStr == "rgb") { 
			var rgbArr = colorArguments[0].split(",");
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
			var hslArr = colorArguments[0].split(",");
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