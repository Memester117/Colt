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
////////////////////////// CONSTS ////////////////////////////
//////////////////////////////////////////////////////////////

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

//////////////////////////////////////////////////////////////
//////////////////////// GET MATERIAL ////////////////////////
//////////////////////////////////////////////////////////////

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 normal;

uniform sampler2D texture;
uniform int fogMode;
uniform float rainStrength;

float rainx = clamp(rainStrength, 0.0f, 1.0f)/1.0f;











//////////////////////////////////////////////////////////////
/////////////////////////// MAIN /////////////////////////////
//////////////////////////////////////////////////////////////

void main() {
	
	vec4 tex = texture2D(texture, texcoord.st);
	
/* DRAWBUFFERS:04 */
	
	vec3 indlmap = texture2D(texture,texcoord.xy).rgb*color.rgb;
	
	gl_FragData[0] = vec4(indlmap,texture2D(texture,texcoord.xy).a*color.a);
	//x = specularity / y = land(0.0/1.0)/shadow early exit(0.2)/water(0.05) / z = torch lightmap
	gl_FragData[1] = vec4(lmcoord.t, 0.4, lmcoord.s, 1.0);
	
}