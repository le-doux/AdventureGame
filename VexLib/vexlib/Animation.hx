package vexlib;

import luxe.Vector;
import luxe.tween.Actuate;

import vexlib.VexPropertyInterface;


/*
TODO
goals
- easy to read in / out
- easy to edit on the fly
- can write by hand


anim.t = 0.5;

anim.play(5);

Save( anim.serialize() );

anim.deserialize( jsonFromFile );

anim.setFrame({
	t: 0.1,
	// select: "head"
	props: {
		rot: 30,
		pos: new Vector(50,50)
	}
});

anim.getFrame(0.1);

anim.getFrame(0.1).t = 0.4;


anim.frame(0.1, {
	select: "head",
	props: {
		rot: 30,
		pos: new Vector(50,50)
	}
}); //creates frame

anim.frame(0.1); //returns frame

anim.frame(0.1, {t:0.3}); //change frame time
anim.frame(0.1).t = 0.3; //change frame time

anim.frame(0.1, {
	select: "head",
	rot: 30,
	pos: new Vector(50,50)
}); //creates frame

{
	id: 'animname',
	keyframes: [
		{
			t: 0,
			props: [
				{
					select: "head",
					pos: "10,10"
				},
				{
					select: "body",
					rot: '30',
					pos: "50,30"
				}
			]
		},
		{
			t: 0.5,
			props: [
				{
					
				}
			]
		}
	]
}

{
	keyframes: {
		0 : {
			head: {
				pos: "10,10",
				rot: "30"
			},
			arm: {
				pos: "30,30"
			}
		},
		0.5 : {
			head: {
				pos: "15,15"
			}
		}
	}
}

{
	keyframes: [
		{
			t:0,
			props: {
				head: {
					pos: "10,10"
				},
				arm: {
					scale: "4"
				}
			}
		},
		{
			t:0.5,
			props: {
				head: {
	
				}
			}
		}
	]
}

*/

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
	@:optional public var updateValueOnPlayAnim : Bool;
}

typedef ScaleFrame = { //too duplicative?
	public var t : Float;
	public var scale : Vector;
	@:optional public var updateValueOnPlayAnim : Bool;
}

typedef RotFrame = {
	public var t : Float;
	public var rot : Float;
	@:optional public var updateValueOnPlayAnim : Bool;
}

//hacky as fuck
typedef KeyframeEditOptions = {
	@:optional public var t : Property;
	@:optional public var select : Property;
	@:optional public var pos : Property;
	@:optional public var scale : Property;
	@:optional public var rot : Property;
}

class Animation {
	public var type : Null<Property>;
	public var id : Null<Property>;
	public var select : Null<Property>;

	public var t (default,set) : Float; //current time

	public var vex : Vex;

	public var keyframes :  Null<Array<KeyframeFormat>>; //on update of this, need to update all these chopped up property-frame arrays
	var posFrames : Null<Array<PosFrame>>; //maybe it would be easier if these weren't nullable
	var scaleFrames : Null<Array<ScaleFrame>>;
	var rotFrames : Null<Array<RotFrame>>;

	var tracks : Null<Array<Animation>>; //does this need to be Null-able?

	public function new(json:AnimationFormat, root:Vex) {
		deserialize(json, root);
	}

	function deserialize(json:AnimationFormat, root:Vex) { //TODO separate root somehow

		if (json.select != null) select = json.select;

		if (select != null) {
			vex = root.find(select)[0];
		}
		else {
			vex = root;
		}

		trace("new anim!!!");
		trace(root.properties.id);
		trace(vex.properties.id);
		
		if (json.type != null) type = json.type;
		if (json.id != null) id = json.id;

		if (json.keyframes != null) {
			keyframes = json.keyframes;
			separateKeyframesIntoPropertySpecificFrames(); //maybe this shouldn't be part of deserialization
		}

		if (json.tracks != null) {
			tracks = [];
			for (t in json.tracks) {
				tracks.push(new Animation(t, root));
			}
		}
	}

	public function serialize() : AnimationFormat {
		var json : AnimationFormat = {};
		
		if (type != null) json.type = type;
		if (id != null) json.id = id;
		if (select != null) json.select = select;
		if (keyframes != null) json.keyframes = keyframes;

		if (tracks != null) {
			json.tracks = [];
			for (tr in tracks) {
				json.tracks.push( tr.serialize() );
			}
		}

		return json;
	}

