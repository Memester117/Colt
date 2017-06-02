#version 120

#define MAX_COLOR_RANGE 48.0
/*
!! DO NOT REMOVE !!
BSL Shaders is derived from Chocapic13 v5 test 2

This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

/*
Disable an effect by putting "//" before "#define" when there is no number after
You can tweak the numbers, the impact on the shaders is self-explained in the variable's name or in a comment
*/

//ADJUSTABLE VARIABLES//

//SHADOWS
	const int shadowMapResolution = 1024;					//shadowmap resolution
	const float shadowDistance = 96.0;						//draw distance of shadows
	
//LIGHTING
	#define Lighting_SunlightVal 1.5						//Change sunlight strength. 2 is default
	const float Lighting_Darkness = 0.2;					//Shadow darkness levels. lower values mean darker shadows, 0.3 is default
	const float Lighting_Brightness = 0.6;					//Sky brightness levels. lower values mean darker sky, 0.6 is default
	
	#define TorchColor 0.7,0.27,0.04 						//Torch color.
	#define TorchStrength 8									//Torch light intensity /8 is default
	
	#define Lighting_Attenuation 1.45

	#define DarkDesaturation_Color 0.6,0.8,1				//0.6,0.8,1 for overworld, 1,0.3,0.1 for nether, 0.8,0.6,1 for end.
	
	#define Lighting_TextureMult 1.0
	#define Lighting_FinalMult 1.0
	
//VISUAL
	#define Godrays											//Rays from sun and moon.
		const float density = 0.7;			
		const int NUM_SAMPLES = 7;							//increase this for better quality at the cost of performance /7 is default
		const float grnoise = 0.7;							//amount of noise /0.7 is default
	
	//#define SSAO											//Gives occluded area darker color. Costs performance.
		const float ssaoside = 4;
		const float ssaodepth = 3;
		const float ssaorad = 1;
		const float ssaosize = 40;
		const float ssaopwr = 1.0;
		const float ssaonoise = 1.0;
	
	#define EDO												//Cheap/less detailed SSAO. Much better performance.
		#define BORDERE 30.0
		#define EDOPASS 3.0
		#define EDOSTR 0.7
	
	#define Celshade										//Comic book-ish shading. Doesn't affect vanila smooth lighting.
	
	#define Gloss											//Specular replacement.
	
	//#define RoundSunMoon
	
	const float	sunPathRotation	= -40.0f;					//determines sun/moon inclination /-40.0 is default - 0.0 is normal rotation

//ADJUSTABLE VARIABLES//



const float 	wetnessHalflife 		= 70.0f;
const float 	drynessHalflife 		= 70.0f;

const bool 		shadowHardwareFiltering = true;

const int 		noiseTextureResolution  = 1024;
#define SHADOW_MAP_BIAS 0.85

varying vec4 texcoord;

varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying vec3 sunlight;
varying vec3 moonlight;
varying vec3 ambient_color;

varying vec4 lightS;

varying float handItemLight;
varying float eyeAdapt;

varying float SdotU;
varying float MdotU;
varying float sunVisibility;
varying float moonVisibility;

uniform sampler2D gcolor;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D gnormal;
uniform sampler2DShadow shadow;
uniform sampler2D gaux1;
uniform sampler2D noisetex;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform int worldTime;

vec3 convertScreenSpaceToWorldSpace(vec2 co, float depth) {
    vec4 fragposition = gbufferProjectionInverse * vec4(vec3(co, depth) * 2.0 - 1.0, 1.0);
    fragposition /= fragposition.w;
    return fragposition.xyz;
}

vec3 convertCameraSpaceToScreenSpace(vec3 cameraSpace) {
    vec4 clipSpace = gbufferProjection * vec4(cameraSpace, 1.0);
    vec3 NDCSpace = clipSpace.xyz / clipSpace.w;
    vec3 screenSpace = 0.5 * NDCSpace + 0.5;
    return screenSpace;
}

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float edepth(vec2 coord) {
	return texture2D(depthtex0,coord).z;
}
vec2 newtc = texcoord.xy;
vec3 sky_color = normalize(vec3(0.1, 0.35, 1.));

