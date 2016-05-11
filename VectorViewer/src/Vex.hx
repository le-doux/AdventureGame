
import luxe.Vector;
import luxe.Color;
import luxe.Visual;
import luxe.options.VisualOptions;
import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import phoenix.Batcher;
import luxe.tween.Actuate;

/*
Animation

Attributes:
- pos
- scale
- rot
- color
- ?visible

- relative vs absolute

- how select children?

- blending

Extras:
- bones?
- morphing meshes?

Possible heirarchy:
{
	object {
		attribute {
			time {
				changeVal
			}
		}
	}
}


Alternatives
{
	"0%" : {
		"pos" : [100,100]
	},
	"50%" : {
		"pos" : [500,500]
	},
	"100%" : {
		"pos" : [0,0]
	}
}

{
	"pos" : {
		"0%" : [100,100],
		"50%" : [500,500],
		"100%" : [0,0]
	}
}

{
	"pos" : [
		{"0%" : [100,100]},
		{"50%" : [500,500]},
		{"100%" : [0,0]}
	]
}

{
	"pos" : [
		{"t" : 0.00, "d" : [100,100]},
		{"t" : 0.50, "d" : [500,500]},
		{"t" : 1.00, "d" : [0,0]}
	]
}

*/

typedef BaseAttributes = {
	@:optional var type : String;
	@:optional var id : String;
	@:optional var tags : Array<String>;
	@:optional var children : Array<BaseAttributes>;
}

typedef SpatialAttributes = {
	> BaseAttributes,
	@:optional var pos: Array<Float>;
	@:optional var origin: Array<Float>;
	@:optional var scale: Array<Float>;
	@:optional var rot: Float;
}

typedef GroupAttributes = {
	> SpatialAttributes,
}

typedef ShapeAttributes = {
	> SpatialAttributes,
	@:optional var color: Array<Dynamic>;
}

typedef PolyAttributes = {
	> ShapeAttributes,
	@:optional var path: Array<Float>;
}

typedef LineAttributes = {
	> PolyAttributes,
}

typedef RectAttributes = {
	> ShapeAttributes,
	@:optional var w: Float;
	@:optional var h: Float;
}

typedef EllipseAttributes = {
	> ShapeAttributes,
	@:optional var r: Array<Float>;
}

typedef MeshAttributes = {
	> ShapeAttributes,
	@:optional var vertices: Array<Float>;
}

typedef AnimationRecord = {
	var t : Float;
	var d : Array<Dynamic>;
}

typedef AnimateableAttributes = {
	@:optional var target: String;
	@:optional var pos:   Array<AnimationRecord>;
	@:optional var rot:   Array<AnimationRecord>;
	@:optional var scale: Array<AnimationRecord>;
	@:optional var color: Array<AnimationRecord>;
	@:optional var animations: Array<AnimateableAttributes>;
}

class Vex extends Visual {
	public var attributes : Dynamic;

	override public function new(_attributes:Dynamic) { //is dynamic necessary? do we need subclasses?
		//build this vex object from its attributes
		attributes = _attributes;
		super(Vex.Builder.Build(attributes));

		//make children
		if (attributes.children != null) {
			for (childAttr in cast(attributes.children, Array<Dynamic>)) {
				var child = new Vex(childAttr);
				child.parent = this;
			}
		}
	}

	public function find(searchStr:String) : Array<Vex> {
		var results = [];

		if (searchStr.charAt(0) == '#' && attributes.tags != null) {
			var tagStr = searchStr.substring(1);
			if (attributes.tags.indexOf(tagStr) != -1) {
				results.push(this);
			}
		}
		else if (searchStr.charAt(0) == '.' && attributes.id != null) {
			var idStr = searchStr.substring(1);
			if (attributes.id == idStr) {
				results.push(this);
			}
		}
		else {
			var typeStr = searchStr;
			if (attributes.type == typeStr) {
				results.push(this);
			}
		}

		for (c in children) {
			results = results.concat( cast(c,Vex).find(searchStr) );
		}

		return results;
	}

