
import luxe.Input;
import luxe.Vector;

import phoenix.geometry.Geometry;
import phoenix.geometry.Vertex;
import phoenix.Batcher;

class Main extends luxe.Game {

	override function config(config:luxe.GameConfig) {

		config.preload.shaders.push({ id:'poly', frag_id:'assets/polyfrag.glsl', vert_id:'assets/polyvert.glsl' });

		return config;

	}

    override function ready() {
    	var g = new Geometry({ batcher:Luxe.renderer.batcher, primitive_type:PrimitiveType.triangles, shader:Luxe.resources.shader("poly") });
    	g.vertices.push( new Vertex(new Vector(0,0)) );
    	g.vertices.push( new Vertex(new Vector(1,0)) );
    	g.vertices.push( new Vertex(new Vector(0,1)) );
    	g.vertices.push( new Vertex(new Vector(1,0)) );
    	g.vertices.push( new Vertex(new Vector(0,1)) );
    	g.vertices.push( new Vertex(new Vector(1,1)) );

    	g.shader.set_vector2("u_resolution", Luxe.screen.size);
    	g.shader.set_vector2("u_origin", new Vector(0,0));
    	g.shader.set_vector2("u_position", new Vector(0,30));
    	g.shader.set_vector2("u_scale", new Vector(2,1));
    	g.shader.set_float("u_rotation", Math.PI*0.3);
    	
    	//g.shader.set_vector2("u_path", [new Vector(0,0),new Vector(100,0),new Vector(100,100)]);
    	//g.shader.set_vector2()
    } //ready

    override function onkeyup( e:KeyEvent ) {

        if(e.keycode == Key.escape) {
            Luxe.shutdown();
        }

    } //onkeyup

    override function update(dt:Float) {

    } //update


} //Main
