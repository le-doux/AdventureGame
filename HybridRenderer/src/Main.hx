
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

using cpp.NativeArray; //for blit


/*
HYBRID RENDERER
- create quads
- software render polygon textures
- send texture + quad to hardware to render final scene

TODO
X polygon -> quad
X polygon -> texture
X full render
X multiple polygons (static)
X test pan & zoom
X animation
	- update vertices
	- update texture
- test performance
	- test animation performance (it bad)
- design
	- paths <--> texture <--> quad
	- keep all elements separate, yet associable
	- possible to render multiple paths into the same texture
	- needs explicit control over what's re-rendered (but with sane defaults)
	- consider local-space vs world-space (may want to be able to rotate quads)
		- does scale of the visual/geo impact the rendering resolution of the path/poly?
	- what data structures do we use on the rendering side?
- test zoom that triggers redraw
	- can we do it async?
	- can we do it by targetting a goal zoom?
	- can we do it based on which elements are visible?
X texture sharing perf tests

NOTES & IDEAS
- moving textures around is hard on the gpu
- pre-render animations?
- try implementing earcut instead?

PERF
mac debug perf bounds: 256 - 512 quads (each with their own texture)
	locked: 512 -> 50 fps (some improvement)
	unlocked: 512 -> 30 fps
mac ship perf bounds: 512 - 1024 quads

SHARED TEXTURE (1) PERF
mac debug perf bounds: 1024 - 2048 quads (sharing 1 texture)
mac ship perf bounds: 1024 - 2048 quads

ANIM PERF
mac debug 8-16
*/

typedef PixelBuffer = Uint8Array;
typedef Polygon = Array<Float>;
typedef Bounds = {
	public var left : Int;
	public var right : Int;
	public var top : Int;
	public var bottom : Int;
};
typedef RGBA = {
	public var r : Int;
	public var g : Int;
	public var b : Int;
	public var a : Int;
};
typedef AnimatedPolygon = {
	public var frame0 : Polygon;
	public var frame1 : Polygon;
	public var color : RGBA;
};

class Main extends luxe.Game {

	// first animation test
	// var polyTest : Array<Float> = [ 400,200, 500,300, 300,300, 400,270, 400,200 ];
	// var polyTest2 : Array<Float> = [ 400,100, 300,260, 300,400, 200,250, 400,100 ];
	// var polyTestVisual : Visual;
	var lerp = {
		factor : 0.0
	};

	// multiple animation test
	var animatedPolyData : Array<AnimatedPolygon> = [];
	var animatedPolyVisual : Array<Visual> = [];

	// var polyTest : Array<Float> = [ 10,10, 100,10, 100,100, 10,100, 10,10 ];
	// var polyTest : Array<Float> = [ 10,10, 10,100, 100,100, 10,10 ];

	var polyVisuals : Array<Visual> = [];

	//texture test
	var sharedTexture : Texture;

	override function config(config:GameConfig) {

		config.window.width = 800;
		config.window.height = 600;

		return config;
	}

	override function ready() {
		// shared texture test
		// var bounds = getPolyBounds( polyTest );
		// var pixels = pixelsFromBounds( bounds );
		// pixels = drawPolygonIntoBuffer( pixels, bounds, polyTest, 255, 0, 255, 255 );
		// var width = bounds.right - bounds.left;
		// var height = bounds.bottom - bounds.top;
		// sharedTexture = textureFromPixels( width, height, pixels );

		for (i in 0 ... 4) {
			var p = makeRandomPoly();
			p.geometry.locked = false;
			polyVisuals.push( p );
		}

		// for (i in 0 ... 2) {
		// 	var a = randomAnimatedPolygon();
		// 	animatedPolyData.push( a );
		// 	animatedPolyVisual.push( makePolygonVisual( a.frame0, a.color ) );
		// }

		// polyTestVisual = makePolygonVisual( polyTest, {r:255,g:0,b:0,a:255} );
		luxe.tween.Actuate.tween( lerp, 1.0, {factor:1.0} ).ease( luxe.tween.easing.Cubic.easeInOut ).reflect().repeat();
	} //ready

	function lerpPolygon( poly1:Array<Float>, poly2:Array<Float>, t:Float ) {
		var poly3 = [];
		for (i in 0 ... poly1.length) {
			poly3.push( poly1[i] + ( ( poly2[i] - poly1[i] ) * t ) );
		}
		return poly3;
	}

