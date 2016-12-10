class Parser {
	public static function parseFigureFile(str:String) /*: Array<Figure>*/ {
		var i = 0;
		while (i < str.length) {
			var char = str.charAt(i);
			if (char == "(") {
				var results = matchParens(str,i);
				i = results.i;
			}
			i++;
		}
	}

	public static function matchParens(str:String, startIndex:Int) {
		var i = startIndex;
		var parenCount = 1;
		var parenStr = "";
		while (parenCount > 0) {
			i++;
			if (str.charAt(i) == "(") parenCount++;
			if (str.charAt(i) == ")") parenCount--;
			if (parenCount > 0) parenStr += str.charAt(i);
		}
		trace(parenStr);
		trace("---");
		return {
			i:i,
			str:parenStr
		};
	}

	public static function figure(str:String) /*: Figure*/ {

	}
}

typedef Figure = {
	@:optional var name : String;
	@:optional var src : String; //for figures that reference other figures
	@:optional var path : Array<Float>; //for single-poly, "leaf" figures
	@:optional var pos : Array<Float>;
	@:optional var color : Array<Float>; //todo: need multiple colors for gradients???
	@:optional var layers : Array<Figure>; //for multi-poly figures
	@:optional var flipIndex : Int; //for animated figures
}