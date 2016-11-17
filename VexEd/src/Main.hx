
import luxe.Input;
import luxe.Visual;
import luxe.Vector;
import luxe.Color;
import luxe.Camera;
import luxe.resource.Resource.JSONResource;
import phoenix.Batcher;
import luxe.utils.Maths;
import phoenix.geometry.Geometry;
import luxe.States;

import vexlib.Vex;
import vexlib.Palette;
import vexlib.VexPropertyInterface;
import vexlib.Animation;
import vexlib.VexTools;
import vexlib.Editor;
import vexlib.EditingTools;

import Command;

/*
REFACTORING masterplan
X remove chunks of related input code & put in editing tools
- turn editing modes into states (in their own files)
- figure out globals (root of scene, batchers, anything else?)
- more comprehensive selection model
- rethink undo/redo entirely
*/

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

//TODO replace with states that each have a root vex
enum EditorMode {
	Draw;
	Edit;
	Animate;
	Sketch;
}

class Main extends luxe.Game {

	var machine : States;

	var mode : EditorMode = EditorMode.Draw;

	/* STATE FLAGS */
	var isEditingId = false;
	var showSketchLayer = true;

	//sketchmode
	var sketchLines : Array<Array<Vector>> = [];
	var curSketchLine : Array<Vector>;
	var sketchGeo : Array<Geometry> = [];

	override function ready() {
		Editor.setup();

		machine = new States({name:"editor_state_machine"});
		machine.add( new DrawState({name:"draw"}) );
		machine.set("draw");
	} //ready

	override function onkeydown( e:KeyEvent ) {

		//TODO replace modes with states (alt-key palette)
		//switch modes
		/*
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
		*/

		switch (mode) {
			case Edit: onkeydown_edit(e);
			case Sketch: onkeydown_sketch(e);
			case Animate: onkeydown_animate(e);
		}

		//toggle sketch visibility
		if (e.keycode == Key.key_k && e.mod.lalt) {
			showSketchLayer = !showSketchLayer;
			for (g in sketchGeo) {
				if (showSketchLayer) {
					Editor.batcher.uiWorld.add(g);
				}
				else {
					Editor.batcher.uiWorld.remove(g);
				}
			}
		}

		//for testing: change background color
		if (e.keycode == Key.key_b && e.mod.meta) {
			Luxe.renderer.clear_color = Palette.Colors[Editor.curPalIndex];
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

		// open/save
		var open = EditingTools.keydownOpenVex( Editor.scene.root, e );
		if (open.success) {
			Editor.scene.root = open.root;
			Editor.selection = null;
		}
		EditingTools.keydownSaveVex( Editor.scene.root, e );

		//import ref
		var reference = EditingTools.keydownImportVexReference( Editor.scene.root, e );
		if (reference.success) Editor.selection = reference.imported;

		//edit id
		if (e.keycode == Key.key_i && e.mod.meta) {
			if (Editor.selection != null) {
				isEditingId = !isEditingId;
				if (isEditingId) Editor.selection.properties.id = "";
			}
		}

		// copy/paste
		EditingTools.keydownCopyPasteVex( Editor.selection, Editor.scene.root, e );

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
			Editor.selection.properties.id += e.text; //TODO command-ify
		}

		//change current color
		var n = Std.parseInt(e.text);
		if (n != null && n > 0 && n < 9) {
			Editor.curPalIndex = n - 1;
		} 
	}

	override function onmousedown( e:MouseEvent ) {

		/* panning */
		if (e.button == luxe.Input.MouseButton.right) {
			return;
		}

		/* mode specific mouse controls */
		switch(mode) {
			case Edit: onmousedown_edit(e);
			case Animate: onmousedown_animate(e);
			case Sketch: onmousedown_sketch(e);
		}
	}

	override function onmousemove(e:MouseEvent) {
		/* PANNING */
		if ( EditingTools.mousemovePanCamera( Luxe.camera, e ) ) {
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
				batcher: Editor.batcher.uiScreen,
				immediate: true
			});

		//id
		if (Editor.selection != null) {
			Luxe.draw.text({
					text: "id: " + Editor.selection.properties.id,
					point_size: 16,
					batcher: Editor.batcher.uiScreen,
					pos: new Vector(0,20),
					immediate: true
				});
		}

		// DRAW ORIGIN
		EditingTools.drawWorldOrigin( Editor.batcher.uiWorld );

