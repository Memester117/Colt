#version 120
#extension GL_ARB_shader_texture_lod : enable

/*

*/

/////////////////////////CONFIGURABLE VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////CONFIGURABLE VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SATURATION_BOOST 0.2 			//How saturated the final image should be. 0 is unchanged saturation. Higher values create more saturated image

#define Color_desaturation  0.0		// Color_desaturation. 0.0 = full color. 1.0 = Black & White [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

#define RainFog2						//This is a second layer of fog that more or less masks the rain on the horizon
#define FOG_DENSITY2	0.010			//Default is 0.043	[0.010 0.020 0.030 0.040]

#define New_GlowStone					//disable to return GlowStones to Continuum Default
#define LENS_FLARE

/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D gaux1;
uniform sampler2D gaux3;
uniform sampler2D shadowcolor0;

varying vec4 texcoord;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform vec3 sunPosition;
uniform mat4 gbufferProjection;

uniform int   isEyeInWater;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;

#define BANDING_FIX_FACTOR 1.0

const bool gcolorMipmapEnabled = true;


/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

vec3 GetTexture(in sampler2D tex, in vec2 coord) {				//Perform a texture lookup with BANDING_FIX_FACTOR compensation
	return pow(texture2D(tex, coord).rgb, vec3(BANDING_FIX_FACTOR + 1.2));
}

vec3 GetTextureLod(in sampler2D tex, in vec2 coord, in int level) {				//Perform a texture lookup with BANDING_FIX_FACTOR compensation
	return pow(texture2DLod(tex, coord, level).rgb, vec3(BANDING_FIX_FACTOR + 1.2));
}

vec3 GetTexture(in sampler2D tex, in vec2 coord, in int LOD) {	//Perform a texture lookup with BANDING_FIX_FACTOR compensation and lod offset
	return pow(texture2D(tex, coord, LOD).rgb, vec3(BANDING_FIX_FACTOR));
}

float GetDepthLinear(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return 2.0 * near * far / (far + near - (2.0 * texture2D(gdepthtex, coord).x - 1.0) * (far - near));
}

vec3 GetColorTexture(in vec2 coord) {
	return GetTextureLod(gnormal, coord.st, 0).rgb;
}

float GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(gdepth, coord).r;
}

vec4 cubic(float x) {
    float x2 = x * x;
    float x3 = x2 * x;
    vec4 w;
    w.x =   -x3 + 3*x2 - 3*x + 1;
    w.y =  3*x3 - 6*x2       + 4;
    w.z = -3*x3 + 3*x2 + 3*x + 1;
    w.w =  x3;
    return w / 6.f;
}

