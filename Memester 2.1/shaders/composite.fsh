#version 120








/*

                                      █████████   ███████████   ████████████   ██████████   ██
									  █████████   ███████████   ████████████   ██████████   ██
                                      ██               ██       ██        ██   ██      ██   ██
                                      ██               ██       ██        ██   ██      ██   ██
                                      █████████        ██       ██        ██   ██████████   ██
									  █████████        ██       ██        ██   ██████████   ██
                                             ██        ██       ██        ██   ██           ██
	                                         ██        ██       ██        ██   ██           
                                      █████████        ██       ████████████   ██           ██
									  █████████        ██       ████████████   ██           ██

                                           Stop doing anything! Read first the agreement!
										   
                                Please read this agreement carefully:

                                      • You are allowed to make videos or pictures with my shaderpack.
                                      • You are allowed to modify it ONLY for yourself!
                                      • If you donated me, please DON’T share my MediaFire link!
                                      • You are not allowed to claim my shaderpack as your own!
                                      • You are not allowed to redistribute it!
                                      • If you like to share my shaderpack, please share ONLY the dedelner.net link!
                                      • You are not allowed to publish your modifications!
                                      • You are not allowed to reupload it!
                                      • You are not allowed to earn money with it!
									  
                                For YouTube:
                                      • You are allowed to earn money with my shaderpack in your YouTube video.
                                      • If you modified something or use my development shaderpacks, please say that in your YouTube Video or description.

                                Please consider my agreement.
                                    - Thank you.
									
								Last change at: 23. August 2014


*/












//to increase shadow draw distance, edit shadowDistance and SHADOWHPL below. Both should be equal. Needs decimal point.
//disabling is done by adding "//" to the beginning of a line.

//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES

//----------Shadows----------//

#define SHADOW_DARKNESS 0.1	//shadow darkness levels, lower values mean darker shadows, see .vsh for colors /0.25 is default
#define SHADOW_FILTER						//smooth shadows

//----------End of Shadows----------//

//----------Lighting----------//
	#define DYNAMIC_HANDLIGHT		
	#define SUNLIGHTAMOUNT 0.4		//change sunlight strength , see .vsh for colors. /1.7 is default
	
	//Minecraft lightmap (used for sky)
	#define MIN_LIGHT 0.002
//----------End of Lighting----------//

//----------Visual----------//
	#define GODRAYS
	
	//#define CELSHADING
		#define BORDER 1.0
		
    #define CLOUDS
		
	#define FOG
	
	#define WATER_REFRACT

//----------End of Visual----------//

//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES

const bool 		generateShadowMipmap 	= false;
const float 	shadowIntervalSize 		= 4.0f;
const int 		shadowMapResolution 	= 512;			//shadowmap resolution
const float 	shadowDistance 			= 80.0f;		//draw distance of shadows
const float 	wetnessHalflife 		= 500.0f; // Wet to dry.
const float 	drynessHalflife 		= 60.0f;  // Dry ro wet.
const float		sunPathRotation			= -35.0f;		//determines sun/moon inclination /-35.0 is default - 0.0 is normal rotation

#define SHADOW_MAP_BIAS 0.85



varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 upVec;
varying float handItemLight;

uniform sampler2D gcolor;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D gnormal;
uniform sampler2D shadow;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform vec3 sunPosition;
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
uniform int isEyeInWater;
uniform int worldTime;
uniform int fogMode;

float rainStrength2 = clamp(wetness, 0.0f, 1.0f)/1.0f;

float timefract = worldTime;
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

