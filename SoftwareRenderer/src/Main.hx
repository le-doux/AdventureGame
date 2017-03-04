
import luxe.Input;
import luxe.GameConfig;

import luxe.Visual;
import phoenix.Texture;
import phoenix.Texture.FilterType;
import luxe.Vector;
import luxe.Color;
import snow.api.buffers.Uint8Array;
import snow.api.buffers.ArrayBufferView;
import snow.api.buffers.ArrayBuffer;
import snow.api.buffers.TypedArrayType;

using cpp.NativeArray;

typedef Polygon = Array<Float>;
typedef RGBA = {
	public var r : Int; 
	public var g : Int; 
	public var b : Int; 
	public var a : Int;
};

/*
areas for optimization:
- blitting
- avoiding redrawing uneccessary pixels
- span calculation

questions
- how does it run on iOS?
- how many polygons do I need?
- how much redrawing do I need?
- can it even be fast enough in principle?
- how will zoom and pan impact perf? (force redraw everything?)
- what level of resolution degradation am I willing to have?

issues:
- memory leak of some kind (creating and destroying texture???)
*/

class Main extends luxe.Game {

	//texture
	var texWidth = 800;
	var texHeight = 600;
	//window
	var winWidth = 800;
	var winHeight = 600;

	var renderVisual : Visual;
	var renderTexture : Texture; //currently every texture is temporary
	var renderPixels : Uint8Array;

	//test
	// var clearData : Array<Float> = [];
	// var clearView : ArrayBufferView;
	var clearBuf : ArrayBuffer;

	override function config(config:GameConfig) {

		config.window.width = winWidth;
		config.window.height = winHeight;

		return config;
	}


	var polygons : Array<Polygon> = [];
	var polygonsAnim : Array<Polygon> = [];
	var polyColors : Array<RGBA> = [];


	override function ready() {

		renderPixels = new Uint8Array( texWidth * texHeight * 4 );

		renderTexture = new Texture({ id:"renderTexture", width: texWidth, height: texHeight, pixels: renderPixels, filter_min: FilterType.nearest, filter_mag: FilterType.nearest });

		renderVisual = new Visual({ size: new Vector(winWidth,winHeight) });
		renderVisual.texture = renderTexture;

		luxe.tween.Actuate.tween( lerp, 1.0, {factor:1.0} ).ease( luxe.tween.easing.Cubic.easeInOut ).reflect().repeat();

		// for ( i in 0 ... texWidth * texHeight * 4 ) clearData.push(0);

		var bLen = texWidth * texHeight * 4 * 1;
		clearBuf = new ArrayBuffer( bLen ); // 1 byte per element
		var i = 0;
		while (i < bLen)
		{
			clearBuf[i] = cast 100;
			i++;
		}

		for (i in 0 ... 4) {
			addRandomPoly();
		}

	} //ready

	function addRandomPoly() {
		var poly = [];
		var polyAnim = [];
		var center = new Vector( Luxe.utils.random.float(100,700), Luxe.utils.random.float(100,500) );
		var count = Luxe.utils.random.int(3,10);
		for (i in 0 ... count ) {
			var p = cast(i,Float) / count;
			var rad = p * 2 * 3.1415;
			var normal = new Vector( Math.cos(rad), Math.sin(rad) );
			var point = Vector.Add( center, Vector.Multiply( normal, Luxe.utils.random.float(30,80) ) );
			poly.push( point.x );
			poly.push( point.y );
			polyAnim.push( point.x + Luxe.utils.random.float(-10,10) );
			polyAnim.push( point.y + Luxe.utils.random.float(-10,10) );
		}
		// close the loop
		poly.push( poly[0] );
		poly.push( poly[1] );
		polyAnim.push( poly[0] );
		polyAnim.push( poly[1] );

		polygons.push( poly );
		polygonsAnim.push( polyAnim );
		polyColors.push( {r:Luxe.utils.random.int(100,255),g:Luxe.utils.random.int(100,255),b:Luxe.utils.random.int(100,255),a:255} );
	}

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