		/* mode specific update functions */
		switch(mode) {
			case Edit: update_edit(dt);
			case Animate: update_animate(dt);
			case Sketch: update_sketch(dt);
			default: return;
		}

	} //update

	/* EDIT */
	function onkeydown_edit( e:KeyEvent ) {
		//z order
		EditingTools.keydownChangeDepthVex( Editor.multiselection, e );

		//delete selected element
		Editor.multiselection = EditingTools.keydownDeleteVex( Editor.multiselection, e ).selection;

		//change color
		EditingTools.keydownFillColorVex( Editor.multiselection, "pal(" + Editor.curPalIndex + ")", e );

		//group selected elements
		Editor.multiselection = EditingTools.keydownGroupVex( Editor.multiselection, Editor.scene.root, e );

		//ungroup selected group
		Editor.selection = EditingTools.keydownUngroupVex( Editor.selection, e );

		//rotate selected elements //TODO make command //TODO make rotate handle?
		EditingTools.keydownRotateVex( Editor.multiselection, e );

		//scale selected elements //TODO make command //TODO separate x- and y- axes
		EditingTools.keydownScaleVex( Editor.multiselection, e );
	}

	function onmousedown_edit( e:MouseEvent ) {
		var p = Luxe.camera.screen_point_to_world(e.pos);

		/* SET ORIGIN */
		if ( EditingTools.mousedownSetOriginVex( Editor.multiselection, e ).success ) {
			return;
		}

		/* CHANGE SELECTION */
		Editor.multiselection = EditingTools.mousedownChangeSelection( Editor.multiselection, Editor.scene.root, e ).selection;
	}

	function onmousemove_edit(e:MouseEvent) {
		/* TRANSLATE SELECTION */
		EditingTools.mousemoveTranslateVex( Editor.multiselection, e );
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
			curAnimation = Editor.scene.root.addAnimation( EditingTools.openJson() );
		}

		//make new animation
		if (e.keycode == Key.key_n && e.mod.meta) {
			curAnimation = Editor.scene.root.addAnimation({id:"newAnimation"});
		}

		//play animation
		if (e.keycode == Key.key_p && e.mod.meta) {
			Editor.scene.root.playAnimation(curAnimation.id, 5)
					.onComplete(function() {
							trace("animation complete!");
							Editor.scene.root.resetToBasePose();
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
				for (sel in Editor.multiselection) {
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
				for (sel in Editor.multiselection) {
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
				for (sel in Editor.multiselection) {
					sel.scale.add(new Vector(0.1,0.1)); //TODO do I need defaults for properties???
					curAnimation.set({
							t : curAnimation.t,
							select : sel.properties.id,
							scale : sel.scale
						});
				}
			}
			if (e.keycode == Key.down && e.mod.meta) {
				for (sel in Editor.multiselection) {
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
			if (Editor.selection != null && Editor.selection.properties.type != "ref") newSelection = Editor.selection.getChildWithPointInside(p);
			if (newSelection == null) newSelection = Editor.scene.root.getChildWithPointInside(p);
			Editor.selection = newSelection;
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
			if (Editor.multiselection.length > 0) {
				for (sel in Editor.multiselection) {
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
			for (sel in Editor.multiselection) {
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
				batcher: Editor.batcher.uiScreen,
				immediate: true
			});

		if (curAnimation != null) {
			if (!selectedKeyframeOnMousedown) {
				var animationProgressMarkerX = timelineX + (timelineW * curAnimation.t);
				Luxe.draw.line({
						p0: new Vector(animationProgressMarkerX, timelineY - 15),
						p1: new Vector(animationProgressMarkerX, timelineY + 15),
						batcher: Editor.batcher.uiScreen,
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
							batcher: Editor.batcher.uiScreen,
							immediate: true
						});
				}
				else {
					Luxe.draw.ring({
							x: keyframeX, 
							y: timelineY,
							r: 10,
							batcher: Editor.batcher.uiScreen,
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
				Editor.batcher.uiWorld.remove(g);
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
							batcher: Editor.batcher.uiWorld
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
						batcher: Editor.batcher.uiWorld,
						color : new Color(1,1,1,0.5),
						immediate:true
					});
			}
		}
	}

	/*
	function switchMode(nextMode:EditorMode) {
		if (mode == EditorMode.Draw) drawingPath = [];
		if (mode == EditorMode.Animate) Editor.scene.root.resetToBasePose();
		mode = nextMode;
	}
	*/

	function renderSelectionBounds() {
		EditingTools.drawVexBounds( Editor.multiselection, Editor.batcher.uiWorld );
	}


} //Main
