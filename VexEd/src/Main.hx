
import luxe.Input;
import luxe.Visual;
import luxe.Vector;
import luxe.Color;

import vexlib.Vex;
import vexlib.Palette;
import vexlib.VexPropertyInterface;

import sys.io.File;
import haxe.Json;
import dialogs.Dialogs;
import luxe.resource.Resource.JSONResource;

import Command;

/*
	TODO for better animated character
	- animation editor
		- add mode support to editor
		- create timeline
		- ? clean up animation format
		- functionalize editing commands so they don't always update properties
		- make editing commands update animation frames
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
	- sketch layer
	- need to handle animation edge cases better
		- edge cases: no start frame, no end frame, ???
		- need to be able to reset to base "pose"
	- report luxe bugs
*/

class Main extends luxe.Game {

	var drawingPath : Array<Vector> = [];
	var distToClosePath = 16;

	var root : Vex;
	var selected (get, set) : Vex;
	var multiSelection : Array<Vex> = [];

	var count = 0;

	/* STATE FLAGS */
	var isEditingId = false;
	var isDrawingMode = true;
	var isPanning = false;

	var isSketchMode = false; //TODO enums or states plz
	var showSketchLayer = true;

	var curPalIndex = 0;

	var clipboard : String;

	//sketchmode
	var sketchLines : Array<Array<Vector>> = [];
	var curSketchLine : Array<Vector>;

	override function ready() {
		Luxe.camera.pos.subtract(Luxe.screen.mid); //put 0,0 in the center of the camera

		//init drawing
		root = new Vex({
				type: "group",
				origin: "0,0",
				pos: "0,0"
			});

		//draw origin
		Luxe.draw.line({
				p0: new Vector(-Luxe.screen.width/2, 0),
				p1: new Vector(Luxe.screen.width/2, 0)
			});
		Luxe.draw.line({
				p0: new Vector(0, -Luxe.screen.height/2),
				p1: new Vector(0, Luxe.screen.height/2)
			});

		//load default palettes - hacky nonsense
		var load = Luxe.resources.load_json('assets/default.pal');
		load.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			Palette.Load(json);
			Palette.Init("default");
		});
	} //ready

	function get_selected() : Vex {
		if (multiSelection.length > 0) return multiSelection[0];
		return null;
	}

	function set_selected(v:Vex) : Vex {
		multiSelection = (v != null) ? [v] : [];
		return v;
	}

	override function ontextinput(e:TextEvent) {
		//edit id
		if (isEditingId) {
			//WILL THIS WORK?
			selected.properties.id += e.text; //TODO command-ify
		}

		//change current color
		var n = Std.parseInt(e.text);
		if (n != null && n > 0 && n < 9) {
			curPalIndex = n - 1;
		} 
	}

	override function onkeydown( e:KeyEvent ) {

		//enter edit mode
		if (e.keycode == Key.key_e && e.mod.meta) {
			isDrawingMode = false;
			drawingPath = [];
		}

		//toggle sketch mode
		if (e.keycode == Key.key_k && e.mod.meta) {
			isSketchMode = !isSketchMode;
		}
		if (e.keycode == Key.key_k && e.mod.lalt) {
			showSketchLayer = !showSketchLayer;
		}


		//enter drawing mode
		if (e.keycode == Key.key_d && e.mod.meta) {
			isDrawingMode = true;
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

		//delete selected element
		if (e.keycode == Key.backspace) {
			if (isSketchMode) {
				sketchLines = [];
			}
			else if (multiSelection.length > 0) {
				new DeleteCommand(multiSelection);
				multiSelection = [];
			}
		}

		//edit id
		if (e.keycode == Key.key_i && e.mod.meta) {
			if (selected != null) {
				isEditingId = !isEditingId;
				if (isEditingId) selected.properties.id = "";
			}
		}

		//change color
		if (e.keycode == Key.key_f && e.mod.meta) {
			if (selected != null) {
				new ColorCommand(multiSelection, "pal(" + curPalIndex + ")");
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

	override function onmousedown( e:MouseEvent ) {

		var p = Luxe.camera.screen_point_to_world(e.pos);

		/* DRAWING MODE */
		var isShiftHeld = Luxe.input.keydown(Key.lshift) || Luxe.input.keydown(Key.rshift);
		var isAltHeld = Luxe.input.keydown(Key.lalt) || Luxe.input.keydown(Key.ralt);
		if (isAltHeld) {
			isPanning = true;
		}
		else if (isSketchMode) {
			curSketchLine = [];
			curSketchLine.push(p);
			sketchLines.push(curSketchLine);
		}
		else if (isDrawingMode) {
			//is the path closed?
			var isPathClosed = false;
			if (drawingPath.length > 2) {
				if ( Vector.Subtract(p,drawingPath[0]).length < distToClosePath ) {
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
		/* EDIT MODE */
		else {
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
	}

	override function onmousemove(e:MouseEvent) {
		var p = Luxe.camera.screen_point_to_world(e.pos);
		//todo sketching

		/* PAN */
		if (isPanning) {
			Luxe.camera.pos.x -= e.xrel / Luxe.camera.zoom;
			Luxe.camera.pos.y -= e.yrel / Luxe.camera.zoom;
		}

		/* TRANSLATE */
		if (isSketchMode) {
			if (Luxe.input.mousedown(luxe.MouseButton.left)) {
				curSketchLine.push(p);
			}
		}
		//TODO turn this into a command?
		else if (!isDrawingMode) { //TODO make states or mode enums or something
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
	}

	override function onmouseup(e:MouseEvent) {
		isPanning = false;
	}

	override function onmousewheel(e:MouseEvent) {

		/* ZOOMING */
		Luxe.camera.zoom += e.yrel * 0.03 * Luxe.camera.zoom;
		
	}

	override function update(dt:Float) {
		//draw cursor
		var cursorPos = Luxe.camera.screen_point_to_world( Luxe.screen.cursor.pos );
		Luxe.draw.circle({
				x: cursorPos.x,
				y: cursorPos.y,
				r: distToClosePath/2,
				color: Palette.Colors[curPalIndex],
				immediate: true
			});

		renderDrawingPath();

		if (selected != null) {
			Luxe.draw.text({
					text: "id: " + selected.properties.id,
					point_size: 16,
					pos: Vector.Multiply( Luxe.screen.mid, -1),
					immediate: true
				});
		}

		if (!isDrawingMode) {
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
							depth:100,
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
							depth: 100
						});
				}
			}
		}

		//draw sketch
		if (showSketchLayer) {
			for (l in sketchLines) {
				for (i in 1 ... l.length) {
					Luxe.draw.line({
							p0: l[i-1],
							p1: l[i],
							depth:100,
							immediate:true
						});
				}
			}
		}

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

	} //update

	function renderDrawingPath() {
		if (drawingPath.length > 0) {

			//start circle
			Luxe.draw.ring({
				x: drawingPath[0].x,
				y: drawingPath[0].y,
				r: distToClosePath,
				color: Palette.Colors[curPalIndex],
				immediate: true,
				depth: 100 //I need a separate UI layer
			});

			//draw path
			if (drawingPath.length > 1) {
				for (i in 1 ... drawingPath.length) {
					Luxe.draw.line({
							p0: new Vector(drawingPath[i-1].x, drawingPath[i-1].y),
							p1: new Vector(drawingPath[i].x, drawingPath[i].y),
							color: Palette.Colors[curPalIndex],
							immediate: true,
							depth: 100
						});
				}
			}

		}
	}


} //Main
