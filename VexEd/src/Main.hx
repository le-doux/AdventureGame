
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
import phoenix.geometry.Geometry;

import vexlib.Vex;
import vexlib.Palette;
import vexlib.VexPropertyInterface;
import vexlib.Animation;

import Command;

/*
	TODO Next
	- vector vs. raster (tiling) decision
	- attempt better character animation w/ vector
	- script for dialog-only game/scene
		- vex-based dialog editor?
		- create new dialog system (raster font)?
	- universal input handler
	X z depth control
		- allow relative depths for children vs parent
		X keyboard controls
	X draw lines
		~ line thickness control [started]
	- path point editor mode
	X TODO automatic DEPTH
	X TODO sketch perf
	- better default palette for main char

	TODO Backlog
	- fix selection bug (happens after running animation???)
	- improve select-into-groups
	- insert objects inside of a group
	- clean up animation format
	- tween two animations
	- palette editor
	- naming scheme for Vex and related formats
	X load palettes at will
	- ? maybe switch bounds off of a bounding box model to collision polys??
	- ? separate level editor
	- ? level editor mode in editor
	- animation references in models
	- parallax layers
	X why don't grays render the way I expect? color unpacking?
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
	public var lineThinBatcher : Batcher;
	public var lineRegularBatcher : Batcher;
	public var lineThickBatcher : Batcher;

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
	var sketchGeo : Array<Geometry> = [];

	//drawing tools
	var currentTool = "poly";
	var curLineWeight = 0;
	var lineWeights = ["thin", "regular", "thick"];

	override function ready() {
		instance = this;

		Luxe.camera.pos.subtract(Luxe.screen.mid); //put 0,0 in the center of the camera

		Luxe.renderer.batcher.layer = 0;

		var uiCam = new Camera({name:"uiCam"});
		uiScreenBatcher = Luxe.renderer.create_batcher({name:"uiScreenBatcher", layer:10, camera:uiCam.view});
		uiSceneBatcher = Luxe.renderer.create_batcher({name:"uiSceneBatcher", layer:5, camera:Luxe.camera.view});

		/* line batchers */
		//TODO make liens exist on same plane as geometry
		lineThinBatcher = Luxe.renderer.create_batcher({name:"lineThinBatcher", layer:0, camera:Luxe.camera.view});
		lineThinBatcher.on(prerender, untyped function(b) { b.renderer.state.lineWidth(1); });
		lineThinBatcher.on(postrender, untyped function(b) { b.renderer.state.lineWidth(1); });

		lineRegularBatcher = Luxe.renderer.create_batcher({name:"lineRegularBatcher", layer:0, camera:Luxe.camera.view});
		lineRegularBatcher.on(prerender, untyped function(b) { b.renderer.state.lineWidth(2); });
		lineRegularBatcher.on(postrender, untyped function(b) { b.renderer.state.lineWidth(1); });

		lineThickBatcher = Luxe.renderer.create_batcher({name:"lineThickBatcher", layer:0, camera:Luxe.camera.view});
		lineThickBatcher.on(prerender, untyped function(b) { b.renderer.state.lineWidth(4); });
		lineThickBatcher.on(postrender, untyped function(b) { b.renderer.state.lineWidth(1); });

		//TODO doublethick lines?


		//init drawing
		root = new Vex({
				type: "group",
				origin: "0,0",
				pos: "0,0"
			});

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
			//load file
			var path = Dialogs.open("Open dialog");
			var fileStr = File.getContent(path);
			var json = Json.parse(fileStr);
			Palette.Load(json);
			Palette.Swap(json.id, 1);
		}
		if (e.keycode == Key.key_p && e.mod.lshift) {
			Palette.SwapNext(1);
		}

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
			case Sketch: onmouseup_sketch(e);
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
		/*
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
		*/

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

		/*
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
		*/

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

		//is the path closed?
		var isPathClosed = false;
		if (drawingPath.length > 2) {
			if ( Vector.Subtract(p,drawingPath[0]).length < (distToClosePath / Luxe.camera.zoom) ) {
				isPathClosed = true;
				if (currentTool == "line") {
					drawingPath.push(drawingPath[0].clone());
				}
			}
		}

		//when drawing with a line you can end the path by right clicking anywhere?
		if (e.button == luxe.Input.MouseButton.right && currentTool == "line") {
			isPathClosed = true;
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
					type: currentTool, //"line", //"poly",
					//weight: (currentTool == "line") ? lineWeights[curLineWeight] : null, //TODO ok this is hacky
					pos: topLeft,
					path: drawingPath,
					id: "poly" + count, //I should get rid of this at some point... not everything needs an id
					color: "pal(" + curPalIndex + ")",
					depth: count //is this the best way to determine starting depth? at least it's the easiest
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
	var isTranslatingSelection = false;

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
			root.playAnimation(curAnimation.id, 5)
					.onComplete(function() {
							trace("animation complete!");
							root.resetToBasePose();
						});
		}

		if (curAnimation != null) { //TODO should I ensure that curAnimation is never null?

			//export animation //TODO overload cmd+s
			if (e.keycode == Key.key_e && e.mod.meta) {
				//get path & open file
				var path = Dialogs.save("Save dialog");
				var output = File.write(path);

				//get data & write it
				var saveJson = curAnimation.serialize();
				var saveStr = Json.stringify(saveJson, null, "	");
				output.writeString(saveStr);

				//close file
				output.close();
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
					sel.pos.x += e.xrel / Luxe.camera.zoom;
					sel.pos.y += e.yrel / Luxe.camera.zoom;
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
		if (curSketchLine.length >= 2) {
			for (i in 1 ... curSketchLine.length) {
				sketchGeo.push( Luxe.draw.line({
						p0: curSketchLine[i-1],
						p1: curSketchLine[i],
						batcher: uiSceneBatcher
					}) );
			}
		}
		curSketchLine = [];
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
