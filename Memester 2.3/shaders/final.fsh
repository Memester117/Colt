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

	#define Vignette_Strength 0.8							//default 0.8
	#define Vignette_Start 0								//distance from the center of the screen where the vignette effect start (0-1), default 0.1
	#define Vignette_End 1.5								//distance from the center of the screen where the vignette effect end (0-1), default 1.5
  
	#define Lens_Strength 1									//default 1

	#define Bloom											//Makes glow effect on bright stuffs.

	//#define DOF											//Blurs non-focused objects.
			#define DOF_DistantBlur_Range 304				//blur distance from player position (best : render distance(in block) * 2.5 - 16)

		const float focal = 0.025;
		float aperture = 0.01;
		const float sizemult = 100.0;
		
		#define DOF_BlurSize 4
		

	//#define MotionBlur									//Sweeps screen when looking/moving too fast.
		#define MotionBlur_Pass 4

	#define Color_Boost 0.15	
	#define Color_Saturation 0.95
	
//TONEMAP		
float A = 1.0;		//brightness multiplier
float B = 0.37;		//black level (lower means darker and more constrasted, higher make the image whiter and less constrasted)
float C = 0.1;		//constrast level 
	
//ADJUSTABLE VARIABLES//



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

uniform sampler2D gaux1;
vec3 aux = texture2D(gaux1, texcoord.st).rgb;
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

float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}
											
