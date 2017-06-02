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

	#define Godrays											//Rays from sun and moon.
		const float Godrays_Full = 0;
		const float exposure = 8.0;							
		const float density = 1;			
		const int NUM_SAMPLES = 8;							
		const float raysize = 2;
	
	//#define RoundSunMoon									//Disable vanila sky to use this effectively.
	
	//#define Sky_Nether									//Use this while you're in the nether.
	//#define Sky_End										//Use this while you're in the end.
	#define Sky_FogRange 128								//you can't disable this.
	
	//#define Specular										//You need specular resource pack.
		//#define ReflectSpecular							//Reflection visible when it's raining.
		#define Specular_Strength 16
	
	#define ReflectWater			
		#define ReflectWater_Strength 1.0
		
	//#define Celshade										//Comic book-ish shading. Doesn't affect vanila smooth lighting.
		const float Celshade_Out = 1;						//Cel shading technique. Can enable both.
		const float Celshade_In = 0;						//Cel shading technique. Can enable both.
		const float BORDERC = 2;
		const float CEL_RANGE = 100;
		
	//#define BumpEdge
		#define BORDERE 2.0
		#define EDGESTR 0.25
		
	#define Cloud_v3
		#define CLOUD_SPEED 1.0
		#define CLOUD_PASS 4
		#define CLOUD_DISTANCE 45
		#define CLOUD_HEIGHT 4
		#define CLOUD_VOLUME 0.1
		#define CLOUD_DENSITY 0.5
	#define Sky_Stars

//ADJUSTABLE VARIABLES//


//don't touch these lines if you don't know what you do!
const int maxf = 4;				//number of refinements
const float stp = 1.2;			//size of one step for raytracing algorithm
const float ref = 0.1;			//refinement multiplier
const float inc = 2.2;			//increasement factor at each step

//ground constants (lower quality)
const int Gmaxf = 3;				//number of refinements
const float Gstp = 1.2;			//size of one step for raytracing algorithm
const float Gref = 0.11;			//refinement multiplier
const float Ginc = 3.0;			//increasement factor at each step

varying vec4 texcoord;

varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying vec3 sunlight;
varying vec3 moonlight;
varying vec3 ambient_color;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

varying float eyeAdapt;

varying float SdotU;
varying float MdotU;
varying float sunVisibility;
varying float moonVisibility;

uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux3;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D gnormal;
uniform sampler2D gdepth;
uniform sampler2D noisetex;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;
uniform vec3 skyColor;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform int isEyeInWater;
uniform int worldTime;
uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float frameTimeCounter;
uniform int fogMode;

float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;
float matflag = texture2D(gaux1,texcoord.xy).g;

vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);
vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;

float time = float(worldTime);
float transition_fading = (clamp((time-12000.0)/300.0,0.0,1.0)-clamp((time-13500.0)/300.0,0.0,1.0) + clamp((time-22500.0)/300.0,0.0,1.0)-clamp((time-23400.0)/300.0,0.0,1.0));	//fading between sun/moon shadows
float night = clamp((time-13000.0)/300.0,0.0,1.0)-clamp((time-21500.0)/300.0,0.0,1.0);

float sky_lightmap = texture2D(gaux1,texcoord.xy).r;
float torch_lightmap = texture2D(gaux1,texcoord.xy).b;
	
vec4 color = texture2D(composite,texcoord.xy);
#ifdef Specular
vec3 specular = pow(texture2D(gaux3,texcoord.xy).rgb,vec3(2.2));
#endif

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*2.0;
}

float edepth(vec2 coord) {
	return texture2D(depthtex0,coord).z;
}

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

