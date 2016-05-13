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
	@:optional var onShowLevel : Dynamic;
	@:optional var onHideLevel : Dynamic;
	@:optional var onLevelUpdate : Float->Void;
}

//TODO: give each level its own scene (maybe extend from scene?)
//that would mean level could no longer be an entity
//NOTE: actually I'm leaving the level as an entity in the main scene for now (is this bad? who knows?)
class Level extends Entity {
	public var terrain : Terrain;
	public var scenery : Array<Polystroke> = [];
	public var buttons : Array<ActionButton> = [];

	var onLevelInit : Dynamic;
	var onShowLevel : Dynamic;
	var onHideLevel : Dynamic;
	var onLevelUpdate : Float->Void;

	var terrainColor : Color;
	var backgroundColor : Color;

	public var levelScene : Scene;

	public override function new(_options:LevelOptions) {
		super(_options);
		levelScene = new Scene(_options.filename); //new scene w/ same name as file name
		if (_options.onLevelInit != null) onLevelInit = _options.onLevelInit;
		if (_options.onShowLevel != null) onShowLevel = _options.onShowLevel;
		if (_options.onHideLevel != null) onHideLevel = _options.onHideLevel;
		if (_options.onLevelUpdate != null) onLevelUpdate = _options.onLevelUpdate;
		loadLevelFromFile(_options.filename);
	}

	function loadLevelFromFile(levelname) {
		trace("! " + levelname);
		var load = Luxe.resources.load_json('assets/' + levelname);
		load.then(function(jsonRes : JSONResource) {

			trace(levelname);

			var json = jsonRes.asset.json;

			//rehydrate colors
			backgroundColor = (new Color()).fromJson(json.backgroundColor);
			terrainColor = (new Color()).fromJson(json.terrainColor);
			var sceneryColor = (new Color()).fromJson(json.sceneryColor);
			//Luxe.renderer.clear_color = backgroundColor;

			//rehydrate terrain
			if (levelname == "4_bagelEntrance_b") trace(json.terrain);
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
		if (onHideLevel != null) onHideLevel();
		this.active = false;
	}

	public function showLevel() {
		Luxe.renderer.clear_color = backgroundColor;
		terrain.draw(terrainColor);
		for (s in scenery) {
			s.active = true;
			s.visible = true;
		}
		for (b in buttons) {
			b.active = true;
			b.visible = true;
		}
		if (onShowLevel != null) onShowLevel();
		this.active = true;
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

		if (onLevelUpdate != null) onLevelUpdate(dt);
	}
}