#version 120

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

//disabling is done by adding "//" to the beginning of a line.

//ADJUSTABLE VARIABLES//

//ADJUSTABLE VARIABLES//

varying vec4 color;
varying vec2 texcoord;
varying vec2 lmcoord;
varying vec3 binormal;
varying vec3 normal;
varying vec3 tangent;
varying vec3 wpos;
varying float iswater;

attribute vec4 mc_Entity;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform int worldTime;
uniform float frameTimeCounter;
uniform int isEyeInWater;

const float PI = 3.1415927;

float calcWaterMove0(vec3 pos){
float speed = 2;
float size = 2;
float wave = 0;
float wave1 = (sin(pos.x*size+frameTimeCounter*speed) + cos(pos.z*size+frameTimeCounter*speed))/2;
float wave2 = (sin(pos.x*size/2+frameTimeCounter*speed/3+30) + cos(pos.z*size/2+frameTimeCounter*speed/3+30))/2;
float wave3 = (sin(pos.x*size/1.5+frameTimeCounter*speed*2+70) + cos(pos.z*size/1.5+frameTimeCounter*speed*2+70))/2;
float wave4 = (sin(pos.x*size/2.5+frameTimeCounter*speed*1.4+120) + cos(pos.z*size/2.5+frameTimeCounter*speed*1.4+120))/2;
float mult1 = sin(frameTimeCounter*speed);
float mult2 = cos(frameTimeCounter*speed);
float mult3 = sin(frameTimeCounter*speed+PI/4);
float mult4 = cos(frameTimeCounter*speed+PI/4);
wave = (wave1*mult1+wave2*mult2+wave3*mult3+wave4*mult4)/4;
return wave;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	
	//vec4 viewpos = gl_ModelViewMatrix * gl_Vertex;
	vec4 position = gl_ModelViewMatrix * gl_Vertex;
	iswater = 0.0f;
	float displacement = 0.0;
	
	/* un-rotate */
	vec4 viewpos = gbufferModelViewInverse * position;

	vec3 worldpos = viewpos.xyz + cameraPosition;
	wpos = worldpos;
	



	if(mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
		iswater = 1.0;
		float fy = fract(worldpos.y + 0.001);
		
		float wave = calcWaterMove0(worldpos)*0.1;
		displacement = wave;
		viewpos.y += displacement;	
	}
	
	/* re-rotate */
	viewpos = gbufferModelView * viewpos;

	/* projectify */
	gl_Position = gl_ProjectionMatrix * viewpos;
	
	color = gl_Color;
	
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;

	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	
	gl_FogFragCoord = gl_Position.z;
	
	tangent = vec3(0.0);
	binormal = vec3(0.0);
	normal = normalize(gl_NormalMatrix * normalize(gl_Normal));

	if (gl_Normal.x > 0.5) {
		//  1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, -1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}
	
	else if (gl_Normal.x < -0.5) {
		// -1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}
	
	else if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	}
	
	else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	}
	
	else if (gl_Normal.z > 0.5) {
		//  0.0,  0.0,  1.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}
	
	else if (gl_Normal.z < -0.5) {
		//  0.0,  0.0, -1.0
		tangent  = normalize(gl_NormalMatrix * vec3(-1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}
	

}