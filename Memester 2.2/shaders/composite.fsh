#version 120

	const float	ambientOcclusionLevel = 0.8f;		//level of Minecraft smooth lighting, 1.0f is default
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

//----------Shadows----------//

    #define SHADOW_DARKNESS 0.30           	 	//shadow darkness levels, lower values mean darker shadows, see .vsh for colors /0.25 is default
    #define SHADOW_FILTER						//smooth shadows
	
	#define DYNAMIC_HANDLIGHT		
	#define SUNLIGHTAMOUNT 0.67		

    #define GODRAYS

	#define FOG
	
  //#define SSAO	

	#define WATER_REFRACT

	#define UNDERWATER_FOG
	
  //#define CELSHADING
	#define BORDER 0.6
	
//----------TorchColor----------//
vec3 torchcolor = vec3(2.55,0.9,0.2);
//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES
const float	sunPathRotation	= -35.0f;
const int 		shadowMapResolution 	= 1128;			//shadowmap resolution
const float 	shadowDistance 			= 128.0f;		//draw distance of shadows
const int 		R8						= 0;
const int 		gdepthFormat 			= R8;
const bool 		generateShadowMipmap 	= false;
const float 	shadowIntervalSize 		= 4.0f;
//SSAO//
const int nbdir 						= 6;		
const float sampledir 					= 6;	
const float ssaorad 					= 1.0;
//SSAO//	
#define SHADOW_MAP_BIAS 0.85

varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 sunlight_color;
varying vec3 ambient_color;
varying float handItemLight;
varying float eyeAdapt;
varying vec3 sunlight;

uniform sampler2D gcolor;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D gnormal;
uniform sampler2D shadow;
uniform sampler2D gaux1;
uniform sampler2D gaux3;
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
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform int worldTime;
uniform int fogMode;

float timefract = worldTime;

//Calculate Time of Day
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


vec2 texel = vec2(1.0/viewWidth,1.0/viewHeight);
vec3 aux = texture2D(gaux1, texcoord.st).rgb;
vec3 sunPos = sunPosition;
vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0f - 1.0f;
vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);
vec3 fogclr = mix(gl_Fog.color.rgb,vec3(0.2,0.2,0.2),rainStrength)*ambient_color;

float pixeldepth = texture2D(depthtex0,texcoord.xy).x;
float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;
float shadowexit = 0.0;

float handlight = handItemLight;
const float speed = 1.5;
float light_jitter = 1.0-sin(frameTimeCounter*1.4*speed+cos(frameTimeCounter*1.9*speed))*0.0;			//little light variations
float torch_lightmap = pow(aux.b*light_jitter,5.6)*0.92;
float sky_lightmap = pow(aux.r,3.0);

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

float ctorspec(vec3 ppos, vec3 lvector, vec3 normal) {
    //half vector
	vec3 pos = -normalize(ppos);
    vec3 cHalf = normalize(lvector + pos);
	
    // beckman's distribution function D
    float normalDotHalf = dot(normal, cHalf);
    float normalDotHalf2 = normalDotHalf * normalDotHalf;

    float roughness2 = 0.05;
    float exponent = -(1.0 - normalDotHalf2) / (normalDotHalf2 * roughness2);
    float e = 2.71828182846;
    float D = pow(e, exponent) / (roughness2 * normalDotHalf2 * normalDotHalf2);
	
    // fresnel term F
	float normalDotEye = dot(normal, pos);
    float F = pow(1.0 - normalDotEye, 5.0);

    // self shadowing term G
    float normalDotLight = dot(normal, lvector);
    float X = 2.0 * normalDotHalf / dot(pos, cHalf);
    float G = min(1.0, min(X * normalDotLight, X * normalDotEye));
    float pi = 3.1415927;
    float CookTorrance = (D*F*G)/(pi*normalDotEye);
	
    return max(CookTorrance/pi,0.0);
}

