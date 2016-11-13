
import luxe.Input;
import luxe.Visual;
import luxe.Vector;
import luxe.Color;
import luxe.Camera;
import luxe.resource.Resource.JSONResource;
import phoenix.Batcher;
import luxe.utils.Maths;
import phoenix.geometry.Geometry;

import vexlib.Vex;
import vexlib.Palette;
import vexlib.VexPropertyInterface;
import vexlib.Animation;
import vexlib.VexTools;
import vexlib.EditingTools;

import Command;

/*

	TODO NEXT WEEK
	- dialog only vignette
		X script
		X new dialog builder tool
		- order: 1. write script, 2. brainstorm dialog needs, 3. create dialog tool, 4. make game, 5. release !?!?

	BUGS
	- other bugs and stuff
		- origin drawn position gets off after translate
		- !!! need to make movement/translation like this: click once to select, again to move
		- be able to rationally control z-order of grouped objects...
		- ability to break out all the "tracks" of animatino in the ui
		- "freeze" a vex on a frame w/o changing it
		- reset a single vex to its base state
		- vex base state methods
		- animate to vex base state
		- control decimal accuracy of save data
		- uneccessary proliferation of "type: 'animation'" in subtracks
		- keyframe t snapping for frames close to 0.0 and 1.0
		- trouble subselecting (because of scaling?)

	TODO Next
	- script for dialog-only game/scene
		- vex-based dialog editor
			- line smoothing
		- create new dialog system
	- allow relative depths for children vs parent
	- path point editor mode
	- improved lines
		- multipath vex
		- interpolateable paths
		- line smoothing
		- improve mesh line corners

	TODO
	- commandify and catch errors gracefully
	- text command palette
	- right click pan
	- morph
	- nongroup children
	- temp file
	- auto saving

	TODO Backlog
	- fix selection bug (happens after running animation???)
	- improve select-into-groups
	- insert objects inside of a group
	- clean up animation format
	- tween two animations
	- palette editor
	- naming scheme for Vex and related formats
	- ? maybe switch bounds off of a bounding box model to collision polys??
	- ? separate level editor
	- ? level editor mode in editor
	- animation references in models
	- parallax layers
	- animate palette colors (e.g. pal1 ---> pal2)
	- commandify new actions to allow undo/redo
	- rotate and scale "handles"
	- add real clipboard support
	- allow de-selection in multiselect
	- update translation property on release only?
	- make it so common vector commands (.add .subtract) work on properties
	- query what kind of property a property is (how?)
	- stop duplication in code between edit / animation modes
	- consolidate control shortcut keys
	- allow cmd+o / cmd+s to mean different things in different modes
	- ?create different file extensions for different vex formats? (.vex, .vxa, .vxp)
	- allow multiple animations to be loaded in the editor at once
	- figure out reliable way to make undo/redo work
	- clean up async loading code in Vex
	- clean up world space / local space code in Vex (make a transform helper again?)
	- rename ___Format typedef names to something more descriptive?
	- general cleanup of animation code
		- reduce Null-able objects in animation code
		- why do I need toFloat() to use <= for Properties?
	- allow pause()-ing animations
*/

enum EditorMode {
	Draw;
	Edit;
	Animate;
	Sketch;
}

class Main extends luxe.Game {

	public static var instance : Main; //hacky

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

	var curPalIndex = 1; //using 0 for the bg

	var clipboard : String;

	//sketchmode
	var sketchLines : Array<Array<Vector>> = [];
	var curSketchLine : Array<Vector>;
	var sketchGeo : Array<Geometry> = [];

	//drawing tools
	var currentTool = "poly";
	var curLineWeight = 0;
	var lineWeights = ["thin", "regular", "thick"];

