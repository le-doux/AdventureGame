
import luxe.Input;

import snow.modules.opengl.GL;
import snow.api.buffers.Float32Array;

/*
	TODO
	X load figures from file
	X figure storage
	X figure drawing
	- anchors / levels
	X layers
	- animation
	- set scale in figure file
	- standard screen dimensions

	questions
	- how do I associate colors and other properties w/ specific layers in the file format
	- can I name a layer?
	- do I still want to keep a "single-poly" figure option
		- if so, how do I break up layers?
			- nested figures?
			- should I really associate colors and paths directly as one?
	- when do I resolve (palette) colors?
		- do I borrow my vex properties?
	- worried the route I'm going may make me run into problems w/ more complex characters (like the protag)
		- more polygons
		- more animations than one
		- more complex animations
		- recycle my vex work here?
		- can I make the two formats play nice?
		- is this even a worthwhile route?
		- can't I use what I already made?

	take stock after
	- anchors are finished
	- two frame morph animations are finished
*/

class Main extends luxe.Game {

	/*
	var figures : Map<String,Figure> = new Map<String,Figure>();
	var scene : Array<Figure>;
	*/

	override function config(config:luxe.GameConfig) {
		config = Renderer.config( config );
		config.preload.texts.push({id:'assets/figures2.txt'});

		return config;

	}

	override function ready() {
		/*
		var figureList = parseFigureFile( Luxe.resources.text('assets/figures.txt').asset.text );
		for (f in figureList) {
			trace(f);
			figures[f.name] = f;
		}
		*/

		Parser.parseFigureFile( Luxe.resources.text('assets/figures2.txt').asset.text );

		Renderer.ready();
	} //ready

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function update(dt:Float) {
		Renderer.addpoly( {path:[0,0, 100,0, 100,100]} );
		Renderer.addpoly( {path:[50,50, 150,50, 150,150, 50,150],color:[1.0,0.0,0.0,1.0]} );
	} //update

	override function onrender() {
		Renderer.onrender();
	}

	/* PARSING */
	/*
	function parseFigureFile(fileStr:String) : Array<Figure> {
		var figureList = [];

		var lines = fileStr.split("\n");
		var i = 0;

		while (i < lines.length) {
			var curLine = lines[i];
			if (curLine.length <= 0) {
				//empty line
				i++;
			}
			else if (parseType(curLine) == "figure") {
				var results = parseFigure(i,lines);
				figureList.push( results.figure );
				i = results.i;
			}
			else {
				//unreadable line
				i++;
			}
		}

		return figureList;
	}

	function parseType(lineStr:String) : String {
		return parseArguments(lineStr)[0].toLowerCase();
	}

	function parseArguments(lineStr:String) : Array<String> {
		return lineStr.split(" ");
	}

	function parseFigure(i:Int,lines:Array<String>) {
		var figure : Figure = {};

		figure.name = parseArguments(lines[i])[1];
		i++;

		figure.layers = [];
		while (i < lines.length && lines[i].length > 0) {
			trace("figure");
			trace(lines[i]);
			var results = parseFigurePath(i,lines);
			figure.layers.push( results.path );
			i = results.i;
		}

		return {
			i: i,
			figure: figure
		};
	}

	function parseFigurePath(i:Int,lines:Array<String>) {		
		var figureStr = "";
		while (lines[i].length > 0 && lines[i].charAt(0) != "-") { //"-" is the seperator character //todo more robust parsing (whitespace lines, eof)
			trace("path");
			trace(lines[i]);
			figureStr += lines[i] + "\n";
			i++;
		}

		var path = figure( figureStr );

		i++;

		return {
			i: i,
			path: path
		};
	}

	var vertexSymbols = "0123456789abcdefghijklmnopqrstuvwxyz";
	var anchorSymbols = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
	//the core ascii-to-vector algorithm
	//todo: does it need a more descriptive name?
	function figure(str:String) : Array<Float> {
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

	function lerpPath(pathA:Array<Float>, pathB:Array<Float>, t:Float) {
		var pathC = [];
		for (i in 0 ... pathA.length) { //path lengths are assumed to be the same
			pathC.push( pathA[i] + (t*(pathB[i] - pathA[i])) );
		}
		return pathC;
	}
	*/

} //Main

/*
old versions
typedef Figure = {
	@:optional var name : String;
	@:optional var src : String;
	@:optional var path : Array<Float>;
	@:optional var pos : Array<Float>;
	@:optional var color : Array<Float>;
}
*/

/*
typedef Figure = {
	@:optional var name : String;
	@:optional var src : String;
	@:optional var layers : Array<Array<Float>>;
	@:optional var pos : Array<Float>;
	@:optional var colors : Array<Array<Float>>;
}
*/

/*
typedef Figure = {
	@:optional var name : String;
	@:optional var src : String; //for figures that reference other figures
	@:optional var path : Array<Float>; //for single-poly, "leaf" figures
	@:optional var pos : Array<Float>;
	@:optional var color : Array<Float>; //todo: need multiple colors for gradients???
	@:optional var layers : Array<Figure>; //for multi-poly figures
	@:optional var flipIndex : Int; //for animated figures
}
*/
//todo lerp figures (recursive!!!)

//Figure as Figure and Layer and Frame... can that work?
//"anchors" could be there own layer/figures too, just ones that use "src" + a "pos" offset