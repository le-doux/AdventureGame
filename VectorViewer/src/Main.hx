
import luxe.Input;
import luxe.Visual;
import luxe.Color;

class Main extends luxe.Game {
	var v : Vex;

	var path = [];

    override function ready() {

    	Vex.Palette.Colors = [
    		new Color(1,0,0),
    		new Color(0,1,0),
    		new Color(0,0,1)
    	];
    	
    	// /*
    	var load = Luxe.resources.load_json("assets/testvex.json");
    	load.then(function() {
    			var res = Luxe.resources.json("assets/testvex.json");
    			v = new Vex(res.asset.json);
    		});
    	// */
    	
    } //ready

    override function onkeyup( e:KeyEvent ) {

        if(e.keycode == Key.escape) {
            Luxe.shutdown();
        }

        if (e.keycode == Key.key_1) {
        	//trigger animation
        	if (v != null){
				var loadAnim = Luxe.resources.load_json("assets/testanim.json");
				loadAnim.then(function() {
						var resAnim = Luxe.resources.json("assets/testanim.json");
						v.animate(resAnim.asset.json, 10);
					});
			}
        }

        if (e.keycode == Key.key_2) {
        	//trigger palette change
			Vex.Palette.Colors[0].g = 1;
			Vex.Palette.Colors[1].b = 1;
			Vex.Palette.Colors[2].r = 1;
        }

        if (e.keycode == Key.key_3) {
        	new Vex({
        			type: "poly",
        			path: path
        		});

        	path = [];
        }

    } //onkeyup

    override function onmousedown( e:MouseEvent ) {
    	Luxe.draw.circle({
    			x: e.x, y: e.y,
    			r: 10
    		});

    	path.push(e.x);
    	path.push(e.y);
    }

    override function update(dt:Float) {

    } //update


} //Main

