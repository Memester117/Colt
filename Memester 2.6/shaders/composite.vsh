#version 120
/*
      
*/

#define Moonlight 0.012 //[0.002 0.004 0.012 0.02 0.04 0.06]

/*--------------------------------*/
varying vec4 texcoord;

varying vec3 lightVector;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying vec3 sunlight;
varying vec3 moonlight;
varying vec3 ambient_color;

varying float handItemLight;
varying float eyeAdapt;

varying float SdotU;
varying float MdotU;
varying float sunVisibility;
varying float moonVisibility;

uniform vec3 skyColor;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform int worldTime;
uniform int heldItemId;
uniform int heldBlockLightValue;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferModelView;
/*--------------------------------*/

//Sunlight
const ivec4 ToD[25] = ivec4[25](ivec4(0,200,134,48), //hour,r,g,b
								ivec4(1,200,134,48),
								ivec4(2,200,134,48),
								ivec4(3,200,134,48),
								ivec4(4,200,134,48),
								ivec4(5,200,134,48),
								ivec4(6,200,134,90),
								ivec4(7,200,180,110),
								ivec4(8,200,186,132),
								ivec4(9,200,195,143),
								ivec4(10,200,199,154),
								ivec4(11,200,200,165),
								ivec4(12,200,200,171),
								ivec4(13,200,200,165),
								ivec4(14,200,199,154),
								ivec4(15,200,195,143),
								ivec4(16,200,186,132),
								ivec4(17,200,180,110),
								ivec4(18,200,153,90),
								ivec4(19,200,134,48),
								ivec4(20,200,134,48),
								ivec4(21,200,134,48),
								ivec4(22,200,134,48),
								ivec4(23,200,134,48),
								ivec4(24,200,134,48));
								
vec3 sky_color = ivec3(60,170,255)/255.0;								
/*--------------------------------*/							

