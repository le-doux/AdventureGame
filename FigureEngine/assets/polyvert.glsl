#ifdef GL_ES
precision mediump float;
precision highp int;
#endif

attribute vec3 a_position;

uniform vec2 u_resolution;

uniform vec2 u_path[32];
uniform int u_pathLength;

uniform vec2 u_origin;
uniform vec2 u_position;
uniform vec2 u_scale;
uniform float u_rotation;

//mat3 u_transform = mat3(1.0,0.0,0.0, 0.0,1.0,0.0, 0.0,0.0,1.0); //todo replace w/ uniform

uniform mat3 u_transform;
//uniform mat4 u_transform;

varying vec2 localPos;

mat3 rotate2d(float _angle){
	return mat3(cos(_angle),-sin(_angle),0.0,
				sin(_angle),cos(_angle),0.0,
				0.0,0.0,1.0);
}

mat3 scale2d(float x, float y){
	return mat3(x,0.0,0.0,
				0.0,y,0.0,
				0.0,0.0,1.0);
}

mat3 translate2d(float x, float y){
	return mat3(1.0,0.0,x,
				0.0,1.0,y,
				0.0,0.0,1.0);
}

void main(void) {

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
	vec2 uv = a_position.xy * size; //is uv the right term?
	localPos = minPoint + (a_position.xy * uv);

	//transformations
	/*
	vec2 screenPos = uv + (minPoint - u_origin); //how will origin math work w/ matrix?
	screenPos = screenPos * u_scale;
	screenPos = rotate2d( u_rotation ) * screenPos;
	screenPos = screenPos + u_position;
	*/
	vec2 screenPos = minPoint + uv;
	//screenPos = (u_transform * vec3(screenPos.xy, 1.0)).xy; //replace everything with one matrix
	//trans2 = trans2 * scale2d(1.5,2.0);//translate2d(200.0,100.0); //scale2d(1.5,2.0); //rotate2d( 3.1415 * 0.25 );
	screenPos = (vec3(screenPos.xy, 1.0) * u_transform).xy;

	//move into screen space
	screenPos = screenPos / u_resolution;

	//final position
	gl_Position = vec4( screenPos, 0.0,1.0 );

}