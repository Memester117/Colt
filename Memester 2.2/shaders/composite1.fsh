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

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////


	#define GODRAYS
	
	#define MOTION_BLUR
	
	#define WATER_REFLECTIONS			
	#define REFLECTION_STRENGTH 0.8
	
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////



//don't touch these lines if you don't know what you do!
const int maxf = 4;				//number of refinements
const float stp = 1.2;			//size of one step for raytracing algorithm
const float ref = 0.1;			//refinement multiplier
const float inc = 2.2;			//increasement factor at each step

varying vec4 texcoord;
varying vec3 sunlight;
varying vec3 lightVector;
varying vec3 ambient_color;

uniform sampler2D composite;
uniform sampler2D gaux4;
uniform sampler2D gaux1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D gnormal;
uniform sampler2D gdepth;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
uniform vec3 skyColor;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;

uniform int isEyeInWater;
uniform int worldTime;
uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;

//Minecraft time cycle
float timefract = worldTime;
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

uniform int fogMode;

float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;

	float matflag = texture2D(gaux1,texcoord.xy).g;


	vec3 fogclr = mix(gl_Fog.color.rgb,vec3(0.2,0.2,0.2),rainStrength)*ambient_color;
	
    vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);
    vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
	
    vec4 color = texture2D(composite,texcoord.xy);
	


float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

#ifdef WATER_REFLECTIONS

float cdist(vec2 coord) {
	return max(abs(coord.x-0.5),abs(coord.y-0.5))*2.0;
}

#endif

float luma(vec3 color) {
return dot(color.rgb,vec3(0.299, 0.587, 0.114));
}

#ifdef WATER_REFLECTIONS
	vec4 raytrace(vec3 fragpos, vec3 normal) {

		vec4 color = vec4(0.0);
		vec3 start = fragpos;
		vec3 rvector = normalize(reflect(normalize(fragpos), normalize(normal)));
		vec3 vector = 1.2 * rvector;
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
			if(err < length(vector)*pow(length(tvector),0.11)*1.75){

				sr++;
				if(sr >=  4.0){
				
				float border = clamp(1.0 - pow(cdist(pos.st), 5.0), 0.0, 1.0);
				color = texture2D(composite, pos.st);
				color.a = 1.0;
				color.a *= border;
				break;
					
				}
					
				tvector -=vector;
				vector *= 0.1;
			
			}
				
			vector *= 2.2;
			oldpos = fragpos;
			tvector += vector;
			fragpos = start + tvector;
				
		}
			
		return color;
			
	}

#endif

#ifdef GODRAYS
	float getnoise(vec2 pos) {
	return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
		
	}
#endif

//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////

void main() {

	int land = int(matflag < 0.03);
	int iswater = int(matflag > 0.04 && matflag < 0.07);
	int hand  = int(matflag > 0.75 && matflag < 0.85);
	
	fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));
	
	#ifdef MOTION_BLUR

		vec4 blur  = texture2D(depthtex2, texcoord.st);
	
		vec4 currentPosition = vec4(texcoord.x * 2.0 - 1.0, texcoord.y * 2.0 - 1.0, 2.0 * blur.x - 1.0, 1.0);
	
		vec4 fragposition = gbufferProjectionInverse * currentPosition;
		fragposition = gbufferModelViewInverse * fragposition;
		fragposition /= fragposition.w;
		fragposition.xyz += cameraPosition;
	
		vec4 previousPosition = fragposition;
		previousPosition.xyz -= previousCameraPosition;
		previousPosition = gbufferPreviousModelView * previousPosition;
		previousPosition = gbufferPreviousProjection * previousPosition;
		previousPosition /= previousPosition.w;

		vec2 velocity = (currentPosition - previousPosition).st * 0.02;

		int samples = 1;

		vec2 coord = texcoord.st + velocity;
		for (int i = 0; i < 3; ++i, coord += velocity) {
			if (coord.s > 1.0 || coord.t > 1.0 || coord.s < 0.0 || coord.t < 0.0) {
				break;
			}
				color += texture2D(composite, coord);
				++samples;
		}

	color = (color/1.0)/samples;
	
