package vexlib;

import luxe.Vector;
import luxe.tween.Actuate;

import vexlib.VexPropertyInterface;

/* ANIMATION */
typedef AnimationPropertiesFormat = {
	@:optional public var pos : Property;
	@:optional public var scale : Property;
	@:optional public var rot : Property;
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
	@:optional public var tracks : Array<AnimationFormat>; //aka sub-animations
}

typedef PosFrame = {
	public var t : Float;
	public var pos : Vector;
}

typedef ScaleFrame = { //too duplicative?
	public var t : Float;
	public var scale : Vector;
}

typedef RotFrame = {
	public var t : Float;
	public var rot : Float;
}

class Animation {
	public var type : Null<Property>;
	public var id : Null<Property>;
	public var select : Null<Property>;

	public var t (default,set) : Float; //current time

	public var vex : Vex;

	var posFrames : Null<Array<PosFrame>>; //maybe it would be easier if these weren't nullable
	var scaleFrames : Null<Array<ScaleFrame>>;
	var rotFrames : Null<Array<RotFrame>>;

	var tracks : Null<Array<Animation>>; //does this need to be Null-able?

	public function new(json:AnimationFormat, root:Vex) {
		if (json.select != null) {
			select = json.select;
			vex = root.find(select)[0];
		}
		else {
			vex = root;
		}
		
		if (json.type != null) type = json.type;
		if (json.id != null) id = json.id;

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
				if (f.props.rot != null) {
					if (rotFrames == null) rotFrames = []; //should be initialized at start?
					rotFrames.push({
							t: f.t,
							rot: f.props.rot
						});
				}
			}
		}

		if (json.tracks != null) {
			tracks = [];
			for (t in json.tracks) {
				tracks.push(new Animation(t, root));
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
		if (rotFrames != null) tweenRot(t);
		if (tracks != null) {
			for (track in tracks) {
				track.t = t;
			}
		}
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

	function tweenRot(t:Float) {
		//TODO what if there are less than two frames?
		var lastKeyFrame = rotFrames[0];
		var nextKeyFrame = rotFrames[1];
		for (i in 2 ... rotFrames.length) {
			if (nextKeyFrame.t > t) break;
			lastKeyFrame = rotFrames[i-1];
			nextKeyFrame = rotFrames[i];
		}

		t -= lastKeyFrame.t;
		var dur = nextKeyFrame.t - lastKeyFrame.t;
		var d = t / dur;

		var deltaR = nextKeyFrame.rot - lastKeyFrame.rot;
		var rot = lastKeyFrame.rot + (deltaR * d);

		//TODO what if vex is null
		vex.rotation_z = rot;
	}
}