
import vexlib.Vex;
import vexlib.Palette;

import luxe.Vector;
import luxe.Input;
import luxe.Camera;
import phoenix.Batcher;
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
					time: 0.5,
					wait: 0.5
				}
			]
		}
	];

	var curPalette = 0;
	var curImage = 0;
	var curAnim = 0;

	var root : Vex;

	var uiBatcher : Batcher;

	override function ready() {
		Luxe.camera.size = new Vector(800,450);
		Luxe.camera.center = new Vector(0,0);
		//Luxe.camera.size_mode = luxe.SizeMode.cover;
		//Luxe.camera.pos = new Vector(-400,-225); //put 0,0 in the center of the camera
		//Luxe.camera.pos.subtract(Luxe.screen.mid); 

		var uiCam = new Camera({name:"uiCam"});
		uiBatcher = Luxe.renderer.create_batcher({name:"uiBatcher", layer:10, camera:uiCam.view});

		loadPalettes();
		loadImage();
	}

	override function update(dt:Float) {
		Luxe.draw.text({
				text: 'FPS: ' + Math.round(1.0/Luxe.debug.dt_average) + '\n'
						+ 'Palette: ' + palettes[curPalette].name + '\n'
						+ 'Image: ' + images[curImage].src + '\n'
						+ 'Animation: ' + images[curImage].animations[curAnim].name,
				point_size: 16,
				batcher: uiBatcher,
				immediate: true
			});

		Luxe.draw.text({
				text: '< Switch Palette >',
				point_size: 16,
				pos: new Vector(Luxe.screen.width * 0, Luxe.screen.height - 24),
				batcher: uiBatcher,
				immediate: true
			});
		Luxe.draw.text({
				text: '< Switch Animation >',
				point_size: 16,
				pos: new Vector(Luxe.screen.width * 0.25, Luxe.screen.height - 24),
				batcher: uiBatcher,
				immediate: true
			});
		Luxe.draw.text({
				text: '< Switch Image >',
				point_size: 16,
				pos: new Vector(Luxe.screen.width * 0.5, Luxe.screen.height - 24),
				batcher: uiBatcher,
				immediate: true
			});

		Luxe.draw.text({
				text: '[ Zoom In ]',
				point_size: 16,
				pos: new Vector(Luxe.screen.width * 0.75, Luxe.screen.height - 24),
				batcher: uiBatcher,
				immediate: true
			});
		Luxe.draw.text({
				text: '[ Zoom Out ]',
				point_size: 16,
				pos: new Vector(Luxe.screen.width * 0.75, 6),
				batcher: uiBatcher,
				immediate: true
			});
	}

	override function onwindowresized(e) {
		trace(Luxe.camera.pos);
		Luxe.camera.center = new Vector(0,0);
		//Luxe.camera.pos = new Vector(-400,-225); //keep it centered LUXE BUG
	}

	override function onmousedown( e:MouseEvent ) {
		if (e.x < Luxe.screen.width * 0.25) {
			nextPalette();
		}
		else if (e.x < Luxe.screen.width * 0.5) {
			nextAnimation();
		}
		else if (e.x < Luxe.screen.width * 0.75) {
			nextImage();
		}
		else {
			Luxe.camera.zoom = 0.25 + (1.75 * (e.y / Luxe.screen.height));
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