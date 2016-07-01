package vexlib;

import luxe.Visual;
import luxe.Vector;
import luxe.Color;
import luxe.Rectangle;

import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import phoenix.Batcher;

import luxe.tween.Actuate;

class Vex extends Visual {
	public var properties : VexPropertyInterface;

	override public function new( json : VexJsonFormat ) {
		super({no_geometry:true});
		properties = new VexPropertyInterface(this);
		properties.deserialize(json);

		if (json.children != null) {
			for (c in json.children) {
				var child = new Vex(c);
				child.parent = this;
			}
		}
	}

	public function serialize() : VexJsonFormat {
		var json = properties.serialize();
		for (c in getVexChildren()) {
			if (json.children == null) json.children = [];
			json.children.push( c.serialize() );
		}
		return json;
	}

	public function find(searchStr:String) : Array<Vex> {
		var results = [];
		/* FIND BY ID */
		if (properties.id == searchStr) {
			results.push(this);
		}
		for (c in getVexChildren()) {
			results = results.concat( c.find(searchStr) );
		}
		return results;
	}

	public function getVexChildren() : Array<Vex> {
		var vexChildren = [];
		if (children != null && children.length > 0) {
			for (c in children) {
				if (Std.is(c, Vex)) {
					vexChildren.push( cast(c,Vex) );
				}
			}
		}
		return vexChildren;
	}

	public function isPointInside(pt:Vector) : Bool {
		return bounds().point_inside(pt);
	}

	public function getChildWithPointInside(pt:Vector) : Vex {
		var vexChildren = getVexChildren();
		vexChildren.reverse(); //should I use depth instead to do the sorting?
		for (c in vexChildren) {
			if (c.isPointInside(pt)) {
				return c;
			}
		}
		return null;
	}

	public function bounds() : Rectangle {
		var boundingBox = new Rectangle();
		if (properties.type == "poly") {
			var path : Array<Vector> = properties.path;
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
			boundingBox.x = xMin;
			boundingBox.y = yMin;
			boundingBox.w = xMax - xMin;
			boundingBox.h = yMax - yMin;
			if (properties.pos != null) { //likely to be fragile
				var p : Vector = properties.pos;
				boundingBox.x += p.x;
				boundingBox.y += p.y;
			}
			if (properties.origin != null) { //likely to be fragile
				var p : Vector = properties.origin;
				boundingBox.x -= p.x;
				boundingBox.y -= p.y;
			}
		}
		else if (properties.type == "group") {
			var vexChildren = getVexChildren();
			if (vexChildren.length > 0) {
				var childBounds = vexChildren[0].bounds();
				var xPlusWidth = childBounds.x + childBounds.w;
				var yPlusHeight = childBounds.y + childBounds.h;
				var xMin = childBounds.x;
				var xMax = xPlusWidth;
				var yMin = childBounds.y;
				var yMax = yPlusHeight;
				for (c in getVexChildren()) {
					childBounds = c.bounds();
					xPlusWidth = childBounds.x + childBounds.w;
					yPlusHeight = childBounds.y + childBounds.h;
					if (childBounds.x < xMin) xMin = childBounds.x;
					if (xPlusWidth > xMax) xMax = xPlusWidth;
					if (childBounds.y < yMin) yMin = childBounds.y;
					if (yPlusHeight > yMax) yMax = yPlusHeight;
				}
				boundingBox.x = xMin;
				boundingBox.y = yMin;
				boundingBox.w = xMax - xMin;
				boundingBox.h = yMax - yMin;
				if (properties.pos != null) { //likely to be fragile
					var p : Vector = properties.pos;
					boundingBox.x += p.x;
					boundingBox.y += p.y;
				}
				if (properties.origin != null) { //likely to be fragile
					var p : Vector = properties.origin;
					boundingBox.x -= p.x;
					boundingBox.y -= p.y;
				}
			}
		}
		return boundingBox;
	}

	//TODO make animation less hacky
	public var animation : Animation;
	public function setAnimation(json:AnimationFormat) {
		//HACK
		var hack = find("cap")[0];
		hack.animation = new Animation(json);
		hack.animation.vex = hack;
		/*
		animation = new Animation(json);
		animation.vex = this;
		*/
	}
	public function playAnimation(duration:Float) {
		//HACK
		var hack = find("cap")[0];
		return hack.animation.play(duration);
		/*
		return animation.play(duration);
		*/
	}
}

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

/* PALETTES */
// TODO I may need to do some renaming of these classes
typedef PaletteFormat = {
	@:optional var type : Property;
	@:optional var id : Property;
	@:optional var colors : Array<Property>;
}
class Palette {
	public static var Colors : Array<Color> = [];
	static var paletteMap : Map<String, PaletteFormat> = new Map();

	//this function needs a better name --- and I need to handle multiple palettes
	public static function Load(pal:PaletteFormat) {
		paletteMap.set(pal.id, pal);
	}