float cdist(vec2 coord){
    return distance(coord,vec2(0.5))*2.0;
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

float edepth(vec2 coord) {
	return texture2D(depthtex0,coord).z;
}

float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
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

#ifdef CLOUDS

	float hash( float n ) {
		return fract(sin(n)*43758.5453);
	}
 
	float noise( in vec2 x ) {
		vec2 p = floor(x);
		vec2 f = fract(x);
    	f = f*f*(3.0-2.0*f);
    	float n = p.x + p.y*57.0;
    	float res = mix(mix( hash(n+  0.0), hash(n+  1.0),f.x), mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y);
    	return res;
	}
 
	float fbm( vec2 p ) {
    	float f = 0.0;
    	f += 0.50000*noise( p ); p = p*2.1;
    	f += 0.25000*noise( p ); p = p*2.3;
    	f += 0.12500*noise( p ); p = p*2.6;
    	f += 0.06250*noise( p ); p = p*2.9;
    	f += 0.03125*noise( p );
    	return f/0.984375;
	}
	
#endif


vec2 texel = vec2(1.0/viewWidth,1.0/viewHeight);
vec3 aux = texture2D(gaux1, texcoord.st).rgb;
vec3 sunPos = sunPosition;
vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0f - 1.0f;

vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);


float pixeldepth = texture2D(depthtex0,texcoord.xy).x;
float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;
float shadowexit = 0.0;

float handlight = handItemLight;
const float speed = 1.5;
float light_jitter = 1.0-sin(frameTimeCounter*1.4*speed+cos(frameTimeCounter*1.9*speed))*0.025;			//little light variations
float torch_lightmap = pow(aux.b,7.0);

float sky_lightmap = pow(aux.r,3.0);
float iswet = wetness*pow(sky_lightmap,10.0)*sqrt(0.5+max(dot(normal,normalize(upPosition)),0.0));

#ifdef SHADOW_FILTER

	//poisson distribution for shadow sampling		
	const vec2 circle_offsets[25] = vec2[25](vec2(-0.4894566f,-0.3586783f),
										vec2(-0.1717194f,0.6272162f),
										vec2(-0.4709477f,-0.01774091f),
										vec2(-0.9910634f,0.03831699f),
										vec2(-0.2101292f,0.2034733f),
										vec2(-0.7889516f,-0.5671548f),
										vec2(-0.1037751f,-0.1583221f),
										vec2(-0.5728408f,0.3416965f),
										vec2(-0.1863332f,0.5697952f),
										vec2(0.3561834f,0.007138769f),
										vec2(0.2868255f,-0.5463203f),
										vec2(-0.4640967f,-0.8804076f),
										vec2(0.1969438f,0.6236954f),
										vec2(0.6999109f,0.6357007f),
										vec2(-0.3462536f,0.8966291f),
										vec2(0.172607f,0.2832828f),
										vec2(0.4149241f,0.8816f),
										vec2(0.136898f,-0.9716249f),
										vec2(-0.6272043f,0.6721309f),
										vec2(-0.8974028f,0.4271871f),
										vec2(0.5551881f,0.324069f),
										vec2(0.9487136f,0.2605085f),
										vec2(0.7140148f,-0.312601f),
										vec2(0.0440252f,0.9363738f),
										vec2(0.620311f,-0.6673451f)
										);
									
#endif

#ifdef CELSHADING

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
		
		float e = clamp(dot(dd,vec4(0.5f,0.5f,0.5f,0.5f)),0.0,1.0);
		return clrr*e;
	}

#endif

#ifdef GODRAYS

	float getnoise(vec2 pos) {
		return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
	}

#endif

