#version 120
#extension GL_ARB_shader_texture_lod : enable
#define MAX_COLOR_RANGE 48.0
/* DRAWBUFFERS:5 */
/*
  
*/

/*--------------------
//ADJUSTABLE VARIABLES//
---------------------*/


/*---------------------------
//END OF ADJUSTABLE VARIABLES//
----------------------------*/

//don't touch these lines if you don't know what you do!
const int maxf = 8;				//number of refinements
const float stp = 1.0;			//size of one step for raytracing algorithm
const float ref = 0.05;			//refinement multiplier
const float inc = 2.2;			//increasement factor at each step
/*--------------------------------*/
varying vec4 texcoord;

varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying vec3 sunlight;
varying vec3 moonlight;
varying vec3 ambient_color;

varying float SdotU;
varying float MdotU;
varying float sunVisibility;
varying float moonVisibility;

uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D gnormal;
uniform sampler2D noisetex;

uniform vec3 sunPosition;
uniform vec3 cameraPosition;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform int isEyeInWater;
uniform int worldTime;
uniform float far;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform ivec2 eyeBrightness;

//Calculate wind for Clouds
vec2 wind[4] = vec2[4](vec2(abs(frameTimeCounter/1500.-0.5),abs(frameTimeCounter/1500.-0.5))+vec2(0.5),
					vec2(-abs(frameTimeCounter/1500.-0.5),abs(frameTimeCounter/1500.-0.5)),
					vec2(-abs(frameTimeCounter/1500.-0.5),-abs(frameTimeCounter/1500.-0.5)),
					vec2(abs(frameTimeCounter/1500.-0.5),-abs(frameTimeCounter/1500.-0.5)));
/*--------------------------------*/
//For Sun occlusion check	
float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;
/*--------------------------------*/
float matflag = texture2D(gaux1,texcoord.xy).g;
vec3 fragpos = vec3(texcoord.st, texture2D(depthtex0, texcoord.st).r);
vec3 normal = texture2D(gnormal, texcoord.st).rgb * 2.0 - 1.0;
float time = float(worldTime);
float night = clamp((time-13000.0)/300.0,0.0,1.0)-clamp((time-22800.0)/200.0,0.0,1.0);
float sky_lightmap = texture2D(gaux1,texcoord.xy).r;	
vec4 color = texture2DLod(composite,texcoord.xy,0);

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}
vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}
float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*2.0;
}

vec3 getSkyColor(vec3 fposition) {
vec3 sky_color = vec3(0.1, 0.35, 1.);
vec3 nsunlight = normalize(pow(sunlight,vec3(2.2))*vec3(1.,0.9,0.8));
vec3 sVector = normalize(fposition);

sky_color = normalize(mix(sky_color,vec3(0.25,0.3,0.4)*length(ambient_color),rainStrength)); //normalize colors in order to don't change luminance

float cosT = dot(sVector,upVec); 
float absCosT = max(cosT,0.0);			
float cosY = dot(sunVec,sVector);
float Y = acos(cosY);	

float a = -1.;
float b = -0.24;
float c = 6.0;
float d = -0.8;
float e = 0.45;

//sun sky color
float L =  (1+a*exp(b/(absCosT+0.01)))*(1+c*exp(d*Y)+e*cosY*cosY); 
L = pow(L,1.0-rainStrength*0.8)*(1.0-rainStrength*0.83); //modulate intensity when raining
vec3 skyColorSun = mix(sky_color, nsunlight,1-exp(-0.005*pow(L,4.)*(1-rainStrength*0.5)))*L*0.5*vec3(0.8,0.9,1.); //affect color based on luminance (0% physically accurate)
skyColorSun *= sunVisibility;
/*--------------------------------*/

//moon sky color
float McosY = dot(moonVec,sVector);
float MY = acos(McosY);
float L2 =  (1+a*exp(b/(absCosT+0.01)))*(1+c*exp(d*MY)+e*McosY*McosY)+0.2;
L2 = pow(L2,1.0-rainStrength*0.8)*(1.0-rainStrength*0.15); //modulate intensity when raining
vec3 skyColormoon = mix(moonlight,normalize(vec3(0.25,0.3,0.4))*length(moonlight),rainStrength*0.8)*L2 ; //affect color based on luminance (0% physically accurate)
skyColormoon *= moonVisibility;
sky_color = skyColormoon+skyColorSun;
/*--------------------------------*/
return sky_color;
}

