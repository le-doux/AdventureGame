
import luxe.Input;
import luxe.GameConfig;

import luxe.Visual;
import luxe.Color;
import luxe.Vector;

import phoenix.Texture;
import phoenix.Texture.FilterType;
import phoenix.geometry.Vertex;
import phoenix.geometry.Geometry;
import phoenix.Batcher;

import snow.api.buffers.Uint8Array;
import snow.api.buffers.ArrayBufferView;
import snow.api.buffers.ArrayBuffer;
import snow.api.buffers.TypedArrayType;

/*
HYBRID RENDERER
- create quads
- software render polygon textures
- send texture + quad to hardware to render final scene

TODO
X polygon -> quad
X polygon -> texture
X full render
- multiple polygons
X test pan & zoom
- animation
	- update vertices
	- update texture
- test performance
*/

typedef Polygon = Array<Float>;
typedef Bounds = {
	public var left : Int;
	public var right : Int;
	public var top : Int;
	public var bottom : Int;
}

class Main extends luxe.Game {

	var polyTest : Array<Float> = [ 400,200, 500,300, 300,300, 400,270, 400,200 ];
	// var polyTest : Array<Float> = [ 10,10, 100,10, 100,100, 10,100, 10,10 ];
	// var polyTest : Array<Float> = [ 10,10, 10,100, 100,100, 10,10 ];

	override function config(config:GameConfig) {

		config.window.width = 800;
		config.window.height = 600;

		return config;
	}

	override function ready() {
		//test
		// var v = new Visual( { pos: new Vector(10, 10), size: new Vector(100,200), color: new Color(0,1,0) } );
		
		// var b : Bounds = { left:10, right:110, top:10, bottom:210 };

		// Luxe.renderer.clear_color = new Color(0,0,1);
		
		// geometry version -- failed why??
		// var bounds = getPolyBounds( polyTest );
		// var quad = quadFromBounds( bounds );
		// var pixels = pixelsFromBounds( bounds );
		// pixels = drawPolygonIntoBuffer( pixels, bounds, polyTest, 255, 0, 0, 255 );
		// var width = bounds.right - bounds.left;
		// var height = bounds.bottom - bounds.top;
		// quad.texture = textureFromPixels( width, height, pixels );

		// hacky test
		// var pixels = new Uint8Array( 2 * 2 * 4 );
		// var i = 4;
		// pixels.buffer[ i + 0 ] = cast 0;
		// pixels.buffer[ i + 1 ] = cast 255;
		// pixels.buffer[ i + 2 ] = cast 0;
		// pixels.buffer[ i + 3 ] = cast 255;
		// i = 8;
		// pixels.buffer[ i + 0 ] = cast 255;
		// pixels.buffer[ i + 1 ] = cast 0;
		// pixels.buffer[ i + 2 ] = cast 0;
		// pixels.buffer[ i + 3 ] = cast 255;
		// var v = new Visual( { pos: new Vector(10, 10), size: new Vector(100,100), color: new Color(1,1,1) } );
		// v.texture = textureFromPixels( 2, 2, pixels );
		// quad.texture = textureFromPixels( 2, 2, pixels );

		// visual version -- TODO what is the difference between this and the geometry version???
		var bounds = getPolyBounds( polyTest );
		var width = bounds.right - bounds.left;
		var height = bounds.bottom - bounds.top;
		var visual = new Visual( { pos: new Vector(bounds.left, bounds.top), size: new Vector(width,height), color: new Color(1,1,1) } );
		var pixels = pixelsFromBounds( bounds );
		pixels = drawPolygonIntoBuffer( pixels, bounds, polyTest, 255, 0, 0, 255 );
		visual.texture = textureFromPixels( width, height, pixels );
	} //ready

	override function onkeydown( e:KeyEvent ) {

		if(e.keycode == Key.up) {
			Luxe.camera.pos.y -= 10;
		}
		if(e.keycode == Key.down) {
			Luxe.camera.pos.y += 10;
		}
		if(e.keycode == Key.left) {
			Luxe.camera.pos.x -= 10;
		}
		if(e.keycode == Key.right) {
			Luxe.camera.pos.x += 10;
		}

		if(e.keycode == Key.key_9) {
			Luxe.camera.zoom -= 0.1;
		}
		if(e.keycode == Key.key_0) {
			Luxe.camera.zoom += 0.1;
		}

	} //onkeydown

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	//fps tracking
	var fps = 60.0;
	var fpsSamples = [];
	var fpsSampleTime = 0.0;
	function trackFps(dt:Float) {
		//fps tracking
		fpsSamples.push( 1.0 / dt );
		fpsSampleTime += dt;
		if (fpsSampleTime >= 1.0) {
			fps = 0.0;
			for (s in fpsSamples) {
				fps += s;
			}
			fps /= fpsSamples.length;
			fps = Math.floor( fps );
			fpsSampleTime = 0.0;
			fpsSamples = [];
		}

		Luxe.draw.text({
				text: "fps " + fps, // + "\n" + "polys " + polygons.length,
				immediate: true
			});
	}

	override function update(dt:Float) {
		trackFps(dt);
	} //update

	function getPolyBounds( polygon:Polygon ) : Bounds {
		var left = polygon[0];
		var right = polygon[0];
		var top = polygon[1];
		var bottom = polygon[1];

		var i = 0;
		while (i < polygon.length) {
			var x = polygon[i+0];
			var y = polygon[i+1];

			left = Math.min( left, x );
			right = Math.max( right, x );

			top = Math.min( top, y );
			bottom = Math.max( bottom, y );

			i += 2;
		}

		return {
			left:Math.floor(left), right:Math.floor(right),
			top:Math.floor(top), bottom:Math.floor(bottom)
		};
	}

