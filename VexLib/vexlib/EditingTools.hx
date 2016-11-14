package vexlib;

import sys.io.File;
import haxe.Json;
import dialogs.Dialogs; //TODO this import doesn't seem to work in the lib?
import clipboard.Clipboard;

import luxe.Camera;
import luxe.Input;
import luxe.Vector;
import luxe.Color;
import phoenix.Batcher;

import vexlib.VexPropertyInterface;

/*
	Home for static methods used for editing vex drawings, animations, levels, etc.
*/

/*
TODO idea for better undo/redo
- store list/path-thru-tree of unique entity IDs
- store before / after json
- store selection information
*/

class EditingTools {
	
	public static function saveString(str:String) {
		//get path & open file
		var path = Dialogs.save("Save dialog");
		var output = File.write(path);

		//write data
		output.writeString(str);

		//close file
		output.close();
	}

	public static function saveJson(json:Dynamic) {
		//stringify
		var str = Json.stringify(json, null, "	");

		//save
		saveString(str);
	}

	public static function saveVex(vex:Vex) {
		//serialize
		var json = vex.serialize();

		//save
		saveJson(json);
	}

	/*
		open methods:
		for now open methods use dialogs vs. load methods use local path

		TODO
			- error checking
			- null-able returns
	*/

	public static function openFileAsString() : String {
		var path = Dialogs.open("Open dialog");
		var fileStr = File.getContent(path);
		return fileStr;
	}

	public static function openJson() : Dynamic {
		return Json.parse( openFileAsString() );
	}

	public static function openVex() : Vex {
		return new Vex( openJson() );
	}

	//TODO openPalette?

	//TODO is "import" right verb here?
	public static function importAssetReference() : String {
		var path = Dialogs.open("Import dialog");
		//hacky method - assumes everything lives in assets folder
		//also - always goes to 0,0
		var pathSplit = path.split("/assets/"); 
		var srcString = "assets/" + pathSplit[1];
		return srcString;	
	}

	public static function importVexReference() : Vex {
		var srcString = importAssetReference();
		return new Vex({type:"ref",src:srcString});
	}

	public static function copyVex(vex:Vex) {
		var str = Json.stringify( vex.serialize(), null, "	" );
		Clipboard.set( str );
	}

	//TODO error checking
	public static function pasteVex() : Vex {
		var json = Json.parse( Clipboard.get() );
		return new Vex(json);
	}

	//TODO hasValidVexOnClipBoard?

	//TODO should panCamera and panCameraWhileRightMouseDown be separate?
	public static function panCamera(cam:Camera, x:Float, y:Float) {
		cam.pos.x -= x / cam.zoom;
		cam.pos.y -= y / cam.zoom;
	}

	//returns true if pan is successful
	public static function panCameraWhileRightMouseDown(cam:Camera, e:MouseEvent) : Bool {
		if ( Luxe.input.mousedown(luxe.Input.MouseButton.right) ) {
			panCamera(cam, e.x_rel, e.y_rel);
			return true;
		}
		return false;
	}

	public static function zoomCamera(cam:Camera, e:MouseEvent) {
		cam.zoom += e.y * 0.03 * cam.zoom;
	}

	//TODO create world origin options object to stay in line with Luxe philosophy
	public static function drawWorldOrigin(batcher:Batcher) {
		//draw origin (pretty hacky rn)
		var screenEdgeRightWorldPos = new Vector( Luxe.camera.screen_point_to_world( new Vector(Luxe.screen.w,0)).x, 0 );
		var screenEdgeLeftWorldPos = new Vector( Luxe.camera.screen_point_to_world( new Vector(0,0)).x, 0 );
		var screenEdgeTopWorldPos = new Vector( 0, Luxe.camera.screen_point_to_world(new Vector(0,0)).y );
		var screenEdgeBottomWorldPos = new Vector( 0, Luxe.camera.screen_point_to_world(new Vector(0,Luxe.screen.h)).y );
		Luxe.draw.line({
			p0: new Vector(0,0),
			p1: screenEdgeRightWorldPos,
			color: new Color(1,1,1,0.5),
			batcher: batcher,
			immediate: true
		});
		Luxe.draw.line({
			p0: new Vector(0,0),
			p1: screenEdgeLeftWorldPos,
			color: new Color(1,1,1,0.5),
			batcher: batcher,
			immediate: true
		});
		Luxe.draw.line({
			p0: new Vector(0,0),
			p1: screenEdgeTopWorldPos,
			color: new Color(1,1,1,0.5),
			batcher: batcher,
			immediate: true
		});
		Luxe.draw.line({
			p0: new Vector(0,0),
			p1: screenEdgeBottomWorldPos,
			color: new Color(1,1,1,0.5),
			batcher: batcher,
			immediate: true
		});
	}

