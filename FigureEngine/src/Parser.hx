class Parser {
	public static function parseFigureFile(str:String) : Array<Figure> {
		var figureList = [];
		var i = 0;
		while (i < str.length) {
			var char = str.charAt(i);
			if (char == "(") {
				var results = matchParens(str,i);
				var f = parseFigure( results.str );
				figureList.push(f);
				i = results.i;
			}
			i++;
		}
		return figureList;
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
		/*
		trace(parenStr);
		trace("---");
		*/
		return {
			i:i,
			str:parenStr
		};
	}

	public static function parseFigure(str:String) : Figure {

		var figure : Figure = {};

		var i = 0;
		var char = str.charAt(i);
		//parse figures
		var layerStrList = [];
		var curFigureStr = "";
		var foundSemi = false;
		while (!foundSemi) {
			if (char == ";") {
				layerStrList.push( curFigureStr );
				curFigureStr = "";
				foundSemi = true;
			}
			else if (char == ",") {
				layerStrList.push( curFigureStr );
				curFigureStr = "";
			}
			else if (char == "(") {
				var results = matchParens(str,i);
				curFigureStr += results.str;
				i = results.i;
			}
			else {
				curFigureStr += char;
			}
			i++;
			if (i < str.length) {
				char = str.charAt(i);
			}
			else {
				layerStrList.push( curFigureStr );
				curFigureStr = "";
				foundSemi = true;//hackish
			}
		}
		if (layerStrList.length == 1) {
			trace(layerStrList[0]);
			figure.path = parsePathFromAscii( layerStrList[0] ); // base case
		}
		else if (layerStrList.length > 1) {
			figure.layers = [];
			for (layerStr in layerStrList) {
				figure.layers.push( parseFigure(layerStr) ); // recursive case
			}
		}
		//parse the rest
		var properties = str.substr(i).split(";");
		for (prop in properties) {
			var propArgs = prop.split(":");
			var propType = StringTools.trim( propArgs[0] );
			var propValue = StringTools.trim( propArgs[1] );
			if (propType == "name") {
				figure.name = propValue; 
			}
			else if (propType == "src") {
				figure.src = propValue; 
			}
			else if (propType == "origin") {
				var colorArgs = propValue.split(",");
				figure.origin = colorArgs.map( function(s) { return Std.parseFloat(s); } );
			}
			else if (propType == "pos") {
				var colorArgs = propValue.split(",");
				figure.pos = colorArgs.map( function(s) { return Std.parseFloat(s); } );
			}
			else if (propType == "scale") {
				var colorArgs = propValue.split(",");
				figure.scale = colorArgs.map( function(s) { return Std.parseFloat(s); } );
			}
			else if (propType == "rot") {
				figure.rot = Std.parseFloat( propValue );
			}
			else if (propType == "color") {
				var colorArgs = propValue.split(",");
				figure.color = colorArgs.map( function(s) { return Std.parseFloat(s); } );
			}
			else if (propType == "flip") {
				figure.flip = Std.parseInt( propValue );
			}
		}
		trace(figure);
		return figure;
	}

	static var vertexSymbols = "0123456789abcdefghijklmnopqrstuvwxyz";
	static var anchorSymbols = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
	//the core ascii-to-vector algorithm
	//todo: does it need a more descriptive name?
	public static function parsePathFromAscii(str:String) : Array<Float> {
		var path = [];
	
		var lines = str.split("\n"); //split string into lines
		lines = lines.map( function(str) { return StringTools.trim(str); } ); //remove whitespace
		lines = lines.filter( function(str) { return str.length > 0; } ); //remove empty lines

		//define figure dimensions
		var height = lines.length;
		var width = lines[0].length;

		//parse raw grid vertices
		var vertices = [];
		for (y in 0 ... height) {
			var l = lines[y];
			for (x in 0 ... width) {
				var char = l.charAt(x);
				var index = vertexSymbols.indexOf(char); 
				if ( index != -1 ) {
					vertices.push( {i:index, x:x, y:y } );
				}
			}
		}

		//sort vertices
		vertices.sort( function(a:{i:Int,x:Int,y:Int}, b:{i:Int,x:Int,y:Int}):Int { return a.i - b.i; } );

		//make path
		var multiplier = 10.0;
		for (i in 0 ... vertices.length) {
			path.push( vertices[i].x * multiplier );
			path.push( vertices[i].y * -multiplier );
		}

		return path;
	}
}

typedef Figure = {
	@:optional var name : String;
	@:optional var src : String; //for figures that reference other figures
	@:optional var path : Array<Float>; //for single-poly, "leaf" figures
	@:optional var layers : Array<Figure>; //for multi-poly figures
	@:optional var color : Array<Float>; //todo: need multiple colors for gradients???
	@:optional var origin : Array<Float>;
	@:optional var pos : Array<Float>;
	@:optional var scale : Array<Float>;
	@:optional var rot : Float;
	//for animated figures
	@:optional var flip : Int; //index that splits the flipbook
	@:optional var morph : Float; //percentage complete morphing between the two "pages"
}