	public function animate(animation:AnimateableAttributes, duration:Float) {
		//keep all these in one method? or split them?
		
		if (animation.pos != null) {
			var prevTime : Float = 0; //create a method for getting step times
			var curTime : Float;
			var animationStepList = [];
			for (record in animation.pos) {
				curTime = record.t * duration;
				var deltaTime = curTime - prevTime;
				var animationStep = {
					dt: deltaTime,
					props: {
						x: record.d[0],
						y: record.d[1]
					}
				}
				animationStepList.push(animationStep);
				prevTime = curTime;
			}
			animateSeries(this.pos, animationStepList);
		}

		if (animation.scale != null) {
			var prevTime : Float = 0;
			var curTime : Float;
			var animationStepList = [];
			for (record in animation.scale) {
				curTime = record.t * duration;
				var deltaTime = curTime - prevTime;
				var animationStep = {
					dt: deltaTime,
					props: {
						x: record.d[0],
						y: record.d[1]
					}
				}
				animationStepList.push(animationStep);
				prevTime = curTime;
			}
			animateSeries(this.scale, animationStepList);
		}

		if (animation.rot != null) {
			var prevTime : Float = 0;
			var curTime : Float;
			var animationStepList = [];
			for (record in animation.rot) {
				curTime = record.t * duration;
				var deltaTime = curTime - prevTime;
				var animationStep = {
					dt: deltaTime,
					props: {
						rotation_z: record.d[0]
					}
				}
				animationStepList.push(animationStep);
				prevTime = curTime;
			}
			animateSeries(this, animationStepList);
		}

		if (animation.color != null) { // REFACTOR
			var prevTime : Float = 0;
			var curTime : Float;
			var animationStepList = [];
			for (record in animation.color) {
				curTime = record.t * duration;
				var deltaTime = curTime - prevTime;
				var c = Builder.ParseColor(record.d);
				var animationStep = {
					dt: deltaTime,
					props: {
						r : c.r,
						g : c.g,
						b : c.b
					}
				}
				animationStepList.push(animationStep);
				prevTime = curTime;
			}
			var funcList = [];
			var fIndex = 0;
			//build animation series
			for (s in animationStepList) {
				//create animation step function
				var func = function() {
					color.tween(s.dt, s.props) //animate to next val
						.onComplete(function() {
								//if animation is incomplete, do next animation
								fIndex++;
								if (fIndex < funcList.length) {
									funcList[fIndex]();
								}
							});
				};
				funcList.push(func);		
			}
			funcList[0](); //start animation chain
		}

		//sub animations
		if (animation.animations != null) {
			for (anim in animation.animations) {
				var targets = find(anim.target);
				for (t in targets) {
					t.animate(anim,duration);
				}
			}
		}
	}

	//hack to get around Actuate limitations (need a new lib?)
	function animateSeries(target:Dynamic, series:Array<Dynamic>) {
		var funcList = [];
		var fIndex = 0;
		//build animation series
		for (s in series) {
			//create animation step function
			var func = function() {
				Actuate.tween(target, s.dt, s.props) //animate to next val
					.onComplete(function() {
							//if animation is incomplete, do next animation
							fIndex++;
							if (fIndex < funcList.length) {
								funcList[fIndex]();
							}
						});
			};
			funcList.push(func);		
		}
		funcList[0](); //start animation chain
	}

	/*
	static public function Rebuild(v:Vex) { // in progress --- may change
		var attributes = v.attributes;
		attributes.children = [];
		
		var newVex = new Vex(attributes);

		for (c in v.children) {
			c.parent = newVex;
		}
		newVex.parent = v.parent;

		v.destroy(true);

		return newVex;
	}
	*/

}

class Builder {
	public static function Build(attributes:BaseAttributes) : VisualOptions {
		if (attributes.type == null) attributes.type = "group"; //group is the default
		return Reflect.field(Vex.Builder, attributes.type)(attributes);
	}

	private static function base(attributes:BaseAttributes) : VisualOptions {
		var name = attributes.type;
		if (attributes.tags != null) {
			for (t in attributes.tags) {
				name += "." + t;
			}
		}
		if (attributes.id != null) name += "." + attributes.id;
		return {
			name : name,
			name_unique : true
		};
	}