	var globalDepthCounter = 0;
	function makePolygonVisual( poly:Polygon, color:RGBA ) {
		// geometry version -- failed why??
		// var bounds = getPolyBounds( polyTest );
		// var quad = quadFromBounds( bounds );
		// var pixels = pixelsFromBounds( bounds );
		// pixels = drawPolygonIntoBuffer( pixels, bounds, polyTest, 255, 0, 0, 255 );
		// var width = bounds.right - bounds.left;
		// var height = bounds.bottom - bounds.top;
		// quad.texture = textureFromPixels( width, height, pixels );

		// visual version -- TODO what is the difference between this and the geometry version???
		var bounds = getPolyBounds( poly );
		var width = bounds.right - bounds.left;
		var height = bounds.bottom - bounds.top;
		var visual = new Visual( { pos: new Vector(bounds.left, bounds.top), size: new Vector(width,height), color: new Color(1,1,1) } );
		
		//hack to stop z-fighting
		visual.depth = globalDepthCounter;
		globalDepthCounter++;
		
		// trace( visual.geometry.vertices );
		// var visual = new Visual( {no_geometry:true} );
		// visual.geometry = quadFromBounds( bounds );
		var pixels = pixelBufferFromBounds( bounds );
		// pixels = drawPolygonIntoPixelBuffer( pixels, bounds, poly, color.r, color.g, color.b, color.a );
		pixels = drawPolygonSpansIntoPixelBuffer( pixels, bounds, poly, color );
		visual.texture = textureFromPixelBuffer( width, height, pixels );

		// shared texture test
		// visual.texture = sharedTexture;

		return visual;
	}

	function updatePolygonVisual( visual:Visual, poly:Polygon, color:RGBA ) {
		var bounds = getPolyBounds( poly );
		var width = bounds.right - bounds.left;
		var height = bounds.bottom - bounds.top;

		// TODO - update geometry location and size
		visual.pos = new Vector(bounds.left, bounds.top);
		visual.size = new Vector(width, height);
		

		var pixels = pixelBufferFromBounds( bounds );
		// pixels = drawPolygonIntoPixelBuffer( pixels, bounds, poly, color.r, color.g, color.b, color.a );
		pixels = drawPolygonSpansIntoPixelBuffer( pixels, bounds, poly, color );
		visual.texture.invalidate();
		visual.texture = textureFromPixelBuffer( width, height, pixels );
		return visual;
	}

	function perturbPath(path:Polygon) {
		return path.map( function(f:Float) { return f + Luxe.utils.random.float(-10,10); });
	}

	function randomPath() {
		var poly = [];
		var center = new Vector( Luxe.utils.random.float(100,700), Luxe.utils.random.float(100,500) );
		var count = Luxe.utils.random.int(3,10);
		for (i in 0 ... count ) {
			var p = cast(i,Float) / count;
			var rad = p * 2 * 3.1415;
			var normal = new Vector( Math.cos(rad), Math.sin(rad) );
			var point = Vector.Add( center, Vector.Multiply( normal, Luxe.utils.random.float(30,80) ) );
			poly.push( point.x );
			poly.push( point.y );
		}
		// close the loop
		poly.push( poly[0] );
		poly.push( poly[1] );
		return poly;
	}

	function randomAnimatedPolygon() : AnimatedPolygon {
		var frame0 = randomPath();
		var frame1 = perturbPath( frame0 );
		return {
			frame0: frame0,
			frame1: frame1,
			color: {r:Luxe.utils.random.int(100,255),g:Luxe.utils.random.int(100,255),b:Luxe.utils.random.int(100,255),a:255}
		};
	}

	function makeRandomPoly() {
		return makePolygonVisual( randomPath(), {r:Luxe.utils.random.int(100,255),g:Luxe.utils.random.int(100,255),b:Luxe.utils.random.int(100,255),a:255} );
	}

	override function onmousedown( e:MouseEvent ) {
		for (i in 0 ... polyVisuals.length) {
			var p = makeRandomPoly();
			p.geometry.locked = false;
			polyVisuals.push( p );
		}
		// for (i in 0 ... animatedPolyData.length) {
		// 	animatedPolyData.push( randomAnimatedPolygon() );
		// }
	}

