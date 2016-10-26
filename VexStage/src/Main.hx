
import luxe.Input;
import luxe.Vector;
import luxe.resource.Resource.JSONResource;
import phoenix.Batcher;
import luxe.Camera;
import luxe.Color;

import vexlib.Vex;
import vexlib.VexPropertyInterface;
import vexlib.Palette;
import vexlib.Stage;

import sys.io.File;
import haxe.Json;
import dialogs.Dialogs;

/* 
TODO vex level editor v0
	X load stage in VexPlay
	X path
	X "stamp" vex objects
	X select dialog objects
	X description component (registers self w/ scene)
	X stage object
		X put in shared lib
	X save / load stage
	? set entrances / exits / other "interest points"
	- replace placingVex bool with separate insertingVex vex
	- bouncy arrows
	X arrows whose size are zoom independent
	X show ideal screen size
		- snap to "floor"


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

	public static var Instance : Main;
	public var stage : Stage;

	/* STAGE DATA */
	var stageStart = new Vector(0,0);
	var stageEnd = new Vector(600,100);

	/* BATCHERS */
	var uiScreenBatcher : Batcher; // UI displayed at screen coords
	var uiSceneBatcher : Batcher; // UI displayed in scene coords


	var isPanning = false;
	var selectedStageHandle : Vector = null;
	var selectedVex : Vex = null;
	var placingVex = false;


	var drawIdealScreenSpace = true;


	override function ready() {
		Instance = this;

		stage = new Stage();
		stage.path = [stageStart,stageEnd];

		Luxe.camera.pos.subtract( Luxe.screen.mid );

		var uiCam = new Camera({name:"uiCam"});
		uiScreenBatcher = Luxe.renderer.create_batcher({name:"uiScreenBatcher", layer:10, camera:uiCam.view});
		uiSceneBatcher = Luxe.renderer.create_batcher({name:"uiSceneBatcher", layer:5, camera:Luxe.camera.view});
		Description.uiBatcher = uiScreenBatcher;

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
		/* IMPORT */
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
			placingVex = true;
		}

		/* ADD DESCRIPTION */
		if (e.keycode == Key.key_d && e.mod.meta) {
			if (selectedVex != null) {
				//selectedVex.add(new Description({name:"description",text:"Default text description"}));
				selectedVex.properties.AddComponent({type:"Description",name:"description",text:"Default text description"});
			}
		}

		/* SAVE */
		if (e.keycode == Key.key_s && e.mod.meta) {
			//get path & open file
			var path = Dialogs.save("Save dialog");
			var output = File.write(path);

			//get data & write it
			var saveJson = stage.serialize();
			var saveStr = Json.stringify(saveJson, null, "	");
			output.writeString(saveStr);

			//close file
			output.close();
		}

		/* OPEN */
		if (e.keycode == Key.key_o && e.mod.meta) {
			//load file
			var path = Dialogs.open("Open dialog");
			var fileStr = File.getContent(path);
			var json = Json.parse(fileStr);

			stage = new Stage(json); //todo do I need to clean up after the old stage?

			//hack assumes the stage path always only has two elements (true for now)
			var path : Array<Vector> = stage.path;
			stageStart = path[0];
			stageEnd = path[1];
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
		if (selectedVex != null && placingVex) {
			var cursorWorldPos = Luxe.camera.screen_point_to_world( Luxe.screen.cursor.pos );
			selectedVex.pos = cursorWorldPos;
		}

		//draw border of selected vex
		if (selectedVex != null && !placingVex) {
			renderSelectionBounds();
		}

		//todo draw ideal screen space
		if (drawIdealScreenSpace) {
			var screenMidWorldPos = Luxe.camera.screen_point_to_world( Luxe.screen.mid );
			Luxe.draw.rectangle({
					x:screenMidWorldPos.x-400,
					y:screenMidWorldPos.y-225,
					w:800,
					h:450,
					immediate:true
				});
		}
	} //update

	override function onmousedown( e:MouseEvent ) {
		/* pannning */
		if (e.button == luxe.Input.MouseButton.right) {
			isPanning = true;
			return;
		}

		/* place new vex */
		if (selectedVex != null && placingVex) {
			var cursorWorldPos = Luxe.camera.screen_point_to_world( Luxe.screen.cursor.pos );
			selectedVex.properties.pos = cursorWorldPos;
			selectedVex.parent = stage.scenery;
			selectedVex = null;
			placingVex = false;
			return;
		}

		/* grab level handles */
		var startScreenPos = Luxe.camera.world_point_to_screen( stageStart );
		var endScreenPos = Luxe.camera.world_point_to_screen( stageEnd );
		if ( Vector.Subtract( startScreenPos, e.pos ).length < 10 ) {
			selectedStageHandle = stageStart;
			return;
		}
		else if ( Vector.Subtract( endScreenPos, e.pos ).length < 10 ) {
			selectedStageHandle = stageEnd;
			return;
		}
		else {
			selectedStageHandle = null;
		}

		/* select vex */
		var cursorWorldPos = Luxe.camera.screen_point_to_world( Luxe.screen.cursor.pos );
		selectedVex = stage.scenery.getChildWithPointInside(cursorWorldPos);

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
			stage.path = [stageStart,stageEnd]; //update stage object
			selectedStageHandle = null;
		}
	}

	override function onmousewheel(e:MouseEvent) {
		/* ZOOMING */
		Luxe.camera.zoom += e.yrel * 0.03 * Luxe.camera.zoom;
	}

	function renderSelectionBounds() {
		var multiSelection = [];
		if (selectedVex != null) multiSelection.push(selectedVex);
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

			/*
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
			*/
		}
	}

} //Main

typedef DescriptionOptions = {
	> luxe.options.ComponentOptions,
	@:optional public var text : String; 
}

class Description extends luxe.Component {
	public var text : String;
	public var vex : Vex;
	public var isEditorMode = true; //obviously not true in the future
	public static var uiBatcher : Batcher; //hacky

	override public function new(?options:DescriptionOptions) {
		super(options);
		if (options.text != null) text = options.text;
		Main.Instance.stage.registerDescription(this); //TODO this is probably a terrible way to to do this
	}

	override public function init() {
		vex = cast(this.entity);
	}

	override public function update(dt:Float) {
		if (isEditorMode) {
			//draw pull tab
			var bounds = vex.boundsWorld();
			var topY = bounds[0].y;
			var midX = bounds[0].x + ((bounds[1].x - bounds[0].x)/2);

			var anchorPoint = new Vector(midX,topY);
			anchorPoint = Luxe.camera.world_point_to_screen( anchorPoint );
			anchorPoint.y -= 30;

			Luxe.draw.line({
					p0: anchorPoint,
					p1: anchorPoint.clone().add(new Vector(-30,-30)),
					immediate: true,
					batcher: uiBatcher
				});
			Luxe.draw.line({
					p0: anchorPoint,
					p1: anchorPoint.clone().add(new Vector(30,-30)),
					immediate: true,
					batcher: uiBatcher
				});
		}
	}
}