	public static function buildPath(path:Array<Vector>, point:Vector, nearDistance:Float, canLeaveOpen:Bool) {
		// First, check to see: is the path finished?
		var isPathFinished = false;
		var isPathClosed = false;
		if (path.length > 0) {
			// You can leave the path open by touching the end point again
			// or close it in a loop by touching the start point
			var isNearStartPoint = Vector.Subtract(point,path[0]).length < nearDistance;
			var isNearEndPoint = Vector.Subtract(point,path[path.length-1]).length < nearDistance;
			if (isNearStartPoint && path.length > 2) {
				isPathFinished = true;
				isPathClosed = true;
			}
			else if (canLeaveOpen && isNearEndPoint && path.length > 1) {
				isPathFinished = true;
			}
		}

		// If the path isn't finished, we need to keep adding points
		if (!isPathFinished) {
			path.push( point );
		}

		return {
			path: path,
			isPathFinished: isPathFinished,
			isPathClosed: isPathClosed
		};
	}

	public static function buildPolyPath(path:Array<Vector>, point:Vector, nearDistance:Float) {
		return buildPath(path, point, nearDistance, false);
	}

	public static function buildLinePath(path:Array<Vector>, point:Vector, nearDistance:Float) {
		return buildPath(path, point, nearDistance, true);
	}

	/*
		Takes in vex properties and a world-space path,
		and sets the position and path of the properties
		in the local space
	*/
	public static function setPathProperties(path:Array<Vector>, isCentered:Bool, ?properties:VexJsonFormat) : VexJsonFormat {
		//find desired pos
		var pos = new Vector(0,0);
		if (isCentered) {
			pos = VexTools.findCenter(path);
		}
		else {
			pos = VexTools.findTopLeft(path);
		}

		//move path points to be relative to pos instead of world origin
		for (p in path) {
			p.subtract(pos);
		}

		if (properties == null) properties = {};
		properties.pos = pos;
		properties.path = path;

		return properties;
	}

	/* TODO !!!! (do this in VexTools)
		createVex(properties, options)
		- make Vex composable in two steps
			- first, create the regular Visual with options
			- second, parse the properties via the VexPropertyInterface
			- either step is optional
			- technically, the Vex object should be optional, you can use a VPI with a regular visual, it just takes more work
				- should probably turn the whole VPI parsing routine into its own method so the objects themselves become optional
			- pair this with the additional work in VexTools for a really robust setup
	*/

	//TODO optional batcher
	public static function drawPath(path:Array<Vector>, color:Color, batcher:Batcher) {
		if (path.length > 1) {
			for (i in 1 ... path.length) {
				Luxe.draw.line({
						p0: new Vector(path[i-1].x, path[i-1].y),
						p1: new Vector(path[i].x, path[i].y),
						color: color,
						immediate: true,
						batcher: batcher
					});
			}
		}
	}

	public static function drawPoints(path:Array<Vector>, ptRadius:Float, batcher:Batcher) {
		for (i in 0 ... path.length) {
			var curPointWorldPos = Luxe.camera.world_point_to_screen(path[i]);
			Luxe.draw.ring({ //draw path points
					x:curPointWorldPos.x, y:curPointWorldPos.y,
					r: ptRadius,
					color: new Color(1,1,1), //TODO color option?
					immediate: true,
					batcher: batcher
				});
		}
	}

	public static function drawEndPoints(path:Array<Vector>, ptRadius:Float, type:String, batcher:Batcher) {
		if (path.length > 0) {

			//start circle
			var pathStartWorldPos = Luxe.camera.world_point_to_screen(path[0]);
			Luxe.draw.ring({
				x: pathStartWorldPos.x,
				y: pathStartWorldPos.y,
				r: ptRadius,
				color: new Color(1,1,1),
				immediate: true,
				batcher: batcher
			});

			if (type == "line" && path.length > 1) {
				//end circle
				var pathEndWorldPos = Luxe.camera.world_point_to_screen(path[path.length-1]);
				Luxe.draw.ring({
					x: pathEndWorldPos.x,
					y: pathEndWorldPos.y,
					r: ptRadius,
					color: new Color(1,1,1),
					immediate: true,
					batcher: batcher
				});
			}

		}
	}