		if (e.keycode == Key.space) {
			for (i in 0 ... polygons.length) {
				addRandomPoly();
			}
		}

	} //onkeyup

	override function onmousedown(e:MouseEvent) {
		for (i in 0 ... polygons.length) {
			addRandomPoly();
		}
	}

	// var polyTest : Array<Float> = [ 400,200, 500,300, 300,300, 400,270, 400,200 ];
	// var polyTest2 : Array<Float> = [ 400,100, 300,260, 300,400, 200,250, 400,100 ];

	var polyTest : Array<Float> = [ 400,0, 800,600, 0,600, 400,0 ];
	var polyTest2 : Array<Float> = [ 400,20, 780,580, 100,500, 400,20 ];
	
	var lerp = {
		factor : 0.0
	};

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
				text: "fps " + fps + "\n" + "polys " + polygons.length,
				immediate: true
			});
	}

	override function update(dt:Float) {
		// set a random pixel every frame
		// setPixel( Luxe.utils.random.int(0,800), // x
		// 		  Luxe.utils.random.int(0,600), // y
		// 		  Luxe.utils.random.int(0,255), // r
		// 		  Luxe.utils.random.int(0,255), // g
		// 		  Luxe.utils.random.int(0,255), // b
		// 		  255							// a
		// 		);

		//trace(lerp.factor);
		// var curPoly = lerpPolygon(polyTest,polyTest2,lerp.factor);
		// var polyBounds = getPolyBounds(curPoly);

		// clear window - slow
		// for (x in 0 ... winWidth) {
		// 	for (y in 0 ... winHeight) {
		// 		setPixel( x, y, 0, 0, 0, 0 );
		// 	}
		// }

		// renderPixels = new Uint8Array( texWidth * texHeight * 4 ); //clear pixels - faster

		// save blit for later
		var bLen = texWidth * texHeight * 4 * 1;
		// var b = new ArrayBuffer( bLen ); // 1 byte per element
		renderPixels.buffer.blit(0,clearBuf,0,bLen);

		// clear attempt 3 (blitting?) -- abysmally slow --
		// var clearData : Array<Float> = [];
		// for (i in 0 ... texWidth * texHeight * 4) {
		// 	clearData.push( 0 );
		// }
		// renderPixels.set( clearData );


		// draw poly - per pixel version
		// for (x in polyBounds.minX ... polyBounds.maxX) {
		// 	for (y in polyBounds.minY ... polyBounds.maxY) {
		// 		if ( isPixelInPoly(x,y,curPoly) ) { //*4 hack to speed things up
		// 			setPixel( x, y, 255, 0, 0, 255 );
		// 		}
		// 		else {
		// 			setPixel( x, y, 0, 0, 255, 255 );
		// 		}
		// 	}
		// }

		// draw poly - span version
		//var r = Luxe.utils.random.int(200,255);
		// for (y in polyBounds.minY ... polyBounds.maxY) {
		// 	var spans = spansInScanline( y, curPoly );
		// 	for (s in spans) {
		// 		// for (x in s.start ... s.end) {
		// 		// 	setPixel( x, y, 255, 0, 0, 255 );
		// 		// }
		// 		// --- attempt at blit is actually slower ? ---
		// 		setSpan( s, y, 255, 0, 0, 255 );
		// 	}
		// }


		/* ----- THE LATEST ------ */

		// var curPoly = lerpPolygon(polyTest,polyTest2,lerp.factor);
		// var polyBounds = getPolyBounds(curPoly);
		// drawPolygon( curPoly, 255,0,0,255 );

		for (i in 0 ... polygons.length) {
			var curPoly = lerpPolygon( polygons[i], polygonsAnim[i], lerp.factor );
			drawPolygon( curPoly, polyColors[i].r,polyColors[i].g,polyColors[i].b,polyColors[i].a );
		}

		updateTexture();


		trackFps(dt);

	} //update

	function drawPolygon( poly:Polygon, r:Int, g:Int, b:Int, a:Int ) {
		var polyBounds = getPolyBounds( poly );
		for (y in polyBounds.minY ... polyBounds.maxY) {
			var spans = spansInScanline( y, poly );
			for (s in spans) {
				setSpan( s, y, r, g, b, a );
			}
		}
	}

	function lerpPolygon( poly1:Array<Float>, poly2:Array<Float>, t:Float ) {
		var poly3 = [];
		for (i in 0 ... poly1.length) {
			poly3.push( poly1[i] + ( ( poly2[i] - poly1[i] ) * t ) );
		}
		return poly3;
	}

	function getPolyBounds( polygon:Array<Float> ) {
		var minX = polygon[0];
		var maxX = polygon[0];
		var minY = polygon[1];
		var maxY = polygon[1];

		var i = 0;
		while (i < polygon.length) {
			var x = polygon[i+0];
			var y = polygon[i+1];

			minX = Math.min( minX, x );
			maxX = Math.max( maxX, x );

			minY = Math.min( minY, y );
			maxY = Math.max( maxY, y );

			i += 2;
		}

		return {
			minX:Math.floor(minX), maxX:Math.floor(maxX),
			minY:Math.floor(minY), maxY:Math.floor(maxY)
		};
	}

	function isPixelInPoly( x:Int, y:Int, polygon:Array<Float> ) {

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

	function setPixel( x:Int, y:Int, r:Int, g:Int, b:Int, a:Int ) {
		// set a single pixel's color
		var pixelSize = 4;
		var rowSize = texWidth * pixelSize; // todo: I'll worry about efficiency later
		var redOffset = 0;
		var greenOffset = 1;
		var blueOffset = 2;
		var alphaOffset = 3;
		var pixelStartIndex = (y*rowSize) + (x*pixelSize);
		renderPixels.buffer[ pixelStartIndex + redOffset ] = cast( r );   // r
		renderPixels.buffer[ pixelStartIndex + blueOffset ] = cast( g );  // g
		renderPixels.buffer[ pixelStartIndex + greenOffset ] = cast( b ); // b
		renderPixels.buffer[ pixelStartIndex + alphaOffset ] = cast( a ); // a
	}

	function setSpan( span:{start:Int,end:Int}, y:Int, r:Int, g:Int, b:Int, a:Int ) {
		var pixelSize = 4;
		var rowSize = texWidth * pixelSize; // todo: I'll worry about efficiency later
		var pixelStartIndex = (y*rowSize) + (span.start*pixelSize);

		var pixelBuf = new ArrayBuffer( pixelSize );
		pixelBuf[0] = cast r;
		pixelBuf[1] = cast g;
		pixelBuf[2] = cast b;
		pixelBuf[3] = cast a;

		var spanLen = (span.end - span.start);
		var spanByteLen = spanLen * pixelSize * 1;
		var buf = new ArrayBuffer( spanByteLen );

		var i = 0;
		while (i < spanByteLen) {
			// buf[i+0] = cast r;
			// buf[i+1] = cast g;
			// buf[i+2] = cast b;
			// buf[i+3] = cast a;
			buf.blit(i,pixelBuf,0,4); //yup that's a little bit faster
			i += pixelSize;
		}
		renderPixels.buffer.blit( pixelStartIndex, buf, 0, spanByteLen );

		// var data : Array<Float> = [];
		// for (x in span.start ... span.end) {
		// 	data = data.concat( [r,g,b,a] );
		// }
		// //trace(data);
		// renderPixels.set( data, pixelStartIndex );
	}

	function updateTexture() {
		// todo: is it really a good idea to create and discard a new texture every frame?
		renderTexture.invalidate();
		renderTexture = new Texture({ id:"renderTexture", width: texWidth, height: texHeight, pixels: renderPixels, filter_min: FilterType.nearest, filter_mag: FilterType.nearest });
		renderVisual.texture = renderTexture;

	}

} //Main
