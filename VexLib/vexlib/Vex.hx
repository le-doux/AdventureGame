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

import phoenix.Batcher;

class Vex extends Visual {
	public var properties : VexPropertyInterface;

	//hack
	var onLoad : Dynamic;

	override public function new( json : VexJsonFormat, ?onLoad:Dynamic ) {
		super({no_geometry:true});
		if (json.batcher == null) json.batcher = Luxe.renderer.batcher;
		//trace(json.batcher.name);

		// create children first, so that properties
		// we set in the parent (like depth) can trickle down to them
		if (json.children != null) {
			for (c in json.children) {
				if (json.batcher != null) c.batcher = json.batcher;
				var child = new Vex(c);
				child.parent = this;
			}
		}

		properties = new VexPropertyInterface(this);
		properties.deserialize(json);

		//hack
		if (onLoad != null) this.onLoad = onLoad;

		if (properties.type == "ref") {
			loadRef( properties.src );
		}

		//trace(properties.id);
	}

	public function resetToBasePose() {
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
			//trace("has ref!");
			var jsonRes = Luxe.resources.json(src);
			if (jsonRes.state == luxe.Resources.ResourceState.loaded) {
				//trace("load from store");
				var json = jsonRes.asset.json;
				deserializeRef(json);
			}
			else {
				//TODO does this event handler stick around?
				Luxe.resources.on(luxe.Resources.ResourceEvent.loaded, function(r:Resource) {
						//trace("load on event");
						var json = Luxe.resources.json(r.id).asset.json;
						deserializeRef(json);
					});
			}
		}
		else {
			//trace("load ref!");
			var load = Luxe.resources.load_json(src);
			load.then(function(jsonRes : JSONResource) {
				//trace("ref loaded!");
				var json = jsonRes.asset.json;
				deserializeRef(json);

				if (onLoad != null) onLoad(this);
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
		return VexTools.findVexById( this, searchStr );
	}

	public function getVexChildren() : Array<Vex> {
		return VexTools.getVexChildren( this );
	}

	//TODO move to VexTools
	//TODO fix origin move again
	//TODO fix child select
	public function isPointInside(pt:Vector) : Bool {
		var ptLocal = VexTools.vectorToLocalSpace( transform, pt );
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

	public function getPathInWorldSpace() : Array<Vector> {
		return VexTools.pathToWorldSpace( transform, properties.path );
	}

	/* Am I recreating the static extension? Shoudl I move it in here? */
	// Hooray this works!

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
		return VexTools.findBoundingBox(path);
	}

	public function boundsWorld() : Array<Vector> {
		return VexTools.pathToWorldSpace( transform, boundsLocal() );
	}

	public function boundsParentSpace() : Array<Vector> {
		return VexTools.pathToParentSpace( transform, boundsLocal() );
	}

	//public var animation : Animation;
	var animations : Map<String, Animation> = new Map<String, Animation>();
	public var curAnimation : Animation;
	public var curTween : luxe.tween.actuators.GenericActuator.IGenericActuator; //don't need both?

	public function traceAnimationNames() {
		//trace("ANIMATION KEYS");
		for (k in animations.keys()) {
			trace(k);
		}
	}
	public function addAnimation(json:AnimationFormat, ?name:String) : Animation {
		if (name == null) {
			//trace(json.id);
			if (json.id != null) {
				name = json.id;
			}
			else {
				name = "default";
			}
		}
		//trace(name);
		var anim = new Animation(json, this);
		animations.set(name, anim);
		return anim;
	}
	public function playAnimation(name:String, duration:Float) {
		curAnimation = animations.get(name);
		curTween = curAnimation.play(duration).ease(luxe.tween.easing.Linear.easeNone).onComplete(function() {
				//if this is overriden there could be problems
				curAnimation = null;
				curTween = null;
			});
		return curTween;
	}
	public function stopAnimation() { //rename pause?
		if (curAnimation != null) Actuate.stop(curAnimation);
		curAnimation = null;
		curTween = null;
	}

	//doesn't work like a real queue though... I can improve that later
	public function queueAnimation(name:String, duration:Float) {
		if (curTween == null) {

			//likely this should be removed later... or turned into the default behavior?
			var oldFacingScaleX = scale.x;
			resetToBasePose(); //this might overwrite things too often
			scale.x = oldFacingScaleX; //hack

			return playAnimation(name, duration);
		}
		else {
			var nextAnimation = animations.get(name);
			var nextTween = nextAnimation.play(duration).ease(luxe.tween.easing.Linear.easeNone).onComplete(function() {
				//if this is overriden there could be problems
				curAnimation = null;
				curTween = null;
			});
			Actuate.pause(nextAnimation);
			curTween.onComplete(function() {
					//trace("play queued!");

					//likely this should be removed later
					var oldFacingScaleX = scale.x;
					resetToBasePose(); //this might overwrite things too often
					scale.x = oldFacingScaleX; //hack

					curAnimation = nextAnimation;
					curTween = nextTween;
					Actuate.resume(nextAnimation);
				});
			return nextTween;
		}
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