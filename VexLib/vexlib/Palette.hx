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

	//this function needs a better name --- and I need to handle multiple palettes
	public static function Load(pal:PaletteFormat, ?name:String) {
		if (name == null) name = pal.id;
		paletteMap.set(name, pal);
	}

	public static function Init(id:String) {
		var pal = paletteMap.get(id);
		for (i in 0 ... pal.colors.length) {
			Colors.push( pal.colors[i] );
		}
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
		return tweenReturn;
	}
}