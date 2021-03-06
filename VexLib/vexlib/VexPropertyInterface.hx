package vexlib;

import luxe.Vector;
import luxe.Color;
import luxe.Visual;
import luxe.utils.Maths;
import luxe.resource.Resource.JSONResource;
import luxe.resource.Resource.Resource;

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
	//@:optional public var batcher : Batcher;
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

	public var children (get, set) : Array <VexJsonFormat>;

	public var components (default, set) : Null<Array<ComponentJsonFormat>>;

	var visual : Visual;
	public var batch : Batcher; //hack

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

		if (children.length > 0) json.children = children;

		if (components != null) json.components = components;

		return json;
	}

	public function parse(json:VexJsonFormat) {
		
		//batch = json.batcher; //hack

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

		if (json.children != null) children = json.children;

		if (json.components != null) components = json.components;

		if (type == "ref") loadRef( src );
	}

	//TODO clean up this async nonsense -- get advice from snowkit peeps?
	function loadRef(src:String) {
		if ( Luxe.resources.has(src) ) {
			//trace("has ref!");
			var jsonRes = Luxe.resources.json(src);
			if (jsonRes.state == luxe.Resources.ResourceState.loaded) {
				//trace("load from store");
				var json = jsonRes.asset.json;
				parseRef(json);
			}
			else {
				//TODO does this event handler stick around?
				Luxe.resources.on(luxe.Resources.ResourceEvent.loaded, function(r:Resource) {
						//trace("load on event");
						var json = Luxe.resources.json(r.id).asset.json;
						parseRef(json);
					});
			}
		}
		else {
			//trace("load ref!");
			var load = Luxe.resources.load_json(src);
			load.then(function(jsonRes : JSONResource) {
				//trace("ref loaded!");
				var json = jsonRes.asset.json;
				parseRef(json);

				//TODO
				//if (onLoad != null) onLoad(this);
			});
		}
	}

	public function parseRef(json:VexJsonFormat) {
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

		//children
		if (json.children != null) children = json.children;

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
		//visual.scale.z = 1; //hack to keep inverse() valid
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
		path = prop;
		if (visual != null) {
			if (type == "poly") {

				//mesh triangulization approach
				visual.geometry = new Geometry({
						primitive_type: PrimitiveType.triangles,
						batcher: batch
					});

				var mesh = VexTools.pathToMesh( path );

				visual.geometry = VexTools.addTrianglesToGeometry( visual.geometry, mesh );


				// todo shader-rendering
				/*				
				trace( Luxe.resources.shader("polyshader") );

				if ( visual.geometry == null ) {
					visual.geometry = new Geometry({
						primitive_type: PrimitiveType.triangles,
						batcher: batch,
						shader: Luxe.resources.shader("polyshader")
					});

					visual.geometry.add( new Vertex( new Vector(0,0) ) );
					visual.geometry.add( new Vertex( new Vector(1,1) ) );
					visual.geometry.add( new Vertex( new Vector(1,0) ) );
					visual.geometry.add( new Vertex( new Vector(0,0) ) );
					visual.geometry.add( new Vertex( new Vector(1,1) ) );
					visual.geometry.add( new Vertex( new Vector(0,1) ) );
					
					// hack test
					// visual.geometry.add( new Vertex( new Vector(0,0) ) );
					// visual.geometry.add( new Vertex( new Vector(100,100) ) );
					// visual.geometry.add( new Vertex( new Vector(100,0) ) );
					// visual.geometry.add( new Vertex( new Vector(0,0) ) );
					// visual.geometry.add( new Vertex( new Vector(100,100) ) );
					// visual.geometry.add( new Vertex( new Vector(0,100) ) );
				}

				var pathFloatArray = [];
				for (v in path.toPath()) {
					pathFloatArray.push( v.x );
					pathFloatArray.push( v.y );
				}

				trace( pathFloatArray );

				visual.geometry.shader.set_int( "u_pathLength", cast(pathFloatArray.length/2, Int) );
				visual.geometry.shader.set_vector2_arr( "u_path", VexTools.makeFloat32Array( pathFloatArray ) ); 
				*/

			}
			else if (type == "line") { //best name? other options: stroke, outline

				visual.geometry = new Geometry({
					primitive_type: PrimitiveType.lines,
					batcher: batch
				});

				visual.geometry = VexTools.addMultilineToGeometry( visual.geometry, path );
				
			}
		}
		return path;
	}

	function set_children(childData:Array<VexJsonFormat>) : Array<VexJsonFormat> {
		visual.children = []; //potentially destructive hack TODO preserve any existing matching children
		for (json in childData) {
			var child = Vex.Create(json);
			child.parent = visual;
		}

		return childData;
	}

	function get_children() : Array<VexJsonFormat> {
		var childrenJson = [];
		if (type == "ref") return childrenJson; //children of references are not accessable through this interface
		for (child in VexTools.getVexChildren( visual )) {
			childrenJson.push( child.serialize() );
		}
		return childrenJson;
	}

	function set_components(componentData:Array<ComponentJsonFormat>) : Array<ComponentJsonFormat> {
		components = componentData;

		for (c in components) {
			visual.add( VexTools.jsonToComponent(c) );
		}

		return components;
	}

	//is this really the best way to do this?
	public function AddComponent(options:Dynamic) {
		visual.add( VexTools.jsonToComponent(options) );

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
		return new Property( VexTools.serializeVector(v) );
	}

	@:to
	public function toVector() : Vector {
		return VexTools.parseVector( this );
	}

	@:from
	static public function fromPath(path:Array<Vector>) {
		return new Property( VexTools.serializePath(path) );
	}

	@:to
	public function toPath() : Array<Vector> {
		return VexTools.parsePath( this );
	}

	@:from
	static public function fromMultiPath(multipath:Array<Array<Vector>>) {
		return new Property( VexTools.serializeMultipath(multipath) );
	}

	@:to
	public function toMultiPath() : Array<Array<Vector>> {
		return VexTools.parseMultipath( this );
	}

	@:from
	static public function fromColor(c:Color) {
		return new Property( VexTools.serializeColor(c) );
	}

	@:to
	public function toColor() : Color {
		return VexTools.parseColor( this );
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