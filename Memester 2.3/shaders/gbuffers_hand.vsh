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
varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 normal;

attribute vec4 mc_Entity;

uniform int worldTime;
uniform float rainStrength;

//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////
//////////////////////////////main//////////////////////////////

void main() {
	
	texcoord = gl_MultiTexCoord0;
	
	vec4 position = gl_Vertex;
	
	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * position);
	
	color = gl_Color;
	
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	
	gl_FogFragCoord = gl_Position.z;
	
	normal = normalize(gl_NormalMatrix * gl_Normal);
	
}