//Draw Sun
vec3 drawSun(vec3 fposition,vec3 color,int land) {
	vec3 sVector = normalize(fposition);
	float angle = (1-max(dot(sVector,sunVec),0.0))*350.0;
	float sun = exp(-angle*angle);
	sun *= land*(1-rainStrength*0.9925)*sunVisibility;
	vec3 sunlight = mix(sunlight,vec3(0.25,0.3,0.4)*length(ambient_color),rainStrength*0.8);
return mix(color,sunlight*16.,sun);
}/*--------------------------------*/

//Fog etc.
vec3 skyGradient (vec3 fposition, vec3 color, vec3 fogclr) {
	return (fogclr*3.+color)/4.;
}

float getAirDensity (float h) {
return (max((h),60.0)-40.0)/2;
}

vec3 calcFog(vec3 fposition, vec3 color, vec3 fogclr) {
	float NormalizeCaveFog = (eyeBrightness.y / 255.0);
	float RainFog = rainStrength*NormalizeCaveFog;	
	vec3 caveFog = vec3(0.10f,0.10f,0.11f);
	
	float density = (3500.0 -RainFog*2250);	
	if(NormalizeCaveFog < 0.1)density = 2000.0;
	
	vec3 worldpos = (gbufferModelViewInverse*vec4(fposition,1.0)).rgb+cameraPosition;
	float d = length(fposition);
	float height = mix(getAirDensity (worldpos.y),0.1,RainFog*0.8);
	
	float fog = clamp(20.0*exp(-getAirDensity (cameraPosition.y)/density) * (1.0-exp( -d*height/density ))/height-0.3+RainFog*0.25,0.0,1.0);

	if(NormalizeCaveFog < 0.1)return mix(color,caveFog/2.0,fog);
	else if(night*rainStrength > 0.1)return mix(color,caveFog/32.0,fog);
	else return mix(color,normalize(fogclr)*mix(pow(length(fogclr),0.33)*vec3(0.35,0.4,0.5),pow(length(fogclr),0.1)*vec3(0.05),max(moonVisibility*(1-sunVisibility),rainStrength)),fog);	
}

vec3 underwaterFog (float depth,vec3 color) {
	const float density = 48.0;
	float fog = exp(-depth/density);

	vec3 Ucolor= normalize(pow(vec3(0.1,0.4,0.6),vec3(2.2)))*(sqrt(3.0));

	vec3 c = mix(color*Ucolor,color,fog);
	vec3 fc = Ucolor*length(ambient_color)*0.02;
	return mix(fc,c,fog);
}/*--------------------------------*/

//Sub-Surface-Scattering
float subSurfaceScattering(vec3 vec,vec3 pos, float N) {
return pow(max(dot(vec,normalize(pos)),0.0),N)*(N+1)/6.28;
}

float subSurfaceScattering2(vec3 vec,vec3 pos, float N) {
return pow(max(dot(vec,normalize(pos))*0.5+0.5,0.0),N)*(N+1)/6.28;
}/*--------------------------------*/