	public static function Init(id:String) {
		var pal = paletteMap.get(id);
		for (i in 0 ... pal.colors.length) {
			Colors.push( pal.colors[i] );
		}
	}

	public static function Swap(id:String, ?t:Float) {
		if (t == null) t = 0;
		var pal = paletteMap.get(id);
		var tweenReturn = null;
		for (i in 0 ... pal.colors.length) {
			var nextColor : Color = pal.colors[i];
			tweenReturn = Colors[i].tween(t, 
						{ 
							r: nextColor.r, 
							g: nextColor.g, 
							b: nextColor.b 
						});
		}
		return tweenReturn;
	}
}

/*
//alt solution: different properties for each type, that all transform into strings
//ok is that even possible w/ vectors tho?

abstract VectorProperty(Vector) from Vector to Vector {
	inline public function new (v:Vector) {
		this = v;
	}

	@:from
	static public function fromString(s:String) {
		var coords = s.split(",");
		var x = Std.parseFloat(coords[0]);
		var y = Std.parseFloat(coords[1]);
		return new VectorProperty( new Vector(x,y) );
	}
}
*/


/* ANIMATION */
typedef AnimationPropertiesFormat = {
	@:optional public var pos : Property;
	@:optional public var scale : Property;
}

typedef KeyframeFormat = {
	@:optional public var t : Property;
	@:optional public var props : AnimationPropertiesFormat;
}

typedef AnimationFormat = {
	@:optional public var type : Property;
	@:optional public var id : Property;
	@:optional public var select : Property;
	@:optional public var keyframes : Array<KeyframeFormat>;
	@:optional public var animations : Array<AnimationFormat>;
}

typedef PosFrame = {
	public var t : Float;
	public var pos : Vector;
}

typedef ScaleFrame = { //too duplicative?
	public var t : Float;
	public var scale : Vector;
}

class Animation {
	public var type : Null<Property>;
	public var id : Null<Property>;
	public var select : Null<Property>;

	public var t (default,set) : Float; //current time

	public var vex : Vex;

	var posFrames : Null<Array<PosFrame>>;
	var scaleFrames : Null<Array<ScaleFrame>>;

	public function new(json:AnimationFormat) {
		if (json.type != null) type = json.type;
		if (json.id != null) id = json.id;
		if (json.select != null) select = json.select;
		if (json.keyframes != null) {
			for (f in json.keyframes) {
				if (f.props.pos != null) {
					if (posFrames == null) posFrames = [];
					posFrames.push({
							t: f.t,
							pos: f.props.pos
						});
				}
				if (f.props.scale != null) {
					if (scaleFrames == null) scaleFrames = [];
					scaleFrames.push({
							t: f.t,
							scale: f.props.scale
						});
				}
			}
		}
	}

	public function play(duration:Float) {
		trace(duration);
		t = 0;
		return Actuate.tween(this, duration, {t:1});
	}

	//TODO
	public function pause() {}

	function set_t(time:Float) : Float {
		t = time;
		trace(t);
		if (posFrames != null) tweenPos(t);
		if (scaleFrames != null) tweenScale(t);
		return t;
	}

	function tweenPos(t:Float) {
		trace(t);
		//TODO what if there are less than two frames?
		var lastKeyFrame = posFrames[0];
		var nextKeyFrame = posFrames[1];
		for (i in 2 ... posFrames.length) {
			if (nextKeyFrame.t > t) break;
			lastKeyFrame = posFrames[i-1];
			nextKeyFrame = posFrames[i];
		}

		t -= lastKeyFrame.t;
		var dur = nextKeyFrame.t - lastKeyFrame.t;
		var d = t / dur;

		var deltaV = Vector.Subtract( nextKeyFrame.pos, lastKeyFrame.pos );
		var pos = Vector.Add( lastKeyFrame.pos, deltaV.multiplyScalar(d) );

		trace(pos);
		//TODO what if vex is null
		vex.pos = pos;
	}

	//duplicative again!!!
	function tweenScale(t:Float) {
		//TODO what if there are less than two frames?
		var lastKeyFrame = scaleFrames[0];
		var nextKeyFrame = scaleFrames[1];
		for (i in 2 ... scaleFrames.length) {
			if (nextKeyFrame.t > t) break;
			lastKeyFrame = scaleFrames[i-1];
			nextKeyFrame = scaleFrames[i];
		}

		t -= lastKeyFrame.t;
		var dur = nextKeyFrame.t - lastKeyFrame.t;
		var d = t / dur;

		var deltaV = Vector.Subtract( nextKeyFrame.scale, lastKeyFrame.scale );
		var scale = Vector.Add( lastKeyFrame.scale, deltaV.multiplyScalar(d) );

		//TODO what if vex is null
		vex.scale = scale;
	}
}