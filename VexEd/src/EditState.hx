import luxe.States;
import luxe.Input;

import vexlib.Editor;
import vexlib.EditingTools;

class EditState extends State {

	override function update(dt:Float) {
		EditingTools.drawVexBounds( Editor.multiselection, Editor.batcher.uiWorld );
	}

	override function onkeydown(e:KeyEvent) {
		//z order
		EditingTools.keydownChangeDepthVex( Editor.multiselection, e );

		//delete selected element
		Editor.multiselection = EditingTools.keydownDeleteVex( Editor.multiselection, e ).selection;

		//change color
		EditingTools.keydownFillColorVex( Editor.multiselection, "pal(" + Editor.curPalIndex + ")", e );

		//group selected elements
		Editor.multiselection = EditingTools.keydownGroupVex( Editor.multiselection, Editor.scene.root, e );

		//ungroup selected group
		Editor.selection = EditingTools.keydownUngroupVex( Editor.selection, e );

		//rotate selected elements //TODO make command //TODO make rotate handle?
		EditingTools.keydownRotateVex( Editor.multiselection, e );

		//scale selected elements //TODO make command //TODO separate x- and y- axes
		EditingTools.keydownScaleVex( Editor.multiselection, e );
	}

	override function onmousedown(e:MouseEvent) {
		var p = Luxe.camera.screen_point_to_world(e.pos);

		/* SET ORIGIN */
		if ( EditingTools.mousedownSetOriginVex( Editor.multiselection, e ).success ) {
			return;
		}

		/* CHANGE SELECTION */
		Editor.multiselection = EditingTools.mousedownChangeSelection( Editor.multiselection, Editor.scene.root, e ).selection;
	}

	override function onmousemove(e:MouseEvent) {
		/* TRANSLATE SELECTION */
		EditingTools.mousemoveTranslateVex( Editor.multiselection, e );
	}

}