
import luxe.Input;

import snow.modules.opengl.GL;
import snow.api.buffers.Float32Array;

import Parser.Figure;

import phoenix.Shader;
import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import phoenix.Batcher;
import luxe.Vector;
import luxe.Color;

/*
	TODO
	X load figures from file
	X figure storage
	X figure drawing
	- anchors / levels
	X layers
	X animation
	X set scale in figure file
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
	X two frame morph animations are finished

	//todo transformation matrix?


	things I like about the new format:
	- editable in text editor
	- visible outside my programs
	- 2 frame morph
	- limitations
	- easy to size things relative to each other
	- can edit on phone
	- simple layers model
	things I don't like
	- can't really see what things look like until you render them in the game
	- very slow iteration / editing loop
	- the grid feels inflexible
	- doesn't support more complex animations
	- no parent-child relationships among polygons
	- can't edit on phone _very well_
*/

class Main extends luxe.Game {

	var figures : Map<String,Figure> = new Map<String,Figure>();
	var scene : Array<Figure>;

	var geoTest : Geometry;

	override function config(config:luxe.GameConfig) {
		/*
		config = Renderer.config( config );
		config.preload.texts.push({id:'assets/figures2.txt'});
		*/

		config.preload.shaders.push({id:'polyshader',vert_id:'assets/polyvertLuxe.glsl',frag_id:'assets/polyfragLuxe.glsl'}); //,frag_id:'assets/polyfrag.glsl'});

		return config;

	}

	var testPoly : PolygonEntity;

	override function ready() {

		geoTest = new Geometry({
			shader: Luxe.resources.shader('polyshader'),
			//color: new Color(1,0,0), //why doesn't this work? //this is likely a bug
			batcher: Luxe.renderer.batcher,
			primitive_type: PrimitiveType.triangles
		});

		/*
			0.0, 0.0,
			1.0, 1.0,
			1.0, 0.0,
			0.0, 0.0,
			1.0, 1.0,
			0.0, 1.0
		*/

		geoTest.add( new Vertex( new Vector(0,0) ) );
		geoTest.add( new Vertex( new Vector(1,1) ) );
		geoTest.add( new Vertex( new Vector(1,0) ) );
		geoTest.add( new Vertex( new Vector(0,0) ) );
		geoTest.add( new Vertex( new Vector(1,1) ) );
		geoTest.add( new Vertex( new Vector(0,1) ) );

		/*
		geoTest.add( new Vertex( new Vector(0,0) ) );
		geoTest.add( new Vertex( new Vector(50,50) ) );
		geoTest.add( new Vertex( new Vector(50,0) ) );
		geoTest.add( new Vertex( new Vector(0,0) ) );
		geoTest.add( new Vertex( new Vector(50,50) ) );
		geoTest.add( new Vertex( new Vector(0,50) ) );
		*/

		geoTest.color = new Color(1,0,0); //but this does?

		//geoTest.shader.set_vector2( 'u_resolution', Luxe.screen.size );
		var path : Array<Float> = [0,0, 50,0, 50,50, 25,35, 0,50];
		trace(path.length/2);
		geoTest.shader.set_int( 'u_pathLength', cast(path.length/2, Int) );
		geoTest.shader.set_vector2_arr( 'u_path', makeFloat32Array(path) );

		/*
		for ( f in Parser.parseFigureFile( Luxe.resources.text('assets/figures2.txt').asset.text ) ) {
			figures[ f.name ] = f;
		}

		Renderer.ready();
		*/

		/*
		testPoly = new PolygonEntity({});
		testPoly.path = [50,50, 150,50, 150,150, 50,150];
		testPoly.color = [1.0,0.0,0.0,1.0];
		testPoly.origin = new luxe.Vector(100,100);
		*/
	} //ready

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function update(dt:Float) {

		// shader test
		//geoTest.shader.set



		// custom renderer test
		/*
		Renderer.addpoly( {path:[0,0, 100,0, 100,100]} );


		testPoly.rotation_z = Math.abs(Math.PI * 2 * Math.sin(Luxe.time*0.3));
		testPoly.pos = new luxe.Vector( Math.cos(Luxe.time*0.3)*300, 0, 0);
		*/



		// old figure test
		//Renderer.addpoly( {path:[50,50, 150,50, 150,150, 50,150],color:[1.0,0.0,0.0,1.0],/*origin:[100,100],*/pos:[200,200]/*,rot:Math.abs(Math.PI * 2 * Math.sin(Luxe.time))*/} );
		
		/*
		drawFigure( figures["tree"] );
		drawFigure( { src:"tree", pos:[200,200] } );
		drawFigure( { src:"tree", pos:[-400,200], color:[1,0,1,1] } );
		drawFigure( figures["kid"] );
		*/

		/*
		drawFigure( { src:"kid", morph:( 0.5 + 0.5*Math.sin(Luxe.time*4) ) } );
		drawFigure( { src:"tree", pos:[200,200], morph:( 0.5 + 0.5*Math.sin(Luxe.time*4) ) } );
		drawFigure( { src:"tree", pos:[-200,-200], color:[1,0,0,1], morph:( 0.5 + 0.5*Math.sin(Luxe.time*4) ) } );
		*/

		/*
		var e = new luxe.Entity({});
		e.pos = new luxe.Vector(0,200);
		var rotE = new luxe.Vector(0,0,Math.PI*0.25);
		var rotQ = new luxe.Quaternion();
		rotQ.setFromEuler(rotE);
		e.rotation = rotQ.clone();
		//e.rotation = new luxe.Quaternion(0,0,1,Math.PI*0.25);
		trace("-- entity --");
		trace(e.transform.world.matrix);
		trace(e.transform.local.matrix);
		*/
	} //update

