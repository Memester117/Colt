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

	#define GODRAYS
		#define DYNAMIC_TONEMAPPING
		
	#define CLOUDS						// For reflections.
	
	#define WATER_REFLECTIONS		

	#define SPECULAR_MAPPING	
	
	//#define MOTIONBLUR











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

uniform sampler2D noisetex;
uniform sampler2D composite;
uniform sampler2D gaux4;
uniform sampler2D gaux3;
uniform sampler2D gaux2;
uniform sampler2D gaux1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D gnormal;
uniform sampler2D gdepth;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;
uniform int isEyeInWater;
uniform int worldTime;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform float frameTimeCounter;
uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;

float rainStrength2 = clamp(wetness, 0.0f, 1.0f)/1.0f;

uniform int fogMode;

float pixeldepth = texture2D(depthtex0,texcoord.xy).x;
float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;

float matflag = texture2D(gaux1,texcoord.xy).g;
	
vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);
vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
	
vec4 color = texture2D(composite,texcoord.xy);

float handlight = handItemLight;
	
vec3 aux = texture2D(gaux1, texcoord.st).rgb;
float sky_lightmap = pow(aux.r,3.0);

float iswet = wetness*pow(sky_lightmap,10.0)*sqrt(0.5+max(dot(normal,normalize(upPosition)),0.0));

vec3 specular = pow(texture2D(gaux3,texcoord.xy).rgb,vec3(2.2));
float specmap = (specular.r+specular.g*(iswet));

float timefract = worldTime;
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 2000.0)/2000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 2000.0)) / 2000.0) - ((clamp(timefract, 10000.0, 12000.0) - 10000.0) / 2000.0);
float TimeSunset   = ((clamp(timefract, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

	


float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.x-0.5),abs(coord.y-0.5))*2.0;
}

#ifdef GODRAYS

	float getnoise(vec2 pos) {
		return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
	}

#endif

#ifdef LENS_EFFECTS

	float distratio(vec2 pos, vec2 pos2, float ratio) {
		float xvect = pos.x*ratio-pos2.x*ratio;
		float yvect = pos.y-pos2.y;
		return sqrt(xvect*xvect + yvect*yvect);
	}

	float gen_circular_lens(vec2 center, float size) {
		return 1.0-pow(min(distratio(texcoord.xy,center,aspectRatio),size)/size,10.0);
	}

	vec2 noisepattern(vec2 pos) {
		return vec2(abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f)),abs(fract(sin(dot(pos.yx ,vec2(18.9898f,28.633f))) * 4378.5453f)));
	} 

#endif

#ifdef SPECULAR_MAPPING

	// Using 2D clouds for creating rain puddle and dirty lens.
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
		f += 0.50000*noise( p ); p = p*2.5;
		f += 0.25000*noise( p ); p = p*2.5;
		f += 0.12500*noise( p ); p = p*2.5;
		f += 0.06250*noise( p ); p = p*2.5;
		f += 0.03125*noise( p );
		return f/0.984375;
	}

#endif

