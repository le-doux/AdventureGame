package vexlib;

import vexlib.Vex;
import vexlib.VexPropertyInterface;

typedef FontFormat = {
	@:optional public var type : Property;
	@:optional public var id : Property;
	@:optional public var characters : Array<VexJsonFormat>;
}

class Font {
	public var type : Null<Property>;
	public var id : Null<Property>;

	//map of character strings to vex drawing data
	private var characters : Map<String,VexJsonFormat> = new Map<String,VexJsonFormat>(); //does it need to be private?
	
	public function new(?json:FontFormat) {
		type = "font"; //this is the same no matter what
		if (json != null) {
			deserialize(json);
		}
	}

	public function deserialize(json:FontFormat) {
		if (json.id != null) id = json.id;

		if (json.characters != null) {
			for (c in json.characters) {
				if (c.id != null) { //requires an id to add it to the map
					set(c.id, c);
				}
			}
		}
	}

	public function serialize() : FontFormat {
		var json : FontFormat = {};

		json.type = type;
		if (id != null) json.id = id;

		json.characters = [];
		for (c in alphabeticalCharacterKeys()) {
			json.characters.push( get(c) );
		}

		return json;
	}

	public function exists(char:String) : Bool {
		return characters.exists(char);
	}

	public function get(char:String) : VexJsonFormat {
		return characters[char];
	}

	public function set(char:String, vex:VexJsonFormat) {
		characters[char] = vex;
	}

	public function alphabeticalCharacterKeys() : Array<String> {
		var keyArr = [];
		for (k in characters.keys()) {
			keyArr.push(k);
		}
		keyArr.sort( function(a:String, b:String):Int
		{
			if (a < b) return -1;
			if (a > b) return 1;
			return 0;
		} );
		return keyArr;
	}

}