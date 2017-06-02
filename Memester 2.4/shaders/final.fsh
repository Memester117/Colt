#version 120
#define MAX_COLOR_RANGE 48.0

/*
!! DO NOT REMOVE !!
This code is from CYBOX shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

/*
Disable an effect by putting "//" before "#define" when there is no number after
You can tweak the numbers, the impact on the shaders is self-explained in the variable's name or in a comment
*/

//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES
//#define VIGNETTE
//#define VIGNETTE_STRENGTH 0.0	//default 0.72
//#define VIGNETTE_START 0.0		//distance from the center of the screen where the vignette effect start (0-1), default 0.1
//#define VIGNETTE_END 0.0		//distance from the center of the screen where the vignette effect end (0-1), bigger than VIGNETTE_START, default 0.7
  
#define LENS_EFFECTS		
	#define LENS_STRENGTH 6.0		//default 6.0
	
//#define RAIN_DROPS


//#define DOF							//enable depth of field (blur on non-focused objects)
	//#define HEXAGONAL_BOKEH			//disabled : circular blur shape - enabled : hexagonal blur shape
	//#define DISTANT_BLUR				//constant
			//lens properties
			const float focal = 0.024;
			float aperture = 0.009;	
			const float sizemult = 100.0;
			/*
			Try different setting by replacing the values above by the values here or use your own settings
			----------------------------------
			"Near to human eye (for gameplay,default)":

			const float focal = 0.024;
			float aperture = 0.009;	
			const float sizemult = 100.0;
			----------------------------------
			"Tilt shift (cinematics)":

			const float focal = 0.3;
			float aperture = 0.3;	
			const float sizemult = 1.0;
			----------------------------------
			"Camera (cinematics)":

			const float focal = 0.05;
			float aperture = focal/7.0;	
			const float sizemult = 100.0;
			---------------------------------- 
			*/

//tonemapping constants			
float A = 1.0;		//brightness multiplier
float B = 0.37;		//black level (lower means darker and more constrasted, higher make the image whiter and less constrasted)
float C = 0.1;		//constrast level 



//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES



varying vec4 texcoord;

varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying vec3 sunlight;
varying vec3 moonlight;
varying vec3 ambient_color;

varying float eyeAdapt;

varying float SdotU;
varying float MdotU;
varying float sunVisibility;
varying float moonVisibility;


uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D noisetex;
uniform sampler2D gaux2;
uniform sampler2D gaux4;
uniform sampler2D composite;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
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
vec3 sunPos = sunPosition;
float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;
float timefract = worldTime;

//Raining
float rainx = clamp(rainStrength, 0.0f, 2.0f)/2.0f;
float wetx  = clamp(wetness, 0.0f, 2.0f);

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
											
	const vec2 offsets[60] = vec2[60]  (  vec2( 0.0000, 0.2500 ),
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



vec3 Uncharted2Tonemap(vec3 x) {
	float D = 0.2;		
	float E = 0.02;
	float F = 0.3;
	float W = MAX_COLOR_RANGE;
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

float distratio(vec2 pos, vec2 pos2) {
	float xvect = pos.x*aspectRatio-pos2.x*aspectRatio;
	float yvect = pos.y-pos2.y;
	return sqrt(xvect*xvect + yvect*yvect);
}
								
float gen_circular_lens(vec2 center, float size) {
	float dist=distratio(center,texcoord.xy)/size;
	return exp(-dist*dist);
}

vec2 noisepattern(vec2 pos) {
	return vec2(abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f)),abs(fract(sin(dot(pos.yx ,vec2(18.9898f,28.633f))) * 4378.5453f)));
}

float getnoise(vec2 pos) {
	return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
}

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*2.0;
}



