
import sys.io.File;
import haxe.Json;

import luxe.Input;
import luxe.Visual;
import luxe.Vector;
import luxe.Color;
import luxe.Camera;
import luxe.resource.Resource.JSONResource;
import phoenix.Batcher;
import dialogs.Dialogs;
import luxe.utils.Maths;

import vexlib.Vex;
import vexlib.Palette;
import vexlib.VexPropertyInterface;
import vexlib.Animation;

import Command;

/*
	TODO for better animated character
	- animation editor
		X add mode support to editor
		X create timeline
		X ? clean up animation format
		X functionalize editing commands so they don't always update properties
		X make editing commands update animation frames
		- sane defaults for start & end of animations
		- sane defaults for single frame animations
		- stop animation "follow through"
	X sketch layer
	X bounds that work w/ transforms
	X groups of groups
	X select into groups
		- this could be better
	X ungroup
	- ? depth control
	- ? insert objects inside of a group
	- ? clean up animation format
	- ? tween two animations
	- ? palette editor

	TODO next
	- clean up animation format
	- animation editor
	- naming scheme for Vex and related formats
	- load palettes at will
	X copy / paste
	X make bounds work with scale and rotation
	- ? maybe switch bounds off of a bounding box model to collision polys??

	TODO for getting things in level
	- ? separate level editor
	- ? level editor mode in editor
	- ? draw lines
		- line thickness control
	X load / save reference (src) objects
	X import objects in editor
	X move objects
	X rotate objects
	X resize objects
	- ? depth control
	- ? animation references
	X level file format!
	- playmode app

	TODO for demo day
	X animated main char
	X vex scenery in level editor / player
		X need to be able to move off origin point in vex editor
	X swipe triggered anims in level
	- ? parallax layers

	TODO:
	- add UI layer for graphics
	X copy paste with JSON
	X make vector viewer app
	- how do I handle z order?
	- why don't grays render the way I expect? color unpacking?
	X sketch layer
	- need to handle animation edge cases better
		- edge cases: no start frame, no end frame, ???
		- need to be able to reset to base "pose"
	- report luxe bugs
*/

enum EditorMode {
	Draw;
	Edit;
	Animate;
	Sketch;
}

class Main extends luxe.Game {

	var mode : EditorMode = EditorMode.Draw;

	/* BATCHERS */
	var uiScreenBatcher : Batcher; // UI displayed at screen coords
	var uiSceneBatcher : Batcher; // UI displayed in scene coords

	var drawingPath : Array<Vector> = [];
	var distToClosePath = 16;

	var root : Vex;
	var selected (get, set) : Vex;
	var multiSelection : Array<Vex> = [];

	var count = 0;

	/* STATE FLAGS */
	var isEditingId = false;
	var isPanning = false;
	var showSketchLayer = true;

	var curPalIndex = 0;

	var clipboard : String;

	//sketchmode
	var sketchLines : Array<Array<Vector>> = [];
	var curSketchLine : Array<Vector>;

