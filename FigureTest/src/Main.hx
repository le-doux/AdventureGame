
import luxe.Input;
import luxe.Vector;
import luxe.utils.Maths;
import luxe.Color;

typedef Joint = {
	public var pos : Vector;
	public var w : Float;
}

class Main extends luxe.Game {

	var limbPoints : Array<Joint> = [];
	var defaultLimbWidth = 20;
	var selectedJoint : Joint = null;
	var isWireframe = false;

    override function ready() {

    } //ready

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
	    				immediate:true
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
