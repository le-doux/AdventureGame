package vexlib;

import sys.io.File;
import haxe.Json;
import dialogs.Dialogs; //TODO this import doesn't seem to work in the lib?
import clipboard.Clipboard;

import luxe.Camera;
import luxe.Input;
import phoenix.Batcher;

/*
	Home for static methods used for editing vex drawings, animations, levels, etc.
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

	//TODO drawing methods

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

}