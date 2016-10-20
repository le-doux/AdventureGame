
import luxe.Input;
import luxe.Vector;
import luxe.resource.Resource.JSONResource;
import phoenix.Batcher;
import luxe.Camera;

import vexlib.Vex;
import vexlib.VexPropertyInterface;
import vexlib.Palette;

import dialogs.Dialogs;

/* 
TODO vex level editor v0
	- path
	- "stamp" vex objects
	- select dialog objects
	- set entrances / exits / other "interest points"
	- description component (registers self w/ scene)


Types of interactive "interest points"
	- static: attached to location in level (where is this stored?)
	- description: attached to vex
	- dialog: attached to character / vex (is character another abstraction?)

Q
- should description be a component on an object?
- or something stored in the stage? using an id to attach?
	- if attached to object, a change in description might require a whole new scenery file
	- if attached to stage, the stage can be swapped out w/ the same scenery underneath
	- or there could be description files that contain conditions for different descriptions
*/

class Main extends luxe.Game {

	/* STAGE DATA */
	var stageStart = new Vector(0,0);
	var stageEnd = new Vector(600,100);
	var scenery : Vex;

	/* BATCHERS */
	var uiScreenBatcher : Batcher; // UI displayed at screen coords
	//var uiSceneBatcher : Batcher; // UI displayed in scene coords


	var isPanning = false;
	var selectedStageHandle : Vector = null;
	var selectedVex : Vex = null;


	override function ready() {
		Luxe.camera.pos.subtract( Luxe.screen.mid );

		var uiCam = new Camera({name:"uiCam"});
		uiScreenBatcher = Luxe.renderer.create_batcher({name:"uiScreenBatcher", layer:10, camera:uiCam.view});

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
		if (e.keycode == Key.key_i && e.mod.meta) {
			var path = Dialogs.open("Import dialog");
			//hacky method - assumes everything lives in assets folder
			//also - always goes to 0,0
			var pathSplit = path.split("/assets/"); 
			var srcString = "assets/" + pathSplit[1];
			var cursorWorldPos = Luxe.camera.screen_point_to_world( Luxe.screen.cursor.pos );
			selectedVex = new Vex({ type:"ref", pos:cursorWorldPos, src:srcString},
								function(v) {
										trace(v.boundsWorld());
									} 
								);
			
		}
	}

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function update(dt:Float) {

		//draw level line
		Luxe.draw.line({
				p0: stageStart,
				p1: stageEnd,
				immediate: true
			});
		//draw level line handles
		var startScreenPos = Luxe.camera.world_point_to_screen( stageStart );
		var endScreenPos = Luxe.camera.world_point_to_screen( stageEnd );
		Luxe.draw.ring({
				x:startScreenPos.x, y:startScreenPos.y,
				r:10,
				batcher:uiScreenBatcher,
				immediate:true
			});
		Luxe.draw.ring({
				x:endScreenPos.x, y:endScreenPos.y,
				r:10,
				batcher:uiScreenBatcher,
				immediate:true
			});

		//move selected vex w/ cursor
		if (selectedVex != null) {
			var cursorWorldPos = Luxe.camera.screen_point_to_world( Luxe.screen.cursor.pos );
			selectedVex.pos = cursorWorldPos;
		}
	} //update

	override function onmousedown( e:MouseEvent ) {
		/* pannning */
		if (e.button == luxe.Input.MouseButton.right) {
			isPanning = true;
			return;
		}

		if (selectedVex != null) {
			var cursorWorldPos = Luxe.camera.screen_point_to_world( Luxe.screen.cursor.pos );
			selectedVex.properties.pos = cursorWorldPos;
			selectedVex = null;
			return;
		}

		var startScreenPos = Luxe.camera.world_point_to_screen( stageStart );
		var endScreenPos = Luxe.camera.world_point_to_screen( stageEnd );
		if ( Vector.Subtract( startScreenPos, e.pos ).length < 10 ) {
			selectedStageHandle = stageStart;
		}
		else if ( Vector.Subtract( endScreenPos, e.pos ).length < 10 ) {
			selectedStageHandle = stageEnd;
		}
		else {
			selectedStageHandle = null;
		}
		

	}

	override function onmousemove( e:MouseEvent ) {
		/* panning */
		if (isPanning) {
			Luxe.camera.pos.x -= e.xrel / Luxe.camera.zoom;
			Luxe.camera.pos.y -= e.yrel / Luxe.camera.zoom;
			return;
		}

		if (selectedStageHandle != null) {
			var shiftDown = ( Luxe.input.keydown( Key.lshift) || Luxe.input.keydown( Key.rshift) );
			selectedStageHandle.x += e.xrel / Luxe.camera.zoom;
			if (!shiftDown) //hold shift to only move in x coords
				selectedStageHandle.y += e.yrel / Luxe.camera.zoom;
		}

	}

	override function onmouseup( e:MouseEvent ) {
		/* panning */
		if (isPanning) {
			isPanning = false;
			return;
		}

		if (selectedStageHandle != null) {
			selectedStageHandle = null;
		}
	}

	override function onmousewheel(e:MouseEvent) {
		/* ZOOMING */
		Luxe.camera.zoom += e.yrel * 0.03 * Luxe.camera.zoom;
	}

} //Main

/* STAGE */
typedef ExitFormat = {
	public var pos : Property;
	public var destination : Property;
}

typedef StageFormat = {
	@:optional public var type : Property;
	@:optional public var id : Property;
	@:optional public var path : Property;
	@:optional public var exits : Array<ExitFormat>;
	@:optional public var background : Property;
	@:optional public var scenery : VexJsonFormat;
	//todo sceneryRef (rename?)
}

class Stage {

}
