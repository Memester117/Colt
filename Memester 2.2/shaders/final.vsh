#version 120


/*
		@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
		@##############################################################@	
		@#															  #@
		@#		[][][][][] [][][][][] [][][][][] [][][][][] []   	  #@
		@#		[]	  	       []     []      [] []	     [] []        #@
		@#		[]	 	       []     []      [] []	     [] []  	  #@
		@#		[]		       []     []      [] []	     [] []     	  #@
		@#		[][][][][]     []     []      [] [][][][][] []   	  #@
		@#				[]     []     []      [] []	        []        #@
		@#				[]     []     []      [] []	        []        #@
		@#				[]     []     []      [] []	           		  #@
		@#		[][][][][]     []     [][][][][] []	        []        #@
		@#															  #@
		@##############################################################@
		@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
		
		
		BEFORE DO ANYTHING, READ THIS AGREEMENT FIRST :
		
		
		YOU ARE ALLOWED TO :
		
		- Make videos or pictures with my shaderpack
		- Modify it only for yourself
		- Earn money with it from your YouTube Videos
		- Share my shaderpack link
		
		YOU ARE NOT ALLOWED TO :
		
		- Rename it and claim my shaderpack as your own
		- Publish your modifications
*/

/*
Werrus HFPS shaders, derived from Chocapic13 V4
*/

varying vec4 texcoord;
varying vec3 sunlight;

uniform int worldTime;
uniform float rainStrength;

	const ivec4 ToD[25] = ivec4[25](ivec4(0,15,30,70), //hour,r,g,b
							ivec4(1,15,30,70),
							ivec4(2,15,30,70),
							ivec4(3,15,30,70),
							ivec4(4,15,30,70),
							ivec4(5,50,60,80),
							ivec4(6,255,190,70),
							ivec4(7,255,195,80),
							ivec4(8,255,200,97),
							ivec4(9,255,200,110),
							ivec4(10,255,205,125),
							ivec4(11,255,215,140),
							ivec4(12,255,215,140),
							ivec4(13,255,215,140),
							ivec4(14,255,205,125),
							ivec4(15,255,200,110),
							ivec4(16,255,200,97),
							ivec4(17,255,195,80),
							ivec4(18,255,190,70),
							ivec4(19,77,67,194),
							ivec4(20,15,30,70),
							ivec4(21,15,30,70),
							ivec4(22,15,30,70),
							ivec4(23,15,30,70),
							ivec4(24,15,30,70));
							
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////

void main() {
	
	gl_Position = ftransform();
	
	texcoord = gl_MultiTexCoord0;
	
	//sunlight color
	float hour = worldTime/1000.0+6.0;
	if (hour > 24.0) hour = hour - 24.0;

							
	ivec4 temp = ToD[int(floor(hour))];
	ivec4 temp2 = ToD[int(floor(hour)) + 1];
	
	sunlight= mix(vec3(temp.yzw),vec3(temp2.yzw),(hour-float(temp.x))/float(temp2.x-temp.x))/255.0f;
}
