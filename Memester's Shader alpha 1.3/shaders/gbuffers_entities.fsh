#version 120

/*
 _______ _________ _______  _______  _
(  ____ \\__   __/(  ___  )(  ____ )( )
| (    \/   ) (   | (   ) || (    )|| |
| (_____    | |   | |   | || (____)|| |
(_____  )   | |   | |   | ||  _____)| |
      ) |   | |   | |   | || (      (_)
/\____) |   | |   | (___) || )       _
\_______)   )_(   (_______)|/       (_)

Do not modify this code until you have read the LICENSE.txt contained in the root directory of this shaderpack!

*/

///////////////////////////////////////////////////END OF ADJUSTABLE VARIABLES///////////////////////////////////////////////////

/* DRAWBUFFERS:01235 */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform vec4 entityColor;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

varying vec3 normal;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

const float bump_distance = 78.0f;
const float fademult = 0.1f;

void main() {
	//store lightmap in auxilliary texture. r = torch light. g = lightning. b = sky light.
	vec4 lightmap = vec4(0.0f, 0.0f, 0.0f, 1.0f);

	//Separate lightmap types
	lightmap.r = clamp((lmcoord.s * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	lightmap.b = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);

	lightmap.b = pow(lightmap.b, 1.0f);
	lightmap.r = pow(lightmap.r, 3.0f);

	vec4 frag2 = vec4((normal) * 0.5f + 0.5f, 1.0f);

	//Diffuse
	vec4 albedo = texture2D(texture, texcoord.st) * color;
	albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.aaa);

	gl_FragData[0] = albedo;

	//Depth
	gl_FragData[1] = vec4(1.0f/255.0f, lightmap.r, lightmap.b, 1.0f);

	//normal
	gl_FragData[2] = frag2;

	//specularity
	gl_FragData[3] = vec4(0.0f, 0.0f, 0.0f, 1.0f);

	gl_FragData[4] = frag2;

}
