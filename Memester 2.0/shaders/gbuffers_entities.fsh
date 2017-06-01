#version 120

/* DRAWBUFFERS:024 */

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
////////////////////// ADJUSTABLE CONSTS /////////////////////
//////////////////////////////////////////////////////////////

const int GL_EXP = 2048;
const int GL_LINEAR = 9729;
const int MAX_OCCLUSION_POINTS = 20;
const float MAX_OCCLUSION_DISTANCE = 100.0;
const float bump_distance = 64.0;			// Bump render distance: tiny = 32, short = 64, normal = 128, far = 256.
const float fademult = 0.1;











//////////////////////////////////////////////////////////////
//////////////////////// GET MATERIAL ////////////////////////
//////////////////////////////////////////////////////////////

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 normal;
varying float translucent;
varying float distance;

uniform sampler2D texture;











//////////////////////////////////////////////////////////////
/////////////////////////// MAIN /////////////////////////////
//////////////////////////////////////////////////////////////

void main() {	
	
	vec2 adjustedTexCoord = texcoord.st;
	
	float texinterval = 0.0625f;
	
	vec3 indlmap = texture2D(texture,adjustedTexCoord).rgb*color.rgb;
	
	gl_FragData[0] = vec4(indlmap,texture2D(texture,adjustedTexCoord).a*color.a);
	
	vec4 frag2 = vec4((normal) * 0.5f + 0.5f, 1.0f);		
	
	gl_FragData[1] = frag2;	
	//x = specularity / y = land(0.0/1.0)/shadow early exit(0.2)/water(0.05) / z = torch lightmap
	gl_FragData[2] = vec4(lmcoord.t, 1.0f, lmcoord.s, 1.0f);
	
}