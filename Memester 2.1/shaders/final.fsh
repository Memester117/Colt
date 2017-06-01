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











/*
Chocapic13' shaders, derived from SonicEther v10 rc6
Place two leading Slashes in front of the following '#define' lines in order to disable an option.
*/

//disabling is done by adding "//" to the beginning of a line.

//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES

#define LENS_EFFECTS

//#define BLOOM								//do the "fog blur" in the same time					
	#define B_TRESH 0.4				
	#define B_RAD 20.0					//sampling circle size multiplier, don't affect performance
	#define B_INTENSITY 1.0		//basic multiplier

//#define DOF
	//#define TILT_SHIFT

//#define VINTAGE

//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES



varying vec4 texcoord;
varying vec3 sunlight;

uniform sampler2D depthtex2;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 sunPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform ivec2 eyeBrightness;
uniform int isEyeInWater;
uniform int worldTime;
uniform float aspectRatio;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float frameTimeCounter;
uniform int fogMode;
float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;
float timefract = worldTime;

vec3 sunPos = sunPosition;

//Raining
float rainStrength2 = clamp(wetness, 0.0f, 1.0f)/1.0f;

//Calculate Time of Day
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float A = 0.58;
float B = 0.23;
float C = 0.1;
float D = 0.2;
float E = 0.02;
float F = 0.3;
float W = 48.0;

