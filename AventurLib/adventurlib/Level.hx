package adventurlib;

import luxe.Entity;
import luxe.Color;
import luxe.Scene;
import luxe.options.EntityOptions;
import luxe.resource.Resource.JSONResource;

using adventurlib.ColorExtender;

typedef LevelOptions = {
	> EntityOptions,
	var filename : String;
	@:optional var onLevelInit : Dynamic;
}

//TODO: give each level its own scene (maybe extend from scene?)
//that would mean level could no longer be an entity
//NOTE: actually I'm leaving the level as an entity in the main scene for now (is this bad? who knows?)
class Level extends Entity {
	public var terrain : Terrain;
	public var scenery : Array<Polystroke> = [];
	public var buttons : Array<ActionButton> = [];

	var onLevelInit : Dynamic;
	var terrainColor : Color;

	public var levelScene : Scene;

	public override function new(_options:LevelOptions) {
		super(_options);
		levelScene = new Scene(_options.filename); //new scene w/ same name as file name
		loadLevelFromFile(_options.filename);
		if (_options.onLevelInit != null) onLevelInit = _options.onLevelInit;
	}

	function loadLevelFromFile(levelname) {
		var load = Luxe.resources.load_json('assets/' + levelname);
		load.then(function(jsonRes : JSONResource) {

			var json = jsonRes.asset.json;

			//rehydrate colors
			var backgroundColor = (new Color()).fromJson(json.backgroundColor);
			terrainColor = (new Color()).fromJson(json.terrainColor);
			var sceneryColor = (new Color()).fromJson(json.sceneryColor);
			Luxe.renderer.clear_color = backgroundColor;

			//rehydrate terrain
			terrain = new Terrain();
			terrain.fromJson(json.terrain);

			//rehydrate scenery
			scenery = [];
			for (s in cast(json.scenery, Array<Dynamic>)) {
				var p = new Polystroke(
					{ 
						color : sceneryColor, 
						batcher : Luxe.renderer.batcher,
						scene : levelScene //add to internal scene
					}, 
					[]);
				p.fromJson(s);
				scenery.push(p);
			}

			//rehydrate action buttons
			buttons = [];
			for (b in cast(json.buttons, Array<Dynamic>)) {
				//trace(b);
				var a = (new ActionButton({scene:levelScene})).fromJson(b);
				a.terrain = terrain;
				a.curSize = 0; //start invisible
				buttons.push(a);
			}

			//start w/ level hidden (should I put everything in a seperate scene object instead of layering it all?)
			hideLevel();

			if (onLevelInit != null) onLevelInit(); //first load finished callback
		});
	}

	public function hideLevel() {
		terrain.clear(); //terrain desperately needs to become a Visual subclass or something
		for (s in scenery) {
			s.active = false;
			s.visible = false;
		}
		for (b in buttons) {
			b.active = false;
			b.visible = false;
		}
	}

	public function showLevel() {
		terrain.draw(terrainColor);
		for (s in scenery) {
			s.active = true;
			s.visible = true;
		}
		for (b in buttons) {
			b.active = true;
			b.visible = true;
		}
	}

	public function anyButtonsTouched() : Bool {
		var anyTouched = false;
		for (a in buttons) {
			if (a.isTouched) anyTouched = true;
		}
		return anyTouched;
	}

	public override function update(dt : Float) {

		//TODO: move this logic into the action buttons update?
		for (a in buttons) {
			if (a.active) {
				if (Math.abs(a.terrainPos - Main.instance.player.terrainPos) < 300) { //arbitrary distance
					a.triggerAppear();
				}
				else {
					a.triggerDisappear();
				}
			}
		}
	}
}