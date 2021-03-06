#version 120
#extension GL_ARB_shader_texture_lod : enable

//#define OLD_LIGHTING_FIX		//In newest versions of the shaders mod/optifine, old lighting isn't removed properly. If OldLighting is On and this is enabled, you'll get proper results in any shaders mod/minecraft version.

#define Dynamic_Weather
#define Dynamic_Terrain

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 worldPosition;
uniform int moonPhase;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

uniform int worldTime;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D noisetex;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 worldNormal;

varying float distance;

varying float materialIDs;

varying mat3 tbnMatrix;
varying vec4 vertexPos;

//If you're using 1.7.2, it has a texture glitch where certain sides of blocks are mirrored. Enable the following to compensate and keep lighting correct
//#define TEXTURE_FIX	//If you're using 1.7.2, it has a texture glitch where certain sides of blocks are mirrored. Enable the following to compensate and keep lighting correct

#define WAVING_GRASS
#define WAVING_WHEAT
#define WAVING_LEAVES
#define WAVING_VINES
#define WAVING_LILIES
#define WAVING_LAVA

#define WAVING_VINES_SPEED 1.0  	//[0.25 0.5 0.75 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0] //Lower numbers means faster, Higher numbers means slower
#define GRASS_SPEED		1.0		//[1.0 100.0 500.0 1000.0 5000.0]Default is 1.0, Higher numbers means slower
#define GRASS_MOVEMENT  0.85 //[0.00000085 0.000085 0.0085 0.55 0.65 0.85 0.95 1.0]Default is 0.85, Lower nimbers means slower
#define WAVING_LEAVES_SPEED 1.0		//[0.75 1.0 1.25 1.50 1.75 2.0 2.25 2.50 2.75 3.0 3.25 3.50 3.75 4.0 4.25 4.50 4.75 5.0 5.25 5.50 5.75 6.0 6.25 6.50 6.75 7.0 8.0 9.0 10.0 11.0 15.0 20.0 30.0 50.0]

//Added
#define WAVING_CARROTS
#define WAVING_NETHER_WART
#define WAVING_POTATOES

#define ENTITY_VINES        106.0

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
	int resolution = 64;

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

vec3 calcLavaMove(in vec3 pos) {
	float fy = fract(pos.y + 0.001);
  float PIs = 3.1415927;
	if (fy > 0.002) {
		float wave = 0.05 * sin(2 * PIs / 4 * frameTimeCounter / 3 + 2 * PIs * 2 / 16 * pos.x + 2 * PIs * 5 / 16 * pos.z)
				   + 0.05 * sin(2 * PIs / 3 * frameTimeCounter / 3 - 2 * PIs * 3 / 16 * pos.x + 2 * PIs * 4 / 16 * pos.z);
		return vec3(0, clamp(wave, -fy, 1.0-fy), 0);
	} else {
		return vec3(0);
	}
}

float dynWeather(in float scale) {
  float dynWeather = 1.0;

#ifdef Dynamic_Weather
	#ifdef Dynamic_Terrain
    float next_moon_phase = moonPhase + 1;

    if(float(moonPhase) == 7) {
      next_moon_phase = 0;
    }

    float moon_phase_smooth = mix(moonPhase, next_moon_phase, float(worldTime) / 24000.0);

    dynWeather = ((abs(float(moon_phase_smooth) - 2) + 1) / scale) + 0.5;
	#endif
#endif

  return dynWeather;
}

