#version 120
/*
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
*/

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
//go to line 96 for changing sunlight/ambient color balance

varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 sunlight_color;
varying vec3 ambient_color;
varying float handItemLight;
varying float eyeAdapt;

uniform ivec2 eyeBrightnessSmooth;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform int heldItemId;
uniform int heldBlockLightValue;
uniform float rainStrength;
uniform float wetness;


	////////////////////sunlight color////////////////////
	////////////////////sunlight color////////////////////
	////////////////////sunlight color////////////////////
	const ivec4 ToD[25] = ivec4[25](ivec4(0,1,1,1), //hour,r,g,b
							ivec4(1,1,1,1),
							ivec4(2,1,1,1),
							ivec4(3,1,1,1),
							ivec4(4,1,1,1),
							ivec4(5,1,1,1),
							ivec4(6,120,80,35),
							ivec4(7,255,135,40),
							ivec4(8,255,150,40),
							ivec4(9,255,150,40),
							ivec4(10,255,155,40),
							ivec4(11,255,165,40),
							ivec4(12,255,165,40),
							ivec4(13,255,165,40),
							ivec4(14,255,155,40),
							ivec4(15,255,150,40),
							ivec4(16,255,150,40),
							ivec4(17,255,145,40),
							ivec4(18,150,67,40),
							ivec4(19,1,1,1),
							ivec4(20,1,1,1),
							ivec4(21,1,1,1),
							ivec4(22,1,1,1),
							ivec4(23,1,1,1),
							ivec4(24,1,1,1));

	////////////////////ambient color////////////////////
	////////////////////ambient color////////////////////
	////////////////////ambient color////////////////////
	const ivec4 ToD2[25] = ivec4[25](ivec4(0,2,4,9), //hour,r,g,b
							ivec4(1,2,4,9),
							ivec4(2,2,4,9),
							ivec4(3,2,4,9),
							ivec4(4,2,4,9),
							ivec4(5,2,4,9),
							ivec4(6,160,200,255),
							ivec4(7,160,205,255),
							ivec4(8,160,210,260),
							ivec4(9,165,220,270),
							ivec4(10,190,235,280),
							ivec4(11,205,250,290),
							ivec4(12,220,250,300),
							ivec4(13,205,250,290),
							ivec4(14,190,235,280),
							ivec4(15,165,220,270),
							ivec4(16,150,210,260),
							ivec4(17,140,200,255),
							ivec4(18,120,140,220),
							ivec4(19,50,50,50),
							ivec4(20,2,4,9),
							ivec4(21,2,4,9),
							ivec4(22,2,4,9),
							ivec4(23,2,4,9),
							ivec4(24,2,4,9));

//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
void main() {
	
	gl_Position = ftransform();
	
	texcoord = gl_MultiTexCoord0;

	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = normalize(sunPosition);
	}
	
	else {
		lightVector = normalize(moonPosition);
	}

	handItemLight = 0.0;
	if (heldItemId == 50) {
		// torch
		handItemLight = 0.5;
	}
	
	else if (heldItemId == 76 || heldItemId == 94) {
		// active redstone torch / redstone repeater
		handItemLight = 0.1;
	}
	
	else if (heldItemId == 89) {
		// lightstone
		handItemLight = 0.6;
	}
	
	else if (heldItemId == 10 || heldItemId == 11 || heldItemId == 51) {
		// lava / lava / fire
		handItemLight = 0.5;
	}
	
	else if (heldItemId == 91) {
		// jack-o-lantern
		handItemLight = 0.6;
	}
	
	
	else if (heldItemId == 327) {
		handItemLight = 0.2;
	}

	

	float hour = worldTime/1000.0+6.0;
	if (hour > 24.0) hour = hour - 24.0;

							
	ivec4 temp = ToD[int(floor(hour))];
	ivec4 temp2 = ToD[int(floor(hour)) + 1];
	
	sunlight_color = mix(vec3(temp.yzw),vec3(temp2.yzw),(hour-float(temp.x))/float(temp2.x-temp.x))/255.0f;
	
	

							
	ivec4 tempa = ToD2[int(floor(hour))];
	ivec4 tempa2 = ToD2[int(floor(hour)) + 1];
	
	ambient_color = mix(vec3(tempa.yzw),vec3(tempa2.yzw),(hour-float(tempa.x))/float(tempa2.x-tempa.x))/255.0f;
	
	vec3 ambient_color_rain = vec3(0.2, 0.2, 0.2); //rain

	//ambient_color.g *= 1.2;
	ambient_color = sqrt(pow(mix(ambient_color, ambient_color_rain, rainStrength*0.75),vec3(2.0))*2.0*ambient_color); //rain
	
	eyeAdapt = (2.0-min(length(ambient_color),eyeBrightnessSmooth.y/240.0*1.7));
	
}