vec3 Uncharted2Tonemap(vec3 x) {
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

#ifdef BLOOM

	const vec2 offsets[60] = vec2[60](vec2( 0.0000, 0.2500 ),
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

#endif


#ifdef DOF

	//hexagon pattern
	const vec2 hex_offsets[60] = vec2[60] (	vec2(  0.2165,  0.1250 ),
										vec2(  0.0000,  0.2500 ),
										vec2( -0.2165,  0.1250 ),
										vec2( -0.2165, -0.1250 ),
										vec2( -0.0000, -0.2500 ),
										vec2(  0.2165, -0.1250 ),
										vec2(  0.4330,  0.2500 ),
										vec2(  0.0000,  0.5000 ),
										vec2( -0.4330,  0.2500 ),
										vec2( -0.4330, -0.2500 ),
										vec2( -0.0000, -0.5000 ),
										vec2(  0.4330, -0.2500 ),
										vec2(  0.6495,  0.3750 ),
										vec2(  0.0000,  0.7500 ),
										vec2( -0.6495,  0.3750 ),
										vec2( -0.6495, -0.3750 ),
										vec2( -0.0000, -0.7500 ),
										vec2(  0.6495, -0.3750 ),
										vec2(  0.8660,  0.5000 ),
										vec2(  0.0000,  1.0000 ),
										vec2( -0.8660,  0.5000 ),
										vec2( -0.8660, -0.5000 ),
										vec2( -0.0000, -1.0000 ),
										vec2(  0.8660, -0.5000 ),
										vec2(  0.2163,  0.3754 ),
										vec2( -0.2170,  0.3750 ),
										vec2( -0.4333, -0.0004 ),
										vec2( -0.2163, -0.3754 ),
										vec2(  0.2170, -0.3750 ),
										vec2(  0.4333,  0.0004 ),
										vec2(  0.4328,  0.5004 ),
										vec2( -0.2170,  0.6250 ),
										vec2( -0.6498,  0.1246 ),
										vec2( -0.4328, -0.5004 ),
										vec2(  0.2170, -0.6250 ),
										vec2(  0.6498, -0.1246 ),
										vec2(  0.6493,  0.6254 ),
										vec2( -0.2170,  0.8750 ),
										vec2( -0.8663,  0.2496 ),
										vec2( -0.6493, -0.6254 ),
										vec2(  0.2170, -0.8750 ),
										vec2(  0.8663, -0.2496 ),
										vec2(  0.2160,  0.6259 ),
										vec2( -0.4340,  0.5000 ),
										vec2( -0.6500, -0.1259 ),
										vec2( -0.2160, -0.6259 ),
										vec2(  0.4340, -0.5000 ),
										vec2(  0.6500,  0.1259 ),
										vec2(  0.4325,  0.7509 ),
										vec2( -0.4340,  0.7500 ),
										vec2( -0.8665, -0.0009 ),
										vec2( -0.4325, -0.7509 ),
										vec2(  0.4340, -0.7500 ),
										vec2(  0.8665,  0.0009 ),
										vec2(  0.2158,  0.8763 ),
										vec2( -0.6510,  0.6250 ),
										vec2( -0.8668, -0.2513 ),
										vec2( -0.2158, -0.8763 ),
										vec2(  0.6510, -0.6250 ),
										vec2(  0.8668,  0.2513 ));

#endif

#ifdef TILT_SHIFT

	// lens properties with tilt shift
	const float focal = 0.3;
	float aperture = 0.3;	
	const float sizemult = 1.0;
	
#else 

	// normal lens properties
	const float focal = 0.024;
	float aperture = 0.009;	
	const float sizemult = 100.0;

#endif

#ifdef LENS_EFFECTS

	float distratio(vec2 pos, vec2 pos2, float ratio) {
		float xvect = pos.x*ratio-pos2.x*ratio;
		float yvect = pos.y-pos2.y;
		return sqrt(xvect*xvect + yvect*yvect);
	}
	
	float PI = 3.14159265358979323846264;
	float angle = 90.0;
	float rad_angle = angle*PI/180.0;

	//circle position pattern (vec2 coordinate, size)
	const vec3 pattern[16] = vec3[16](	vec3(0.1,0.1,0.02),
										vec3(-0.12,0.07,0.02),
										vec3(-0.11,-0.13,0.02),
										vec3(0.1,-0.1,0.02),
									
										vec3(0.07,0.15,0.02),
										vec3(-0.08,0.17,0.02),
										vec3(-0.14,-0.07,0.02),
										vec3(0.15,-0.19,0.02),
									
										vec3(0.012,0.15,0.02),
										vec3(-0.08,0.17,0.02),
										vec3(-0.14,-0.07,0.02),
										vec3(0.02,-0.17,0.021),
									
										vec3(0.10,0.05,0.02),
										vec3(-0.13,0.09,0.02),
										vec3(-0.05,-0.1,0.02),
										vec3(0.1,0.01,0.02)
									);	
									
	float gen_circular_lens(vec2 center, float size) {
		return 1.0-pow(min(distratio(texcoord.xy,center,aspectRatio),size)/size,10.0);
	}

	vec2 noisepattern(vec2 pos) {
		return vec2(abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f)),abs(fract(sin(dot(pos.yx ,vec2(18.9898f,28.633f))) * 4378.5453f)));
	} 
	
	float yDistAxis (in float degrees) {
	
		vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
			 tpos = vec4(tpos.xyz/tpos.w,1.0);
		vec2 lightPos = tpos.xy/tpos.z;
			 lightPos = (lightPos + 1.0f)/2.0f;
			 
		return abs((lightPos.y-lightPos.x*(degrees))-(texcoord.y-texcoord.x*(degrees)));
		
	}
	
	float ratioDist (in float lensDist) {

		vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
			 tpos = vec4(tpos.xyz/tpos.w,1.0);
		vec2 lightPos = tpos.xy/tpos.z*lensDist;
			 lightPos = (lightPos + 1.0f)/2.0f;
			 
		return distratio(lightPos.xy,texcoord.xy,aspectRatio);
		
	}

#endif

