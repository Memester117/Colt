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

	//#define LENS_EFFECTS

	#define BLOOM	
	
	#define DYNAMIC_TONEMAPPING

	#define DOF
		//#define TILT_SHIFT

	//#define SHAKING_CAMERA
	
	//#define ANTI_ALIASING				   // Only antialias the outlines of the entities. Not the texture of them. - Not compatible with DOF.











//////////////////////////////////////////////////////////////
//////////////////////// GET MATERIAL ////////////////////////
//////////////////////////////////////////////////////////////

const bool gaux2MipmapEnabled = true;

varying vec4 texcoord;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D gdepthtex;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux4;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 sunPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
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
uniform float centerDepthSmooth;
uniform int fogMode;
float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;
float timefract = worldTime;

vec3 sunPos = sunPosition;

// Raining
float rainStrength2 = clamp(wetness, 0.0f, 1.0f)/1.0f;

vec3 aux = texture2D(gaux1, texcoord.st).rgb;
float sky_lightmap = pow(aux.r,5.0);

// Calculate Time of Day
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float edepth(vec2 coord) {
	return texture2D(depthtex0, coord).z;
}

// Tonemapping constants			
float A = 1.0;		//brightness multiplier
float B = 0.37;		//black level (lower means darker and more constrasted, higher make the image whiter and less constrasted)
float C = 0.1;		//constrast level 

