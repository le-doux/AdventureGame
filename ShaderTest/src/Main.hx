
import luxe.Input;
import luxe.Vector;

import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import phoenix.Batcher;

import snow.modules.opengl.GL;
import snow.api.buffers.Float32Array;

class Main extends luxe.Game {

	override function config(config:luxe.GameConfig) {

		config.preload.texts.push({id:'assets/polyvert.glsl'});
		config.preload.texts.push({id:'assets/polyfrag.glsl'});

		return config;

	}

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

	var treeFigure = 
		"
		.....7......
		....###.....
		...#####....
		...#####....
		..6#####8...
		....5#9.....
		...#####....
		..#######...
		..#######...
		.4#######a..
		....3#b.....
		...#####....
		..#######...
		..#######...
		.#########..
		2#########c.
		....1#d.....
		....###.....
		....###.....
		....###.....
		....0#e.....
		";
	var treePath = [];
	var treeSwayFigure =
		"
		............
		...........7
		............
		......6.....
		............
		.......5.9.8
		............
		............
		............
		..4.........
		.....3......
		.......b..a.
		............
		............
		............
		2...........
		....1.d...c.
		............
		............
		............
		....0.e.....
		";
	var treeSwayPath = [];
	var curTreePath = [];

	var numTrees = 2;
	var treePositions = [];
	function randomizeTreePositions() {
		treePositions = [];
		for (i in 0 ... numTrees) {
			var x = -Luxe.screen.w/2 + ( Math.random() * Luxe.screen.w );
			var y = -Luxe.screen.h/2 + ( Math.random() * Luxe.screen.h );
			treePositions.push(x);
			treePositions.push(y);
		}
	}

	override function ready() {

		treePath = figureToPath(treeFigure);
		treeSwayPath = figureToPath(treeSwayFigure);
		trace(treePath);
		randomizeTreePositions();

		Luxe.renderer.should_clear = false;

		/* setup */
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
		
	} //ready

	override function onrender() {
		/* draw */
		//set the viewport
		GL.viewport(0, 0, Luxe.screen.w, Luxe.screen.h);

		//clear the canvas
		GL.clearColor(0, 0, 0, 0);
		GL.clear(GL.COLOR_BUFFER_BIT);

		//tell gl to use our program
		GL.useProgram(program);

		//set uniforms
		GL.uniform2f(resolutionUniformLocation, Luxe.screen.w, Luxe.screen.h);
		GL.uniform2f(originUniformLocation, 0, 0);
		GL.uniform2f(positionUniformLocation, 0, 0);
		GL.uniform2f(scaleUniformLocation, 1, 1);
		GL.uniform1f(rotationUniformLocation, 0);
		GL.uniform4f(colorUniformLocation, 0, 1, 0, 1);
		GL.uniform1i(pathLengthUniformLocation, cast(curTreePath.length/2,Int));
		GL.uniform2fv(pathUniformLocation, pathToFloat32Array(curTreePath));

		//use the position attribute with the position buffer
		GL.enableVertexAttribArray(positionAttributeLocation);
		GL.bindBuffer(GL.ARRAY_BUFFER, positionBuffer);
		var size = 2;
		var type = GL.FLOAT;
		var normalize = false;
		var stride = 0;
		var offset = 0;
		GL.vertexAttribPointer(positionAttributeLocation, size, type, normalize, stride, offset);

		//draw the array
		var primitiveType = GL.TRIANGLES;
		var offset = 0;
		var count = 6;
		GL.drawArrays(primitiveType, offset, count);

		//draw extra trees
		var i = 0;
		while (i < treePositions.length) {
			GL.uniform2f(positionUniformLocation, treePositions[i+0], treePositions[i+1]);
			GL.drawArrays(primitiveType, offset, count);
			i += 2;
		}

	}

	var vertexSymbols = "0123456789abcdefghijklmnopqrstuvwxyz";
	function figureToPath(figureStr:String) : Array<Float> {
		var path = [];
	
		var lines = figureStr.split("\n");
		lines = lines.slice(1,lines.length-1);
		lines = lines.map( function(str) { return StringTools.trim(str); });

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

	override function onmousedown(e:MouseEvent) {
		//numTrees *= 2;
		numTrees += 10;
		randomizeTreePositions();
	}

	override function update(dt:Float) {
		//trace(1.0 / dt);

		Luxe.draw.text({
				text: "fps " + (1.0 / dt) + "\n" + "trees " + numTrees,
				immediate: true
			});

		curTreePath = lerpPath( treePath, treeSwayPath, Math.sin(Luxe.time) );
	} //update

	/*
	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function update(dt:Float) {

	} //update


	override function onmousewheel(e:MouseEvent) {
		Luxe.camera.zoom += e.y * 0.03 * Luxe.camera.zoom;
		trace(Luxe.camera.zoom);
	}
	*/

} //Main
