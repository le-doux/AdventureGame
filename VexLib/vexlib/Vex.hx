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
		properties = new VexPropertyInterface(this);
		properties.deserialize(json);

		if (properties.type == "ref") {
			loadRef( properties.src );
		}

		if (json.children != null) {
			for (c in json.children) {
				var child = new Vex(c);
				child.parent = this;
			}
		}

		trace(properties.id);
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
		return vexChildren;
	}

	public function isPointInside(pt:Vector) : Bool {
		var b = bounds();
		var col = b.testCircle( new CollisionCircle(pt.x, pt.y, 1) ); //radius = 1 is a temp hack
		return col != null;
		//return bounds().point_inside(pt); //old version
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

	/* Am I recreating the static extension? Shoudl I move it in here? */
	// Hooray this works!
	function pathToWorldSpace(pathArray:Array<Vector>) : Array<Vector> {
		var worldPath = [];
		for (p in pathArray) {
			worldPath.push( p.clone().applyProjection( transform.local.matrix ) );
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

	// TODO - need to store bounds somewhere until they need to update?
	// TODO bounds don't work right if they have a parent 
	public function bounds() : CollisionPolygon {

		var path : Array<Vector> = [];
		if (properties.type == "poly") {
			path = properties.path;
		}
		else if (properties.type == "group" || properties.type == "ref") {
			for (c in getVexChildren()) {
				path = path.concat( c.bounds().transformedVertices );
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

			var x = xMin - origin.x; //have to take into account origin in this janky way
			var y = yMin - origin.y;
			var w = xMax - xMin;
			var h = yMax - yMin;
			var vertices:Array<Vector> = [];
			vertices.push( new Vector(x,y) );
			vertices.push( new Vector(x+w,y) );
			vertices.push( new Vector(x+w,y+h) );
			vertices.push( new Vector(x,y+h) );

			var boundingBox = new CollisionPolygon(pos.x, pos.y, vertices);

			boundingBox.rotation = rotation_z;
			boundingBox.scaleX = scale.x;
			boundingBox.scaleY = scale.y;

			return boundingBox;
		}


		/*
		if (properties.type == "poly") {
			var boundingPoly = new CollisionPolygon(pos.x, pos.y, properties.path);
			boundingPoly.rotation = rotation_z;
			boundingPoly.scaleX = scale.x;
			boundingPoly.scaleY = scale.y;
			return boundingPoly;
		}
		else if (properties.type == "group" || properties.type == "ref") {
			var childCollisionPoints = [];
			for (c in getVexChildren()) {
				var childBounds = c.bounds();
				childCollisionPoints = childCollisionPoints.concat( childBounds.transformedVertices );
			}
			if (childCollisionPoints.length > 0) {
				var xMin = childCollisionPoints[0].x;
				var xMax = childCollisionPoints[0].x;
				var yMin = childCollisionPoints[0].y;
				var yMax = childCollisionPoints[0].y;
				for (p in childCollisionPoints) {
					if (p.x < xMin) xMin = p.x;
					if (p.x > xMax) xMax = p.x;
					if (p.y < yMin) yMin = p.y;
					if (p.y > yMax) yMax = p.y;
				}
				var boundingBoxPath = [
							new Vector(xMin, yMin),
							new Vector(xMax, yMin),
							new Vector(xMax, yMax),
							new Vector(xMin, yMax)
						];
				var boundingPoly = new CollisionPolygon(pos.x, pos.y, boundingBoxPath);
				boundingPoly.rotation = rotation_z;
				boundingPoly.scaleX = scale.x;
				boundingPoly.scaleY = scale.y;
				return boundingPoly;
			}

		}
		*/

		//error case
		return new CollisionPolygon(0,0,[]);

		/*
		var boundingBox = new Rectangle();
		var path : Array<Vector> = [];
		if (properties.type == "poly") {
			path = properties.path;
			path = pathToWorldSpace( path );
		}
		else if (properties.type == "group" || properties.type == "ref") {
			for (c in getVexChildren()) {
				var boundsPath = rectangleToPath( c.bounds() );
				boundsPath = pathToWorldSpace( boundsPath );
				path = path.concat( boundsPath );
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
			boundingBox.x = xMin;
			boundingBox.y = yMin;
			boundingBox.w = xMax - xMin;
			boundingBox.h = yMax - yMin;
		}
		*/

		//old version -- for posterity?
		/*
		if (properties.type == "poly") {
			var path : Array<Vector> = properties.path;
			path = pathToWorldSpace(path);
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
		}
		else if (properties.type == "group" || properties.type == "ref") {
			//TODO
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
			}
		}
		*/
		//return boundingBox;
	}

	//TODO make animation less hacky
	//public var animation : Animation;
	var animations : Map<String, Animation> = new Map<String, Animation>();
	var curAnimation : Animation;
	public function addAnimation(json:AnimationFormat, ?name:String) {
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
	}
	public function playAnimation(name:String, duration:Float) {
		curAnimation = animations.get(name);
		trace(curAnimation);
		curAnimation.t = 0;
		return Actuate.tween(curAnimation, duration, {t:1}).ease(luxe.tween.easing.Linear.easeNone); //.play(duration);
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