import luxe.States;
import luxe.Input;

import vexlib.Editor;
import vexlib.EditingTools;
import vexlib.Vex;

class EditState extends State {

	var groupCount = 0;

	override function update(dt:Float) {
		EditingTools.drawVexBounds( Editor.multiselection, Editor.batcher.uiWorld );
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

		//z order
		EditingTools.keydownChangeDepthVex( Editor.multiselection, e );

		//delete selected element
		Editor.multiselection = EditingTools.keydownDeleteVex( Editor.multiselection, e ).selection;
		trace(Editor.multiselection);

		//change color
		EditingTools.keydownFillColorVex( Editor.multiselection, "pal(" + Editor.curPalIndex + ")", e );

		//group selected elements
		var groupResults = EditingTools.keydownGroupVex( Editor.multiselection, Editor.scene.root, e, "group" + groupCount );
		if (groupResults.success) { //todo make uneccessary by adding anonymouse animation
			groupCount++;
			Editor.multiselection = groupResults.selection;
		}

		//ungroup selected group
		Editor.multiselection = EditingTools.keydownUngroupVex( Editor.multiselection, e ).selection;

		//rotate selected elements //TODO make command //TODO make rotate handle?
		EditingTools.keydownRotateVex( Editor.multiselection, e );

		//scale selected elements //TODO make command //TODO separate x- and y- axes
		EditingTools.keydownScaleVex( Editor.multiselection, e );
	}

	override function onmousedown(e:MouseEvent) {
		if (Luxe.input.mousedown(luxe.MouseButton.right)) {
			//panning
			return;
		}

		var p = Luxe.camera.screen_point_to_world(e.pos);

		/* SET ORIGIN */
		if ( EditingTools.mousedownSetOriginVex( Editor.multiselection, e ).success ) {
			return;
		}

		/* CHANGE SELECTION */
		Editor.multiselection = EditingTools.mousedownChangeSelection( Editor.multiselection, Editor.scene.root, e ).selection;
	}

	override function onmousemove(e:MouseEvent) {
		if (Luxe.input.mousedown(luxe.MouseButton.right)) {
			//panning
			return;
		}

		/* TRANSLATE SELECTION */
		EditingTools.mousemoveTranslateVex( Editor.multiselection, e );
	}

}