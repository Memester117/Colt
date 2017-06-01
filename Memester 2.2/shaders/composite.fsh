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
///////////////////// ADJUSTABLE FEATURES ////////////////////
//////////////////////////////////////////////////////////////

	//#define INTEL_HD_GRAPHICS_FIX

	#define SHADOW_FILTER						// Smooth shadows. Looks better with shadowMapResolution = 1024.
		//#define SHADOW_ILLUMINATION					// Shadow Filter needs to be enabled!

	#define GODRAYS
	
	//#define CELSHADING
		
    #define CLOUDS
		
	#define FOG
	
	#define SSAO
	
	#define WATER_REFRACT
	
	#define DYNAMIC_TONEMAPPING

	
	
	
	
	
	
	
	
	
	
	
	
//////////////////////////////////////////////////////////////
////////////////////// ADJUSTABLE CONSTS /////////////////////
//////////////////////////////////////////////////////////////

const float 	centerDepthHalflife 	 = 2.0f;
const float 	shadowIntervalSize 		 = 6.f;
const int 		shadowMapResolution 	 = 1024;		 // Shadowmap resolution.
const float 	shadowDistance 			 = 80.0f;		 // Draw distance of shadows.
const float 	wetnessHalflife 		 = 500.0f; 		 // Wet to dry.
const float 	drynessHalflife 		 = 60.0f;		 // Dry ro wet.
const float		sunPathRotation			 = -35.0f;       // 0.0 is default rotation.
const float		eyeBrightnessHalflife	 = 7.5f;         // For dynamic tonemapping.
const int 		noiseTextureResolution   = 720;
const float 	ambientOcclusionLevel	 = 0.5f;

#define SHADOW_MAP_BIAS 0.85











//////////////////////////////////////////////////////////////
//////////////////////// GET MATERIAL ////////////////////////
//////////////////////////////////////////////////////////////

varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;
varying float SdotU;
varying float MdotU;
varying float sunVisibility;
varying float moonVisibility;
varying float handItemLight;

uniform sampler2D gcolor;
uniform sampler2D noisetex;
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
uniform mat4 gbufferModelView;
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
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform int worldTime;
uniform int fogMode;

float rainStrength2 = clamp(wetness, 0.0f, 1.0f)/1.0f;

