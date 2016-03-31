package adventurlib;

import luxe.Color;

class ColorExtender {
	public static function toJson(c : Color) {
		return {
			r : c.r,
			g : c.g,
			b : c.b
		};
	}

	public static function fromJson(c : Color, json) : Color {
		c = new Color(json.r, json.g, json.b);
		return c;
	}
}