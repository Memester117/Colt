#version 120
#extension GL_ARB_shader_texture_lod : enable 

/* DRAWBUFFERS:0246 */

/*



			███████ ███████ ███████ ███████ █
			█          █    █     █ █     █ █
			███████    █    █     █ ███████ █
			      █    █    █     █ █       
			███████    █    ███████ █       █

	Before you change anything here, please notice that you
	are allowed to modify my shaderpack ONLY for yourself!

	Please read my agreement for more informations!
		- http://bit.ly/1De7OOY

		
		
*/

//////////////////////////////////////////////////////////////
///////////////////// ADJUSTABLE FEATURES ////////////////////
//////////////////////////////////////////////////////////////

	#define WATER_HEIGHTMAP

	
	
	
	
	
	
	
	
	
	
//////////////////////////////////////////////////////////////
////////////////////////// CONSTS ////////////////////////////
//////////////////////////////////////////////////////////////

const float PI = 3.1415927;

//////////////////////////////////////////////////////////////
//////////////////////// GET MATERIAL ////////////////////////
//////////////////////////////////////////////////////////////

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 position;
varying vec3 binormal;
varying vec3 normal;
varying vec3 tangent;
varying vec3 viewVector;
varying vec3 wpos;
varying float iswater;

uniform sampler2D texture;
uniform int worldTime;
uniform float far;
uniform float rainStrength;
uniform float frameTimeCounter;

float wave(float n) {
	return sin(2 * PI * (n));
}

#ifdef WATER_HEIGHTMAP

	float waterH(vec3 posxz) {

		float wave = 0.0;


		float factor = 1.0;
		float amplitude = 0.2;
		float speed = 5.6;
		float size = 0.2;


		float px = posxz.x/50.0 + 250.0;
		float py = posxz.z/50.0  + 250.0;

		float fpx = abs(fract(px*20.0)-0.5)*2.0;
		float fpy = abs(fract(py*20.0)-0.5)*2.0;

		float d = length(vec2(fpx,fpy));

		for (int i = 1; i < 6; i++) {
			wave -= d*factor*sin( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
			factor /= 2;
		}

		factor = 1.0;
		px = -posxz.x/50.0 + 250.0;
		py = -posxz.z/150.0 - 250.0;

		fpx = abs(fract(px*20.0)-0.5)*2.0;
		fpy = abs(fract(py*20.0)-0.5)*2.0;

		d = length(vec2(fpx,fpy));
		float wave2 = 0.0;
		
		for (int i = 1; i < 6; i++) {
			wave2 -= d*factor*cos( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
			factor /= 2;
		}

		return amplitude*wave2+amplitude*wave;
	}
	
#endif










//////////////////////////////////////////////////////////////
/////////////////////////// MAIN /////////////////////////////
//////////////////////////////////////////////////////////////

void main() {	
	
	vec4 watercolor = vec4(0.05,0.3,0.4,0.5);
	vec4 tex = vec4((watercolor*color).rgb,watercolor.a);
	
	if (iswater == 0.0) tex = texture2D(texture, texcoord.xy)*color;
	
	#ifdef WATER_HEIGHTMAP
	
		vec3 posxz = wpos.xyz;
	
		posxz.x += sin(posxz.z*4.0+frameTimeCounter)*0.1;
		posxz.z += cos(posxz.x*2.0+frameTimeCounter*0.5)*0.1;
		
		float deltaPos = 0.1;
		float h0 = waterH(posxz);
		float h1 = waterH(posxz + vec3(deltaPos,0.0,0.0));
		float h2 = waterH(posxz + vec3(-deltaPos,0.0,0.0));
		float h3 = waterH(posxz + vec3(0.0,0.0,deltaPos));
		float h4 = waterH(posxz + vec3(0.0,0.0,-deltaPos));
		
		float xDelta = ((h1-h0)+(h0-h2))/deltaPos;
		float yDelta = ((h3-h0)+(h0-h4))/deltaPos;
		
		vec3 newnormal = normalize(vec3(xDelta,yDelta,1.0-xDelta*xDelta-yDelta*yDelta));
		
		vec4 frag2;
			 frag2 = vec4((normal) * 0.5f + 0.5f, 1.0f);			
		float NdotE = pow(abs(dot(normal,normalize(position.xyz))),2.0);
		
		if (iswater == 1.0) {
		
			vec3 bump = newnormal;
			bump = bump;
				
			float bumpmult = 0.04;	
			
			bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
			mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
								tangent.y, binormal.y, normal.y,
								tangent.z, binormal.z, normal.z);
			
			frag2 = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
			
		}
	
	#endif 
	
	gl_FragData[0] = tex;
	
	#ifdef WATER_HEIGHTMAP
		gl_FragData[1] = frag2;	
	#endif
	
	gl_FragData[2] = vec4(lmcoord.t, mix(1.0,0.05,iswater), lmcoord.s, 1.0);
	gl_FragData[3] = vec4(vec3(0.0), 1.0);
}