
import luxe.Input;
import luxe.Visual;
import luxe.Vector;
import luxe.Color;

import vexlib.Vex;
import vexlib.Vex.Palette;

import sys.io.File;
import haxe.Json;
import dialogs.Dialogs;
import luxe.resource.Resource.JSONResource;

/*
	TODO convert to new vex format

	TODO:
	- selection
	- grouping
	- update animation file format for easier authoring
	- update animation so it doesn't rely on tweening lib
	- add UI layer for graphics
	- copy paste with JSON
	- vector viewer app
	- support multiple palettes in system, by name
*/

class Main extends luxe.Game {

	var drawingPath : Array<Vector> = [];
	var distToClosePath = 16;

	var root : Vex;
	var selected (get, set) : Vex;
	var multiSelection : Array<Vex> = [];

	var count = 0;

	/* STATE FLAGS */
	var isEditingId = false;
	var isDrawingMode = true;

	var curPalIndex = 0;

	override function ready() {
		Luxe.camera.pos.subtract(Luxe.screen.mid); //put 0,0 in the center of the camera

		//init drawing
		root = new Vex({
				type: "group",
				origin: "0,0",
				pos: "0,0"
			});

		//draw origin
		Luxe.draw.line({
				p0: new Vector(-Luxe.screen.width/2, 0),
				p1: new Vector(Luxe.screen.width/2, 0)
			});
		Luxe.draw.line({
				p0: new Vector(0, -Luxe.screen.height/2),
				p1: new Vector(0, Luxe.screen.height/2)
			});

		//load default palette - hacky nonsense
		var load = Luxe.resources.load_json('assets/default.pal');
		load.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			Palette.Load(json);
		});
	} //ready

	function get_selected() : Vex {
		if (multiSelection.length > 0) return multiSelection[0];
		return null;
	}

	function set_selected(v:Vex) : Vex {
		multiSelection = (v != null) ? [v] : [];
		return v;
	}

	override function ontextinput(e:TextEvent) {
		//edit id
		if (isEditingId) {
			//WILL THIS WORK?
			selected.properties.id += e.text; //TODO command-ify
		}

		//change current color
		var n = Std.parseInt(e.text);
		if (n != null && n > 0 && n < 9) {
			curPalIndex = n - 1;
		} 
	}

	override function onkeydown( e:KeyEvent ) {

		/*
		//test animation
		if (e.keycode == Key.key_a) {
			root.animate({
					animations : [{
						target : ".world",
						rot : [
							{t : 0.60, d : [0]},
							{t : 1.00, d : [90]}
						]
					}]
				}, 1.2);
		}
		*/

		//enter edit mode
		if (e.keycode == Key.key_e && e.mod.meta) {
			isDrawingMode = false;
			drawingPath = [];
		}

		//enter drawing mode
		if (e.keycode == Key.key_d && e.mod.meta) {
			isDrawingMode = true;
		}

		//delete selected element
		if (e.keycode == Key.backspace) {
			if (multiSelection.length > 0) {
				new DeleteCommand(multiSelection);
				multiSelection = [];
			}
		}

		//edit id
		if (e.keycode == Key.key_i && e.mod.meta) {
			if (selected != null) {
				isEditingId = !isEditingId;
				if (isEditingId) selected.properties.id = "";
			}
		}

		//change color
		if (e.keycode == Key.key_f && e.mod.meta) {
			if (selected != null) {
				new ColorCommand(multiSelection, "pal(" + curPalIndex + ")");
			}
		}

		//open
		if (e.keycode == Key.key_o && e.mod.meta ) {

			//load file
			var path = Dialogs.open("Open dialog");
			var fileStr = File.getContent(path);
			var json = Json.parse(fileStr);

			//destroy current image
			root.destroy();

			//load new image
			root = new Vex(json);

		}

		//save
		if (e.keycode == Key.key_s && e.mod.meta ) {
			//get path & open file
			var path = Dialogs.save("Save dialog");
			var output = File.write(path);

			//get data & write it
			var saveJson = root.serialize();
			var saveStr = Json.stringify(saveJson, null, "	");
			output.writeString(saveStr);

			//close file
			output.close();
		}

		//undo redo
		if (e.keycode == Key.key_z && e.mod.meta) Command.Undo();
		if (e.keycode == Key.key_y && e.mod.meta) Command.Redo();

	}

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function onmousedown( e:MouseEvent ) {

		var p = Luxe.camera.screen_point_to_world(e.pos);

		/* DRAWING MODE */
		if (isDrawingMode) {
			//is the path closed?
			var isPathClosed = false;
			if (drawingPath.length > 2) {
				if ( Vector.Subtract(p,drawingPath[0]).length < distToClosePath ) {
					isPathClosed = true;
				}
			}

			if (isPathClosed) {
				var cmd = new DrawVexCommand(root, //should parent be a possible attribute?
					{
						type: "poly",
						path: drawingPath,
						id: "poly" + count,
						color: "pal(" + curPalIndex + ")"
					});
				selected = cmd.vex;

				//clear drawing path
				drawingPath = [];

				count++;
			}
			else {
				//add new point
				drawingPath.push(p);
			}
		}
		/* EDIT MODE */
		else {
			if (Luxe.input.keydown(Key.lshift)) {
				var v = root.getChildWithPointInside(p);
				if (v != null) {
					var alreadySelected = multiSelection.indexOf(v) != -1;
					if (!alreadySelected) {
						multiSelection.push(v);
					}
					else {
						// TODO remove if already selected?
					}
				}
			}
			else {
				selected = root.getChildWithPointInside(p);
			}
		}

	}

	override function onmousewheel(e:MouseEvent) {
		//zoom on scroll
		Luxe.camera.zoom += e.yrel * 0.1;
	}

	override function update(dt:Float) {
		//draw cursor
		var cursorPos = Luxe.camera.screen_point_to_world( Luxe.screen.cursor.pos );
		Luxe.draw.circle({
				x: cursorPos.x,
				y: cursorPos.y,
				r: distToClosePath/2,
				color: Palette.Colors[curPalIndex],
				immediate: true
			});

		renderDrawingPath();

		if (selected != null) {
			Luxe.draw.text({
					text: "id: " + selected.properties.id,
					point_size: 16,
					pos: Vector.Multiply( Luxe.screen.mid, -1),
					immediate: true
				});
		}

		if (!isDrawingMode) {
			for (s in multiSelection) {
				var selectedBounds = s.bounds();
				Luxe.draw.rectangle({
						x: selectedBounds.x, y: selectedBounds.y,
						w: selectedBounds.w, h: selectedBounds.h,
						color: new Color(1,1,1),
						immediate: true
					});
			}
		}
	} //update

	function renderDrawingPath() {
		if (drawingPath.length > 0) {

			//start circle
			Luxe.draw.ring({
				x: drawingPath[0].x,
				y: drawingPath[0].y,
				r: distToClosePath,
				color: Palette.Colors[curPalIndex],
				immediate: true 
			});

			//draw path
			if (drawingPath.length > 1) {
				for (i in 1 ... drawingPath.length) {
					Luxe.draw.line({
							p0: new Vector(drawingPath[i-1].x, drawingPath[i-1].y),
							p1: new Vector(drawingPath[i].x, drawingPath[i].y),
							color: Palette.Colors[curPalIndex],
							immediate: true
						});
				}
			}

		}
	}


} //Main

