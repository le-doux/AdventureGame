
import luxe.Input;
import luxe.Vector;
import luxe.utils.Maths;
import luxe.Color;

/*
TODO
- how to handle points that should really be on the same grid spot? snapping?
- test drawing now --- how hard is it? what can I make?
	- everything looks distorted because font isn't square
	- hard to correct mistake because everythign is ordered (even separate paths)
		- not end of the world to redraw everything for simple objects with only a few points
	- 16x16 is more than enough for a simple teapot, but what about people? how big are these grids going to be?
		- teapot handle is almost unreadable in ascii
	- final teapot result looks pretty good, but required back & forth with viewer
	- I'm not running out of points (yet)
	- definite charm to the ascii graphics
	- my first dude looks pretty shit
	- noodles / lines will help a lot I think
	- how will the teapot look next to the dude when resized appropriately
- most important ways this could be improved: easier to change, more detail, easier to read
- curves might help "smooth the rough edges" haha
*/

/* LIMB data */
typedef Joint = {
	public var pos : Vector;
	public var w : Float;
}

/* FIGURE data */
typedef FigureGridPoint = { //todo simplify name
	public var id : String;
	public var x : Int;
	public var y : Int;
}

class Main extends luxe.Game {

	/* LIMB variables*/
	var limbPoints : Array<Joint> = [];
	var defaultLimbWidth = 20;
	var selectedJoint : Joint = null;
	var isWireframe = true;

	/* FIGURE variables */
	var figurePointIds = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
	var gridSize = 10; //space between points
	var isCurved = true;
	var curveDist : Float = 5;
	var curveSteps = 5;

	override function ready() {

		var teapot = 
"................
................
................
................
................
................
................
................
.......G........
................
....CH...IB.....
....P.........87
..ODQ......A9.56
.NR..........4..
.MS........3....
..LET......2....
....K...........
.....0...1......";

		drawFigure(teapot,20,0);

		var dude =
"...............
......9.A......
.....8...B.....
...............
.....7...C.....
......6.D......
.....15.E2.....
.K...J...G...H.
...............
...............
...............
...............
.....0M.P3.....
...............
...............
...............
...............
......N.Q......";

		drawFigure(dude,200,0);

		var player =
"...........I...........
..........J...H........
...........3.4.........
..........2.PD5........
........K..OBAEG.......
...........N..F........
........LM1.896........
...........R0S.........
..........W...T........
....r..q..p...l..m..n..
.......................
.........Y.....Z.......
.........V.....U.......
.......................
..........d...h........
.......................
........b.......a......
.......................
.......................
..........e...i........
.......................
.......................
.......................
..........f...j........
.......................";

		drawFigure(player,400,0);

	} //ready

	function drawFigure(str:String,xOff:Float,yOff:Float) {
		//get lines
		var lines : Array<String> = str.split("\n");

		//define figure dimensions
		var height = lines.length;
		var width = lines[0].length;

		//parse raw grid points
		var points : Array<FigureGridPoint> = [];
		for (y in 0 ... height) {
			var l = lines[y];
			for (x in 0 ... width) {
				var char = l.charAt(x);
				if ( figurePointIds.indexOf(char) != -1 ) {
					points.push( {id:char, x:x, y:y } );
				}
			}
		}
		trace(points);

		//sort grid points by ascii order
		points.sort(
			function(a:FigureGridPoint, b:FigureGridPoint):Int
				{
					if ( figurePointIds.indexOf(a.id) < figurePointIds.indexOf(b.id) ) return -1;
					if ( figurePointIds.indexOf(a.id) > figurePointIds.indexOf(b.id) ) return 1;
					return 0;
				} 
			);
		trace(points);

		//create grid paths
		var paths : Array<Array<FigureGridPoint>> = [ [points[0]] ];
		var i = 0;
		for (j in 1 ... points.length) {
			var p0 = points[j-1];
			var p1 = points[j-0];
			var idNum0 = figurePointIds.indexOf(p0.id);
			var idNum1 = figurePointIds.indexOf(p1.id);
			if (idNum1 - idNum0 > 1) {
				//new path
				paths.push( [p1] );
				i++;
			}
			else {
				//add to current path
				paths[i].push( p1 );
			}
		}
		trace(paths);

		//create world-space paths
		var worldSpacePaths : Array<Array<Vector>> = [];
		for (path in paths) {
			var worldPath = [];
			for (p in path) {
				worldPath.push( new Vector( (p.x * gridSize) + xOff, (p.y * gridSize) + yOff ) );
			}
			worldSpacePaths.push( worldPath );
		}
		trace(worldSpacePaths);

		if (isCurved) {
			//curve the paths using bezier curve algorithm
			var curvePaths : Array<Array<Vector>> = [];
			for (path in worldSpacePaths) {
				var curvedPath = [];
				for (i in 0 ... path.length) {
					var prevIndex = i-1;
					if (prevIndex == -1) prevIndex = path.length-1;
	
					var nextIndex = i+1;
					if (nextIndex >= path.length) nextIndex = 0;
	
					var towardsPrev = Vector.Subtract(path[prevIndex], path[i]).normalized;
					var towardsNext = Vector.Subtract(path[nextIndex], path[i]).normalized;
	
					var b = path[i];
					var a = Vector.Add( b, Vector.Multiply( towardsPrev, curveDist ));
					var c = Vector.Add( b, Vector.Multiply( towardsNext, curveDist ));
					
					//bezier algo
					var curveControlPoints = [a,b,c];
					for (j in 0 ... curveSteps) {
						var delta : Float = cast(j, Float) / cast((curveSteps-1),Float);
						var point = bezierCurveInterpolation( curveControlPoints, delta );
						curvedPath.push( point );
					}
				}
				curvePaths.push( curvedPath );
			}
			trace(curvePaths);
			worldSpacePaths = curvePaths;
		}

		//render paths //todo replace with real mesh algorithm
		for (path in worldSpacePaths) {
			//todo for now this is a wireframe
			Luxe.draw.poly({
					points:path,
					solid:false,
					close:true
				});
		}
	}

