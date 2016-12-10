
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
*/

class Main extends luxe.Game {

	var figures : Map<String,Figure> = new Map<String,Figure>();
	var scene : Array<Figure>;

	override function config(config:luxe.GameConfig) {

		config.preload.texts.push({id:'assets/polyvert.glsl'});
		config.preload.texts.push({id:'assets/polyfrag.glsl'});

		config.preload.texts.push({id:'assets/figures.txt'});

		return config;

	}

	override function ready() {
		var figureList = parseFigureFile( Luxe.resources.text('assets/figures.txt').asset.text );
		for (f in figureList) {
			trace(f);
			figures[f.name] = f;
		}

		setupFigureRendering();
	} //ready

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function update(dt:Float) {

	} //update

	override function onrender() {
		/* draw */
		//set the viewport
		GL.viewport(0, 0, Luxe.screen.w, Luxe.screen.h);

		//clear the canvas
		GL.clearColor(0, 0, 0, 0);
		GL.clear(GL.COLOR_BUFFER_BIT);

		//draw figures
		beginFigureRendering();
		/*
		renderFigure( { src:"tree" } );
		renderFigure( { src:"tree", pos:[200.0,200.0], color:[0.0,1.0,0.0,1.0] } );
		renderFigure( { src:"test", pos:[-200.0,-200.0], color:[0.0,0.0,1.0,1.0] } );
		renderFigure( { path:[0.0,0.0, 30.0,0.0, 60.0,30.0, 30.0,20.0, -10.0,30.0], pos:[-200.0,200.0] } );
		*/
		renderFigure( { src:"kid", colors:[[0.0,0.0,1.0,1.0],[1.0,0.0,0.0,1.0]] } );
	}

	/* PARSING */
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

	/* RENDERING */
	var program : GLProgram;
	var positionAttributeLocation : Int;
	var positionBuffer : GLBuffer;
	var resolutionUniformLocation : GLUniformLocation;
	var pathUniformLocation : GLUniformLocation;
	var pathLengthUniformLocation : GLUniformLocation;
	var colorUniformLocation : GLUniformLocation;
	var rotationUniformLocation : GLUniformLocation;
	var originUniformLocation : GLUniformLocation;
	var positionUniformLocation : GLUniformLocation;
	var scaleUniformLocation : GLUniformLocation;

	function setupFigureRendering() {
		/* setup */
		Luxe.renderer.should_clear = false;
		
		//create vertex shader
		var vertexShader = GL.createShader(GL.VERTEX_SHADER);
		GL.shaderSource(vertexShader, Luxe.resources.text('assets/polyvert.glsl').asset.text);
		GL.compileShader(vertexShader);
		var _compile_log = GL.getShaderInfoLog(vertexShader);
		trace("vertex shader results: ");
		trace( _compile_log );

		//create fragment shader
		var fragmentShader = GL.createShader(GL.FRAGMENT_SHADER);
		GL.shaderSource(fragmentShader, Luxe.resources.text('assets/polyfrag.glsl').asset.text);
		GL.compileShader(fragmentShader);
		_compile_log = GL.getShaderInfoLog(fragmentShader);
		trace("fragment shader results: ");
		trace( _compile_log );

		//create shader program
		program = GL.createProgram();
		GL.attachShader(program, vertexShader);
		GL.attachShader(program, fragmentShader);
		GL.linkProgram(program);
		if( GL.getProgramParameter(program, GL.LINK_STATUS) == 0) {
			trace("shader program failed to link");
		}

		//get uniform locations
		trace("-- uniforms --");
		resolutionUniformLocation = GL.getUniformLocation(program, "u_resolution");
		trace(resolutionUniformLocation);
		pathUniformLocation = GL.getUniformLocation(program, "u_path");
		pathLengthUniformLocation = GL.getUniformLocation(program, "u_pathLength");
		originUniformLocation = GL.getUniformLocation(program, "u_origin");
		trace(originUniformLocation);
		positionUniformLocation = GL.getUniformLocation(program, "u_position");
		trace(positionUniformLocation);
		scaleUniformLocation = GL.getUniformLocation(program, "u_scale");
		trace(scaleUniformLocation);
		rotationUniformLocation = GL.getUniformLocation(program, "u_rotation");
		trace(rotationUniformLocation);
		colorUniformLocation = GL.getUniformLocation(program, "u_color");

		//setup position attribute
		positionAttributeLocation = GL.getAttribLocation(program, "a_position");
		positionBuffer = GL.createBuffer();
		GL.bindBuffer(GL.ARRAY_BUFFER, positionBuffer);
		var positions = [
			0.0, 0.0,
			1.0, 1.0,
			1.0, 0.0,
			0.0, 0.0,
			1.0, 1.0,
			0.0, 1.0
		];
		var positionsArr = new Float32Array( positions.length );
		for (i in 0 ... positions.length) {
			positionsArr[i] = positions[i];
		}
		GL.bufferData(GL.ARRAY_BUFFER, positionsArr, GL.STATIC_DRAW);
	}

