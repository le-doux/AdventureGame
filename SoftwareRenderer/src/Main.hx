
import luxe.Input;
import luxe.GameConfig;

import luxe.Visual;
import phoenix.Texture;
import phoenix.Texture.FilterType;
import luxe.Vector;
import luxe.Color;
import snow.api.buffers.Uint8Array;
import snow.api.buffers.ArrayBufferView;

class Main extends luxe.Game {

	//texture
	var texWidth = 800;
	var texHeight = 600;
	//window
	var winWidth = 800;
	var winHeight = 600;

	var renderVisual : Visual;
	//var renderTexture : Texture; //currently every texture is temporary
	var renderPixels : Uint8Array;

	override function config(config:GameConfig) {

		config.window.width = winWidth;
		config.window.height = winHeight;

		return config;
	}


	override function ready() {

		renderPixels = new Uint8Array( texWidth * texHeight * 4 );

		renderVisual = new Visual({ size: new Vector(winWidth,winHeight) });

		luxe.tween.Actuate.tween( lerp, 1.0, {factor:1.0} ).ease( luxe.tween.easing.Cubic.easeInOut ).reflect().repeat();

	} //ready

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	var polyTest : Array<Float> = [ 400,200, 500,300, 300,300, 400,270, 400,200 ];
	var polyTest2 : Array<Float> = [ 400,100, 300,260, 300,400, 200,250, 400,100 ];
	var lerp = {
		factor : 0.0
	};

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
		var curPoly = lerpPolygon(polyTest,polyTest2,lerp.factor);
		var polyBounds = getPolyBounds(curPoly);

		// clear window
		for (x in 0 ... winWidth) {
			for (y in 0 ... winHeight) {
				setPixel( x, y, 0, 0, 0, 0 );
			}
		}

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
		for (y in polyBounds.minY ... polyBounds.maxY) {
			var spans = spansInScanline( y, curPoly );
			for (s in spans) {
				for (x in s.start ... s.end) {
					setPixel( x, y, 255, 0, 0, 255 );
				}
			}
		}

		updateTexture();

	} //update

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

	function drawPolygon() {
		// todo
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

	function updateTexture() {
		// todo: is it really a good idea to create and discard a new texture every frame?
		renderVisual.texture = new Texture({ id:"renderTexture", width: texWidth, height: texHeight, pixels: renderPixels, filter_min: FilterType.nearest, filter_mag: FilterType.nearest });
	}

} //Main
