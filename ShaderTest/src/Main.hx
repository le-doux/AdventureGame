
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

	override function ready() {

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
		GL.uniform2f(positionUniformLocation, 0, 200);
		GL.uniform2f(scaleUniformLocation, 1, 1);
		GL.uniform1f(rotationUniformLocation, Math.PI * 0.5);
		GL.uniform4f(colorUniformLocation, 0, 1, 0, 1);
		GL.uniform1i(pathLengthUniformLocation, 5);
		var pathArray = new Float32Array(10);
		pathArray[0] = 0; //(0,0)
		pathArray[1] = 0;
		pathArray[2] = 60; //(60,0)
		pathArray[3] = 0;
		pathArray[4] = 80; //(80,40)
		pathArray[5] = 40;
		pathArray[6] = 50; //(50,100)
		pathArray[7] = 100;
		pathArray[8] = 30; //(50,100)
		pathArray[9] = 30;
		GL.uniform2fv(pathUniformLocation, pathArray);

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
	}

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