#ifdef WATER_REFLECTIONS

	vec4 raytrace(vec3 fragpos, vec3 normal, vec3 skyCl) {
	
		const int maxf = 6;				// Number of refinements
		const float stp = 1.0;			// Size of one step for raytracing algorithm
		const float ref = 0.1;			// Refinement multiplier
		const float inc = 2.0;			// Increasement factor at each step
		
		vec3 rvector = normalize(reflect(normalize(fragpos), normalize(normal)));
		
		// Black dots fix.
		vec4 wrv = (gbufferModelViewInverse*vec4(rvector,1.0));
		wrv.y *= sign(dot(upVec,rvector));
		rvector = normalize((gbufferModelView*wrv).rgb);
		
		vec4 color = vec4(0.0);
		vec3 start = fragpos;
		vec3 vector = stp * rvector;
		vec3 oldpos = fragpos;
		fragpos += vector;
		vec3 tvector = vector;
		int sr = 0;
		
		for(int i = 0; i < 30; i++){
			
			vec3 pos = nvec3(gbufferProjection * nvec4(fragpos)) * 0.5 + 0.5;
			if(pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;
			vec3 spos = vec3(pos.st, texture2D(depthtex1, pos.st).r);
			spos = nvec3(gbufferProjectionInverse * nvec4(spos * 2.0 - 1.0));
			float err = distance(fragpos.xyz,spos.xyz);
			
			if(err < length(vector)*pow(length(tvector),0.11)*1.75){
				
				sr++;
					
				if(sr >= maxf) {
				
					float land = texture2D(gaux1, pos.st).g;
					land = float(land < 0.03);
						
					float border = clamp(1.0 - pow(cdist(pos.st), 5.0), 0.0, 1.0);
					color = texture2D(composite, pos.st);
					if (land > 0.9) color.rgb = skyCl * 0.73;
					color.a = 1.0;
					color.a *= border;
										
					break;
						
				}
					
					tvector -=vector;
					vector *= ref;
					
			}
				
			vector *= inc;
			oldpos = fragpos;
			tvector += vector;
			fragpos = start + tvector;
			
		}
		
		return color;
		
	}

#endif

#ifdef SPECULAR_MAPPING

	vec4 raytraceGround(vec3 fragpos, vec3 normal, vec3 skyCl) {

		const int Gmaxf = 4;			// Number of refinements
		const float Gstp = 1.0;			// Size of one step for raytracing algorithm
		const float Gref = 0.1;			// Refinement multiplier
		const float Ginc = 2.4;			// Increasement factor at each step
		
		vec3 rvector = normalize(reflect(normalize(fragpos), normalize(normal)));
		
		// Black dots fix.
		vec4 wrv = (gbufferModelViewInverse*vec4(rvector,1.0));
		wrv.y *= sign(dot(upVec,rvector));
		rvector = normalize((gbufferModelView*wrv).rgb);

		vec4 color = vec4(0.0);
		vec3 start = fragpos;
		vec3 vector = Gstp * rvector;
		vec3 oldpos = fragpos;
		fragpos += vector;
		vec3 tvector = vector;
		int sr = 0;
		
		for(int i=0;i<30;i++){
		
			vec3 pos = nvec3(gbufferProjection * nvec4(fragpos)) * 0.5 + 0.5;
			if(pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;
			
			vec3 spos = vec3(pos.st, texture2D(depthtex1, pos.st).r);
			spos = nvec3(gbufferProjectionInverse * nvec4(spos * 2.0 - 1.0));
			float err = distance(fragpos.xyz,spos.xyz);
			
			if(err < pow(length(vector)*pow(length(tvector),0.11),1.1)*1.1){

				sr++;
				
				if(sr >= Gmaxf){
				
					float land = texture2D(gaux1, pos.st).g;
					land = float(land < 0.03);
						
					float border = clamp(1.0 - pow(cdist(pos.st), 5.0), 0.0, 1.0);
					color = texture2D(composite, pos.st);
					if (land > 0.9) color.rgb = skyCl * 0.72;
					color.a = 1.0;
					color.a *= border;
					break;
					
				}
				
				tvector -=vector;
				vector *=Gref;
			
			}
			
			vector *= Ginc;
			oldpos = fragpos;
			tvector += vector;
			fragpos = start + tvector;
			
		}
		
		return color;
	}

#endif

float sunReflection(vec3 ppos, vec3 lvector, vec3 normal) {

	//half vector
	vec3 pos = normalize(-ppos);
	vec3 cHalf = normalize(lvector + pos);
		
	// beckman's distribution function D
	float normalDotHalf = dot(normal, cHalf);
	float normalDotHalf2 = normalDotHalf * normalDotHalf;

	float roughness2 = 0.03;
	float exponent = -(1.0 - normalDotHalf2) / (normalDotHalf2 * roughness2);
	float e = 2.71828182846;
	float D = pow(e, exponent) / (roughness2 * normalDotHalf2 * normalDotHalf2);
		
	// fresnel term F
	float normalDotEye = dot(normal, pos);
	float F = pow(1.0 - normalDotEye, 1.0);

	// self shadowing term G
	float normalDotLight = dot(normal, lvector);
	float X = 2.0 * normalDotHalf / dot(pos, cHalf);
	float G = min(1.0, min(X * normalDotLight, X * normalDotEye));
	float pi = 3.1415927;
	float CookTorrance = (D*F*G) / (pi * normalDotEye);
		
	return max(CookTorrance /pi, 0.0);
	
}

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

	vec3 drawCloud(vec3 fposition, vec3 color, vec3 cloudcolor, vec3 cloudcolorRain, vec3 sunlight) {

		float cloudDepth	  		  = 0.5;
		float cloudCover	  		  = 1.0;
		float cloudExposure	  		  = 8.0;
		float cloudScatteringExposure = 17.0;
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

		for (int i = 0; i < 2 ;i++) {
		
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
			float density = max(1.0 - cl * cloudDepth, 0.) * max(1.0 - cl * cloudDepth,0.)*(i/2.)*(i/2.);

			vec3 c  = (vec3(1.0) + mix(cloudcolor, cloudcolorRain, rainStrength2)) * cloudExposure * density;
			     c += (cloudScatteringExposure*subSurfaceScattering(sunVec,fragpos,5.0)*pow(density,3.) + 5.*subSurfaceScattering2(sunVec,fragpos,0.1)*pow(density,2.)) * sunlight;
				 c += (cloudScatteringExposure*subSurfaceScattering(moonVec,fragpos,5.0)*pow(density,3.) + 5.*subSurfaceScattering2(moonVec,fragpos,0.1)*pow(density,2.)) * sunlight * moonVisibility;
			
			totalcloud += vec4(c.rgb*exp(-totalcloud.a),cl);
			totalcloud.a = min(totalcloud.a,1.0);

			if (totalcloud.a > 0.999) break;
			
		}

		return mix(color.rgb, totalcloud.rgb, totalcloud.a * pow(cosT2, 1.2));

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

	int land = int(matflag < 0.03);
	int iswater = int(matflag > 0.04 && matflag < 0.07);
	int hand  = int(matflag > 0.75 && matflag < 0.85);
	
	fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));
    float volumetric_cone = max(dot(normalize(fragpos),lightVector),0.0);
	
	float time = float(worldTime);
	float transition_fading = 1.0-(clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-13000.0)/300.0,0.0,1.0) + clamp((time-22800.0)/200.0,0.0,1.0)-clamp((time-23400.0)/200.0,0.0,1.0));	//fading between sun/moon shadows
	
	#ifdef MOTIONBLUR

		vec4 depth  = texture2D(depthtex2, texcoord.st);
		
		vec4 currentPosition = vec4(texcoord.x * 2.0 - 1.0, texcoord.y * 2.0 - 1.0, 2.0 * depth.x - 1.0, 1.0);
		
		vec4 fragposition = gbufferProjectionInverse * currentPosition;
		fragposition = gbufferModelViewInverse * fragposition;
		fragposition /= fragposition.w;
		fragposition.xyz += cameraPosition;
		
		vec4 previousPosition = fragposition;
		previousPosition.xyz -= previousCameraPosition;
		previousPosition = gbufferPreviousModelView * previousPosition;
		previousPosition = gbufferPreviousProjection * previousPosition;
		previousPosition /= previousPosition.w;

		vec2 velocity = (currentPosition - previousPosition).st * 0.05;

		int samples = 1;

		vec2 coord = texcoord.st + velocity;
		for (int i = 0; i < 8; ++i, coord += velocity) {
			if (coord.s > 1.0 || coord.t > 1.0 || coord.s < 0.0 || coord.t < 0.0) {
				break;
			}
				color += texture2D(composite, coord);
				++samples;
		}

		color = (color/1.0) / samples;
	
	#endif
	
	// Add sky colors.
	vec3 skycolor_sunrise = vec3(1.0, 0.95, 0.9) * 0.75 * TimeSunrise;
	vec3 skycolor_noon = vec3(0.7, 0.8, 1.0) * 0.9 * TimeNoon * (1.0-rainStrength2);
	vec3 skycolor_sunset = vec3(1.0, 0.8, 0.7) * 0.75 * TimeSunset;
	vec3 skycolor_night = vec3(0.6, 1.0, 1.3) * 0.13 * TimeMidnight;
	vec3 skycolor_rain_night = vec3(1.0, 1.0, 1.0) * 0.01 * TimeMidnight * rainStrength2;
	vec3 skycolor_rain_noon = vec3(1.0, 1.0, 1.0) * 0.7 * TimeNoon * rainStrength2;
	vec3 skycolor = (skycolor_sunrise + skycolor_noon + skycolor_sunset + skycolor_night + skycolor_rain_night + skycolor_rain_noon) * (eyeBrightness.y/255.0);
	
	// Get sun color.
	vec3 suncolor_sunrise = vec3(2.52, 1.2, 0.0) * TimeSunrise;
	vec3 suncolor_noon = vec3(2.52, 2.25, 2.0) * TimeNoon;
	vec3 suncolor_sunset = vec3(2.52, 1.0, 0.0) * TimeSunset;
	vec3 suncolor_midnight = vec3(0.3, 0.7, 1.3) * 0.05 * TimeMidnight * (1.0 - rainStrength2 * 1.0);

	vec3 suncolor = suncolor_sunrise + suncolor_noon + suncolor_sunset + suncolor_midnight;
		 suncolor.r = pow(suncolor.r, 1.0 - rainStrength2 * 0.5);
		 suncolor.g = pow(suncolor.g, 1.0 - rainStrength2 * 0.5);
		 suncolor.b = pow(suncolor.b, 1.0 - rainStrength2 * 0.5);
		
	// Get sun color for reflection.
	vec3 suncolorRef_sunrise = vec3(1.0, 0.6, 0.2) * TimeSunrise * (1.0 - rainStrength2 * 0.5);
	vec3 suncolorRef_noon = vec3(2.55, 2.55, 2.55) * TimeNoon * (1.0 - rainStrength2 * 0.5);
	vec3 suncolorRef_sunset = vec3(1.0, 0.6, 0.2) * TimeSunset * (1.0 - rainStrength2 * 0.5);
	
	vec3 suncolorRef = suncolorRef_sunrise + suncolorRef_noon + suncolorRef_sunset;
		 suncolorRef.r = pow(suncolorRef.r, 1.0 - rainStrength2 * 0.5);
		 suncolorRef.g = pow(suncolorRef.g, 1.0 - rainStrength2 * 0.5);
		 suncolorRef.b = pow(suncolorRef.b, 1.0 - rainStrength2 * 0.5);
		
	#ifndef MOTIONBLUR
		vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
		fragposition /= fragposition.w;
	#endif
	
	vec4 worldposition = vec4(0.0);
	worldposition = gbufferModelViewInverse * fragposition  / far * 128.0;	
		
	vec3 cloudcolor_normal = vec3(1.0, 1.0, 1.0) * (TimeSunrise + TimeNoon + TimeSunset) * (1.0-rainStrength2);
	vec3 cloudcolor_midnight = vec3(0.1, 0.7, 1.3) * TimeMidnight * (1.0-rainStrength2);
	vec3 cloudColor = cloudcolor_normal + cloudcolor_midnight;
	
	vec3 cloudcolor_rain_day = vec3(0.25,0.32,0.4) * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength2;
	vec3 cloudcolor_rain_night = vec3(0.1, 0.7, 1.3) * TimeMidnight * rainStrength2;
	vec3 cloudColorRain = cloudcolor_rain_day + cloudcolor_rain_night;
		
	vec3 reflectedVector = reflect(normalize(fragpos), normalize(normal));
	reflectedVector = fragpos + reflectedVector * (2000.0-fragpos.z);
	
	vec3 sunRef = sunReflection(fragpos.xyz, lightVector, normalize(normal)) * suncolorRef * 0.1 * transition_fading;
		
	#ifdef CLOUDS
		vec3 sky = (drawCloud(reflectedVector.xyz, skycolor.rgb, cloudColor, cloudColorRain, suncolor * 2.0 * transition_fading) + sunRef) * sky_lightmap;
	#else
		vec3 sky = (skycolor.rgb + sunRef) * sky_lightmap;
	#endif
		
	if (iswater == 1.0) {
		
		#ifdef WATER_REFLECTIONS
			vec4 reflection = raytrace(fragpos, normal, sky.rgb);
		#else
			vec4 reflection = vec4(0.0);
		#endif
		
		const float reflectionStrength = 0.5;
				
		float normalDotEye = dot(normal, normalize(fragpos));
		float fresnel = clamp(pow(1.0 + normalDotEye, 1.0),0.0,1.0);
				
		reflection.rgb = mix(sky.rgb, reflection.rgb, reflection.a);			//fake sky reflection, avoid empty spaces
		reflection.a = min(reflection.a + 0.75, 1.0);
				
		color.rgb = mix(color.rgb, reflection.rgb, fresnel * reflection.a * reflectionStrength);
		
	}

	#ifdef SPECULAR_MAPPING
	
		const bool rainReflection = true;
		const bool specularMapping = true;
		const float rainReflectionStrength = 0.4;
		const float specularReflectionStrength = 0.7;
		
		if (rainReflection && land == 0.0 && rainStrength2 > 0.01 && iswater == 0.0) {
		
			// Using 2D clouds for creating rain puddle
			vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
			fragposition /= fragposition.w;
		
			vec4 worldposition = vec4(0.0);
			worldposition = gbufferModelViewInverse * fragposition;	
		
			// Set up domain
			vec2 q = (worldposition.xz + cameraPosition.xz);
			vec2 p = -1.0 + 3.0 * q;
				
			// Resolution
			p /= 35.0;
		
			// Create noise using fBm
			float f = fbm( 4.0*p);
	 
			float cover = 0.55f * rainStrength2;
			float sharpness = 0.99;	// Brightness
		
			float c = f - (1.0 - cover);
			if ( c < 0.0 )
				c = 0.0;
		
			f = 1.0 - (pow(1.0 - sharpness, c));

			vec4 reflection = raytraceGround(fragpos, normal, skycolor);
				
				float normalDotEye = dot(normal, normalize(fragpos));
				float fresnel = clamp(pow(1.0 + normalDotEye, 1.0),0.0,1.0);
				
				reflection.rgb = mix(sky.rgb * sky_lightmap, reflection.rgb, reflection.a);			//fake sky reflection, avoid empty spaces
				reflection.a = min(reflection.a + 0.75,1.0);
				
				color.rgb = mix(color.rgb, reflection.rgb, fresnel * reflection.a * (iswet * rainReflectionStrength + f * 0.6 * iswet));

		}
		
		if (specularMapping && land == 0.0 && iswater == 0.0 && hand == 0.0) {
			
			vec4 reflection = raytraceGround(fragpos, normal, skycolor);
				
				float normalDotEye = dot(normal, normalize(fragpos));
				float fresnel = clamp(pow(1.0 + normalDotEye, 1.0),0.0,1.0);
				
				reflection.rgb = mix(sky.rgb * sky_lightmap, reflection.rgb, reflection.a);			//fake sky reflection, avoid empty spaces
				reflection.a = min(reflection.a + 0.75,1.0);
				
				color.rgb = mix(color.rgb, reflection.rgb, fresnel * reflection.a * specmap * specularReflectionStrength);

		}
		
	#endif

	if (isEyeInWater == 1.0) {
		float groundPosition = abs(worldposition.y + cameraPosition.y - 55);
		float fogHeight = max(pow(max(1.0 - groundPosition/(50.0),0.01),8.0)-0.1,0.0);

		float depth_diff2 = exp(-pow(length(fragpos) / 10.0, 1.0));
		float fogfactor =  1.0 - clamp(depth_diff2, 0.0, 1.0);

		vec3 colorMul = vec3(0.18,0.3,0.4) * 0.5;
		color.rgb = mix(color.rgb * colorMul, vec3(0.2,0.6,1.0) * 0.15, fogfactor);
	}
		
		
