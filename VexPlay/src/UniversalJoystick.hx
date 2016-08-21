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
	public var maxScrollSpeed = 1200; //todo shouldn't be public really //TODO remove & replace
	var timeSinceMouseReleased = 0.0;
	var maxMouseReleaseTime = 0.1; // 1/10th of a second
	var deadzoneVector : Vector;
	var deadzoneSize = Main.Settings.IDEAL_SCREEN_SIZE_W * 0.02;

	override function onmousedown( e:MouseEvent ) {
		if (hasScrollingSamples() && timeSinceMouseReleased < maxMouseReleaseTime) {
			//do nothing --- scrolling was only temporarily interrupted
		}
		else {
			//start a new scrolling action
			velocitySamples = [];
			deadzoneVector = new Vector(0,0);

			for (i in  0 ... 5) { //this avoids sudden stops caused by not having enough samples (but it does "deaden" fast flicks... what's the solution?)
				velocitySamples.push(new Vector(0,0));
			}

			prevTouchPos = Main.Settings.RealScreenPosToStandardScreenPos(e.pos);
			prevTouchTime = e.timestamp;

			axis = new Vector(0,0);

			Luxe.events.fire("joystick.pressed", axis);
		}
	}

	override function onmousemove( e:MouseEvent ) {
	}

	override function onmouseup( e:MouseEvent ) {
		timeSinceMouseReleased = 0;
	}

	function scrollrelease() {
		trace("scroll release!!!");
		trace(velocitySamples);

		if (velocitySamples.length > samplesMin && deadzoneVector.length > deadzoneSize) {
			
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

		//lock axis
		if ( Math.abs(deadzoneVector.x) > Math.abs(deadzoneVector.y) ) {
			releaseVelocity.y = 0;
		}
		else {
			releaseVelocity.x = 0;
		}

		//TODO revisit maxScrollSpeed?
		axis.x = Maths.clamp(releaseVelocity.x, -maxScrollSpeed, maxScrollSpeed) / Main.Settings.IDEAL_SCREEN_SIZE_W;

		//TODO remove this nonsense below
		//sort of a hack to avoid dealing with velocity in the y axis
		axis.y = 0;

		velocitySamples = []; //purge samples after successful release

		Luxe.events.fire("joystick.released", axis);

		axis = new Vector(0,0); //clear axis after release
	}

	//todo name?
	function hasScrollingSamples() {
		return velocitySamples.length > 0;
	}

	/* KEYBOARD INPUT */
	var maxKeyboardSpeed = 0.8;
	var keyboardAcceleration = 0.6;
	var keyboardUpSpeed = 0.5;
	var areKeysAlreadyHeld = false;

	override function onkeydown( e:KeyEvent ) {

		if (e.keycode == Key.right || e.keycode == Key.key_d || 
			e.keycode == Key.left || e.keycode == Key.key_a || 
			e.keycode == Key.up || e.keycode == Key.key_w ||
			e.keycode == Key.down || e.keycode == Key.key_s)
		{
			if ( !areKeysAlreadyHeld ) {
				areKeysAlreadyHeld = true;
				axis = new Vector(0,0);
				Luxe.events.fire("joystick.pressed", axis);
			}
		}

	}

	override function onkeyup( e:KeyEvent ) {

		if (e.keycode == Key.right || e.keycode == Key.key_d || 
			e.keycode == Key.left || e.keycode == Key.key_a) 
		{
			areKeysAlreadyHeld = false;
			Luxe.events.fire("joystick.released", axis);

			axis = new Vector(0,0); //clear axis after release
		}

		if (e.keycode == Key.up || e.keycode == Key.key_w ||
			e.keycode == Key.down || e.keycode == Key.key_s)
		{
			areKeysAlreadyHeld = false;
			Luxe.events.fire("joystick.released", axis);

			axis = new Vector(0,0); //clear axis after release
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

			
			if (deadzoneVector.length < deadzoneSize) {
				//build up deadzone value
				deadzoneVector.add( Vector.Multiply( avgVelocity, dt ) );
				//axis = new Vector(0,0); //I don't think this will actually be necessary
			}
			else {
				//out of deadzone, so we can actually set the axis
				if ( Math.abs(deadzoneVector.x) > Math.abs(deadzoneVector.y) ) {
					axis.x = avgVelocity.divide( Main.Settings.IdealScreenSize() ).x;
					axis.y = 0; //only move in one axis at a time
				}
				else {
					axis.x = 0;
					axis.y = avgVelocity.divide( Main.Settings.IdealScreenSize() ).y;
				}
			}

			
		}
		else if ( hasScrollingSamples() ) {
			timeSinceMouseReleased += dt;

			//deadzone calculations: redundant?
			if (deadzoneVector.length < deadzoneSize) {
				var avgVelocity = new Vector(0, 0);
				for (s in velocitySamples) {
					avgVelocity.add(s);
				}
				avgVelocity.divideScalar(velocitySamples.length);
				deadzoneVector.add( Vector.Multiply( avgVelocity, dt ) );
			}

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

		//trace(axis);
	}

	function isScrollOngoing() {
		return ( Luxe.input.mousedown(1) ) || ( hasScrollingSamples() && timeSinceMouseReleased < maxMouseReleaseTime );
	}

	//is this really the best approach? ... probably not (but I'll do it "for now")
	public function yAxisHeld() {
		return isScrollOngoing() || 
				Luxe.input.keydown(Key.up) || Luxe.input.keydown(Key.key_w) ||
				Luxe.input.keydown(Key.down) || Luxe.input.keydown(Key.key_s);
	}

	public function xAxisHeld() {
		return isScrollOngoing() || 
				Luxe.input.keydown(Key.right) || Luxe.input.keydown(Key.key_d) ||
				Luxe.input.keydown(Key.left) || Luxe.input.keydown(Key.key_a);
	}

	public function isDown() {
		return yAxisHeld() || xAxisHeld();
	}

}