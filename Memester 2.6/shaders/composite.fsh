#version 120
#define MAX_COLOR_RANGE 48.0
#extension GL_ARB_shader_texture_lod : enable
#define ALBEDO_MULTIPLIER 1.0 //texture brightness multiplier, reduce it when using bright ressourcepacks (summerfields for example)
/* DRAWBUFFERS:31 */

/*
                     
*/


/*--------------------
//ADJUSTABLE VARIABLES//
---------------------*/

//SHADOWS//
const int shadowMapResolution = 2048;		//Shadows resolution. [256 512 1024 2048 3072 4096 8192]
const float shadowDistance = 120;			//Draw distance of shadows.[60 90 120 150 180 210]
	#define Shadow_Darkness 0.10			//Shadow darkness levels, lower values mean darker shadows.
	#define Shadow_Filter					//Smooth out edges of shadows, little to no performance hit.
//END OF SHADOWS//

//LIGHTING//
	#define Dynamic_Handlight				//Item like torches emit light while holding them in your hand. Zero performance impact.
	#define Sunlightamount 4.0				//change sunlight strength , see .vsh for colors.
//END OF LIGHTING//

//VISUAL//
#define Godrays								//Sun casts rays, Requires sun effects to be enabled. Low performance impact.
#ifdef Godrays
	const float density = 0.7;			
	const int NUM_SAMPLES = 6;				//increase this for better quality at the cost of performance
	const float grnoise = 0.9;				//amount of noise
#endif

//#define Celshading						//Cel shades everything, making it look somewhat like Borderlands. Zero performance impact.
	#define BORDER 1.0

#define SSAO								//Ambient Occlusion, makes lighting more realistic. High performance impact.
#ifdef SSAO	
	const int nbdir = 7;			
	const float sampledir = 7;	
	const float ssaorad = 1.0;		
#endif	

//END OF VISUAL//

/*---------------------------
//END OF ADJUSTABLE VARIABLES//
----------------------------*/

//Constants
const float 	wetnessHalflife 		= 70.0f;
const float 	drynessHalflife 		= 70.0f;
const bool 		shadowtex1Mipmap 		= true;
const bool 		shadowtex1Nearest 		= false;
const bool 		shadowHardwareFiltering0 = true;
const float 	shadowIntervalSize 		= 6.0f;
const float		sunPathRotation			= -40.0f;
const int 		noiseTextureResolution  = 1024;
#define SHADOW_MAP_BIAS 0.85
/*--------------------------------*/

varying vec4 texcoord;

varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying vec3 sunlight;
varying vec3 moonlight;
varying vec3 ambient_color;

varying float handItemLight;
varying float eyeAdapt;

varying float sunVisibility;
varying float moonVisibility;

uniform sampler2D gcolor;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D gnormal;
uniform sampler2DShadow shadow;
uniform sampler2D gaux1;
uniform sampler2D gaux3;
uniform sampler2D gdepth;

uniform vec3 cameraPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float frameTimeCounter;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform int worldTime;
float time = float(worldTime);
float night = clamp((time-13000.0)/300.0,0.0,1.0)-clamp((time-22800.0)/200.0,0.0,1.0);
/*--------------------------------*/

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

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

float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;

vec3 aux = texture2D(gaux1, texcoord.st).rgb;
vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0f - 1.0f;

float pixeldepth = texture2D(depthtex0,texcoord.xy).x;
float handlight = handItemLight;

#define TORCH_INTENSITY 10.0
float modlmap = min(aux.b,0.9);
float torch_lightmap = max((1.0/pow((1-modlmap)*16.0,2.0)-(1.0*1.0)/(16.0*16.0))*TORCH_INTENSITY,0.0);

float sky_lightmap = pow(max(aux.r-1.5/16.,0.0)*(1/(1-1.5/16.)),1.3);

float iswet = wetness*pow(sky_lightmap,5.0)*sqrt(0.5+max(dot(normal,normalize(upPosition)),0.0));
	
vec3 specular = texture2D(gaux3,texcoord.xy).rgb;
float specmap = specular.r*(1.0-specular.b)+specular.g*iswet+specular.b*0.85*(1.0-specular.r);
	
float Blinn_Phong(vec3 ppos, vec3 lvector, vec3 normal,float fpow, float gloss, float visibility)  {
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
	float n =  pow(2.0,gloss*8.0+log(1+length(ppos)/2.));
	return (pow(blinnTerm, n )*((n+8.0)/(8*pi)))*visibility;
}

