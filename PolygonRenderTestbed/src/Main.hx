
import luxe.Input;

import luxe.Visual;
import phoenix.geometry.Geometry;
import luxe.Vector;
import luxe.GameConfig;
import phoenix.Batcher; // for PrimitiveType

import vexlib.VexTools;

// TODO
// - fps slowly dropping over time? some kind of leak of geometry?

class Main extends luxe.Game {

	// var testVisual : Visual;

	// test quad
	// var path0 = [ new Vector(300,200), new Vector(400,300), new Vector(500,200), new Vector(400,220) ];
	// var path1 = [ new Vector(300,200), new Vector(400,400), new Vector(500,200), new Vector(400,100) ];

	var visuals : Array<Visual> = [];

	// test quad centered
	var path0 = [ new Vector(-100,0), new Vector(0,100), new Vector(100,0), new Vector(0,20) ];
	var path1 = [ new Vector(-150,0), new Vector(0,200), new Vector(150,0), new Vector(0,-100) ];

	var lerp = {
		factor : 0.0
	};

	override function config(config:GameConfig) {

		config.window.width = 800;
		config.window.height = 600;

		return config;
	}

    override function ready() {

    	// testVisual = new Visual({
    	// 		pos: new Vector(200,200)
    	// 	});

    	// testVisual.geometry = new Geometry({
					// 	primitive_type: PrimitiveType.triangles,
					// 	batcher: Luxe.renderer.batcher
					// });

    	// var mesh = VexTools.pathToMesh( path0 );
    	// testVisual.geometry = VexTools.addTrianglesToGeometry( testVisual.geometry, mesh );

    	for (i in 0 ... 5) {
    		visuals.push( randomVisual() );
    	}

		luxe.tween.Actuate.tween( lerp, 1.0, {factor:1.0} ).ease( luxe.tween.easing.Cubic.easeInOut ).reflect().repeat();
    } //ready

    function randomVisual() {
    	var testVisual = new Visual({
	   			pos: new Vector( Luxe.utils.random.float(100,700), Luxe.utils.random.float(100,500) ),
	   			scale: new Vector( Luxe.utils.random.float(0.1,1.2), Luxe.utils.random.float(0.1,1.2) )
    		});

    	testVisual.geometry = new Geometry({
						primitive_type: PrimitiveType.triangles,
						batcher: Luxe.renderer.batcher
					});

    	var mesh = VexTools.pathToMesh( path0 );
    	testVisual.geometry = VexTools.addTrianglesToGeometry( testVisual.geometry, mesh );

    	testVisual.color = new luxe.Color( Luxe.utils.random.float(0,1), Luxe.utils.random.float(0,1), Luxe.utils.random.float(0,1) );

    	return testVisual;
    }

    override function onkeyup( e:KeyEvent ) {

        if(e.keycode == Key.escape) {
            Luxe.shutdown();
        }

        if (e.keycode == Key.space) { //double the number of visuals
        	var curCount = visuals.length;
        	for (i in 0 ... curCount) {
        		visuals.push( randomVisual() );
        	}
        }

        if (e.keycode == Key.up) {
        	Luxe.camera.zoom += 0.1;
        }
        else if (e.keycode == Key.down) {
        	Luxe.camera.zoom -= 0.1;
        }

    } //onkeyup

    //fps tracking
    var fps = 60.0;
    var fpsSamples = [];
    var fpsSampleTime = 0.0;

    override function update(dt:Float) {
    	// var curPath = lerpPath( path0, path1, lerp.factor );
    	// testVisual.geometry.vertices = []; //clear vertices
    	// var mesh = VexTools.pathToMesh( curPath ); //get new mesh
    	// testVisual.geometry = VexTools.addTrianglesToGeometry( testVisual.geometry, mesh );

    	for (v in visuals) {
	    	var curPath = lerpPath( path0, path1, lerp.factor );
	    	v.geometry.vertices = []; //clear vertices
	    	var mesh = VexTools.pathToMesh( curPath ); //get new mesh
	    	v.geometry = VexTools.addTrianglesToGeometry( v.geometry, mesh );
	    	v.color = v.color; // recolor all the vertices with this hack
    	}

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
				text: "fps " + fps + "\n" + "polys " + visuals.length,
				immediate: true
			});
    } //update


    // todo add to VexTools?
    function lerpPath( pathA:Array<Vector>, pathB:Array<Vector>, t:Float ) {
    	var pathC = [];
    	for (i in 0 ... pathA.length) {
    		var pA = pathA[i];
    		var pB = pathB[i];
    		var vAB = Vector.Subtract( pB, pA );
    		var pC = Vector.Add( pA, Vector.Multiply( vAB, t ) );
    		pathC.push( pC );
    	}
    	return pathC;
    }


} //Main