vec3 getSkyColor(vec3 fposition) {

/*--------------------------------*/
	float SdotU = dot(sunVec,upVec);
	float MdotU = dot(moonVec,upVec);
	float sunVisibility = pow(clamp(SdotU+0.1,0.0,0.1)/0.1,2.0);
	float moonVisibility = pow(clamp(MdotU+0.1,0.0,0.1)/0.1,2.0);
/*--------------------------------*/	
vec3 sky_color = vec3(0.1, 0.35, 1.);
vec3 nsunlight = normalize(pow(sunlight,vec3(2.2))*vec3(1.,0.9,0.8));
vec3 sVector = normalize(fposition);

sky_color = normalize(mix(sky_color,vec3(0.25,0.3,0.4)*length(sunlight)*0.3,rainStrength)); //normalize colors in order to don't change luminance
/*--------------------------------*/
float cosT = dot(sVector,upVec); 
float absCosT = max(cosT,0.0);			
float cosY = dot(sunVec,sVector);
float Y = acos(cosY);	
/*--------------------------------*/	
float a = -1.;
float b = -0.24;
float c = 6.0;
float d = -0.8;
float e = 0.45;

/*--------------------------------*/

//sun sky color
float L =  (1+a*exp(b/(absCosT+0.01)))*(1+c*exp(d*Y)+e*cosY*cosY); 
L = pow(L,1.0-rainStrength*0.8)*(1.0-rainStrength*0.8); //modulate intensity when raining

vec3 skyColorSun = mix(sky_color, nsunlight,1-exp(-0.005*pow(L,4.)*(1-rainStrength*0.8)))*L*0.5; //affect color based on luminance (0% physically accurate)
skyColorSun *= sunVisibility;
/*--------------------------------*/

//moon sky color
float McosY = dot(moonVec,sVector);
float MY = acos(McosY);
/*--------------------------------*/

float L2 =  (1+a*exp(b/(absCosT+0.01)))*(1+c*exp(d*MY)+e*McosY*McosY)+0.2;
L2 = pow(L2,1.0-rainStrength*0.8)*(1.0-rainStrength*0.35); //modulate intensity when raining

vec3 skyColormoon = mix(pow(normalize(moonlight),vec3(2.2))*length(moonlight),normalize(vec3(0.25,0.3,0.4))*length(moonlight),rainStrength)*L2*0.8 ; //affect color based on luminance (0% physically accurate)
skyColormoon *= moonVisibility;
sky_color = skyColormoon*2.0+skyColorSun;
/*--------------------------------*/
return sky_color;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	
	moonlight =  vec3(0.4, 0.75, 1.3) * Moonlight;
	/*--------------------------------*/
	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = normalize(sunPosition);
	}
	else {
		lightVector = normalize(-sunPosition);
	}
	/*--------------------------------*/
	sunVec = normalize(sunPosition);
	moonVec = normalize(-sunPosition);
	upVec = normalize(upPosition);
	
	SdotU = dot(sunVec,upVec);
	MdotU = dot(moonVec,upVec);
	sunVisibility = pow(clamp(SdotU+0.1,0.0,0.1)/0.1,2.0);
	moonVisibility = pow(clamp(MdotU+0.1,0.0,0.1)/0.1,2.0);
	/*--------------------------------*/
	
	float hour = mod(worldTime/1000.0+6.0,24);
	
	ivec4 temp = ToD[int(mod(floor(hour),24))];
	ivec4 temp2 = ToD[int(mod(floor(hour) + 1,24))];
	
	sunlight = mix(vec3(temp.yzw),vec3(temp2.yzw),(hour-float(temp.x))/float(temp2.x-temp.x))/255.0f;

	sunlight.b *= 0.95;
	/*--------------------------------*/
	
	//sample the skybox at different places to get an accurate average color from the sky
	vec3 wUp = (gbufferModelView * vec4(vec3(0.0,1.0,0.0),0.0)).rgb;
	vec3 wS1 = (gbufferModelView * vec4(normalize(vec3(3.5,1.0,3.5)),0.0)).rgb;
	vec3 wS2 = (gbufferModelView * vec4(normalize(vec3(-3.5,1.0,3.5)),0.0)).rgb;
	vec3 wS3 = (gbufferModelView * vec4(normalize(vec3(3.5,1.0,-3.5)),0.0)).rgb;
	vec3 wS4 = (gbufferModelView * vec4(normalize(vec3(-3.5,1.0,-3.5)),0.0)).rgb;

	ambient_color = (getSkyColor(wUp) + getSkyColor(wS1) + getSkyColor(wS2) + getSkyColor(wS3) + getSkyColor(wS4))*2.;
	ambient_color = pow(normalize(ambient_color),vec3(1./2.2))*length(ambient_color);		
	/*--------------------------------*/
	eyeAdapt = (2.0-min(length((getSkyColor(wUp) + getSkyColor(wS1) + getSkyColor(wS2) + getSkyColor(wS3) + getSkyColor(wS4))*2.)/sqrt(3.)*2.,eyeBrightnessSmooth.y/255.0*1.6+0.3))*(1-rainStrength*0.5);
	/*--------------------------------*/

	//Handheld Items casting light
	handItemLight = 0.0;
	if (heldItemId == 50) {
		//torch
		handItemLight = 0.5;
	}	
	else if (heldItemId == 76 || heldItemId == 94) {
		//active redstone torch / redstone repeater
		handItemLight = 0.1;
	}
	else if (heldItemId == 89) {
		//lightstone
		handItemLight = 0.6;
	}
	else if (heldItemId == 10 || heldItemId == 11 || heldItemId == 51 || heldItemId == 169 || heldItemId == 138) {
		//lava-flowing / lava-still / fire / sea lantern / beacon
		handItemLight = 0.5;
	}
	else if (heldItemId == 91) {
		//jack-o-lantern
		handItemLight = 0.6;
	}
	else if (heldItemId == 327) {
		//Lava bucket
		handItemLight = 0.2;
	}/*--------------------------------*/
}