float getnoise(vec2 pos) {
	return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
}

#ifdef Celshading
vec3 celshade(vec3 clrr) {
	//edge detect
	float d = edepth(texcoord.xy);
	float dtresh = 1/(far-near)/5000.0;	
	vec4 dc = vec4(d,d,d,d);
	vec4 sa;
	vec4 sb;
	sa.x = edepth(texcoord.xy + vec2(-pw,-ph)*BORDER);
	sa.y = edepth(texcoord.xy + vec2(pw,-ph)*BORDER);
	sa.z = edepth(texcoord.xy + vec2(-pw,0.0)*BORDER);
	sa.w = edepth(texcoord.xy + vec2(0.0,ph)*BORDER);
	
	//opposite side samples
	sb.x = edepth(texcoord.xy + vec2(pw,ph)*BORDER);
	sb.y = edepth(texcoord.xy + vec2(-pw,ph)*BORDER);
	sb.z = edepth(texcoord.xy + vec2(pw,0.0)*BORDER);
	sb.w = edepth(texcoord.xy + vec2(0.0,-ph)*BORDER);
	
	vec4 dd = abs(2.0* dc - sa - sb) - dtresh;
	dd = vec4(step(dd.x,0.0),step(dd.y,0.0),step(dd.z,0.0),step(dd.w,0.0));
	
	float e = clamp(dot(dd,vec4(0.25f,0.25f,0.25f,0.25f)),0.0,1.0);
	return clrr*e;
}
#endif

//Sub-Surface-Scattering
float subSurfaceScattering(vec3 pos, float N) {
return pow(max(dot(lightVector,normalize(pos)),0.0),N)*(N+1)/6.28;
}

