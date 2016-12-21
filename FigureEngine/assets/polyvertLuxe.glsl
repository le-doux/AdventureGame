#ifdef GL_ES
precision mediump float;
precision highp int;
#endif

// luxe defaults

attribute vec3 vertexPosition;
attribute vec2 vertexTCoord;
attribute vec4 vertexColor;
attribute vec3 vertexNormal;

varying vec2 tcoord;
varying vec4 color;

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

// luxe defaults


uniform vec2 u_path[32];
uniform int u_pathLength;
varying vec2 localPos;


void main(void) {

/*
    gl_Position = projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);
    tcoord = vertexTCoord;
    color = vertexColor;
        //hmm! I think shaders are compiled optimised, removing unused values which means
        //that the shaders getVertexNormal attribute returns invalid (-1) values!
    vec3 n = vertexNormal;
    gl_PointSize = 1.0;
*/
	
	//hack test
	/*
	u_path[0] = vec2(0.0,0.0);
	u_path[1] = vec2(50.0,0.0);
	u_path[2] = vec2(100.0,50.0);
	*/


	//calculate quad bounds and vertex local position
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
	vec2 uv = vertexPosition.xy * size; //is uv the right term?
	localPos = minPoint + (vertexPosition.xy * uv);
	vec2 screenPos = minPoint + uv;

    gl_Position = projectionMatrix * modelViewMatrix * vec4(screenPos, 0.0, 1.0);
    tcoord = vertexTCoord; //texture, not needed?
    color = vertexColor;
    vec3 n = vertexNormal;

}