
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

//import luxe.GameConfig; // todo shader-rendering

import vexlib.Vex;
import vexlib.Palette;
import vexlib.VexPropertyInterface;
import vexlib.Animation;
import vexlib.VexTools;
import vexlib.Editor;
import vexlib.EditingTools;

import Command;

/*
	PIGEON TODOS
	X isPointInside bug
	- cmd-n (new)
	- cmd-a (select all)
	- auto save work so far
	- need animation without naming everything in local storage
	X need to fix sub-selction in groups
	X switch colors 0-7, 8-15
	- change default animation speed
	- show color palete in other modes beside draw
*/

/*
REFACTORING masterplan
X remove chunks of related input code & put in editing tools
- turn editing modes into states (in their own files)
	X draw
	X edit
	X animate
	- sketch
X figure out globals (root of scene, batchers, anything else?)
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

class Main extends luxe.Game {

	//states
	var machine : States;
	var states = ["draw","edit","animate"];
	var stateIndex = 0;

	//flags
	var isEditingId = false;

	var palOffset = 0;

	// todo shader-rendering
	/*
	override function config(config:GameConfig) {
		//todo hide in parent class
		//todo move into vexlib somehow
		config.preload.shaders.push({id:'polyshader',vert_id:'assets/shaders/polyvert.glsl',frag_id:'assets/shaders/polyfrag.glsl'});
		return config;
	}
	*/

	override function ready() {

		Editor.setup();

		machine = new States( {name:"editor_state_machine"} );
		machine.add( new DrawState({name:"draw"}) );
		machine.add( new EditState({name:"edit"}) );
		machine.add( new AnimateState({name:"animate"}) );
		machine.set("draw");
	} //ready

	override function onkeydown( e:KeyEvent ) {

		//switch modes
		if (e.keycode == Key.right && e.mod.lalt) {
			stateIndex = (stateIndex + 1) % states.length;
			machine.set( states[stateIndex] );
		}
		if (e.keycode == Key.left && e.mod.lalt) {
			stateIndex = (stateIndex - 1) % states.length;
			if (stateIndex < 0) stateIndex = states.length - 1;
			machine.set( states[stateIndex] );
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

		//toggle pal offset
		if (e.keycode == Key.key_c && e.mod.lshift) {
			if (palOffset == 0)
				palOffset = 8;
			else
				palOffset = 0;
		}

		// TODO new version of undo redo
	}

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function ontextinput(e:TextEvent) {
		trace(e);

		//edit id
		if (isEditingId) {
			Editor.selection.properties.id += e.text; //TODO command-ify
		}

		//change current color
		var n = Std.parseInt(e.text);
		if (n != null && n > 0 && n < 9) {
			var palIndex = (n - 1) + palOffset;
			Editor.curPalIndex = palIndex;
		} 
	}

	override function onmousedown( e:MouseEvent ) {}

	override function onmousemove(e:MouseEvent) {
		/* PANNING */
		if ( EditingTools.mousemovePanCamera( Luxe.camera, e ) ) {
			return;
		}
	}

	override function onmouseup(e:MouseEvent) {}

	override function onmousewheel(e:MouseEvent) {
		/* ZOOMING */
		EditingTools.zoomCamera( Luxe.camera, e );
	}

	override function update(dt:Float) {

		//current mode
		Luxe.draw.text({
				text: "mode: " + states[stateIndex],
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

	} //update




	//TODO move sketch mode into its own state
	/* SKETCH */
	var showSketchLayer = true;
	var sketchLines : Array<Array<Vector>> = [];
	var curSketchLine : Array<Vector>;
	var sketchGeo : Array<Geometry> = [];
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

} //Main