	//TODO don't operate on list?
	public static function drawVexBounds(vexList:Array<Vex>, batcher:Batcher) {
		for (vex in vexList) {
			var boundsColor = new Color(1,1,1);
			if (vex.properties.type == "group") boundsColor = new Color(1,1,0);
			if (vex.properties.type == "ref") boundsColor = new Color(0,1,1);

			var boundsVertices = vex.boundsWorld();
			for (i in 0 ... boundsVertices.length) {
				var v0 = boundsVertices[ i ];
				var v1 = boundsVertices[ cast((i+1)%boundsVertices.length) ];
				Luxe.draw.line({
						p0: v0, p1: v1,
						color: boundsColor,
						batcher: batcher,
						immediate: true
					});
			}

			/* draw position */
			if (vex.properties.pos != null) {
				var p : Vector = vex.properties.pos;
				if (vex.parent != null) p = VexTools.vectorToWorldSpace( vex.parent.transform, p );
				Luxe.draw.ring({
						x: p.x, y: p.y,
						r: 8,
						immediate: true,
						color: boundsColor,
						batcher: batcher //TODO allow separate batcher?
					});
			}
		}
	}

	//TODO function that combine` all path drawing stuff?

	public static function groupVex(children:Array<Vex>) : Vex {
		//make group
		var g = new Vex({
				type: "group",
				pos: "0,0"
			});
		for (c in children) {
			c.parent = g;
		}
		
		//move pos to top left
		var curPos : Vector  = g.properties.pos;
		var bounds = g.boundsWorld();
		var topLeft : Vector = bounds[0];
		var displacement = Vector.Subtract( topLeft, curPos );
		for (v in g.getVexChildren()) {
			var pos : Vector = v.properties.pos;
			v.properties.pos = pos.subtract(displacement);
		}
		g.properties.pos = topLeft;

		return g;
	}

	public static function ungroupVex(group:Vex) : Array<Vex> {
		var children = [];
		for (v in group.getVexChildren()) {
			var newPos = VexTools.vectorToParentSpace( group.transform, v.pos );
			var newScale = v.scale.multiply( group.scale );
			var newRot = v.rotation_z + group.rotation_z;

			v.properties.pos = newPos;
			v.properties.scale = newScale;
			v.properties.rot = newRot;

			v.parent = group.parent;

			children.push(v);
		}
		return children;
	}

	/* Set origin of vex without moving it */
	public static function setOrigin(vex:Vex, origin:Vector) : Vex {
		var newOriginLocalSpace = VexTools.vectorToLocalSpace( vex.transform, origin );

		var prevOriginLocalSpace : Vector = (vex.properties.origin == null) ? new Vector(0,0) : vex.properties.origin;
		var prevOriginWorldSpace = VexTools.vectorToWorldSpace( vex.transform, prevOriginLocalSpace );

		var displacement = Vector.Subtract( origin, prevOriginWorldSpace );

		vex.properties.origin = newOriginLocalSpace;
		vex.properties.pos = Vector.Add( vex.properties.pos, displacement );

		return vex;
	}

	//TODO should "root" be optional? (how?)
	//TODO test if this works inside groups (I don't think it does)
	public static function multiselect(selection:Array<Vex>, point:Vector, root:Vex) : Array<Vex> {
		/* MULTISELECT */
		var v = root.getChildWithPointInside( point );
		if (v != null) {
			var alreadySelected = selection.indexOf(v) != -1;
			if (!alreadySelected) {
				selection.push(v);
			}
			else {
				// TODO remove if already selected?
			}
		}
		return selection;
	}

	//TODO can do without "root", if "root" is replaced with parent
	public static function select(selection:Null<Vex>, point:Vector, root:Vex) : Null<Vex> {
		var newSelection : Vex = null;
		//select inside current selection if possible
		if (selection != null && selection.properties.type != "ref") newSelection = selection.getChildWithPointInside( point );
		//if that fails, select from root
		if (newSelection == null) newSelection = root.getChildWithPointInside( point );

		return newSelection;
	}

