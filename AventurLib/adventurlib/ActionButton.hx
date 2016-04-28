package adventurlib;

import luxe.Color;
import luxe.Vector;
import luxe.Entity;
import luxe.Input;
import phoenix.geometry.*;
import luxe.tween.Actuate;
import luxe.tween.actuators.GenericActuator.IGenericActuator;
import luxe.tween.actuators.GenericActuator;
import luxe.Visual;

using adventurlib.ColorExtender;
using adventurlib.PolylineExtender;
using adventurlib.VectorExtender;

enum Direction {
	Left;
	Right;
	Up;
	Down;
}

enum OutroAnimation {
	Disappear;
	FillScreen;
	Emphasize;
}

//maybe this should all be a "Visual" class
class ActionButton extends Visual {

	////
	public var startSize : Float;
	public var endSize : Float;
	public var curSize (default, set) : Float;

	private var editFrame = 0;
	private var isEditing = false;

	public var pullDir (default, set) : Direction;
	public var outro : OutroAnimation;

	public var illustrations : Array<Array<Polystroke>> = [[],[]];

	public var onCompleteCallback : Dynamic = null;

	public var terrainPos (default, set) : Float;
	public var height (default, set) : Float;
	public var terrain (default, set) : Terrain;
	/////

	///
	public var isTouched = false;
	public var touchStartPos : Vector;
	public var isOutroed = false;
	///

	///
	private var pullTab : Visual;
	var isAppeared = false; //hack
	//


	///OLD STUFF (some still in use --- needs major cleanup)
	//saveable data (extract into its own struct-like object?)
	var backgroundColor : Color;
	public var illustrationColor : Color;

	var geo : Array<Geometry> = [];

	public var stateController = 1; //needs a better name

	public var curState = 0; //0 - start, 1 - end

	public var curIllustrationIndex = 0;
	public var curIllustration /*(get, null)*/ : Array<Polystroke>;
	///END OLD STUFF

	public override function new(_options : luxe.options.VisualOptions) {
		super(_options);
		geometry = Luxe.draw.circle({
			x : 0, y : 0,
			r : 100, //arbitrary
			batcher : _options.batcher
		});

		var ring = new Visual({
			geometry: Luxe.draw.ring({
							x : 0, y : 0,
							r : 102, //arbitrary,
							color : new Color(1,1,1), //temporary
							batcher : _options.batcher
						}),
			parent: this
		});

		pullTab = new Visual({no_geometry:true, parent:this});
		new Visual({
			geometry: Luxe.draw.line({
					p0 : new Vector(-10,110),
					p1 : new Vector(0,120),
					color : new Color(1,1,1), //temporary,
					batcher : _options.batcher
				}),
			parent: pullTab
		});
		new Visual({
			geometry: Luxe.draw.line({
					p0 : new Vector(10,110),
					p1 : new Vector(0,120),
					color : new Color(1,1,1), //temporary,
					batcher : _options.batcher
				}),
			parent: pullTab
		});
	}

	public override function onmousedown(e:MouseEvent) {
		var mouseWorldPos = Luxe.camera.screen_point_to_world(e.pos);
		if (isAppeared && !isOutroed && mouseWorldPos.distance(pos) < (100 * curSize * 1.2)) {
			isTouched = true;
			touchStartPos = mouseWorldPos;
		}
	}

	public override function onmousemove(e:MouseEvent) {
		if (isTouched) {
			var mouseWorldPos = Luxe.camera.screen_point_to_world(e.pos);
			var pullDist : Float = 0;
			switch pullDir {
				case Direction.Left:
					pullDist = touchStartPos.x - mouseWorldPos.x;
				case Direction.Right:
					pullDist = mouseWorldPos.x - touchStartPos.x;
				case Direction.Up:
					pullDist = touchStartPos.y - mouseWorldPos.y;
				case Direction.Down:
					pullDist = mouseWorldPos.y - touchStartPos.y;
			}
			pullDist = Math.max(0, pullDist);

			var pullDelt = pullDist / 200;
			var sizeDelt = endSize - startSize;
			curSize = startSize + (sizeDelt * pullDelt);

			if (pullDelt >= 1) {
				isTouched = false;
				isOutroed = true;
				animateOutro();
			}
		}
	}