float diffuseorennayar(vec3 pos, vec3 lvector, vec3 normal, float spec, float roughness) {
	
    vec3 v=normalize(pos);
	vec3 l=normalize(lvector);
	vec3 n=normalize(normal);

	float vdotn=dot(v,n);
	float ldotn=dot(l,n);
	float cos_theta_r=vdotn; 
	float cos_theta_i=ldotn; 
	float cos_phi_diff=dot(normalize(v-n*vdotn),normalize(l-n*ldotn));
	float cos_alpha=min(cos_theta_i,cos_theta_r); // alpha=max(theta_i,theta_r);
	float cos_beta=max(cos_theta_i,cos_theta_r); // beta=min(theta_i,theta_r)

	float r2=roughness*roughness;
	float a=1.0-0.5*r2/(r2+0.33);
	float b_term;
	
	if(cos_phi_diff>=0.0) {
		float b=0.45*r2/(r2+0.09);
		//b_term=b*sqrt((1.0-cos_alpha*cos_alpha)*(1.0-cos_beta*cos_beta))/cos_beta*cos_phi_diff;
		b_term = b*sin(cos_alpha)*tan(cos_beta)*cos_phi_diff;
	}
	else b_term=0.0;

	return clamp(cos_theta_i*(a+b_term*spec),0.0,1.0);
}

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

float getnoise(vec2 pos) {
return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));

}

float interpolate(vec3 truepos,float center,vec3 poscenter,float value2,vec3 pos2,float value3,vec3 pos3,float value4,vec3 pos4,float value5,vec3 pos5) {

return center*(1.0-distance(truepos,poscenter))+value2*(1.0-distance(truepos,pos2))+value3*(1.0-distance(truepos,pos3))+value4*(1.0-distance(truepos,pos4))+value5*(1.0-distance(truepos,pos5));
}

const float PI = 3.1415927;

#ifdef WATER_REFRACT

