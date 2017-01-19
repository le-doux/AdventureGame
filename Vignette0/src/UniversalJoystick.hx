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

enum InputSource {
	Mouse;
	Keyboard;
	Touch;
	None;
}

class UniversalJoystick extends luxe.Entity {
	
	public var axis : Vector = new Vector(0,0);
	public var source : InputSource = InputSource.None;

	//todo replace with touch input?
	/* MOUSE INPUT */
	var prevTouchPos : Vector;
	var prevTouchTime : Float;
	var velocitySamples = [];
	//var samplesMin = 5;
	//var samplesMax = 20;
	var sampleCollectionFrameTime = 0.05; //20 times per second
	var samplesMin = 1;
	var samplesMax = 6;
	var touchDelta : Vector;
	var releaseVelocity : Vector;

	var timeSinceMouseReleased = 0.0;
	var maxMouseReleaseTime = 0.1; // 1/10th of a second

	var timeSinceMousePressed = 0.0;
	var isScrolling = false;
	
	var deadzoneVector : Vector;
	var deadzoneSize = Main.Settings.IDEAL_SCREEN_SIZE_W * 0.02;
	var minFastFlickSpeed = 100.0;

	override public function new(?opt) {
		super(opt);
		Luxe.timer.schedule(sampleCollectionFrameTime, track_scrolling_velocity, true);
	}

	//todo rename
	function scroll_joystick_down() {
		isScrolling = true;
		Luxe.events.fire("joystick.pressed", axis);
	}

	function track_scrolling_velocity() {
		/* MOUSE */
		var dt = sampleCollectionFrameTime;
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

			//allow suddent stops, despite deadzone logic
			timeSinceMousePressed += dt;
			if (timeSinceMousePressed >= 0.1 && Math.abs(avgVelocity.length) < 1 && !isScrolling) {
				axis = new Vector(0,0);
				scroll_joystick_down();
			}
			
			if (deadzoneVector.length < deadzoneSize) {
				//build up deadzone value
				deadzoneVector.add( Vector.Multiply( avgVelocity, dt ) );
				if (deadzoneVector.length >= deadzoneSize && !isScrolling) {
					//test -- joystick isn't "down" until we're out of the deadzone
					if ( isScrollingLockedToXAxis() ) {
						axis.x = avgVelocity.divide( Main.Settings.IdealScreenSize() ).x;
						axis.y = 0; //only move in one axis at a time
					}
					else {
						axis.x = 0;
						axis.y = avgVelocity.divide( Main.Settings.IdealScreenSize() ).y;
					}
					scroll_joystick_down();
					//test
				}
			}
			else {
				//out of deadzone, so we can actually set the axis
				if ( isScrollingLockedToXAxis() ) {
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
	}

	override function onmousedown( e:MouseEvent ) {
		source = InputSource.Mouse;

		if (hasScrollingSamples() && timeSinceMouseReleased < maxMouseReleaseTime) {
			//do nothing --- scrolling was only temporarily interrupted
		}
		else {
			//start a new scrolling action
			velocitySamples = [];
			deadzoneVector = new Vector(0,0);

			/*
			for (i in  0 ... samplesMin) { //this avoids sudden stops caused by not having enough samples (but it does "deaden" fast flicks... what's the solution?)
				velocitySamples.push(new Vector(0,0));
			}
			*/

			prevTouchPos = Main.Settings.RealScreenPosToStandardScreenPos(e.pos);
			prevTouchTime = e.timestamp;

			axis = new Vector(0,0);

			timeSinceMousePressed = 0; //hacky

			//test
			//Luxe.events.fire("joystick.pressed", axis);
		}
	}

	override function onmousemove( e:MouseEvent ) {
	}

	override function onmouseup( e:MouseEvent ) {
		isScrolling = false;
		timeSinceMouseReleased = 0;
	}

	function scrollrelease() {
		trace("scroll release!!!");
		trace(velocitySamples);

		if (velocitySamples.length >= samplesMin /*&& deadzoneVector.length > deadzoneSize*/) {
			
			//normal calculations
			var avgVelocity = new Vector(0, 0);
			for (s in velocitySamples) {
				avgVelocity.add(s);
			}
			avgVelocity.divideScalar(velocitySamples.length);

			releaseVelocity = avgVelocity;

			//hack for sudden stops
			var isSuddenStop = true;
			for (i in 0 ... samplesMin) { //should I really use samplesMin like this?
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
		if ( isScrollingLockedToXAxis() ) {
			releaseVelocity.y = 0;
		}
		else {
			releaseVelocity.x = 0;
		}
		axis = releaseVelocity; //set axis
		axis.divide( Main.Settings.IdealScreenSize() );

		//check if we meet fast flick or slow flick criteria
		var isSlowFlick = deadzoneVector.length > deadzoneSize;
		if (!isSlowFlick) {
			var isFastEnough = axis.length > minFastFlickSpeed;
			if (!isFastEnough) {
				axis = new Vector(0,0);
				trace("fast flick isn't fast enough!");
			}
		}

		velocitySamples = []; //purge samples after successful release

		Luxe.events.fire("joystick.released", axis);

		axis = new Vector(0,0); //clear axis after release
	}

	function isScrollingLockedToXAxis() {
		return (Math.abs(deadzoneVector.x) * 1.5) > Math.abs(deadzoneVector.y); //1.5 multiplier makes x-axis lock zone bigger
	}

	//todo name?
	function hasScrollingSamples() {
		return velocitySamples.length > 0;
	}

	/* KEYBOARD INPUT */
	var maxKeyboardSpeed = 0.8;
	//var maxKeyboardSpeed = 2.0; //test max speed
	var keyboardAcceleration = 0.6;
	var keyboardUpSpeed = 0.5;
	var areKeysAlreadyHeld = false;

	override function onkeydown( e:KeyEvent ) {

		if (e.keycode == Key.right || e.keycode == Key.key_d || 
			e.keycode == Key.left || e.keycode == Key.key_a || 
			e.keycode == Key.up || e.keycode == Key.key_w ||
			e.keycode == Key.down || e.keycode == Key.key_s)
		{
			source = InputSource.Keyboard;

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
		//return ( Luxe.input.mousedown(1) ) || ( hasScrollingSamples() && timeSinceMouseReleased < maxMouseReleaseTime );
		//return ( Luxe.input.mousedown(1) && deadzoneVector.length > deadzoneSize ) || ( hasScrollingSamples() && timeSinceMouseReleased < maxMouseReleaseTime );
		return ( isScrolling ) || ( hasScrollingSamples() && timeSinceMouseReleased < maxMouseReleaseTime );
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