//uniform vec2 u_path[32];
//uniform int u_pathLength;
//uniform vec4 u_color[2];
vec2 u_path[3];// = [vec2(0,0), vec2(40,0), vec2(40,40)];
int u_pathLength = 3;

varying vec2 localPos;

void main() {
	
	//test
	u_path[0] = vec2(0,0);
	u_path[1] = vec2(40,0);
	u_path[2] = vec2(50,40);



	float crossCount = 0.0;

	vec2 a = u_path[0];
	for (int i=1;i<32;i++) {

		if (i > u_pathLength) break;

		vec2 b = u_path[i];
		if (i == u_pathLength) {
			b = u_path[0]; //I have to go to contortions to allow different size polygons :(
		}
		vec2 c = localPos;

		float deltaY = (c.y - a.y) / (b.y - a.y);
		float x = a.x + ((b.x - a.x)*deltaY);
		float inY = step(0.0,deltaY) - step(1.0,deltaY);
		float inX = step(x,c.x);
		float cross = inY * inX;

		crossCount += cross;

		a = b;
	}

	float inPoly = mod(crossCount,2.0); 
	//vec4 color = inPoly * (u_color[0] + (u_color[1]-u_color[0])*(localPos.y/-200.0)); //todo make relative to bounding box
	vec4 color = inPoly * vec4(1.0,0.0,0.0,1.0);

	gl_FragColor = color;

}