#ifdef BumpEdge
float getdist(float rng) {
	return 1-clamp(ld(texture2D(depthtex0,texcoord.xy).r)/rng*far,0,1);
}
vec3 edgeshadow(vec3 clrr,float str) {
	//edge detect
	float d = edepth(texcoord.xy);
	float dtresh = 1/(far-near)/120.0;	
	vec4 dc = vec4(d,d,d,d);
	vec4 sa;
	vec4 sb;
	float dist = (getdist(64)+1)/2;
	float bord = floor(BORDERE*viewWidth/1280) * dist;
	sa.x = edepth(texcoord.xy + vec2(-pw,-ph)*bord);
	sa.y = edepth(texcoord.xy + vec2(pw,-ph)*bord);
	sa.z = edepth(texcoord.xy + vec2(-pw,0.0)*bord);
	sa.w = edepth(texcoord.xy + vec2(0.0,ph)*bord);
	
	//opposite side samples
	sb.x = edepth(texcoord.xy + vec2(pw,ph)*bord);
	sb.y = edepth(texcoord.xy + vec2(-pw,ph)*bord);
	sb.z = edepth(texcoord.xy + vec2(pw,0.0)*bord);
	sb.w = edepth(texcoord.xy + vec2(0.0,-ph)*bord);
	
	vec4 dd = (2.0* dc - sa - sb) - dtresh;
	dd = vec4(step(dd.x,0.0),step(dd.y,0.0),step(dd.z,0.0),step(dd.w,0.0));
	
	float e = (clamp(dot(dd,vec4(0.25f,0.25f,0.25f,0.25f)),0.0,1.0));
	return clrr*(1-str)+clrr*e*str;
}
vec3 edgerim(vec3 clrr,float str) {
	//edge detect
	float d = edepth(texcoord.xy);
	float dtresh = 1/(far-near)/120.0;	
	vec4 dc = vec4(d,d,d,d);
	vec4 sa;
	vec4 sb;
	float dist = (getdist(64)+1)/2;
	float bord = floor(BORDERE*viewWidth/1280) * dist;
	sa.x = edepth(texcoord.xy + vec2(-pw,-ph)*bord);
	sa.y = edepth(texcoord.xy + vec2(pw,-ph)*bord);
	sa.z = edepth(texcoord.xy + vec2(-pw,0.0)*bord);
	sa.w = edepth(texcoord.xy + vec2(0.0,ph)*bord);
	
	//opposite side samples
	sb.x = edepth(texcoord.xy + vec2(pw,ph)*bord);
	sb.y = edepth(texcoord.xy + vec2(-pw,ph)*bord);
	sb.z = edepth(texcoord.xy + vec2(pw,0.0)*bord);
	sb.w = edepth(texcoord.xy + vec2(0.0,-ph)*bord);
	
	vec4 dd = abs(2.0* dc - sa - sb) - (2.0* dc - sa - sb) - dtresh;
	dd = vec4(step(dd.x,0.0),step(dd.y,0.0),step(dd.z,0.0),step(dd.w,0.0));
	
	float e = (clamp(dot(dd,vec4(0.25f,0.25f,0.25f,0.25f)),0.0,1.0));
	return clrr*(1-e)*str;
}
#endif

vec3 getSkyColor(vec3 fposition) {
//sky gradient
/*----------*/
vec3 sky_color = vec3(0.1, 0.35, 1.);
vec3 nsunlight = normalize(pow(sunlight,vec3(2.2)))*(1-dot(normalize(fposition),upVec)+skyColor*dot(normalize(fposition),upVec));
vec3 sVector = normalize(fposition);

sky_color = normalize(mix(sky_color,vec3(0.25,0.3,0.4)*length(ambient_color),rainStrength)); //normalize colors in order to don't change luminance

float Lz = 1.0;
float cosT = dot(sVector,upVec); 
float absCosT = max(cosT,0.0);
float cosS = dot(sunVec,upVec);
float S = acos(cosS);				
float cosY = dot(sunVec,sVector);
float Y = acos(cosY);	
float timebrightness = abs(sin(time/12000*22/7));

float a = -1.;
float b = -0.4+0.2*timebrightness+0.1*transition_fading;
float c = 1.0+timebrightness+transition_fading*3;
float d = -0.6;
float e = 0.45;			

//sun sky color
float sidefog = pow(clamp(1-abs(cosT),0,0.9),3);
float L = (1+a*exp(b/(absCosT+0.01)))*(1+c*exp(d*Y)+e*cosY*cosY) + sidefog*(1-transition_fading);
L = pow(L,1.0-rainStrength*0.8)*(1.0-rainStrength*0.2); //modulate intensity when raining
vec3 skyColorSun = mix(sky_color, nsunlight,1-exp(-0.005*pow(L,4.)*(1-rainStrength*0.5)))*(L*(1-cosY*cosY/2*transition_fading))*0.5*vec3(0.8,0.9,1.); //affect color based on luminance (0% physically accurate)
skyColorSun *= sunVisibility * (1-transition_fading*0.2);

//moon sky color
float McosS = MdotU;
float MS = acos(McosS);
float McosY = dot(moonVec,sVector);
float MY = acos(McosY);

float L2 = (1+a*exp(b/(absCosT+0.01)))*(1+c*exp(d*MY)+e*McosY*McosY)+0.2;
L2 = pow(L2,1.0-rainStrength*0.8)*(1.0-rainStrength*0.2); //modulate intensity when raining
vec3 skyColormoon = mix(moonlight,normalize(vec3(0.25,0.3,0.4))*length(moonlight),rainStrength*0.8)*L2*0.8 ; //affect color based on luminance (0% physically accurate)
skyColormoon *= moonVisibility;

sky_color = min(vec3(1),skyColormoon*2.0+skyColorSun);
//sky_color = vec3(Lc);
/*----------*/

#ifdef Sky_Nether
sky_color = vec3(0.01,0,0);
#endif
#ifdef Sky_End
sky_color = vec3(0.005,0,0.005);
#endif
return sky_color;
}