float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;

vec3 aux = texture2D(gaux1, texcoord.st).rgb;
vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0f - 1.0f;


float pixeldepth = texture2D(depthtex0,texcoord.xy).x;
float handlight = handItemLight;

float modlmap = min(aux.b,0.9);
#ifdef Lighting_CelLight
float torch_lightmap = floor((max((1.0/pow((1-modlmap)*16.0,2.0)-(1.0*1.0)/(16.0*16.0))*TorchStrength,0.0)*2.0*3 + pow(max(aux.b,0.0)*2.2,1.8))/4*4)/4;
#else
float torch_lightmap = (max((1.0/pow((1-modlmap)*16.0,2.0)-(1.0*1.0)/(16.0*16.0))*TorchStrength,0.0)*2.0*3 + pow(max(aux.b,0.0)*2.2,1.8))/4;
#endif


//float torch_lightmap = (1.0-exp(-aux.b*light_jitter/TORCH_ATTEN))*TorchStrength;

#ifdef Lighting_CelLight
float sky_lightmap = floor(pow(aux.r,Lighting_Attenuation)*8)/8;
#else
float sky_lightmap = pow(aux.r,Lighting_Attenuation);
#endif

float iswet = wetness*pow(sky_lightmap,5.0)*sqrt(0.5+max(dot(normal,upVec),0.0));

	
//poisson distribution for shadow sampling		
const vec2 shadow_offsets[60] = vec2[60]  (  vec2( 0.0000, 0.2500 ),
									vec2( -0.2165, 0.1250 ),
									vec2( -0.2165, -0.1250 ),
									vec2( -0.0000, -0.2500 ),
									vec2( 0.2165, -0.1250 ),
									vec2( 0.2165, 0.1250 ),
									vec2( 0.0000, 0.5000 ),
									vec2( -0.2500, 0.4330 ),
									vec2( -0.4330, 0.2500 ),
									vec2( -0.5000, 0.0000 ),
									vec2( -0.4330, -0.2500 ),
									vec2( -0.2500, -0.4330 ),
									vec2( -0.0000, -0.5000 ),
									vec2( 0.2500, -0.4330 ),
									vec2( 0.4330, -0.2500 ),
									vec2( 0.5000, -0.0000 ),
									vec2( 0.4330, 0.2500 ),
									vec2( 0.2500, 0.4330 ),
									vec2( 0.0000, 0.7500 ),
									vec2( -0.2565, 0.7048 ),
									vec2( -0.4821, 0.5745 ),
									vec2( -0.6495, 0.3750 ),
									vec2( -0.7386, 0.1302 ),
									vec2( -0.7386, -0.1302 ),
									vec2( -0.6495, -0.3750 ),
									vec2( -0.4821, -0.5745 ),
									vec2( -0.2565, -0.7048 ),
									vec2( -0.0000, -0.7500 ),
									vec2( 0.2565, -0.7048 ),
									vec2( 0.4821, -0.5745 ),
									vec2( 0.6495, -0.3750 ),
									vec2( 0.7386, -0.1302 ),
									vec2( 0.7386, 0.1302 ),
									vec2( 0.6495, 0.3750 ),
									vec2( 0.4821, 0.5745 ),
									vec2( 0.2565, 0.7048 ),
									vec2( 0.0000, 1.0000 ),
									vec2( -0.2588, 0.9659 ),
									vec2( -0.5000, 0.8660 ),
									vec2( -0.7071, 0.7071 ),
									vec2( -0.8660, 0.5000 ),
									vec2( -0.9659, 0.2588 ),
									vec2( -1.0000, 0.0000 ),
									vec2( -0.9659, -0.2588 ),
									vec2( -0.8660, -0.5000 ),
									vec2( -0.7071, -0.7071 ),
									vec2( -0.5000, -0.8660 ),
									vec2( -0.2588, -0.9659 ),
									vec2( -0.0000, -1.0000 ),
									vec2( 0.2588, -0.9659 ),
									vec2( 0.5000, -0.8660 ),
									vec2( 0.7071, -0.7071 ),
									vec2( 0.8660, -0.5000 ),
									vec2( 0.9659, -0.2588 ),
									vec2( 1.0000, -0.0000 ),
									vec2( 0.9659, 0.2588 ),
									vec2( 0.8660, 0.5000 ),
									vec2( 0.7071, 0.7071 ),
									vec2( 0.5000, 0.8660 ),
									vec2( 0.2588, 0.9659 ));					

