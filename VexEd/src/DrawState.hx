import luxe.States;
import luxe.Vector;
import luxe.Input;

import vexlib.Editor;
import vexlib.EditingTools;
import vexlib.Vex;
import vexlib.Palette;

class DrawState extends State {

	var drawingPath : Array<Vector> = [];
	var distToClosePath = 16;
	var count = 0;
	var currentTool = "poly";

	override function update(dt:Float) {
		//tool
		Luxe.draw.text({
				text: "tool: " + currentTool,
				point_size: 16,
				batcher: Editor.batcher.uiScreen,
				pos: new Vector(0,40),
				immediate: true
			});

		//draw cursor
		Luxe.draw.circle({
				x: Luxe.screen.cursor.pos.x,
				y: Luxe.screen.cursor.pos.y,
				r: distToClosePath/2,
				color: Palette.Colors[Editor.curPalIndex],
				batcher: Editor.batcher.uiScreen,
				immediate: true
			});

		renderDrawingPath();
	}

	function renderDrawingPath() {
		if (drawingPath.length > 0) {
			EditingTools.drawPath( drawingPath, Palette.Colors[Editor.curPalIndex], Editor.batcher.uiWorld );
			EditingTools.drawPoints( drawingPath, 5, Editor.batcher.uiScreen );
			EditingTools.drawEndPoints( drawingPath, distToClosePath, currentTool, Editor.batcher.uiScreen );
		}
	}

	override function onkeydown(e:KeyEvent) {
		// open/save
		var open = EditingTools.keydownOpenVex( Editor.scene.root, e );
		if (open.success) {
			Editor.scene.root = open.root;
			Editor.selection = null;
		}
		EditingTools.keydownSaveVex( Editor.scene.root, e );

		// new clears the current drawing
		// TODO move into VexTools
		if (e.keycode == Key.key_n && e.mod.meta) {
			Editor.scene.root.destroy();
			Editor.scene.root = Vex.Create({
				type: "group",
				origin: "0,0",
				pos: "0,0"
			});
		}

		//delete selected element
		Editor.multiselection = EditingTools.keydownDeleteVex( Editor.multiselection, e ).selection;

		//change color
		EditingTools.keydownFillColorVex( Editor.multiselection, "pal(" + Editor.curPalIndex + ")", e );

		//change tool
		if (e.keycode == Key.key_t && e.mod.meta) {
			if (currentTool == "poly") {
				currentTool = "line";
			}
			else {
				currentTool = "poly";
			}
		}
	}

	override function onmousedown(e:MouseEvent) {
		if (Luxe.input.mousedown(luxe.MouseButton.right)) {
			//panning
			return;
		}

		//TODO package this up one thing?
		var p = Luxe.camera.screen_point_to_world(e.pos);
		var pathResults = EditingTools.buildPath( drawingPath, p, 
													(distToClosePath / Luxe.camera.zoom) /*nearDistance*/, 
													(currentTool == "line") /*canLeaveOpen*/ );
		drawingPath = pathResults.path;

		if (pathResults.isPathFinished) {
			if (currentTool == "line" && pathResults.isPathClosed)
				drawingPath.push( drawingPath[0].clone() ); //add final point for looped line

			//create and select vex
			var vex = Vex.Create( EditingTools.setPathProperties( drawingPath, true /*isCentered*/, 
								{
									type: currentTool,
									id: "poly" + count,
									color: "pal(" + Editor.curPalIndex + ")",
									depth: count
								} ) );
			vex.parent = Editor.scene.root;
			Editor.selection = vex;

			//clear drawing path
			drawingPath = [];
			count++;
		}
	}

	override function onleave<T>(t:T) {
		drawingPath = [];
	}

}