vec3 drawSun(vec3 fposition,vec3 color,int land) {
vec3 sVector = normalize(fposition);

float angle = (1-max(dot(sVector,sunVec),0.0))*700.0;
float sun = exp(-angle*angle);
sun *= land*(1-rainStrength)*clamp(sunVisibility+transition_fading*(1-rainStrength)/2,0,1);
sun = clamp(sun*sun*sun*sun,0,1)+sun/10;

float angle1 = (1-max(dot(sVector,sunVec),0.0))*400.0;
float sun1 = exp(-angle1*angle1);
sun1 *= land*(1-rainStrength)*sunVisibility;
sun1 = clamp(sun1*sun1*sun1*sun1,0,1)+sun1/10;
sun1 *= texture2D(noisetex,texcoord.xy/128+vec2(frameTimeCounter)/2000).r/4;

vec3 sunlight = vec3(0.4,0.2,0.05)*(2-transition_fading)/2;

return mix(color,sunlight*200.,sun+sun1);

}

vec3 drawMoon(vec3 fposition,vec3 color,int land) {
vec3 sVector = normalize(fposition);

float angle = (1-max(dot(sVector,moonVec),0.0))*400.0;
float moon = exp(-angle*angle);
moon *= land*(1-rainStrength)*clamp(moonVisibility+transition_fading*(1-rainStrength)/2,0,1);
moon = clamp(moon*moon*moon*moon,0,1)+moon/10;
vec3 moonlight = vec3(0.3,0.4,0.5)*(2-transition_fading)/2;

return mix(color,moonlight*20.,moon);

}



vec3 calcFog(vec3 fposition, vec3 color, vec3 fogclr) {
	float density = Sky_FogRange*240/eyeBrightnessSmooth.y;
	const float start = 0.5;
	float rainFog = 1.0;
	float fog = min(exp(-length(fposition)/density)+start*(1-rainStrength),1.0);
	
	vec3 fc = fogclr*1.5;
	return mix(fc,color,fog);
}
vec3 calcSkyFog(vec3 fposition, vec3 color, vec3 fogclr) {
	float density = 2000.0 + 1000.0 * rainStrength;
	const float start = 0.02;
	float rainFog = 1.0+rainStrength;
	float fog = min(exp(-length(fposition)/density/(sunVisibility*0.7+0.3)*rainFog)+start*sunVisibility*(1-rainStrength),1.0);
	
	vec3 fc = fogclr*1.5;
	return mix(fc,color,fog);
}
	

