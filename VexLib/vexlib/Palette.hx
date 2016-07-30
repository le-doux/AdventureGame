package vexlib;

import luxe.Color;

import vexlib.VexPropertyInterface;

/* PALETTES */
// TODO I may need to do some renaming of these classes
typedef PaletteFormat = {
	@:optional var type : Property;
	@:optional var id : Property;
	@:optional var colors : Array<Property>;
}
class Palette {
	public static var Colors : Array<Color> = [];
	static var paletteMap : Map<String, PaletteFormat> = new Map();
	static var curPal;

	//this function needs a better name --- and I need to handle multiple palettes
	public static function Load(pal:PaletteFormat, ?name:String) {
		if (name == null) name = pal.id;
		paletteMap.set(name, pal);
	}

	//default init -- no colors
	public static function StartBlank() { //needs a new name?
		for (i in 0 ... 8) { //8 is an arbitrary number I'm currently limiting myself to
			Colors.push( new Color(0,0,0) ); //all black
		}
	}

	public static function Init(id:String) { //should I keep this
		var pal = paletteMap.get(id);
		for (i in 0 ... pal.colors.length) {
			Colors.push( pal.colors[i] );
		}
		curPal = id;
	}

	public static function Swap(id:String, ?t:Float) {
		if (t == null) t = 0;
		var pal = paletteMap.get(id);
		var tweenReturn = null;
		for (i in 0 ... pal.colors.length) {
			var nextColor : Color = pal.colors[i];
			tweenReturn = Colors[i].tween(t, 
						{ 
							r: nextColor.r, 
							g: nextColor.g, 
							b: nextColor.b 
						});
		}
		curPal = id;
		return tweenReturn;
	}

	public static function SwapNext(?t:Float) {
		trace(curPal);
		var firstPal : String = null;
		var prevPal : String = null;
		var nextPal : String = null;
		for (k in paletteMap.keys()) {
			trace("cur " + curPal);
			trace("prev " + prevPal);
			trace("next " + nextPal);
			trace("-");
			if (curPal != null && prevPal != null && prevPal == curPal) nextPal = k;
			if (firstPal == null) firstPal = k;
			prevPal = k;
			trace("cur " + curPal);
			trace("prev " + prevPal);
			trace("next " + nextPal);
			trace("---");
		}
		trace("first " + firstPal);
		if (nextPal == null) nextPal = firstPal;
		if (nextPal != null) Swap(nextPal, t);
		trace(curPal);
	}
}