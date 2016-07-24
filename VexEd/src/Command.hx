
import vexlib.Vex;
import vexlib.VexPropertyInterface;

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

// rename to insert vex command probs
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