float subSurfaceScattering(vec3 vec,vec3 pos, float N) {

return pow(max(dot(vec,normalize(pos)),0.0),N)*(N+1)/6.28;

}
vec3 drawCloudv3(vec3 fposition,vec3 color) {
vec3 sVector = normalize(fposition);
float cosT = dot(sVector,upVec);
float McosY = MdotU;
float cosY = SdotU;

float totalcloud = 0;

float pi = 3.1415927;

//cloud generation

vec3 tpos = vec3(gbufferModelViewInverse * vec4(fposition,1.0));
vec3 wvec = normalize(tpos);
vec3 wVector = normalize(tpos);

float N = 8.0;
vec3 cloud_color = (sunlight*sunVisibility+moonlight*2)*8*(8-rainStrength*(7+sunVisibility/2))/8;

for (int i = 0; i < CLOUD_PASS; i++) {
	vec3 intersection = wVector*((CLOUD_DISTANCE+i*CLOUD_HEIGHT/CLOUD_PASS)/(wVector.y));
	vec2 wind = vec2(frameTimeCounter*(cos(frameTimeCounter/1000.0)+0.5),frameTimeCounter*(sin(frameTimeCounter/8000.0)+0.5))/4*CLOUD_SPEED;	
	vec3 wpos = tpos.xyz;
	vec2 coord1 = (intersection.xz+cosT*intersection.xz)/768.0/32+(cameraPosition.xz+wind*CLOUD_SPEED)/50000;
	vec2 coord = sin(coord1.yx);
	float noise = texture2D(noisetex,coord).x;
	
	float scale = 3;
	float mult = 1.0;
	float r = 3.;
	float tmult = 1.0;

	coord = fract(coord1/4.0);
	noise = texture2D(noisetex,coord).x;

	mult = 2.0;
	r = 2.5-rainStrength;
	tmult = 1.0;
	for (int i = 0; i < 4; i++) {
	coord *= scale;
	mult /= r;
	noise += texture2D(noisetex,coord+wind/8000/CLOUD_SPEED).x*mult;
	tmult += mult;
	}
	noise /= tmult;
	
	float cl = max((noise*(0.7+abs(cosT)/2)-((CLOUD_DENSITY*(1-rainStrength)+CLOUD_VOLUME/2)-cos(pi*i/CLOUD_PASS)*CLOUD_VOLUME))+rainStrength*0.3-sin(frameTimeCounter/3000.0)*0.1,0.0);
	float ef = 0.55;
 
    float cloud2 = (1.0 - (pow((1-rainStrength*0.1)*ef,cl)))*sqrt(max(cosT,0.0))/(2.5+rainStrength)*(1+moonVisibility);
	cloud2 *= sin(pi*i/CLOUD_PASS)*2;
	totalcloud += cloud2;
}
totalcloud /= CLOUD_PASS;
totalcloud *= 1-rainStrength*(1-rainStrength)*2;
totalcloud *= 2 - sunVisibility*moonVisibility;

vec3 c = mix(color,cloud_color,totalcloud);

return c;
}

vec3 drawStar(vec3 fposition,vec3 color) {

vec3 sVector = normalize(fposition);
float cosT = max(dot(normalize(sVector),upVec),0.0);
float McosY = MdotU;
float cosY = SdotU;
vec3 tpos = vec3(gbufferModelViewInverse * vec4(fposition,1.0));
vec3 wvec = normalize(tpos);
vec3 wVector = normalize(tpos);

vec4 totalcloud = vec4(.0);

vec3 intersection = wVector*((-cameraPosition.y+400.0+400*sqrt(cosT))/(wVector.y));
vec3 iSpos = (gbufferModelView*vec4(intersection,1.0)).rgb;
float cosT2 = max(dot(normalize(iSpos),upVec),0.0);
vec2 wind = vec2(abs(frameTimeCounter/1000.-0.5),abs(frameTimeCounter/1000.-0.5))+vec2(0.5);

	intersection = wVector*((-cameraPosition.y+300.0*3.66*(1+cosT2*cosT2*3.5)+500*sqrt(cosT2))/(wVector.y)); 			//curved cloud plane
	vec3 wpos = tpos.xyz+cameraPosition;
	vec2 coord1 = (intersection.xz+cameraPosition.xz)/1000.0/140.+wind*0.01;
	vec2 coord = fract(coord1);
	
	float noise = texture2D(noisetex,coord*4).x;
	noise += texture2D(noisetex,coord*8+vec2(250)).x;
	noise += texture2D(noisetex,coord*16+vec2(500)).x;
	noise += texture2D(noisetex,coord*32+vec2(750)).x;
	noise = clamp(noise*noise*noise-32,0,1);
	
	float starglow = texture2D(noisetex,coord+wind/4).x;
	starglow += texture2D(noisetex,coord/4-wind/4).x;
	starglow = clamp(starglow*starglow-1,0,1);

	totalcloud += vec4(moonlight*6*(1+starglow),noise);
	totalcloud.a = min(totalcloud.a,1.0);

totalcloud *= clamp(cosT*1.5,0,1)*2;
return mix(color.rgb,totalcloud.rgb*(1 - rainStrength*0.2)*4.6,totalcloud.a*pow(cosT2,1.2)*moonVisibility*(1-rainStrength)*(1-transition_fading));

}

