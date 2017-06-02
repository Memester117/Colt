#version 120

//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES

#define ENTITY_LEAVES        18.0
#define ENTITY_VINES        106.0
#define ENTITY_TALLGRASS     31.0
#define ENTITY_DANDELION     37.0
#define ENTITY_ROSE          38.0
#define ENTITY_WHEAT         59.0
#define ENTITY_LILYPAD      111.0
#define ENTITY_FIRE          51.0
#define ENTITY_LAVAFLOWING   10.0
#define ENTITY_LAVASTILL     11.0
#define ENTITY_LEAVES2		161.0
#define ENTITY_NEWFLOWERS	175.0
#define ENTITY_NETHER_WART	115.0
#define ENTITY_DEAD_BUSH	 32.0
#define ENTITY_CARROT		141.0
#define ENTITY_POTATO		142.0
#define ENTITY_COBWEB		 30.0

//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES

#define SHADOW_MAP_BIAS 0.9

const float PI = 3.1415927;

varying vec4 texcoord;
varying vec4 color;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform vec3 cameraPosition;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;

uniform int worldTime;

	float timefract = worldTime;

	float TimeSunrise  = ((clamp(timefract, 23000.0f, 25000.0f) - 23000.0f) / 1000.0f) + (1.0f - (clamp(timefract, 0.0f, 2000.0f)/2000.0f));
	float TimeNoon     = ((clamp(timefract, 0.0f, 2000.0f)) / 2000.0f) - ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f);
	float TimeSunset   = ((clamp(timefract, 9000.0f, 12000.0f) - 9000.0f) / 3000.0f) - ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f);
	float TimeMidnight = ((clamp(timefract, 12000.0f, 12750.0f) - 12000.0f) / 750.0f) - ((clamp(timefract, 23000.0f, 24000.0f) - 23000.0f) / 1000.0f);


float rainx = clamp(rainStrength, 0.0, 1.0);

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
    return move1+move2;
}
/*
vec3 calcWave(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5)
{
    vec3 ret;
    float magnitude,d0,d1,d2,d3;
    magnitude = sin(pi2ft*fm + pos.x*0.5 + pos.z*0.5 + pos.y*0.5) * mm + ma;
    d0 = sin(pi2ft*f0);
    d1 = sin(pi2ft*f1);
    d2 = sin(pi2ft*f2);
    ret.x = sin(pi2ft*f3 + d0 + d1 - pos.x + pos.z + pos.y) * magnitude;
    ret.z = sin(pi2ft*f4 + d1 + d2 + pos.x - pos.z + pos.y) * magnitude;
	ret.y = sin(pi2ft*f5 + d2 + d0 + pos.z + pos.y - pos.y) * magnitude;
    return ret;
}

vec3 calcMove(in vec3 pos, in float f1, in float f2, in float f3, in float f4, in vec3 amp1, in vec3 amp2)
{
/*
    const vec3 v1 = vec3( 2.0/16.0,2.0/16.0,2.0/16.0);
	const vec3 v2 = vec3(-3.0/16.0,3.0/16.0,3.0/16.0);
	float pi2t = PI*frameTimeCounter;
	float s1 = sin(pi2t*f1 + dot(2*PI*v1,pos));
	float s2 = sin(pi2t*f2 + dot(2*PI*v2,pos));
	vec3 move1 = (normalize(v1)*s1 + normalize(v2)*s2)*amp1*2.5;
	pos += move1;
    const vec3 v3 = vec3( 5.0/16.0,5.0/16.0,6.0/16.0);
	const vec3 v4 = vec3(-6.0/16.0,5.0/16.0,5.0/16.0);
	float s3 = sin(pi2t*f3 + dot(2*PI*v3,pos));
	float s4 = sin(pi2t*f4 + dot(2*PI*v4,pos));
	vec3 move2 = (normalize(v3)*s3 + normalize(v4)*s4)*(abs(s1*s2)*0.6+0.4)*amp2*2.5;
    return move1+move2;


}
*/
vec3 calcWaterMove(in vec3 pos)
{
	float fy = fract(pos.y + 0.001);
	if (fy > 0.002)
	{
		float wave = 0.05 * sin(2*PI/4*frameTimeCounter + 2*PI*2/16*pos.x + 2*PI*5/16*pos.z)
				   + 0.05 * sin(2*PI/3*frameTimeCounter - 2*PI*3/16*pos.x + 2*PI*4/16*pos.z);
		return vec3(0, clamp(wave, -fy, 1.0-fy), 0);
	}
	else
	{
		return vec3(0);
	}
}