//Water waves
float waterH(vec3 posxz) {
float wave = 0.0;

float factor = 1.0;
float amplitude = 0.2;
float speed = 4.0;
float size = 0.2;

float px = posxz.x/50.0 + 250.0;
float py = posxz.z/50.0  + 250.0;

float fpx = abs(fract(px*20.0)-0.5)*2.0;
float fpy = abs(fract(py*20.0)-0.5)*2.0;

float d = length(vec2(fpx,fpy));

for (int i = 0; i < 3; i++) {
wave -= d*factor*cos( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
factor /= 2;
}

factor = 1.0;
px = -posxz.x/50.0 + 250.0;
py = -posxz.z/150.0 - 250.0;

fpx = abs(fract(px*20.0)-0.5)*2.0;
fpy = abs(fract(py*20.0)-0.5)*2.0;

d = length(vec2(fpx,fpy));
float wave2 = 0.0;
for (int i = 0; i < 3; i++) {
wave2 -= d*factor*cos( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
factor /= 2;
}

return amplitude*wave2+amplitude*wave;
}/*--------------------------------*/

/* If you reached this line, then you're probably about to break the agreement which you accepted by downloading Sildur's shaders!
So stop your doing and ask Sildur's before copying anything which would break the agreement, unless you're Chocapic then go ahead ;)
--------------------------------------------------------------------------------------------------------------------------------*/

void main() {
	
#ifndef Dynamic_Handlight
		handlight = 0.0;
#endif

	//Unpack Materials
	float land = float(aux.g > 0.04);
	float iswater = float(aux.g > 0.04 && aux.g < 0.07);
	float translucent = float(aux.g > 0.3 && aux.g < 0.5);
	float tallgrass = float(aux.g > 0.42 && aux.g < 0.48);
	float hand = float(aux.g > 0.75 && aux.g < 0.85);
	float shading = 0.0f;
	float spec = 0.0;
	/*--------------------------------*/
	
	//Specular
	float roughness = mix(1.0-specular.b,0.005,iswater);
	if (specular.r+specular.g+specular.b < 1.0/255.0 && iswater < 0.09) roughness = 0.99;
	
	float fresnel_pow = pow(roughness,1.25+iswet*0.75)*5.0;
	if (iswater > 0.9) fresnel_pow=5.0;
	/*--------------------------------*/
	
	//Colors and more
	vec3 color = texture2D(gcolor, newtc.st).rgb;
	color = pow(color,vec3(2.2))*(.75+tallgrass*0.2)*ALBEDO_MULTIPLIER;
	
	//limit overbright textures
	float colLength = length(color);
	if (colLength > 0.5) colLength = 0.5+max(colLength-0.5,0.0)*.5;
	color = normalize(color)*colLength/sqrt(3.)*0.9;

	//fading between sun/moon shadows
	float time = float(worldTime);
	float transition_fading = 1.0-(clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-13500.0)/300.0,0.0,1.0) + clamp((time-22500.0)/300.0,0.0,1.0)-clamp((time-23400.0)/300.0,0.0,1.0));
	/*--------------------------------*/	

	//Positioning
	float NdotL = dot(lightVector,normal);
	float NdotUp = dot(normal,upVec);

	vec4 fragposition = gbufferProjectionInverse * vec4(newtc.s * 2.0f - 1.0f, newtc.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
	fragposition /= fragposition.w;
	
	vec4 worldposition = gbufferModelViewInverse * fragposition;	
	float xzDistanceSquared = worldposition.x * worldposition.x + worldposition.z * worldposition.z;
	float yDistanceSquared  = worldposition.y * worldposition.y;
	/*--------------------------------*/		
	
	//Refraction
	vec3 uPos = vec3(0.0);
	float uDepth = texture2D(depthtex1,newtc.xy).x;	
	if (iswater > 0.9) {
	vec3 posxz = worldposition.xyz+cameraPosition;
	posxz.x += sin(posxz.z+frameTimeCounter)*0.25;
	posxz.z += cos(posxz.x+frameTimeCounter*0.5)*0.25;
	
		float deltaPos = 0.4;
		float h0 = waterH(posxz);
		float h1 = waterH(posxz - vec3(deltaPos,0.0,0.0));
		float h2 = waterH(posxz - vec3(0.0,0.0,deltaPos));
	
		float dX = ((h0-h1))/deltaPos;
		float dY = ((h0-h2))/deltaPos;
	
		float nX = sin(atan(dX));
		float nY = sin(atan(dY));
	
		vec3 refract = normalize(vec3(nX,nY,1.0));

		float refMult = 0.005-dot(normal,normalize(fragposition).xyz)*0.003;
	
		vec4 rA = texture2D(gcolor, newtc.st + refract.xy*refMult);
		rA.rgb = pow(rA.rgb,vec3(2.2));
		vec4 rB = texture2D(gcolor, newtc.st);
		rB.rgb = pow(rB.rgb,vec3(2.2));
	
		float mask = texture2D(gaux1, newtc.st + refract.xy*refMult).g;
		mask =  float(mask > 0.04 && mask < 0.07);
		newtc = (newtc.st + refract.xy*refMult)*mask + texcoord.xy*(1-mask);
	
		color.rgb = pow(texture2D(gcolor,newtc.xy).rgb,vec3(2.2));
	
		uPos  = nvec3(gbufferProjectionInverse * nvec4(vec3(newtc.xy,uDepth) * 2.0 - 1.0));	
		
	}/*--------------------------------*/	
	
	
	//Shadows
	if (land > 0.9) {
		float shadow_fade = sqrt(clamp(1.0 - xzDistanceSquared / (shadowDistance*shadowDistance*1.0), 0.0, 1.0) * clamp(1.0 - yDistanceSquared / (shadowDistance*shadowDistance*1.0), 0.0, 1.0));
		
		//Shadows positioning
		worldposition = shadowModelView * worldposition;
		worldposition = shadowProjection * worldposition;
		worldposition /= worldposition.w;
		float distb = length(worldposition.st);
		float distortFactor = mix(1.0,distb,SHADOW_MAP_BIAS);
		worldposition.xy /= distortFactor;  
		worldposition = worldposition * 0.5f + 0.5f;
		/*---------------------------------*/
		
		float diffthresh = (pow(distortFactor*1.2,2.0)*(0.2/148.0)*(tan(acos(abs(NdotL)))) + (0.02/148.0))*(1.0+iswater*2.0);
		diffthresh = mix(diffthresh,0.0005,translucent)*(1.+tallgrass*0.1*clamp(tan(acos(abs(NdotL))),0.0,2.));
		
		if (worldposition.s < 0.99 && worldposition.s > 0.01 && worldposition.t < 0.99 && worldposition.t > 0.01 ) {
			if ((NdotL < 0.0 && translucent < 0.1) || (sky_lightmap < 0.01 && eyeBrightness.y < 2))shading = 0.0;
			else {
			#ifdef Shadow_Filter
			float step = 0.75/shadowMapResolution*(1.0+rainStrength*5.0);
				shading = shadow2D(shadow,vec3(worldposition.st, worldposition.z-diffthresh)).x;
				shading += shadow2D(shadow,vec3(worldposition.st + vec2(step,0), worldposition.z-diffthresh*2)).x;
				shading += shadow2D(shadow,vec3(worldposition.st + vec2(-step,0), worldposition.z-diffthresh*2)).x;
				shading += shadow2D(shadow,vec3(worldposition.st + vec2(0,step), worldposition.z-diffthresh*2)).x;
				shading += shadow2D(shadow,vec3(worldposition.st + vec2(0,-step), worldposition.z-diffthresh*2)).x;
				shading = shading/5.0;
			#endif
			#ifndef Shadow_Filter
				shading = shadow2D(shadow,vec3(worldposition.st, worldposition.z-diffthresh)).x;
			#endif 
			}
		} else shading = 1.0;	
	if (sky_lightmap < 0.02 && eyeBrightness.y < 2)shading = 0.0;
	/*--------------------------------*/	

//SSAO	
float ao = 1.0;
vec3 avgDir = vec3(0.0);
#ifdef SSAO
if (land > 0.9 && iswater < 0.9 && hand < 0.9) {
	vec3 norm = texture2D(gnormal,texcoord.xy).rgb*2.0-1.0;
	vec3 projpos = convertScreenSpaceToWorldSpace(texcoord.xy,pixeldepth); 
		
	float progress = 0.0;
	ao = 0.0;
		
	float projrad = clamp(distance(convertCameraSpaceToScreenSpace(projpos + vec3(ssaorad,ssaorad,ssaorad)).xy,texcoord.xy),7.5*pw,60.0*pw);
		
		for (int i = 1; i < nbdir; i++) {
			for (int j = 1; j < sampledir; j++) {
				vec2 samplecoord = vec2(cos(progress),sin(progress))*(j/sampledir)*projrad + texcoord.xy;
				float sample = texture2D(depthtex0,samplecoord).x;
				vec3 sprojpos = convertScreenSpaceToWorldSpace(samplecoord,sample);
				float angle = pow(min(1.0-dot(norm,normalize(sprojpos-projpos)),1.0),2.0);
				float dist = pow(min(abs(ld(sample)-ld(pixeldepth)),0.015)/0.015,2.0);
				float temp = min(dist+angle,1.0);
				ao += pow(temp,3.0);
				//progress += (1.0-temp)/nbdir*3.14;
			}
			progress = i*1.256;
		}
		
		ao /= (nbdir-1)*(sampledir-1);
		
	}
#endif
/*--------------------------------*/
		
		//Water
		vec4 uPosC = gbufferProjectionInverse * (vec4(newtc,uDepth,1.0) * 2.0 - 1.0);
		uPosC /= uPosC.w;
		
		vec4 uPosY = gbufferModelViewInverse*vec4(uPosC);	
		vec3 pos2 = uPosY.xyz+vec3(sin(uPosY.z+cameraPosition.z+frameTimeCounter)*0.25,0.0,cos(uPosY.x+cameraPosition.x+frameTimeCounter*0.5)*0.25)+cameraPosition+sin(uPosY.y+cameraPosition.y);
	
		float caustics = waterH((pos2.xyz)*2.0)*1.5+2.5;
		float getlight = (eyeBrightness.y / 255.0);
		if(getlight < 0.1);
		else if(iswater > 0.9 || isEyeInWater > 0.1)color *= caustics;
		//-------------------------------------
		
		//Lighting etc.
		float diffuse = max(dot(lightVector,normal),0.0);
		
		diffuse = mix(diffuse,1.0,translucent*0.8);
		float sss = subSurfaceScattering(fragposition.xyz,30.0)*Sunlightamount;
		sss = (mix(0.0,sss,max(shadow_fade-0.5,0.0)*2.0))*translucent;
			
		float mfp = min(1-clamp(length(fragposition.xyz),0.0,16.0)/16.0,0.85);		
		float handLight = (1.0/pow((1-mfp)*16.0,2.0))*TORCH_INTENSITY*handlight*sqrt(dot(normalize(fragposition.xyz), -normal)*0.5+0.51);
		
		shading *= 1-isEyeInWater;
		
		vec3 light_col =  mix(pow(sunlight,vec3(2.2)),moonlight,moonVisibility);
		light_col = mix(light_col,vec3(length(light_col))*vec3(0.25,0.32,0.4),rainStrength);
		vec3 Sunlight_lightmap = light_col*shading*(1.0-rainStrength)*Sunlightamount *diffuse*transition_fading ;
		/*--------------------------------*/
		
		vec3 Ucolor= normalize(vec3(0.1,0.4,0.6));
		//we'll suppose water plane have same height above pixel and at pixel water's surface
		vec3 uVec = fragposition.xyz-uPos;
		float UNdotUP = abs(dot(normalize(uVec),normal));
		float depth = length(uVec)*UNdotUP;
		float sky_absorbance = mix(mix(1.0,exp(-depth/2.5)*0.2,iswater),1.0,isEyeInWater);
		/*--------------------------------*/

		vec4 occlusion = vec4(-normalize(avgDir),length(avgDir));
		
		//Sky, lighting, bouncing	
		float visibility = sky_lightmap;
		float bouncefactor = (NdotUp*0.33+0.67);
		float cfBounce = ((-NdotL*0.45+0.56) + (1-bouncefactor)*0.4)*mix(pow(clamp(dot(occlusion.rgb,-lightVector),0.0,1.),2.0),1.0,ao)*mix(pow(clamp(dot(occlusion.rgb,-upVec),0.0,1.),2.0),1.0,ao);
		vec3 bounceSunlight = 3.2*cfBounce*light_col*visibility*visibility*visibility*Shadow_Darkness * (1-rainStrength*0.9)*transition_fading;
		vec3 skycolor = ambient_color;
		vec3 sky_light = Shadow_Darkness*skycolor*visibility*bouncefactor*(transition_fading*0.5+0.5)*mix(pow(clamp(dot(occlusion.rgb,upVec),0.0,1.),2.0),1.0,ao);
		/*--------------------------------*/
		
		//Torchlight
		vec3 torchcolor = vec3(0.84, 0.26, 0.11)*eyeAdapt*(0.5+(1.0*night));
		vec3 Torchlight_lightmap = (torch_lightmap + handLight) *  torchcolor ;
		vec3 color_torchlight = Torchlight_lightmap*ao;

		//Put everything together
		color = (((bounceSunlight+sky_light) * (1.0+tallgrass*0.1) + 0.002*ao + color_torchlight) + Sunlight_lightmap +  sss * light_col * shading *(1.0-rainStrength*0.9)*transition_fading)*sky_absorbance*color;
		if (iswater > 0.9) color = mix(Ucolor*length(ambient_color)*0.01*sky_lightmap,color,exp(-depth/16));
		
		float gfactor = mix(roughness*0.5+0.01,1.,iswater);
		spec = Blinn_Phong(fragposition.xyz,lightVector,normal,fresnel_pow,gfactor,shading*diffuse) *land * (1.0-isEyeInWater)*transition_fading;
		/*--------------------------------*/
	} 
	else {
	color = pow(texture2D(gcolor,newtc.xy).rgb,vec3(2.2))*(1-sunVisibility)*7.0*sqrt(max(dot(upVec,normalize(fragposition.xyz)),0.0)) ;
	}/*--------------------------------*/

	
	if(night < 0.1){
		float lightlevel = pow(eyeBrightnessSmooth.y / 255.0, 6.0f) * 1.0 + 0.3;
		if(land > 0.9){
		color /= lightlevel;
		}
	}	
	
float gr = 0.0;
#ifdef Godrays
	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
	tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lightPos = pos1*0.5+0.5;
	
		vec2 deltaTextCoord = vec2( newtc.st - lightPos.xy );
		deltaTextCoord *= 1.0 /  float(NUM_SAMPLES) * density;
		float noise = getnoise(newtc.st);
		
		for(int i=0; i < NUM_SAMPLES ; i++) {			
			newtc.st -= deltaTextCoord;

			float sample = step(texture2D(gaux1, newtc.st+ deltaTextCoord*noise*grnoise).g,0.01);
			gr += sample*0.3;
		}

#endif

#ifdef Celshading
	if (iswater < 0.9) color = celshade(color);
#endif

	color = pow(color/MAX_COLOR_RANGE,vec3(1.0/2.2));
	gl_FragData[0] = vec4(color, spec);
	#ifdef Godrays
	gl_FragData[1] = vec4(vec3((gr/NUM_SAMPLES)),1.0);
	#endif
}