vec4 raytrace(vec3 fragpos, vec3 normal,vec3 fogclr, vec3 sky_int) {
    vec4 color = vec4(0.0);
    vec3 start = fragpos;
    vec3 rvector = normalize(reflect(normalize(fragpos), normalize(normal)));
    vec3 vector = stp * rvector;
    vec3 oldpos = fragpos;
    fragpos += vector;
	vec3 tvector = vector;
    int sr = 0;
    for(int i=0;i<40;i++){
        vec3 pos = nvec3(gbufferProjection * nvec4(fragpos)) * 0.5 + 0.5;
        if(pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;
        vec3 spos = vec3(pos.st, texture2D(depthtex1, pos.st).r);
        spos = nvec3(gbufferProjectionInverse * nvec4(spos * 2.0 - 1.0));
        float err = abs(fragpos.z-spos.z);
if(err < pow(length(vector)*1.85,1.15)){
	
                sr++;
                if(sr >= maxf){
                    float border = clamp(1.0 - pow(cdist(pos.st), 20.0), 0.0, 1.0);
                    color = texture2D(composite, pos.st);
					float land = texture2D(gaux1, pos.st).g;
					land = float(land < 0.03);
					spos.z = mix(fragpos.z,2000.0*(0.4+clamp(sunVisibility+moonVisibility,0,1)*0.6),land);
					
					#ifdef Cloud_v3
					if (land > 0.0) color.rgb = drawCloudv3(sky_int,calcFog(spos,pow(color.rgb,vec3(2.2))*MAX_COLOR_RANGE,fogclr));
					else color.rgb = calcFog(spos,pow(color.rgb,vec3(2.2))*MAX_COLOR_RANGE,fogclr);
					#else
					color.rgb = calcFog(spos,pow(color.rgb,vec3(2.2))*MAX_COLOR_RANGE,fogclr);
					#endif

					color.a = 1.0;
                    color.a *= border;
                    break;
                }
				tvector -=vector;
                vector *=ref;
				
        
}
        vector *= inc;
        oldpos = fragpos;
        tvector += vector;
		fragpos = start + tvector;
    }
    return color;
}

vec4 raytraceGround(vec3 fragpos, vec3 normal, vec3 fogclr, vec3 sky_int) {
    vec4 color = vec4(0.0);
    vec3 start = fragpos;
    vec3 rvector = normalize(reflect(normalize(fragpos), normalize(normal)));
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
        if(err < length(vector)){

                sr++;
                if(sr >= maxf){
                    float border = clamp(1.0 - pow(cdist(pos.st), 20.0), 0.0, 1.0);
                    color = texture2D(composite, pos.st);
					float land = texture2D(gaux1, pos.st).g;
					land = float(matflag < 0.03);
					spos.z = mix(fragpos.z,2000.0*(0.25+sunVisibility*0.75),land);
					#ifdef Cloud_v3
					if (land > 0.0) color.rgb = drawCloudv3(sky_int,calcFog(spos,pow(color.rgb,vec3(2.2))*MAX_COLOR_RANGE,fogclr));
					else color.rgb = calcFog(spos,pow(color.rgb,vec3(2.2))*MAX_COLOR_RANGE,fogclr);
					#else
					color.rgb = calcFog(spos,pow(color.rgb,vec3(2.2))*MAX_COLOR_RANGE,fogclr);
					#endif
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

vec3 underwaterFog (float depth,vec3 color) {
	const float density = 256.0;
	float fog = exp(-depth/density);
	vec3 Ucolor= normalize(pow(vec3(0.1,0.4,0.6),vec3(2.2)))*(sqrt(3.0));
	
	vec3 c = mix(color*Ucolor,color,fog);
	vec3 fc = Ucolor*length(ambient_color)*0.05;
	return mix(fc,c,fog);
}
float waterH(vec3 posxz) {

float wave = 0.0;


float factor = 1.0;
float amplitude = 0.2;
float speed = 4.0;
float size = 0.2;

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

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	color.rgb = pow(color.rgb,vec3(2.2))*MAX_COLOR_RANGE;
	int land = int(matflag < 0.03);
	int iswater = int(matflag > 0.04 && matflag < 0.07);
	int islava = int(matflag > 0.62 && matflag < 0.65);
	int hand  = int(matflag > 0.75 && matflag < 0.85);
	
	fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));
	vec3 uPos  = nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord.xy,texture2D(depthtex1,texcoord.xy).x) * 2.0 - 1.0));		//underwater position
	float cosT = dot(normalize(fragpos),upVec);
	#ifdef Cloud_v3
	if (cosT > 0 && land > 0.9) color.rgb = drawCloudv3(fragpos.xyz,color.rgb);
	#endif
	#ifdef Sky_Stars
	if (cosT > 0 && land > 0.9) color.rgb = drawStar(fragpos.xyz,color.rgb);
	#endif
	#ifdef RoundSunMoon
	color.rgb = drawSun(fragpos,color.rgb,land);
	color.rgb = drawMoon(fragpos,color.rgb,land);
	#endif
	
	#ifdef Specular
	vec3 speccol = sunlight*sunVisibility + moonlight*50*moonVisibility;
	float specarea = color.a*color.a*specular.r*(1-rainStrength*0.9)*Specular_Strength;
	color.rgb += specarea*speccol;
	#endif
	
	vec3 fogclr = getSkyColor(fragpos.xyz);
	uPos.z = mix(uPos.z,2000.0*(0.25+sunVisibility*0.75),land);
		float normalDotEye = dot(normal, normalize(fragpos));
		float fresnel = pow(1.0 + normalDotEye, 5.0);
		fresnel = mix(1.,fresnel,0.98);
		