float Blinn_Phong(vec3 ppos, vec3 lvector, vec3 normal,float fpow, float gloss, float visibility, float glossmult)  {
	vec3 lightDir = vec3(lvector);
	
	vec3 surfaceNormal = normal;
	float cosAngIncidence = dot(surfaceNormal, lightDir);
	cosAngIncidence = clamp(cosAngIncidence, 0.0, 1.0);
	
	vec3 viewDirection = normalize(-ppos);
	
	vec3 halfAngle = normalize(lightDir + viewDirection);
	float blinnTerm = dot(surfaceNormal, halfAngle);
	
	float normalDotEye = dot(normal, normalize(ppos));
	float fresnel = clamp(pow(1.0 + normalDotEye, 5.0),0.0,1.0);
	fresnel = fresnel*0.85 + 0.15 * (1.0-fresnel);
	float pi = 3.1415927;
	float n =  pow(2.0,gloss*glossmult);
	return (pow(blinnTerm, n )*((n+8.0)/(8*pi)))*visibility;
}

float getnoise(vec2 pos) {
	return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
}

#ifdef EDO
float getdist(float rng) {
	return 1-clamp(ld(texture2D(depthtex0,texcoord.xy).r)/rng*far,0,1);
}

vec3 edo(vec3 clrr) {
	//edge detect
	float total = 0;
	float d = edepth(newtc.xy);
	float dtresh = 1/(far-near)/50.0;
	vec4 dc = vec4(d,d,d,d);
	vec4 sa;
	vec4 sb;
	
	float dist = (getdist(32)*2+getdist(64))/3;
	float noise = 1+getnoise(texcoord.xy)*3/EDOPASS;
	float border = floor(BORDERE/EDOPASS*viewWidth/1280);
	float mod = border*dist*noise;
	
	float e = 0;
	
	for (int i = 0; i < EDOPASS; i++) {
	sa.x = edepth(newtc.xy + vec2(-pw,-ph)*mod*i);
	sa.y = edepth(newtc.xy + vec2(pw,-ph)*mod*i);
	sa.z = edepth(newtc.xy + vec2(-pw,0.0)*mod*i);
	sa.w = edepth(newtc.xy + vec2(0.0,ph)*mod*i);
	
	//opposite side samples
	sb.x = edepth(newtc.xy + vec2(pw,ph)*mod*i);
	sb.y = edepth(newtc.xy + vec2(-pw,ph)*mod*i);
	sb.z = edepth(newtc.xy + vec2(pw,0.0)*mod*i);
	sb.w = edepth(newtc.xy + vec2(0.0,-ph)*mod*i);
	
	vec4 dd = (2.0* dc - sa - sb) - dtresh;
	dd = vec4(step(dd.x,0.0),step(dd.y,0.0),step(dd.z,0.0),step(dd.w,0.0));
	
	e = clamp(dot(dd,vec4(0.25f)),0.0,1.0);
	e = e*(dist)+1-dist;
	total += e;
	}
	total /= EDOPASS;
	return clrr * (1-EDOSTR) + clrr*total * EDOSTR;
}
#endif