float getTransparent(){

	if (mc_Entity.x == 174.0 || mc_Entity.x == 79.0 || mc_Entity.x == 95.0 || mc_Entity.x == 160.0) {
		return 1.0;
	} return 0.0;

}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	gl_Position = ftransform();
	vec2 lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	float underCover = lmcoord.t;

	vec4 position = gl_Position;

	position = shadowProjectionInverse * position;
	position = shadowModelViewInverse * position;

	vec3 worldpos = position.xyz + cameraPosition;
	float mat = 1.0f;
	float istopv = 0.0;
	//texcoord = gl_MultiTexCoord0.xy;
	if (gl_MultiTexCoord0.t < mc_midTexCoord.t) istopv = 1.0;

	underCover = pow(underCover, 15.0);

	if ( mc_Entity.x == ENTITY_LEAVES || mc_Entity.x == ENTITY_LEAVES2 || mc_Entity.x == ENTITY_NEWFLOWERS ) {
				position.xyz += calcMove(worldpos.xyz, 0.0030, 0.0054, 0.0033, 0.0025, 0.0017, 0.0031,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.0,0.0,0.0+rainx*+1.0 +TimeMidnight*-1.0))*underCover;
				}

		if ( mc_Entity.x == ENTITY_VINES ) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5+rainx*+1.0 +TimeMidnight*-1.0))*underCover;
				}

		if ( mc_Entity.x == ENTITY_COBWEB ) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5+rainx*+1.0 +TimeMidnight*-1.0))*underCover * 0.1;
				}

		if (istopv > 0.9) {

		if ( mc_Entity.x == ENTITY_TALLGRASS) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(2.5,1.1,2.5+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.0,0.0,0.0+rainx*+1.0 +TimeMidnight*-1.0))*underCover;
				}

		if ((mc_Entity.x == ENTITY_DANDELION || mc_Entity.x == ENTITY_ROSE)) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5+rainx*+1.0 +TimeMidnight*-1.0))*underCover;
				}

		if ( mc_Entity.x == ENTITY_WHEAT) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5+rainx*+1.0 +TimeMidnight*-1.0))*underCover;
				}

		if ( mc_Entity.x == ENTITY_FIRE) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5+rainx*+1.0 +TimeMidnight*-1.0))*underCover;
				}

		if ( mc_Entity.x == ENTITY_NETHER_WART ) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5+rainx*+1.0 +TimeMidnight*-1.0))*underCover;
				}

		if ( mc_Entity.x == ENTITY_DEAD_BUSH ) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5+rainx*+1.0 +TimeMidnight*-1.0))*underCover;
				}

		if ( mc_Entity.x == ENTITY_CARROT || mc_Entity.x == ENTITY_POTATO) {
				position.xyz += calcMove(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041,vec3(1.0,0.2,1.0+rainx*+1.0 +TimeMidnight*-1.0), vec3(0.5,0.1,0.5+rainx*+1.0 +TimeMidnight*-1.0))*underCover;
				}

		}

	float movemult = 0.0;

	if ( mc_Entity.x == ENTITY_LAVAFLOWING || mc_Entity.x == ENTITY_LAVASTILL ) {
			mat = 0.4;
			position.xyz += calcWaterMove(worldpos.xyz) * 0.25;
			}
	if ( mc_Entity.x == ENTITY_LILYPAD ) {
			position.xyz += calcWaterMove(worldpos.xyz);
			mat = 0.4;
			}

	if (mc_Entity.x == ENTITY_CARROT || mc_Entity.x == ENTITY_COBWEB || mc_Entity.x == ENTITY_DANDELION || mc_Entity.x == ENTITY_DEAD_BUSH || mc_Entity.x == ENTITY_FIRE || mc_Entity.x == ENTITY_LEAVES || mc_Entity.x == ENTITY_LEAVES2
	 || mc_Entity.x == ENTITY_LILYPAD || mc_Entity.x == ENTITY_NETHER_WART || mc_Entity.x == ENTITY_NEWFLOWERS || mc_Entity.x == ENTITY_POTATO || mc_Entity.x == ENTITY_ROSE || mc_Entity.x == ENTITY_TALLGRASS || mc_Entity.x == ENTITY_VINES
	 || mc_Entity.x == ENTITY_WHEAT || mc_Entity.x == 83.0)
	mat = 0.4;

	if (mc_Entity.x == 50.0 || mc_Entity.x == 62.0 || mc_Entity.x == 76.0 || mc_Entity.x == 91.0 || mc_Entity.x == 89.0 || mc_Entity.x == 124.0 || mc_Entity.x == 138.0 || mc_Entity.x == 169.0) mat = 0.6;

	position = shadowModelView * position;
	position = shadowProjection * position;

	color = gl_Color;

	if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0 || mc_Entity.x == 97.0 || mc_Entity.x == 95.0 || mc_Entity.x == 160.0)
	position *= 0.0;

	gl_Position = position;

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;

	gl_Position.xy *= 1.0f / distortFactor;

	texcoord = gl_MultiTexCoord0;
}