	public override function onmouseup(e:MouseEvent) {
		if (isTouched) {	
			isTouched = false;
			if (!isOutroed) {
				Actuate.tween(this, 0.3, {curSize: startSize})
					.ease(luxe.tween.easing.Quad.easeOut);
			}
		}
	}

	public function triggerAppear() {
		if (!isAppeared && !isOutroed) {
			isAppeared = true;
			animateAppear();
		}
	}

	public function triggerDisappear() {
		if (isAppeared && !isOutroed) {
			isAppeared = false;
			animateLeave();
		}
	}

	//TODO make the illustration change as you pull!
	public override function update(dt : Float) {

		//inefficient to do this every loop?
		if (curSize - startSize >= (endSize - startSize)/2 
			&& illustrations[1].length > 0) {
			for (s in illustrations[0]) {
				s.set_visible(false);
			}
			for (s in illustrations[1]) {
				s.set_visible(true);
			}
		}
		else {
			for (s in illustrations[0]) {
				s.set_visible(true);
			}
			for (s in illustrations[1]) {
				s.set_visible(false);
			}
		}

		//causes bugs by resetting pos all the damn time
		/*
		if (terrain != null) {
			pos = terrain.worldPosFromTerrainPos(terrainPos);
			pos.y -= height;
		}
		*/
	}

	public function set_height(h : Float) : Float {
		height = h;
		updatePos();
		return height;
	}

	public function set_terrainPos(p : Float) : Float {
		terrainPos = p;
		updatePos();
		return terrainPos;
	}

	public function set_terrain(t : Terrain) : Terrain {
		terrain = t;
		updatePos();
		return terrain;
	}

	function updatePos() {
		if (terrain != null) {
			//update position with terrain
			pos = terrain.worldPosFromTerrainPos(terrainPos);
			pos.y -= height;	
		}

	}

	public function set_pullDir(d : Direction) : Direction {
		pullDir = d;
		switch pullDir {
			case Direction.Left:
				pullTab.rotation_z = 90;
			case Direction.Right:
				pullTab.rotation_z = 270;
			case Direction.Up:
				pullTab.rotation_z = 180;
			case Direction.Down:
				pullTab.rotation_z = 0;
		}
		return pullDir;
	}

	public function addStrokeToIllustration(p : Polystroke) {
		//this works, but it feels like I should be using a transformation matrix or something
		//p.pos.subtract(this.pos).divideScalar(this.scale.x);
		//p.scale.divideScalar(this.scale.x);
		p.color = illustrationColor;

		p.parent = this;
		illustrations[editFrame].push(p);
	}

	function set_curSize(size) : Float {
		curSize = size;
		scale = new Vector(curSize, curSize);

		if (isEditing) {
			if (editFrame == 0) startSize = curSize;
			if (editFrame == 1) endSize = curSize;
		}

		return curSize;
	}

	public function editStart() {
		editFrame = 0;
		isEditing = true;
		curSize = startSize;
	}

	public function editEnd() {
		editFrame = 1;
		isEditing = true;
		curSize = endSize;
	}

	public function animateAppear() : IGenericActuator {
		isEditing = false; //hack?
		curSize = 0;
		return Actuate.tween(this, 1.0, {curSize: startSize})
					.ease(luxe.tween.easing.Bounce.easeOut);
	}

	public function animateLeave() : IGenericActuator {
		isEditing = false; //hack?
		curSize = startSize;
		return Actuate.tween(this, 1.0, {curSize: 0})
					.ease(luxe.tween.easing.Quad.easeOut);
	}

	public function animatePull() : IGenericActuator {
		isEditing = false; //hack?
		curSize = startSize;
		return Actuate.tween(this, 3.0, {curSize: endSize})
					.ease(luxe.tween.easing.Quad.easeOut);
	}

	public function animateOutro() { //returning this will be tricky
		switch outro {
			case OutroAnimation.Disappear:
				animateDisappear();
			case OutroAnimation.FillScreen:
				animateFillScreen();
			case OutroAnimation.Emphasize:
				animateEmphasize();
		}
	}

