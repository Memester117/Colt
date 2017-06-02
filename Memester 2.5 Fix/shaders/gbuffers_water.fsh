#version 120
/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

/* DRAWBUFFERS:024 */

//ADJUSTABLE VARIABLES//
	
	//#define Watercolor_Tropical							//Weak green-ish water.Only enable one.
	//#define Watercolor_Legacy								//Strong blue water.Only enable one.
	//#define Watercolor_Classic							//Weak light blue water.Only enable one.
	#define Watercolor_Original								//Strong dark blue water.Only enable one.
		
//ADJUSTABLE VARIABLES//

const int MAX_OCCLUSION_POINTS = 20;
const float MAX_OCCLUSION_DISTANCE = 100.0;
const float bump_distance = 64.0;				//Bump render distance: tiny = 32, short = 64, normal = 128, far = 256
const float pom_distance = 32.0;				//POM render distance: tiny = 32, short = 64, normal = 128, far = 256
const float fademult = 0.1;
const float PI = 3.1415927;

varying vec4 color;
varying vec2 texcoord;
varying vec2 lmcoord;
varying vec3 binormal;
varying vec3 normal;
varying vec3 tangent;
varying vec3 wpos;
varying float iswater;

uniform sampler2D texture;
uniform sampler2D noisetex;
uniform int worldTime;
uniform int isEyeInWater;
uniform float far;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

	float rainx = clamp(rainStrength, 0.0f, 1.0f)/1.0f;

vec2 dx = dFdx(texcoord.xy);
vec2 dy = dFdy(texcoord.xy);

float wave(float n) {
return sin(2 * PI * (n));
}

float getnoise(vec2 pos) {
	return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
}

float waterH(vec3 posxz) {

vec3 waterpos = posxz;

float speed = 2;
float size = 4;

float noise = 0;

float noisesize = 32*size;
float noiseweight = 0;
float noiseneg = 1;

float noisea = 1;
for (int i = 0; i < 2; i++) {
noisea += texture2D(noisetex,vec2(waterpos.x,waterpos.z)/noisesize*0.1+vec2(frameTimeCounter/1000*speed,0)).r*i*noiseneg;
noiseweight += i;
noiseneg *= -1;
noisesize /= 2;
}
noisea /= noiseweight;

noisesize = 16*size;
noiseweight = 0;

float noiseb = 1;
for (int i = 0; i < 2; i++) {
noiseb += texture2D(noisetex,vec2(-waterpos.x,waterpos.z)/noisesize*0.1+vec2(0,frameTimeCounter/1000*speed)).r*i*noiseneg;
noiseweight += i;
noiseneg *= -1;
noisesize /= 2;
}
noiseb /= noiseweight;

noisesize = 64*size;
noiseweight = 0;

float noisec = 1;
for (int i = 0; i < 2; i++) {
noisec += texture2D(noisetex,vec2(posxz.x,-posxz.z)/noisesize*0.1+vec2(-frameTimeCounter/1000*speed,0)).r*i*noiseneg;
noiseweight += i;
noiseneg *= -1;
noisesize /= 2;
}
noisec /= noiseweight;

noisesize = 48*size;
noiseweight = 0;

float noised = 1;
for (int i = 0; i < 2; i++) {
noised += texture2D(noisetex,vec2(-posxz.x,-posxz.z)/noisesize*0.1+vec2(0,-frameTimeCounter/1000*speed)).r*i*noiseneg;
noiseweight += i;
noiseneg *= -1;
noisesize /= 2;
}
noised /= noiseweight;

noise = (noisea*noiseb + noiseb*noisec + noisec*noised + noised*noisea) * (1- noisea*noiseb*noisec*noised)/2;


float wave = 0;
	wave = sin(posxz.x+frameTimeCounter*0.5)*cos(posxz.z+frameTimeCounter*0.5);
	wave += sin(posxz.x/1.5-frameTimeCounter)*cos(posxz.z/1.5+frameTimeCounter);
	wave += sin(posxz.x/2+frameTimeCounter*1.5)*cos(posxz.z/2-frameTimeCounter*1.5);
	wave += sin(posxz.x/2.5-frameTimeCounter*2)*cos(posxz.z/2.5-frameTimeCounter*2);
	wave /= 4;


return noise+wave;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	
	#ifdef Watercolor_Tropical
	vec3 watercolor = vec3(0.1,0.5,0.6);
	float wateropacity = 0.4;
	#endif
	
	#ifdef Watercolor_Legacy
	vec3 watercolor = vec3(0.0,0.3,0.7);
	float wateropacity = 0.7;
	#endif
	
	#ifdef Watercolor_Classic
	vec3 watercolor = vec3(0.1,0.4,0.7);
	float wateropacity = 0.4;
	#endif
	
	#ifdef Watercolor_Original
	vec3 watercolor = vec3(0.02,0.08,0.14);
	float wateropacity = 0.8;
	#endif
	
	vec4 raw = texture2D(texture, texcoord.xy);
	vec4 tex = vec4(vec3(raw.b + (raw.r+raw.g)),wateropacity*(1-isEyeInWater*0.7));
	tex *= vec4(watercolor,1);
	if (iswater < 0.9){
	tex = texture2D(texture, texcoord.xy)*color;
	//tex.a = floor(tex.a+0.5);
	}
	
	vec3 posxz = wpos.xyz;

	posxz.x += sin(posxz.z+frameTimeCounter)*0.25;
	posxz.z += cos(posxz.x+frameTimeCounter)*0.25;
	
	float deltaPos = 0.4;
	float h0 = waterH(posxz);
	float h1 = waterH(posxz + vec3(deltaPos,0.0,0.0));
	float h2 = waterH(posxz + vec3(-deltaPos,0.0,0.0));
	float h3 = waterH(posxz + vec3(0.0,0.0,deltaPos));
	float h4 = waterH(posxz + vec3(0.0,0.0,-deltaPos));
	
	float xDelta = ((h1-h0)+(h0-h2))/deltaPos;
	float yDelta = ((h3-h0)+(h0-h4))/deltaPos;
	
	vec3 newnormal = normalize(vec3(xDelta,yDelta,1.0-xDelta*xDelta-yDelta*yDelta));
	newnormal = newnormal + (xDelta*yDelta) / (sin(xDelta) + cos(yDelta)+frameTimeCounter);
	
	vec4 frag2;
		frag2 = vec4((normal) * 0.5f + 0.5f, 1.0f);		
		
	if (iswater > 0.9) {
		vec3 bump = newnormal;
			bump = bump;
			
		
		float bumpmult = 0.03;	
		
		bump = 	bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							tangent.y, binormal.y, normal.y,
							tangent.z, binormal.z, normal.z);
		
		frag2 = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	}
	gl_FragData[0] = tex;
	gl_FragData[1] = frag2;	
	gl_FragData[2] = vec4(lmcoord.t, mix(1.0,0.05,iswater), lmcoord.s, 1.0);
}