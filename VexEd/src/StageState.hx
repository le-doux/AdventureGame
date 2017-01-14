import luxe.States;
import luxe.Input;
import luxe.Vector;

import vexlib.Editor;
import vexlib.EditingTools;
import vexlib.Vex;
import vexlib.Stage;

import sys.io.File;
import haxe.Json;
import dialogs.Dialogs;

/*
TODO
X save/load
X stage path
- dialog
- exits

MAYBE
- some edit mode features?
- some draw mode features?
*/
class StageState extends State {

	/* DATA */
	public var stage : Stage = new Stage();

	/* STAGE EDITING */
	var stageStart = new Vector(0,0);
	var stageEnd = new Vector(600,100);
	var selectedStageHandle : Vector = null;

	/* GUI */
	var drawIdealScreenSpace = true; //todo zoom independent mode?

	override function update(dt:Float) {
		//draw level line
		Luxe.draw.line({
				p0: stageStart,
				p1: stageEnd,
				batcher: Editor.batcher.uiWorld,
				immediate: true
			});

		//draw level line handles
		var startScreenPos = Luxe.camera.world_point_to_screen( stageStart );
		var endScreenPos = Luxe.camera.world_point_to_screen( stageEnd );
		Luxe.draw.ring({
				x:startScreenPos.x, y:startScreenPos.y,
				r:10,
				batcher: Editor.batcher.uiScreen,
				immediate:true
			});
		Luxe.draw.ring({
				x:endScreenPos.x, y:endScreenPos.y,
				r:10,
				batcher: Editor.batcher.uiScreen,
				immediate:true
			});

		// draw ideal screen space
		if (drawIdealScreenSpace) {
			Luxe.draw.rectangle({
					x:Luxe.screen.mid.x-400,
					y:Luxe.screen.mid.y-225,
					w:800,
					h:450,
					batcher:Editor.batcher.uiScreen,
					immediate:true
				});
		}
	}

	override function onmousedown( e:MouseEvent ) {
		/* grab level handles */
		if ( e.button == luxe.Input.MouseButton.left ) {
			var startScreenPos = Luxe.camera.world_point_to_screen( stageStart );
			var endScreenPos = Luxe.camera.world_point_to_screen( stageEnd );
			if ( Vector.Subtract( startScreenPos, e.pos ).length < 10 ) {
				selectedStageHandle = stageStart;
				//return;
			}
			else if ( Vector.Subtract( endScreenPos, e.pos ).length < 10 ) {
				selectedStageHandle = stageEnd;
				//return;
			}
			else {
				selectedStageHandle = null;
			}
		}
	}

	override function onmousemove( e:MouseEvent ) {
		/* move level handles */
		if (selectedStageHandle != null) {
			var shiftDown = ( Luxe.input.keydown( Key.lshift) || Luxe.input.keydown( Key.rshift) );
			selectedStageHandle.x += e.x_rel / Luxe.camera.zoom;
			if (!shiftDown) //hold shift to only move in x coords
				selectedStageHandle.y += e.y_rel / Luxe.camera.zoom;
		}
	}

	override function onmouseup( e:MouseEvent ) {
		if (selectedStageHandle != null) {
			//stage.path = [stageStart,stageEnd]; //update stage object
			selectedStageHandle = null;
		}
	}

	override function onkeydown( e:KeyEvent ) {
		/* SAVE STAGE */
		if (e.keycode == Key.key_s && e.mod.meta) {
			// update stage
			stage.path = [stageStart,stageEnd];
			stage.scenery = Editor.scene.root;

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

		/* LOAD STAGE */
		if (e.keycode == Key.key_o && e.mod.meta) {
			// load file
			var path = Dialogs.open("Open dialog");
			var fileStr = File.getContent(path);
			var json = Json.parse(fileStr);

			// load stage
			stage = new Stage(json); //todo do I need to clean up after the old stage?

			// update path values
			//hack assumes the stage path always only has two elements (true for now)
			var path : Array<Vector> = stage.path;
			stageStart = path[0];
			stageEnd = path[1];

			// load scenery
			Editor.scene.root.destroy();
			Editor.scene.root = stage.scenery;
			Editor.selection = null;
		}
	}

}