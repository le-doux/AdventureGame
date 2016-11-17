package vexlib;

import luxe.Camera;
import phoenix.Batcher;
import luxe.resource.Resource.JSONResource;

/*
	Editor
	--
	Global state for editor apps
*/

class Editor {
	public static var batcher : {
		world : Batcher,
		uiScreen : Batcher,
		uiWorld : Batcher
	};

	public static var camera : {
		world : Camera,
		ui : Camera
	};

	public static var scene : {
		root : Vex
	};

	//TODO is there a way to decrease the number of globals? curPalIndex? selection?
	public static var multiselection : Array<Vex> = [];
	public static var selection (get, set) : Vex; //TODO should I deprecate this?

	public static var curPalIndex : Int = 1;

	public static var clipboard : String;

	public static function setup() {
		batcher = {
			world : null,
			uiScreen : null,
			uiWorld : null
		};

		camera = {
			world : null,
			ui : null
		};

		scene = {
			root : null
		};

		//setup cameras and batchers
		camera.world = Luxe.camera;
		camera.world.pos.subtract(Luxe.screen.mid); //put 0,0 in the center of the camera
		camera.world.size_mode = luxe.Camera.SizeMode.fit;

		batcher.world = Luxe.renderer.batcher;
		batcher.world.layer = 0;

		camera.ui = new Camera({name:"uiCam"});

		batcher.uiScreen = Luxe.renderer.create_batcher({name:"uiScreenBatcher", layer:10, camera:camera.ui.view});
		batcher.uiWorld = Luxe.renderer.create_batcher({name:"uiWorldBatcher", layer:5, camera:camera.world.view});

		//setup drawing
		scene.root = Vex.Create({
				type: "group",
				origin: "0,0",
				pos: "0,0"
			});

		//load default palettes - hacky nonsense
		var load = Luxe.resources.load_json('assets/testpal.vex');
		load.then(function(jsonRes : JSONResource) {
			var json = jsonRes.asset.json;
			Palette.Load(json);
			Palette.Init("test");
			Luxe.renderer.clear_color = Palette.Colors[0];
		});
	}

	static function get_selection() : Vex {
		if (multiselection.length > 0) return multiselection[0];
		return null;
	}

	static function set_selection(v:Vex) : Vex {
		multiselection = (v != null) ? [v] : [];
		return v;
	}
}