const vec2 circle_offsets[60] = vec2[60]  (  vec2( 0.0000, 0.2500 ),
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


float distratio(vec2 pos, vec2 pos2, float ratio) {
	float xvect = pos.x*ratio-pos2.x*ratio;
	float yvect = pos.y-pos2.y;
	return sqrt(xvect*xvect + yvect*yvect);
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
		 
	return pow(min(distratio(lightPos.xy, texcoord.xy, aspectRatio),size)/size,10.);
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
   	f += 1.0000*noise( p ); p = p*2.03;
   	f += 0.12500*noise( p ); p = p*2.01;
   	f += 0.06250*noise( p ); p = p*2.04;
   	f += 0.03125*noise( p );
	
   	return f/0.984375;
}

vec3 alphablend(vec3 c, vec3 ac, float a) {
vec3 n_ac = normalize(ac)*(1/sqrt(3.));
vec3 nc = sqrt(c*n_ac);
return mix(c,nc,a);
}
float smStep (float edge0,float edge1,float x) {
float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
return t * t * (3.0 - 2.0 * t); }
float dirtPattern (vec2 tc) {
	float noise = texture2D(noisetex,tc).x;
	noise += texture2D(noisetex,tc*3.5).x/3.5;
	noise += texture2D(noisetex,tc*12.25).x/12.25;
	noise += texture2D(noisetex,tc*42.87).x/42.87;	
	return noise / 1.4472;
}
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

		if (rainStrength > 0.02) {
		float gen = 1.0-fract((ftime+0.5)*0.5);
		vec2 pos = (noisepattern(vec2(-0.94386347*floor(ftime*0.5+1.0),floor(ftime*0.5+1.0))))*0.8+0.1 - drop;
		rainlens += gen_circular_lens(fract(pos),0.04)*gen*rainStrength;

		gen = 1.0-fract((ftime+1.0)*0.5);
		pos = (noisepattern(vec2(0.9347*floor(ftime*0.5+0.5),-1.033282*floor(ftime*0.5+0.5))))*0.8+0.1- drop;
		rainlens += gen_circular_lens(fract(pos),0.023)*gen*rainStrength;

		gen = 1.0-fract((ftime+1.5)*0.5);
		pos = (noisepattern(vec2(0.785282*floor(ftime*0.5+0.75),-0.285282*floor(ftime*0.5+0.75))))*0.8+0.1- drop;
		rainlens += gen_circular_lens(fract(pos),0.03)*gen*rainStrength;

		gen =  1.0-fract(ftime*0.5);
		pos = (noisepattern(vec2(-0.347*floor(ftime*0.5),0.6847*floor(ftime*0.5))))*0.8+0.1- drop;
		rainlens += gen_circular_lens(fract(pos),0.05)*gen*rainStrength;
	
		rainlens *= clamp((eyeBrightness.y-220)/15.0,0.0,1.0);
	}
	vec2 fake_refract = vec2(sin(frameTimeCounter + texcoord.x*100.0 + texcoord.y*50.0),cos(frameTimeCounter + texcoord.y*100.0 + texcoord.x*50.0)) ;
	vec2 newTC = texcoord.st + fake_refract * 0.01 * (rainlens+isEyeInWater*0.25);
	#ifdef CAM_SHIFT
	vec2 camshift = vec2(0.37,1.0);
	newTC = newTC/2+camshift;
	#endif
	
	vec3 color = pow(texture2D(gaux2, newTC).rgb,vec3(2.2))*MAX_COLOR_RANGE;
	vec3 aux = texture2D(gaux1, newTC).rgb;
	
		float hand  = float(aux.g > 0.75 && aux.g < 0.85);
		float land = float(aux.g > 0.04);
		
	float fog = 1-(exp(-pow(ld(texture2D(depthtex0, newTC.st).r)/DOF_DistantBlur_Range*far,4.0-(rainStrength))*4.0));
	
float pcoc = 0;	
#ifdef DOF
	float z = ld(texture2D(depthtex0, newTC.st).r)*far;
	float focus = ld(texture2D(depthtex0, vec2(0.5)).r)*far;
	float blursize = DOF_BlurSize*viewWidth/1280;
	pcoc = min((abs(aperture * (focal * (z - focus)) / (z * (focus - focal))))*sizemult,pw*blursize);
	pcoc = pcoc*(1-hand);

	vec4 sample = vec4(0.0);
	vec3 bcolor = vec3(0);
	float nb = 0.0;
	vec2 bcoord = vec2(0.0);
	
	if (pcoc > pw){
	for ( int i = 0; i < 60; i++) {
		bcolor += pow(texture2D(gaux2, newTC.xy + circle_offsets[i]*pcoc*vec2(1.0,aspectRatio)).rgb,vec3(2.2));
		}
		color.rgb = bcolor/(60)*MAX_COLOR_RANGE;
	}
#endif

#ifdef MotionBlur
	
	vec4 motionblur  = texture2D(depthtex2, newTC.st);
	vec3 mblur = pow(texture2D(gaux2,newTC.st).rgb,vec3(2.2))*MAX_COLOR_RANGE;
	
	vec4 currentPosition = vec4(newTC.x * 2.0 - 1.0, newTC.y * 2.0 - 1.0, 2.0 * motionblur.x - 1.0, 1.0);
	
	vec4 fragposition = gbufferProjectionInverse * currentPosition;
	fragposition = gbufferModelViewInverse * fragposition;
	fragposition /= fragposition.w;
	fragposition.xyz += cameraPosition;
	
	vec4 previousPosition = fragposition;
	previousPosition.xyz -= previousCameraPosition;
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	previousPosition /= previousPosition.w;

	vec2 velocity = (currentPosition - previousPosition).st * 0.12 / MotionBlur_Pass;

	vec2 coord = newTC.st + velocity;
	for (int i = 0; i < MotionBlur_Pass; ++i, coord += velocity) {
		if (coord.s > 1.0 || coord.t > 1.0 || coord.s < 0.0 || coord.t < 0.0 || hand > 0.9)
		mblur += pow(texture2D(gaux2, newTC).rgb,vec3(2.2))*MAX_COLOR_RANGE;
		if (hand < 0.9)
		mblur += pow(texture2D(gaux2, coord).rgb,vec3(2.2))*MAX_COLOR_RANGE;
	}
	mblur /= (MotionBlur_Pass+1);
float pcoc1 = clamp(pcoc/2,0,pw*2)/pw/2;
color.rgb = color*pcoc1 + mblur.rgb*(1-pcoc1);
//color = vec3(pcoc1);
#endif

#ifdef Bloom

vec3 blur = vec3(0);
vec2 bloomcoord = texcoord.xy;

	vec3 blur1 = pow(texture2D(composite,bloomcoord/pow(2.0,2.0) + vec2(0.0,0.0)).rgb,vec3(2.2))*pow(6.0,1.0);
	vec3 blur2 = pow(texture2D(composite,bloomcoord/pow(2.0,3.0) + vec2(0.3,0.0)).rgb,vec3(2.2))*pow(5.0,1.0);
	vec3 blur3 = pow(texture2D(composite,bloomcoord/pow(2.0,4.0) + vec2(0.0,0.3)).rgb,vec3(2.2))*pow(4.0,1.0);
	vec3 blur4 = pow(texture2D(composite,bloomcoord/pow(2.0,5.0) + vec2(0.1,0.3)).rgb,vec3(2.2))*pow(3.0,1.0);
	vec3 blur5 = pow(texture2D(composite,bloomcoord/pow(2.0,6.0) + vec2(0.2,0.3)).rgb,vec3(2.2))*pow(2.0,1.0);
	vec3 blur6 = pow(texture2D(composite,bloomcoord/pow(2.0,7.0) + vec2(0.3,0.3)).rgb,vec3(2.2))*pow(1.0,1.0);
	blur = blur1 + blur2 + blur3 + blur4 + blur5 + blur6;
	blur = blur*pow(length(blur),0.4);
	//blur = pow(texture2D(composite,bloomcoord/2).rgb,vec3(2.2));
	
color.rgb = mix(color,blur*MAX_COLOR_RANGE,0.006);
//color = blur*MAX_COLOR_RANGE*0.006;
//color.rgb = blur3;
#endif

	color.xyz = ((1-(1-color.xyz/48.0)*(1-(color.rgb/48.0)*sqrt(luma(color.rgb/48.0))))*48.0);


	//draw rain
	vec4 rain = pow(texture2D(gaux4,newTC.xy),vec4(vec3(2.2),0.4));
	color.rgb = alphablend(color,color,rain.a/2);


	


	//rain drops on screen
	vec3 c_rain = rainlens*ambient_color;
	color = alphablend(color,ambient_color,rainlens);


	
	
	//Tonemapping
	vec3 curr = Uncharted2Tonemap(color);
	
	vec3 whiteScale = 1.0f/Uncharted2Tonemap(vec3(MAX_COLOR_RANGE));
	color = curr*whiteScale;
	
		
	//Vignette
	float len = length(texcoord.xy-vec2(.5));
	float len2 = distratio(texcoord.xy,vec2(.5));
	float dc = mix(len,len2,0.3);
    float vignette = smStep(Vignette_End, Vignette_Start,  dc);
	
	color = mix(color,color*vignette,Vignette_Strength);
	
	
	//Lens Flare
	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
		tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 lightPos = tpos.xy/tpos.z;
		lightPos = (lightPos + 1.0f)/2.0f;

    float distof = min(min(1.0-lightPos.x,lightPos.x),min(1.0-lightPos.y,lightPos.y));
	float fading = clamp(1.0-step(distof,0.1)+pow(distof*10.0,5.0),0.0,1.0);

    float time = float(worldTime);

    float sunvisibility = min(texture2D(gaux2,vec2(0.0)).a,1.0) * fading ;
	float sunvisibility2 = min(texture2D(gaux2,vec2(0.0)).a,1.0);
	float centerVisibility = 1.0 - clamp(distance(lightPos.xy, vec2(0.5, 0.5)) * 2.0, 0.0, 1.0);
		  centerVisibility *= sunvisibility;
	
	float lensBrightness = 1.2*Lens_Strength;
	
	
	// Fix, that the particles are visible on the moon position at daytime
	float truepos = sign(sunPosition.z);		//1 -> sun / -1 -> moon
	vec3 rainc = mix(vec3(1.),vec3(0.2,1.0,0.3),rainStrength);
	vec3 lightColor = mix(sunlight*sunVisibility*rainc,12.0*moonlight*moonVisibility*rainc,truepos*0.5+0.5);
	
	
	// Anamorphic Lens
	if (sunvisibility > 0.01) {
		
		float visibility = max(pow(max(1.0 - smoothCircleDist(1.0)/1.5,0.1),1.0)-0.1,0.0);
		
			
		vec3 lenscolor = length(lightColor)*vec3(0.2, 0.4, 1.25)*(1+moonVisibility)/2;

		float lens_strength = 0.8 * lensBrightness;
		lenscolor *= lens_strength;
		
		float anamorphic_lens = max(pow(max(1.0 - yDistAxis(0.0)/1.4,0.1),10.0),0.0);
		color += anamorphic_lens * lenscolor * visibility  * sunvisibility * (1.0-rainStrength*1.0);
		
		//Sun Glow
		if (length(lightColor) > 0.001)
		lenscolor = pow(normalize(lightColor),vec3(2.2))*length(lightColor)*vec3(0.7,0.75,1.);

			
		lens_strength = 0.6 * lensBrightness;
		lenscolor *= lens_strength;
		
		float lensFlare = max(pow(max(1.0 - smoothCircleDist(1.0)/2.4,0.1),5.0)-0.1,0.0);
			
		//color += lensFlare * lenscolor * sunvisibility2 * (1.0-rainStrength*1.0);
		
		
				// Circle Lens 1
		
		
			lenscolor =  vec3(2.52, 1.8, 0.4) * lightColor;
			
			lens_strength = 0.2 * lensBrightness;
			lenscolor *= lens_strength;
			
			float lensFlare1 = max(pow(max(1.0 - cirlceDist(-0.15, 0.07)/1.0,0.1),5.0)-0.1,0.0);
			float lensFlare2 = max(pow(max(1.0 - cirlceDist(-0.2, 0.07)/1.0,0.1),5.0)-0.1,0.0);
			float lensFlare3 = max(pow(max(1.0 - cirlceDist(-1.0, 0.07)/1.0,0.1),5.0)-0.1,0.0);
			
			lensFlare = clamp(lensFlare1 * lensFlare2 * lensFlare3, 0.0, 1.0);
			
			color += lensFlare * lenscolor * sunvisibility * (1.0-rainStrength*1.0)*0.7;
		
		
		// Circle Lens 2
		
		
			lenscolor =  vec3(0.7, 2.55, 0.4) * lightColor;
			
			lens_strength = 0.2 * lensBrightness;
			lenscolor *= lens_strength;
			
			lensFlare1 = max(pow(max(1.0 - cirlceDist(-0.4, 0.13)/1.0,0.1),5.0)-0.1,0.0);
			lensFlare2 = max(pow(max(1.0 - cirlceDist(-0.5, 0.13)/1.0,0.1),5.0)-0.1,0.0);
			lensFlare3 = max(pow(max(1.0 - cirlceDist(-0.6, 0.13)/1.0,0.1),5.0)-0.1,0.0);
			
			lensFlare = clamp(lensFlare1 * lensFlare2 * lensFlare3, 0.0, 1.0);
			
			color += lensFlare * lenscolor * sunvisibility * (1.0-rainStrength*1.0)*0.7;
		
		
		// Circle Lens 3
		
		
			lenscolor =  vec3(0.4, 1.95, 2.55) * lightColor;
			
			lens_strength = 0.1 * lensBrightness;
			lenscolor *= lens_strength;
			
			lensFlare1 = max(pow(max(1.0 - cirlceDist(-0.75, 0.09)/1.0,0.1),5.0)-0.1,0.0);
			lensFlare2 = max(pow(max(1.0 - cirlceDist(-0.8, 0.09)/1.0,0.1),5.0)-0.1,0.0);
			lensFlare3 = max(pow(max(1.0 - cirlceDist(-0.85, 0.09)/1.0,0.1),5.0)-0.1,0.0);
			
			lensFlare = clamp(lensFlare1 * lensFlare2 * lensFlare3, 0.0, 1.0);
			
			color += lensFlare * lenscolor * sunvisibility * (1.0-rainStrength*1.0)*0.7;
		
		
		
		// Small point 1

		
			lenscolor = vec3(2.55, 2.55, 0.0) * lightColor;
			
			lens_strength = 150.0 * lensBrightness;
			lenscolor *= lens_strength;
			
			lensFlare1 = max(pow(max(1.0 - smoothCircleDist(-0.27)/1.0,0.1),5.0)-0.85,0.0);
			lensFlare2 = max(pow(max(1.0 - smoothCircleDist(-0.3)/1.0,0.1),5.0)-0.85,0.0);
			lensFlare3 = max(pow(max(1.0 - smoothCircleDist(-0.33)/1.0,0.1),5.0)-0.85,0.0);
			
			lensFlare = clamp(lensFlare1 * lensFlare2 * lensFlare3, 0.0, 1.0);
			
			color += lensFlare * lenscolor * sunvisibility * (1.0-rainStrength*1.0);
		
		// Small point 2
		
		
			lenscolor = vec3(0.0, 2.55, 1.52) * lightColor;
			
			lens_strength = 150.0 * lensBrightness;
			lenscolor *= lens_strength;
			
			lensFlare1 = max(pow(max(1.0 - smoothCircleDist(-0.62)/1.0,0.1),5.0)-0.85,0.0);
			lensFlare2 = max(pow(max(1.0 - smoothCircleDist(-0.65)/1.0,0.1),5.0)-0.85,0.0);
			lensFlare3 = max(pow(max(1.0 - smoothCircleDist(-0.68)/1.0,0.1),5.0)-0.85,0.0);
			
			lensFlare = clamp(lensFlare1 * lensFlare2 * lensFlare3, 0.0, 1.0);
			
			color += lensFlare * lenscolor * sunvisibility * (1.0-rainStrength*1.0);
		
		
		// Ring Lens 

		
			lenscolor = vec3(0.2, 0.8, 2.55) * length(lightColor);
			
			lens_strength = 0.3 * lensBrightness;
			lenscolor *= lens_strength;
			
			lensFlare1 = max(pow(max(1.0 - cirlceDist(-0.7, 0.5)/1.0,0.1),5.0)-0.1,0.0);
			lensFlare2 = max(pow(max(1.0 - cirlceDist(-0.9, 0.5)/1.0,0.1),5.0)-0.1,0.0);
			
			lensFlare = clamp(lensFlare2 - lensFlare1, 0.0, 1.0);
			color += lensFlare*lensFlare * lenscolor * sunvisibility * (1.0-rainStrength*1.0)*1.3;
		
		
	}

		
	color = clamp(pow(color,vec3(1.0/2.2)),0.0,1.0);

	color =  (color*(1+Color_Boost) + (color*color-Color_Boost/2)*Color_Boost*(1-land));
	color = color*(Color_Saturation)-(color.r+color.g+color.b)/3*(Color_Saturation-1);
	
	gl_FragColor = vec4(color,1.0);
}