	//borrowed from stack overflow
	function bezierCurveInterpolation(p:Array<Vector>, t:Float) {
		var x = (1 - t) * (1 - t) * p[0].x + 2 * (1 - t) * t * p[1].x + t * t * p[2].x;
		var y = (1 - t) * (1 - t) * p[0].y + 2 * (1 - t) * t * p[1].y + t * t * p[2].y;
		return new Vector(x,y);
	}

	override function onkeydown( e:KeyEvent ) {
		if (selectedJoint != null){
			if (e.keycode == Key.minus) {
				selectedJoint.w--;
			}
			else if (e.keycode == Key.equals) {
				selectedJoint.w++;
			}
		}
	}

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function onmousedown( e:MouseEvent ) {
		//select joint
		selectedJoint = null;
		for (j in limbPoints) {
			if ( Vector.Subtract( j.pos, e.pos ).length <= (j.w/2) ) {
				selectedJoint = j;
			}
		}

		//add joint
		if (selectedJoint == null)
			limbPoints.push( {pos:e.pos.clone(), w:defaultLimbWidth} );
	}

	override function onmousemove( e:MouseEvent ) {
		if (selectedJoint != null && Luxe.input.mousedown(1)) {
			selectedJoint.pos.x = e.pos.x;
			selectedJoint.pos.y = e.pos.y;
		}
	}

	override function onmouseup( e:MouseEvent ) {
	}

	override function update(dt:Float) {
		/* DRAW LIMB */
		//draw joints
		for (j in limbPoints) {
			var selected = (j == selectedJoint);
			var p = j.pos;

			if (isWireframe) {	
				Luxe.draw.ring({
						x:p.x, y:p.y,
						r:(j.w/2),
						color: (selected ? new Color(1,1,0) : new Color(1,1,1)),
						immediate:true
					});
			}
			else {
				Luxe.draw.circle({
						x:p.x, y:p.y,
						r:(j.w/2),
						immediate:true,
						steps:8 //testing how limited steps look
					});
			}
		}
		//draw connections
		for (i in 0 ... (limbPoints.length-1)) {
			//get joints
			var j0 = limbPoints[i+0];
			var j1 = limbPoints[i+1];

			//get connector points
			var p0 = j0.pos;
			var p1 = j1.pos;

			//quad connector precalculations TODO: make line-to-quad a method
			var p0_to_p1 = Vector.Subtract(p1, p0);
			var unitForward = p0_to_p1.normalized;
			var radiansForward = unitForward.angle2D;
			var degreesForward = Maths.degrees(radiansForward);
			var degreesRight = degreesForward + 90;
			var radiansRight = Maths.radians(degreesRight);
			var unitRight = (new Vector(1,0));
			unitRight.angle2D = radiansRight;
			var rightward0 = Vector.Multiply(unitRight, j0.w/2);
			var leftward0 = Vector.Multiply(rightward0, -1);
			var rightward1 = Vector.Multiply(unitRight, j1.w/2);
			var leftward1 = Vector.Multiply(rightward1, -1);

			//quad points
			var a = Vector.Add( p0, leftward0 );
			var b = Vector.Add( p0, rightward0 );
			var c = Vector.Add( p1, rightward1 );
			var d = Vector.Add( p1, leftward1 );

			if (isWireframe) {
				//draw quad with lines
				Luxe.draw.line({p0:a, p1:b, immediate:true});
				Luxe.draw.line({p0:b, p1:c, immediate:true});
				Luxe.draw.line({p0:c, p1:d, immediate:true});
				Luxe.draw.line({p0:d, p1:a, immediate:true});

				//draw line connector
				Luxe.draw.line({p0:p0, p1:p1, immediate:true});
			}
			else {
				Luxe.draw.poly({
						points:[a,b,c,d],
						immediate:true
					});
			}
		}
	} //update


} //Main
