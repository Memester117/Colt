#version 120

/*
Read Mine and Chocapic13's terms of mofification/sharing before changing something below please!
ﯼᵵᴀᵶᵶᴬﺤ super Shaders (ﯼ✗∃), derived from Chocapic13 v4 Beta 4.8
Place two leading Slashes in front of the following '#define' lines in order to disable an option.
*/

/* DRAWBUFFERS:0 */

varying vec4 color;
varying vec4 texcoord;
varying vec3 normal;

uniform int worldTime;
uniform sampler2D texture;
uniform float rainStrength;
uniform int fogMode;

const int FOGMODE_LINEAR = 9729;
const int FOGMODE_EXP = 2048;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	
	gl_FragData[0] = vec4(0.0,0.0,.0,1.0);

}