#endif
	
	
    if (iswater > 0.9) {

	#ifdef WATER_REFLECTIONS
		
		if (iswater > 0.9) {
			
			vec4 reflection = raytrace(fragpos, normal);
		
				float normalDotEye = dot(normal, normalize(fragpos));
				float fresnel = clamp(pow(1.0 + normalDotEye, 5.0),0.0,1.0);
		
				reflection.rgb = mix(gl_Fog.color.rgb, reflection.rgb, reflection.a);			//fake sky reflection, avoid empty spaces
				reflection.a = min(reflection.a + 0.75,1.0);

				color.rgb = mix(color.rgb,reflection.rgb , fresnel * (1.0-isEyeInWater*0.8)*reflection.a);
		 
		}
	#endif
    }
	
		vec3 colmult = mix(vec3(1.0),vec3(0.1,0.25,0.45),isEyeInWater);
		float depth_diff = clamp(pow(ld(texture2D(depthtex0, texcoord.st).r)*3.4,2.0),0.0,1.0);
		color.rgb = mix(color.rgb*colmult,vec3(0.05,0.1,0.15),depth_diff*isEyeInWater);
		
		float time = float(worldTime);
		float transition_fading = 1.0-(clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-13000.0)/300.0,0.0,1.0) + clamp((time-22800.0)/200.0,0.0,1.0)-clamp((time-23400.0)/200.0,0.0,1.0));
		float fog = clamp(exp(-length(fragpos)/192.0*(1.0+rainStrength)/1.4)+0.25*(1.0-rainStrength),0.0,1.0);
		//inject sun color into the fog
		float volumetric_cone = max(dot(normalize(fragpos),lightVector),0.0)*transition_fading;
		//fogclr += sunlight*pow(volumetric_cone,9.0)*1.5*(1.0-rainStrength*0.9);
		float fogfactor =  clamp(fog + hand + isEyeInWater,0.0,1.0);
		fogclr = mix(fogclr,color.rgb,(1.0-rainStrength)*0.7);
		color.rgb = mix(fogclr,color.rgb,fogfactor);
		
/* DRAWBUFFERS:5 */
	
	//draw rain
	color.rgb += texture2D(gaux4,texcoord.xy).a*0.1;
	
	
		vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
		tpos = vec4(tpos.xyz/tpos.w,1.0);
		vec2 pos1 = tpos.xy/tpos.z;
		vec2 lightPos = pos1*0.5+0.5;

	
	
	#ifdef GODRAYS
	if (rainStrength < 0.5) {
		const float exposure = 0.28;
		const float density = 0.7;			
		const int NUM_SAMPLES = 10;
		const float grnoise = 0.0;

		vec2 deltaTextCoord = vec2( texcoord.st - lightPos.xy );
		vec2 textCoord = texcoord.st;
		deltaTextCoord *= 1.0 /  float(NUM_SAMPLES) * density;
		float illuminationDecay = 1.0;
		float gr = 0.0;
		float distx = abs(texcoord.x*aspectRatio-lightPos.x*aspectRatio);
		float disty = abs(texcoord.y-lightPos.y);
		illuminationDecay = pow(max(1.0-sqrt(distx*distx+disty*disty),0.0),3.0);

		for(int i=0; i < NUM_SAMPLES ; i++) {
		
			textCoord -= deltaTextCoord;
				
			float sample = texture2D(gdepth, textCoord).r;
			gr += sample;

		}
	
		vec3 GODRAYS_color_sunrise = vec3(2.52, 0.5, 0.2) * 1.0 * TimeSunrise * (1.0 - rainStrength * 1.0);
		vec3 GODRAYS_color_noon = vec3(2.52, 0.8, 0.2) * 1.0 * TimeNoon * (1.0 - rainStrength * 1.0);
		vec3 GODRAYS_color_sunset = vec3(2.52, 0.7, 0.2) * TimeSunset * (1.0 - rainStrength * 1.0);
		vec3 GODRAYS_color_night = vec3(0.2, 0.2, 0.7) * 1.3 * TimeMidnight * (1.0 - rainStrength * 1.0);
		vec3 GODRAYS_color_rain = vec3(0.7,0.85,1.0) * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength;
		
		vec3 GODRAYS_color = GODRAYS_color_sunrise + GODRAYS_color_noon + GODRAYS_color_sunset + GODRAYS_color_night + GODRAYS_color_rain;
		

		float truepos = 0.0f;
		
		if ((worldTime < 13000 || worldTime > 23000) && sunPosition.z < 0) truepos = 1.0 * (TimeSunrise + TimeNoon + TimeSunset); 
		if ((worldTime < 23000 || worldTime > 13000) && -sunPosition.z < 0) truepos = 1.0 * TimeMidnight; 
	
		color.rgb = mix(color.rgb,pow(GODRAYS_color,vec3(1.0/4.0)),((gr/NUM_SAMPLES)*exposure*truepos*length(pow(GODRAYS_color,vec3(1.0/2.2)))*illuminationDecay/sqrt(3.0)*transition_fading));
	}	
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