	public function set(options:KeyframeEditOptions) {
		trace(options);

		//create keyframe data from options
		var props : AnimationPropertiesFormat = {}; //so much boilerplate this shit could be a steam train
		if (options.pos != null) props.pos = options.pos;
		if (options.scale != null) props.scale = options.scale;
		if (options.rot != null) props.rot = options.rot;
		var frame : KeyframeFormat = {};
		if (options.t != null) frame.t = options.t;
		frame.props = props;

		var select : Animation = this; // by default: update keyframe on root animation
		if (options.select != null) { 
			select = findTrack(options.select); // if a selection is available, update keyframe on that track
		}

		if (select != null) {
			(select.select != null) ? trace(select.select) : trace("root");
		}
		else {
			trace("no valid selection yet");
		}

		if (select == null) {
			// create track from scratch, if it doesn't exist
			trace("new track!!!");
			var track : AnimationFormat = {
				type : "animation",
				select : options.select,
				keyframes : [frame]
			};
			var anim = new Animation(track, vex);
			if (tracks == null) tracks = [];
			tracks.push(anim);
		}
		else {
			select.setKeyframe(frame); // if the selection does exist, set the keyframe
		}
	}

	public function move(t0:Float, t1:Float) { //move frames in this animation and all child tracks
		moveKeyframe(t0,t1);
		for (tr in tracks) tr.moveKeyframe(t0,t1);
	}

	public function delete(t:Float) {
		deleteKeyframe(t);
		if (tracks != null)
			for (tr in tracks) tr.deleteKeyframe(t);
	}

	public function times() : Array<Float> {
		var times : Array<Float> = [];
		for (t in getKeyframeTimes()) {
			if (times.indexOf(t) == -1) times.push(t);
		}
		if (tracks != null) {
			for (tr in tracks) {
				for (t in tr.getKeyframeTimes()) {
					if (times.indexOf(t) == -1) times.push(t);
				}
			}
		}
		times.sort(
			function(a,b) {
				if (a < b) return -1;
				if (a > b) return 1;
				return 0;
			});
		return times;
	}

	public function findTrack(searchStr:String) : Animation {
		if (tracks != null) { //TODO replace nullable arrays with empty arrays?
			for (t in tracks) {
				if (t.select != null && t.select == searchStr) return t;
			}
		}
		return null;
	}

	public function findKeyframe(t:Float) {
		var results = {
			frame: null,
			index: -1
		};
		if (keyframes != null) {
			for (i in 0 ... keyframes.length) {
				var f = keyframes[i];
				if (f.t.toFloat() <= t) results.index = i; //TODO seems like toFloat() shouldn't be necessary :(
				if (f.t.toFloat() == t) results.frame = f;
			}
		}
		results.index += 1;
		return results;
	}

	public function setKeyframe(keyframe:KeyframeFormat) {
		var findFrameResults = findKeyframe(keyframe.t.toFloat()); //TODO toFloat() surely not necessary?
		if (findFrameResults.frame != null) {
			if (keyframe.props.pos != null) findFrameResults.frame.props.pos = keyframe.props.pos;
			if (keyframe.props.scale != null) findFrameResults.frame.props.scale = keyframe.props.scale;
			if (keyframe.props.rot != null) findFrameResults.frame.props.rot = keyframe.props.rot;
		}
		else {
			keyframes.insert( findFrameResults.index, keyframe );
		}
		trace(findFrameResults.index);
		separateKeyframesIntoPropertySpecificFrames();
	}

	public function moveKeyframe(t0:Float, t1:Float) {
		trace(t0);
		trace(t1);
		var findFrameResults = findKeyframe(t0);
		if (findFrameResults.frame != null) {
			var keyframe = findFrameResults.frame;
			trace(keyframe);
			keyframes.remove(keyframe);
			trace(keyframes);
			keyframe.t = t1;
			setKeyframe(keyframe);
			trace(keyframes);
		}
	}