vec3 alphablend(vec3 c, vec3 ac, float a) {
vec3 n_ac = normalize(ac)*(1/sqrt(3.));
vec3 nc = sqrt(c*n_ac);
return mix(c,nc,a);
}
float smStep (float edge0,float edge1,float x) {
float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
return t * t * (3.0 - 2.0 * t); }
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {


		const float pi = 3.14159265359;
		float rainlens = 0.0;
		const float lifetime = 4.0;		//water drop lifetime in seconds
		float ftime = frameTimeCounter*2.0/lifetime;  
		vec2 drop = vec2(0.0,fract(frameTimeCounter/20.0));
#ifdef RAIN_DROPS
		if (rainStrength > 0.02) {
		float gen = 1.0-fract((ftime+0.5)*0.5);
		vec2 pos = (noisepattern(vec2(-0.94386347*floor(ftime*0.5+0.25),floor(ftime*0.5+0.25))))*0.8+0.1 - drop;
		rainlens += gen_circular_lens(fract(pos),0.04)*gen*rainStrength;

		gen = 1.0-fract((ftime+1.0)*0.5);
		pos = (noisepattern(vec2(0.9347*floor(ftime*0.5+0.5),-0.2533282*floor(ftime*0.5+0.5))))*0.8+0.1- drop;
		rainlens += gen_circular_lens(fract(pos),0.023)*gen*rainStrength;

		gen = 1.0-fract((ftime+1.5)*0.5);
		pos = (noisepattern(vec2(0.785282*floor(ftime*0.5+0.75),-0.285282*floor(ftime*0.5+0.75))))*0.8+0.1- drop;
		rainlens += gen_circular_lens(fract(pos),0.03)*gen*rainStrength;

		gen =  1.0-fract(ftime*0.5);
		pos = (noisepattern(vec2(-0.347*floor(ftime*0.5),0.6847*floor(ftime*0.5))))*0.8+0.1- drop;
		rainlens += gen_circular_lens(fract(pos),0.05)*gen*rainStrength;
	
		rainlens *= clamp((eyeBrightness.y-220)/15.0,0.0,1.0);
	}
#endif
	vec2 fake_refract = vec2(sin(frameTimeCounter + texcoord.x*100.0 + texcoord.y*50.0),cos(frameTimeCounter + texcoord.y*100.0 + texcoord.x*50.0)) ;
	vec2 newTC = texcoord.st + fake_refract * 0.01 * (rainlens+isEyeInWater*0.25);
	
	vec3 color = pow(texture2D(gaux2, newTC).rgb,vec3(2.2))*MAX_COLOR_RANGE;

	float fog = 1-(exp(-pow(ld(texture2D(depthtex0, newTC.st).r)/256.0*far,4.0-(2.7*rainStrength))*4.0));
	
	
#ifdef DOF
	float z = ld(texture2D(depthtex0, newTC.st).r)*far;
	float focus = ld(texture2D(depthtex0, vec2(0.5)).r)*far;
	float pcoc = min(abs(aperture * (focal * (z - focus)) / (z * (focus - focal)))*sizemult,pw*15.0);
	#ifdef DISTANT_BLUR
	pcoc = min(fog*pw*20.0,pw*20.0);
	#endif
	vec4 sample = vec4(0.0);
	vec3 bcolor = color/MAX_COLOR_RANGE;
	float nb = 0.0;
	vec2 bcoord = vec2(0.0);
	if (pcoc > pw) {
	#ifdef HEXAGONAL_BOKEH
	
		for ( int i = 0; i < 60; i++) {
			bcolor += pow(texture2D(gaux2, newTC.xy + hex_offsets[i]*pcoc*vec2(1.0,aspectRatio)).rgb,vec3(2.2));
			
		}
		color.rgb = bcolor/61.0*MAX_COLOR_RANGE;
	#else

		for ( int i = 0; i < 60; i++) {
		bcolor += pow(texture2D(gaux2, newTC.xy + offsets[i]*pcoc*vec2(1.0,aspectRatio)).rgb,vec3(2.2));
		}
color.rgb = bcolor/61.0*MAX_COLOR_RANGE;
	#endif
		
	}
#endif
	

	color.xyz = ((1-(1-color.xyz/48.0)*(1-(color.rgb/48.0)*sqrt(luma(color.rgb/48.0))))*48.0);


	//draw rain
	vec4 rain = pow(texture2D(gaux4,newTC.xy)+0.0001,vec4(vec3(2.2),0.4))*vec4(ambient_color*0.4,1.0);
	color.rgb = alphablend(color,rain.rgb,rain.a);


	


	//rain drops on screen
	#ifdef RAIN_DROPS
	vec3 c_rain = rainlens*ambient_color;
	color = alphablend(color,ambient_color,rainlens);
	#endif


	
	
	//Tonemapping
	vec3 curr = Uncharted2Tonemap(color);
	
	vec3 whiteScale = 1.0f/Uncharted2Tonemap(vec3(MAX_COLOR_RANGE));
	color = curr*whiteScale;
	
		
	#ifdef VIGNETTE
	float len = length(texcoord.xy-vec2(.5));
	float len2 = distratio(texcoord.xy,vec2(.5));
	float dc = mix(len,len2,0.3);
    float vignette = smStep(VIGNETTE_END, VIGNETTE_START,  dc);
	
	color = mix(color,color*vignette,VIGNETTE_STRENGTH);
	#endif

	
			#ifdef LENS_EFFECTS
	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
	tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 pos2 = tpos.xy/tpos.z;
	vec2 lightPos = pos2*0.5+0.5;
	float truepos = sunPosition.z/abs(sunPosition.z);		//1 -> sun / -1 -> moon

	float xdist = abs(lightPos.x-newTC.x);
	float ydist = abs(lightPos.y-newTC.y);

	float sunvisibility = texture2D(gaux2,vec2(pw,ph)).a*(1-rainStrength*0.9);
	
	float centerdist = clamp(1.0 - pow(cdist(lightPos), 0.2), 0.0, 1.0);

	vec3 light_color = mix(sunlight*sunVisibility,3*moonlight*moonVisibility,(truepos+1.0)/2.);
	
		if (sunvisibility > 0.05) {

			vec3 lensColor = exp(-ydist*ydist/0.003/(1.5-centerdist))*exp(-xdist*xdist/0.05/(1.5-centerdist))* vec3(0.1,0.3,1.0);

			vec2 LC = vec2(0.5)-lightPos;
			
			
			
			vec2 pos1 = lightPos + LC * 0.7;
			lensColor += vec3(1.0,0.3,.1)*gen_circular_lens(vec2(pos1),0.03*(1.5-centerdist))*0.58;
			
			pos1 = lightPos + LC * 0.9;
			lensColor += vec3(0.8,0.6,.1)*gen_circular_lens(vec2(pos1),0.06*(1.5-centerdist))*0.375;
			
			pos1 = lightPos + LC * 1.3;
			lensColor += vec3(0.1,1.0,.3)*gen_circular_lens(vec2(pos1),0.12*(1.5-centerdist))*0.28;
			
			pos1 = lightPos + LC * 2.1;
			lensColor += vec3(0.1,0.6,.8)*gen_circular_lens(vec2(pos1),0.24*(1.5-centerdist))*0.21;
			
			//lensColor += gen_circular_lens(vec2(lightPos),0.04*(1.3-centerdist))*pow(sunvisibility,-0.1)*.2/(centerdist*0.99+0.01);		//sun glare (replace bloom)
			
			lensColor = lensColor*pow(sunvisibility,2.2)*light_color*LENS_STRENGTH*centerdist;
			color += lensColor + gen_circular_lens(vec2(lightPos),0.035*(2.3-centerdist))*pow(sunvisibility,-0.1)*.3*pow(sunvisibility,2.2)*light_color*LENS_STRENGTH*(1-centerdist*0.95);
	       
             }
        #endif
         
        float saturation = 1.015;   
	
       
        float avg = (color.r + color.g + color.b);
       
        color = (((color - avg )*saturation)+avg) ;
		color /= saturation;

	
	

	

	


	color = clamp(pow(color,vec3(1.0/2.2)),0.0,1.0);

	 color.r = color.r*1.1;
         color.g = color.g*1.1; 
         color.b = color.b*1.1;


	gl_FragColor = vec4(color,1.0);
}

