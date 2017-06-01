#version 120

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

	#define SHADOW_MAP_BIAS 0.85

	#define WAVING_TERRAIN









	
	

//////////////////////////////////////////////////////////////
////////////////////////// CONSTS ////////////////////////////
//////////////////////////////////////////////////////////////

const float PI = 3.1415927;

//////////////////////////////////////////////////////////////
//////////////////////// GET MATERIAL ////////////////////////
//////////////////////////////////////////////////////////////

varying vec4 texcoord;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform vec3 cameraPosition;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform int worldTime;
uniform float frameTimeCounter;
uniform float rainStrength;

float timefract = worldTime;
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

float pi2wt = PI*2*(frameTimeCounter*24);

vec3 calcWave(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {
    vec3 ret;
    float magnitude,d0,d1,d2,d3;
    magnitude = sin(pi2wt*fm + pos.x*0.5 + pos.z*0.5 + pos.y*0.5) * mm + ma;
    d0 = sin(pi2wt*f0);
    d1 = sin(pi2wt*f1);
    d2 = sin(pi2wt*f2);
    ret.x = sin(pi2wt*f3 + d0 + d1 - pos.x + pos.z + pos.y) * magnitude;
    ret.z = sin(pi2wt*f4 + d1 + d2 + pos.x - pos.z + pos.y) * magnitude;
	ret.y = sin(pi2wt*f5 + d2 + d0 + pos.z + pos.y - pos.y) * magnitude;
    return ret;
}

vec3 calcMove(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWave(pos      , 0.0027, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
	vec3 move2 = calcWave(pos+move1, 0.0348, 0.0400, 0.0400, f0, f1, f2, f3, f4, f5) * amp2;
	
	float day = 1.0 * (TimeSunrise + TimeNoon + TimeSunset);
	float night = 0.5 * TimeMidnight; 
	float rain = rainStrength * 1.5;
	
	float strength = day + night + rain;
	
	move1 *= strength;
	move2 *= strength;
    return move1+move2;
}

vec3 calcWaterMove(in vec3 pos) {
	float fy = fract(pos.y + 0.001);
	if (fy > 0.002) {
		float wave = 0.05 * sin(2*PI/4*frameTimeCounter + 2*PI*2/16*pos.x + 2*PI*5/16*pos.z)
				   + 0.05 * sin(2*PI/3*frameTimeCounter - 2*PI*3/16*pos.x + 2*PI*4/16*pos.z);
		return vec3(0, clamp(wave, -fy, 1.0-fy), 0);
	} else {
		return vec3(0);
	}
}











//////////////////////////////////////////////////////////////
/////////////////////////// MAIN /////////////////////////////
//////////////////////////////////////////////////////////////

void main() {

	gl_Position = ftransform();
	float istopv = 0.0;
	
	if (gl_MultiTexCoord0.t < mc_midTexCoord.t) istopv = 1.0;
	vec4 position = gl_Position;

	 position = shadowProjectionInverse * position;
	 position = shadowModelViewInverse * position;
	 position.xyz += cameraPosition.xyz;

	#ifdef WAVING_TERRAIN
		
		// Leaves
		if ( mc_Entity.x == 18.0 || mc_Entity.x == 161.0) position.xyz += calcMove(position.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(0.5,0.2,0.5), vec3(0.2,0.1,0.2));
		
		// Lillypads
		if ( mc_Entity.x == 111.0 ) position.xyz += calcMove(position.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(0.0,0.0,0.0), vec3(0.4,0.0,0.4));

		// Vines
		if ( mc_Entity.x == 106.0 ) position.xyz += calcMove(position.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0,0.2,1.0), vec3(0.5,0.1,0.5));
		
		// Large Grass
		if ( mc_Entity.x == 175.0) position.xyz += calcMove(position.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(0.3,0.15,0.3), vec3(0.15,0.07,0.15));

		if (istopv > 0.9) {

			// Grass
			if ( mc_Entity.x == 31.0 ) position.xyz += calcMove(position.xyz, 0.0041, 0.0070, 0.0044, 0.0038, 0.0063, 0.0000, vec3(1.0,0.8,1.0), vec3(0.4,0.4,0.4));

			// Flowers
			if (mc_Entity.x == 37.0 || mc_Entity.x == 38.0) position.xyz += calcMove(position.xyz, 0.0041, 0.005, 0.0044, 0.0038, 0.0240, 0.0000, vec3(0.8,0.0,0.8), vec3(0.4,0.0,0.4));

			// Wheat, Carrots, Potatoes
			if ( mc_Entity.x == 59.0) position.xyz += calcMove(position.xyz, 0.0041, 0.0070, 0.0044, 0.0038, 0.0240, 0.0000, vec3(0.8,0.2,0.8), vec3(0.4,0.1,0.4));
			if ( mc_Entity.x == 141.0) position.xyz += calcMove(position.xyz, 0.0041, 0.0070, 0.0044, 0.0038, 0.0240, 0.0000, vec3(0.8,0.2,0.8), vec3(0.4,0.1,0.4));
			if ( mc_Entity.x == 142.0) position.xyz += calcMove(position.xyz, 0.0041, 0.0070, 0.0044, 0.0038, 0.0240, 0.0000, vec3(0.8,0.2,0.8), vec3(0.4,0.1,0.4));

			// Fire
			if ( mc_Entity.x == 51.0) position.xyz += calcMove(position.xyz, 0.0105, 0.0096, 0.0087, 0.0063, 0.0097, 0.0156, vec3(1.2,0.4,1.2), vec3(0.8,0.8,0.8));

		}
	
	#endif
	
	position.xyz -= cameraPosition.xyz;
	position = shadowModelView * position;
	position = shadowProjection * position;
	
	gl_Position = position;

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	gl_Position.xy *= 1.0f / distortFactor;
	
	texcoord = gl_MultiTexCoord0;

	gl_FrontColor = gl_Color;
	
}
