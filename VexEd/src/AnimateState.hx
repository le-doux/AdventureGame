import luxe.States;
import luxe.Input;
import luxe.Vector;
import luxe.utils.Maths;

import vexlib.Editor;
import vexlib.EditingTools;
import vexlib.Vex;
import vexlib.Animation;

class AnimateState extends State {

	var curAnimation : Animation = null;
	var isTouchingTimeline = false;
	var selectedKeyframeOnMousedown = false;
	var isTranslatingSelection = false;
	var animationPreviewDuration = 5.0;

	override function onkeydown( e:KeyEvent ) {
		//open animation
		//TODO overload key_o instead
		if (e.keycode == Key.key_a && e.mod.meta) {
			//load file
			curAnimation = Editor.scene.root.addAnimation( EditingTools.openJson() );
		}

		//make new animation
		if (e.keycode == Key.key_n && e.mod.meta) {
			curAnimation = Editor.scene.root.addAnimation({id:"newAnimation"});
		}

		//change animation duration
		if (e.keycode == Key.key_t && e.mod.meta) {
			animationPreviewDuration += 1;
		}
		else if (e.keycode == Key.key_g && e.mod.meta) {
			animationPreviewDuration -= 1;
			if (animationPreviewDuration < 1) animationPreviewDuration = 1;
		}

		//play animation
		if (e.keycode == Key.key_p && e.mod.meta) {
			Editor.scene.root.playAnimation(curAnimation.id, animationPreviewDuration)
					.onComplete(function() {
							trace("animation complete!");
							Editor.scene.root.resetToBasePose();
						});
		}

		if (curAnimation != null) { //TODO should I ensure that curAnimation is never null?

			//export animation //TODO overload cmd+s
			if (e.keycode == Key.key_e && e.mod.meta) {
				var json = curAnimation.serialize();
				EditingTools.saveJson( json );
			}

			//delete current keyframe
			if (e.keycode == Key.backspace) {
				curAnimation.delete(curAnimation.t);
				curAnimation.t = curAnimation.t; //update the view
			}

			//TODO share code between regular edit & animate edit?
			//rotate selected elements //TODO make command //TODO make rotate handle?
			if (e.keycode == Key.right && e.mod.meta) {
				trace("!!");
				for (sel in Editor.multiselection) {
					trace(sel);
					sel.rotation_z += 5;
					curAnimation.set({
							t : curAnimation.t,
							select : sel.properties.id,
							rot : sel.rotation_z
						});
				}
			}
			if (e.keycode == Key.left && e.mod.meta) {
				for (sel in Editor.multiselection) {
					sel.rotation_z -= 5;
					curAnimation.set({
							t : curAnimation.t,
							select : sel.properties.id,
							rot : sel.rotation_z
						});
				}
			}

			//scale selected elements //TODO make command //TODO separate x- and y- axes
			if (e.keycode == Key.up && e.mod.meta) {
				for (sel in Editor.multiselection) {
					sel.scale.add(new Vector(0.1,0.1)); //TODO do I need defaults for properties???
					curAnimation.set({
							t : curAnimation.t,
							select : sel.properties.id,
							scale : sel.scale
						});
				}
			}
			if (e.keycode == Key.down && e.mod.meta) {
				for (sel in Editor.multiselection) {
					sel.scale.subtract(new Vector(0.1,0.1));
					curAnimation.set({
							t : curAnimation.t,
							select : sel.properties.id,
							scale : sel.scale
						});
				}
			}	
		}

	}

	override function onmousedown( e:MouseEvent ) {
		var screenPos = e.pos;
		var p = Luxe.camera.screen_point_to_world(e.pos);

		// timeline scrubbing
		var timelineY = Luxe.screen.h * 0.9;
		var distFromTimelineY = Math.abs(timelineY - screenPos.y);
		isTouchingTimeline = distFromTimelineY < 15;
		if (isTouchingTimeline) {
			selectedKeyframeOnMousedown = animationTimelineSelect(screenPos.x);
		}
		else {
			//TODO add multiselect here
			/* SELECT */
			var newSelection : Vex = null;
			if (Editor.selection != null && Editor.selection.properties.type != "ref") newSelection = Editor.selection.getChildWithPointInside(p);
			if (newSelection == null) newSelection = Editor.scene.root.getChildWithPointInside(p);
			Editor.selection = newSelection;
		}
	}

