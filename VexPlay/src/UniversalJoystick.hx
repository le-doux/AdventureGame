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
	var timeSinceMouseReleased = 0.0;
	var maxMouseReleaseTime = 0.1; // 1/10th of a second

	override function onmousedown( e:MouseEvent ) {
		if (hasScrollingSamples() && timeSinceMouseReleased < maxMouseReleaseTime) {
			//do nothing --- scrolling was only temporarily interrupted
		}
		else {
			//start a new scrolling action
			velocitySamples = [];

			for (i in  0 ... 5) { //this avoids sudden stops caused by not having enough samples (but it does "deaden" fast flicks... what's the solution?)
				velocitySamples.push(new Vector(0,0));
			}

			prevTouchPos = Main.Settings.RealScreenPosToStandardScreenPos(e.pos);
			prevTouchTime = e.timestamp;

			if (isCoasting) {
				isCoasting = false;
				Actuate.stop(axis);
			}

			axis = new Vector(0,0);
		}
	}

	override function onmousemove( e:MouseEvent ) {
	}

	override function onmouseup( e:MouseEvent ) {
		timeSinceMouseReleased = 0;
	}

	function scrollrelease() {
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

		//TODO revisit maxScrollSpeed?
		axis.x = Maths.clamp(releaseVelocity.x, -maxScrollSpeed, maxScrollSpeed) / Main.Settings.IDEAL_SCREEN_SIZE_W;
		isCoasting = true;
		Actuate.tween(axis, scrollCoastTime, {x:0}).ease(luxe.tween.easing.Quad.easeOut)
			.onComplete(function() { 
							axis.x = 0;
							isCoasting = false; 
						});


		//sort of a hack
		axis.y = 0;

		velocitySamples = []; //purge samples after successful release
	}

	//todo name?
	function hasScrollingSamples() {
		return velocitySamples.length > 0;
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
			var cursorPosStd = Main.Settings.RealScreenPosToStandardScreenPos( Luxe.screen.cursor.pos );
			touchDelta = Vector.Subtract( prevTouchPos, cursorPosStd );

			var sample = Vector.Divide( touchDelta, dt );
			velocitySamples.insert(0,sample);

			if (velocitySamples.length > samplesMax) velocitySamples.pop();

			prevTouchPos = cursorPosStd;

			//use average velocity to smooth things out
			var avgVelocity = new Vector(0, 0);
			for (s in velocitySamples) { //TODO can I make this average velocity feel snappier to respond?
				avgVelocity.add(s);
			}
			avgVelocity.divideScalar(velocitySamples.length);
			axis = avgVelocity.divide( Main.Settings.IdealScreenSize() );
		}
		else if ( hasScrollingSamples() ) {
			timeSinceMouseReleased += dt;
			if (timeSinceMouseReleased >= maxMouseReleaseTime) {
				scrollrelease();
			}
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