	function quadFromBounds(b:Bounds) : Geometry {
		var opt : luxe.options.GeometryOptions = {};
		// opt.color = new Color(1,0,0);
		opt.batcher = Luxe.renderer.batcher;
		opt.primitive_type = PrimitiveType.triangles;

		var geo = new Geometry( opt );

		// left-top triangle
		geo.add( new Vertex( new Vector( b.left, b.top ) ) );
		geo.add( new Vertex( new Vector( b.left, b.bottom ) ) );
		geo.add( new Vertex( new Vector( b.right, b.top ) ) );

		// right-bottom triangle
		geo.add( new Vertex( new Vector( b.right, b.bottom ) ) );
		geo.add( new Vertex( new Vector( b.right, b.top ) ) );
		geo.add( new Vertex( new Vector( b.left, b.bottom ) ) );

		return geo;
	}

	function pixelsFromBounds(b:Bounds) {
		var width = b.right - b.left;
		var height = b.bottom - b.top;
		return new Uint8Array( width * height * 4 );
	}

	function drawPolygonIntoBuffer( pixels:Uint8Array, bounds:Bounds, polygon:Polygon, r:Int, g:Int, b:Int, a:Int ) {
		var width = bounds.right - bounds.left;
		// var height = bounds.bottom - bounds.top;
		var pixelSize = 4;
		for ( y in bounds.top ... bounds.bottom ) {
			var yBuf = y - bounds.top;
			var debugStr = "";
			for ( x in bounds.left ... bounds.right ) {
				var xBuf = x - bounds.left;
				var pixelStartIndex = ( yBuf * width * pixelSize ) + ( xBuf * pixelSize );
				// trace( x + ", " + y );
				// trace( xBuf + ", " + yBuf );
				if ( isPixelInPoly( x, y, polygon ) ) {
					// trace("!");
					if (x % 2 == 0) debugStr += "X";
					// trace( "!" + x + ", " + y );
					pixels.buffer[ pixelStartIndex + 0 ] = cast r;
					pixels.buffer[ pixelStartIndex + 1 ] = cast g;
					pixels.buffer[ pixelStartIndex + 2 ] = cast b;
					pixels.buffer[ pixelStartIndex + 3 ] = cast a;
					// pixels.buffer[ pixelStartIndex + 0 ] = cast 255;
					// pixels.buffer[ pixelStartIndex + 1 ] = cast 255;
					// pixels.buffer[ pixelStartIndex + 2 ] = cast 255;
					// pixels.buffer[ pixelStartIndex + 3 ] = cast 255;
				}
				else { // necessary?
					if (x % 2 == 0) debugStr += ".";
					// trace( x + ", " + y );
					pixels.buffer[ pixelStartIndex + 0 ] = cast 0;
					pixels.buffer[ pixelStartIndex + 1 ] = cast 0;
					pixels.buffer[ pixelStartIndex + 2 ] = cast 0;
					pixels.buffer[ pixelStartIndex + 3 ] = cast 0;
					// pixels.buffer[ pixelStartIndex + 0 ] = cast r;
					// pixels.buffer[ pixelStartIndex + 1 ] = cast g;
					// pixels.buffer[ pixelStartIndex + 2 ] = cast b;
					// pixels.buffer[ pixelStartIndex + 3 ] = cast a;
				}
				// pixels.buffer[ pixelStartIndex + 0 ] = cast 255;
				// pixels.buffer[ pixelStartIndex + 1 ] = cast 255;
				// pixels.buffer[ pixelStartIndex + 2 ] = cast 255;
				// pixels.buffer[ pixelStartIndex + 3 ] = cast 255;
			}
			// trace( debugStr );
		}
		return pixels;
	}

	function isPixelInPoly( x:Int, y:Int, polygon:Polygon ) {

		// var isTestPixel = x == 350 && y == 250;
		// if (isTestPixel) {
		// 	trace("---");
		// }

		var cx = x + 0.5; // the 0.5 pixel adjustment stops you from hitting corners dead on
		var cy = y + 0.5;
		var hitCount = 0;
		var i = 0;
		while (i+3 < polygon.length) { 
			var ax = polygon[i+0]; //todo need a point abstraction don't i
			var ay = polygon[i+1];
			var bx = polygon[i+2];
			var by = polygon[i+3];

			var yDeltaAlongLine = (cy - ay) / (by - ay);
			var closestXPositionOnLine = ax + ( (bx - ax) * yDeltaAlongLine );
			var isInYRange = yDeltaAlongLine >= 0 && yDeltaAlongLine <= 1;
			var isLeftOfLine = cx <= closestXPositionOnLine;
			var doesHitLine = isInYRange && isLeftOfLine;

			// if (isTestPixel) {
			// 	trace( i + " " + doesHitLine );
			// }

			if (doesHitLine) hitCount++;

			i += 2;
		}

		// if (isTestPixel) {
		// 	trace( x + "," + y + " " + hitCount );
		// }

		return (hitCount % 2) == 1;
	}

	function textureFromPixels( width:Int, height:Int, pixels:Uint8Array ) {
		return new Texture({ id:"tex", width: width, height: height, pixels: pixels, filter_min: FilterType.nearest, filter_mag: FilterType.nearest });
	}


} //Main
