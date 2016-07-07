package vexlib;

import luxe.Visual;
import luxe.Vector;
import luxe.Rectangle;
import luxe.tween.Actuate;

import vexlib.VexPropertyInterface;
import vexlib.Animation;

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
	//public var animation : Animation;
	var animations : Map<String, Animation> = new Map<String, Animation>();
	var curAnimation : Animation;
	public function addAnimation(json:AnimationFormat, ?name:String) {
		if (name == null) name = "default";
		if (json.id != null) name = json.id;
		var anim = new Animation(json, this);
		animations.set(name, anim);
	}
	public function playAnimation(name:String, duration:Float) {
		curAnimation = animations.get(name);
		curAnimation.t = 0;
		return Actuate.tween(curAnimation, duration, {t:1}).ease(luxe.tween.easing.Linear.easeNone); //.play(duration);
	}
	public function stopAnimation() { //rename pause?
		Actuate.stop(curAnimation);
	}
}