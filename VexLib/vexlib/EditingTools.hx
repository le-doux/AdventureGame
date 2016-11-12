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

	//TODO put this in VexEdit
	public static function buildPath(path:Array<Vector>, point:Vector, nearDistance:Float, canLeaveOpen:Bool) {
		// First, check to see: is the path closed?
		var isPathClosed = false;
		if (path.length > 0) {
			// You can leave the path open by touching the end point again
			// or close it in a loop by touching the start point
			var isNearStartPoint = Vector.Subtract(point,path[0]).length < nearDistance;
			var isNearEndPoint = Vector.Subtract(point,path[path.length-1]).length < nearDistance;
			if (isNearStartPoint && path.length > 2) {
				path.push(path[0].clone()); // To make a path loop, you need to add the start point to the end
				isPathClosed = true;
			}
			else if (canLeaveOpen && isNearEndPoint && path.length > 1) {
				isPathClosed = true;
			}
		}

		// If the path isn't closed, we need to keep adding points
		if (!isPathClosed) {
			path.push( point );
		}

		return {
			path: path,
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

	/* TODO !!!!
		createVex(properties, options)
		- make Vex composable in two steps
			- first, create the regular Visual with options
			- second, parse the properties via the VexPropertyInterface
			- either step is optional
			- technically, the Vex object should be optional, you can use a VPI with a regular visual, it just takes more work
				- should probably turn the whole VPI parsing routine into its own method so the objects themselves become optional
			- pair this with the additional work in VexTools for a really robust setup
	*/

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

	//
}