{		
	if (iswater > 0.9 && isEyeInWater == 0) {
		vec3 lc = mix(vec3(0.0),sunlight * vec3(1,0.8,0.5),sunVisibility)+mix(vec3(0.0),moonlight*90,moonVisibility);
		vec4 reflection_w = vec4(0.0);
		vec3 npos = normalize(fragpos);
		vec3 reflectedVector = reflect(normalize(fragpos), normalize(normal));
		reflectedVector = fragpos + reflectedVector * (2048.0-fragpos.z);
		vec3 skyc = getSkyColor(reflectedVector);
		vec3 sky_color = calcFog(reflectedVector,vec3(0),skyc)*clamp(sky_lightmap*2.0-2/16.0,0.0,1.0)*(vec3(.05,0.4,1)*fresnel+vec3(1)*(1-fresnel));
		#ifdef Cloud_v3
		sky_color = calcFog(reflectedVector,drawCloudv3(reflectedVector,vec3(0.0))*2,skyc)*clamp(sky_lightmap*2.0-2/16.0,0.0,1.0)*(vec3(.05,0.4,1)*fresnel+vec3(1)*(1-fresnel));
		#endif
		
		#ifdef ReflectWater
		reflection_w = raytrace(fragpos,normal,skyc,reflectedVector);
		#endif
		reflection_w.rgb = mix(sky_color, reflection_w.rgb, reflection_w.a)+(color.a)*lc*(1.0-rainStrength)*128.0;			//fake sky reflection_w, avoid empty spaces
		reflection_w.a = min(reflection_w.a,1.0);
		reflection_w.rgb = reflection_w.rgb*ReflectWater_Strength;
		color.rgb = fresnel*reflection_w.rgb + (1-fresnel)*color.rgb;
    }
	#ifdef ReflectSpecular
	if (land < 0.9 && isEyeInWater == 0 && rainStrength > 0) {
		vec3 lc = mix(vec3(0.0),sunlight * vec3(1,0.8,0.5),sunVisibility)+mix(vec3(0.0),moonlight*90,moonVisibility);
		vec4 reflection_s = vec4(0.0);
		vec3 npos = normalize(fragpos);
		vec3 reflectedVector = reflect(normalize(fragpos), normalize(normal));
		reflectedVector = fragpos + reflectedVector * (2048.0-fragpos.z);
		vec3 skyc = getSkyColor(reflectedVector);
		vec3 sky_color = calcFog(reflectedVector,vec3(0),skyc)*clamp(sky_lightmap*2.0-2/16.0,0.0,1.0)*(vec3(.05,0.4,1)*fresnel+vec3(1)*(1-fresnel));
		#ifdef Cloud_v3
		sky_color = calcFog(reflectedVector,drawCloudv3(reflectedVector,vec3(0.0))*2,skyc)*clamp(sky_lightmap*2.0-2/16.0,0.0,1.0)*(vec3(.05,0.4,1)*fresnel+vec3(1)*(1-fresnel));
		#endif
		
		reflection_s = raytraceGround(fragpos,normal,skyc,reflectedVector);
		reflection_s.rgb = mix(sky_color*(1-rainStrength)+ambient_color*rainStrength, reflection_s.rgb, reflection_s.a);			//fake sky reflection_s, avoid empty spaces
		reflection_s.a = min(reflection_s.a,1.0);
		reflection_s.rgb = reflection_s.rgb*ReflectWater_Strength;
		float specfresnel = fresnel*rainStrength*specular.g*clamp(sky_lightmap*15-14,0,0.1)*10;
		color.rgb = specfresnel*reflection_s.rgb + (1-specfresnel)*color.rgb;	
    }
	#endif
}

	if (hand < 0.1)
	{
	if (land < 0.1)
	{
	color.rgb = calcFog(uPos.xyz,color.rgb,fogclr);
	}
	else
	{
	color.rgb = calcSkyFog(uPos.xyz,color.rgb,fogclr);
	}
	}
	if (isEyeInWater == 1 && land < 0.9) color.rgb = underwaterFog(length(fragpos),color.rgb);
	
	#ifdef Celshade
	float celborder = ceil(BORDERC*viewWidth/1280);
	float cdepth = clamp(ld(texture2D(depthtex0,texcoord.xy).r)/256*far,0,1)*4;
	
	float cdepthmask = 0;
	cdepthmask += clamp(ld(texture2D(depthtex0,texcoord.xy+vec2(pw*celborder,0)).r)/256*far,0,1);
	cdepthmask += clamp(ld(texture2D(depthtex0,texcoord.xy+vec2(-pw*celborder,0)).r)/256*far,0,1);
	cdepthmask += clamp(ld(texture2D(depthtex0,texcoord.xy+vec2(0,ph*celborder)).r)/256*far,0,1);
	cdepthmask += clamp(ld(texture2D(depthtex0,texcoord.xy+vec2(0,-ph*celborder)).r)/256*far,0,1);
	
	if (Celshade_Out > 0.5){
	float cdeptho = cdepth-cdepthmask;
	cdeptho = clamp(cdeptho,0,1/CEL_RANGE)*CEL_RANGE;
	cdeptho *= exp(-length(fragpos.xyz)/200)*(1-land)+land;
	cdeptho = 1-cdeptho;
	if (iswater < 0.9) color.rgb = color.rgb*(isEyeInWater*0.7+cdeptho*(1-isEyeInWater*0.7)) + vec3(0.001);
	}
	
	if (Celshade_In > 0.5){
	float cdepthi = cdepthmask-cdepth;
	cdepthi = clamp(cdepthi,0,1/CEL_RANGE)*CEL_RANGE;
	cdepthi *= exp(-length(fragpos.xyz)/200)*(1-land)+land;
	cdepthi = 1-cdepthi;
	if (iswater < 0.9) color.rgb = color.rgb*(isEyeInWater*0.7+cdepthi*(1-isEyeInWater*0.7)) + vec3(0.001);
	}
	
	
	cdepth = clamp(ld(texture2D(depthtex0,texcoord.xy).r)/256*far,0,1)*4*iswater;
	
	cdepthmask = 0;
	
	float celwaterflag = texture2D(gaux1,texcoord.xy+vec2(pw*celborder,0)).g;
	int celwatermat = int(celwaterflag > 0.04 && celwaterflag < 0.07);
	cdepthmask += clamp(ld(texture2D(depthtex0,texcoord.xy+vec2(pw*celborder,0)).r)/256*far,0,1)*celwatermat;
	
	celwaterflag = texture2D(gaux1,texcoord.xy+vec2(-pw*celborder,0)).g;
	celwatermat = int(celwaterflag > 0.04 && celwaterflag < 0.07);
	cdepthmask += clamp(ld(texture2D(depthtex0,texcoord.xy+vec2(-pw*celborder,0)).r)/256*far,0,1)*celwatermat;
	
	celwaterflag = texture2D(gaux1,texcoord.xy+vec2(0,ph*celborder)).g;
	celwatermat = int(celwaterflag > 0.04 && celwaterflag < 0.07);
	cdepthmask += clamp(ld(texture2D(depthtex0,texcoord.xy+vec2(0,ph*celborder)).r)/256*far,0,1)*celwatermat;
	
	celwaterflag = texture2D(gaux1,texcoord.xy+vec2(0,-ph*celborder)).g;
	celwatermat = int(celwaterflag > 0.04 && celwaterflag < 0.07);
	cdepthmask += clamp(ld(texture2D(depthtex0,texcoord.xy+vec2(0,-ph*celborder)).r)/256*far,0,1)*celwatermat;
	
	cdepth = cdepthmask-cdepth;
	cdepth = clamp(cdepth,0,1/CEL_RANGE)*CEL_RANGE;
	cdepth *= exp(-length(fragpos.xyz)/200)*(1-land)+land;
	cdepth = (1-cdepth)*(1-iswater)+iswater;
	
	if (iswater < 0.9) color.rgb = color.rgb*(isEyeInWater*0.7+cdepth*(1-isEyeInWater*0.7)) + vec3(0.001);
	#endif
	
	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
	tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lightPos = pos1*0.5+0.5;
	float gr = 0.0;
	
