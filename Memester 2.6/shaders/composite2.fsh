#version 120
#extension GL_ARB_shader_texture_lod : enable
/* DRAWBUFFERS:3 */
/*
 		
*/

#define Bloom //Makes lightsources more glowy, is only enabled during night-time or in dark areas. Medium performance impact.

/*--------------------------------*/
const bool gaux2MipmapEnabled = true;
uniform sampler2D gaux2;
varying vec4 texcoord;
uniform float aspectRatio;
uniform ivec2 eyeBrightness;
uniform float rainStrength;
uniform int worldTime;
float time = float(worldTime);
float night = clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-22800.0)/200.0,0.0,1.0);
/*--------------------------------*/

void main() {

#ifdef Bloom
vec3 blur = vec3(0.0);
float GetLight;
if(night < 0.1 && rainStrength < 0.1)GetLight = (eyeBrightness.y/1572.0);
if(GetLight < 0.1){
const float rMult = 0.0025;
const int nSteps = 15;
int center = (nSteps-1)/2;
float sigma = 0.3;
float tw = 0.0;

for (int i = 0; i < nSteps; i++) {
	float dist = (i-float(center))/center;
	float weight = exp(-(dist*dist)/(2.0*sigma));
	vec3 bsample= max(pow(texture2DLod(gaux2,texcoord.xy + rMult*vec2(1.0,aspectRatio)*vec2(i-center,0.0),2).rgb,vec3(2.2)),0.0);
	blur += bsample*(pow(length(bsample),0.75))*weight;
	tw += weight;
	}
blur /= tw;
blur = clamp(pow(blur,vec3(1.0/2.2)),0.0,1.0);
}
#endif

#ifdef Bloom
	gl_FragData[0] = vec4(blur,1.0);
#else
	gl_FragData[0] = vec4(0.0);
#endif	
}
