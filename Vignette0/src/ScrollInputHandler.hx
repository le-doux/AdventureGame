import luxe.Input;
import luxe.Vector;

class ScrollInputHandler extends luxe.Entity {

	var prevTouchPos : Vector;
	var prevTouchTime : Float;

	var velocitySamples = [];
	var samplesMin = 5;
	var samplesMax = 20;

	public var touchDelta : Vector;
	public var releaseVelocity : Vector;

	override function onmousedown( e:MouseEvent ) {
		velocitySamples = [];

		for (i in  0 ... 5) { //this avoids sudden stops caused by not having enough samples (but it does "deaden" fast flicks... what's the solution?)
			velocitySamples.push(new Vector(0,0));
		}

		prevTouchPos = e.pos;
		prevTouchTime = e.timestamp;
	}

	override function onmousemove( e:MouseEvent ) {
	}

	override function onmouseup( e:MouseEvent ) {
		trace(velocitySamples);

		if (velocitySamples.length > samplesMin) {
			
			//normal calculations
			var avgVelocity = new Vector(0, 0);
			for (s in velocitySamples) {
				avgVelocity.add(s);
			}
			avgVelocity.divideScalar(velocitySamples.length);

			releaseVelocity = avgVelocity;

			//hack for sudden stops
			var isSuddenStop = true;
			for (i in 0 ... 5) {
				if ( Math.abs(velocitySamples[i].x) > 0.1 ) {
					isSuddenStop = false;
				}
			}

			if (isSuddenStop) {
				trace("sudden stop!");
				releaseVelocity = new Vector(0,0);
			}
			
		}
		else {
			trace("not enough samples!");
			releaseVelocity = new Vector(0,0);
		}

		trace(releaseVelocity);
	}

	override function update(dt:Float) {
		if (Luxe.input.mousedown(1)) {
			touchDelta = Vector.Subtract( prevTouchPos, Luxe.screen.cursor.pos );

			var sample = Vector.Divide( touchDelta, dt );
			velocitySamples.insert(0,sample);

			if (velocitySamples.length > samplesMax) velocitySamples.pop();

			prevTouchPos = Luxe.screen.cursor.pos;
		}
	} //update
}