class Command {
	static var UndoStack : Array<Command> = [];
	static var RedoStack : Array<Command> = [];

	public function new() {
		Perform();
		UndoStack.push(this);
		RedoStack = [];
	}

	public static function Undo() {
		if (UndoStack.length <= 0) return;
		var cmd = UndoStack.pop();
		cmd.UnPerform();
		RedoStack.push(cmd);
	}

	public static function Redo() {
		if (RedoStack.length <= 0) return;
		var cmd = RedoStack.pop();
		cmd.Perform();
		UndoStack.push(cmd);
	}

	public function Perform() {

	}

	public function UnPerform() {

	}
}

class DrawVexCommand extends Command {
	var properties : VexJsonFormat;
	var parent : Vex;
	public var vex : Vex;

	override public function new(parent:Vex, properties:VexJsonFormat) {
		this.parent = parent;
		this.properties = properties;
		super();
	}

	override public function Perform() {
		vex = new Vex(properties);
		trace("!!! create");
		trace(vex.name);
		vex.parent = parent;
	}

	override public function UnPerform() {
		trace("!!! uncreate");
		//THIS IS A HACK because destroy() doesn't work --- log a luxe bug
		for (v in parent.find(properties.id)) {
			vex = v;
		}
		vex.destroy(true);
		/*
		vex = parent.find(properties.id)[0]; //refind this in case it was created as a new object
		if (vex != null) {
			trace(vex.name);
			trace(vex.properties);
			vex.destroy(true);
		}
		*/
	}
}

class SelectionCommand extends Command {
	var selection : Array<Vex>;

	override public function new(selection:Array<Vex>) {
		this.selection = selection;
		super();
	}
}

class ColorCommand extends SelectionCommand {
	var newColor : Property;
	var oldColors : Array<Property> = [];

	override public function new(selection:Array<Vex>, color:Property) {
		newColor = color;
		for (s in selection) {
			oldColors.push(s.properties.color);
		}
		super(selection);
	}

	override public function Perform() {
		for (s in selection) {
			s.properties.color = newColor;
		}
	}

	override public function UnPerform() {
		for (i in 0 ... selection.length) {
			var s = selection[i];
			s.properties.color = oldColors[i];
		}
	}
}

class DeleteCommand extends SelectionCommand {
	var saveDeletedVex : Array<VexJsonFormat> = [];
	var parent : Vex; //this feels hacky - what if they have different parents?

	override public function new(selection:Array<Vex>) {
		parent = cast(selection[0].parent,Vex);
		for (s in selection) {
			saveDeletedVex.push( s.serialize() );
		}
		super(selection);
	}

	override public function Perform() {
		trace("--- delete");
		/*
		for (s in selection) {
			trace(s.name);
			s.destroy(true);
		}
		selection = [];
		*/
		for (s in saveDeletedVex) {
			var vex : Vex = null;
			for (v in parent.find(s.id)) { //ugly hack again
				vex = v;
			}
			if (vex != null) vex.destroy(true);
		}
		selection = [];
	}

	override public function UnPerform() {
		trace("--- undelete");
		selection = [];
		for (json in saveDeletedVex) {
			var v = new Vex(json);
			trace(v.name);
			v.parent = parent;
			selection.push(v);
		}
	}
}
