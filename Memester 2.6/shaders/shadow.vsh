#version 120
/*
 
*/

#define SHADOW_MAP_BIAS 0.85

varying vec4 texcoord;

void main() {
	gl_Position = ftransform();

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	
	gl_Position.xy *= 1.0f / distortFactor;
	
	texcoord = gl_MultiTexCoord0;

	gl_FrontColor = gl_Color;
}
