package vexlib;

import luxe.Visual;
import luxe.Vector;
import luxe.Color;

import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import phoenix.Batcher;

import haxe.rtti.Meta;


/*
GOALS
A easy to read in N
B easy to save out ~
C easy to manually author format Y
D easy to edit properties at runtime Y
?E code is easy to maintain and update and add to

A: put JSON in an object --> get visual
B: retrieve JSON from visual object and save immediately to a string
C: concise and readable format
D: edit single variables that match the JSON properties
		--> immediately see changes visual object
		--> immediately update the JSON you want to save out

A
v = new Vex({
	type: "poly",
	path: "10,10 100,200 20,300"
})
B
output = v.serialize()
C
{
	type: "poly",
	path: "10,10 100,200 20,300",
	color: "pal(2)" //or rgb(100,200,120) or #ff0
}
D
visual.vex.path = [new Vector(10,10), new Vector(100,200), new Vector(20,300)];
visual.vex.color = new Color(1,1,1);



TODO
- handle children gracefully
- read in json
- attach to visual
*/

class VexVisual extends Visual {
	public var vex : VexPropertyInterface;

	override public function new( json : VexJsonFormat ) {
		super({no_geometry:true});
		vex = new VexPropertyInterface(this);
		vex.deserialize(json);

		if (json.children != null) {
			for (c in json.children) {
				children.push( new VexVisual(c) );
			}
		}
	}

	public function serialize() : VexJsonFormat {
		var json = vex.serialize();
		for (c in children) {
			if (Std.is(c, VexVisual)) {
				var v = cast(c, VexVisual);
				if (json.children == null) json.children = [];
				json.children.push( v.serialize() );
			}
		}
		return json;
	}
}

//is this even good? necessary?
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

	function getVexFields() : Array<String> {
		var fields : Array<String> = [];

		var classType : Class<Dynamic> = Type.getClass(this);
		var metadata = Meta.getFields(classType);

		for (fieldName in Reflect.fields(metadata)) {
			var metaField = Reflect.field(metadata, fieldName);
			var isVexField = Reflect.hasField(metaField, "vex");
			if (isVexField) {
				fields.push(fieldName);
			}
		}

		return fields;
	}

	function set_type(prop:Property) : Property {
		return type = prop;
	}

	function set_id(prop:Property) : Property {
		return id = prop;
	}

	function set_pos(prop:Property) : Property {
		pos = prop;
		if (visual != null) { //these checks may not be necessary
			visual.pos = pos;
		}
		return pos;
	}

	function set_origin(prop:Property) : Property {
		origin = prop;
		if (visual != null) {
			visual.origin = origin;
		}
		return origin;
	}

	function set_scale(prop:Property) : Property {
		scale = prop;
		if (visual != null) {
			visual.scale = scale;
		}
		return scale;
	}

	function set_rot(prop:Property) : Property {
		rot = prop;
		if (visual != null) {
			visual.rotation_z = rot;
		}
		return rot;
	}

	function set_color(prop:Property) : Property {
		color = prop;
		if (visual != null) {
			visual.color = color;
		}
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
		var r = ~/[\(\)]/;
		var colorArguments = r.split(this);
		var formatStr = colorArguments[0];

		if (formatStr == "pal") {
			var paletteIndex = Std.parseInt(colorArguments[1]);
			return Palette.Colors[paletteIndex];
		}

		//default
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

//hacky standin
class Palette {
	public static var Colors : Array<Color> = [new Color(1,0,0)];
}