	public function deleteKeyframe(t:Float) { //very similar to moveKeyframe()... duplicative?
		var findFrameResults = findKeyframe(t);
		if (findFrameResults.frame != null) {
			var keyframe = findFrameResults.frame;
			keyframes.remove(keyframe);
			separateKeyframesIntoPropertySpecificFrames(); //update the actual underlying data that moves the vex
		}
	}

	public function getKeyframeTimes() : Array<Float> { 
		//assumes frames are all in the correct order
		var times : Array<Float> = [];
		if (keyframes == null) return times;
		for (f in keyframes) {
			times.push(f.t);
		}
		return times;
	}

	// TODO this name is a bit unwieldy
	function separateKeyframesIntoPropertySpecificFrames() {
		posFrames = null;
		scaleFrames = null;
		rotFrames = null;
		trace("!!!");
		for (f in keyframes) {
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

		//create special first and last frames if necessary
		if (posFrames != null)
		{
			var firstPosFrame = posFrames[0];
			if (firstPosFrame.t > 0) {
				posFrames.insert(0, {
						t: 0.0,
						pos: (vex.properties.pos != null) ? vex.properties.pos : new Vector(0,0),
						updateValueOnPlayAnim: true
					});
			}

			var finalPosFrame = posFrames[posFrames.length-1];
			if (finalPosFrame.t < 1) {
				posFrames.push({
						t: 1.0,
						pos: finalPosFrame.pos
					});
			}
		}
		if (scaleFrames != null)
		{
			var firstScaleFrame = scaleFrames[0];
			if (firstScaleFrame.t > 0) {
				trace(vex);
				scaleFrames.insert(0, {
						t: 0.0,
						scale: (vex.properties.scale != null) ? vex.properties.scale : new Vector(1,1),
						updateValueOnPlayAnim: true
					});
			}

			var finalScaleFrame = scaleFrames[scaleFrames.length-1];
			if (finalScaleFrame.t < 1) {
				scaleFrames.push({
						t: 1.0,
						scale: finalScaleFrame.scale
					});
			}
		}
		if (rotFrames != null)
		{
			var firstRotFrame = rotFrames[0];
			if (firstRotFrame.t > 0) {
				rotFrames.insert(0, {
						t: 0.0,
						rot: (vex.properties.rot != null) ? vex.properties.rot : 0.0,
						updateValueOnPlayAnim: true
					});
			}

			var finalRotFrame = rotFrames[rotFrames.length-1];
			if (finalRotFrame.t < 1) {
				rotFrames.push({
						t: 1.0,
						rot: finalRotFrame.rot
					});
			}
		}


	}

	public function play(duration:Float) {
		updateStartFrames();
		t = 0;
		return Actuate.tween(this, duration, {t:1}).onUpdate(function() {
				trace("update anim!");
			});
	}

	function updateStartFrames() {
		if (posFrames != null) {
			if (posFrames[0].updateValueOnPlayAnim != null && posFrames[0].updateValueOnPlayAnim) {
				posFrames[0].pos = vex.pos.clone();
			}
		}

		if (scaleFrames != null) {
			if (scaleFrames[0].updateValueOnPlayAnim != null && scaleFrames[0].updateValueOnPlayAnim) {
				scaleFrames[0].scale = vex.scale.clone();
			}
		}

		if (rotFrames != null) {
			if (rotFrames[0].updateValueOnPlayAnim != null && rotFrames[0].updateValueOnPlayAnim) {
				rotFrames[0].rot = vex.rotation_z; //aliased?
			}
		}
	}

	//TODO
	public function pause() {}

	function set_t(time:Float) : Float {
		t = time;
		if (posFrames != null) tweenPos(t);
		//if (scaleFrames != null) tweenScale(t);
		//if (rotFrames != null) tweenRot(t);
		if (tracks != null) {
			for (track in tracks) {
				track.t = t;
			}
		}
		return t;
	}

	function tweenPos(t:Float) {
		//TODO what if there are less than two frames?
		if (posFrames == null || posFrames.length < 2) return;

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

		//TODO what if vex is null
		vex.pos = pos;
	}

	//duplicative again!!!
	function tweenScale(t:Float) {
		//TODO what if there are less than two frames?
		if (scaleFrames == null || scaleFrames.length < 2) return;

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
		if (rotFrames == null || rotFrames.length < 2) return;

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