
import luxe.Input;
import luxe.Vector;

import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import phoenix.Batcher;

import snow.modules.opengl.GL;
import snow.api.buffers.Float32Array;

class Main extends luxe.Game {

	override function config(config:luxe.GameConfig) {

		config.preload.texts.push({id:'assets/basicvert_2.glsl'});
		config.preload.texts.push({id:'assets/basicfrag_2.glsl'});

		return config;

	}

	var program : GLProgram;
	var positionAttributeLocation : Int;
	var positionBuffer : GLBuffer;
	var resolutionUniformLocation : GLUniformLocation;
	//var pathUniformLocation,pathLengthUniformLocation;
	//var colorUniformLocation;
	var rotationUniformLocation : GLUniformLocation;
	var originUniformLocation : GLUniformLocation;
	var positionUniformLocation : GLUniformLocation;
	var scaleUniformLocation : GLUniformLocation;

	override function ready() {

		/* setup */
		//create vertex shader
		var vertexShader = GL.createShader(GL.VERTEX_SHADER);
		GL.shaderSource(vertexShader, Luxe.resources.text('assets/basicvert_2.glsl').asset.text);
		GL.compileShader(vertexShader);

		//create fragment shader
		var fragmentShader = GL.createShader(GL.FRAGMENT_SHADER);
		GL.shaderSource(fragmentShader, Luxe.resources.text('assets/basicfrag_2.glsl').asset.text);
		GL.compileShader(fragmentShader);

		//create shader program
		program = GL.createProgram();
		GL.attachShader(program, vertexShader);
		GL.attachShader(program, fragmentShader);
		GL.linkProgram(program);

		//get uniform locations
		/*
		resolutionUniformLocation = GL.getUniformLocation(program, "u_resolution");
		//pathUniformLocation = GL.getUniformLocation(program, "u_path");
		//pathLengthUniformLocation = GL.getUniformLocation(program, "u_pathLength");
		originUniformLocation = GL.getUniformLocation(program, "u_origin");
		positionUniformLocation = GL.getUniformLocation(program, "u_position");
		scaleUniformLocation = GL.getUniformLocation(program, "u_scale");
		rotationUniformLocation = GL.getUniformLocation(program, "u_rotation");
		//colorUniformLocation = GL.getUniformLocation(program, "u_color");
		*/

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

	override function onpostrender() { //hacky
		/* draw */
		//set the viewport
		//GL.viewport(0, 0, 500,500);

		//clear the canvas
		//GL.clearColor(0, 0, 0, 0);
		//GL.clear(GL.COLOR_BUFFER_BIT);

		//tell gl to use our program
		GL.useProgram(program);

		//set uniforms
		/*
		trace(resolutionUniformLocation);
		var resolution = new Float32Array(2);
		resolution[0] = 500;
		resolution[1] = 500;
		trace(resolution);
		GL.uniform2fv(resolutionUniformLocation, 500, 500);
		//GL.uniform2fv(pathUniformLocation, poly.path);
		//GL.uniform1i(pathLengthUniformLocation, (poly.path.length/2));
		var origin = new Float32Array(2);
		origin[0] = 0;
		origin[1] = 0;
		GL.uniform2fv(originUniformLocation, origin);
		var position = new Float32Array(2);
		position[0] = 0;
		position[1] = 0;
		GL.uniform2fv(positionUniformLocation, position);
		var scale = new Float32Array(2);
		scale[0] = 1;
		scale[1] = 1;
		GL.uniform2fv(scaleUniformLocation, scale);
		GL.uniform1f(rotationUniformLocation, 0);
		//GL.uniform4fv(colorUniformLocation, poly.color);
		*/

		//test uniform
		var u = GL.getUniformLocation(program, "u_mult");
		var a = new Float32Array(1);
		a[0] = 0.5;
		a[1] = 1.0;
		GL.uniform2fv(u, a); //2fv doesn't work yet...
		//GL.uniform2f(u, 0.5, 1.0);

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
	override function config(config:luxe.GameConfig) {

		config.preload.shaders.push({ id:'poly', frag_id:'assets/polyfrag.glsl', vert_id:'assets/polyvert.glsl' });

		return config;

	}

	override function ready() {
		var g = new Geometry({ batcher:Luxe.renderer.batcher, primitive_type:PrimitiveType.triangles, shader:Luxe.resources.shader("poly") });
		g.vertices.push( new Vertex(new Vector(0,0)) );
		g.vertices.push( new Vertex(new Vector(1,0)) );
		g.vertices.push( new Vertex(new Vector(0,1)) );
		g.vertices.push( new Vertex(new Vector(1,0)) );
		g.vertices.push( new Vertex(new Vector(0,1)) );
		g.vertices.push( new Vertex(new Vector(1,1)) );

		g.shader.set_vector2("u_resolution", Luxe.screen.size);
		g.shader.set_vector2("u_origin", new Vector(0,0));
		g.shader.set_vector2("u_position", new Vector(0,0));
		g.shader.set_vector2("u_scale", new Vector(1,1));
		g.shader.set_float("u_rotation", 0);
	} //ready

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
