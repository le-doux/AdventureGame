import luxe.Vector;
import luxe.Input;
import luxe.tween.Actuate;
import luxe.utils.Maths;

/*
	TODO
	- handle possibility of multiple input types simultaneously
	- refactor mouse input
	- get rid of reliance on Actuate
	- question: should coasting really happen in here??? or does that belong to the player?
*/

class UniversalJoystick extends luxe.Entity {
	
	public var axis : Vector = new Vector(0,0);

	//todo replace with touch input?
	/* MOUSE INPUT */
	var prevTouchPos : Vector;
	var prevTouchTime : Float;
	var velocitySamples = [];
	var samplesMin = 5;
	var samplesMax = 20;
	var touchDelta : Vector;
	var releaseVelocity : Vector;
	public var maxScrollSpeed = 1200; //todo shouldn't be public really
	var scrollCoastTime = 0.75;
	var isCoasting = false;

	override function onmousedown( e:MouseEvent ) {
		velocitySamples = [];

		for (i in  0 ... 5) { //this avoids sudden stops caused by not having enough samples (but it does "deaden" fast flicks... what's the solution?)
			velocitySamples.push(new Vector(0,0));
		}

		/* CHANGE TO STANDARD SCREEN */
		//prevTouchPos = e.pos;
		prevTouchPos = Main.Settings.RealScreenPosToStandardScreenPos(e.pos);
		/* CHANGE TO STANDARD SCREEN */
		prevTouchTime = e.timestamp;

		if (isCoasting) {
			isCoasting = false;
			Actuate.stop(axis);
		}

		axis = new Vector(0,0);
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

		/* CHANGE TO STANDARD SCREEN */
		//axis.x = Maths.clamp(releaseVelocity.x, -maxScrollSpeed, maxScrollSpeed) / Luxe.screen.w;
		//TODO revisit maxScrollSpeed?
		axis.x = Maths.clamp(releaseVelocity.x, -maxScrollSpeed, maxScrollSpeed) / Main.Settings.IDEAL_SCREEN_SIZE_W;
		/* CHANGE TO STANDARD SCREEN */
		isCoasting = true;
		Actuate.tween(axis, scrollCoastTime, {x:0}).ease(luxe.tween.easing.Quad.easeOut)
			.onComplete(function() { 
							axis.x = 0;
							isCoasting = false; 
						});


		//sort of a hack
		axis.y = 0;
	}

	/* KEYBOARD INPUT */
	var maxKeyboardSpeed = 0.5;
	var keyboardAcceleration = 0.3;
	var keyboardUpSpeed = 0.3;

	override function onkeydown( e:KeyEvent ) {
		if (e.keycode == Key.right || e.keycode == Key.key_d || 
			e.keycode == Key.left || e.keycode == Key.key_a) 
		{
			if (isCoasting) {
				isCoasting = false;
				Actuate.stop(axis);
			}
		}
	}

	override function onkeyup( e:KeyEvent ) {
		if (e.keycode == Key.right || e.keycode == Key.key_d || 
			e.keycode == Key.left || e.keycode == Key.key_a) 
		{
			//let go and coast (same coast time?)
			isCoasting = true;
			Actuate.tween(axis, scrollCoastTime, {x:0}).ease(luxe.tween.easing.Quad.easeOut)
				.onComplete(function() { 
								axis.x = 0;
								isCoasting = false; 
							});
		}

		if (e.keycode == Key.up || e.keycode == Key.key_w ||
			e.keycode == Key.down || e.keycode == Key.key_s)
		{
			axis.y = 0;
		}
	}

	//todo scroll input?

	//todo gamepad input?

	override function update(dt:Float) {
		/* MOUSE */
		if (Luxe.input.mousedown(1)) {
			/* CHANGE TO STANDARD SCREEN */
			//touchDelta = Vector.Subtract( prevTouchPos, Luxe.screen.cursor.pos );
			var cursorPosStd = Main.Settings.RealScreenPosToStandardScreenPos( Luxe.screen.cursor.pos );
			touchDelta = Vector.Subtract( prevTouchPos, cursorPosStd );
			/* CHANGE TO STANDARD SCREEN */

			var sample = Vector.Divide( touchDelta, dt );
			velocitySamples.insert(0,sample);

			if (velocitySamples.length > samplesMax) velocitySamples.pop();

			/* CHANGE TO STANDARD SCREEN */
			//prevTouchPos = Luxe.screen.cursor.pos;
			prevTouchPos = cursorPosStd;
			/* CHANGE TO STANDARD SCREEN */

			/* CHANGE TO STANDARD SCREEN */
			//axis = touchDelta.divide( Luxe.screen.size ).divideScalar( dt );
			axis = touchDelta.divide( Main.Settings.IdealScreenSize() ).divideScalar( dt );
			/* CHANGE TO STANDARD SCREEN */
		}

		/* KEYBOARD */
		if (Luxe.input.keydown(Key.right) || Luxe.input.keydown(Key.key_d)) {
			axis.x += keyboardAcceleration * dt;
			axis.x = Math.min(axis.x, maxKeyboardSpeed);
		}
		else if (Luxe.input.keydown(Key.left) || Luxe.input.keydown(Key.key_a)) {
			axis.x -= keyboardAcceleration * dt;
			axis.x = Math.max(axis.x, -maxKeyboardSpeed);
		}
		else if (Luxe.input.keydown(Key.up) || Luxe.input.keydown(Key.key_w)) {
			axis.y = keyboardUpSpeed;
		}
		else if (Luxe.input.keydown(Key.down) || Luxe.input.keydown(Key.key_s)) {
			axis.y = -keyboardUpSpeed;
		}
	}

	//is this really the best approach? ... probably not (but I'll do it "for now")
	public function yAxisHeld() {
		return Luxe.input.mousedown(1) || 
				Luxe.input.keydown(Key.up) || Luxe.input.keydown(Key.key_w) ||
				Luxe.input.keydown(Key.down) || Luxe.input.keydown(Key.key_s);
	}

	public function xAxisHeld() {
		return Luxe.input.mousedown(1) || 
				Luxe.input.keydown(Key.right) || Luxe.input.keydown(Key.key_d) ||
				Luxe.input.keydown(Key.left) || Luxe.input.keydown(Key.key_a);
	}

	//todo rename?
	public function stopCoasting() {
		isCoasting = false;
		Actuate.stop(axis);
	}

}