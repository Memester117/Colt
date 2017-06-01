#version 120
/*
						[][][][][] [][][][][] [][][][][] [][][][][] []   	  
						[]	  	       []     []      [] []	     [] []        
						[]	 	       []     []      [] []	     [] []  	    	  
						[][][][][]     []     []      [] [][][][][] []   	  
								[]     []     []      [] []	        []        
								[]     []     []      [] []	              	  
						[][][][][]     []     [][][][][] []	        []        
						Before editing anything here make sure you've 
						read The agreement, which you accepted by downloading
						my shaderpack. The agreement can be found here:
 http://www.minecraftforum.net/forums/mapping-and-modding/minecraft-mods/2348685-kadir-nck-shader-v1-2
						   
				Kadir Nck's shaders, derived from Chocapic's shaders */
//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES


	#define VIGNETTE
	
	#define RAIN_DROPS

  //#define DOF

	


//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES


varying vec3 ambient_color;
varying vec4 texcoord;
varying vec3 sunlight;


uniform sampler2D depthtex0;
uniform sampler2D noisetex;
uniform sampler2D depthtex2;
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
vec3 sunPos = sunPosition;
uniform int fogMode;
float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;
float timefract = worldTime;

//Raining
float rainx = clamp(rainStrength, 0.0f, 1.0f)/1.0f;
float wetx  = clamp(wetness, 0.0f, 1.0f);

//Calculate Time of Day
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

// Standard depth function.
float getDepth(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

float distratio(vec2 pos, vec2 pos2) {
	float xvect = pos.x*aspectRatio-pos2.x*aspectRatio;
	float yvect = pos.y-pos2.y;
	return sqrt(xvect*xvect + yvect*yvect);
}

float smStep (float edge0,float edge1,float x) {
float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
return t * t * (3.0 - 2.0 * t); }

float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

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

//////DOF
// normal lens properties
const float focal = 0.024;
float aperture = 0.009;	
const float sizemult = 100.0;


#define TONEMAP
#define TONEMAP_CURVE 4.0
#define CONTRAST 0.2
#define GAMMA 0.8	
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////

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
void main() {
	vec2 fake_refract = vec2(sin(worldTime/5.0 + texcoord.x*100.0 + texcoord.y*50.0),cos(worldTime/15.0 + texcoord.y*100.0 + texcoord.x*50.0)) * isEyeInWater;
	vec3 color = texture2D(gaux2, texcoord.st + fake_refract * 0.005).rgb;
	
/*
#ifdef DOF
	float focal = ld(texture2D(depthtex2,vec2(0.5)).x);
	float ddiff;
	float mult = 1.0;
	vec3 bcolor = vec3(0.0);
	vec2 samplecoord;
	bcolor = color.rgb;
	for (int i = -3; i < 4; i++) {
		for (int j = -3; j < 4; j++) {
			samplecoord = vec2(pw*i*2.0f,pw*cos(j/3.0f)*6.0f);
			ddiff = ld(texture2D(depthtex2, texcoord.xy + samplecoord).x);
			if (ddiff - ld(depth) < 0.0) {
				ddiff -= -focal;
				bcolor += texture2D(gaux2,texcoord.xy + samplecoord).rgb*ddiff;
				mult += ddiff;
			}
		}
	}
	color.rgb = bcolor/mult;
#endif
*/


#ifdef DOF
	
	//Calculate pixel Circle of Confusion that will be used for bokeh depth of field
	float z = ld(texture2D(depthtex2, texcoord.st).r)*far;
	float focus = ld(texture2D(depthtex2, vec2(0.5)).r)*far;
	float pcoc = min(abs(aperture * (focal * (z - focus)) / (z * (focus - focal)))*sizemult,pw*10.0);		
	
	vec4 sample = vec4(0.0);
	vec3 bcolor = vec3(0.0);
	float nb = 0.0;
	vec2 bcoord = vec2(0.0);

	for ( int i = 0; i < 60; i++) {
		sample = texture2D(gaux2, texcoord.xy + hex_offsets[i]*pcoc*vec2(1.0,aspectRatio));
		bcolor += sample.rgb;
	}
	
	color.rgb = bcolor/60.0;
		
#endif
	

#ifdef RAIN_DROPS

	if (rainStrength > 0.01) {
		const float pi = 3.14159265359;
		float lightmap = pow(eyeBrightness.y/255.0, 6.0f);
		vec3 watercolor = texture2D(gaux1, texcoord.st + fake_refract * 0.015 * lightmap).rgb;
		float raindrops = 0.0;
		float fake_refract = 1.0-sin(worldTime/5.14159265359 + texcoord.x*30.0 + texcoord.y*30.0);
		float fake_refract2 = sin(worldTime/7.14159265359 + texcoord.x*20.0 + texcoord.y*20.0) * pow(eyeBrightness.y/255.0, 6.0f) * (1.0-TimeMidnight*0.7);
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

/////Color
	
	color.rgb *= pow(color.rgb, 0.9/vec3(2.3));
	float dist = distance(texcoord.st, vec2(0.5, 0.5));
	dist = 0.75 - dist;
	
	#ifdef VINTAGE
	
		color.r = pow(color.r, 1.2);
		color.g = pow(color.g, 1.2);
		color.b = pow(color.b, 1.2);
		
		color.r = pow(color.r, 0.9);
		color.g = pow(color.g, 0.9);
		color.b = pow(color.b, 0.9);
		
	#endif


	#ifdef VIGNETTE
	
		float len = length(texcoord.xy-vec2(.5));
		float len2 = distratio(texcoord.xy,vec2(.5));
		float dc = mix(len,len2,0.3);
		float vintage_color = smStep(1.80, 1.19, 1.10);
		
		color.rgb = color.rgb * (vintage_color,1.80);
	
	#endif

	#ifdef TONEMAP

		color = color / (color + TONEMAP_CURVE) * (1.0+TONEMAP_CURVE);


	#endif
	
	color = clamp(color,0.0,1.0);
	
	vec3 Gray = vec3(0.0, 0.3, 0.3);
	float white = luma(color);
	color = color*(1.0+pow(white,CONTRAST))/(2.0-CONTRAST);

	color = pow(color,vec3(2.2));
	
	color = pow(color,vec3(1.0/2.2));
	
	gl_FragColor = vec4(color,1.0);
	
}