float timefract = worldTime;
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 2000.0)/2000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 2000.0)) / 2000.0) - ((clamp(timefract, 10000.0, 12000.0) - 10000.0) / 2000.0);
float TimeSunset   = ((clamp(timefract, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
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

vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);

#ifdef CLOUDS

	vec2 wind[4] = vec2[4](vec2(abs(frameTimeCounter/1000.-0.5),abs(frameTimeCounter/1000.-0.5))+vec2(0.5),
						vec2(-abs(frameTimeCounter/1000.-0.5),abs(frameTimeCounter/1000.-0.5)),
						vec2(-abs(frameTimeCounter/1000.-0.5),-abs(frameTimeCounter/1000.-0.5)),
						vec2(abs(frameTimeCounter/1000.-0.5),-abs(frameTimeCounter/1000.-0.5)));
				
	float subSurfaceScattering(vec3 vec,vec3 pos, float N) {
		return pow(max(dot(vec,normalize(pos)),0.0),N)*(N+1)/6.28;
	}

	float subSurfaceScattering2(vec3 vec,vec3 pos, float N) {
		return pow(max(dot(vec,normalize(pos))*0.5+0.5,0.0),N)*(N+1)/6.28;
	}

	vec3 drawCloud(vec3 fposition, vec3 color, vec3 cloudcolor, vec3 cloudcolorRain, vec3 sunlight, float remove, vec2 worldPos, float hPos) {

		float cloudDepth	  		  = 1.1;
		float cloudCover	  		  = 1.0;
		float cloudExposure	  		  = 0.05;
		float cloudScatteringExposure = 2.0;
		float cloudWindSpeed		  = 0.5;
		float cloudViewDistance		  = 300.0;

		vec3 sVector = normalize(fposition);
		float cosT = max(dot(normalize(sVector),upVec),0.0);
		float McosY = MdotU;
		float cosY = SdotU;
		vec3 tpos = vec3(gbufferModelViewInverse * vec4(fposition,1.0));
		vec3 wvec = normalize(tpos);
		vec3 wVector = normalize(tpos);

		vec4 totalcloud = vec4(.0);

		vec3 intersection = wVector*((-cloudViewDistance)/(wVector.y));
		vec3 iSpos = (gbufferModelView*vec4(intersection,1.0)).rgb;
		float cosT2 = pow(0.89,distance(vec2(0.0),intersection.xz)/100);
		
		float cloudCoverSunrise  = 0.4 * TimeSunrise * (1.0 - rainStrength2 * 1.0);
		float cloudCoverNoon     = 0.5 * TimeNoon * (1.0 - rainStrength2 * 1.0);
		float cloudCoverSunset   = 0.45 * TimeSunset * (1.0 - rainStrength2 * 1.0);
		float cloudCoverMidnight = 0.4 * TimeMidnight * (1.0 - rainStrength2 * 1.0);
		float cloudCoverRain     = 0.0 * rainStrength2;
		
			  cloudCover *= cloudCoverSunrise + cloudCoverNoon + cloudCoverSunset + cloudCoverMidnight + cloudCoverRain;
			  
		cloudExposure *= 1.0 - TimeMidnight * 0.9;
		cloudDepth *= 1.0 - rainStrength2 * 0.3;

		// Add stars at midnight.
		float starMask = 0.0f;
		float starNoise = fract(sin(dot(texcoord.xy + worldPos / 25000000.0 * vec2(frameTimeCounter / 300.0, frameTimeCounter / 300.0), vec2(18.9898f, 28.633f))) * 4378.5453f);
		      starNoise *= starNoise;
			  starNoise *= starNoise;
			  starNoise *= starNoise;
			  starNoise *= starNoise;
			  starNoise *= starNoise;
			  starNoise *= starNoise;
			  starNoise *= starNoise;
			  starNoise *= starNoise;
			  starNoise *= starNoise;
			  starNoise *= starNoise;
			  starNoise *= starNoise;
			  
		float stars = starNoise * TimeMidnight * (0.1 - hPos * 0.1);

		for (int i = 0; i < 16; i++) {
		
			intersection = wVector * ((-cameraPosition.y + 500.0 - i * 3.66 * (1+cosT2*cosT2*3.5) + cloudViewDistance * sqrt(cosT2)) / (wVector.y)); 			//curved cloud plane
			vec3 wpos = tpos.xyz + cameraPosition;
			vec2 coord1 = (intersection.xz + cameraPosition.xz) / 1000.0 / 140.0 + wind[0] * 0.2 * cloudWindSpeed;
			vec2 coord = fract(coord1/2.0);

			float noise = texture2D(noisetex,coord - wind[0] * 0.15 * cloudWindSpeed).x;
			noise += texture2D(noisetex,coord*3.5 - wind[0] * 0.15 * cloudWindSpeed).x / 3.5;
			noise += texture2D(noisetex,coord*12.25 - wind[0] * 0.15 * cloudWindSpeed).x / 12.25;
			noise += texture2D(noisetex,coord*42.87 - wind[0] * 0.15 * cloudWindSpeed).x / 42.87;	
			noise /= 1.4472;

			float cl = max(noise - cloudCover, 0.0);
			float density = max(1.0 - cl * cloudDepth, 0.) * max(1.0 - cl * cloudDepth,0.)*(i/16.)*(i/16.);

			vec3 c  = (vec3(1.0) + mix(cloudcolor, cloudcolorRain, rainStrength2)) * cloudExposure * density;
			     c += (cloudScatteringExposure*subSurfaceScattering(sunVec,fragpos,5.0)*pow(density,3.) + 5.*subSurfaceScattering2(sunVec,fragpos,0.1)*pow(density,2.)) * sunlight;
				 c += (cloudScatteringExposure*subSurfaceScattering(moonVec,fragpos,5.0)*pow(density,3.) + 5.*subSurfaceScattering2(moonVec,fragpos,0.1)*pow(density,2.)) * sunlight * moonVisibility;
			
			cl = max(cl-(abs(i-8.0)/8.)*0.15,0.)*0.08;

			totalcloud += vec4(c.rgb*exp(-totalcloud.a),cl) * remove;
			totalcloud.a = min(totalcloud.a,1.0);
			
			stars *= 1.0-totalcloud.a;

			if (totalcloud.a > 0.999) break;
			
		}

		return mix(color.rgb + stars, totalcloud.rgb, totalcloud.a * pow(cosT2, 1.2));

	}
	
#endif


vec2 texel = vec2(1.0/viewWidth,1.0/viewHeight);
vec3 aux = texture2D(gaux1, texcoord.st).rgb;
vec3 sunPos = sunPosition;
vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0f - 1.0f;


float pixeldepth = texture2D(depthtex0,texcoord.xy).x;
float shadowexit = 0.0;

float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;

#ifdef SSAO

    float readDepth( vec2 coord );
    float readDepth(vec2 coord) {
        return 2.0 * near * far / (far + near - (2.0 * texture2D(depthtex0, coord).x - 1.0) * (far - near));
    }
	
#endif

float handlight = handItemLight;
const float speed = 1.5;

float sky_lightmap = pow(aux.r,3.0);
float iswet = wetness*pow(sky_lightmap,10.0)*sqrt(0.5+max(dot(normal,normalize(upPosition)),0.0));

#ifndef INTEL_HD_GRAPHICS_FIX

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
	
		float border = 1.0;

		//edge detect
		float d = edepth(texcoord.xy);
		float dtresh = 1/(far-near)/5000.0;	
		vec4 dc = vec4(d,d,d,d);
		vec4 sa;
		vec4 sb;
		sa.x = edepth(texcoord.xy + vec2(-pw,-ph)*border);
		sa.y = edepth(texcoord.xy + vec2(pw,-ph)*border);
		sa.z = edepth(texcoord.xy + vec2(-pw,0.0)*border);
		sa.w = edepth(texcoord.xy + vec2(0.0,ph)*border);
		
		//opposite side samples
		sb.x = edepth(texcoord.xy + vec2(pw,ph)*border);
		sb.y = edepth(texcoord.xy + vec2(-pw,ph)*border);
		sb.z = edepth(texcoord.xy + vec2(pw,0.0)*border);
		sb.w = edepth(texcoord.xy + vec2(0.0,-ph)*border);
		
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
		float speed = 5.5;
		float size = 0.2;


		float px = posxz.x/50.0 + 250.0;
		float py = posxz.z/50.0  + 250.0;

		float fpx = abs(fract(px*20.0)-0.5)*2.0;
		float fpy = abs(fract(py*20.0)-0.5)*2.0;

		float d = length(vec2(fpx,fpy));

		for (int i = 1; i < 6; i++) {
			wave -= d*factor*sin( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
			factor /= 2;
		}

		factor = 1.0;
		px = -posxz.x/50.0 + 250.0;
		py = -posxz.z/150.0 - 250.0;

		fpx = abs(fract(px*20.0)-0.5)*2.0;
		fpy = abs(fract(py*20.0)-0.5)*2.0;

		d = length(vec2(fpx,fpy));
		float wave2 = 0.0;
		
		for (int i = 1; i < 6; i++) {
			wave2 -= d*factor*cos( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
			factor /= 2;
		}

		return amplitude*wave2+amplitude*wave;
	}

#endif

#ifdef DYNAMIC_TONEMAPPING

	float dynamicTonemapping(float dTDayValue, float dTNightValue) {
	
		float dTDay = dTDayValue * (TimeSunrise + TimeNoon + TimeSunset);
		float dTNight = dTNightValue * TimeMidnight;
			
		float dTBrightness = dTDay + dTNight;
			  
		return (pow(eyeBrightnessSmooth.y / 255.0, 6.0f) * 1.0 + dTBrightness);
	
	}

#endif











//////////////////////////////////////////////////////////////
/////////////////////////// MAIN /////////////////////////////
//////////////////////////////////////////////////////////////

void main() {
	


	fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));
    float volumetric_cone = max(dot(normalize(fragpos), lightVector),0.0);

	float shadowexit 	= float(aux.g == 0.2);
	float land 			= float(aux.g > 0.03);
	float iswater		= float(aux.g > 0.04 && aux.g < 0.07);
	float translucent 	= float(aux.g == 0.4);
	float hand 			= float(aux.g > 0.75 && aux.g < 0.85);
	float lightSources 	= float(aux.g > 0.56 && aux.g < 0.58);
	
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
	float SIshading = 1.0f;
	float SI = 0.0;
	float spec = 0.0;
	float time = float(worldTime);
	float transition_fading = 1.0-(clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-13000.0)/300.0,0.0,1.0) + clamp((time-22800.0)/200.0,0.0,1.0)-clamp((time-23400.0)/200.0,0.0,1.0));	//fading between sun/moon shadows
	float night = clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-22800.0)/200.0,0.0,1.0);
	
	float watersunlight = 0.0f;
	
	if (iswater == 1.0) {
	
		vec3 watercolor = vec3(1.0);
	
		#ifdef WATER_REFRACT
		
			vec3 underwaterpos = vec3(texcoord.st, texture2D(depthtex1, texcoord.st).r);
			underwaterpos = nvec3(gbufferProjectionInverse * nvec4(underwaterpos * 2.0 - 1.0));
			vec4 worldpositionuw = gbufferModelViewInverse * vec4(underwaterpos,1.0);	
			vec3 wpos = worldpositionuw.xyz + cameraPosition.xyz;
		
			vec3 posxz = worldposition.xyz + cameraPosition.xyz;
			
			posxz.x += sin(posxz.z*4.0+frameTimeCounter)*0.1;
			posxz.z += cos(posxz.x*2.0+frameTimeCounter*0.5)*0.1;
			
			float deltaPos = 0.1;
			float h0 = waterH(posxz);
			float h1 = waterH(posxz + vec3(deltaPos,0.0,0.0));
			float h2 = waterH(posxz + vec3(-deltaPos,0.0,0.0));
			float h3 = waterH(posxz + vec3(0.0,0.0,deltaPos));
			float h4 = waterH(posxz + vec3(0.0,0.0,-deltaPos));
			
			float xDelta = ((h1-h0)+(h0-h2))/deltaPos;
			float yDelta = ((h3-h0)+(h0-h4))/deltaPos;
			
			// Reduce refMult in the distance.
			float depth_diff = 1.0-clamp(pow(ld(texture2D(depthtex0, texcoord.st).r)*10.0,2.0),0.0,1.0);
			float refMult = 0.0025-dot(normal,normalize(fragposition).xyz)*0.01*depth_diff;
			
			vec3 refract = normalize(vec3(xDelta,yDelta,1.0-xDelta*xDelta-yDelta*yDelta));
			vec4 rA = texture2D(gcolor, texcoord.st + refract.xy*refMult);
			rA.rgb = pow(rA.rgb,vec3(2.2));
			vec4 rB = texture2D(gcolor, texcoord.st);
			rB.rgb = pow(rB.rgb,vec3(2.2));
			float mask = texture2D(gaux1, texcoord.st + refract.xy*refMult).g;
			mask =  float(mask > 0.04 && mask < 0.07);
			
			watercolor = rA.rgb*mask + rB.rgb*(1-mask);
			
			vec3 uPos  = nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord.xy + refract.xy*refMult, texture2D(depthtex1, texcoord.xy + refract.xy*refMult).x) * 2.0 - 1.0));  //underwater position
			
		#else
		
			watercolor = color.rgb;
			
			vec3 uPos  = nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord.xy, texture2D(depthtex1, texcoord.xy).x) * 2.0 - 1.0));  //underwater position
			
		#endif
		
		vec3 uVec = fragposition.xyz-uPos;
		float UNdotUP = abs(dot(normalize(uVec),normal));
		float depth = length(uVec)*UNdotUP;
		depth *= 0.15;
			
		if (depth > 0.95) depth = 0.95;

		if (isEyeInWater == 0.0) {

			color.rgb = mix(watercolor.rgb, vec3(0.1,0.55,1.0) * 0.1, depth);
			
			#ifdef WATER_REFRACT
			
				//watersunlight += clamp(waterH(wpos),0.0, 1.0) * 0.2 * (1.0-depth) * (1.0-rainStrength) * sky_lightmap;	
				
			#endif
			
		}
		
	}
	
	if (land == 1.0 && isEyeInWater == 0.0) {
	
		float dist = length(fragposition.xyz);

		float shadingsharp = 0.0f;
		float SIshadingsharp = 0.0f;	
		
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
		float diffthresh = 1.0*distortFactor;
		float isshadow = 0.0;
		float ssample;

		float distof = clamp(1.0-dist/shadowDistance,0.0,1.0);
		float distof2 = clamp(1.0-dist/(shadowDistance*0.75),0.0,1.0);
		float shadow_fade = clamp(distof*12.0,0.0,1.0);
		float sss_fade = pow(distof2,0.2);
		float step = 1.0/shadowMapResolution;
		
		float SI_IlluminationDistance = 30.0;
		float SIstep = 1.0 / 512.0 * SI_IlluminationDistance;
		
		
			if (dist < shadowDistance) {
				
				if (shadowexit == 1.0) {
					shading = 1.0;
					SIshading = 1.0;
				} else {
				
				#ifdef SHADOW_FILTER
				#ifndef INTEL_HD_GRAPHICS_FIX
				
					for(int i = 0; i < 25; i++){
					
						shadingsharp += (clamp(comparedepth - (0.05 + (texture2D(shadow, worldposition.st + circle_offsets[i] * step).z) * (256.0 - 0.05)), 0.0, diffthresh)/(diffthresh));
				
						#ifdef SHADOW_ILLUMINATION
					
							SIshadingsharp += (clamp(comparedepth - (0.05 + (texture2D(shadow, worldposition.st + circle_offsets[i]*SIstep).z) * (256.0 - 0.05)), 0.0, diffthresh)/(diffthresh));

						#endif
						
						
					}
					
					#ifdef SHADOW_ILLUMINATION
					
						SIshadingsharp /= 25.0;
						SIshading = 1.0-SIshadingsharp;
						
						float SI_maxBrightness = 0.25;
						SI = SIshading * SI_maxBrightness;
						
					#endif
					
					shadingsharp /= 25.0;
					shading = 1.0-shadingsharp + SI;
					isshadow = 1.0;
					
				#else 
				
					shading = (clamp(comparedepth - (0.05 + (texture2D(shadow, worldposition.st).z) * (256.0 - 0.05)), 0.0, diffthresh)/(diffthresh));
					shading = 1.0-shading;
					
				#endif
				#endif
				
				#ifndef SHADOW_FILTER
				
					shading = (clamp(comparedepth - (0.05 + (texture2D(shadow, worldposition.st).z) * (256.0 - 0.05)), 0.0, diffthresh)/(diffthresh));
					shading = 1.0-shading;
					
				#endif
				
				}
				
			}		
		
		const float sssExposure = 0.2;
		float sss_transparency = mix(0.0,0.75,translucent);		//subsurface scattering amount
		float sunlight_direct = 1.0;
		float direct = 1.0;
		float sss = 0.0;
		vec3 npos = normalize(fragposition.xyz);
		float NdotL = 1.0;
		
		NdotL = dot(normal, lightVector);
		direct = NdotL;
			
		sunlight_direct = max(direct, 0.0);
		sunlight_direct = mix(sunlight_direct,0.75,translucent*min(sss_fade+0.4,1.0));
		
		sss += pow(max(dot(npos, lightVector),0.0),20.0)*sss_transparency*clamp(-NdotL,0.0,1.0)*translucent * sssExposure;
		
		sss = mix(0.0,sss,sss_fade);
		shading = clamp(shading,0.0,1.0);
		SIshading = clamp(SIshading,0.0,1.0);
		
		
		// Ambientcolor
	    vec3 ambientColor_sunrise = vec3(1.1, 1.2, 1.27) * 0.7 * TimeSunrise * (1.0- rainStrength2 * 1.0);
	    vec3 ambientColor_noon = vec3(0.9, 1.1, 1.27) * 1.5 * TimeNoon * (1.0- rainStrength2 * 1.0);
	    vec3 ambientColor_sunset = vec3(1.1, 1.2, 1.27) * 0.7 * TimeSunset * (1.0- rainStrength2 * 1.0);
	    vec3 ambientColor_midnight = vec3(0.03, 0.15, 0.30) * 0.5 * TimeMidnight * (1.0- rainStrength2 * 1.0);
        vec3 ambientColor_rain_day = vec3(2.0, 2.0, 2.0)  * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength2;
        vec3 ambientColor_rain_night = vec3(0.1, 0.2, 0.30) * TimeMidnight * rainStrength2;
		
	    vec3 ambient_color = ambientColor_sunrise + ambientColor_noon + ambientColor_sunset + ambientColor_midnight + ambientColor_rain_day + ambientColor_rain_night;
		
		
		// Sunlightcolor
		vec3 sunlightColor_sunrise = vec3(2.52, 0.65, 0.0) * 0.7 * TimeSunrise;
		vec3 sunlightColor_noon = vec3(2.52, 1.9, 1.3) * TimeNoon;
		vec3 sunlightColor_sunset = vec3(2.52, 0.65, 0.0) * 0.7 * TimeSunset;
		vec3 sunlightColor_midnight = vec3(0.07, 0.12, 0.3) * 0.2 * TimeMidnight;
		
		vec3 sunlight_color = sunlightColor_sunrise + sunlightColor_noon + sunlightColor_sunset + sunlightColor_midnight;
		
		vec3 Sunlight_lightmap = sunlight_color*mix(max(sky_lightmap-rainStrength2*1.0,0.0),shading*(1.0-rainStrength2*1.0),shadow_fade)*0.35 * sunlight_direct *transition_fading*sky_lightmap*(1.0-iswater*0.8);
		
		#ifdef SHADOW_ILLUMINATION
		
			float SI_maxDarkness = 1.0;
			float SInormal = SI_maxDarkness * (1.0-rainStrength2);
			float SIrain   = 1.0 * rainStrength2;
		
			float SIbrightness = SInormal + SIrain;
			
		#else
		
			float SIbrightness = 1.0;
			
		#endif
		
		float sky_inc = sqrt(direct*0.5+0.51);
		vec3 amb = (sky_inc*ambient_color+(1.0-sky_inc)*(sunlight_color+ambient_color*2.0)*vec3(0.2,0.24,0.27))*vec3(0.8,0.8,1.0)*SIbrightness;
		
		float min_light = 0.0005f;
	
	
		#ifdef DYNAMIC_TONEMAPPING

			amb = amb / dynamicTonemapping(0.25, 1.0);
			sunlight_color = sunlight_color * 0.7 / dynamicTonemapping(0.25, 1.0);
			
		#endif
		
		// Torchlight properties.
		float torchDistanceOutsideDay   = 15.0f * sky_lightmap       * (TimeSunrise + TimeNoon + TimeSunset);
		float torchDistanceInsideDay    = 5.0f  * (1.0-sky_lightmap) * (TimeSunrise + TimeNoon + TimeSunset);
		
		float torchHDistanceOutsideDay  = 2.0f  * sky_lightmap       * (TimeSunrise + TimeNoon + TimeSunset);
		float torchHDistanceInsideDay   = 9.0f * (1.0-sky_lightmap) * (TimeSunrise + TimeNoon + TimeSunset);
		
		float torchBrightnessOutsideDay = 0.5f  * sky_lightmap       * (TimeSunrise + TimeNoon + TimeSunset);
		float torchBrightnessInsideDay  = 0.5f * (1.0-sky_lightmap) * (TimeSunrise + TimeNoon + TimeSunset);
		
		
		float torchDistanceNight        = 5.0f  * TimeMidnight;
		float torchHDistanceNight       = 11.0f * TimeMidnight;
		float torchBrightnessNight      = 0.5f * TimeMidnight;
		
		
		float torchDistance          = torchDistanceOutsideDay   + torchDistanceInsideDay   + torchDistanceNight;
		float torchHandlightDistance = torchHDistanceOutsideDay  + torchHDistanceInsideDay  + torchHDistanceNight;
		float torchBrightness        = torchBrightnessOutsideDay + torchBrightnessInsideDay + torchBrightnessNight;
		
		
		float torch_lightmap = pow(aux.b, torchDistance) * torchBrightness;
		vec3 torchcolor = vec3(2.55, 0.95, 0.3);
		vec3 Torchlight_lightmap = (torch_lightmap+handlight*pow(max(torchHandlightDistance-length(fragposition.xyz),0.0)/torchHandlightDistance,5.0)*max(dot(-fragposition.xyz,normal),0.0)) *  torchcolor;
		
		
		
		vec3 color_sunlight = Sunlight_lightmap;
		vec3 color_torchlight = Torchlight_lightmap;
			
		#ifdef SSAO
		#ifndef INTEL_HD_GRAPHICS_FIX
				
			float depth = readDepth(texcoord.xy);
			float d;
			float ssao = 0.0;
			
			float ssaoDepth = exp(-pow(length(fragpos)/10.0,3.0));
			float ssaoFactor =  clamp(ssaoDepth + hand,0.0,1.0);

			float ssaoDarkness = 120.0;
			float ssaoMultiplier = 5.0;
			float ssaoRange = 0.03;
		   
			for(int i = 0; i < 25; i++){
				
				d=readDepth( vec2(texcoord.x + pw * 4.0,texcoord.y + ph * 4.0) + circle_offsets[i] * ssaoRange * ssaoFactor);
				ssao+=min(1.0,max(0.0,depth-d) * ssaoMultiplier);

				d=readDepth( vec2(texcoord.x - pw * 4.0,texcoord.y + ph * 4.0) + circle_offsets[i] * ssaoRange * ssaoFactor);
				ssao+=min(1.0,max(0.0,depth-d) * ssaoMultiplier);

				d=readDepth( vec2(texcoord.x + pw * 4.0,texcoord.y - ph * 4.0) + circle_offsets[i] * ssaoRange * ssaoFactor);
				ssao+=min(1.0,max(0.0,depth-d) * ssaoMultiplier);

				d=readDepth( vec2(texcoord.x - pw * 4.0,texcoord.y - ph * 4.0) + circle_offsets[i] * ssaoRange * ssaoFactor);
				ssao+=min(1.0,max(0.0,depth-d) * ssaoMultiplier);
				
			}
			
			pw*=2.0;
			ph*=2.0;
			ssaoMultiplier/=2.0;

			ssao /= ssaoDarkness;
		    
			color = (1.0 - ssao * ssaoFactor) * color;

		#endif
		#endif
		
		// Ground get's darker it's wet.
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
		color = (amb * 0.06 * sky_lightmap + min_light + (watersunlight*shading*sunlight_color) + color_sunlight + color_torchlight + sss * sunlight_color * shading * (1.0-rainStrength2*1.0) * transition_fading) * color;

		
	} else if (isEyeInWater == 0.0) {
	
		const bool overwriteSky = true;
		
	    vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
	    fragposition /= fragposition.w;
	
	    vec4 worldposition = vec4(0.0);
	    worldposition = gbufferModelViewInverse * fragposition  / far * 128.0;	
		
		float horizont = abs(worldposition.y - texcoord.y);
		float skycolor_position = clamp(max(pow(max(1.0 - horizont/(35.0*100.0),0.01),8.0)-0.1,0.0), 0.35, 1.0);
		float horizont_position = max(pow(max(1.0 - horizont/(7.5*100.0),0.01),8.0)-0.1,0.0);
		
		// Get sun color.
	    vec3 suncolor_sunrise = vec3(2.52, 1.2, 0.0) * TimeSunrise;
	    vec3 suncolor_noon = vec3(2.52, 2.25, 2.0) * TimeNoon;
	    vec3 suncolor_sunset = vec3(2.52, 1.0, 0.0) * TimeSunset;
		vec3 suncolor_midnight = vec3(0.3, 0.7, 1.3) * 0.05 * TimeMidnight * (1.0 - rainStrength2 * 1.0);
	
	    vec3 suncolor = suncolor_sunrise + suncolor_noon + suncolor_sunset + suncolor_midnight;
			 suncolor.r = pow(suncolor.r, 1.0 - rainStrength2 * 0.5);
			 suncolor.g = pow(suncolor.g, 1.0 - rainStrength2 * 0.5);
			 suncolor.b = pow(suncolor.b, 1.0 - rainStrength2 * 0.5);
		
		if (overwriteSky) {
		
			// Overwrite sky colors.
			vec3 skycolor_sunrise = vec3(0.5, 0.7, 1.0) * 0.2 * (1.0-rainStrength2*1.0) * TimeSunrise;
			vec3 skycolor_noon = vec3(0.2, 0.45, 1.0) * 0.4 * (1.0-rainStrength2*1.0) * TimeNoon;
			vec3 skycolor_sunset = vec3(0.5, 0.7, 1.0) * 0.2 * (1.0-rainStrength2*1.0) * TimeSunset;
			vec3 skycolor_night = vec3(0.0, 0.0, 0.0) * TimeMidnight;
			vec3 skycolor_rain_day = vec3(1.2, 1.6, 2.0) * 0.1 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength2;
			vec3 skycolor_rain_night = vec3(0.0, 0.0, 0.0) * TimeMidnight * rainStrength2;
			color.rgb = (skycolor_sunrise + skycolor_noon + skycolor_sunset + skycolor_night + skycolor_rain_day + skycolor_rain_night) * skycolor_position;
			
			vec3 horizontColor_sunrise = vec3(2.52, 1.8, 1.0) * 0.28 * TimeSunrise;
			vec3 horizontColor_noon = vec3(2.0, 2.25, 2.55) * 0.27 * TimeNoon;
			vec3 horizontColor_sunset = vec3(2.52, 1.6, 0.8) * 0.28 * TimeSunset;
			vec3 horizontColor_night = vec3(0.3, 0.7, 1.3) * 0.03 * (1.0-rainStrength2*1.0) * TimeMidnight;
			vec3 horizontColor_rain_night = vec3(0.3, 0.7, 1.3) * 0.01 * TimeMidnight * rainStrength2;
			
			vec3 horizontColor = horizontColor_sunrise + horizontColor_noon + horizontColor_sunset + horizontColor_night + horizontColor_rain_night;
			color.rgb = mix(color.rgb, horizontColor * 0.6, horizont_position);

			
			
			// New sun/moon.
			// ambient color.
			#ifdef GODRAYS
				color.rgb += pow(volumetric_cone, 5.0) * 0.03 * suncolor * transition_fading;
			#else
				color.rgb += pow(volumetric_cone, 5.0) * 0.1 * suncolor * transition_fading;
			#endif
				
			// Sun.
			color.rgb += clamp(pow(volumetric_cone, 700.0), 0.0, 0.2) * suncolor.rgb * 2.0 * transition_fading * (1.0 - rainStrength2 * 0.6) * (TimeSunrise + TimeNoon + TimeSunset);
			
			// Moon.
			color.rgb += clamp(pow(volumetric_cone, 1000.0), 0.0, 0.2) * vec3(0.85, 1.05, 1.3) * transition_fading * (1.0 - rainStrength2 * 1.0) * TimeMidnight;
		
		}
			
		
		#ifdef CLOUDS
		
			// Remove clouds under land
			float remove = clamp(worldposition.y + length(worldposition.y), 0.0, 1.0);
		
			vec3 cloudcolor_normal = vec3(1.0, 1.0, 1.0) * (TimeSunrise + TimeNoon + TimeSunset) * (1.0-rainStrength2);
			vec3 cloudcolor_midnight = vec3(0.1, 0.7, 1.3) * TimeMidnight * (1.0-rainStrength2);
			vec3 cloudColor = cloudcolor_normal + cloudcolor_midnight;
			
			vec3 cloudcolor_rain_day = vec3(0.25,0.32,0.4) * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength2;
			vec3 cloudcolor_rain_night = vec3(0.1, 0.7, 1.3) * TimeMidnight * rainStrength2;
			vec3 cloudColorRain = cloudcolor_rain_day + cloudcolor_rain_night;
		
			color.rgb = drawCloud(fragpos.xyz, color.rgb, cloudColor, cloudColorRain, suncolor * transition_fading, remove, worldposition.xy, horizont_position);
			
		#endif
		
		#ifdef DYNAMIC_TONEMAPPING
		
			color.rgb = color.rgb * 0.7 / dynamicTonemapping(0.15, 1.0);
			
		#endif
	
	}
	
	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
	tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lightPos = pos1*0.5+0.5;
	
	#ifdef FOG
	
	    float groundPosition = abs(worldposition.y + cameraPosition.y - 65);
		float fogHeight = max(pow(max(1.0 - groundPosition/(1.0*100.0),0.01),8.0)-0.1,0.0) * (1.0-rainStrength2);
		
		// Get sun color.
	    vec3 suncolor_sunrise = vec3(2.52, 1.2, 0.0) * TimeSunrise;
	    vec3 suncolor_noon = vec3(2.52, 2.25, 2.0) * TimeNoon;
	    vec3 suncolor_sunset = vec3(2.52, 1.0, 0.0) * TimeSunset;
		vec3 suncolor_midnight = vec3(0.3, 0.7, 1.3) * 0.05 * TimeMidnight * (1.0 - rainStrength2 * 1.0);
	
	    vec3 suncolor = suncolor_sunrise + suncolor_noon + suncolor_sunset + suncolor_midnight;
			 suncolor.r = pow(suncolor.r, 1.0 - rainStrength2 * 0.5);
			 suncolor.g = pow(suncolor.g, 1.0 - rainStrength2 * 0.5);
			 suncolor.b = pow(suncolor.b, 1.0 - rainStrength2 * 0.5);
	
	    // Fog distance.
		float fog_sunrise = 85.0 * TimeSunrise *  (1.0-rainStrength2*1.0);
		float fog_noon = 150.0 * TimeNoon * (1.0-rainStrength2*1.0);
	    float fog_sunset = 200.0 * TimeSunset * (1.0-rainStrength2*1.0);
		float fog_midnight = 75.0 * TimeMidnight * (1.0-rainStrength2*1.0);
	    float fog_rain = 25.0 * rainStrength2;
	    float fog_distance = fog_sunrise + fog_noon + fog_sunset + fog_midnight + fog_rain;
	
	    // Get fog color. 
		vec3 fogclr_sunrise = vec3(0.75, 0.9, 1.27) * 0.5 * TimeSunrise * (1.0-rainStrength2*1.0);
		vec3 fogclr_noon = vec3(0.6, 0.8, 1.27) * 0.5 * TimeNoon * (1.0-rainStrength2*1.0);
	    vec3 fogclr_sunset = vec3(0.75, 0.9, 1.27) * 0.5 * TimeSunset * (1.0-rainStrength2*1.0);
	    vec3 fogclr_midnight = vec3(0.2, 0.6, 1.3) * 0.01 * TimeMidnight * (1.0-rainStrength2*1.0);
	    vec3 fogclr_rain_day = vec3(1.5, 1.9, 2.55) * 0.2 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength2;
	    vec3 fogclr_rain_night = vec3(0.35, 0.7, 1.3) * 0.01  * TimeMidnight * rainStrength2;
		
	    vec3 fogclr = fogclr_sunrise + fogclr_noon + fogclr_sunset + fogclr_midnight + fogclr_rain_day + fogclr_rain_night;
			 fogclr += suncolor * pow(volumetric_cone, 10.0) * 0.2 * transition_fading;
			 fogclr *= (eyeBrightness.y / 255.0);
	 
	    if (land == 1.0) {		
	        float depth_diff2 = exp(-pow(length(fragpos)/fog_distance,3.0));
	        float fogfactor =  clamp(depth_diff2 + hand,0.0,1.0);
	        color.rgb += mix(fogclr * 0.1 + fogclr * 0.11 * fogHeight, color.rgb, fogfactor);
	    }
		
	#else
	
		// Fix dark landscape when fog is disabled.
	    if (land == 1.0) {		
	        color.rgb *= 1.75;
	    }
		
	#endif

/* DRAWBUFFERS:31 */

#ifdef CELSHADING

	if (land > 0.9 && iswater < 0.9) color = celshade(color);
	
#endif


	
	
	#ifdef GODRAYS
	
		const float density = 0.5;			
		const int NUM_SAMPLES = 10;
		const float grnoise = 0.0;	
	
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
			
			float sample = step(texture2D(gaux1, textCoord + deltaTextCoord * noise * grnoise).g,0.01);
			gr += sample;
					
		}

	#endif

		
	color = pow(color,vec3(1.0/2.2));
	color = clamp(color,0.0,1.0);
	gl_FragData[0] = vec4(color, 0.0);
	
	#ifdef GODRAYS
		gl_FragData[1] = vec4(vec3((gr/NUM_SAMPLES)),1.0);
	#endif
}