	override function onmousemove( e:MouseEvent ) {
		var screenPos = e.pos;
		var p = Luxe.camera.screen_point_to_world(e.pos);

		// timeline scrubbing
		if (selectedKeyframeOnMousedown) {
			//don't do nothin
		}
		else if (isTouchingTimeline) {
			animationTimelineSelect(screenPos.x);
		}
		/* TRANSLATE SELECTION */
		else if (Luxe.input.mousedown(luxe.MouseButton.left)) {
			if (Editor.multiselection.length > 0) {
				for (sel in Editor.multiselection) {
					sel.pos.x += e.x_rel / Luxe.camera.zoom;
					sel.pos.y += e.y_rel / Luxe.camera.zoom;
					isTranslatingSelection = true;
				}
			}
		}

	}

	function animationTimelineSelect(x:Float) {
		var isKeyframeTouched = false;

		var timelineX = Luxe.screen.w * 0.1;
		var timelineW = Luxe.screen.w * 0.8;

		var selectX = Maths.clamp(x - timelineX, 0, timelineW);
		var timelinePercent = selectX / timelineW;
		
		if (curAnimation != null) {

			//snap & select
			for (t in curAnimation.times()) {
				var keyframeX = (timelineW * t);
				if (Math.abs(keyframeX - selectX) < 10) {
					timelinePercent = t;
					isKeyframeTouched = true;
				}
			}

			//move animation marker & update animation
			curAnimation.t = timelinePercent;

		}

		return isKeyframeTouched;
	}

	override function onmouseup(e:MouseEvent) {
		if (selectedKeyframeOnMousedown) {
			var timelineX = Luxe.screen.w * 0.1;
			var timelineW = Luxe.screen.w * 0.8;
			var selectX = Maths.clamp(e.pos.x - timelineX, 0, timelineW);
			var timelinePercent = selectX / timelineW;
			curAnimation.move(curAnimation.t, timelinePercent);
			curAnimation.t = timelinePercent;
		}

		if (isTranslatingSelection) {
			for (sel in Editor.multiselection) {
				curAnimation.set({
					t : curAnimation.t,
					select : sel.properties.id, //do I rely too much on everything having a unique id?
					pos : sel.pos
				});
			}
		}

		isTouchingTimeline = false;
		selectedKeyframeOnMousedown = false;
		isTranslatingSelection = false;
	}

	override function update( dt:Float ) {
		//tool
		Luxe.draw.text({
				text: "time (s): " + animationPreviewDuration,
				point_size: 16,
				batcher: Editor.batcher.uiScreen,
				pos: new Vector(0,40),
				immediate: true
			});

		//draw timeline
		var timelineY = Luxe.screen.h * 0.9;
		var timelineX = Luxe.screen.w * 0.1;
		var timelineW = Luxe.screen.w * 0.8;

		Luxe.draw.line({
				p0: new Vector(timelineX, timelineY),
				p1: new Vector(timelineX + timelineW, timelineY),
				batcher: Editor.batcher.uiScreen,
				immediate: true
			});

		if (curAnimation != null) {
			if (!selectedKeyframeOnMousedown) {
				var animationProgressMarkerX = timelineX + (timelineW * curAnimation.t);
				Luxe.draw.line({
						p0: new Vector(animationProgressMarkerX, timelineY - 15),
						p1: new Vector(animationProgressMarkerX, timelineY + 15),
						batcher: Editor.batcher.uiScreen,
						immediate: true
					});
			}

			for (t in curAnimation.times()) {
				var keyframeX = timelineX + (timelineW * t);

				if (t == curAnimation.t) {
					if (selectedKeyframeOnMousedown) {
						var selectX = Maths.clamp(Luxe.screen.cursor.pos.x, timelineX, timelineX + timelineW);
						keyframeX = selectX;
					}
					Luxe.draw.circle({
							x: keyframeX, 
							y: timelineY,
							r: 10,
							batcher: Editor.batcher.uiScreen,
							immediate: true
						});
				}
				else {
					Luxe.draw.ring({
							x: keyframeX, 
							y: timelineY,
							r: 10,
							batcher: Editor.batcher.uiScreen,
							immediate: true
						});
				}
			}
		}

		//render selection bounds
		EditingTools.drawVexBounds( Editor.multiselection, Editor.batcher.uiWorld );
	}

	override function onleave<T>(t:T) {
		Editor.scene.root.resetToBasePose();
	}

}