	override function ready() {
		instance = this;

		Luxe.camera.pos.subtract(Luxe.screen.mid); //put 0,0 in the center of the camera
		Luxe.camera.size_mode = luxe.Camera.SizeMode.fit;

		Luxe.renderer.batcher.layer = 0;

		var uiCam = new Camera({name:"uiCam"});
		uiScreenBatcher = Luxe.renderer.create_batcher({name:"uiScreenBatcher", layer:10, camera:uiCam.view});
		uiSceneBatcher = Luxe.renderer.create_batcher({name:"uiSceneBatcher", layer:5, camera:Luxe.camera.view});

		//init drawing
		root = new Vex({
				type: "group",
				origin: "0,0",
				pos: "0,0"
			});

		//load default palettes - hacky nonsense
		var load = Luxe.resources.load_json('assets/testpal.vex');
		load.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			Palette.Load(json);
			Palette.Init("test");
			Luxe.renderer.clear_color = Palette.Colors[0];
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
			for (g in sketchGeo) {
				if (showSketchLayer) {
					uiSceneBatcher.add(g);
				}
				else {
					uiSceneBatcher.remove(g);
				}
			}
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

		//load a different palette
		if (e.keycode == Key.key_p && e.mod.lalt) {
			var json = EditingTools.openJson();
			Palette.Load(json);
			Palette.Swap(json.id, 1);
		}
		if (e.keycode == Key.key_p && e.mod.lshift) {
			Palette.SwapNext(1);
		}

		//open
		if (e.keycode == Key.key_o && e.mod.meta ) {

			//destroy current image
			root.destroy();

			//load new image
			root = EditingTools.openVex();

		}

		//save
		if (e.keycode == Key.key_s && e.mod.meta ) {
			EditingTools.saveVex(root);
		}

		//import ref
		if (e.keycode == Key.key_r && e.mod.meta) {
			var vex = EditingTools.importVexReference();
			vex.parent = root;
			selected = vex;
		}

		//edit id
		if (e.keycode == Key.key_i && e.mod.meta) {
			if (selected != null) {
				isEditingId = !isEditingId;
				if (isEditingId) selected.properties.id = "";
			}
		}

		//copy paste
		if (e.keycode == Key.key_c && e.mod.meta) {
			if (selected != null) {
				EditingTools.copyVex( selected );
			}
			else {
				EditingTools.copyVex( root );
			}
		}
		if (e.keycode == Key.key_v && e.mod.meta) {
			var vex = EditingTools.pasteVex();
			vex.parent = root;	
		}

		// TODO new version of undo redo
		//undo redo
		/*
		if (e.keycode == Key.key_z && e.mod.meta) Command.Undo();
		if (e.keycode == Key.key_y && e.mod.meta) Command.Redo();
		*/

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
		/*
		var isAltHeld = Luxe.input.keydown(Key.lalt) || Luxe.input.keydown(Key.ralt);
		if (isAltHeld) {
			isPanning = true;
			return;
		}
		*/
		if (e.button == luxe.Input.MouseButton.right) {
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
		/*
		if (isPanning) {
			Luxe.camera.pos.x -= e.x_rel / Luxe.camera.zoom;
			Luxe.camera.pos.y -= e.y_rel / Luxe.camera.zoom;
			return;
		}
		*/
		//todo editingtools
		if ( EditingTools.panCameraWhileRightMouseDown( Luxe.camera, e ) ) {
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
			case Sketch: onmouseup_sketch(e);
			default: return;
		}
	}

	override function onmousewheel(e:MouseEvent) {
		/* ZOOMING */
		EditingTools.zoomCamera( Luxe.camera, e );
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

		// DRAW ORIGIN
		EditingTools.drawWorldOrigin( uiSceneBatcher );

		/* mode specific update functions */
		switch(mode) {
			case Draw: update_draw(dt);
			case Edit: update_edit(dt);
			case Animate: update_animate(dt);
			case Sketch: update_sketch(dt);
			default: return;
		}

	} //update

	/* DRAW */
	function onkeydown_draw( e:KeyEvent ) {
		//delete selected element
		if (e.keycode == Key.backspace) {
			if (multiSelection.length > 0) {
				//TODO my command suck, so I'm ripping them out for now
				//new DeleteCommand(multiSelection);
				for (s in multiSelection) {
					s.destroy(true);
				}
				multiSelection = [];
			}
		}

		//change color
		if (e.keycode == Key.key_f && e.mod.meta) {
			if (multiSelection.length > 0) {
				//new ColorCommand(multiSelection, "pal(" + curPalIndex + ")");
				for (s in multiSelection) {
					s.properties.color = "pal(" + curPalIndex + ")";
				}
			}
		}

		//change tool
		if (e.keycode == Key.key_t && e.mod.meta) {
			if (currentTool == "poly") {
				currentTool = "line";
			}
			else {
				currentTool = "poly";
			}
		}
		//change weight
		if (currentTool == "line" && e.keycode == Key.key_w && e.mod.meta) {
			curLineWeight = (curLineWeight + 1) % lineWeights.length;
		}
	}

	function onmousedown_draw( e:MouseEvent ) {
		var p = Luxe.camera.screen_point_to_world(e.pos);
		var pathResults = EditingTools.buildPath( drawingPath, p, 
													(distToClosePath / Luxe.camera.zoom) /*nearDistance*/, 
													(currentTool == "line") /*canLeaveOpen*/ );
		drawingPath = pathResults.path;

		if (pathResults.isPathFinished) {
			if (currentTool == "line" && pathResults.isPathClosed)
				drawingPath.push( drawingPath[0].clone() ); //add final point for looped line

			//create and select vex
			var vex = new Vex( EditingTools.setPathProperties( drawingPath, false /*isCentered*/, 
								{
									type: currentTool,
									id: "poly" + count,
									color: "pal(" + curPalIndex + ")",
									depth: count
								} ) );
			vex.parent = root;
			selected = vex;

			//clear drawing path
			drawingPath = [];
			count++;
		}
	}

	function update_draw( dt:Float ) {
		//tool
		Luxe.draw.text({
				text: "tool: " + currentTool,
				point_size: 16,
				batcher: uiScreenBatcher,
				pos: new Vector(0,40),
				immediate: true
			});
		//line thickness
		if (currentTool == "line") {
			if (selected != null) {
				Luxe.draw.text({
						text: "weight: " + lineWeights[curLineWeight],
						point_size: 16,
						batcher: uiScreenBatcher,
						pos: new Vector(0,60),
						immediate: true
					});
			}
		}

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
		//z order
		if (e.keycode == Key.up && e.mod.lshift) {
			for (sel in multiSelection) { //TODO commandify
				var depth = sel.depth + 1;
				sel.properties.depth = depth; //hacky?
				trace(sel.depth);
			}
		}
		else if (e.keycode == Key.down && e.mod.lshift) {
			for (sel in multiSelection) {
				var depth = sel.depth - 1;
				sel.properties.depth = depth;
				trace(sel.depth);
			}
		}

		//delete selected element
		if (e.keycode == Key.backspace) {
			if (multiSelection.length > 0) {
				//new DeleteCommand(multiSelection);
				for (s in multiSelection) {
					s.destroy(true);
				}
				multiSelection = [];
			}
		}

		//change color
		if (e.keycode == Key.key_f && e.mod.meta) {
			if (multiSelection.length > 0) {
				//new ColorCommand(multiSelection, "pal(" + curPalIndex + ")");
				for (s in multiSelection) {
					s.properties.color = "pal(" + curPalIndex + ")";
				}
			}
		}

		//group selected elements
		if (e.keycode == Key.key_g && e.mod.meta) {
			if (multiSelection.length > 1) {
				var g = EditingTools.groupVex( multiSelection );

				//add group to scene
				g.parent = root;
				selected = g;
			}
		}

		//ungroup selected group
		if (e.keycode == Key.key_u && e.mod.meta) {
			if ( selected != null && (selected.properties.type == "group" || selected.properties.type == "ref") ) {
				EditingTools.ungroupVex( selected );

				//remove group from scene
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
				selected = EditingTools.setOrigin( selected, newOriginWorldSpace );
			}
		}
		else if (isShiftHeld) {
			multiSelection = EditingTools.multiselect( multiSelection, p, root );
		}
		else {
			selected = EditingTools.select( selected, p, root );
		}
	}

	function onmousemove_edit(e:MouseEvent) {
		/* TRANSLATE SELECTION */
		if (Luxe.input.mousedown(luxe.MouseButton.left)) {
			if (multiSelection.length > 0) {
				for (sel in multiSelection) {
					//TODO live edit the Vex pos, then ON RELEASE update the property
					var pos = sel.pos.clone(); //this is starting to feel roundabout...
					pos.x += e.x_rel / Luxe.camera.zoom;
					pos.y += e.y_rel / Luxe.camera.zoom;
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
	var isTranslatingSelection = false;

	function onkeydown_animate( e:KeyEvent ) {
		//open animation
		//TODO overload key_o instead
		if (e.keycode == Key.key_a && e.mod.meta) {
			//load file
			curAnimation = root.addAnimation( EditingTools.openJson() );
		}

		//make new animation
		if (e.keycode == Key.key_n && e.mod.meta) {
			curAnimation = root.addAnimation({id:"newAnimation"});
		}

		//play animation
		if (e.keycode == Key.key_p && e.mod.meta) {
			root.playAnimation(curAnimation.id, 5)
					.onComplete(function() {
							trace("animation complete!");
							root.resetToBasePose();
						});
		}

		if (curAnimation != null) { //TODO should I ensure that curAnimation is never null?

			//export animation //TODO overload cmd+s
			if (e.keycode == Key.key_e && e.mod.meta) {
				var json = curAnimation.serialize();
				EditingTools.saveJson( json );
			}

			//delete current keyframe
			if (e.keycode == Key.backspace) {
				curAnimation.delete(curAnimation.t);
				curAnimation.t = curAnimation.t; //update the view
			}

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
		/* TRANSLATE SELECTION */
		else if (Luxe.input.mousedown(luxe.MouseButton.left)) {
			if (multiSelection.length > 0) {
				for (sel in multiSelection) {
					sel.pos.x += e.x_rel / Luxe.camera.zoom;
					sel.pos.y += e.y_rel / Luxe.camera.zoom;
					isTranslatingSelection = true;
				}
			}
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

		if (isTranslatingSelection) {
			for (sel in multiSelection) {
				curAnimation.set({
					t : curAnimation.t,
					select : sel.properties.id, //do I rely too much on everything having a unique id?
					pos : sel.pos
				});
			}
		}

		isTouchingTimeline = false;
		selectedKeyframeOnMousedown = false;
		isTranslatingSelection = false;
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
			//sketchLines = [];
			for (g in sketchGeo) {
				uiSceneBatcher.remove(g);
			}
			sketchGeo = [];
		}
	}

	function onmousedown_sketch( e:MouseEvent ) {
		var p = Luxe.camera.screen_point_to_world(e.pos);
		curSketchLine = [];
		curSketchLine.push(p);
		//sketchLines.push(curSketchLine);
	}

	function onmousemove_sketch(e:MouseEvent) {
		var p = Luxe.camera.screen_point_to_world(e.pos);
		if (Luxe.input.mousedown(luxe.MouseButton.left)) {
			curSketchLine.push(p);
		}
	}

	function onmouseup_sketch(e:MouseEvent) {
		//make line permanent
		if (curSketchLine != null) {
			if (curSketchLine.length >= 2) {
				for (i in 1 ... curSketchLine.length) {
					sketchGeo.push( Luxe.draw.line({
							p0: curSketchLine[i-1],
							p1: curSketchLine[i],
							color: new Color(1,1,1,0.5),
							batcher: uiSceneBatcher
						}) );
				}
			}
			curSketchLine = [];	
		}
	}

	function update_sketch(dt:Float) {
		//draw line in progress
		if (curSketchLine == null) return;
		if (curSketchLine.length >= 2) {
			for (i in 1 ... curSketchLine.length) {
				Luxe.draw.line({
						p0: curSketchLine[i-1],
						p1: curSketchLine[i],
						batcher: uiSceneBatcher,
						color : new Color(1,1,1,0.5),
						immediate:true
					});
			}
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
			EditingTools.drawPath( drawingPath, Palette.Colors[curPalIndex], uiSceneBatcher );
			EditingTools.drawPoints( drawingPath, 5, uiScreenBatcher );
			EditingTools.drawEndPoints( drawingPath, distToClosePath, currentTool, uiScreenBatcher );
		}
	}

	function renderSelectionBounds() {
		EditingTools.drawVexBounds( multiSelection, uiSceneBatcher );
	}


} //Main
