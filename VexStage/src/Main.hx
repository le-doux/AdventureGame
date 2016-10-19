
import luxe.Input;
import luxe.Vector;
import luxe.resource.Resource.JSONResource;

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

	var stageStart = new Vector(0,0);
	var stageEnd = new Vector(600,100);

	var scenery : Vex;

	override function ready() {
		Luxe.camera.pos.subtract( Luxe.screen.mid );

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
			var v = new Vex({ type:"ref", pos:"0,0", origin:"0,0", src:srcString},
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
		Luxe.draw.line({
				p0: stageStart,
				p1: stageEnd,
				immediate: true
			});
	} //update

	override function onmousedown( e:MouseEvent ) {}

	override function onmousemove( e:MouseEvent ) {}

	override function onmouseup( e:MouseEvent ) {}


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
