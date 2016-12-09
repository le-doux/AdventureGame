attribute vec2 a_position;
uniform vec2 u_mult;
void main() {
	gl_Position = vec4(a_position.xy * u_mult[0], 0.0, 1.0);
}