	override function ready() {
		Luxe.camera.pos.subtract(Luxe.screen.mid); //put 0,0 in the center of the camera

		var uiCam = new Camera({name:"uiCam"});
		uiScreenBatcher = Luxe.renderer.create_batcher({name:"uiScreenBatcher", layer:10, camera:uiCam.view});
		uiSceneBatcher = Luxe.renderer.create_batcher({name:"uiSceneBatcher", layer:5, camera:Luxe.camera.view});

		//init drawing
		root = new Vex({
				type: "group",
				origin: "0,0",
				pos: "0,0"
			});

		/*
		//draw origin
		Luxe.draw.line({
				p0: new Vector(-Luxe.screen.width/2, 0),
				p1: new Vector(Luxe.screen.width/2, 0)
			});
		Luxe.draw.line({
				p0: new Vector(0, -Luxe.screen.height/2),
				p1: new Vector(0, Luxe.screen.height/2)
			});
		*/

		//load default palettes - hacky nonsense
		var load = Luxe.resources.load_json('assets/default.pal');
		load.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			Palette.Load(json);
			Palette.Init("default");
		});
	} //ready

	override function onkeydown( e:KeyEvent ) {

		//switch modes
		var modeCount = 4; //hack
		if (e.keycode == Key.right && e.mod.lalt) {
			var modeIndex = mode.getIndex();
			modeIndex = (modeIndex + 1) % modeCount;
			switchMode(EditorMode.createByIndex(modeIndex));
		}
		if (e.keycode == Key.left && e.mod.lalt) {
			var modeIndex = mode.getIndex();
			modeIndex = (modeIndex - 1) % modeCount;
			if (modeIndex < 0) modeIndex = modeCount - 1;
			switchMode(EditorMode.createByIndex(modeIndex));
		}

		switch (mode) {
			case Draw: onkeydown_draw(e);
			case Edit: onkeydown_edit(e);
			case Sketch: onkeydown_sketch(e);
			case Animate: onkeydown_animate(e);
		}

		//toggle sketch visibility
		if (e.keycode == Key.key_k && e.mod.lalt) {
			showSketchLayer = !showSketchLayer;
		}

		//for testing: change background color
		if (e.keycode == Key.key_b && e.mod.meta) {
			Luxe.renderer.clear_color = Palette.Colors[curPalIndex];
		}

		/*
		//for testing: swap palettes
		if (e.keycode == Key.key_p && e.mod.meta) {
			Palette.Swap("alt", 5);
		}
		*/

		//open
		if (e.keycode == Key.key_o && e.mod.meta ) {

			//load file
			var path = Dialogs.open("Open dialog");
			var fileStr = File.getContent(path);
			var json = Json.parse(fileStr);

			//destroy current image
			root.destroy();

			//load new image
			root = new Vex(json);

		}

		//save
		if (e.keycode == Key.key_s && e.mod.meta ) {
			//get path & open file
			var path = Dialogs.save("Save dialog");
			var output = File.write(path);

			//get data & write it
			var saveJson = root.serialize();
			var saveStr = Json.stringify(saveJson, null, "	");
			output.writeString(saveStr);

			//close file
			output.close();
		}

		//import ref
		if (e.keycode == Key.key_r && e.mod.meta) {
			var path = Dialogs.open("Import dialog");
			//hacky method - assumes everything lives in assets folder
			//also - always goes to 0,0
			var pathSplit = path.split("/assets/"); 
			var srcString = "assets/" + pathSplit[1];
			var cmd = new DrawVexCommand(root,
					{
						type: "ref",
						src: srcString
					});
			selected = cmd.vex;
		}

		//edit id
		if (e.keycode == Key.key_i && e.mod.meta) {
			if (selected != null) {
				isEditingId = !isEditingId;
				if (isEditingId) selected.properties.id = "";
			}
		}

		//copy paste
		//TODO use real clipboard
		if (e.keycode == Key.key_c && e.mod.meta) {
			if (selected != null) {
				clipboard = Json.stringify( selected.serialize() );
			}
			else {
				clipboard = Json.stringify( root.serialize() ); //not sure this is a great idea actually
			}
		}
		if (e.keycode == Key.key_v && e.mod.meta) {
			if (clipboard != null) {
				var json = Json.parse( clipboard );
				var cmd = new DrawVexCommand(root,json);
				selected = cmd.vex;
				selected.pos.add(new Vector(10,10));
				selected.properties.pos = selected.pos; //there has GOT to be a better way TODO can I override this?
			}
		}

		//undo redo
		if (e.keycode == Key.key_z && e.mod.meta) Command.Undo();
		if (e.keycode == Key.key_y && e.mod.meta) Command.Redo();

	}

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function ontextinput(e:TextEvent) {
		//edit id
		if (isEditingId) {
			selected.properties.id += e.text; //TODO command-ify
		}

		//change current color
		var n = Std.parseInt(e.text);
		if (n != null && n > 0 && n < 9) {
			curPalIndex = n - 1;
		} 
	}

	override function onmousedown( e:MouseEvent ) {

		/* panning */
		var isAltHeld = Luxe.input.keydown(Key.lalt) || Luxe.input.keydown(Key.ralt);
		if (isAltHeld) {
			isPanning = true;
			return;
		}

		/* mode specific mouse controls */
		switch(mode) {
			case Draw: onmousedown_draw(e);
			case Edit: onmousedown_edit(e);
			case Animate: onmousedown_animate(e);
			case Sketch: onmousedown_sketch(e);
		}
	}

	override function onmousemove(e:MouseEvent) {
		/* PANNING */
		if (isPanning) {
			Luxe.camera.pos.x -= e.xrel / Luxe.camera.zoom;
			Luxe.camera.pos.y -= e.yrel / Luxe.camera.zoom;
			return;
		}

		/* mode specific mouse controls */
		switch(mode) {
			case Edit: onmousemove_edit(e);
			case Sketch: onmousemove_sketch(e);
			case Animate: onmousemove_animate(e);
			default: return;
		}
	}

	override function onmouseup(e:MouseEvent) {
		/* PANNING */
		isPanning = false;

		/* mode specific mouse controls */
		switch(mode) {
			case Animate: onmouseup_animate(e);
			default: return;
		}
	}

	override function onmousewheel(e:MouseEvent) {
		/* ZOOMING */
		Luxe.camera.zoom += e.yrel * 0.03 * Luxe.camera.zoom;
	}

	override function update(dt:Float) {

		//current mode
		Luxe.draw.text({
				text: "mode: " + mode,
				point_size: 16,
				batcher: uiScreenBatcher,
				immediate: true
			});

		//id
		if (selected != null) {
			Luxe.draw.text({
					text: "id: " + selected.properties.id,
					point_size: 16,
					batcher: uiScreenBatcher,
					pos: new Vector(0,20),
					immediate: true
				});
		}

		//draw sketch
		if (showSketchLayer) {
			for (l in sketchLines) {
				for (i in 1 ... l.length) {
					Luxe.draw.line({
							p0: l[i-1],
							p1: l[i],
							batcher: uiSceneBatcher,
							immediate:true
						});
				}
			}
		}

		//draw origin (pretty hacky rn)
		var screenEdgeRightWorldPos = new Vector( Luxe.camera.screen_point_to_world( new Vector(Luxe.screen.w,0)).x, 0 );
		var screenEdgeLeftWorldPos = new Vector( Luxe.camera.screen_point_to_world( new Vector(0,0)).x, 0 );
		var screenEdgeTopWorldPos = new Vector( 0, Luxe.camera.screen_point_to_world(new Vector(0,0)).y );
		var screenEdgeBottomWorldPos = new Vector( 0, Luxe.camera.screen_point_to_world(new Vector(0,Luxe.screen.h)).y );
		Luxe.draw.line({
			p0: new Vector(0,0),
			p1: screenEdgeRightWorldPos,
			color: new Color(1,1,1,0.5),
			batcher: uiSceneBatcher,
			immediate: true
		});
		Luxe.draw.line({
			p0: new Vector(0,0),
			p1: screenEdgeLeftWorldPos,
			color: new Color(1,1,1,0.5),
			batcher: uiSceneBatcher,
			immediate: true
		});
		Luxe.draw.line({
			p0: new Vector(0,0),
			p1: screenEdgeTopWorldPos,
			color: new Color(1,1,1,0.5),
			batcher: uiSceneBatcher,
			immediate: true
		});
		Luxe.draw.line({
			p0: new Vector(0,0),
			p1: screenEdgeBottomWorldPos,
			color: new Color(1,1,1,0.5),
			batcher: uiSceneBatcher,
			immediate: true
		});

		//move around document
		var isShiftHeld = Luxe.input.keydown(Key.lshift) || Luxe.input.keydown(Key.rshift);
		var panSpeed : Float = 50;
		if (Luxe.input.keydown(Key.left) && isShiftHeld) {
			Luxe.camera.pos.x -= panSpeed * dt;
		}
		else if (Luxe.input.keydown(Key.right) && isShiftHeld) {
			Luxe.camera.pos.x += panSpeed * dt;
		}
		if (Luxe.input.keydown(Key.up) && isShiftHeld) {
			Luxe.camera.pos.y -= panSpeed * dt;
		}
		else if (Luxe.input.keydown(Key.down) && isShiftHeld) {
			Luxe.camera.pos.y += panSpeed * dt;
		}

		/* mode specific update functions */
		switch(mode) {
			case Draw: update_draw(dt);
			case Edit: update_edit(dt);
			case Animate: update_animate(dt);
			default: return;
		}

	} //update

	/* DRAW */
	function onkeydown_draw( e:KeyEvent ) {
		//delete selected element
		if (e.keycode == Key.backspace) {
			if (multiSelection.length > 0) {
				new DeleteCommand(multiSelection);
				multiSelection = [];
			}
		}

		//change color
		if (e.keycode == Key.key_f && e.mod.meta) {
			if (selected != null) {
				new ColorCommand(multiSelection, "pal(" + curPalIndex + ")");
			}
		}
	}

	function onmousedown_draw( e:MouseEvent ) {
		var p = Luxe.camera.screen_point_to_world(e.pos);

		//is the path closed?
		var isPathClosed = false;
		if (drawingPath.length > 2) {
			if ( Vector.Subtract(p,drawingPath[0]).length < (distToClosePath / Luxe.camera.zoom) ) {
				isPathClosed = true;
			}
		}

		if (isPathClosed) {

			//find top left point and shift the drawing path to be relative to it
			var topLeft = drawingPath[0].clone();
			for (p in drawingPath) {
				if (p.x < topLeft.x) topLeft.x = p.x;
				if (p.y < topLeft.y) topLeft.y = p.y;
			}
			for (p in drawingPath) {
				p.subtract(topLeft);
			}


			var cmd = new DrawVexCommand(root, //should parent be a possible attribute?
				{
					type: "poly",
					pos: topLeft,
					path: drawingPath,
					id: "poly" + count, //I should get rid of this at some point... not everything needs an id
					color: "pal(" + curPalIndex + ")"
				});
			selected = cmd.vex;

			//clear drawing path
			drawingPath = [];

			count++;
		}
		else {
			//add new point
			drawingPath.push(p);
		}
	}

	function update_draw( dt:Float ) {
		//draw cursor
		Luxe.draw.circle({
				x: Luxe.screen.cursor.pos.x,
				y: Luxe.screen.cursor.pos.y,
				r: distToClosePath/2,
				color: Palette.Colors[curPalIndex],
				batcher: uiScreenBatcher,
				immediate: true
			});

		renderDrawingPath();
	}

	/* EDIT */
	function onkeydown_edit( e:KeyEvent ) {
		//delete selected element
		if (e.keycode == Key.backspace) {
			if (multiSelection.length > 0) {
				new DeleteCommand(multiSelection);
				multiSelection = [];
			}
		}

		//change color
		if (e.keycode == Key.key_f && e.mod.meta) {
			if (selected != null) {
				new ColorCommand(multiSelection, "pal(" + curPalIndex + ")");
			}
		}

		//group selected elements
		if (e.keycode == Key.key_g && e.mod.meta) {
			if (multiSelection.length > 1) {
				//make group
				var g = new Vex({
						type: "group",
						pos: "0,0"
					});
				for (s in multiSelection) {
					s.parent = g;
				}
				
				//move pos to top left
				var curPos : Vector  = g.properties.pos;
				var bounds = g.boundsWorld();
				var topLeft : Vector = bounds[0]; //bounds.transformedVertices[0]; //hope this works
				var displacement = Vector.Subtract( topLeft, curPos );
				for (v in g.getVexChildren()) {
					var pos : Vector = v.properties.pos;
					v.properties.pos = pos.subtract(displacement);
				}
				g.properties.pos = topLeft;

				//add group to scene
				g.parent = root;
				selected = g;
			}
		}

		//ungroup selected group
		if (e.keycode == Key.key_u && e.mod.meta) {
			if ( selected != null && (selected.properties.type == "group" || selected.properties.type == "ref") ) {
				for (v in selected.getVexChildren()) {
					var newPos = selected.toParentSpace( v.pos );
					var newScale = v.scale.multiply( selected.scale );
					var newRot = v.rotation_z + selected.rotation_z;

					v.properties.pos = newPos;
					v.properties.scale = newScale;
					v.properties.rot = newRot;

					v.parent = selected.parent;
				}
				selected.destroy(true);
				selected = null;
			}
		}

		//rotate selected elements //TODO make command //TODO make rotate handle?
		if (e.keycode == Key.right && e.mod.meta) {
			for (sel in multiSelection) {
				sel.rotation_z += 5;
				sel.properties.rot = sel.rotation_z; //TODO this makes my properties system look bad...
			}
		}
		if (e.keycode == Key.left && e.mod.meta) {
			for (sel in multiSelection) {
				sel.rotation_z -= 5;
				sel.properties.rot = sel.rotation_z; //this makes my properties system look bad...
			}
		}

		//scale selected elements //TODO make command //TODO separate x- and y- axes
		if (e.keycode == Key.up && e.mod.meta) {
			for (sel in multiSelection) {
				sel.scale.add(new Vector(0.1,0.1)); //TODO do I need defaults for properties???
				sel.properties.scale = sel.scale;
			}
		}
		if (e.keycode == Key.down && e.mod.meta) {
			for (sel in multiSelection) {
				sel.scale.subtract(new Vector(0.1,0.1));
				sel.properties.scale = sel.scale;
			}
		}
	}

	function onmousedown_edit( e:MouseEvent ) {
		var p = Luxe.camera.screen_point_to_world(e.pos);
		var isShiftHeld = Luxe.input.keydown(Key.lshift) || Luxe.input.keydown(Key.rshift);

		if (Luxe.input.keydown(Key.key_x) && Luxe.input.keydown(Key.lmeta)) {
			/* SET ORIGIN */
			if (selected != null) {
				var newOriginWorldSpace = p.clone();
				var newOriginLocalSpace = selected.toLocalSpace( newOriginWorldSpace );

				var prevOriginLocalSpace : Vector = (selected.properties.origin == null) ? new Vector(0,0) : selected.properties.origin;
				var prevOriginWorldSpace = selected.toWorldSpace( prevOriginLocalSpace );

				var displacement = Vector.Subtract( newOriginWorldSpace, prevOriginWorldSpace );

				selected.properties.origin = newOriginLocalSpace;
				selected.properties.pos = Vector.Add( selected.properties.pos, displacement );
			}
		}
		else if (isShiftHeld) {
			/* MULTISELECT */
			var v = root.getChildWithPointInside(p);
			if (v != null) {
				var alreadySelected = multiSelection.indexOf(v) != -1;
				if (!alreadySelected) {
					multiSelection.push(v);
				}
				else {
					// TODO remove if already selected?
				}
			}
		}
		else {
			/* SELECT */
			var newSelection : Vex = null;
			if (selected != null && selected.properties.type != "ref") newSelection = selected.getChildWithPointInside(p);
			if (newSelection == null) newSelection = root.getChildWithPointInside(p);
			selected = newSelection;
			/*
			if (selected != null) {
				var newSelection = selected.getChildWithPointInside(p);
				if (newSelection == null) newSelection = root.getChildWithPointInside(p);
				selected = newSelection;
			}
			else {
				selected = root.getChildWithPointInside(p);
			}
			*/
			//selected = root.getChildWithPointInside(p);
		}
	}

	function onmousemove_edit(e:MouseEvent) {
		/* TRANSLATE SELECTION */
		if (Luxe.input.mousedown(luxe.MouseButton.left)) {
			if (multiSelection.length > 0) {
				for (sel in multiSelection) {
					//TODO live edit the Vex pos, then ON RELEASE update the property
					var pos = sel.pos.clone(); //this is starting to feel roundabout...
					pos.x += e.xrel / Luxe.camera.zoom;
					pos.y += e.yrel / Luxe.camera.zoom;
					sel.properties.pos = pos;

					trace(sel.transform.local.matrix);
				}
			}
		}
	}

	function update_edit( dt:Float ) {
		renderSelectionBounds();
	}

	/* ANIMATE */
	var curAnimation : Animation = null;
	var isTouchingTimeline = false;
	var selectedKeyframeOnMousedown = false;

	function onkeydown_animate( e:KeyEvent ) {
		//open animation
		//TODO overload key_o instead
		if (e.keycode == Key.key_a && e.mod.meta) {
			//load file
			var path = Dialogs.open("Open dialog");
			var fileStr = File.getContent(path);
			var json = Json.parse(fileStr);	
			curAnimation = root.addAnimation(json);
		}

		//make new animation
		if (e.keycode == Key.key_n && e.mod.meta) {
			curAnimation = root.addAnimation({id:"newAnimation"});
		}

		//play animation
		if (e.keycode == Key.key_p && e.mod.meta) {
			/*
			root.addAnimation( curAnimation );
			root.playAnimation( curAnimation.id, 5 )
				.onComplete(function() {
						trace("!!!");
						root.resetToBasePose();
					});
			*/
			root.playAnimation(curAnimation.id, 5);
		}

		if (curAnimation != null) { //TODO should I ensure that curAnimation is never null?
			//TODO share code between regular edit & animate edit?
			//rotate selected elements //TODO make command //TODO make rotate handle?
			if (e.keycode == Key.right && e.mod.meta) {
				trace("!!");
				for (sel in multiSelection) {
					trace(sel);
					sel.rotation_z += 5;
					curAnimation.set({
							t : curAnimation.t,
							select : sel.properties.id,
							rot : sel.rotation_z
						});
				}
			}
			if (e.keycode == Key.left && e.mod.meta) {
				for (sel in multiSelection) {
					sel.rotation_z -= 5;
					curAnimation.set({
							t : curAnimation.t,
							select : sel.properties.id,
							rot : sel.rotation_z
						});
				}
			}

			//scale selected elements //TODO make command //TODO separate x- and y- axes
			if (e.keycode == Key.up && e.mod.meta) {
				for (sel in multiSelection) {
					sel.scale.add(new Vector(0.1,0.1)); //TODO do I need defaults for properties???
					curAnimation.set({
							t : curAnimation.t,
							select : sel.properties.id,
							scale : sel.scale
						});
				}
			}
			if (e.keycode == Key.down && e.mod.meta) {
				for (sel in multiSelection) {
					sel.scale.subtract(new Vector(0.1,0.1));
					curAnimation.set({
							t : curAnimation.t,
							select : sel.properties.id,
							scale : sel.scale
						});
				}
			}	
		}

	}

	function onmousedown_animate( e:MouseEvent ) {
		var screenPos = e.pos;
		var p = Luxe.camera.screen_point_to_world(e.pos);

		// timeline scrubbing
		var timelineY = Luxe.screen.h * 0.9;
		var distFromTimelineY = Math.abs(timelineY - screenPos.y);
		isTouchingTimeline = distFromTimelineY < 15;
		if (isTouchingTimeline) {
			selectedKeyframeOnMousedown = animationTimelineSelect(screenPos.x);
		}
		else {
			//TODO add multiselect here
			/* SELECT */
			var newSelection : Vex = null;
			if (selected != null && selected.properties.type != "ref") newSelection = selected.getChildWithPointInside(p);
			if (newSelection == null) newSelection = root.getChildWithPointInside(p);
			selected = newSelection;
		}
	}

	function onmousemove_animate( e:MouseEvent ) {
		var screenPos = e.pos;
		var p = Luxe.camera.screen_point_to_world(e.pos);

		// timeline scrubbing
		if (selectedKeyframeOnMousedown) {
			//don't do nothin
		}
		else if (isTouchingTimeline) {
			animationTimelineSelect(screenPos.x);
		}

	}

	function animationTimelineSelect(x:Float) {
		var isKeyframeTouched = false;

		var timelineX = Luxe.screen.w * 0.1;
		var timelineW = Luxe.screen.w * 0.8;

		var selectX = Maths.clamp(x - timelineX, 0, timelineW);
		var timelinePercent = selectX / timelineW;
		
		if (curAnimation != null) {

			//snap & select
			for (t in curAnimation.times()) {
				var keyframeX = (timelineW * t);
				if (Math.abs(keyframeX - selectX) < 10) {
					timelinePercent = t;
					isKeyframeTouched = true;
				}
			}

			//move animation marker & update animation
			curAnimation.t = timelinePercent;

		}

		return isKeyframeTouched;
	}

	function onmouseup_animate(e:MouseEvent) {
		if (selectedKeyframeOnMousedown) {
			var timelineX = Luxe.screen.w * 0.1;
			var timelineW = Luxe.screen.w * 0.8;
			var selectX = Maths.clamp(e.pos.x - timelineX, 0, timelineW);
			var timelinePercent = selectX / timelineW;
			curAnimation.move(curAnimation.t, timelinePercent);
			curAnimation.t = timelinePercent;
		}

		isTouchingTimeline = false;
		selectedKeyframeOnMousedown = false;
	}

	function update_animate( dt:Float ) {
		//draw timeline
		var timelineY = Luxe.screen.h * 0.9;
		var timelineX = Luxe.screen.w * 0.1;
		var timelineW = Luxe.screen.w * 0.8;

		Luxe.draw.line({
				p0: new Vector(timelineX, timelineY),
				p1: new Vector(timelineX + timelineW, timelineY),
				batcher: uiScreenBatcher,
				immediate: true
			});

		if (curAnimation != null) {
			if (!selectedKeyframeOnMousedown) {
				var animationProgressMarkerX = timelineX + (timelineW * curAnimation.t);
				Luxe.draw.line({
						p0: new Vector(animationProgressMarkerX, timelineY - 15),
						p1: new Vector(animationProgressMarkerX, timelineY + 15),
						batcher: uiScreenBatcher,
						immediate: true
					});
			}

			for (t in curAnimation.times()) {
				var keyframeX = timelineX + (timelineW * t);

				if (t == curAnimation.t) {
					if (selectedKeyframeOnMousedown) {
						var selectX = Maths.clamp(Luxe.screen.cursor.pos.x, timelineX, timelineX + timelineW);
						keyframeX = selectX;
					}
					Luxe.draw.circle({
							x: keyframeX, 
							y: timelineY,
							r: 10,
							batcher: uiScreenBatcher,
							immediate: true
						});
				}
				else {
					Luxe.draw.ring({
							x: keyframeX, 
							y: timelineY,
							r: 10,
							batcher: uiScreenBatcher,
							immediate: true
						});
				}
			}
		}

		renderSelectionBounds();
	}

	/* SKETCH */
	function onkeydown_sketch( e:KeyEvent ) {
		if (e.keycode == Key.backspace) {
			sketchLines = [];
		}
	}

	function onmousedown_sketch( e:MouseEvent ) {
		var p = Luxe.camera.screen_point_to_world(e.pos);
		curSketchLine = [];
		curSketchLine.push(p);
		sketchLines.push(curSketchLine);
	}

	function onmousemove_sketch(e:MouseEvent) {
		var p = Luxe.camera.screen_point_to_world(e.pos);
		if (Luxe.input.mousedown(luxe.MouseButton.left)) {
			curSketchLine.push(p);
		}
	}

	function get_selected() : Vex {
		if (multiSelection.length > 0) return multiSelection[0];
		return null;
	}

	function set_selected(v:Vex) : Vex {
		multiSelection = (v != null) ? [v] : [];
		return v;
	}

	function switchMode(nextMode:EditorMode) {
		if (mode == EditorMode.Draw) drawingPath = [];
		if (mode == EditorMode.Animate) root.resetToBasePose();
		mode = nextMode;
	}

	function renderDrawingPath() {
		if (drawingPath.length > 0) {

			//start circle
			var pathStartWorldPos = Luxe.camera.world_point_to_screen(drawingPath[0]);
			Luxe.draw.ring({
				x: pathStartWorldPos.x,
				y: pathStartWorldPos.y,
				r: distToClosePath,
				color: new Color(1,1,1),
				immediate: true,
				batcher: uiScreenBatcher
			});

			//draw path
			if (drawingPath.length > 1) {
				for (i in 1 ... drawingPath.length) {
					Luxe.draw.line({
							p0: new Vector(drawingPath[i-1].x, drawingPath[i-1].y),
							p1: new Vector(drawingPath[i].x, drawingPath[i].y),
							color: Palette.Colors[curPalIndex],
							immediate: true,
							batcher: uiSceneBatcher
						});

					var curPointWorldPos = Luxe.camera.world_point_to_screen(drawingPath[i]);
					Luxe.draw.ring({ //draw path points
							x:curPointWorldPos.x, y:curPointWorldPos.y,
							r: 5,
							color: new Color(1,1,1),
							immediate: true,
							batcher: uiScreenBatcher
						});
				}
			}

		}
	}

	function renderSelectionBounds() {
		for (s in multiSelection) {
			/*
			var selectedBounds = s.bounds();
			var boundsVertices = selectedBounds.transformedVertices;
			*/
			var boundsColor = new Color(1,1,1);
			if (s.properties.type == "group") boundsColor = new Color(1,1,0);
			if (s.properties.type == "ref") boundsColor = new Color(0,1,1);

			var boundsVertices = s.boundsWorld();
			for (i in 0 ... boundsVertices.length) {
				var v0 = boundsVertices[ i ];
				var v1 = boundsVertices[ cast((i+1)%boundsVertices.length) ];
				Luxe.draw.line({
						p0: v0, p1: v1,
						color: boundsColor,
						batcher: uiSceneBatcher,
						immediate: true
					});
			}

			if (s.properties.pos != null) {
				var p = s.toWorldSpace2(s.properties.pos);
				Luxe.draw.ring({
						x: p.x, y: p.y,
						r: 8,
						immediate: true,
						color: boundsColor,
						batcher: uiSceneBatcher
					});
			}
		}
	}


} //Main