	override function onkeydown( e:KeyEvent ) {

		// pan
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

		// zoom
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
				text: "fps " + fps + "\n" + "static-poly " + polyVisuals.length + "\n" + "anim-poly " + animatedPolyData.length,
				immediate: true,
				depth: 2000
			});
	}

	override function update(dt:Float) {

		// destroy and recreate the polygon every frame (probs bad --- actually this is ok if the polygon rendering itself is fast enough)
		// polyTestVisual.destroy();
		// polyTestVisual = makePolygonVisual( lerpPolygon( polyTest, polyTest2, lerp.factor ), {r:255,g:0,b:0,a:255} );

		// updatePolygonVisual( polyTestVisual, lerpPolygon( polyTest, polyTest2, lerp.factor ), {r:255,g:0,b:0,a:255} );

		// multiple poly test
		for (i in 0 ... animatedPolyVisual.length) {
			animatedPolyVisual[i].destroy();
		}
		animatedPolyVisual = [];
		for (a in animatedPolyData) {
			animatedPolyVisual.push( makePolygonVisual( lerpPolygon( a.frame0, a.frame1, lerp.factor ), a.color ) );
		}

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

	function pixelBufferFromBounds(b:Bounds) {
		var width = b.right - b.left;
		var height = b.bottom - b.top;
		return new PixelBuffer( width * height * 4 );
	}

	// TODO - optimize with span rendering
	function drawPolygonIntoPixelBuffer( pixels:PixelBuffer, bounds:Bounds, polygon:Polygon, r:Int, g:Int, b:Int, a:Int ) {
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
				}
				else { // necessary?
					if (x % 2 == 0) debugStr += ".";
					// trace( x + ", " + y );
					pixels.buffer[ pixelStartIndex + 0 ] = cast 0;
					pixels.buffer[ pixelStartIndex + 1 ] = cast 0;
					pixels.buffer[ pixelStartIndex + 2 ] = cast 0;
					pixels.buffer[ pixelStartIndex + 3 ] = cast 0;
				}

			}
			// trace( debugStr );
		}
		return pixels;
	}

	function drawPolygonSpansIntoPixelBuffer( pixels:PixelBuffer, bounds:Bounds, polygon:Polygon, color:RGBA ) {
		var width = bounds.right - bounds.left;
		for ( y in bounds.top ... bounds.bottom ) {
			var spans = spansInScanline( y, polygon );
			for (s in spans) {
				setSpan( pixels, width, bounds.left, bounds.top, y, s, color ); //awkward function signature if you ask me
			}
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

	function textureFromPixelBuffer( width:Int, height:Int, pixels:PixelBuffer ) {
		return new Texture({ id:"tex" + Luxe.utils.uniqueid(), width: width, height: height, pixels: pixels, filter_min: FilterType.nearest, filter_mag: FilterType.nearest });
	}

	function spansInScanline( scanY:Int, polygon:Array<Float> ) {

		var hits : Array<Int> = [];

		var cy = scanY + 0.5;

		var i = 0;
		while (i+3 < polygon.length) { 
			var ax = polygon[i+0]; //todo need a point abstraction don't I
			var ay = polygon[i+1];
			var bx = polygon[i+2];
			var by = polygon[i+3];

			var yDeltaAlongLine = (cy - ay) / (by - ay);
			var closestXPositionOnLine = ax + ( (bx - ax) * yDeltaAlongLine );
			var isInYRange = yDeltaAlongLine >= 0 && yDeltaAlongLine <= 1;

			if (isInYRange)
				hits.push( Math.floor(closestXPositionOnLine) );

			i += 2;
		}

		hits.sort(function(a, b):Int {
		  if (a < b) return -1;
		  else if (a > b) return 1;
		  return 0;
		});

		var spans = [];
		var j = 0;
		while ((j+1) < hits.length) {
			spans.push({
					start: hits[j],
					end: hits[j+1]
				});
			j += 2;
		}

		return spans;
	}


	function setSpan( pixels:PixelBuffer, texWidth:Int, texX:Int, texY:Int, y:Int, span:{start:Int,end:Int}, color:RGBA ) {
		var pixelSize = 4;
		var rowSize = texWidth * pixelSize; // todo: I'll worry about efficiency later
		var pixelStartIndex = ((y-texY)*rowSize) + ( (span.start-texX) *pixelSize);

		var pixelBuf = new ArrayBuffer( pixelSize );
		pixelBuf[0] = cast color.r;
		pixelBuf[1] = cast color.g;
		pixelBuf[2] = cast color.b;
		pixelBuf[3] = cast color.a;

		var spanLen = (span.end - span.start);
		var spanByteLen = spanLen * pixelSize * 1;
		var buf = new ArrayBuffer( spanByteLen );

		var i = 0;
		while (i < spanByteLen) {
			// buf[i+0] = cast r;
			// buf[i+1] = cast g;
			// buf[i+2] = cast b;`
			// buf[i+3] = cast a;
			buf.blit(i,pixelBuf,0,4); //yup that's a little bit faster
			i += pixelSize;
		}
		pixels.buffer.blit( pixelStartIndex, buf, 0, spanByteLen );

		// var data : Array<Float> = [];
		// for (x in span.start ... span.end) {
		// 	data = data.concat( [r,g,b,a] );
		// }
		// //trace(data);
		// renderPixels.set( data, pixelStartIndex );
	}

} //Main
