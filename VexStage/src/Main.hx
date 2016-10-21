
import luxe.Input;
import luxe.Vector;
import luxe.resource.Resource.JSONResource;
import phoenix.Batcher;
import luxe.Camera;
import luxe.Color;

import vexlib.Vex;
import vexlib.VexPropertyInterface;
import vexlib.Palette;

import dialogs.Dialogs;

/* 
TODO vex level editor v0
	X path
	X "stamp" vex objects
	X select dialog objects
	X description component (registers self w/ scene)
	- stage object
		- put in shared lib
	- save / load stage
	? set entrances / exits / other "interest points"
	- replace placingVex bool with separate insertingVex vex
	- bouncy arrows
	- arrows whose size are zoom independent


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
	public var stage : Stage = new Stage();

	/* STAGE DATA */
	var stageStart = new Vector(0,0);
	var stageEnd = new Vector(600,100);
	var scenery : Vex;

	/* BATCHERS */
	var uiScreenBatcher : Batcher; // UI displayed at screen coords
	var uiSceneBatcher : Batcher; // UI displayed in scene coords


	var isPanning = false;
	var selectedStageHandle : Vector = null;
	var selectedVex : Vex = null;
	var placingVex = false;


	override function ready() {
		Instance = this;

		scenery = new Vex({
				type: "group",
				origin: "0,0",
				pos: "0,0"
			});

		Luxe.camera.pos.subtract( Luxe.screen.mid );

		var uiCam = new Camera({name:"uiCam"});
		uiScreenBatcher = Luxe.renderer.create_batcher({name:"uiScreenBatcher", layer:10, camera:uiCam.view});
		uiSceneBatcher = Luxe.renderer.create_batcher({name:"uiSceneBatcher", layer:5, camera:Luxe.camera.view});

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
				selectedVex.add(new Description({name:"description",text:"Default text description"}));
			}
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
			selectedVex.parent = scenery;
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
		selectedVex = scenery.getChildWithPointInside(cursorWorldPos);

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
			//trace(vex);
			var bounds = vex.boundsWorld();
			//trace(bounds);
			var topY = bounds[0].y;
			var midX = bounds[0].x + ((bounds[1].x - bounds[0].x)/2);

			Luxe.draw.line({
					p0: new Vector(midX, topY-60),
					p1: new Vector(midX-30, topY-60-30),
					immediate: true
				});
			Luxe.draw.line({
					p0: new Vector(midX, topY-60),
					p1: new Vector(midX+30, topY-60-30),
					immediate: true
				});
		}
	}
}


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

	public function new() {

	}

	public function registerDescription( d : Description ) {
		//TODO make this a real and better thing
		//TODO actually can't the description handle all this logic? maybe not?
		trace("description registered!");
	}

}