//Clouds
float CloudSightFix;	
vec3 drawCloud(vec3 fposition,vec3 color) {
vec3 tpos = vec3(gbufferModelViewInverse * vec4(fposition,1.0));
vec3 wVector = normalize(tpos);

vec4 totalcloud = vec4(0.0);

vec3 intersection = wVector*((-400.0)/(wVector.y));
float cosT2 = pow(0.89,distance(vec2(0.0),intersection.xz)/100);

for (int i = 0;i<16;i++) {
	intersection = wVector*((-cameraPosition.y+500.0-i*3.*(1+cosT2*cosT2*3.5)+400*sqrt(cosT2))/(wVector.y)); 			//curved cloud plane
	vec2 coord1 = (intersection.xz+cameraPosition.xz)/1000.0/180.+wind[0]*0.07;
	vec2 coord = fract(coord1/2.0);

	vec2 distortion = wind[0] * 0.07;
	float noise = texture2D(noisetex,coord + distortion).x;
	noise += texture2D(noisetex,coord*3.5 + distortion).x/3.5;
	noise += texture2D(noisetex,coord*12.25 + distortion).x/12.25;
	noise += texture2D(noisetex,coord*42.87 + distortion).x/42.87;	
	noise /= 1.4472;

	float cl = max(noise-0.55  +rainStrength*0.4,0.0)*(1-rainStrength*0.4);
	float density = max(1-cl*2.5,0.)*max(1-cl*2.5,0.)*(i/16.)*(i/16.);

	vec3 c =(ambient_color + mix(sunlight,length(sunlight)*vec3(0.25,0.32,0.4),rainStrength)*sunVisibility + mix(moonlight,length(moonlight)*vec3(0.25,0.32,0.4),rainStrength) * moonVisibility) * 0.12 *density + (24.*subSurfaceScattering(sunVec,fragpos,10.0)*pow(density,3.) + 10.*subSurfaceScattering2(sunVec,fragpos,0.1)*pow(density,2.))*mix(sunlight,length(sunlight)*vec3(0.25,0.32,0.4),rainStrength)*sunVisibility +  (24.*subSurfaceScattering(moonVec,fragpos,10.0)*pow(density,3.) + 10.*subSurfaceScattering2(moonVec,fragpos,0.1)*pow(density,2.))*mix(moonlight,length(moonlight)*vec3(0.25,0.32,0.4),rainStrength)*moonVisibility;
	cl = max(cl-(abs(i-8.0)/8.)*0.15,0.)*CloudSightFix;

	totalcloud += vec4(c.rgb*exp(-totalcloud.a),cl);
	totalcloud.a = min(totalcloud.a,1.0);

	if (totalcloud.a > 0.999) break;
}
return mix(color.rgb,totalcloud.rgb*(1 - rainStrength*0.87)*2.5,totalcloud.a*pow(cosT2,1.2));
}/*--------------------------------*/

