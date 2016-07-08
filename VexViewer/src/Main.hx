
import vexlib.Vex;
import vexlib.Palette;

import luxe.Vector;
import luxe.Input;
import luxe.resource.Resource.JSONResource;

class Main extends luxe.Game {
	var palettes = [
		{
			src: "default_pal.vex",
			name: "default"
		},
		{
			src: "alt_pal.vex",
			name: "alt"
		}
	];

	var images = [ 
		{
			src: "shroom.vex",
			pos: new Vector(0,100),
			animations: [
				{
					src: "shroom_bounce.vex",
					name: "bounce",
					time: 0.5,
					wait: 1.0
				},
				{
					src: "shroom_rot.vex",
					name: "rot",
					time: 1.0,
					wait: 0.5
				}
			]
		},
		{
			src: "guy.vex",
			pos: new Vector(0,0),
			animations: [
				{
					src: "guy_walk.vex",
					name: "walk",
					time: 2.0,
					wait: 0.0
				},
				{
					src: "guy_surprise.vex",
					name: "surprise",
					time: 1.0,
					wait: 0.5
				}
			]
		}
	];

	var curPalette = 0;
	var curImage = 0;
	var curAnim = 0;

	var root : Vex;

	override function ready() {
		Luxe.camera.pos.subtract(Luxe.screen.mid); //put 0,0 in the center of the camera
		//Luxe.camera.size_mode = luxe.SizeMode.fit;

		loadPalettes();
		loadImage();
	}

	override function onmousedown( e:MouseEvent ) {
		if (e.x < Luxe.screen.width * 0.3) {
			nextPalette();
		}
		else if (e.x < Luxe.screen.width * 0.6) {
			nextAnimation();
		}
		else {
			nextImage();
		}
	}

	override function onmousewheel(e:MouseEvent) {
		/* ZOOMING */
		Luxe.camera.zoom += e.yrel * 0.03 * Luxe.camera.zoom;
	}

	function loadPalettes() {
		for (i in 0 ... palettes.length) {
			var p = palettes[i];
			var load = Luxe.resources.load_json('assets/' + p.src);
			var name = p.name;
			load.then(function(jsonRes : JSONResource) {
					var json = jsonRes.asset.json;
					Palette.Load(json, name);
					if (i == 0) {
						Palette.Init(name);
						Luxe.renderer.clear_color = Palette.Colors[2];
					}
				});
		}
	}

	function nextPalette() {
		curPalette = (curPalette + 1) % palettes.length;
		Palette.Swap( palettes[curPalette].name, 2 );
	}

	function loadImage() {
		var img = images[curImage];
		var load = Luxe.resources.load_json('assets/' + img.src);
		load.then(function(jsonRes : JSONResource) {
				var json = jsonRes.asset.json;
				if (root != null) {
					root.stopAnimation();
					root.destroy();
				}
				root = new Vex(json);
				root.pos = img.pos;
				curAnim = 0;

				for (i in 0 ... img.animations.length) {
					var anim = img.animations[i];
					trace(anim.src);
					var load = Luxe.resources.load_json('assets/' + anim.src);
					load.then(function(jsonRes : JSONResource) {
							var json = jsonRes.asset.json;
							trace("load " + anim.name);
							root.addAnimation(json, anim.name);
							if (i == 0) root.playAnimation(anim.name, anim.time).delay(anim.wait).repeat();
						});
				}
			});
		
	}

	function nextImage() {
		curImage = (curImage + 1) % images.length;
		loadImage();
	}

	function nextAnimation() {
		var img = images[curImage];
		var animations = img.animations;
		curAnim = (curAnim + 1) % animations.length;
		var anim = animations[curAnim];
		root.stopAnimation();
		root.playAnimation(anim.name, anim.time).delay(anim.wait).repeat();
	}
}