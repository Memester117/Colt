#version 120
/*

*/


varying vec4 texcoord;

uniform sampler2D tex;

void main() {
	gl_FragData[0] = texture2D(tex,texcoord.xy);
}