void main() {
	texcoord = gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
  float dynWeatherScaler = dynWeather(5);

	vec4 viewpos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec4 position = viewpos;

	worldPosition = viewpos.xyz + cameraPosition.xyz;

	//Gather materials
	materialIDs = 1.0f;

	//Grass
	if(mc_Entity.x == 31.0
		|| mc_Entity.x == 38.0f 	//Rose
		|| mc_Entity.x == 37.0f 	//Flower
		|| mc_Entity.x == 1925.0f 	//Biomes O Plenty: Medium Grass
		|| mc_Entity.x == 1920.0f 	//Biomes O Plenty: Thorns, barley
		|| mc_Entity.x == 1921.0f 	//Biomes O Plenty: Sunflower
		) {
		materialIDs = max(materialIDs, 2.0f);
	}

	//Wheat
	if (mc_Entity.x == 59.0
		|| mc_Entity.x == 141.0f
		|| mc_Entity.x == 142.0f
		|| mc_Entity.x == 115.0f

		) {
		materialIDs = max(materialIDs, 2.0f);
	}

	//Leaves
	if(mc_Entity.x == 18.0
    || mc_Entity.x == 161.0
		|| mc_Entity.x == 1962.0f //Biomes O Plenty: Leaves
		|| mc_Entity.x == 1924.0f //Biomes O Plenty: Leaves
		|| mc_Entity.x == 1923.0f //Biomes O Plenty: Leaves
		|| mc_Entity.x == 1926.0f //Biomes O Plenty: Leaves
		|| mc_Entity.x == 1936.0f //Biomes O Plenty: Giant Flower Leaves

		 ) {
		materialIDs = max(materialIDs, 3.0f);
	}

  //Double Tall
  if(mc_Entity.x == 175.0f
    ) {
      materialIDs = max(materialIDs, 65.0);
    }
	//Gold block
	if (mc_Entity.x == 41) {
		materialIDs = max(materialIDs, 20.0f);
	}

	//Iron block
	if (mc_Entity.x == 42) {
		materialIDs = max(materialIDs, 21.0f);
	}

	//Diamond Block
	if (mc_Entity.x == 57) {
		materialIDs = max(materialIDs, 22.0f);
	}

	//Emerald Block
	if (mc_Entity.x == -123) {
		materialIDs = max(materialIDs, 23.0f);
	}

	//sand
	if (mc_Entity.x == 12) {
		materialIDs = max(materialIDs, 24.0f);
	}

	//sandstone
	if (mc_Entity.x == 24 || mc_Entity.x == -128) {
		materialIDs = max(materialIDs, 25.0f);
	}

	//stone
	if (mc_Entity.x == 1) {
		materialIDs = max(materialIDs, 26.0f);
	}

	//cobblestone
	if (mc_Entity.x == 4) {
		materialIDs = max(materialIDs, 27.0f);
	}

	//wool
	if (mc_Entity.x == 35) {
		materialIDs = max(materialIDs, 28.0f);
	}

	//torch
	if (mc_Entity.x == 50) {
		materialIDs = max(materialIDs, 30.0f);
	}

	//lava
	if (mc_Entity.x == 10 || mc_Entity.x == 11) {
		materialIDs = max(materialIDs, 31.0f);
	}

	//glowstone and lamp
	if (mc_Entity.x == 89 || mc_Entity.x == 124) {
		materialIDs = max(materialIDs, 32.0f);
	}

	//fire
	if (mc_Entity.x == 51) {
		materialIDs = max(materialIDs, 33.0f);
	}

	float tick = frameTimeCounter / WAVING_LEAVES_SPEED;

  float grassWeight = mod(texcoord.t * 16.0f, 1.0f / 16.0f);
  float vineweight = mod(texcoord.t * 1.0f, 1.0f / 0.20f);

  float lightWeight = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	lightWeight *= 1.1f;
	lightWeight -= 0.1f;
	lightWeight = max(0.0f, lightWeight);
	lightWeight = pow(lightWeight, 5.0f);

	if (grassWeight < 0.01f) {
	  grassWeight = 1.0f;
	} else {
	  grassWeight = 0.0f;
	}

  const float pi = 3.14159265f;

  position.xyz += cameraPosition.xyz;

  #ifdef WAVING_GRASS
    //Waving grass
    if(materialIDs == 2.0f) {
		  vec2 angleLight = vec2(0.0f);
		  vec2 angleHeavy = vec2(0.0f);
      vec2 angle 		= vec2(0.0f);

      vec3 pn0 = position.xyz;
			pn0.x -= frameTimeCounter / 3.0f;

      vec3 stoch = BicubicTexture(noisetex, pn0.xz / 64.0f).xyz;
      vec3 stochLarge = BicubicTexture(noisetex, position.xz / (64.0f * 6.0f)).xyz;

      vec3 pn = position.xyz;
			pn.x *= 2.0f;
			pn.x -= frameTimeCounter * 15.0f;
			pn.z *= 8.0f;

      vec3 stochLargeMoving = BicubicTexture(noisetex, pn.xz / (64.0f * 10.0f)).xyz;

		  vec3 p = position.xyz;
		 	p.x += sin(p.z / 2.0f) * 1.0f;
		 	p.xz += stochLarge.rg * 5.0f;

		  float windStrength = mix(GRASS_MOVEMENT * dynWeatherScaler, 1.0f, rainStrength);
      float windStrengthRandom = stochLargeMoving.x;
			windStrengthRandom = pow(windStrengthRandom, mix(2.0f, 1.0f, rainStrength));
			windStrength *= mix(windStrengthRandom, 0.5f, rainStrength * dynWeatherScaler * 0.25f);

		  //heavy wind
		  float heavyAxialFrequency 			= 8.0f;
		  float heavyAxialWaveLocalization 	= 0.9f;
		  float heavyAxialRandomization 		= 13.0f;
	    float heavyAxialAmplitude 			= 15.0f;
		  float heavyAxialOffset 				= 15.0f;

		  float heavyLateralFrequency 		= 6.732f;
		  float heavyLateralWaveLocalization 	= 1.274f;
	    float heavyLateralRandomization 	= 1.0f;
		  float heavyLateralAmplitude 		= 6.0f;
	    float heavyLateralOffset 			= 0.0f;

		  //light wind
		  float lightAxialFrequency 			= 5.5f;
	    float lightAxialWaveLocalization 	= 1.1f;
      float lightAxialRandomization 		= 21.0f;
      float lightAxialAmplitude 			= 5.0f;
      float lightAxialOffset 				= 5.0f;

      float lightLateralFrequency 		= 5.9732f;
      float lightLateralWaveLocalization 	= 1.174f;
      float lightLateralRandomization 	= 0.0f;
      float lightLateralAmplitude 		= 1.0f;
      float lightLateralOffset 			= 0.0f;

      float windStrengthCrossfade = clamp(windStrength * 2.0f - 1.0f, 0.0f, 1.0f);
      float lightWindFade = clamp(windStrength * 2.0f, 0.2f, 1.0f);

      angleLight.x += sin(frameTimeCounter / GRASS_SPEED * lightAxialFrequency 		- p.x * lightAxialWaveLocalization		+ stoch.x * lightAxialRandomization) 	* lightAxialAmplitude 		+ lightAxialOffset;
      angleLight.y += sin(frameTimeCounter / GRASS_SPEED * lightLateralFrequency 	- p.x * lightLateralWaveLocalization 	+ stoch.x * lightLateralRandomization) 	* lightLateralAmplitude  	+ lightLateralOffset;

      angleHeavy.x += sin(frameTimeCounter / GRASS_SPEED * heavyAxialFrequency 		- p.x * heavyAxialWaveLocalization		+ stoch.x * heavyAxialRandomization) 	* heavyAxialAmplitude 		+ heavyAxialOffset;
      angleHeavy.y += sin(frameTimeCounter / GRASS_SPEED * heavyLateralFrequency 	- p.x * heavyLateralWaveLocalization 	+ stoch.x * heavyLateralRandomization) 	* heavyLateralAmplitude  	+ heavyLateralOffset;

      angle = mix(angleLight * lightWindFade, angleHeavy, vec2(windStrengthCrossfade));
      angle *= 2.0f;

		  ////Rotate block pivoting from bottom based on angle
		  position.x += (sin((angle.x / 180.0f) * 3.141579f)) * grassWeight * lightWeight						* 1.0f	;
      position.z += (sin((angle.y / 180.0f) * 3.141579f)) * grassWeight * lightWeight						* 1.0f	;
      position.y += (cos(((angle.x + angle.y) / 180.0f) * 3.141579f) - 1.0f)  * grassWeight * lightWeight	* 1.0f	;
	  }
  #endif



  #ifdef WAVING_WHEAT
    if (mc_Entity.x == 296 && texcoord.t < 0.35) {
		  float speed = 0.03;

      float magnitude = sin((tick * pi / (28.0)) + position.x + position.z) * 0.12 + 0.02;
			magnitude *= grassWeight * 0.2f;
			magnitude *= lightWeight;
		  float d0 = sin(tick * pi / (122.0 * speed)) * 3.0 - 1.5 + position.z;
      float d1 = sin(tick * pi / (152.0 * speed)) * 3.0 - 1.5 + position.x;
      float d2 = sin(tick * pi / (122.0 * speed)) * 3.0 - 1.5 + position.x;
      float d3 = sin(tick * pi / (152.0 * speed)) * 3.0 - 1.5 + position.z;
      position.x += sin((tick * pi / (28.0 * speed)) + (position.x + d0) * 0.1 + (position.z + d1) * 0.1) * magnitude * dynWeatherScaler;
      position.z += sin((tick * pi / (28.0 * speed)) + (position.z + d2) * 0.1 + (position.x + d3) * 0.1) * magnitude * dynWeatherScaler;
    }

	  //small leaf movement
	  if(mc_Entity.x == 59.0 && texcoord.t < 0.35) {
		  float speed = 0.04;

		  float magnitude = (sin(((position.y + position.x)/2.0 + tick * pi / ((28.0)))) * 0.025 + 0.075) * 0.2;
			magnitude *= grassWeight;
			magnitude *= lightWeight;
		  float d0 = sin(tick * pi / (112.0 * speed)) * 3.0 - 1.5;
	    float d1 = sin(tick * pi / (142.0 * speed)) * 3.0 - 1.5;
      float d2 = sin(tick * pi / (112.0 * speed)) * 3.0 - 1.5;
      float d3 = sin(tick * pi / (142.0 * speed)) * 3.0 - 1.5;
      position.x += sin((tick * pi / (18.0 * speed)) + (-position.x + d0)*1.6 + (position.z + d1)*1.6) * magnitude * (1.0f + rainStrength * 2.0f) * dynWeatherScaler;
      position.z += sin((tick * pi / (18.0 * speed)) + (position.z + d2)*1.6 + (-position.x + d3)*1.6) * magnitude * (1.0f + rainStrength * 2.0f) * dynWeatherScaler;
      position.y += sin((tick * pi / (11.0 * speed)) + (position.z + d2) + (position.x + d3)) * (magnitude/3.0) * (1.0f + rainStrength * 2.0f) * dynWeatherScaler;
	  }
  #endif

  #ifdef WAVING_LEAVES
	  if(materialIDs == 3.0f && texcoord.t < 1.90 && texcoord.t > -1.0) {
		  float speed = 0.05 * dynWeatherScaler;

		  float magnitude = (sin((position.y + position.x + tick * pi / ((28.0) * speed))) * 0.15 + 0.15) * 0.30 * lightWeight;
		  magnitude *= lightWeight;
		  float d0 = sin(tick * pi / (112.0 * speed * dynWeatherScaler)) * 3.0 - 1.5;
		  float d1 = sin(tick * pi / (142.0 * speed * dynWeatherScaler)) * 3.0 - 1.5;
		  float d2 = sin(tick * pi / (132.0 * speed * dynWeatherScaler)) * 3.0 - 1.5;
		  float d3 = sin(tick * pi / (122.0 * speed * dynWeatherScaler)) * 3.0 - 1.5;
		  position.x += sin((tick * pi / (18.0 * speed)) + (-position.x + d0)*1.6 + (position.z + d1)*1.6) * magnitude * (1.0f + rainStrength * 1.0f) * dynWeatherScaler;
	    position.z += sin((tick * pi / (17.0 * speed)) + (position.z + d2)*1.6 + (-position.x + d3)*1.6) * magnitude * (1.0f + rainStrength * 1.0f) * dynWeatherScaler;
		  position.y += sin((tick * pi / (11.0 * speed)) + (position.z + d2) + (position.x + d3)) * (magnitude/2.0) * (1.0f + rainStrength * 1.0f) * dynWeatherScaler;
	  }


	  //lower leaf movement
	  if(materialIDs == 3.0f) {
		  float speed = 0.075 * dynWeatherScaler;

		  float magnitude = (sin((tick * pi / ((28.0) * speed))) * 0.05 + 0.15) * 0.075 * lightWeight;
			magnitude *= lightWeight;
		  float d0 = sin(tick * pi / (122.0 * speed * dynWeatherScaler)) * 3.0 - 1.5;
		  float d1 = sin(tick * pi / (142.0 * speed * dynWeatherScaler)) * 3.0 - 1.5;
		  float d2 = sin(tick * pi / (162.0 * speed * dynWeatherScaler)) * 3.0 - 1.5;
		  float d3 = sin(tick * pi / (112.0 * speed * dynWeatherScaler)) * 3.0 - 1.5;
		  position.x += sin((tick * pi / (13.0 * speed)) + (position.x + d0)*0.9 + (position.z + d1)*0.9) * magnitude * dynWeatherScaler;
		  position.z += sin((tick * pi / (16.0 * speed)) + (position.z + d2)*0.9 + (position.x + d3)*0.9) * magnitude * dynWeatherScaler;
		  position.y += sin((tick * pi / (15.0 * speed)) + (position.z + d2) + (position.x + d3)) * (magnitude/1.0) * dynWeatherScaler;
	  }
  #endif

  #ifdef WAVING_VINES
    //large scale movement
    if(mc_Entity.x == ENTITY_VINES ) {
      float speed = WAVING_VINES_SPEED * dynWeatherScaler;
      float magnitude = (sin(((position.y + position.x)/2.0 + worldTime * 3.14159265358979323846264 / ((88.0)))) * 0.05 + 0.15) * 0.26;
			magnitude *= vineweight;
			magnitude *= lightWeight;
		  float d0 = sin(worldTime * 3.14159265358979323846264 / (122.0 * speed)) * 3.0 - 1.5;
      float d1 = sin(worldTime * 3.14159265358979323846264 / (152.0 * speed)) * 3.0 - 1.5;
      float d2 = sin(worldTime * 3.14159265358979323846264 / (192.0 * speed)) * 3.0 - 1.5;
      float d3 = sin(worldTime * 3.14159265358979323846264 / (142.0 * speed)) * 3.0 - 1.5;
      position.x += sin((worldTime * 3.14159265358979323846264 / (16.0 * speed)) + (position.x + d0)*0.5 + (position.z + d1)*0.5 + (position.y)) * magnitude;
      position.z += sin((worldTime * 3.14159265358979323846264 / (18.0 * speed)) + (position.z + d2)*0.5 + (position.x + d3)*0.5 + (position.y)) * magnitude;
    }

    //small scale movement
    if(mc_Entity.x == 106.0 && texcoord.t < 0.20) {
      float speed = WAVING_VINES_SPEED * dynWeatherScaler;
      float magnitude = (sin(((position.y + position.x)/8.0 + worldTime * 3.14159265358979323846264 / ((88.0)))) * 0.15 + 0.05) * 0.22;
      float d0 = sin(worldTime * 3.14159265358979323846264 / (112.0 * speed)) * 3.0 + 0.5;
      float d1 = sin(worldTime * 3.14159265358979323846264 / (142.0 * speed)) * 3.0 + 0.5;
      float d2 = sin(worldTime * 3.14159265358979323846264 / (112.0 * speed)) * 3.0 + 0.5;
      float d3 = sin(worldTime * 3.14159265358979323846264 / (142.0 * speed)) * 3.0 + 0.5;
      position.x += sin((worldTime * 3.14159265358979323846264 / (18.0 * speed)) + (-position.x + d0)*1.6 + (position.z + d1)*1.6) * magnitude;
      position.z += sin((worldTime * 3.14159265358979323846264 / (18.0 * speed)) + (position.z + d2)*1.6 + (-position.x + d3)*1.6) * magnitude;
      position.y += sin((worldTime * 3.14159265358979323846264 / (11.0 * speed)) + (position.z + d2) + (position.x + d3)) * (magnitude/4.0);
    }
  #endif

	#ifdef WAVING_LILIES
    //flowing water
    if(mc_Entity.x == 111.0 && texcoord.t > 0.05) {
      float speed = 2.7 * dynWeatherScaler;
      float magnitude = (sin((worldTime * 3.14159265358979323846264 / ((28.0) * speed))) * 0.05 + 0.15) * 0.17;
      float d0 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
      float d1 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
      float d2 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
      float d3 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
      position.x += sin((worldTime * 3.14159265358979323846264 / (13.0 * speed)) + (position.x + d0)*0.9 + (position.z + d1)*0.9) * magnitude;
      position.y += sin((worldTime * 3.14159265358979323846264 / (15.0 * speed)) + (position.z + d2) + (position.x + d3)) * magnitude;
      position.y -= 0.04;
    }

    //still water
    if(mc_Entity.x == 111.0 && texcoord.t > 0.05) {
      float speed = 2.7 * dynWeatherScaler;
      float magnitude = (sin((worldTime * 3.14159265358979323846264 / ((28.0) * speed))) * 0.05 + 0.15) * 0.17;
      float d0 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
      float d1 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
      float d2 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
      float d3 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
      position.x += sin((worldTime * 3.14159265358979323846264 / (13.0 * speed)) + (position.x + d0)*0.9 + (position.z + d1)*0.9) * magnitude;
      position.y += sin((worldTime * 3.14159265358979323846264 / (15.0 * speed)) + (position.z + d2) + (position.x + d3)) * magnitude;
      position.y -= 0.04;
    }
  #endif

  #ifdef WAVING_LAVA
    if(mc_Entity.x == 10.0 || mc_Entity.x == 11.0 ) {
      position.xyz += calcLavaMove(position.xyz + cameraPosition) * 0.25;
    }
  #endif

	vec4 locposition = gl_ModelViewMatrix * gl_Vertex;

	distance = sqrt(locposition.x * locposition.x + locposition.y * locposition.y + locposition.z * locposition.z);

	position.xyz -= cameraPosition.xyz;

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

	color = gl_Color;

	gl_FogFragCoord = gl_Position.z;

	normal = normalize(gl_NormalMatrix * gl_Normal);
	worldNormal = gl_Normal;

	#ifdef OLD_LIGHTING_FIX
	  if(worldNormal.x > 0.85) {
		  color.rgb *= 1.0 / 0.6;
	  }

	  if(worldNormal.x < -0.85) {
		  color.rgb *= 1.0 / 0.6;
	  }

	  if(worldNormal.z > 0.85) {
		  color.rgb *= 1.0 / 0.8;
	  }

	  if(worldNormal.z < -0.85) {
		  color.rgb *= 1.0 / 0.8;
	  }

	  if (worldNormal.y < -0.85) {
		  color.rgb *= 1.0 / 0.5;
	  }
	#endif

  tangent			= normalize(gl_NormalMatrix * at_tangent.xyz );
	binormal		= normalize(gl_NormalMatrix * -cross(gl_Normal, at_tangent.xyz));

	tbnMatrix		= mat3(tangent.x, binormal.x, normal.x,
						   tangent.y, binormal.y, normal.y,
						   tangent.z, binormal.z, normal.z);

	vertexPos = gl_Vertex;
}
