package vexlib;

import luxe.Vector;

import vexlib.Vex;
import vexlib.VexPropertyInterface;

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
	public var id : Null<Property>;
	public var path : Property;
	public var scenery : Vex;

	public function new(?json:StageFormat) {
		if (json != null) {
			//load stage from json
			deserialize(json);
		}
		else {
			//empty stage
			scenery = new Vex({
					type: "group",
					origin: "0,0",
					pos: "0,0"
				});
		}
	}

	//todo make real
	public function registerDescription( d : luxe.Component ) {
		//TODO make this a real and better thing
		//TODO actually can't the description handle all this logic? maybe not?
		trace("description registered!");
	}

	public function deserialize(json:StageFormat) {
		if (json.id != null) id = json.id;
		if (json.path != null) path = json.path;
		//todo exits
		//todo background
		if (json.scenery != null) {
			scenery = new Vex(json.scenery);
		}
	}

	public function serialize() : StageFormat {
		var json : StageFormat = {};
		json.type = "stage"; //always the same type
		if (id != null) json.id = id;
		json.path = path;
		//todo exits
		//todo background
		json.scenery = scenery.serialize();
		return json;
	}

}