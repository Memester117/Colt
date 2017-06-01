#version 120
#extension GL_ARB_shader_texture_lod : enable 

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
///////////////////// ADJUSTABLE FEATURES ////////////////////
//////////////////////////////////////////////////////////////

	//#define PARALLAX_OCCLUSION_MAPPING

	
	
	
	
	
	
	
	
	
	
//////////////////////////////////////////////////////////////
////////////////////////// CONSTS ////////////////////////////
//////////////////////////////////////////////////////////////

const float normalMapMaxAngle	   = 1.0;
const float pomMapResolution 	   = 64.0;
const float pomDepth			   = 7.0;

const int RGBA16 				   = 3;
const int RGB16 				   = 2;
const int RGBA8 				   = 1;
const int R8 					   = 0;

const int gdepthFormat 			   = R8;
const int gnormalFormat 		   = RGB16;
const int compositeFormat 		   = RGBA16;
const int gaux2Format 			   = RGBA16;
const int gcolorFormat 			   = RGBA8;

const float MAX_OCCLUSION_DISTANCE = 32.0;
const float MIX_OCCLUSION_DISTANCE = 28.0;
const int   MAX_OCCLUSION_POINTS   = 12;

const vec3 intervalMult = vec3(1.0, 1.0, 1.0 / (1.0 / pomDepth)) / pomMapResolution * 1.0; 

//////////////////////////////////////////////////////////////
//////////////////////// GET MATERIAL ////////////////////////
//////////////////////////////////////////////////////////////

varying vec2 lmcoord;
varying vec4 color;
varying float mat;
varying vec2 texcoord;
varying vec3 tangent;
varying vec3 normal;
varying vec3 binormal;
varying vec3 viewVector;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;
varying float dist;

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform int fogMode;
uniform int worldTime;
uniform float wetness;

float totalspec = 0.0;
float wetx = clamp(wetness, 0.0f, 1.0)/1.0;

const float mincoord = 1.0/4096.0;
const float maxcoord = 1.0-mincoord;

vec2 dcdx = dFdx(vtexcoord.st*vtexcoordam.pq);
vec2 dcdy = dFdy(vtexcoord.st*vtexcoordam.pq);

vec4 readTexture(in vec2 coord) {
	return texture2DGradARB(texture,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}

vec4 readNormal(in vec2 coord) {
	return texture2DGradARB(normals,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}











//////////////////////////////////////////////////////////////
/////////////////////////// MAIN /////////////////////////////
//////////////////////////////////////////////////////////////

void main() {
	
	vec2 adjustedTexCoord;
	adjustedTexCoord = vtexcoord.st * vtexcoordam.pq + vtexcoordam.st;
		
	vec4 c = mix(color,vec4(1.0),float(mat > 0.58 && mat < 0.62));		//fix weird lightmap bug on emissive blocks
		
	#ifdef PARALLAX_OCCLUSION_MAPPING
	
		if (dist < MAX_OCCLUSION_DISTANCE) {
			
			if ( viewVector.z < 0.0 && readNormal(vtexcoord.st).a < 0.99 && readNormal(vtexcoord.st).a > 0.01) {
				vec3 interval = viewVector.xyz * intervalMult;
				vec3 coord = vec3(vtexcoord.st, 1.0);
				
				for (int loopCount = 0; (loopCount < MAX_OCCLUSION_POINTS) && (readNormal(coord.st).a < coord.p); ++loopCount) {
					coord = coord+interval;
				}
			
				// Don't wrap around top of tall grass/flower
				if (coord.t < mincoord) {
					if (readTexture(vec2(coord.s,mincoord)).a == 0.0) {
						coord.t = mincoord;
						discard;
					}
				}
			
				adjustedTexCoord = mix(fract(coord.st)*vtexcoordam.pq+vtexcoordam.st , adjustedTexCoord , max(dist-MIX_OCCLUSION_DISTANCE,0.0)/(MAX_OCCLUSION_DISTANCE-MIX_OCCLUSION_DISTANCE));
			
			}
		
		}
	
	#endif
		
	vec3 specularity = texture2DGradARB(specular, adjustedTexCoord.st, dcdx, dcdy).rgb;
	float atten = 1.0-(specularity.b)*0.86;

	vec4 frag2 = vec4(normal, 1.0f);
		
	vec3 bump = texture2DGradARB(normals, adjustedTexCoord.st, dcdx, dcdy).rgb*2.0-1.0;
					
	float bumpmult = normalMapMaxAngle * (1.0-wetness*lmcoord.t*0.65)*atten;
		
	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
				
	frag2 = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);

	
/* DRAWBUFFERS:0246 */

	gl_FragData[0] = texture2DGradARB(texture, adjustedTexCoord.st, dcdx, dcdy) * c;
	gl_FragData[1] = frag2;	
	gl_FragData[2] = vec4(lmcoord.t, mat, lmcoord.s, 1.0);
	gl_FragData[3] = texture2DGradARB(specular, adjustedTexCoord.st, dcdx, dcdy);
	
}