#ifdef Godrays
	float truepos = sunPosition.z/abs(sunPosition.z);		//1 -> sun / -1 -> moon
	vec3 rainc = mix(vec3(1.),fogclr*1.5,rainStrength);
	float centerdist = (1-cdist(lightPos));
	vec3 lightColor = mix(sunlight*sunVisibility*rainc,20*moonlight*moonVisibility*rainc,(truepos+1.0)/2.)/2;
	const int nSteps = NUM_SAMPLES;
	const float blurScale = 0.002/nSteps*9.0;
	const int center = (nSteps-1)/2;
	vec3 blur = vec3(0.0);
	float tw = 0.0;
	const float sigma = 0.5;

	vec2 deltaTextCoord = normalize(texcoord.st - lightPos.xy)*blurScale;
	vec2 textCoord = texcoord.st - deltaTextCoord*center;
		
	float distx = texcoord.x*aspectRatio-lightPos.x*aspectRatio;
	float disty = texcoord.y-lightPos.y;
	float illuminationDecay = pow(max(1.0-sqrt((distx*distx)/raysize+(disty*disty)/raysize),0.0),2);
	if (Godrays_Full == 1) illuminationDecay = 0.5;
	/*-----------*/
		for(int i=0; i < nSteps ; i++) {
				textCoord += deltaTextCoord;
				
				float dist = (i-float(center))/center;
				float weight = exp(-(dist*dist)/(2.0*sigma));
				
				float sample = texture2D(gdepth, textCoord).r*weight;
				tw += weight;
				gr += sample;
		
		
		
	}
	vec3 grC = mix(lightColor,fogclr,rainStrength)*exposure*(gr/tw)*(1.0 - rainStrength*0.8)*illuminationDecay * (1-isEyeInWater) * (1+centerdist*3)/(8*(2-transition_fading+night));
	grC = clamp(grC,vec3(0),vec3(1));
	color.xyz = (1-(1-color.xyz/48.0)*(1-grC.xyz/48.0))*48.0;
	/*-----------*/
	
