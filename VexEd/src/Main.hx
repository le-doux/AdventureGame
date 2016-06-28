
import luxe.Input;
import luxe.Visual;
import luxe.Vector;
import luxe.Color;

import vexlib.Vex;
//import vexlib.Vex.Palette;

import sys.io.File;
import haxe.Json;
import dialogs.Dialogs;
import luxe.resource.Resource.JSONResource;

/*
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

//test
import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import phoenix.Batcher;

class Main extends luxe.Game {
	override function ready() {
		/*
		var v = new Vex();
		var p = new Poly();
		//trace(v.type.toNonsense());
		v.type = "group";
		v.type = "group2";
		v.type = new Vector(-12,3.1);
		//v.id = "testId";
		v.id = new Vector(30,20);
		trace(v.serialize());
		trace("---");
		p.path = [new Vector(0,10), new Vector(30,40), new Vector(5,-5)];
		trace(p.serialize());
		*/

		/*
		var v = new Vex();
		v.deserialize({
				type:"test",
				id:"testAgain"
			});
		trace(v.serialize());
		*/

		var v = new VexVisual({
				type: "poly",
				color: "pal(0)",
				path: "10,10 30,10 20,20"
			});
	}
}

/*
class Main extends luxe.Game {

	var drawingPath = [];
	var distToClosePath = 16;

	var root : Vex;
	var selected : Vex = null;
	var multiSelection : Array<Vex> = []; //hacky hack hack

	var count = 0;

	var isEditingId = false;

	var curPalIndex = 0;

	override function ready() {
		Luxe.camera.pos.subtract(Luxe.screen.mid); //put 0,0 in the center of the camera

		//init drawing
		root = new Vex({
				type: "group",
				origin: [0,0],
				pos: [0,0]
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

		//load default palette
		var load = Luxe.resources.load_json('assets/default.pal');
		load.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			Palette.Load(json);
		});
	} //ready

	override function ontextinput(e:TextEvent) {
		//edit id
		if (isEditingId) {
			selected.attributes.id += e.text; //TODO command-ify
		}

		//change current color
		var n = Std.parseInt(e.text);
		if (n != null && n > 0 && n < 9) {
			curPalIndex = n - 1;
		} 
	}

	override function onkeydown( e:KeyEvent ) {

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

		//delete selected element
		if (e.keycode == Key.backspace) {
			if (selected != null) {
				selected.destroy(true);
				selected = null; //for now (need a stack?)
			}
		}

		//edit id
		if (e.keycode == Key.key_i && e.mod.meta) {
			if (selected != null) {
				isEditingId = !isEditingId;
				if (isEditingId) selected.attributes.id = "";
			}
		}

		//change color
		if (e.keycode == Key.key_f && e.mod.meta) {
			if (selected != null) {
				new ColorCommand(multiSelection, ["#ddd"]); //hack test (need to overcome problems with palette design & selection)
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
			var saveJson = root.attributes;
			var saveStr = Json.stringify(saveJson, null, "	");
			saveStr = unindentLists(saveStr);
			trace(saveStr);
			output.writeString(saveStr);

			//close file
			output.close();
		}

		//undo redo
		if (e.keycode == Key.key_z && e.mod.meta) Command.Undo();
		if (e.keycode == Key.key_y && e.mod.meta) Command.Redo();

	}

	function unindentLists(jsonString : String) : String {
		var prettyString = "";
		var isInsideList = false;
		for (i in 0 ... jsonString.length) {
			var char = jsonString.charAt(i);
			if (char == "[") {
				var isListOfObjects = false;
				var j = i + 1;
				var nextChar = jsonString.charAt(j);
				while (nextChar == "\n" || nextChar == "\t") {
					j++;
					nextChar = jsonString.charAt(j);
				}
				if (nextChar == "{") {
					isListOfObjects = true;
				}

				if (!isListOfObjects) {
					isInsideList = true;
				}
			}
			if (char == "]") isInsideList = false;
			if (isInsideList && (char == "\t" || char == "\n")) {
				// do nothing
			}
			else {
				prettyString += char;
			}
		}
		return prettyString;
	}

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function onmousedown( e:MouseEvent ) {

		var p = Luxe.camera.screen_point_to_world(e.pos);

		//is the path closed?
		var isPathClosed = false;
		if (drawingPath.length > 2) {
			var startPos = new Vector(drawingPath[0], drawingPath[1]);
			var nextPos = new Vector(p.x, p.y);
			if ( nextPos.subtract(startPos).length < distToClosePath ) {
				isPathClosed = true;
			}
		}

		if (isPathClosed) {
			var colorArr : Array<Dynamic> = ["pal", curPalIndex];
			var cmd = new DrawVexCommand(root, //should parent be a possible attribute?
				{
					type: "poly",
					path: drawingPath,
					id: "poly" + count,
					color: colorArr
				});
			selected = cmd.vex;
			multiSelection.push(cmd.vex);

			//clear drawing path
			drawingPath = [];

			count++;
		}
		else {
			//add new point
			drawingPath.push(p.x);
			drawingPath.push(p.y);
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
					text: "id: " + selected.attributes.id,
					point_size: 16,
					pos: Vector.Multiply( Luxe.screen.mid, -1),
					immediate: true
				});
		}
	} //update

	function renderDrawingPath() {
		if (drawingPath.length > 0) {

			//start circle
			Luxe.draw.ring({
				x: drawingPath[0],
				y: drawingPath[1],
				r: distToClosePath,
				color: Palette.Colors[curPalIndex],
				immediate: true 
			});

			//draw path
			if (drawingPath.length > 2) {
				var i = 3;
				while (i < drawingPath.length) {
					Luxe.draw.line({
							p0: new Vector(drawingPath[i-3], drawingPath[i-2]),
							p1: new Vector(drawingPath[i-1], drawingPath[i-0]),
							color: Palette.Colors[curPalIndex],
							immediate: true
						});
					i += 2;
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
	var attributes : Dynamic;
	var parent : Vex;
	public var vex : Vex;

	override public function new(parent:Vex, attributes:Dynamic) {
		this.parent = parent;
		this.attributes = attributes;
		super();
	}

	override public function Perform() {
		vex = new Vex(attributes);
		parent.addChild(vex);
	}

	override public function UnPerform() {
		vex.destroy(true);
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
	var newColor : Array<Dynamic>;
	var oldColors : Array<Array<Dynamic>> = [];

	override public function new(selection:Array<Vex>, color:Array<Dynamic>) {
		newColor = color;
		for (s in selection) {
			oldColors.push(s.attributes.color);
		}
		super(selection);
	}

	override public function Perform() {
		for (i in 0 ... selection.length) {
			var s = selection[i];
			s.attributes.color = newColor;
			s = Vex.Rebuild(s); //this process is hacky as fuck
			selection[i] = s;
		}
	}

	override public function UnPerform() {
		for (i in 0 ... selection.length) {
			var s = selection[i];
			s.attributes.color = oldColors[i];
			s = Vex.Rebuild(s);
			selection[i] = s;
		}
	}
}
*/