	function beginFigureRendering() {
		//tell gl to use our program
		GL.useProgram(program);

		//set shared uniforms
		GL.uniform2f(resolutionUniformLocation, Luxe.screen.w, Luxe.screen.h);

		//use the position attribute with the position buffer
		GL.enableVertexAttribArray(positionAttributeLocation);
		GL.bindBuffer(GL.ARRAY_BUFFER, positionBuffer);
		var size = 2;
		var type = GL.FLOAT;
		var normalize = false;
		var stride = 0;
		var offset = 0;
		GL.vertexAttribPointer(positionAttributeLocation, size, type, normalize, stride, offset);
	}

	function renderFigure(f:Figure) {
		//properties //todo use f.src for other features besides path
		var layers = (f.layers != null) ? f.layers : figures[f.src].layers;
		var pos = (f.pos != null) ? f.pos : [0.0,0.0];
		var colors = (f.colors != null) ? f.colors : [[1.0,1.0,1.0,1.0]];

		//set uniforms
		GL.uniform2f(originUniformLocation, 0, 0);
		GL.uniform2f(positionUniformLocation, pos[0], pos[1]);
		GL.uniform2f(scaleUniformLocation, 1, 1);
		GL.uniform1f(rotationUniformLocation, 0);
		//draw array once per layer
		var primitiveType = GL.TRIANGLES;
		var offset = 0;
		var count = 6;
		for (i in 0 ... layers.length) {
			var color = colors[colors.length-1];
			if (colors.length > 1) {
				color = colors[i];
			}
			GL.uniform4f(colorUniformLocation, color[0], color[1], color[2], color[3]);

			var path = layers[i];
			GL.uniform1i(pathLengthUniformLocation, cast(path.length/2,Int));
			GL.uniform2fv(pathUniformLocation, pathToFloat32Array(path));

			GL.drawArrays(primitiveType, offset, count);
		}

		//old version - kept for reference
		/*
		//properties //todo use f.src for other features besides path
		var path = (f.path != null) ? f.path : figures[f.src].path;
		var pos = (f.pos != null) ? f.pos : [0.0,0.0];
		var color = (f.color != null) ? f.color : [1.0,1.0,1.0,1.0];
		//set uniforms
		GL.uniform2f(originUniformLocation, 0, 0);
		GL.uniform2f(positionUniformLocation, pos[0], pos[1]);
		GL.uniform2f(scaleUniformLocation, 1, 1);
		GL.uniform1f(rotationUniformLocation, 0);
		GL.uniform4f(colorUniformLocation, color[0], color[1], color[2], color[3]);
		GL.uniform1i(pathLengthUniformLocation, cast(path.length/2,Int));
		GL.uniform2fv(pathUniformLocation, pathToFloat32Array(path));
		//draw array
		var primitiveType = GL.TRIANGLES;
		var offset = 0;
		var count = 6;
		GL.drawArrays(primitiveType, offset, count);
		*/
	}

	function pathToFloat32Array(path:Array<Float>) {
		var arr = new Float32Array(path.length);
		for (i in 0 ... path.length) {
			arr[i] = path[i];
		}
		return arr;
	}

	function lerpPath(pathA:Array<Float>, pathB:Array<Float>, t:Float) {
		var pathC = [];
		for (i in 0 ... pathA.length) { //path lengths are assumed to be the same
			pathC.push( pathA[i] + (t*(pathB[i] - pathA[i])) );
		}
		return pathC;
	}

} //Main

typedef Figure = {
	@:optional var name : String;
	@:optional var src : String;
	@:optional var layers : Array<Array<Float>>;
	@:optional var pos : Array<Float>;
	@:optional var colors : Array<Array<Float>>;
}