float fx(float x) {
return (2 *(-sin(x)*sin(x)*sin(x) + 3*sin(x) + 3*x)) / 3;

}
float fx2(float x) {
return (-cos(x) * sin(x) + 6*x) / 2;

}

float subSurfaceScattering(vec3 pos, float N) {

return pow(max(dot(lightVector,normalize(pos)),0.0),N)*(N+1)/6.28;

}

float PosDot(vec3 v1,vec3 v2) {
return max(dot(v1,v2),0.0);
}

float waterH(vec3 posxz) {
vec3 waterpos = posxz;

float speed = 2;
float size = 2;

float noise = 1.0;
float noisesize = 32*size;
float noiseweight = 0;
float noiseneg = 1;

float noisea = 1;
for (int i = 0; i < 2; i++) {
noisea += texture2D(noisetex,vec2(waterpos.x,waterpos.z)/noisesize*0.1+vec2(frameTimeCounter/1000*speed,0)).r*i*noiseneg;
noiseweight += i;
noiseneg *= -1;
noisesize /= 2;
}
noisea /= noiseweight;

noisesize = 16*size;
noiseweight = 0;

float noiseb = 1;
for (int i = 0; i < 2; i++) {
noiseb += texture2D(noisetex,vec2(-waterpos.x,waterpos.z)/noisesize*0.1+vec2(0,frameTimeCounter/1000*speed)).r*i*noiseneg;
noiseweight += i;
noiseneg *= -1;
noisesize /= 2;
}
noiseb /= noiseweight;

noisesize = 64*size;
noiseweight = 0;

float noisec = 1;
for (int i = 0; i < 2; i++) {
noisec += texture2D(noisetex,vec2(posxz.x,-posxz.z)/noisesize*0.1+vec2(-frameTimeCounter/1000*speed,0)).r*i*noiseneg;
noiseweight += i;
noiseneg *= -1;
noisesize /= 2;
}
noisec /= noiseweight;

noisesize = 48*size;
noiseweight = 0;

float noised = 1;
for (int i = 0; i < 2; i++) {
noised += texture2D(noisetex,vec2(-posxz.x,-posxz.z)/noisesize*0.1+vec2(0,-frameTimeCounter/1000*speed)).r*i*noiseneg;
noiseweight += i;
noiseneg *= -1;
noisesize /= 2;
}
noised /= noiseweight;

noise = (noisea*noiseb + noiseb*noisec + noisec*noised + noised*noisea) * (1- noisea*noiseb*noisec*noised)/2;

float wave = 0;
	wave = sin(posxz.x/3+frameTimeCounter/1.4)*cos(posxz.z/3+frameTimeCounter/1.4)*sin(frameTimeCounter/10);
	wave += sin(posxz.x/5+frameTimeCounter/2.2)*cos(posxz.z/5+frameTimeCounter/2.2)*cos(frameTimeCounter/10);

return (noise+wave);
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	vec2 newtc = texcoord.xy;
	//unpack material flags
	float land = float(aux.g > 0.04);
	float iswater = float(aux.g > 0.04 && aux.g < 0.07);
	float translucent = float(aux.g > 0.3 && aux.g < 0.5);
	float hand = float(aux.g > 0.75 && aux.g < 0.85);
	float emissive = float(aux.g > 0.58 && aux.g < 0.62);
	float islava = float(aux.g > 0.62 && aux.g < 0.65);
	float particle = float(aux.g > 0.65 && aux.g < 0.68);
	float shading = 0.0f;
	float spec = 0.0;
	
	float time = float(worldTime);
	float transition_fading = 1.0-(clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-13500.0)/300.0,0.0,1.0) + clamp((time-22500.0)/300.0,0.0,1.0)-clamp((time-23400.0)/300.0,0.0,1.0));	//fading between sun/moon shadows
	float night = clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-22800.0)/200.0,0.0,1.0);
	
	float timebrightness = abs(sin(time/12000*22/7));
	timebrightness = timebrightness*timebrightness;
	
	vec3 nsunlight = normalize(mix(pow(sunlight,vec3(2.2)),vec3(0.25,0.3,0.4),rainStrength));
	sky_color = normalize(mix(sky_color,vec3(0.25,0.3,0.4),rainStrength)); //normalize colors in order to don't change luminance
	
	float fresnel_pow = 5.0;
	
	vec3 color = texture2D(gcolor, newtc.st).rgb + vec3(0.001);
	color = pow(color,vec3(2.2))*(1.0+translucent*0.3)*Lighting_TextureMult;
	
	float NdotL = dot(lightVector,normal);
	float NdotUp = dot(normal,upVec);
	
	vec4 fragposition = gbufferProjectionInverse * vec4(newtc.s * 2.0f - 1.0f, newtc.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
	fragposition /= fragposition.w;
	
		vec4 worldposition = vec4(0.0);
		vec4 worldpositionraw = vec4(0.0);
		worldposition = gbufferModelViewInverse * fragposition;	
		float xzDistanceSquared = worldposition.x * worldposition.x + worldposition.z * worldposition.z;
		float yDistanceSquared  = worldposition.y * worldposition.y;
		worldpositionraw = worldposition;
		
	
	vec3 uPos = vec3(.0);
	
	if (iswater > 0.9) {
	
	vec3 posxz = worldposition.xyz+cameraPosition;
	posxz.x += sin(posxz.z+frameTimeCounter)*0.4;
	posxz.z += cos(posxz.x+frameTimeCounter*0.5)*0.4;
	
	float deltaPos = 0.4;
	float h0 = waterH(posxz);
	float h1 = waterH(posxz + vec3(deltaPos,0.0,0.0));
	float h2 = waterH(posxz + vec3(-deltaPos,0.0,0.0));
	float h3 = waterH(posxz + vec3(0.0,0.0,deltaPos));
	float h4 = waterH(posxz + vec3(0.0,0.0,-deltaPos));
	
	float xDelta = ((h1-h0)+(h0-h2))/deltaPos;
	float yDelta = ((h3-h0)+(h0-h4))/deltaPos;

	
	float refMult = 0.0005-dot(normal,normalize(fragposition).xyz)*0.0015;
	
	vec3 refract = normalize(vec3(xDelta,yDelta,1.0-xDelta*xDelta-yDelta*yDelta));
	vec4 rA = texture2D(gcolor, newtc.st + refract.xy*refMult);
	rA.rgb = pow(rA.rgb,vec3(2.2));
	vec4 rB = texture2D(gcolor, newtc.st);
	rB.rgb = pow(rB.rgb,vec3(2.2));
	float mask = texture2D(gaux1, newtc.st + refract.xy*refMult).g;
	mask =  float(mask > 0.04 && mask < 0.07);
	newtc = (newtc.st + refract.xy*refMult)*mask + texcoord.xy*(1-mask);
	float uDepth = texture2D(depthtex1,newtc.xy).x;
	color.rgb = pow(texture2D(gcolor,newtc.xy).rgb,vec3(2.2));
	uPos  = nvec3(gbufferProjectionInverse * nvec4(vec3(newtc.xy,uDepth) * 2.0 - 1.0));	
	}
	
	
	if (land > 0.9) {
		float dist = length(fragposition.xyz);
		float distof = clamp(1.0-dist/shadowDistance,0.0,1.0);
		float distof2 = clamp(1.0-pow(dist/(shadowDistance*0.75),2.0),0.0,1.0);
		//float shadow_fade = clamp(distof*12.0,0.0,1.0);
		float shadow_fade = sqrt(clamp(1.0 - xzDistanceSquared / (shadowDistance*shadowDistance*1.0), 0.0, 1.0) * clamp(1.0 - yDistanceSquared / (shadowDistance*shadowDistance*1.0), 0.0, 1.0));

		
		/*--reprojecting into shadow space --*/

		worldposition = shadowModelView * worldposition;
		float comparedepth = -worldposition.z;
		worldposition = shadowProjection * worldposition;
		worldposition /= worldposition.w;
		float distb = sqrt(worldposition.x * worldposition.x + worldposition.y * worldposition.y);
		float distortFactor = (1.0f - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
		worldposition.xy *= 1.0f / distortFactor;
		worldposition = worldposition * 0.5f + 0.5f;
		/*---------------------------------*/
		
		
		float step = 3.0/shadowMapResolution*(1.0+rainStrength*5.0);
		//shadow_fade = 1.0-clamp((max(abs(worldposition.x-0.5),abs(worldposition.y-0.5))*2.0-0.9),0.0,0.1)*10.0;
		
		float NdotL = dot(normal, lightVector);
		float diffthresh = (pow(distortFactor*1.2,2.0)*(0.25/148.0)*(tan(acos(abs(NdotL)))) + (0.02/148.0))*(1.0+iswater*2.0);
		diffthresh = mix(diffthresh,0.0005,translucent);
		
		if (comparedepth > 0.02 &&	worldposition.s < 0.98 && worldposition.s > 0.02 && worldposition.t < 0.98 && worldposition.t > 0.02 ) {
			if ((NdotL < 0.0 && translucent < 0.1) || (sky_lightmap < 0.01 && eyeBrightness.y < 2)) {
					shading = 0.0;
				}
			
			else {
			step = 0.5/shadowMapResolution*(1.0+rainStrength*5.0);
			
			shading = shadow2D(shadow,vec3(worldposition.st, worldposition.z-diffthresh)).x;
			shading += shadow2D(shadow,vec3(worldposition.st + vec2(step,0), worldposition.z-diffthresh*2)).x;
			shading += shadow2D(shadow,vec3(worldposition.st + vec2(-step,0), worldposition.z-diffthresh*2)).x;
			shading += shadow2D(shadow,vec3(worldposition.st + vec2(0,step), worldposition.z-diffthresh*2)).x;
			shading += shadow2D(shadow,vec3(worldposition.st + vec2(0,-step), worldposition.z-diffthresh*2)).x;
			shading = shading/5.0;
				
			shading = shading*transition_fading;
			}
		}
		
		else shading = 1.0;
		if (sky_lightmap < 0.02 && eyeBrightness.y < 2) {
					shading = 0.0;
				}

if (particle > 0.9) shading = 1.0;
				
float ao = 1.0;
#ifdef SSAO

if (land > 0.9 && iswater < 0.9 && hand < 0.9) {
	float pi = 3.1415927;
	vec3 norm = texture2D(gnormal,texcoord.xy).rgb*2.0-1.0;
	vec3 projpos = convertScreenSpaceToWorldSpace(texcoord.xy,pixeldepth); 
	vec2 noiseAO = vec2(getnoise(texcoord.xy),getnoise(vec2(texcoord.x,-texcoord.y)))*2-1;
		
	float rprogress = 0.0;
	float sprogress = 1.0;
	ao = 0.0;
	
	float aosize = ssaosize*pw*viewWidth/1280;
	float projrad = clamp(distance(convertCameraSpaceToScreenSpace(projpos + vec3(ssaorad,ssaorad,ssaorad)).xy,texcoord.xy),aosize/2,aosize);
	noiseAO = noiseAO*projrad/(ssaodepth*sqrt(ssaoside))*viewWidth/1280*ssaonoise;
	
		for (int i = 0; i < ssaodepth; i++) {
			for (int j = 0; j < ssaoside; j++) {
				vec2 samplecoord = vec2(cos(rprogress*pi/180),sin(rprogress*pi/180))*(sprogress*projrad*vec2(1,aspectRatio)) + texcoord.xy + noiseAO;
				float sample = texture2D(depthtex0,samplecoord).x;
				vec3 sprojpos = convertScreenSpaceToWorldSpace(samplecoord,sample);
				float angle = pow(min(1.0-dot(norm,normalize(sprojpos-projpos)),1.0),2.0);
				float dist = pow(min(abs(ld(sample)-ld(pixeldepth)),0.015)/0.015,2.0);
				float temp = min(dist+angle,1.0);
				ao += pow(temp,3.0);
				rprogress += 360/ssaoside;
			}
			sprogress = (i+1)/ssaodepth;
			rprogress += 90/ssaoside;
		}
		
		ao /= ssaoside*ssaodepth;
		ao = pow(ao,ssaopwr);
	}
#endif
		
		vec3 npos = normalize(fragposition.xyz);

		float diffuse = max(dot(lightVector,normal),0.0);
		
		diffuse = mix(diffuse,1.0,translucent*0.3);
		float sss = subSurfaceScattering(fragposition.xyz,30.0)*Lighting_SunlightVal*2.0;
		sss = (mix(0.0,sss,max(shadow_fade-0.5,0.0)*2.0)*0.5+0.5)*translucent;
		
		float handLight = (handlight*5)/pow(1.0+length(fragposition.xyz/2.2),2.0)*sqrt(dot(normalize(fragposition.xyz), -normal)*0.5+0.51);
		#ifdef Lighting_CelLight
		handLight = floor(handLight*4)/4;
		#endif
		
	//Apply different lightmaps to image
		shading *= 1-isEyeInWater;
		
		vec3 light_col =  mix(pow(sunlight,vec3(2.2)),moonlight,moonVisibility)*(eyeAdapt*2)*(1-rainStrength*0.8) * (1-moonVisibility*0.8) * (1+shading)/2 * Lighting_SunlightVal;
		light_col = mix(light_col,vec3(length(light_col))*0.3,rainStrength*0.9);
		vec3 Sunlight_lightmap = light_col*shading*(1.0-rainStrength*0.95)*Lighting_SunlightVal *diffuse*transition_fading;

		//we'll suppose water plane have same height above pixel and at pixel water's surface
			//underwater position
		
		vec3 uVec = fragposition.xyz-uPos;
		float UNdotUP = abs(dot(normalize(uVec),normal));
		float depth = length(uVec)*UNdotUP;
		float sky_absorbance = mix(mix(1.0,exp(-depth/2.5),iswater),1.0,isEyeInWater);


		
		
		float visibility = sky_lightmap;
		float bouncefactor = sqrt((NdotUp*0.4+0.61) * pow(1.01-NdotL*NdotL,2.0)+0.5)*0.66;
		float cfBounce = (-NdotL*0.45+0.56);
		
		float timebrightness = pow(abs(sin(time/12000*22/7)),0.5);
		timebrightness = timebrightness*timebrightness;
		float avglightstr = (Lighting_Brightness + Lighting_Darkness)/2;
		float skylightstr = Lighting_Brightness;
		float shdlightstr = Lighting_Darkness;
		skylightstr = mix(mix(avglightstr,skylightstr,timebrightness*sky_lightmap),avglightstr*2,rainStrength);
		shdlightstr = mix(shdlightstr,avglightstr*2,rainStrength);
		
		vec3 emissive = length(color)*(emissive+islava*4+particle)*color*6.0;

		vec3 bounceSunlight = 0.6*cfBounce*light_col*sky_lightmap*sky_lightmap*sky_lightmap*(skylightstr*shading+shdlightstr*(1-shading)) * (1-rainStrength*0.9);
		
		float tL = (lightS.x*pow(sky_lightmap,2.2) + lightS.y)/5.5;
		float tLMoon = (lightS.z + lightS.w)/3.;
		
		vec3 skycolor = mix(sky_color, nsunlight,1-exp(-0.11*tL*(1-rainStrength*0.8)))*tL*sunVisibility*(1-rainStrength*0.8) + tLMoon*moonVisibility*moonlight;

		vec3 sky_light = (skylightstr*shading+shdlightstr*(1-shading))*skycolor*visibility*bouncefactor*(0.3+(moonVisibility+timebrightness/4)*0.7);
		
		vec3 torchcolor = vec3(TorchColor);
		//torchcolor = torchcolor*(1-sky_lightmap) + sky_lightmap;
		vec3 torch_sky = vec3(1)*(1-(1-sky_lightmap)*(1-sky_lightmap))/2*(1-rainStrength)*(1-moonVisibility)*(1+shading*3)/4;
		vec3 Torchlight_lightmap = (torch_lightmap+handLight)*torchcolor + (moonlight*(1+sunVisibility)*2 + torch_sky)*(1+eyeAdapt)/2;
		vec3 color_torchlight = Torchlight_lightmap;
		
		//color = vec3(0.5);

		float sata = clamp((sky_lightmap*(sunVisibility*(1-rainStrength*0.85)+(1-rainStrength/2)/8) + shading*(sunVisibility*(1-rainStrength)) + torch_lightmap+handLight)*4,0.1,1);
		vec3 satb = vec3(DarkDesaturation_Color)*sky_lightmap+vec3(0.5)*(1-sky_lightmap);
		vec3 satc = vec3(color.r+color.g+color.b)/3*satb;
		color = color*sata + satc*(1-sata);
		
		float blockspec = clamp(Blinn_Phong(fragposition.xyz,lightVector,normal,fresnel_pow,1,shading*diffuse,4) *land * (1-isEyeInWater) * (1-iswater) *transition_fading,0,1);
		vec3 lightspec = vec3(0);
		#ifdef Gloss
		lightspec = blockspec*light_col*2*(1+night*7)*(1-rainStrength*0.8);
		#endif
		
		color = ((bounceSunlight+sky_light)+ Sunlight_lightmap + color_torchlight + sss * light_col * shading *(1.0-rainStrength*0.9)*transition_fading + emissive + lightspec)*color*sky_absorbance*ao*Lighting_FinalMult;

		spec = Blinn_Phong(fragposition.xyz,lightVector,normal,fresnel_pow,1,shading*diffuse,11 + night) * iswater * (1.0-isEyeInWater)*transition_fading + blockspec;
	}
	

	
	else {
	#ifndef RoundSunMoon
	color = pow(texture2D(gcolor,newtc.xy).rgb,vec3(2.2))*1.4;
	color = color*1.1;
	#else
	color = vec3(0);
	#endif
	}

	

float gr = 0.0;
#ifdef Godrays
	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
	tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lightPos = pos1*0.5+0.5;
	

		vec2 deltaTextCoord = vec2( newtc.st - lightPos.xy );
		vec2 textCoord = newtc.st;
		deltaTextCoord *= 1.0 /  float(NUM_SAMPLES) * density;
		float avgdecay = 0.0;
		float distx = abs(newtc.x*aspectRatio-lightPos.x*aspectRatio);
		float disty = abs(newtc.y-lightPos.y);
		float fallof = 1.0;
		float noise = getnoise(textCoord);
		
		for(int i=0; i < NUM_SAMPLES ; i++) {			
			textCoord -= deltaTextCoord;

			fallof *= 0.7;
			float sample = step(texture2DLod(gaux1, textCoord+ deltaTextCoord*noise*grnoise,1).g,0.01);
			gr += sample*fallof;
		}

#endif

#ifdef EDO
	if (iswater < 0.9 && islava < 0.9) color = edo(color);
#endif
	color = clamp(pow(color/MAX_COLOR_RANGE,vec3(1.0/2.2)),1.0/255.0,1.0);
/* DRAWBUFFERS:31 */
	gl_FragData[0] = vec4(color, spec);
	gl_FragData[1] = vec4(vec3((gr/NUM_SAMPLES)),1.0);
}