#endif
	
	float visiblesun = 0.0;
	float temp;
	float nb = 0;
	
//calculate sun occlusion (only on one pixel) 
if (texcoord.x < 3.0*pw && texcoord.x < 3.0*ph) {
	for (int i = 0; i < 10;i++) {
		for (int j = 0; j < 10 ;j++) {
		temp = texture2D(gaux1,lightPos + vec2(pw*(i-5.0)*10.0,ph*(j-5.0)*10.0)).g;
		visiblesun +=  1.0-float(temp > 0.04) ;
		nb += 1;
		}
	}
	visiblesun /= nb;

}

#ifdef BumpEdge
vec3 nobump = color.rgb;
float isbump = hand + land*(1-rainStrength);
float bumpfog = 1-(exp(-pow(ld(texture2D(depthtex0, texcoord.st).r)/4*far,4.0)*4.0));
float bumpfog2 = 1-(exp(-pow(ld(texture2D(depthtex0, texcoord.st).r)/128*far,4.0)*4.0));
bumpfog = clamp(bumpfog - bumpfog2 + isbump,0,1);
float bumpstr = EDGESTR;
#ifdef Godrays
bumpstr += (grC.r+grC.g+grC.b)/3;
#endif
if (iswater < 0.9 && islava < 0.9){
color.rgb = edgeshadow(color.rgb,bumpstr);
color.rgb = color.rgb + edgerim(color.rgb,bumpstr) * (1+torch_lightmap);
}

color.rgb = color.rgb*bumpfog + nobump.rgb*(1-bumpfog);
//color.rgb = color.rgb*0 + bumpfog;
#endif

	color.rgb = clamp(pow(color.rgb/MAX_COLOR_RANGE,vec3(1.0/2.2)),0.0,1.0);

/* DRAWBUFFERS:5 */
	gl_FragData[0] = vec4(color.rgb,visiblesun);
}