float waterH(vec3 posxz) {

	float wave = 0.0;


	float factor = 2.0;
	float amplitude = 0.2;
	float speed = 5.0;
	float size = 0.6;

	float px = posxz.x/50.0 + 250.0;
	float py = posxz.z/50.0  + 250.0;

	float fpx = abs(fract(px*20.0)-0.5)*2.0;
	float fpy = abs(fract(py*20.0)-0.5)*2.0;

	float d = length(vec2(fpx,fpy));

	for (int i = 1; i < 4; i++) {
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
	for (int i = 1; i < 4; i++) {
		wave2 -= d*factor*cos( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
		factor /= 2;
	}

	return amplitude*wave2+amplitude*wave;
	}

#endif

//CLOUDS//
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
    	f += 0.50000*noise( p ); p = p*2.02*1.1;
    	f += 0.25000*noise( p ); p = p*2.03*1.1;
    	f += 0.12500*noise( p ); p = p*2.01*1.1;
    	f += 0.06250*noise( p ); p = p*2.04*1.1;
    	f += 0.03125*noise( p );
    	return f/0.984375;
	}

	float mat(float n) { return fract(sin(n)*43758.5453); }

	
	float getAlphafbm(vec4 fragpos, float x, float y) {

	vec4 wrldpos = gbufferModelViewInverse * fragpos / far * 290.0;

	float common = (wrldpos.y + length(wrldpos.y))/90, t = frameTimeCounter;  

	vec2 wind = vec2(1+t, 4+t)/(0.85*3+2.0), camPos = (wrldpos.xz / wrldpos.y);
	vec2 pos = -1+4*(camPos + wind/y); float f = 0.20;
	
	vec2 p = (0.5*pos); pos /= x/y;
	
	f += 0.50*noise			( p ); p = p*2.002;
   	f += 0.25*noise			( p ); p = p*2.003; 
	f += 0.125*noise		( p ); p = p*2.001;  
	f += 0.0625*noise		( p ); p = p*2.004;
	f += 0.03125*noise		( p ); p = p*2.005; 
	f += 0.015625*noise     ( p ); p = p*2.006; 
	f += 0.0078125*noise	( p ); p = p*2.008;
	f += 0.00390625*noise   ( p ); p = p*2.007;
	f /= 0.984375; 
	float tex = f, b = 0.575, c = tex - (b+0.175);
	if(c <= 0) c = 0; tex = ((1.0 - pow(b, c))*common);

    return tex*(1-rainStrength);
}

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
	float shading = 1.0f;
	float spec = 0.0;
	float time = float(worldTime);
	float transition_fading = 1.0-(clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-13000.0)/300.0,0.0,1.0) + clamp((time-22800.0)/200.0,0.0,1.0)-clamp((time-23400.0)/200.0,0.0,1.0));	//fading between sun/moon shadows
	float night = clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-22800.0)/200.0,0.0,1.0);
	
	if (land > 0.9 && isEyeInWater < 0.1) {


		float dist = length(fragposition.xyz);

		float shadingsharp = 0.0f;

	
		vec4 worldposition = vec4(0.0);
		vec4 worldpositionraw = vec4(0.0);
	
		worldposition = gbufferModelViewInverse * fragposition;	
	
		float xzDistanceSquared = worldposition.x * worldposition.x + worldposition.z * worldposition.z;
		float yDistanceSquared  = worldposition.y * worldposition.y;
	
		worldpositionraw = worldposition;

		#ifdef WATER_REFRACT

		if (iswater > 0.9) {
		
		vec3 underwaterpos = vec3(texcoord.st, texture2D(depthtex1, texcoord.st).r);
		underwaterpos = nvec3(gbufferProjectionInverse * nvec4(underwaterpos * 4.0 - 4.0));
		vec4 worldpositionuw = gbufferModelViewInverse * vec4(underwaterpos,4.0);	
		vec3 wpos = worldpositionuw.xyz + cameraPosition.xyz;
			
		vec3 watercolor = vec3(1.0);
		float watersunlight = 0.0f;
	
		vec3 posxz = worldposition.xyz + cameraPosition.xyz;
			
		float deltaPos = 0.075;
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
	
	#ifdef UNDERWATER_FOG
	
		vec3 Ufogcolor= normalize(vec3(0.0,0.2,0.5));
		vec3 uPos  = nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord.xy,texture2D(depthtex1,texcoord.xy).x) * 2.0 - 1.0));  //underwater position
		vec3 uVec = fragposition.xyz-uPos;
		float UNdotUP = abs(dot(normalize(uVec),normal));
		float depth = length(uVec)*UNdotUP+0.5;
		if (iswater > 0.9) color = mix(Ufogcolor*length(ambient_color)*0.04*sky_lightmap,color,exp(-depth/3.0));
		
	#endif
	
	
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
	
		if (dist < shadowDistance) {
			
			
			if (shadowexit > 0.1) {
				shading = 1.0;
			}
			
			else {
			#ifdef SHADOW_FILTER
				for(int i = 0; i < 25; i++){
					shadingsharp += (clamp(comparedepth - (0.05 + (texture2D(shadow, worldposition.st + circle_offsets[i]*step).z) * (256.0 - 0.05)), 0.0, diffthresh)/(diffthresh));
				}
				shadingsharp /= 25.0;
				shading = 1.0-shadingsharp;
				isshadow = 1.0;
			#endif
			
			#ifndef SHADOW_FILTER
				shading = 1.0-(clamp(comparedepth - (0.05 + (texture2D(shadow, worldposition.st).z) * (256.0 - 0.05)), 0.0, diffthresh)/(diffthresh));
			#endif
			}
			
		}
	
	float ao = 1.0;
	
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
	
		sss += pow(max(dot(npos, lightVector),0.0),20.0)*sss_transparency*clamp(-NdotL,0.0,1.0)*translucent*4.0;

	
	
		sss = mix(0.0,sss,sss_fade);
		shading = clamp(shading,0.0,1.0);
 
		
		//Apply different lightmaps to image

		vec3 ambientColor_sunrise = vec3(0.7, 1.0, 1.27) * TimeSunrise * (1.0- rainStrength * 1.0); 
	    vec3 ambientColor_noon = vec3(0.7, 1.0, 1.27) * TimeNoon * (1.0- rainStrength * 1.0);
	    vec3 ambientColor_sunset = vec3(0.7, 1.1, 1.27) * TimeSunset * (1.0- rainStrength * 1.0);
	    vec3 ambientColor_midnight = vec3(0.03, 0.15, 0.30) * TimeMidnight * (1.0- rainStrength * 1.0);
		vec3 ambientColor_rain_day = vec3(2.22, 2.22, 2.22)  * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength;
        vec3 ambientColor_rain_night = vec3(0.1, 0.2, 0.30) * TimeMidnight * rainStrength;
		
	    vec3 ambient_color = ambientColor_sunrise + ambientColor_noon + ambientColor_sunset + ambientColor_midnight + ambientColor_rain_day + ambientColor_rain_night;
		
	    vec3 suncolor_sunrise = vec3(2.52, 1.2, 0.0) * TimeSunrise * (1.0 - rainStrength * 1.0);
	    vec3 suncolor_noon = vec3(2.52, 2.25, 2.0) * TimeNoon * (1.0 - rainStrength * 1.0);
	    vec3 suncolor_sunset = vec3(2.52, 1.2, 0.0) * TimeSunset * (1.0 - rainStrength * 1.0);
		vec3 suncolor_midnight = vec3(0.3, 0.7, 1.3) * 0.05 * TimeMidnight * (1.0 - rainStrength * 1.0);
	    vec3 suncolor_rain_day = vec3(0.8, 0.9, 1.0) * 0.3 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength;
	
	    vec3 suncolor = suncolor_sunrise + suncolor_noon + suncolor_sunset + suncolor_midnight;
		
		vec3 sunlightColor_sunrise = vec3(2.50, 0.6, 0.2) * 0.5 * TimeSunrise;
		vec3 sunlightColor_noon = vec3(2.30, 1.6, 1.0) * TimeNoon;
		vec3 sunlightColor_sunset = vec3(2.30, 0.8, 0.2) * 0.5 * TimeSunset;
		vec3 sunlightColor_midnight = vec3(0.05, 0.1, 0.3) * 0.7 * TimeMidnight;
		
		vec3 sunlight_color = sunlightColor_sunrise + sunlightColor_noon + sunlightColor_sunset + sunlightColor_midnight;
		
	
		vec3 Sunlight_lightmap = sunlight_color*mix(max(sky_lightmap-rainStrength*1.0,0.0),shading*(1.0-rainStrength*1.0),shadow_fade)*SUNLIGHTAMOUNT *sunlight_direct*transition_fading ;
		
		
		float sky_inc = sqrt(direct*0.5+0.51);
		vec3 amb = (sky_inc*ambient_color+(1.0-sky_inc)*(sunlight_color+ambient_color*2.0)*vec3(0.2,0.24,0.27))*vec3(0.8,0.8,1.0);

		float MIN_LIGHT = 0.0005f;
		
		vec3 Torchlight_lightmap = (torch_lightmap+handlight*pow(max(10.0-length(fragposition.xyz),0.0)/10.0,5.0)*max(dot(-fragposition.xyz,normal),0.0)) *  torchcolor;
		
		vec3 color_sunlight = Sunlight_lightmap;
		vec3 color_torchlight = Torchlight_lightmap;
		
		//Add all light elements together
		color = (amb*SHADOW_DARKNESS*sky_lightmap*ao + MIN_LIGHT*ao + color_sunlight + color_torchlight*ao  +  sss * sunlight_color * shading *(1.0-rainStrength*0.9)*transition_fading)*color;
		//color = color_torchlight*ao;

	}
	
	else if (isEyeInWater < 0.1){
	
        vec3 Gray = vec3(0.3, 0.3, 0.3);

		vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
	    fragposition /= fragposition.w;
	
	    vec4 worldposition = vec4(0.0);
	    worldposition = gbufferModelViewInverse * fragposition / far * 128.0;
		
        float horizont = abs(worldposition.y - texcoord.y);
		float skycolor_position = clamp(max(pow(max(1.0 - horizont/(25.0*100.0),0.01),8.0)-0.1,0.0), 0.25, 1.0);
		float horizont_position = max(pow(max(1.0 - horizont/(30.0*100.0),0.01),8.0)-0.1,0.0);
		
		//Sky colors.
	    vec3 skycolor_sunrise = vec3(0.9, 0.5, 1.0) * 0.95 * (1.0-rainStrength*1.0) * TimeSunrise;
	    vec3 skycolor_noon = vec3(0.25,0.3,0.9) * (1.0-rainStrength*1.0) * TimeNoon;
	    vec3 skycolor_sunset = vec3(0.3, 0.5, 1.0) * (1.0-rainStrength*1.0) * TimeSunset;
		vec3 skycolor_night = vec3(0.15, 0.6, 1.3) * TimeMidnight;
		vec3 skycolor_rain_day = vec3(4.2, 4.2, 4.5)* (TimeSunrise + TimeNoon + TimeSunset) * rainStrength;
		vec3 skycolor_rain_night = vec3 (0.15, 0.5, 1.3) * TimeMidnight * rainStrength;
		color.rgb *= (skycolor_sunrise + skycolor_noon + skycolor_sunset + skycolor_night + skycolor_rain_day + skycolor_rain_night) * skycolor_position;
		
		float Better_sun = max(dot(normalize(fragpos),lightVector),0.0);
		color.rgb += pow(Better_sun,500.0)*10.0*((vec3(1.5,1.5,1.5)-rainStrength)-TimeMidnight)*transition_fading;

		//Color for the Clouds
		vec3 CLOUDCOLOR_Day		 = vec3(0.1, 0.1, 0.1) * (TimeSunrise + TimeNoon + TimeSunset) * (1.0-rainStrength*1.0);
		vec3 CLOUDCOLOR_Midnight = vec3(0.15, 0.6, 1.3) * 0.01 * TimeMidnight * (1.0-rainStrength*1.0);
		vec3 CLOUDCOLOR_Rain_day = vec3(1.0, 1.0, 1.0) * 0.5 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength;
		
		vec3 CLOUDCOLOR = CLOUDCOLOR_Day + CLOUDCOLOR_Midnight + CLOUDCOLOR_Rain_day;
	
		if (land < 0.1) {
		color.rgb += (CLOUDCOLOR * getAlphafbm(fragposition, 1002, 10.1));
		color.rgb += (CLOUDCOLOR * getAlphafbm(fragposition, 1008, 16.1));
		}
	
	}
	
	#ifdef FOG
		
		float fog 			= clamp(exp(-length(fragpos)/92.0*(5.0+rainStrength)/5.4)+0.25*(1.0-rainStrength),0.0,1.0);
		
		vec3 fogclr_day 	 	= vec3(0.6, 0.85, 1.27) * 0.5 * (TimeSunrise + TimeNoon + TimeSunset) * (1.0-rainStrength*1.0);
	    vec3 fogclr_midnight 	= vec3(0.2, 0.6, 1.3) * 0.06 * TimeMidnight * (1.0-rainStrength*1.0);
	    vec3 fogclr_rain_day 	= vec3(1.5, 1.9 ,2.55) * 0.3 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength;
	    vec3 fogclr_rain_night  = vec3(0.2, 0.5, 1.3) * 0.06  * TimeMidnight * rainStrength;
		
	    vec3 fogclr	= fogclr_day + fogclr_midnight + fogclr_rain_day + fogclr_rain_night;
		
		float fogfactor =  clamp(fog,0.0,1.0);
		fogclr = mix(fogclr,color.rgb,(1.0-rainStrength)*0.7);
		color.rgb = mix(fogclr,color.rgb,fogfactor);
		
	#endif
	
/* DRAWBUFFERS:31 */

	spec =  ctorspec(fragposition.xyz,lightVector,normalize(normal)) * iswater * (1.0-isEyeInWater) * shading * (1.0-night*0.75)*0.05;
#ifdef CELSHADING
	if (land > 0.9 && iswater < 0.9) color = celshade(color);
#endif


	
	
	#ifdef GODRAYS
		
		vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
		tpos = vec4(tpos.xyz/tpos.w,1.0);
		vec2 pos1 = tpos.xy/tpos.z;
		vec2 lightPos = pos1*0.5+0.5;
		
		const float density = 0.9;			
		const int NUM_SAMPLES = 10;
		const float grnoise = 0.00;	
	
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
	gl_FragData[0] = vec4(color, spec);
	gl_FragData[1] = vec4(vec3((gr/NUM_SAMPLES)),1.0);
}