vec3 Uncharted2Tonemap(vec3 x) {
	float D = 0.2;		
	float E = 0.02;
	float F = 0.3;
	float W = 48.0;
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

	//hexagon pattern
	const vec2 hex_offsets[60] = vec2[60] (vec2(  0.2165,  0.1250 ),
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
										
										
		const vec2 offsets[25] = vec2[25](vec2(-0.4894566f,-0.3586783f),
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
	
	float smoothCircleDist (in float lensDist) {

		vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
			 tpos = vec4(tpos.xyz/tpos.w,1.0);
		vec2 lightPos = tpos.xy/tpos.z*lensDist;
			 lightPos = (lightPos + 1.0f)/2.0f;
			 
		return distratio(lightPos.xy, texcoord.xy, aspectRatio);
		
	}
	
	float cirlceDist (float lensDist, float size) {
	
		vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
			 tpos = vec4(tpos.xyz/tpos.w,1.0);
		vec2 lightPos = tpos.xy/tpos.z*lensDist;
			 lightPos = (lightPos + 1.0f)/2.0f;
			 
		return pow(min(distratio(lightPos.xy, texcoord.xy, aspectRatio),size)/size,10.0);
	}
	
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
    	f += 0.50000*noise( p ); p = p*2.02;
    	f += 0.25000*noise( p ); p = p*2.03;
    	f += 0.12500*noise( p ); p = p*2.01;
    	f += 0.06250*noise( p ); p = p*2.04;
    	f += 0.03125*noise( p );
		
    	return f/0.984375;
	}
	
	float fbmRain( vec2 p ) {
    	float f = 0.0;
    	f += 0.50000*noise( p + frameTimeCounter * 0.5); p = p*2.02;
    	f += 0.25000*noise( p + frameTimeCounter * 0.6); p = p*2.03;
    	f += 0.12500*noise( p + frameTimeCounter * 0.7); p = p*2.01;
    	f += 0.06250*noise( p + frameTimeCounter * 0.8); p = p*2.04;
    	f += 0.03125*noise( p + frameTimeCounter * 0.9);
		
    	return f/0.984375;
	}
	
#endif

#ifdef SHAKING_CAMERA

	vec2 shaking_camera = vec2(0.0015 * sin(frameTimeCounter * 2.0), 0.0015 * cos(frameTimeCounter * 3.0));

#else

	vec2 shaking_camera = vec2(0.0, 0.0);

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

	vec2 fake_refract = vec2(sin(frameTimeCounter*1.7 + texcoord.x*50.0 + texcoord.y*25.0),cos(frameTimeCounter*2.5 + texcoord.y*100.0 + texcoord.x*25.0)) * isEyeInWater;
	
	#ifdef ANTI_ALIASING
	
		bool antialiasAll = false;
	
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
		
		float e = 1.0 - clamp(dot(dd,vec4(0.5f,0.5f,0.5f,0.5f)),0.0,1.0);
		
		float depth_diff = clamp(1.0-pow(ld(texture2D(depthtex0, texcoord.st).r)*5.0,2.0),0.0,1.0);
	
		float AAsample = 0.0;
		
		if (antialiasAll) {
			AAsample = 1.0 + (depth_diff);
		}
		
		float AAsampleE = e + (depth_diff * e);
		float sampleOffset = AAsample * 0.0002 + AAsampleE * 0.0003;
		
	
		vec3 colorSample = vec3(0.0);
		
			 colorSample += texture2D(gaux2, texcoord.st + shaking_camera + fake_refract * 0.005).rgb;
			 colorSample += texture2D(gaux2, texcoord.st + vec2(sampleOffset, 0.0) + shaking_camera + fake_refract * 0.005).rgb;
			 colorSample += texture2D(gaux2, texcoord.st + vec2(0.0, sampleOffset) + shaking_camera + fake_refract * 0.005).rgb;
			 colorSample += texture2D(gaux2, texcoord.st + vec2(sampleOffset, sampleOffset) + shaking_camera + fake_refract * 0.005).rgb;
			 colorSample += texture2D(gaux2, texcoord.st + vec2(-sampleOffset, 0.0) + shaking_camera + fake_refract * 0.005).rgb;
			 colorSample += texture2D(gaux2, texcoord.st + vec2(0.0, -sampleOffset) + shaking_camera + fake_refract * 0.005).rgb;
			 colorSample += texture2D(gaux2, texcoord.st + vec2(-sampleOffset, -sampleOffset) + shaking_camera + fake_refract * 0.005).rgb;
			 
		vec3 color = colorSample / 7.0;
		
	#else
	
		vec3 color = texture2D(gaux2, texcoord.st + shaking_camera + fake_refract * 0.005).rgb;
	
	#endif

#ifdef DOF
	
	// Calculate pixel Circle of Confusion that will be used for bokeh depth of field
	float z = ld(texture2D(gdepthtex, texcoord.st + shaking_camera).r) * far;
	float focus = ld(texture2D(gdepthtex, vec2(0.5)).r) * far;
	float pcoc = min(abs(aperture * (focal * (z - focus)) / (z * (focus - focal))) * sizemult,pw * 10.0);
	
	#ifdef TILT_SHIFT
		pcoc *= 0.5;
	#else
		pcoc *= 1.0;
	#endif
	
	vec4 sample = vec4(0.0);
	vec3 bcolor = vec3(0.0);
	
	vec4 fringe_sample = vec4(0.0);
	vec3 fringecolor = vec3(0.0);
	
	float depth_diff2 = exp(-pow(length(fragpos)/10.0, 3.0));

	for ( int i = 0; i < 60; i++) {
		if (isEyeInWater > 0.9) {
			sample = texture2D(gaux2, texcoord.xy + shaking_camera + hex_offsets[i]*0.01*vec2(1.0,aspectRatio) + fake_refract * 0.005);
			bcolor += sample.rgb;
		} else {
			sample			 = texture2D(gaux2, texcoord.xy + shaking_camera + hex_offsets[i] * 0.4 * pcoc * vec2(1.0,aspectRatio));
			bcolor		 	+= sample.rgb;
		}
	}
	
	color.rgb 	= bcolor / 60.0;
	
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

    float sunvisibility = min(texture2D(gaux2, vec2(0.0)).a, 1.0) * fading * transition_fading;
	float sunvisibility2 = min(texture2D(gaux2, vec2(0.0)).a, 1.0) * transition_fading;
	float centerVisibility = 1.0 - clamp(distance(lightPos.xy, vec2(0.5, 0.5)) * 2.0, 0.0, 1.0);
		  centerVisibility *= sunvisibility;
	
	float lensBrightness = 1.0;
	
	// Fix, that the particles are visible on the moon position at daytime
	float truepos = 0.0f;
	
	if ((worldTime < 13000 || worldTime > 23000) && sunPos.z < 0) truepos = 1.0 * (TimeSunrise + TimeNoon + TimeSunset); 
	if ((worldTime < 23000 || worldTime > 13000) && -sunPos.z < 0) truepos = 1.0 * TimeMidnight; 

	// Dirty Lens
	
		// Set up domain
		vec2 q = texcoord.xy + texcoord.x * 0.4;
		vec2 p = -1.0 + 3.0 * q;
		vec2 p2 = -1.0 + 3.0 * q + vec2(10.0, 10.0);
		
		// Create noise using fBm
		float f = fbm(5.0 * p);
		float f2 = fbm(10.0 * p2);
	 
		float cover = 0.35f;
		float sharpness = 0.99 * sunvisibility2;	// Brightness
		
		float c = f - (1.0 - cover);
		if ( c < 0.0 )
			 c = 0.0;
		
		f = 1.0 - (pow(1.0 - sharpness, c));
				
				
		float c2 = f2 - (1.0 - cover);
		if ( c2 < 0.0 )
			 c2 = 0.0;
		
		f2 = 1.0 - (pow(1.0 - sharpness, c2));
				
		float dirtylens = (f * 2.0) + (f2 / 1);

	
		float visibility = max(pow(max(1.0 - smoothCircleDist(1.0)/0.7,0.1),2.0)-0.1,0.0);
			
		vec3 dirtcolorSunrise = vec3(2.52, 1.2, 0.4) * TimeSunrise;
		vec3 dirtcolorNoon = vec3(2.52, 2.25, 2.0) * 0.5 * TimeNoon;
		vec3 dirtcolorSunset = vec3(2.52, 1.2, 0.4) * TimeSunset;
		vec3 dirtcolorNight = vec3(0.6, 0.8, 1.3) * 0.2 * TimeMidnight;
				
		vec3 dirtcolor = dirtcolorSunrise + dirtcolorNoon + dirtcolorSunset + dirtcolorNight;
			
		float lens_strength = 1.3 * lensBrightness;
		dirtcolor *= lens_strength;
				
		color += (dirtylens*visibility*truepos)*dirtcolor*(1.0-rainStrength*1.0);

	// End of Dirty Lens
	
	// Anamorphic Lens
	if (sunvisibility > 0.01) {
		
		float visibility = max(pow(max(1.0 - smoothCircleDist(1.0)/1.5,0.1),1.0)-0.1,0.0);
		
		vec3 lenscolorSunrise = vec3(0.3, 1.3, 2.55) * TimeSunrise;
		vec3 lenscolorNoon = vec3(0.3, 1.3, 2.55) * TimeNoon;
		vec3 lenscolorSunset = vec3(0.3, 1.3, 2.55) * TimeSunset;
		vec3 lenscolorNight = vec3(0.6, 0.8, 1.3) * 0.3 * TimeMidnight;
			
		vec3 lenscolor = lenscolorSunrise + lenscolorNoon + lenscolorSunset + lenscolorNight;

		float lens_strength = 0.6 * lensBrightness;
		lenscolor *= lens_strength;
			
		float anamorphic_lens = max(pow(max(1.0 - yDistAxis(0.0)/1.0,0.1),10.0)-0.5,0.0);
		color += anamorphic_lens * lenscolor * visibility * truepos * sunvisibility * (1.0-rainStrength*1.0);
		
	}
	
	if ((worldTime < 13000 || worldTime > 23000) && sunPos.z < 0 && isEyeInWater < 0.9) {
	
		float dist = distance(texcoord.st, vec2(0.5, 0.5));

		// Sunrays
		if (sunvisibility > 0.01) {
		
			float visibility = max(pow(max(1.0 - smoothCircleDist(1.0)/1.0,0.1),5.0)-0.1,0.0);
			float sun = max(pow(max(1.0 - smoothCircleDist(1.0)/0.5,0.1),5.0)-0.1,0.0);
		
			vec3 lenscolorSunrise = vec3(2.52, 1.6, 0.7) * TimeSunrise;
			vec3 lenscolorNoon = vec3(2.52, 2.0, 1.5) * TimeNoon;
			vec3 lenscolorSunset = vec3(2.52, 1.6, 0.7) * TimeSunset;
			
			vec3 lenscolor = lenscolorSunrise + lenscolorNoon + lenscolorSunset;
			
			float lens_strength = clamp(0.8 * lensBrightness - sun, 0.0, 1.0);
			lenscolor *= lens_strength;
			
			float sunray1 = max(pow(max(1.0 - yDistAxis(1.5)/0.7,0.1),10.0)-0.6,0.0);
			float sunray2 = max(pow(max(1.0 - yDistAxis(-1.3)/0.7,0.1),10.0)-0.6,0.0);
			float sunray3 = max(pow(max(1.0 - yDistAxis(5.0)/1.5,0.1),10.0)-0.6,0.0);
			float sunray4 = max(pow(max(1.0 - yDistAxis(-4.8)/1.5,0.1),10.0)-0.6,0.0);
			
			float sunrays = min(sunray1 + sunray2 + sunray3 + sunray4, 1.0);
			
			color += lenscolor * sunrays * visibility * sunvisibility * (1.0-rainStrength*1.0);
		}
		
		
		// Circle Lens 1
		if (sunvisibility > 0.01) {
		
			vec3 lenscolor = vec3(1.2, 2.55, 0.4) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 0.2 * lensBrightness;
			lenscolor *= lens_strength;
			
			float lensFlare1 = max(pow(max(1.0 - cirlceDist(-0.15, 0.07)/1.0,0.1),5.0)-0.1,0.0);
			float lensFlare2 = max(pow(max(1.0 - cirlceDist(-0.2, 0.07)/1.0,0.1),5.0)-0.1,0.0);
			float lensFlare3 = max(pow(max(1.0 - cirlceDist(-0.25, 0.07)/1.0,0.1),5.0)-0.1,0.0);
			
			float lensFlare = clamp(lensFlare1 * lensFlare2 * lensFlare3, 0.0, 1.0);
			
			color += lensFlare * lenscolor * sunvisibility * (1.0-rainStrength*1.0);
		}
		
		// Circle Lens 2
		if (sunvisibility > 0.01) {
		
			vec3 lenscolor = vec3(2.52, 1.6, 0.4) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 0.2 * lensBrightness;
			lenscolor *= lens_strength;
			
			float lensFlare1 = max(pow(max(1.0 - cirlceDist(-0.4, 0.13)/1.0,0.1),5.0)-0.1,0.0);
			float lensFlare2 = max(pow(max(1.0 - cirlceDist(-0.5, 0.13)/1.0,0.1),5.0)-0.1,0.0);
			float lensFlare3 = max(pow(max(1.0 - cirlceDist(-0.6, 0.13)/1.0,0.1),5.0)-0.1,0.0);
			
			float lensFlare = clamp(lensFlare1 * lensFlare2 * lensFlare3, 0.0, 1.0);
			
			color += lensFlare * lenscolor * sunvisibility * (1.0-rainStrength*1.0);
		}
		
		// Circle Lens 3
		if (sunvisibility > 0.01) {
		
			vec3 lenscolor = vec3(0.0, 1.55, 2.52) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 0.2 * lensBrightness;
			lenscolor *= lens_strength;
			
			float lensFlare1 = max(pow(max(1.0 - cirlceDist(-0.75, 0.09)/1.0,0.1),5.0)-0.1,0.0);
			float lensFlare2 = max(pow(max(1.0 - cirlceDist(-0.8, 0.09)/1.0,0.1),5.0)-0.1,0.0);
			float lensFlare3 = max(pow(max(1.0 - cirlceDist(-0.85, 0.09)/1.0,0.1),5.0)-0.1,0.0);
			
			float lensFlare = clamp(lensFlare1 * lensFlare2 * lensFlare3, 0.0, 1.0);
			
			color += lensFlare * lenscolor * sunvisibility * (1.0-rainStrength*1.0);
		}
		
		// Small point 1
		if (sunvisibility > 0.01) {
		
			vec3 lenscolor = vec3(2.55, 2.55, 0.0) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 150.0 * lensBrightness;
			lenscolor *= lens_strength;
			
			float lensFlare1 = max(pow(max(1.0 - smoothCircleDist(-0.27)/1.0,0.1),5.0)-0.85,0.0);
			float lensFlare2 = max(pow(max(1.0 - smoothCircleDist(-0.3)/1.0,0.1),5.0)-0.85,0.0);
			float lensFlare3 = max(pow(max(1.0 - smoothCircleDist(-0.33)/1.0,0.1),5.0)-0.85,0.0);
			
			float lensFlare = clamp(lensFlare1 * lensFlare2 * lensFlare3, 0.0, 1.0);
			
			color += lensFlare * lenscolor * sunvisibility * (1.0-rainStrength*1.0);
		}
		
		// Small point 2
		if (sunvisibility > 0.01) {
		
			vec3 lenscolor = vec3(0.0, 1.55, 2.52) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 150.0 * lensBrightness;
			lenscolor *= lens_strength;
			
			float lensFlare1 = max(pow(max(1.0 - smoothCircleDist(-0.82)/1.0,0.1),5.0)-0.85,0.0);
			float lensFlare2 = max(pow(max(1.0 - smoothCircleDist(-0.85)/1.0,0.1),5.0)-0.85,0.0);
			float lensFlare3 = max(pow(max(1.0 - smoothCircleDist(-0.88)/1.0,0.1),5.0)-0.85,0.0);
			
			float lensFlare = clamp(lensFlare1 * lensFlare2 * lensFlare3, 0.0, 1.0);
			
			color += lensFlare * lenscolor * sunvisibility * (1.0-rainStrength*1.0);
		}
		
		// Ring Lens 
		if (sunvisibility > 0.01) {
		
			vec3 lenscolor = vec3(0.3, 1.3, 2.55) * (TimeSunrise + TimeNoon + TimeSunset);
			
			float lens_strength = 0.3 * lensBrightness;
			lenscolor *= lens_strength;
			
			float lensFlare1 = max(pow(max(1.0 - cirlceDist(-0.7, 0.5)/1.0,0.1),5.0)-0.1,0.0);
			float lensFlare2 = max(pow(max(1.0 - cirlceDist(-0.9, 0.5)/1.0,0.1),5.0)-0.1,0.0);
			
			float lensFlare = clamp(lensFlare2 - lensFlare1, 0.0, 1.0);
			color += lensFlare * lenscolor * sunvisibility * (1.0-rainStrength*1.0);
		}
	
		#ifdef DYNAMIC_TONEMAPPING
			
			// Screen getting darker when looking at the sun.
			color.rgb *= (1.0 - centerVisibility * 1.2 * truepos * (TimeSunrise + TimeNoon + TimeSunset) * (1.0 - rainStrength));
			
		#endif

	}

//rain drops on screen

	if (rainStrength > 0.01) {

		float lightmap = pow(eyeBrightnessSmooth.y/255.0, 6.0f);
		float fake_refract  = sin(texcoord.x*30.0 + texcoord.y*50.0);
		
		vec3 watercolor = texture2D(gaux2, texcoord.st + fake_refract * 0.0075).rgb;
		
		// Set up domain
		vec2 dropAnimation = vec2(frameTimeCounter * 0.0, frameTimeCounter * 0.4);
		vec2 q = texcoord.xy + texcoord.x * 0.5;
		vec2 p = -1.0 + 3.0 * q + dropAnimation;
		vec2 p2 = -1.0 + 3.0 * q + dropAnimation + vec2(10.0, 10.0);
		
		p.x += fake_refract * 0.02;
		p.y += fake_refract * 0.02;
			
		p2.x += fake_refract * 0.01;
		p2.y += fake_refract * 0.01;
		
		// Create noise using fBm
		float f = fbmRain(2.5 * p);
		float f2 = fbmRain(5.0 * p2);
	 
		float cover = 0.37f * lightmap * rainStrength;
		float sharpness = 1.0;	// Brightness
		
		float c = f - (1.0 - cover);
		if ( c < 0.0 )
			 c = 0.0;
		
		f = 1.0 - (pow(1.0 - sharpness, c));
				
				
		float c2 = f2 - (1.0 - cover);
		if ( c2 < 0.0 )
			 c2 = 0.0;
		
		f2 = 1.0 - (pow(1.0 - sharpness, c2));
				
		float raindrops = clamp((f + f2), 0.0, 1.0);
		 
		if (isEyeInWater < 0.9) {
			color = mix(color, watercolor, raindrops);
		}
	}
	
#endif

#ifdef BLOOM

	float torch_lightmap = 1.0-pow(aux.b, 13.0);

	const int GL_LINEAR = 9729;
	const int GL_EXP = 2048;
	
	const bool torchlightBloom = false;		// Not done yet.
	
	float bRadius     = 15.0;
	float bIntensity  = 0.7;
	float bCover      = 0.3;
	float bMipmapStep = 3.0;

	float scale = length(vec2(pw,ph));
	vec3 csample = vec3(0.0);

			
	for (int i=0; i < 25; i++) {
	
		vec2 coords = offsets[i];
		csample    += max(texture2DLod(gaux2, texcoord.xy + coords * bRadius*scale, bMipmapStep).rgb - bCover, 0.0) * (length(coords) + 0.6)/2.0;
			
	}
	
	// Desaturate samples.
	vec3 bGray = vec3(0.3, 0.3, 0.3);
	vec3 bColorScale = vec3(0.8, 0.9, 1.0);
	float bSaturation = 0.3;

	vec3 bOutColor = csample.rgb;
	bOutColor = (bOutColor * bColorScale);
		
	float bLuma = dot(bOutColor, bGray);
	vec3 bChroma = bOutColor - bLuma;
	bOutColor = (bChroma * bSaturation) + bLuma;
		
	csample = bOutColor;

	color += csample / 25.0 * bIntensity;
	
	
	if (torchlightBloom) {
	
		vec3 glowSample = vec3(0.0);

		for (int i=0; i < 25; i++) {
		
			vec2 coords = offsets[i];
			glowSample += max(clamp(pow(texture2DLod(gaux1, texcoord.xy + coords * bRadius*scale, bMipmapStep).b, 30.0), 0.0, 0.1), 0.0) * (length(coords) + 0.6)/2.0 * vec3(1.0, 0.6, 0.3);
				
		}
		
		color += glowSample / 25.0 * 5.0;
	
	}
	
#endif

	color = clamp(color,0.0,1.0);

	float white = luma(color);
	color = color*(1.0+pow(white,0.3))/(2.0-0.3);

	color = pow(color,vec3(2.2));

	//Tonemapping
	vec3 curr = Uncharted2Tonemap(color);
	
	vec3 whiteScale = 1.0f/Uncharted2Tonemap(vec3(48.0));
	color = curr*whiteScale;


    float dist = distance(texcoord.st, vec2(0.5, 0.5));
	dist = 0.75 - dist;
	
    color.r = color.r * dist;
    color.g = color.g * dist;
    color.b = color.b * dist;

	color.r = pow(color.r, 0.85);
	color.g = pow(color.g, 0.85);
	color.b = pow(color.b, 0.85);
	
    vec3 Gray = vec3(0.0, 0.3, 0.3);
    vec3 ColorScale = vec3(1.0, 1.0, 1.0);
    float Saturation = 1.35;

    // Color Matrix
    vec3 OutColor = color.rgb;
    
    // Offset & Scale
    OutColor = (OutColor * ColorScale);
    
    // Saturation
    float Luma = dot(OutColor, Gray);
    vec3 Chroma = OutColor - Luma;
    OutColor = (Chroma * Saturation) + Luma;
    
    color = OutColor;
	
	color *= 2.0;

	
#ifdef VINTAGE

	vec3 vintage_color = vec3(1.08, 1.19, 1.0);
	vec3 second_color = vec3(0.0, 0.02, 0.05);
	
	color.rgb = color.rgb * vintage_color + second_color;

#endif

	color = pow(color,vec3(1.0/2.5));

	gl_FragColor = vec4(color,1.0);
	
}