void main() {

	vec2 fake_refract = vec2(sin(frameTimeCounter*1.7 + texcoord.x*50.0 + texcoord.y*25.0),cos(frameTimeCounter*2.5 + texcoord.y*100.0 + texcoord.x*25.0)) * isEyeInWater;
	vec3 color = texture2D(gaux2, texcoord.st + fake_refract * 0.003).rgb;


#ifdef DOF
	
	// Calculate pixel Circle of Confusion that will be used for bokeh depth of field
	float z = ld(texture2D(depthtex2, texcoord.st).r)*far;
	float focus = ld(texture2D(depthtex2, vec2(0.5)).r)*far;
	float pcoc = min(abs(aperture * (focal * (z - focus)) / (z * (focus - focal)))*sizemult,pw*10.0);
	
	pcoc *= 0.5;
	
	vec4 sample = vec4(0.0);
	vec3 bcolor = vec3(0.0);
	float nb = 0.0;
	vec2 bcoord = vec2(0.0);

	for ( int i = 0; i < 60; i++) {
		if (isEyeInWater > 0.9) {
			sample = texture2D(gaux2, texcoord.xy + hex_offsets[i]*0.01*vec2(1.0,aspectRatio) + fake_refract * 0.007);
			bcolor += sample.rgb;
		} else {
			sample = texture2D(gaux2, texcoord.xy + hex_offsets[i]*pcoc*vec2(1.0,aspectRatio) + fake_refract * 0.007);
			bcolor += sample.rgb;
		}
	}
	
	color.rgb = bcolor/60.0;
	
#endif
	
	float plum = luma(color.rgb);

#ifdef BLOOM
		
const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

	vec3 blur = vec3(0.0);
	float fog = 0.0;
	if (fogMode == 0) fog = 1.0-clamp(exp(-ld(texture2D(depthtex2, texcoord.st).r)),0.0,1.0);

	float scale = length(vec2(pw,ph));
	vec3 csample = vec3(0.0);
	
	for (int i=0; i < 60; i++) {
		vec2 coords = offsets[i];
		vec3 sample = texture2D(gaux2,texcoord.xy + coords*B_RAD*scale).rgb;
		csample += max(texture2D(gaux2,texcoord.xy + coords*B_RAD*scale).rgb-plum*0.75-B_TRESH,0.0) * (length(coords)+0.6)/2.0;
		blur += sample;
	}
	
	color += csample/60.0*1.3;
	
#endif

#ifdef LENS_EFFECTS

	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
		tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 lightPos = tpos.xy/tpos.z;
		lightPos = (lightPos + 1.0f)/2.0f;

    float distof = min(min(1.0-lightPos.x,lightPos.x),min(1.0-lightPos.y,lightPos.y));
    float fading = clamp(1.0-step(distof,0.1)+pow(distof*10.0,5.0),0.0,1.0);

    float time = float(worldTime);
	float transition_fading = 1.0-(clamp((time-12000.0)/500.0,0.0,1.0)-clamp((time-13000.0)/500.0,0.0,1.0) + clamp((time-22500.0)/100.0,0.0,1.0)-clamp((time-23300.0)/200.0,0.0,1.0));

    float sunvisibility = min(texture2D(gaux2,vec2(0.0)).a*2.5,1.0) * fading * transition_fading;
	
    float dirtylens = 0.0;

    vec2 pos1 = noisepattern(vec2(0.6,-0.12));
    dirtylens += gen_circular_lens(pos1,0.05)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.3,-0.4));
    dirtylens += gen_circular_lens(pos1,0.015)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.8,-0.4));
    dirtylens += gen_circular_lens(pos1,0.02)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.9,-0.2));
    dirtylens += gen_circular_lens(pos1,0.03)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.9,-0.6));
    dirtylens += gen_circular_lens(pos1,0.04)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.2,-0.8));
    dirtylens += gen_circular_lens(pos1,0.04)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.5,-0.9));
    dirtylens += gen_circular_lens(pos1,0.05)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.5,-0.95));
    dirtylens += gen_circular_lens(pos1,0.02)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.6,-0.95));
    dirtylens += gen_circular_lens(pos1,0.02)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.7,-0.1));
    dirtylens += gen_circular_lens(pos1,0.035)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.9,-0.1));
    dirtylens += gen_circular_lens(pos1,0.02)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.2,-0.2));
    dirtylens += gen_circular_lens(pos1,0.037)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.4,-0.2));
    dirtylens += gen_circular_lens(pos1,0.02)*sunvisibility;
	
    pos1 = noisepattern(vec2(-0.95,-0.8));
    dirtylens += gen_circular_lens(pos1,0.03)*sunvisibility;
	
    pos1 = noisepattern(vec2(-0.99,-0.8));
    dirtylens += gen_circular_lens(pos1,0.04)*sunvisibility;
	
    pos1 = noisepattern(vec2(-0.99,0.99));
    dirtylens += gen_circular_lens(pos1,0.03)*sunvisibility;
	
    pos1 = noisepattern(vec2(-0.2,0.9));
    dirtylens += gen_circular_lens(pos1,0.043)*sunvisibility;
	
    pos1 = noisepattern(vec2(-0.4,0.99));
    dirtylens += gen_circular_lens(pos1,0.02)*sunvisibility;
	
    pos1 = noisepattern(vec2(-0.69,0.999));
    dirtylens += gen_circular_lens(pos1,0.02)*sunvisibility;
	
    pos1 = noisepattern(vec2(-0.69,0.99));
    dirtylens += gen_circular_lens(pos1,0.025)*sunvisibility;
	
    pos1 = noisepattern(vec2(-0.9,0.3));
    dirtylens += gen_circular_lens(pos1,0.03)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.9,0.3));
    dirtylens += gen_circular_lens(pos1,0.04)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.1,0.1));
    dirtylens += gen_circular_lens(pos1,0.05)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.1,0.15));
    dirtylens += gen_circular_lens(pos1,0.035)*sunvisibility;
	
    pos1 = noisepattern(vec2(0.15,0.13));
    dirtylens += gen_circular_lens(pos1,0.025)*sunvisibility;
	
	// Fix, that the particles are visible on the moon position at daytime
	float truepos = 0.0f;
	
	if ((worldTime < 13000 || worldTime > 23000) && sunPos.z < 0) truepos = 1.0 * (TimeSunrise + TimeNoon + TimeSunrise); 
	if ((worldTime < 23000 || worldTime > 13000) && -sunPos.z < 0) truepos = 1.0 * TimeMidnight; 
	
	if (sunvisibility > 0.1) {
		float visibility = max(pow(max(1.0 - ratioDist(1.0)/1.0,0.1),2.0)-0.1,0.0);
	    color += (dirtylens*visibility*truepos)*0.2*(TimeSunrise + TimeNoon + TimeSunset)*(1.0-rainStrength2*1.0) * (eyeBrightness.y/255.0);
		color += (dirtylens*visibility*truepos)*vec3(0.25, 0.5, 0.7)*0.1*TimeMidnight*(1.0-rainStrength2*1.0) * (eyeBrightness.y/255.0);
	}

	if ((worldTime < 13000 || worldTime > 23000) && sunPos.z < 0 && isEyeInWater < 0.9) {
	
		float dist = distance(texcoord.st, vec2(0.5, 0.5));

		if (sunvisibility > 0.1) {
			float ratiolens = max(pow(max(1.0 - ratioDist(1.0)/1.0,0.1),2.0)-0.1,0.0);
			color += ratiolens*0.2*sunvisibility * (1.0-rainStrength2*1.0) * (eyeBrightness.y/255.0);
		}
		
		// Sunrays
		if (sunvisibility > 0.1) {
		
			float visibility = max(pow(max(1.0 - ratioDist(1.0)/1.0,0.1),5.0)-0.1,0.0);
		
			vec3 lenscolor = vec3(2.55, 2.55, 2.55) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 0.5 * (eyeBrightness.y/255.0);
			lenscolor *= lens_strength;
			
			float sunray1 = max(pow(max(1.0 - yDistAxis(1.5)/1.0,0.1),10.0)-0.6,0.0);
			float sunray2 = max(pow(max(1.0 - yDistAxis(-1.5)/1.0,0.1),10.0)-0.6,0.0);
			float sunray3 = max(pow(max(1.0 - yDistAxis(5.0)/1.0,0.1),10.0)-0.6,0.0);
			float sunray4 = max(pow(max(1.0 - yDistAxis(-5.0)/1.0,0.1),10.0)-0.6,0.0);
			
			float sunrays = sunray1 + sunray2 + sunray3 + sunray4;
			
			color += lenscolor * sunrays * visibility * sunvisibility * (1.0-rainStrength2*1.0);
		}

		// Anamorphic Lens
		if (sunvisibility > 0.1) {
		
			float visibility = max(pow(max(1.0 - ratioDist(1.0)/1.5,0.1),1.0)-0.1,0.0);
		
			vec3 lenscolor = vec3(2.55, 1.5, 0.3) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 0.6 * (eyeBrightness.y/255.0);
			lenscolor *= lens_strength;
			
			float anamorphic_lens = max(pow(max(1.0 - yDistAxis(0.0)/1.0,0.1),10.0)-0.6,0.0);
			color += lenscolor * anamorphic_lens * visibility * sunvisibility * (1.0-rainStrength2*1.0);
		}
		
		// Circle Lens
		if (sunvisibility > 0.1) {
		
			vec3 lenscolor = vec3(2.55, 1.0, 0.0) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 0.2 * (eyeBrightness.y/255.0);
			lenscolor *= lens_strength;
			
			float circle_lens = max(pow(max(1.0 - ratioDist(0.1)/1.0,0.1),5.0)-0.2,0.0);
			
			color += lenscolor * circle_lens * sunvisibility * (1.0-rainStrength2*1.0);
		}
		
		if (sunvisibility > 0.1) {
		
			vec3 lenscolor = vec3(1.0, 2.55, 0.3) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 0.8 * (eyeBrightness.y/255.0);
			lenscolor *= lens_strength;
			
			float circle_lens = max(pow(max(1.0 - ratioDist(-0.1)/1.0,0.1),5.0)-0.9,0.0);
			
			color += lenscolor * circle_lens * sunvisibility * (1.0-rainStrength2*1.0);
		}
		
		if (sunvisibility > 0.1) {
		
			vec3 lenscolor = vec3(2.55, 1.0, 0.0) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 1.0 * (eyeBrightness.y/255.0);
			lenscolor *= lens_strength;
			
			float circle_lens = max(pow(max(1.0 - ratioDist(-0.2)/1.0,0.1),10.0)-0.9,0.0);
			
			color += lenscolor * circle_lens * sunvisibility * (1.0-rainStrength2*1.0);
		}
		
		if (sunvisibility > 0.1) {
		
			vec3 lenscolor = vec3(2.55, 1.5, 0.0) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 1.5 * (eyeBrightness.y/255.0);
			lenscolor *= lens_strength;
			
			float circle_lens = max(pow(max(1.0 - ratioDist(-0.4)/1.0,0.1),5.0)-0.9,0.0);
			
			color += lenscolor * circle_lens * sunvisibility * (1.0-rainStrength2*1.0);
		}
		
		if (sunvisibility > 0.1) {
		
			vec3 lenscolor = vec3(2.55, 1.0, 0.0) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 0.1 * (eyeBrightness.y/255.0);
			lenscolor *= lens_strength;
			
			float circle_lens = max(pow(max(1.0 - ratioDist(-0.4)/1.0,0.1),5.0)-0.5,0.0);
			
			color += lenscolor * circle_lens * sunvisibility * (1.0-rainStrength2*1.0);
		}
		
		if (sunvisibility > 0.1) {
		
			vec3 lenscolor = vec3(1.0, 2.55, 0.5) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 0.2 * (eyeBrightness.y/255.0);
			lenscolor *= lens_strength;
			
			float circle_lens = max(pow(max(1.0 - ratioDist(-0.9)/1.0,0.1),10.0)-0.7,0.0);
			
			color += lenscolor * circle_lens * sunvisibility * (1.0-rainStrength2*1.0);
		}
		
	}
	