	override function onrender() {
		//Renderer.onrender();
	}

	/*
	function drawFigure(figure:Figure, ?parent:Figure) {
		if (figure.path != null) {
			var poly : Renderer.Polygon = {};
			poly.path = figure.path;
			//
			if (parent != null){ //this works for layers, but not src, where the "parent" should take precedent
				if (parent.origin != null) poly.origin = parent.origin;
				if (parent.pos != null) poly.pos = parent.pos;
				if (parent.scale != null) poly.scale = parent.scale;
				if (parent.rot != null) poly.rot = parent.rot;
				if (parent.color != null) poly.color = parent.color;
			}
			//
			if (figure.origin != null) poly.origin = figure.origin;
			if (figure.pos != null) poly.pos = figure.pos;
			if (figure.scale != null) poly.scale = figure.scale;
			if (figure.rot != null) poly.rot = figure.rot;
			if (figure.color != null) poly.color = figure.color;
			//
			Renderer.addpoly( poly );
		}

		if (figure.src != null) {
			var srcFig = figures[figure.src];
			var fig : Figure = {};
			fig.name = srcFig.name;
			fig.path = srcFig.path;
			fig.layers = srcFig.layers;
			fig.flip = srcFig.flip;
			fig.color = (figure.color != null) ? figure.color : srcFig.color;
			fig.origin = (figure.origin != null) ? figure.origin : srcFig.origin;
			fig.pos = (figure.pos != null) ? figure.pos : srcFig.pos;
			fig.scale = (figure.scale != null) ? figure.scale : srcFig.scale;
			fig.rot = (figure.rot != null) ? figure.rot : srcFig.rot;
			fig.morph = (figure.morph != null) ? figure.morph : srcFig.morph;
			//todo do something here to move parent attributes into child
			drawFigure( fig );
		}

		if (figure.flip != null) {
			//animated layers
			for (i in 0 ... figure.flip) {
				var a = figure.layers[i];
				var b = figure.layers[i+figure.flip];
				var c = lerpFigure(a, b, figure.morph);
				drawFigure( c, figure );
			}
		}
		else if (figure.layers != null) {
			//non-animated layers
			for (l in figure.layers) {
				drawFigure( l, figure );
			}
		}
	}
	*/

	function lerpFloats(a:Null<Array<Float>>, b:Null<Array<Float>>, t:Float) : Null<Array<Float>> {
		if (a == null && b == null) return null;
		if (a == null) return b;
		if (b == null) return a;

		var c = [];
		for (i in 0 ... a.length) {
			c.push( a[i] + t*( b[i]-a[i] ) );
		}
		return c;
	}

	function lerpFloat(a:Null<Float>, b:Null<Float>, t:Float) : Null<Float> {
		if (a == null && b == null) return null;
		if (a == null) return b;
		if (b == null) return a;
		return a + t*(b-a);
	}

	function lerpFigures(a:Null<Array<Figure>>, b:Null<Array<Figure>>, t:Float) : Null<Array<Figure>> {
		if (a == null && b == null) return null;
		if (a == null) return b;
		if (b == null) return a;

		var c = [];
		for (i in 0 ... a.length) {
			c.push( lerpFigure(a[i],b[i],t) );
		}
		return c;
	}

	function lerpFigure(a:Figure, b:Figure, t:Float) : Figure {
		return {
			name: a.name,
			src: a.src,
			path: lerpFloats( a.path, b.path, t ),
			origin: lerpFloats( a.origin, b.origin, t ),
			scale: lerpFloats( a.scale, b.scale, t ),
			rot: lerpFloat( a.rot, b.rot, t ),
			color: lerpFloats( a.color, b.color, t ),
			layers: lerpFigures( a.layers, b.layers, t )
		};
	}

	function makeFloat32Array(arr:Array<Float>) {
		var buf = new Float32Array(arr.length);
		for (i in 0 ... arr.length) {
			buf[i] = arr[i];
		}
		return buf;
	}

	function makePaddedFloat32Array(arr:Array<Float>) {
		var buf = new Float32Array(32);
		for (i in 0 ... arr.length) {
			buf[i] = arr[i];
		}
		return buf;
	}

} //Main

class PolygonEntity extends luxe.Entity {
	public var color : Array<Float>;
	public var path : Array<Float>;
	public var rotation_z (default,set) : Float;

	override function update(dt:Float) {
		var mat4 = transform.world.matrix;
		//var mat3 = [mat4.M11, mat4.M21, mat4.M41,  mat4.M12, mat4.M22, mat4.M42,  mat4.M14, mat4.M24, mat4.M44];
		var mat3 = [mat4.M11, mat4.M12, mat4.M14,  mat4.M21, mat4.M22, mat4.M24,  mat4.M41, mat4.M42, mat4.M44];
		//trace(mat3);
		Renderer.addpoly({ path:path, color:color, transform:mat3 });
	}

	public function set_rotation_z(radians:Float) : Float {
		rotation_z = radians;
		var rotE = new luxe.Vector(0,0,rotation_z);
		var rotQ = new luxe.Quaternion();
		rotQ.setFromEuler(rotE);
		rotation = rotQ.clone();
		return rotation_z;
	}
}