	private static function spatial(attributes:SpatialAttributes) : VisualOptions {
		var options = base(attributes);

		if (attributes.pos != null) options.pos = new Vector(attributes.pos[0], attributes.pos[1]);

		if (attributes.origin != null) options.origin = new Vector(attributes.origin[0], attributes.origin[1]);

		if (attributes.scale != null) { // THIS is the better method
			if (attributes.scale.length < 2) {
				options.scale = new Vector(attributes.scale[0], attributes.scale[0]);
			}
			else {
				options.scale = new Vector(attributes.scale[0], attributes.scale[1]);	
			}
		}

		if (attributes.rot != null) options.rotation_z = attributes.rot;

		return options;
	}

	private static function group(attributes:GroupAttributes) : VisualOptions {
		var options = spatial(attributes);
		options.no_geometry = true;
		return options;
	}

	private static function shape(attributes:ShapeAttributes) : VisualOptions {
		var options = spatial(attributes);

		if (attributes.color != null) {
			options.color = ParseColor(attributes.color);
		}
		else {
			options.color = new Color(1,1,1);
		}

		return options;
	}

	private static function poly(attributes:PolyAttributes) : VisualOptions {
		var options = shape(attributes);

		/*
		var pts = [];
		var i = 0;
		while (i < attributes.path.length) {
			var x = attributes.path[i+0];
			var y = attributes.path[i+1];
			pts.push( new Vector(x, y) );
			i += 2;
		}

		options.geometry = Luxe.draw.poly({
				solid: true,
				color: options.color,
				points: pts
			});
		*/


		///*
		options.geometry = new Geometry({
				primitive_type: PrimitiveType.triangles,
				batcher: Luxe.renderer.batcher
			});

		var p2tpath = [];
		var i = 0;
		while (i < attributes.path.length) {
			var x = attributes.path[i+0];
			var y = attributes.path[i+1];
			p2tpath.push( new org.poly2tri.Point(x, y) );
			i += 2;
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

				var vertex = new Vertex(new Vector(x, y, z), options.color);

				options.geometry.add(vertex);
			}

			i += 3;
		}
		//*/

		return options;
	}

	private static function rect(attributes:RectAttributes) : VisualOptions {
		var options = shape(attributes);

		options.geometry = Luxe.draw.box({
				w: attributes.w, h: attributes.h,
				color: options.color		
			});

		return options;
	}

	private static function ellipse(attributes:EllipseAttributes) : VisualOptions {
		var options = shape(attributes);

		if (attributes.r == null) attributes.r = [0];
		if (attributes.r.length < 2) attributes.r.push(attributes.r[0]);

		options.geometry = Luxe.draw.circle({
				rx: attributes.r[0], ry: attributes.r[1],
				color: options.color
			});

		return options;
	}

	public static function ParseColor(colorArr:Array<Dynamic>) : Color {
		var colorFormatStr : String = cast(colorArr[0]);
		if (colorFormatStr == "rgb") { 
			var c = new Color(colorArr[1]/255, colorArr[2]/255, colorArr[3]/255);
			if (colorArr.length > 4) {
				c.a = colorArr[4];
			}
			return c;
		}
		else if (colorFormatStr == "hsl") {
			var c = new ColorHSL(colorArr[1]/255, colorArr[2]/255, colorArr[3]/255);
			if (colorArr.length > 4) {
				c.a = colorArr[4];
			}
			return c;
		}
		else if (colorFormatStr == "pal") { //palette color
			return Vex.Palette.Colors[ colorArr[1] ];
		}
		else if (colorFormatStr.charAt(0) == "#") { //hex color
			var hexStr = "0x";
			var colorFormatSubStr = colorFormatStr.substring(1); //hack off the #
			if (colorFormatSubStr.length == 3) {
				//double the compressed hex code (e.g. #fa0 -> #ffaa00)
				hexStr += colorFormatSubStr.charAt(0) + colorFormatSubStr.charAt(0) + 
							colorFormatSubStr.charAt(1) + colorFormatSubStr.charAt(1) +
							colorFormatSubStr.charAt(2) + colorFormatSubStr.charAt(2);
			}
			else if (colorFormatSubStr.length == 6) {
				//uncompressed hex code
				hexStr += colorFormatSubStr;
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
		return new Color(1,1,1); //fallback
	}
}

class Palette {
	// right place to store this?
	// what about multiple palettes?
	// should I keep it Luxe format (luxe.Color), or Vex format (Array<Dynamic>)
	// how do you handle when the palette changes? animation?
	// what about colors derived from the palette?
	// should I encapsulate the actual Luxe colors?
	public static var Colors : Array<Color>; 
}