vec4 raytrace(vec3 fragpos, vec3 normal,vec3 fogclr,vec3 sky_int) {
    vec4 color = vec4(0.0);
    vec3 start = fragpos;
    vec3 rvector = normalize(reflect(normalize(fragpos), normalize(normal)));
	
	//far black dots fix
	vec4 wrv = (gbufferModelViewInverse*vec4(rvector,1.0));
	wrv.y *= sign(dot(upVec,rvector));
	rvector = normalize((gbufferModelView*wrv).rgb);
	
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
		if(err < pow(length(vector)*2.0,1.15)){
                sr++;
                if(sr >= maxf){
                    float border = clamp(1.0 - pow(cdist(pos.st), 20.0), 0.0, 1.0);
                    color = texture2DLod(composite, pos.st,0);
					float land = texture2D(gaux1, pos.st).g;
					land = float(land < 0.03);
					
					spos.z = mix(spos.z,2000.0*(0.25+sunVisibility*0.75),land);
					if (land > 0.0) color.rgb = skyGradient(spos,pow(color.rgb,vec3(2.2))*MAX_COLOR_RANGE,fogclr);
					else color.rgb = calcFog(spos,pow(color.rgb,vec3(2.2))*MAX_COLOR_RANGE,fogclr);
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

/* If you reached this line, then you're probably about to break the agreement which you accepted by downloading Sildur's shaders!
So stop your doing and ask Sildur before copying anything which would break the agreement, unless you're Chocapic then go ahead ;)
--------------------------------------------------------------------------------------------------------------------------------*/ 

void main() {
	
	//Unpack Materials
	int land = int(matflag < 0.03);
	int iswater = int(matflag > 0.04 && matflag < 0.07);
	int hand  = int(matflag > 0.75 && matflag < 0.85);
	/*--------------------------------*/
	
	color.rgb = pow(color.rgb,vec3(2.2))*MAX_COLOR_RANGE;
	if(iswater > 0.1)CloudSightFix = 0.5;	
	else CloudSightFix = 0.08;	
	
	//Reflections
	fragpos = nvec3(gbufferProjectionInverse * nvec4(fragpos * 2.0 - 1.0));
	vec3 tfpos = fragpos.xyz;;
	vec3 uPos  = nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord.xy,texture2D(depthtex1,texcoord.xy).x) * 2.0 - 1.0));		//underwater position
	float cosT = dot(normalize(fragpos),upVec);
	vec3 fogclr = getSkyColor(fragpos.xyz);
	uPos.z = mix(uPos.z,2000.0*(0.25+sunVisibility*0.75),land);

	float normalDotEye = clamp((dot(normal, normalize(fragpos))),-1.0,0.0);
	float fresnel = pow(1.0 + normalDotEye, mix(4.0+rainStrength,5.,iswater));
	fresnel = mix(1.,fresnel,0.95)*0.5;

	//Water
	if (iswater > 0.9 && isEyeInWater == 0) {
	vec3 lc = mix(vec3(0.0),sunlight,sunVisibility);
	vec3 reflectedVector = reflect(normalize(fragpos), normalize(normal));
	float RdotU = (dot(reflectedVector,upVec)+1.)/2.;
	reflectedVector = fragpos + reflectedVector * (2000.0-fragpos.z);
	vec3 skyc = mix(getSkyColor(reflectedVector),vec3(0.002,0.005,0.002)*ambient_color*0.5,1-RdotU) ;
	vec3 sky_color = skyGradient(reflectedVector,drawCloud(reflectedVector,vec3(0.0)),skyc)*clamp(sky_lightmap*2.0-2/16.0,0.0,1.0);		
	
		vec4 reflection = raytrace(fragpos, normal,skyc,reflectedVector);
		reflection.rgb = mix(sky_color, reflection.rgb*1.5, reflection.a)+(color.a)*lc*(1.0-rainStrength)*(5.+SdotU*45.);			
		reflection.a = min(reflection.a,1.0);
		color.rgb = fresnel*reflection.rgb + (1-fresnel)*color.rgb;
    }/*--------------------------------*/

	//Draw Sun
	color.rgb = drawSun(tfpos,color.rgb,land);
	//Draw Sky color
	if(land > 0.9)color.rgb = skyGradient(uPos.xyz,color.rgb,fogclr);
	//Draw Clouds
	if(land > 0.9 && cosT > 0.)color.rgb = drawCloud(tfpos.xyz,color.rgb);
	//Draw Land fog
	if(land < 0.9)color.rgb = calcFog(fragpos.xyz,color.rgb,(fogclr));
	//Draw (under)water fog
	if (isEyeInWater == 1)color.rgb = underwaterFog(length(fragpos),color.rgb);
	/*--------------------------------*/
	
//calculate sun occlusion (only on one pixel) for lens flare	
	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
	tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lightPos = pos1*0.5+0.5;
	
float visiblesun = 0.0;
float nb = 0;
if (texcoord.x < 3.0*pw && texcoord.x < 3.0*ph) {
	for (int i = 0; i < 10;i++) {
		for (int j = 0; j < 10 ;j++) {
		float temp = texture2D(gaux1,lightPos + vec2(pw*(i-5.0)*10.0,ph*(j-5.0)*10.0)).g;
		visiblesun +=  1.0-float(temp > 0.04) ;
		nb += 1;
		}
	}
	visiblesun /= nb;
}/*--------------------------------*/

	color.rgb = clamp(pow(color.rgb/MAX_COLOR_RANGE,vec3(1.0/2.2)),0.0,1.0);

	gl_FragData[0] = vec4(color.rgb,visiblesun);
}