#ifdef WATER_REFRACT

	float waterH(vec3 posxz) {

		float wave = 0.0;


		float factor = 1.0;
		float amplitude = 0.2;
		float speed = 5.0;
		float size = 0.6;

		float px = posxz.x/50.0 + 250.0;
		float py = posxz.z/50.0  + 250.0;

		float fpx = abs(fract(px*20.0)-0.5)*2.0;
		float fpy = abs(fract(py*20.0)-0.5)*2.0;

		float d = length(vec2(fpx,fpy));

		for (int i = 1; i < 8; i++) {
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
		for (int i = 1; i < 8; i++) {
			wave2 -= d*factor*cos( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
			factor /= 2;
		}

		return amplitude*wave2+amplitude*wave;
		
	}

#endif

//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////

void main() {

	fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));
    float volumetric_cone = max(dot(normalize(fragpos),lightVector),0.0);
	
	#ifndef DYNAMIC_HANDLIGHT
		handlight = 0.0;
	#endif

	float shadowexit = float(aux.g > 0.1 && aux.g < 0.3);
	float land = float(aux.g > 0.03);
	float iswater = float(aux.g > 0.04 && aux.g < 0.07);
	float translucent = float(aux.g > 0.3 && aux.g < 0.5);
	float hand = float(aux.g > 0.75 && aux.g < 0.85);
	
	vec3 color = texture2D(gcolor, texcoord.st).rgb;
	color = pow(color,vec3(2.2));
	vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
	fragposition /= fragposition.w;
	
	vec4 worldposition = vec4(0.0);
	vec4 worldpositionraw = vec4(0.0);
	worldposition = gbufferModelViewInverse * fragposition;	
	float xzDistanceSquared = worldposition.x * worldposition.x + worldposition.z * worldposition.z;
	float yDistanceSquared  = worldposition.y * worldposition.y;
	worldpositionraw = worldposition;
		
	float shading = 1.0f;
	float spec = 0.0;
	float time = float(worldTime);
	float transition_fading = 1.0-(clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-13000.0)/300.0,0.0,1.0) + clamp((time-22800.0)/200.0,0.0,1.0)-clamp((time-23400.0)/200.0,0.0,1.0));	//fading between sun/moon shadows
	float night = clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-22800.0)/200.0,0.0,1.0);
	
	float watersunlight = 0.0f;
	
	#ifdef WATER_REFRACT
	
		if (iswater > 0.9) {
		
			vec3 underwaterpos = vec3(texcoord.st, texture2D(depthtex1, texcoord.st).r);
			underwaterpos = nvec3(gbufferProjectionInverse * nvec4(underwaterpos * 2.0 - 1.0));
			vec4 worldpositionuw = gbufferModelViewInverse * vec4(underwaterpos,1.0);	
			vec3 wpos = worldpositionuw.xyz + cameraPosition.xyz;
		
		
			vec3 posxz = worldposition.xyz + cameraPosition.xyz;
			
			float deltaPos = 0.2;
			float h0 = waterH(posxz);
			float h1 = waterH(posxz + vec3(deltaPos,0.0,0.0));
			float h2 = waterH(posxz + vec3(-deltaPos,0.0,0.0));
			float h3 = waterH(posxz + vec3(0.0,0.0,deltaPos));
			float h4 = waterH(posxz + vec3(0.0,0.0,-deltaPos));
			
			float xDelta = ((h1-h0)+(h0-h2))/deltaPos;
			float yDelta = ((h3-h0)+(h0-h4))/deltaPos;

			
			float refMult = 0.0025-dot(normal,normalize(fragposition).xyz)*0.015;
			
			vec3 refract = normalize(vec3(xDelta,yDelta,1.0-xDelta*xDelta-yDelta*yDelta));
			vec4 rA = texture2D(gcolor, texcoord.st + refract.xy*refMult);
			rA.rgb = pow(rA.rgb,vec3(2.2));
			vec4 rB = texture2D(gcolor, texcoord.st);
			rB.rgb = pow(rB.rgb,vec3(2.2));
			float mask = texture2D(gaux1, texcoord.st + refract.xy*refMult).g;
			mask =  float(mask > 0.04 && mask < 0.07);
			color = rA.rgb*mask + rB.rgb*(1-mask);
		}
	
	#endif
	
	if (land > 0.9 && isEyeInWater < 0.1) {
	
		float dist = length(fragposition.xyz);

		float shadingsharp = 0.0f;
		
		vec4 worldposition = vec4(0.0);
		vec4 worldpositionraw = vec4(0.0);
		
		worldposition = gbufferModelViewInverse * fragposition;	
		
		float xzDistanceSquared = worldposition.x * worldposition.x + worldposition.z * worldposition.z;
		float yDistanceSquared  = worldposition.y * worldposition.y;
		
		worldpositionraw = worldposition;
		
		worldposition = shadowModelView * worldposition;
		float comparedepth = -worldposition.z;
		worldposition = shadowProjection * worldposition;
		worldposition /= worldposition.w;
		
		float distb = sqrt(worldposition.x * worldposition.x + worldposition.y * worldposition.y);
		float distortFactor = (1.0f - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
		worldposition.xy *= 1.0f / distortFactor;
		worldposition = worldposition * 0.5f + 0.5f;
		int vpsize = 0;
		float diffthresh = 1.0*distortFactor+iswater+translucent;
		float isshadow = 0.0;
		float ssample;

		float distof = clamp(1.0-dist/shadowDistance,0.0,1.0);
		float distof2 = clamp(1.0-dist/(shadowDistance*0.75),0.0,1.0);
		float shadow_fade = clamp(distof*12.0,0.0,1.0);
		float sss_fade = pow(distof2,0.2);
		float step = 1.0/shadowMapResolution;
		
		float global_illumintaion = 0.0f;	
		float global_illumintaion2 = 0.0f;
		
			if (dist < shadowDistance) {
				
				if (shadowexit > 0.1) {
					shading = 1.0;
				} else {
				
				#ifdef SHADOW_FILTER
				
					for(int i = 0; i < 25; i++){
					
						global_illumintaion = (clamp(comparedepth - (0.05 + (texture2D(shadow, worldposition.st + circle_offsets[i]*step*10.0 + circle_offsets[i]*step).z) * (256.0 - 0.05)), 0.0, diffthresh)/(diffthresh));
						global_illumintaion2 = (clamp(comparedepth - (0.05 + (texture2D(shadow, worldposition.st + circle_offsets[i]*step/10.0 + circle_offsets[i]*step).z) * (256.0 - 0.05)), 0.0, diffthresh)/(diffthresh));
						
						shadingsharp += global_illumintaion * global_illumintaion2;
						
					}
					
					shadingsharp /= 25.0;
					shading = 1.0-shadingsharp;
					isshadow = 1.0;
					
				#endif
				
				#ifndef SHADOW_FILTER
				
					shading = (clamp(comparedepth - (0.05 + (texture2D(shadow, worldposition.st).z) * (256.0 - 0.05)), 0.0, diffthresh)/(diffthresh));
					shading = 1.0-shading;
					
				#endif
				
				}
				
			}
			
		
		float sss_transparency = mix(0.0,0.75,translucent);		//subsurface scattering amount
		float sunlight_direct = 1.0;
		float direct = 1.0;
		float sss = 0.0;
		vec3 npos = normalize(fragposition.xyz);
		float NdotL = 1.0;
		
		NdotL = dot(normal, lightVector);
		direct = NdotL;
			
		sunlight_direct = max(direct,0.0);
		sunlight_direct = mix(sunlight_direct,0.75,translucent*min(sss_fade+0.4,1.0));
		
		sss += pow(max(dot(npos, lightVector),0.0),20.0)*sss_transparency*clamp(-NdotL,0.0,1.0)*translucent*1.5;
		
		sss = mix(0.0,sss,sss_fade);
		shading = clamp(shading,0.0,1.0);
		
		
		// Ambientcolor
	    vec3 ambientColor_sunrise = vec3(0.5, 0.9, 1.27) * TimeSunrise * (1.0- rainStrength2 * 1.0);
	    vec3 ambientColor_noon = vec3(0.5, 0.9, 1.27) * 1.5 * TimeNoon * (1.0- rainStrength2 * 1.0);
	    vec3 ambientColor_sunset = vec3(0.5, 0.9, 1.27) * TimeSunset * (1.0- rainStrength2 * 1.0);
	    vec3 ambientColor_midnight = vec3(0.02, 0.05, 0.1) * TimeMidnight * (1.0- rainStrength2 * 1.0);
        vec3 ambientColor_rain_day = vec3(1.5, 2.0, 2.55) * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength2;
        vec3 ambientColor_rain_night = vec3(0.02, 0.05, 0.1) * TimeMidnight * rainStrength2;
		
	    vec3 ambient_color = ambientColor_sunrise + ambientColor_noon + ambientColor_sunset + ambientColor_midnight + ambientColor_rain_day + ambientColor_rain_night;
		
		
		// Sunlightcolor
		vec3 sunlightColor_sunrise = vec3(2.52, 0.8, 0.2) * 0.8 * TimeSunrise;
		vec3 sunlightColor_noon = vec3(2.52, 1.6, 1.0) * TimeNoon;
		vec3 sunlightColor_sunset = vec3(2.52, 0.8, 0.2) * 0.8 * TimeSunset;
		vec3 sunlightColor_midnight = vec3(0.01, 0.06, 0.3) * TimeMidnight;
		
		vec3 sunlight_color = sunlightColor_sunrise + sunlightColor_noon + sunlightColor_sunset + sunlightColor_midnight;


		
		vec3 Sunlight_lightmap = sunlight_color*mix(max(sky_lightmap-rainStrength2*1.0,0.0),shading*(1.0-rainStrength2*1.0),shadow_fade)*SUNLIGHTAMOUNT *sunlight_direct*transition_fading*sky_lightmap*(1.0-iswater*1.0) ;
		
		float sky_inc = sqrt(direct*0.5+0.51);
		vec3 amb = (sky_inc*ambient_color+(1.0-sky_inc)*(sunlight_color+ambient_color*2.0)*vec3(0.2,0.24,0.27))*vec3(0.8,0.8,1.0);

		vec3 torchcolor = vec3(2.55,0.4,0.2);
		vec3 Torchlight_lightmap = (torch_lightmap+handlight*pow(max(5.5-length(fragposition.xyz),0.0)/5.5,2.0)*max(dot(-fragposition.xyz,normal),0.0)) *  torchcolor;
	
		
		vec3 color_sunlight = Sunlight_lightmap;
		vec3 color_torchlight = Torchlight_lightmap;
		
		// Water fog
		//we'll suppose water plane have same height above pixel and at pixel water's surface
		if (iswater > 0.9) {
			vec3 uPos  = nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord.xy,texture2D(depthtex1,texcoord.xy).x) * 2.0 - 1.0));  //underwater position
			vec3 uVec = fragpos-uPos;
			float UNdotUP = dot(normalize(uVec),normalize(upPosition));
			float depth = length(uVec)*UNdotUP;
			depth *= 0.3;
			  
			if (depth < 0.96) {
				color *= 1.0-depth;
				//watersunlight += abs(waterH(wpos))*0.05*(1.0-depth);
			} else {
				color *= 0.04;
			}		
		}
		
		// Ground get's darker if it's wet
		if (iswet > 0.10 ) color *= 1.0;
		if (iswet > 0.15 ) color *= 0.98;
		if (iswet > 0.20 ) color *= 0.96;
		if (iswet > 0.25 ) color *= 0.94;
		if (iswet > 0.30 ) color *= 0.92;
		if (iswet > 0.35 ) color *= 0.90;
		if (iswet > 0.40 ) color *= 0.88;
		if (iswet > 0.45 ) color *= 0.86;
		if (iswet > 0.50 ) color *= 0.84;
		
		
		//Add all light elements together
		color = (amb*SHADOW_DARKNESS*sky_lightmap + MIN_LIGHT + watersunlight*shading*sunlight_color + color_sunlight + color_torchlight  +  sss * sunlight_color * shading*(1.0-rainStrength2*1.0)*transition_fading)*color;
		
	} else if (isEyeInWater < 0.1) {
	
	    // Desaturate sky colors from resource packs.
        vec3 Gray = vec3(0.3, 0.3, 0.3);
        vec3 ColorScale = vec3(1.0, 1.0, 1.0);
        float Saturation = 0.0;

        // Color Matrix
        vec3 OutColor = color.rgb;
    
        // Offset & Scale
        OutColor = (OutColor * ColorScale);
    
        // desaturation night ambient.
        float Luma = dot(OutColor, Gray);
        vec3 Chroma = OutColor - Luma;
        OutColor = (Chroma * Saturation) + Luma;
		
		color = OutColor;
		
	    vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
	    fragposition /= fragposition.w;
	
	    vec4 worldposition = vec4(0.0);
	    worldposition = gbufferModelViewInverse * fragposition  / far * 128.0;	
		
        float horizont = abs(worldposition.y - texcoord.y);
		float skycolor_position = max(pow(max(1.0 - horizont/(100.0*100.0),0.01),8.0)-0.1,0.0);
		float horizont_position = max(pow(max(1.0 - horizont/(5.0*100.0),0.01),8.0)-0.1,0.0);
	
	    // Add new sky colors.
	    vec3 skycolor_sunrise = vec3(0.4, 0.6, 1.0) * (1.0-rainStrength2*1.0) * TimeSunrise;
	    vec3 skycolor_noon = vec3(0.25, 0.45, 1.0) * (1.0-rainStrength2*1.0) * TimeNoon;
	    vec3 skycolor_sunset = vec3(0.4, 0.6, 1.0) * (1.0-rainStrength2*1.0) * TimeSunset;
		vec3 skycolor_night = vec3(0.15, 0.6, 1.3) * TimeMidnight;
		vec3 skycolor_rain_day = vec3(1.0, 1.4, 2.0) * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength2;
		vec3 skycolor_rain_night = vec3(0.15, 0.6, 1.3) * TimeMidnight * rainStrength2;
		color.rgb *= (skycolor_sunrise + skycolor_noon + skycolor_sunset + skycolor_night + skycolor_rain_day + skycolor_rain_night) * skycolor_position;
		
	    vec3 horizontColor_sunrise = vec3(2.52, 1.5, 0.0) * 0.3 * (1.0-rainStrength2*1.0) * TimeSunrise;
	    vec3 horizontColor_noon = vec3(2.55, 2.55, 2.55) * 0.2 * (1.0-rainStrength2*1.0) * TimeNoon;
	    vec3 horizontColor_sunset = vec3(2.52, 1.0, 0.0) * 0.3 * (1.0-rainStrength2*1.0) * TimeSunset;
	    vec3 horizontColor_night = vec3(0.15, 0.6, 1.3) * 0.03 * (1.0-rainStrength2*1.0) * TimeMidnight;
	    vec3 horizontColor_rain_day = vec3(0.4, 0.5, 0.6) * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength2;
	    vec3 horizontColor_rain_night = vec3(0.15, 0.6, 1.3) * 0.03 * TimeMidnight * rainStrength2;
		
		vec3 horizontColor = horizontColor_sunrise + horizontColor_noon + horizontColor_sunset + horizontColor_night + horizontColor_rain_day + horizontColor_rain_night;
		color.rgb += horizontColor * horizont_position;
		
		// better sun
		// get sun color.
	    vec3 suncolor_sunrise = vec3(2.52, 0.9, 0) * TimeSunrise * (1.0 - rainStrength2 * 1.0);
	    vec3 suncolor_noon = vec3(2.52, 1.60, 0.5) * TimeNoon * (1.0 - rainStrength2 * 1.0);
	    vec3 suncolor_sunset = vec3(2.52, 0.9, 0.0) * TimeSunset * (1.0 - rainStrength2 * 1.0);
		vec3 suncolor_midnight = vec3(0.15, 0.6, 1.3) * 0.1 * TimeMidnight * (1.0 - rainStrength2 * 1.0);
	    vec3 suncolor_rain_day = vec3(0.8, 0.9, 1.0) * 0.5 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength2;
	
	    vec3 suncolor = suncolor_sunrise + suncolor_noon + suncolor_sunset + suncolor_midnight;
		
	    // ambient color.
		color.rgb += pow(volumetric_cone,3.0)*0.1*suncolor*transition_fading;
			
	    // ambient color at rain.
		color.rgb += pow(volumetric_cone,3.0)*suncolor_rain_day*transition_fading;
			
		// fake sun color.
		color.rgb += pow(volumetric_cone,300.0)*3.0*suncolor*(1.0 - rainStrength2 * 1.0)*transition_fading;
			
		
		#ifdef CLOUDS
		
	        // Wind - Used to animate the clouds
	        vec2 wind_vec = vec2(0.001 + frameTimeCounter*0.02, 0.003 + frameTimeCounter * 0.02);
	        vec2 wind_vec2 = vec2(0.002 + frameTimeCounter*0.05, 0.002 + frameTimeCounter * 0.05);
	        vec2 wind_vec3 = vec2(0.003 + frameTimeCounter*0.1, 0.001 + frameTimeCounter * 0.1);
			
			// Remove clouds under land
			float remove = worldposition.y + length(worldposition.y);
	
	        // Set up domain
	        vec2 q = (worldposition.xz / worldposition.y + (cameraPosition.xz*0.005));
	        vec2 q2 = (worldposition.xz / worldposition.y + (cameraPosition.xz*0.0075));
	        vec2 q3 = (worldposition.xz / worldposition.y + (cameraPosition.xz*0.01));
	        vec2 p = -1.0 + 3.0 * q + wind_vec;
	        vec2 p2 = -1.0 + 3.0 * q2 + wind_vec2 + 6.0;
	        vec2 p3 = -1.0 + 3.0 * q3 + wind_vec3 + 12.0;
			
            // Resolution
            p /= 6.0;
            p2 /= 9.0;
            p3 /= 12.0;
	
	        // Create noise using fBm
	        float f = fbm( 4.0*p);
	        float f2 = fbm( 4.0*p2 );
	        float f3 = fbm( 4.0*p3 );
 
	        float cover = 0.0f;
	        float sharpness = 0.15;	// Brightness
			
			float cover_sunrise = 0.55 * TimeSunrise * (1.0-rainStrength2*1.0);
			float cover_noon = 0.45 * TimeNoon * (1.0-rainStrength2*1.0);
			float cover_sunset = 0.55 * TimeSunset * (1.0-rainStrength2*1.0);
			float cover_midnight = 0.8 * TimeMidnight * (1.0-rainStrength2*1.0);
			float cover_rain = 0.99 * rainStrength2;
			
			cover = cover_sunrise + cover_noon + cover_sunset + cover_midnight + cover_rain;
	
	        float c = f - (1.0 - cover);
	        if ( c < 0.0 )
		        c = 0.0;
	
        	f = 1.0 - (pow(1.0 - sharpness, c));
			
	        float c2 = f2 - (1.0 - cover);
	        if ( c2 < 0.0 )
		        c2 = 0.0;
	
        	f2 = 1.0 - (pow(1.0 - sharpness, c2));
			
	        float c3 = f3 - (1.0 - cover);
	        if ( c3 < 0.0 )
		        c3 = 0.0;
	
        	f3 = 1.0 - (pow(1.0 - sharpness, c3));
			
			vec3 cloudcolor_normal = vec3(1.0, 1.0, 1.0) * (TimeSunrise + TimeNoon + TimeSunset) * (1.0-rainStrength2*1.0);
			vec3 cloudcolor_midnight = vec3(0.15, 0.6, 1.3) * 0.01 * TimeMidnight * (1.0-rainStrength2*1.0);
			vec3 cloudcolor_rain_day = vec3(1.0, 1.0, 1.0) * 0.5 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength2;
			vec3 cloudcolor_rain_night = vec3(0.15, 0.6, 1.3) * 0.01 * TimeMidnight * rainStrength2;
			
			vec3 cloudcolor = cloudcolor_normal + cloudcolor_midnight + cloudcolor_rain_day + cloudcolor_rain_night;
			
			cloudcolor += pow(volumetric_cone,2.0)*suncolor*0.5;

			color.rgb += (cloudcolor * f / 100.0) * remove;
			color.rgb += (cloudcolor * f2 / 100.0) * remove;
			color.rgb += (cloudcolor * f3 / 100.0) * remove;
			
		#endif
		
		color.rgb *= (eyeBrightness.y/255.0);
	
	}
	
	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
	tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lightPos = pos1*0.5+0.5;
	
	#ifdef FOG
	
	    // fog distance.
		float fog_sunrise = 40.0 * TimeSunrise *  (1.0-rainStrength2*1.0);
		float fog_noon = 75.0 * TimeNoon * (1.0-rainStrength2*1.0);
	    float fog_sunset = 100.0 * TimeSunset * (1.0-rainStrength2*1.0);
		float fog_midnight = 25.0 * TimeMidnight * (1.0-rainStrength2*1.0);
	    float fog_rain = 25.0*rainStrength2;
	    float fog_distance = fog_sunrise + fog_noon + fog_sunset + fog_midnight + fog_rain;
	
	    // get fog color. 
	    vec3 fogclr_day = vec3(0.5, 0.8, 1.27) * (TimeSunrise + TimeNoon + TimeSunset) * (1.0-rainStrength2*1.0);
	    vec3 fogclr_midnight = vec3(0.15, 0.6, 1.3) * 0.1 * TimeMidnight * (1.0-rainStrength2*1.0);
	    vec3 fogclr_rain_day = vec3(1.5, 1.9 ,2.55) * 0.5 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength2;
	    vec3 fogclr_rain_night = vec3(0.15, 0.6, 1.3) * 0.1  * TimeMidnight * rainStrength2;
		
	    vec3 fogclr = fogclr_day + fogclr_midnight + fogclr_rain_day + fogclr_rain_night;
		fogclr *= (eyeBrightness.y/255.0);
	 
	    if (land > 0.9) {		
	        float depth_diff2 = exp(-pow(length(fragpos)/fog_distance,4.0));
	        float fogfactor =  clamp(depth_diff2 + hand,0.0,1.0);
	        color.rgb += mix(fogclr*0.1,color.rgb,fogfactor);
	    }
		
	#endif