vec4 BicubicTexture(in sampler2D tex, in vec2 coord) {
	vec2 resolution = vec2(viewWidth, viewHeight);

	coord *= resolution;

	float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

bool GetMaterialMask(in vec2 coord, in int ID) {
	float matID = floor(GetMaterialIDs(coord) * 255.0);

	//Catch last part of sky
	if (matID > 254.0)
		matID = 0.0;

	return (matID == ID);
}

bool GetMaterialMask(in vec2 coord, in int ID, float matID) {
	matID = floor(matID * 255.0);

	if (matID > 254.0)
		matID = 0.0;

	return (matID == ID);
}

void Vignette(inout vec3 color) {
	float dist = distance(texcoord.st, vec2(0.5)) * 2.0;
		  dist /= 1.5142;
		  dist = pow(dist, 1.1);

	color.rgb *= 1.0 - dist;

}

void CalculateExposure(inout vec3 color) {
	float exposureMax = 1.55;
	exposureMax *= mix(1.0, 0.25, timeSunrise);
	exposureMax *= mix(1.0, 0.25, timeSunset);
	exposureMax *= mix(1.0, 0.0, timeMidnight);
	exposureMax *= mix(1.0, 0.25, rainStrength);

	float exposureMin = 0.07;
	float exposure = pow(eyeBrightnessSmooth.y / 240.0, 6.0) * exposureMax + exposureMin;

	color.rgb /= vec3(exposure);
}


/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct MaskStruct {
	float matIDs;

	bool sky;
	bool land;
	bool grass;
	bool leaves;
	bool ice;
	bool hand;
	bool translucent;
	bool glow;
	bool sunspot;
	bool goldBlock;
	bool ironBlock;
	bool diamondBlock;
	bool emeraldBlock;
	bool sand;
	bool sandstone;
	bool stone;
	bool cobblestone;
	bool wool;
	bool clouds;

	bool torch;
	bool lava;
	bool glowstone;
	bool fire;

	bool water;

	bool volumeCloud;
} mask;


/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void CalculateMasks(inout MaskStruct mask) {
	mask.glowstone = GetMaterialMask(texcoord.st, 32, mask.matIDs);
}

vec3 GetBloomTile(const int scale, vec2 offset) {
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

	vec2 coord  = texcoord.st;
	     coord /= scale;
	     coord += offset + pixelSize;

	return pow((texture2DLod(gcolor, coord, 0).rgb), vec3(2.2));
}

vec3[8] GetBloom() {
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

	vec3[8] bloom;

	// These arguments should be identical to those in composite2.fsh
	bloom[1] = GetBloomTile(  4, vec2(0.0                         ,                          0.0));
	bloom[2] = GetBloomTile(  8, vec2(0.0                         , 0.25     + pixelSize.y * 2.0));
	bloom[3] = vec3(0.0);
	bloom[4] = vec3(0.0);
	bloom[5] = vec3(0.0);
	bloom[6] = vec3(0.0);
	bloom[7] = vec3(0.0);

	bloom[0] = vec3(0.0);

	for (int index = 1; index < bloom.length(); index++)
		bloom[0] += bloom[index];

	bloom[0] /= bloom.length() - 1.0;

	return bloom;
}

void AddRainFogScatter(inout vec3 color, in vec3[8] bloom) {
	const float    bloomSlant = 0.0;
	const float[7] bloomWeight = float[7] (pow(7.0, bloomSlant),
	                                       pow(6.0, bloomSlant),
	                                       pow(5.0, bloomSlant),
	                                       pow(4.0, bloomSlant),
	                                       pow(3.0, bloomSlant),
	                                       pow(2.0, bloomSlant),
	                                       1.0);

	vec3 fogBlur = bloom[1] * bloomWeight[6] +
	               bloom[2] * bloomWeight[5] +
	               bloom[3] * bloomWeight[4] +
	               bloom[4] * bloomWeight[3] +
	               bloom[5] * bloomWeight[2] +
	               bloom[6] * bloomWeight[1] +
	               bloom[7] * bloomWeight[0];

	float fogTotalWeight = bloomWeight[0] +
	                       bloomWeight[1] +
	                       bloomWeight[2] +
	                       bloomWeight[3] +
	                       bloomWeight[4] +
	                       bloomWeight[5] +
	                       bloomWeight[6];

	fogBlur /= fogTotalWeight;

	float linearDepth = GetDepthLinear(texcoord.st);

	float fogDensity = FOG_DENSITY2 * (rainStrength);
	float visibility = 1.0 / (pow(exp(linearDepth * fogDensity), 1.0));
	float fogFactor = 1.0 - visibility;
	fogFactor = clamp(fogFactor, 0.0, 1.0);
	fogFactor *= mix(0.0, 1.0, pow(eyeBrightnessSmooth.y / 240.0, 6.0));

	color = mix(color, fogBlur, fogFactor * 1.0);
}

void TonemapReinhard05(inout vec3 color) {
	float averageLuminance = 0.000055;

	vec3 value = color.rgb / (color.rgb + vec3(averageLuminance));

	color.rgb = value * 1.195 - 0.00;
	color.rgb = min(color.rgb, vec3(1.0));
	color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
}


vec3 flare(vec2 uv, vec2 pos) {
  vec2 main = uv - pos;
  vec2 uvd = uv * length(uv);

  float ang = atan(main.x, main.y);
  float dist = length(main);
	dist = pow(dist, 0.1);

  float f0 = 1.0 / (length(uv - pos) * 16.0 + 1.0);

  float f1 = max(0.01 - pow(length(uv + 1.2 * pos), 1.9), 0.0) * 7.0;

  float f2 = max(1.0 / (1.0 + 32.0 * pow(length(uvd + 0.8 * pos), 1.0)), 0.0) * 0.25;
  float f22 = max(1.0 / (1.0 + 32.0 * pow(length(uvd + 0.83 * pos), 1.0)), 0.0) * 0.23;
  float f23 = max(1.0 / (1.0 + 32.0 * pow(length(uvd + 0.87 * pos), 1.0)), 0.0) * 0.21;

  vec2 uvx = mix(uv, uvd, 0.5);

  float f4 = max(0.01 - pow(length(uvx + 0.4 * pos), 1.4), 0.0) * 6.0;
  float f42 = max(0.01 - pow(length(uvx + 0.43 * pos), 1.4), 0.0) * 5.0;
  float f43 = max(0.01 - pow(length(uvx + 0.47 * pos), 1.4), 0.0) * 3.0;

  uvx = mix(uv, uvd, -0.4);

  float f5 = max(0.01 - pow(length(uvx + 0.3 * pos), 1.5), 0.0) * 2.0;
  float f52 = max(0.01 - pow(length(uvx + 0.35 * pos), 1.5), 0.0) * 2.0;
  float f53 = max(0.01 - pow(length(uvx + 0.4 * pos), 1.5), 0.0) * 2.0;

  uvx = mix(uv, uvd, -0.5);

  float f6 = max(0.01 - pow(length(uvx - 0.3 * pos), 0.6), 0.0) * 6.0;
  float f62 = max(0.01 - pow(length(uvx - 0.325 * pos), 0.6), 0.0) * 3.0;
  float f63 = max(0.01 - pow(length(uvx - 0.35 * pos), 0.6), 0.0) * 5.0;

  vec3 c = vec3(0.0);

  c.r += f2 + f4 + f5 + f6;
	c.g += f22 + f42 + f52 + f62;
	c.b += f23 + f43 + f53 + f63;
  c = c * 1.3 - vec3(length(uvd) * 0.05);
  c += vec3(0);

  return c * 1.5;
}

void LensFlare(inout vec3 color) {
	vec3 tempColor2 = vec3(0.0);
	float pw = 1.0 / viewWidth;
	float ph = 1.0 / viewHeight;
	vec3 sP = sunPosition;

	vec4 tpos = vec4(sP, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz / tpos.w, 1.0);
	vec2 lPos = tpos.xy / tpos.z;
	lPos = (lPos + 1.0) / 2.0;
 	vec2 checkcoord = lPos;

  	if(checkcoord.x < 1.0 && checkcoord.x > 0.0 && checkcoord.y < 1.0 && checkcoord.y > 0.0 && timeMidnight < 1.0) {
    	vec2 checkcoord;

  		float sunmask = 0.0;
    	float sunstep = -4.5;
    	float masksize = 0.004;

		for(int a = 0; a < 4; a++) {
    		for(int b = 0; b < 4; b++) {
        		checkcoord = lPos + vec2(pw * a * 5.0, ph * 5.0 * b);

		        bool sky = false;

		        float matID = GetMaterialIDs(checkcoord);      //Gets texture that has all material IDs stored in it
		        matID = floor(matID * 255.0);      //Scale texture from 0-1 float to 0-255 integer format

		        //Catch last part of sky
		        if(matID > 254.0) {
		        	matID = 0.0;
		        }

		        if(matID == 0) {
		          sky = true;
		        } else {
		          sky = false;
		        }

		        if(checkcoord.x < 1.0 && checkcoord.x > 0.0 && checkcoord.y < 1.0 && checkcoord.y > 0.0) {
		        	if(sky == true) {
		            	sunmask = 1.0;
		        	} else {
		            	sunmask = 0.0;
		          	}
		        }
      		}
    	}

	    sunmask *= 0.34 * (1.0 - timeMidnight);
	    sunmask *= (1.0 - rainStrength);

	    if(sunmask > 0.02) {
	    	color += vec3(1.4, 1.2, 1.0) * flare(texcoord.st - 0.5, sunPosition.xy / 100);
		}
	}
	color.rgb = color;
}


/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void main() {
	vec2 fake_refract = vec2(sin(frameTimeCounter * 1.7 + texcoord.x * 50.0 + texcoord.y * 25.0), cos(frameTimeCounter * 2.5 + texcoord.y * 100.0 + texcoord.x * 25.0)) * isEyeInWater;
	vec2 Fake_Refract_1 = vec2(sin(frameTimeCounter * 1.7 + texcoord.x * 50.0 + texcoord.y * 25.0), cos(frameTimeCounter + texcoord.y * 100.0 + texcoord.x * 25.0));

	vec3 color = GetColorTexture(texcoord.st + fake_refract * 0.005 + 0.0045 * (Fake_Refract_1 * 0.0045));	//Sample gcolor texture

	mask.matIDs = GetMaterialIDs(texcoord.st);
	CalculateMasks(mask);

	#ifdef New_GlowStone
		color /= mix(1.0, 15.0, float(mask.glowstone)* timeMidnight);
		color /= mix(1.0, 2.5, float(mask.glowstone)* timeNoon);
		color /= mix(1.0, 7.0,float(mask.glowstone) * mix(1.0, 0.0, pow(eyeBrightnessSmooth.y / 240.0, 2.0))* timeNoon);
	#endif

	vec3[8] bloom = GetBloom();

	//color = mix(color, bloom[0] * 1, vec3(0.0007));

	#ifdef RainFog2
		AddRainFogScatter(color, bloom);
	#endif

	Vignette(color);

	CalculateExposure(color);

	TonemapReinhard05(color);


	color = mix(color, vec3(dot(color, vec3(1.0 / 3.0))), vec3(Color_desaturation));

	gl_FragColor = vec4(color.rgb, 1.0);
	//gl_FragColor = vec4(texture2D(shadowcolor0, texcoord.st).rgba);
}
