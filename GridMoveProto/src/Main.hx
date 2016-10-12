
import luxe.Input;
import luxe.Vector;
import luxe.utils.Maths;
import luxe.tween.Actuate;

class Main extends luxe.Game {

	var gridW = 4;
	var gridH = 4;
	var squareSize = 130;

	var playerGridX = 2;
	var playerGridY = 2;
	var playerOffX = 0.0;
	var playerOffY = 0.0;

	var swipeX = 0.0;
	var swipeY = 0.0;
	var swipeDeadzone = 13;

	var minDistToSlide = 30;
	var slideTime = 0.2;
	var isSliding = false;

	var roomOffX = 0.0;
	var roomOffY = 0.0;
	var roomSlideTime = 0.3;

	override function ready() {

	} //ready

	override function onkeyup( e:KeyEvent ) {

		if(e.keycode == Key.escape) {
			Luxe.shutdown();
		}

	} //onkeyup

	override function onmousedown( e:MouseEvent ) {
		if (!isSliding) {
			swipeX = 0;
			swipeY = 0;
		}
	}

	override function onmousemove( e:MouseEvent ) {
		if (Luxe.input.mousedown(1) && !isSliding) {
			if (Math.abs(swipeX) < swipeDeadzone && Math.abs(swipeY) < swipeDeadzone) {
				swipeX += e.xrel;
				swipeY += e.yrel;
			}
			else if (Math.abs(swipeX) >= swipeDeadzone) {
				swipeX += e.xrel;
				swipeY = 0;
			}
			else if (Math.abs(swipeY) >= swipeDeadzone) {
				swipeX = 0;
				swipeY += e.yrel;
			}

			swipeX = Maths.clamp(swipeX, -squareSize, squareSize);
			swipeY = Maths.clamp(swipeY, -squareSize, squareSize);

		}
	}

	override function onmouseup( e:MouseEvent ) {
		if (isSliding) return;

		if (Math.abs(swipeX) >= swipeDeadzone) {
			//slide X
			var destGridX = playerGridX;
			var destOffX = 0.0;
			if (swipeX >= minDistToSlide) {
				destGridX++;
				destOffX = squareSize;
			}
			else if (swipeX <= -minDistToSlide) {
				destGridX--;
				destOffX = -squareSize;
			}

			isSliding = true;
			var tOff = {
				x : playerOffX
			};
			Actuate.tween(tOff, slideTime, {x:destOffX})
				.onUpdate(function() {
						playerOffX = tOff.x;
					})
				.onComplete(function() {
						playerGridX = destGridX;
						playerOffX = 0;
						isSliding = false;
						checkRoomEdge();
					});
		}
		else if (Math.abs(swipeY) >= swipeDeadzone) {
			//slide Y
			var destGridY = playerGridY;
			var destOffY = 0.0;
			if (swipeY >= minDistToSlide) {
				destGridY++;
				destOffY = squareSize;
			}
			else if (swipeY <= -minDistToSlide) {
				destGridY--;
				destOffY = -squareSize;
			}

			isSliding = true;
			var tOff = {
				y : playerOffY
			};
			Actuate.tween(tOff, slideTime, {y:destOffY})
				.onUpdate(function() {
						playerOffY = tOff.y;
					})
				.onComplete(function() {
						playerGridY = destGridY;
						playerOffY = 0;
						isSliding = false;
						checkRoomEdge();
					});
		}

		swipeX = 0;
		swipeY = 0;
	}

	function checkRoomEdge() {
		if (playerGridX < 0) {
			//slide out
			isSliding = true;
			roomOffX = 0;
			var tOff = {
				x: 0.0
			};
			Actuate.tween(tOff, roomSlideTime, {x:Luxe.screen.w})
				.onUpdate(function() {
						roomOffX = tOff.x;
					})
				.onComplete(function() {
						//slide in
						playerGridX = gridW - 1;
						roomOffX = -Luxe.screen.w;
						tOff.x = -Luxe.screen.w;
						Actuate.tween(tOff, roomSlideTime, {x:0})
							.onUpdate(function() {
									roomOffX = tOff.x;
								})
							.onComplete(function() {
									roomOffX = 0;
									isSliding = false;
								});
					});
		}
		else if (playerGridX >= gridW) {
			//slide out
			isSliding = true;
			roomOffX = 0;
			var tOff = {
				x: 0.0
			};
			Actuate.tween(tOff, roomSlideTime, {x:-Luxe.screen.w})
				.onUpdate(function() {
						roomOffX = tOff.x;
					})
				.onComplete(function() {
						//slide in
						playerGridX = 0;
						roomOffX = Luxe.screen.w;
						tOff.x = Luxe.screen.w;
						Actuate.tween(tOff, roomSlideTime, {x:0})
							.onUpdate(function() {
									roomOffX = tOff.x;
								})
							.onComplete(function() {
									roomOffX = 0;
									isSliding = false;
								});
					});
		}
		else if (playerGridY < 0) {
			//slide out
			isSliding = true;
			roomOffY = 0;
			var tOff = {
				y: 0.0
			};
			Actuate.tween(tOff, roomSlideTime, {y:Luxe.screen.h})
				.onUpdate(function() {
						roomOffY = tOff.y;
					})
				.onComplete(function() {
						//slide in
						playerGridY = gridH - 1;
						roomOffY = -Luxe.screen.h;
						tOff.y = -Luxe.screen.h;
						Actuate.tween(tOff, roomSlideTime, {y:0})
							.onUpdate(function() {
									roomOffY = tOff.y;
								})
							.onComplete(function() {
									roomOffY = 0;
									isSliding = false;
								});
					});
		}
		else if (playerGridY >= gridH) {
			//slide out
			isSliding = true;
			roomOffY = 0;
			var tOff = {
				y: 0.0
			};
			Actuate.tween(tOff, roomSlideTime, {y:-Luxe.screen.h})
				.onUpdate(function() {
						roomOffY = tOff.y;
					})
				.onComplete(function() {
						//slide in
						playerGridY = 0;
						roomOffY = Luxe.screen.h;
						tOff.y = Luxe.screen.h;
						Actuate.tween(tOff, roomSlideTime, {y:0})
							.onUpdate(function() {
									roomOffY = tOff.y;
								})
							.onComplete(function() {
									roomOffY = 0;
									isSliding = false;
								});
					});
		}
	}

	override function update(dt:Float) {
		//draw grid
		var gridSize = new Vector(gridW * squareSize, gridH * squareSize);
		var topCorner = Luxe.screen.mid.clone().subtract( gridSize.clone().multiplyScalar(0.5) ).add( new Vector(roomOffX, roomOffY) );
		for (x in 0 ... gridW) {
			for (y in 0 ... gridH) {
				Luxe.draw.rectangle({
						x: topCorner.x + (x*squareSize),
						y: topCorner.y + (y*squareSize),
						w: squareSize,
						h: squareSize,
						immediate: true
					});
			}
		}
		//draw player
		if (!isSliding && (Math.abs(swipeX) >= swipeDeadzone || Math.abs(swipeY) >= swipeDeadzone)) {
			playerOffX = swipeX;
			playerOffY = swipeY;
		}
		Luxe.draw.box({
				x: topCorner.x + (playerGridX*squareSize) + playerOffX,
				y: topCorner.y + (playerGridY*squareSize) + playerOffY,
				w: squareSize,
				h: squareSize,
				immediate: true
			});

	} //update


} //Main