//rain drops on screen

	if (rainStrength > 0.01) {
		const float pi = 3.14159265359;
		float lightmap = pow(eyeBrightness.y/255.0, 6.0f);
		float fake_refract = 1.0-sin(worldTime/5.14159265359 + texcoord.x*30.0 + texcoord.y*30.0);
		float fake_refract2 = sin(worldTime/7.14159265359 + texcoord.x*20.0 + texcoord.y*20.0) * pow(eyeBrightness.y/255.0, 6.0f) * (1.0-TimeMidnight*0.7);
		vec3 watercolor = texture2D(gaux1, texcoord.st + fake_refract * 0.015 * lightmap).rgb;
		float raindrops = 0.0;
		float time2 = frameTimeCounter;

		float gen = cos(time2*pi)*0.5+0.5;
		vec2 pos = noisepattern(vec2(0.9347*floor(time2*0.5+0.5),-0.2533282*floor(time2*0.5+0.5)));
		raindrops += gen_circular_lens(pos,0.033)*gen*rainStrength;

		gen = cos(time2*pi)*0.5+0.5;
		pos = noisepattern(vec2(0.785282*floor(time2*0.5+0.5),-0.285282*floor(time2*0.5+0.5)));
		raindrops += gen_circular_lens(pos,0.033)*gen*rainStrength;

		gen = sin(time2*pi)*0.5+0.5;
		pos = noisepattern(vec2(-0.347*floor(time2*0.5+0.5),0.6847*floor(time2*0.5+0.5)));
		raindrops += gen_circular_lens(pos,0.033)*gen*rainStrength;

		gen = cos(time2*pi)*0.5+0.5;
		pos = noisepattern(vec2(0.3347*floor(time2*0.5+0.5),-0.2533282*floor(time2*0.5+0.5)));
		raindrops += gen_circular_lens(pos,0.033)*gen*rainStrength;

		gen = cos(time2*pi)*0.5+0.5;
		pos = noisepattern(vec2(0.385282*floor(time2*0.5+0.5),-0.285282*floor(time2*0.5+0.5)));
		raindrops += gen_circular_lens(pos,0.033)*gen*rainStrength;
		 
		if (isEyeInWater < 0.9) {
			color += abs(fake_refract2)/25*raindrops;
		}
	}
