import snow.modules.opengl.GL;
import snow.api.buffers.Float32Array;

class Renderer {
	static var renderList : Array<Polygon> = [];

	/* POLYGON PROGRAM */
	static var program : GLProgram;
	static var positionAttributeLocation : Int;
	static var positionBuffer : GLBuffer;
	static var resolutionUniformLocation : GLUniformLocation;
	static var pathUniformLocation : GLUniformLocation;
	static var pathLengthUniformLocation : GLUniformLocation;
	static var colorUniformLocation : GLUniformLocation;
	static var rotationUniformLocation : GLUniformLocation;
	static var originUniformLocation : GLUniformLocation;
	static var positionUniformLocation : GLUniformLocation;
	static var scaleUniformLocation : GLUniformLocation;

	public static function config(config:luxe.GameConfig) : luxe.GameConfig {
		config.preload.texts.push({id:'assets/polyvert.glsl'});
		config.preload.texts.push({id:'assets/polyfrag.glsl'});

		return config;
	}

	public static function ready() {
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

	public static function onrender() {
		/* draw */
		//set the viewport
		GL.viewport(0, 0, Luxe.screen.w, Luxe.screen.h);

		//clear the canvas
		GL.clearColor(0, 0, 0, 0);
		GL.clear(GL.COLOR_BUFFER_BIT);

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

		//render everything in the queue then empty it for the next frame
		for (poly in renderList) {
			renderpoly( poly );
		}
		renderList = [];
	}

	static function renderpoly(poly:Polygon) {
		//property defaults
		var origin = (poly.origin != null) ? poly.origin : [0.0,0.0];
		var pos = (poly.pos != null) ? poly.pos : [0.0,0.0];
		var scale = (poly.scale != null) ? poly.scale : [1.0,1.0];
		var rot = (poly.rot != null) ? poly.rot : 0.0;
		var color = (poly.color != null) ? poly.color : [1.0,1.0,1.0,1.0];
		var path = (poly.path != null) ? poly.path : [0.0,0.0, 0.0,0.0, 0.0,0.0]; //no good default here
		//set uniforms
		GL.uniform2f(originUniformLocation, origin[0], origin[1]);
		GL.uniform2f(positionUniformLocation, pos[0], pos[1]);
		GL.uniform2f(scaleUniformLocation, scale[0], scale[1]);
		GL.uniform1f(rotationUniformLocation, rot);
		GL.uniform4f(colorUniformLocation, color[0], color[1], color[2], color[3]);
		GL.uniform1i(pathLengthUniformLocation, cast(path.length/2,Int));
		GL.uniform2fv(pathUniformLocation, makeFloat32Array(path));
		//draw array
		var primitiveType = GL.TRIANGLES;
		var offset = 0;
		var count = 6;
		GL.drawArrays(primitiveType, offset, count);
	}

	public static function addpoly(poly:Polygon) {
		renderList.push(poly);
	}

	static function makeFloat32Array(arr:Array<Float>) {
		var buf = new Float32Array(arr.length);
		for (i in 0 ... arr.length) {
			buf[i] = arr[i];
		}
		return buf;
	}
}

typedef Polygon = {
	@:optional var path : Array<Float>;
	@:optional var origin : Array<Float>;
	@:optional var pos : Array<Float>;
	@:optional var scale : Array<Float>;
	@:optional var rot : Float;
	@:optional var color : Array<Float>;
}