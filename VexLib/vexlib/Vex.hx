package vexlib;

import luxe.Visual;
import luxe.Vector;
import luxe.Rectangle;
import luxe.tween.Actuate;
import luxe.resource.Resource.JSONResource;
import luxe.resource.Resource.Resource;
import luxe.collision.shapes.Polygon in CollisionPolygon;
import luxe.collision.shapes.Circle in CollisionCircle;

import vexlib.VexPropertyInterface;
import vexlib.Animation;

class Vex extends Visual {
	public var properties : VexPropertyInterface;

	override public function new( json : VexJsonFormat ) {
		super({no_geometry:true});

		// create children first, so that properties
		// we set in the parent (like depth) can trickle down to them
		if (json.children != null) {
			for (c in json.children) {
				var child = new Vex(c);
				child.parent = this;
			}
		}

		properties = new VexPropertyInterface(this);
		properties.deserialize(json);

		if (properties.type == "ref") {
			loadRef( properties.src );
		}

		trace(properties.id);
	}

	public function resetToBasePose() {
		trace("??");
		//properties.deserialize( properties.serialize() );

		if (properties.scale != null) {
			scale = properties.scale;
		}
		else {
			scale = new Vector(1,1,1); //fuck z scale - it always causes the weirdest bugs
		}
		
		if (properties.pos != null) {
			pos = properties.pos;
		}
		else {
			pos = new Vector(0,0);
		}

		if (properties.rot != null) {
			rotation_z = properties.rot;
		}
		else {
			rotation_z = 0.0;
		}

		for (c in getVexChildren()) {
			c.resetToBasePose();
		}
	}

	public function serialize() : VexJsonFormat {
		var json = properties.serialize();

		var shouldSerializeChildren = (json.type != "ref"); //don't serialize children of reference objects
		if (shouldSerializeChildren) {
			for (c in getVexChildren()) {
				if (json.children == null) json.children = [];
				json.children.push( c.serialize() );
			}			
		}

		return json;
	}

	//TODO clean up this async nonsense -- get advice from snowkit peeps?
	function loadRef(src:String) {
		if ( Luxe.resources.has(src) ) {
			trace("has ref!");
			var jsonRes = Luxe.resources.json(src);
			if (jsonRes.state == luxe.Resources.ResourceState.loaded) {
				trace("load from store");
				var json = jsonRes.asset.json;
				deserializeRef(json);
			}
			else {
				//TODO does this event handler stick around?
				Luxe.resources.on(luxe.Resources.ResourceEvent.loaded, function(r:Resource) {
						trace("load on event");
						var json = Luxe.resources.json(r.id).asset.json;
						deserializeRef(json);
					});
			}
		}
		else {
			trace("load ref!");
			var load = Luxe.resources.load_json(src);
			load.then(function(jsonRes : JSONResource) {
				trace("ref loaded!");
				var json = jsonRes.asset.json;
				deserializeRef(json);
			});
		}
	}

	function deserializeRef(json) {
		properties.deserializeRef(json);
		if (json.children != null) {
			for (c in json.children) {
				var child = new Vex(c);
				child.parent = this;
			}
		}
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
		vexChildren.sort(
			function(a,b) {
				if (a.depth > b.depth) return -1;
				if (a.depth < b.depth) return 1;
				return 0;
			});
		return vexChildren;
	}

	//TODO move these into a transform helper
	public function toLocalSpace(p:Vector) : Vector {
		return p.clone().applyProjection( transform.world.matrix.inverse() );
	}

	//TODO move these into a transform helper
	public function toWorldSpace(p:Vector) : Vector {
		return p.clone().applyProjection( transform.world.matrix );
	}

	//what should this actually be called?
	public function toWorldSpace2(p:Vector) : Vector {
		var pWorld = p.clone();
		if (parent != null) pWorld = cast(parent, Vex).toWorldSpace(pWorld);
		return pWorld;
	}

