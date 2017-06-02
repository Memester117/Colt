#version 120

/*
Read Mine and Chocapic13's terms of mofification/sharing before changing something below please!
ﯼᵵᴀᵶᵶᴬﺤ super Shaders (ﯼ✗∃), derived from Chocapic13 v4 Beta 4.8
Place two leading Slashes in front of the following '#define' lines in order to disable an option.
*/

varying vec4 color;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	color = gl_Color;

	vec4 viewVertex = gl_ModelViewMatrix * gl_Vertex;

	gl_Position = gl_ProjectionMatrix * viewVertex;

	gl_FogFragCoord = gl_Position.z;
}