/* DRAWBUFFERS:31 */

#ifdef CELSHADING

	if (land > 0.9 && iswater < 0.9) color = celshade(color);
	
#endif


	
	
	#ifdef GODRAYS
	
		const float density = 0.55;			
		const int NUM_SAMPLES = 5;			//increase this for better quality at the cost of performance /5 is default
		const float grnoise = 0.0;		//amount of noise /0.012 is default
	
		float gr = 0.0;
		
		vec2 deltaTextCoord = vec2( texcoord.st - lightPos.xy );
		vec2 textCoord = texcoord.st;
		deltaTextCoord *= 1.0 /  float(NUM_SAMPLES) * density;
		
		float avgdecay = 0.0;
		float distx = abs(texcoord.x*aspectRatio-lightPos.x*aspectRatio);
		float disty = abs(texcoord.y-lightPos.y);
		vec2 noise = vec2(getnoise(textCoord),getnoise(-textCoord.yx+0.05));
				
		for(int i=0; i < NUM_SAMPLES ; i++) {	
				
			textCoord -= deltaTextCoord;
			float sample = step(texture2D(gaux1, textCoord+ textCoord*noise*grnoise).g,0.01);
			gr += sample;
					
		}

	#endif

		
	color = pow(color,vec3(1.0/2.2));
	color = clamp(color,0.0,1.0);
	gl_FragData[0] = vec4(color, spec);
	
	#ifdef GODRAYS
		gl_FragData[1] = vec4(vec3((gr/NUM_SAMPLES)),1.0);
	#endif
}