	function animateDisappear() {
		isEditing = false; //hack?
		curSize = endSize;
		Actuate.tween(this, 1.0, {curSize: 0})
				.ease(luxe.tween.easing.Elastic.easeIn)
				.onComplete(function() {
					if (onCompleteCallback != null) {
						onCompleteCallback();
					}
				});
	}

	function animateFillScreen() {
		isEditing = false; //hack?
		curSize = endSize;
		Actuate.tween(this, 1.0, {curSize: Luxe.screen.width})
				.ease(luxe.tween.easing.Quad.easeIn)
				.onComplete(function() {
					if (onCompleteCallback != null) {
						onCompleteCallback();
					}
				});
	}

	//TODO can't figure out how to return a two deep animation
	function animateEmphasize() {
		isEditing = false; //hack?
		curSize = endSize;

		var curMid = Luxe.camera.screen_point_to_world(Luxe.screen.mid);
		Actuate.tween(pos, 0.6, {x:curMid.x, y:curMid.y});
		Actuate.tween(this, 0.6, {curSize: (endSize * 1.5)})
				.ease(luxe.tween.easing.Quad.easeOut)
				.onComplete(function() {
					Actuate.tween(this, 0.2, {curSize: 0})
							.delay(1.0)
							.ease(luxe.tween.easing.Quad.easeIn)
							.onComplete(function() {
								if (onCompleteCallback != null) {
									onCompleteCallback();
								}
							});
				});
	}

	public function animateSequence() { //can't figure out how to return this
		animateAppear()
			.onComplete(function() {
				animatePull()
					.onComplete(function(){
							animateOutro();
						});
			});
	}

	public function toJson() {
		var illustration1 = [];
		for (p in illustrations[0]) {
			illustration1.push(p.toJson());
		}
		var illustration2 = [];
		for (p in illustrations[1]) {
			illustration2.push(p.toJson());
		}

		return {
			type : "action",
			name : this.name,
			backgroundColor : backgroundColor.toJson(),
			illustrationColor : illustrationColor.toJson(),
			terrainPos : terrainPos,
			height : height,
			startSize : startSize,
			endSize : endSize,
			pullDir : pullDir.getName(),
			outro : outro.getName(),
			illustration1: illustration1,
			illustration2: illustration2
		};
	}

	public function fromJson(json : Dynamic) : ActionButton {
		backgroundColor = (new Color()).fromJson(json.backgroundColor);
		illustrationColor = (new Color()).fromJson(json.illustrationColor);
		terrainPos = json.terrainPos;
		height = json.height;
		startSize = json.startSize;
		endSize = json.endSize;
		pullDir = Direction.createByName(json.pullDir);
		outro = OutroAnimation.createByName(json.outro);

		for (j in cast(json.illustration1, Array<Dynamic>)) {
			var p = new Polystroke(
							{
								color:illustrationColor,
								batcher:Luxe.renderer.batcher,
								depth:50 //arbitrary
							},
						[]).fromJson(j);
			p.parent = this;
			illustrations[0].push(p);
		}
		for (j in cast(json.illustration2, Array<Dynamic>)) {
			var p = new Polystroke(
							{
								color:illustrationColor,
								batcher:Luxe.renderer.batcher,
								depth:50 //arbitrary
							},
						[]).fromJson(j);
			p.parent = this;
			illustrations[1].push(p);
		}
		//switchIllustration(0);

		curSize = startSize;

		color = backgroundColor;
		//color children (w/ plenty of hacks)
		for (c in this.children) {
			cast(c, Visual).color = illustrationColor;
			for (c2 in c.children) {
				cast(c2, Visual).color = illustrationColor;
			}
		};

		//change name hack (should do this on creation instead? make a new constructor with a json initializer obj like the library uses)
		var tmpScene = this.scene;
		tmpScene.remove(this);
		this.name = json.name;
		tmpScene.add(this);

		return this;
	}

	override public function set_visible(v:Bool) : Bool {
		super.set_visible(v);
		for (i in illustrations) {
			for (s in i) {
				s.visible = v;
			}
		}
		return v;
	}
}