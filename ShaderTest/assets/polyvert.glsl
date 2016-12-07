attribute vec3 vertexPosition;
/*
attribute vec2 vertexTCoord;
attribute vec4 vertexColor;
attribute vec3 vertexNormal;

varying vec2 tcoord;
varying vec4 color;
*/

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

//uniform float sizeMult;

uniform vec2 u_resolution;

uniform vec2 u_path[32];
uniform int u_pathLength;

uniform vec2 u_origin;
uniform vec2 u_position;
uniform vec2 u_scale;
uniform float u_rotation;

varying vec2 localPos;

mat2 rotate2d(float _angle){
	return mat2(cos(_angle),-sin(_angle),
				sin(_angle),cos(_angle));
}

void main(void) {

	//gl_Position = projectionMatrix * modelViewMatrix * vec4(vertexPosition * sizeMult, 1.0);

	//calculate quad bounds and vertex local position
	/*
	vec2 minPoint = u_path[0];
	vec2 maxPoint = u_path[0];
	for (int i=0;i<32;i++) {

		if (i >= u_pathLength) break; //this is hacky; something that generates shaders might be better?

		minPoint.x = min(minPoint.x, u_path[i].x);
		maxPoint.x = max(maxPoint.x, u_path[i].x);
		minPoint.y = min(minPoint.y, u_path[i].y);
		maxPoint.y = max(maxPoint.y, u_path[i].y);
	}
	vec2 size = maxPoint - minPoint;
	vec2 uv = a_position.xy * size; //is uv the right term?
	localPos = minPoint + (a_position.xy * uv);

	//transformations
	vec2 screenPos = uv + (minPoint - u_origin);
	screenPos = screenPos * u_scale;
	screenPos = rotate2d( u_rotation ) * screenPos;
	screenPos = screenPos + u_position;

	//move into screen space
	screenPos = screenPos / u_resolution;

	//final position
	gl_Position = vec4( screenPos, 1.0,1.0 );
	*/

	vec2 screenPos = (vertexPosition.xy * 100.0);
	screenPos = screenPos * u_scale;
	screenPos = rotate2d( u_rotation ) * screenPos;
	screenPos = screenPos + u_position;

	//move into screen space
	screenPos = screenPos / u_resolution;

	gl_Position = vec4( screenPos, 1.0,1.0 );
}