/* DRAWBUFFERS:5 */
	
	//draw rain
	if (hand == 0.0) {
	
		vec3 rainTex = texture2D(gaux4, texcoord.xy).rgb;
		
		float rainTexExp_day = 0.35 * (TimeSunrise + TimeNoon + TimeSunset);
		float rainTexExp_night = 0.1 * TimeMidnight;
		
		color.rgb += rainTex * (rainTexExp_day + rainTexExp_night);
		
	}
	
	
	vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 lpos = tpos.xy/tpos.z;
	vec2 lightPos = lpos*0.5+0.5;
	
	
	#ifdef GODRAYS
	
		const float exposure = 0.7;
		const float density = 0.8;			
		const int NUM_SAMPLES = 10;

		vec2 deltaTextCoord = vec2( texcoord.st - lightPos.xy );
		vec2 textCoord = texcoord.st;
		deltaTextCoord *= 1.0 /  float(NUM_SAMPLES) * density;
		float illuminationDecay = 1.0;
		float gr = 0.0;
		float distx = abs(texcoord.x*aspectRatio-lightPos.x*aspectRatio);
		float disty = abs(texcoord.y-lightPos.y);
		illuminationDecay = pow(max(1.0-sqrt(distx*distx+disty*disty),0.0),3.0);
		
		// fog distance.
		float fog_sunrise = 100.0 * TimeSunrise *  (1.0-rainStrength2*1.0);
		float fog_noon = 150.0 * TimeNoon * (1.0-rainStrength2*1.0);
	    float fog_sunset = 200.0 * TimeSunset * (1.0-rainStrength2*1.0);
		float fog_midnight = 75.0 * TimeMidnight * (1.0-rainStrength2*1.0);
	    float fog_rain = 75.0*rainStrength2;
	    float fog_distance = fog_sunrise + fog_noon + fog_sunset + fog_midnight + fog_rain;

		for(int i=0; i < NUM_SAMPLES ; i++) {
		
			textCoord -= deltaTextCoord;
				
			float sample = texture2D(gdepth, textCoord).r;
			gr += sample;

		}
	
		vec3 gr_color_sunrise = vec3(2.52, 0.5, 0.05) * TimeSunrise;
		vec3 gr_color_noon = vec3(2.52, 1.4, 0.7) * TimeNoon;
		vec3 gr_color_sunset = vec3(2.52, 0.4, 0.03) * TimeSunset;
		vec3 gr_color_night = vec3(0.2, 0.45, 1.3) * 0.5 * TimeMidnight * (1.0 - rainStrength2 * 1.0);
		
		vec3 gr_color = gr_color_sunrise + gr_color_noon + gr_color_sunset + gr_color_night;
			 gr_color.r = pow(gr_color.r, 1.0 - rainStrength2 * 0.5);
			 gr_color.g = pow(gr_color.g, 1.0 - rainStrength2 * 0.5);
			 gr_color.b = pow(gr_color.b, 1.0 - rainStrength2 * 0.5);
		
		// Fix, that moonrays are visible at daytime
		float truepos = 0.0f;
		
		if ((worldTime < 13000 || worldTime > 23000) && sunPosition.z < 0) truepos = 1.0 * (TimeSunrise + TimeNoon + TimeSunset); 
		if ((worldTime < 23000 || worldTime > 13000) && -sunPosition.z < 0) truepos = 1.0 * TimeMidnight; 
		
		#ifdef DYNAMIC_TONEMAPPING
		
			gr_color = gr_color * 0.7 / dynamicTonemapping(0.6, 1.0);
			
		#endif
		
		color.rgb = mix(color.rgb,pow(gr_color,vec3(1.0/4.0)),((gr/NUM_SAMPLES)*exposure*truepos*length(pow(gr_color,vec3(1.0/2.2)))*illuminationDecay/sqrt(3.0)*transition_fading));
		
	#endif
	
	float visiblesun = 0.0;
	float temp;
	int nb = 0;

				
	//calculate sun occlusion (only on one pixel) 
	if (texcoord.x < pw && texcoord.x < ph) {
		for (int i = 0; i < 10;i++) {
			for (int j = 0; j < 10 ;j++) {
			temp = texture2D(gaux1,lightPos + vec2(pw*(i-5.0)*10.0,ph*(j-5.0)*10.0)).g;
			visiblesun +=  1.0-float(temp > 0.04) ;
			nb += 1;
			}
		}
		visiblesun /= nb;

	}
	
	color = clamp(color,0.0,1.0);

	gl_FragData[0] = vec4(color.rgb,visiblesun);
	
}