#endif

	color = clamp(color,0.0,1.0);

	float white = luma(color);
	color = color*(1.0+pow(white,0.3))/(2.0-0.3);

	color = pow(color,vec3(2.2));

	//Tonemapping
	float avglight = texture2D(gaux2,vec2(1.0)).a;
	
	vec3 curr = Uncharted2Tonemap(color);

	vec3 whiteScale = 1.0f/Uncharted2Tonemap(vec3(W));
	color = curr*whiteScale;


    float dist = distance(texcoord.st, vec2(0.5, 0.5));
    dist = 0.75 - dist;
	
    color.r = color.r * dist;
    color.g = color.g * dist;
    color.b = color.b * dist;
	
	#ifdef VINTAGE
	
		color.r = pow(color.r, 0.6);
		color.g = pow(color.g, 0.6);
		color.b = pow(color.b, 0.6);
		
	#else 
	
		color.r = pow(color.r, 0.7);
		color.g = pow(color.g, 0.7);
		color.b = pow(color.b, 0.7);
		
	#endif
	
    vec3 Gray = vec3(0.0, 0.3, 0.3);
    vec3 ColorScale = vec3(1.0, 1.0, 1.0);
    float Saturation = 1.3;

    // Color Matrix
    vec3 OutColor = color.rgb;
    
    // Offset & Scale
    OutColor = (OutColor * ColorScale);
    
    // Saturation
    float Luma = dot(OutColor, Gray);
    vec3 Chroma = OutColor - Luma;
    OutColor = (Chroma * Saturation) + Luma;
    
    color = OutColor;
	
	color *= 1.7;
	
#ifdef VINTAGE

	vec3 vintage_color = vec3(1.08, 1.19, 1.0);
	vec3 second_color = vec3(0.0, 0.02, 0.05);
	
	color.rgb = color.rgb * vintage_color + second_color;

#endif

color = pow(color,vec3(1.0/2.2));


	
	gl_FragColor = vec4(color,1.0);
	
}