	public function toParentSpace(p:Vector) : Vector {
		return p.clone().applyProjection( transform.local.matrix );
	}

	//TODO fix origin move again
	//TODO fix child select
	public function isPointInside(pt:Vector) : Bool {
		var ptLocal = toLocalSpace(pt);
		var b = boundsLocal();
		var topLeft = b[0];
		var bottomRight = b[2];
		return (ptLocal.x > topLeft.x && ptLocal.y > topLeft.y && ptLocal.x < bottomRight.x && ptLocal.y < bottomRight.y);
	}

	public function getChildWithPointInside(pt:Vector) : Vex {
		var vexChildren = getVexChildren();
		for (c in vexChildren) {
			if (c.isPointInside(pt)) {
				return c;
			}
		}
		return null;
	}

	/* Am I recreating the static extension? Shoudl I move it in here? */
	// Hooray this works!
	function pathToWorldSpace(pathArray:Array<Vector>) : Array<Vector> {
		var worldPath = [];
		for (p in pathArray) {
			//worldPath.push( p.clone().applyProjection( transform.local.matrix ) );
			worldPath.push( toWorldSpace(p) );
		}
		return worldPath;
	}

	function pathToParentSpace(pathArray:Array<Vector>) : Array<Vector> {
		var worldPath = [];
		for (p in pathArray) {
			worldPath.push( toParentSpace(p) );
		}
		return worldPath;
	}

	//weird place to put this helper function
	function rectangleToPath(rect:Rectangle) : Array<Vector> {
		var path = [];
		path.push( new Vector(rect.x,			rect.y) );
		path.push( new Vector(rect.x + rect.w,	rect.y) );
		path.push( new Vector(rect.x + rect.w,	rect.y + rect.h) );
		path.push( new Vector(rect.x, 			rect.y + rect.h) );
		return path;
	}

	public function boundsLocal() : Array<Vector> {
		var path : Array<Vector> = [];
		if (properties.type == "poly" || properties.type == "line") {
			path = properties.path;
		}
		else if (properties.type == "group" || properties.type == "ref") {
			for (c in getVexChildren()) {
				path = path.concat( c.boundsParentSpace() );
			}
		}
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
		return [new Vector(0,0), new Vector(0,0), new Vector(0,0), new Vector(0,0)]; //error
	}

	public function boundsWorld() : Array<Vector> {
		return pathToWorldSpace( boundsLocal() );
	}

	public function boundsParentSpace() : Array<Vector> {
		return pathToParentSpace( boundsLocal() );
	}

	//public var animation : Animation;
	var animations : Map<String, Animation> = new Map<String, Animation>();
	public var curAnimation : Animation;

	public function traceAnimationNames() {
		trace("ANIMATION KEYS");
		for (k in animations.keys()) {
			trace(k);
		}
	}
	public function addAnimation(json:AnimationFormat, ?name:String) : Animation {
		if (name == null) {
			trace(json.id);
			if (json.id != null) {
				name = json.id;
			}
			else {
				name = "default";
			}
		}
		trace(name);
		var anim = new Animation(json, this);
		animations.set(name, anim);
		return anim;
	}
	public function playAnimation(name:String, duration:Float) {
		curAnimation = animations.get(name);
		return curAnimation.play(duration).ease(luxe.tween.easing.Linear.easeNone);
		/*
		trace(curAnimation);
		curAnimation.t = 0;
		return Actuate.tween(curAnimation, duration, {t:1}).ease(luxe.tween.easing.Linear.easeNone); //.play(duration);
		*/
	}
	public function stopAnimation() { //rename pause?
		if (curAnimation != null) Actuate.stop(curAnimation);
	}
	public function getAnimation(name:String) : Animation {
		return animations.get(name);
	}

	//probably hacky and dumb -- please revisit later you doofus
	override function set_depth(_v:Float) {
		for (c in getVexChildren()) {
			c.depth = _v;
		}
		return super.set_depth(_v);
	}
}