	// returns true if the event happened (TODO should it return the vex too?)
	// TODO name keydown vs onkeydown
	public static function keydownOpenSaveVex(vex:Vex, e:KeyEvent) : Bool {
		//open
		if (e.keycode == Key.key_o && e.mod.meta ) {
			//destroy current image
			vex.destroy();
			//load new image
			vex = EditingTools.openVex();

			return true;
		}

		//save
		if (e.keycode == Key.key_s && e.mod.meta ) {
			EditingTools.saveVex(vex);

			return true;
		}

		return false;
	}

	public static function keydownCopyPasteVex(selected:Vex, root:Vex, e:KeyEvent) : Bool {
		//copy
		if (e.keycode == Key.key_c && e.mod.meta) {
			if (selected != null) {
				EditingTools.copyVex( selected );
			}
			else {
				EditingTools.copyVex( root );
			}
			return true;
		}

		//paste
		if (e.keycode == Key.key_v && e.mod.meta) {
			var vex = EditingTools.pasteVex();
			vex.parent = root;	
			return true;
		}

		return false
	}

	public static function keydownDeleteVex(multiselection:Array<Vex>, e:KeyEvent) : Bool {
		if (e.keycode == Key.backspace && e.mod.meta) {
			if (multiselection.length > 0) {
				for (s in multiselection) {
					s.destroy(true);
				}
				multiselection = [];
			}
			return true;
		}
		return false;
	}

	public static function keydownFillColorVex(multiselection:Array<Vex>, color:String, e:KeyEvent) : Bool {
		if (e.keycode == Key.key_f && e.mod.meta) {
			if (multiselection.length > 0) {
				for (s in multiselection) {
					s.properties.color = "pal(" + curPalIndex + ")";
				}
			}
			return true;
		}
		return false;
	}

	// TODO group functions return selection data, which is differnent from everything else... can I make it all match somehow?
	// Maybe everything can return {selection,results}
	public static function keydownGroupVex(multiselection:Array<Vex>, root:Vex, e:KeyEvent) : Array<Vex> {
		//group selected elements
		if (e.keycode == Key.key_g && e.mod.meta) {
			if (multiselection.length > 1) {
				var g = groupVex( multiselection );
				//add group to scene
				g.parent = root;

				return [g];
			}
		}

		return multiselection;

	}

	public static function keydownUngroupVex(group:Vex, e:KeyEvent) : Vex {
		//ungroup selected group
		if (e.keycode == Key.key_u && e.mod.meta) {
			if ( group != null && (group.properties.type == "group" || group.properties.type == "ref") ) {
				ungroupVex( group );
				group.destroy(true);
				return null;
			}
		}
		return group;
	}
	*/

	public static function keydownRotateVex(multiselection:Array<Vex>, e:KeyEvent) : Bool {
		if (e.keycode == Key.right && e.mod.meta) {
			for (sel in multiselection) {
				sel.properties.rot = (sel.rotation_z + 5);
			}
			return true;
		}
		if (e.keycode == Key.left && e.mod.meta) {
			for (sel in multiselection) {
				sel.properties.rot = (sel.rotation_z - 5);
			}
			return true;
		}
		return false;
	}

	public static function keydownScaleVex(multiselection:Array<Vex>, e:KeyEvent) : Bool {
		if (e.keycode == Key.up && e.mod.meta) {
			for (sel in multiselection) {
				sel.properties.scale = sel.scale.add( new Vector(0.1,0.1) );
			}
			return true;
		}
		if (e.keycode == Key.down && e.mod.meta) {
			for (sel in multiselection) {
				sel.properties.scale = sel.scale.subtract( new Vector(0.1,0.1) );
			}
			return true;
		}
		return false;
	}

	public static function keydownChangeDepthVex(multiselection:Array<Vex>, e:KeyEvent) : Bool {
		if (e.keycode == Key.up && e.mod.lshift) {
			for (sel in multiSelection) {
				sel.properties.depth = sel.depth + 1;
			}
			return true;
		}
		else if (e.keycode == Key.down && e.mod.lshift) {
			for (sel in multiSelection) {
				sel.properties.depth = sel.depth - 1;
			}
			return true;
		}
		return false;
	}

	//TODO this combo return type is a test for other methods above
	public static function mousedownSetOriginVex(multiselection:Array<Vex>, e:MouseEvent) {
		//TODO
	}
		
}