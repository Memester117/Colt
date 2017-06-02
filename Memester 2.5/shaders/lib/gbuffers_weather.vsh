#version 120

/*
############   #############   ##############   ############# 
############   #############   ##############   #############
###                 ###        ###        ###   ###       ###
###                 ###        ###        ###   ###       ###
############        ###        ###        ###   #############
############        ###        ###        ###   #############
         ###        ###        ###        ###   ###
         ###        ###        ###        ###   ###
############        ###        ##############   ###
############        ###        ##############   ###

/*

- Before you adjust variables below, please read Chocapic13's Sharing and Modification Rules HERE:
http://www.minecraftforum.net/forums/mapping-and-modding/minecraft-mods/1293898-chocapic13s-shaders

*- Basically all code in this shader Belongs to Chocapic13, I used his shader as a base.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
BASE VERSION: Chocapic13's V5TEST2
SHADER VERSION: 2.02 Beta
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SeaMatis's Shaders Rules:
-You are NOT permitted to use this shader as a base,due to the fact that my shader is not "my own" or "Independent" from Chocapic13's shader
-No taking and reuploading to the internet as yours
-No using monetizing links on my shader
However, you ARE allowed to make videos of my shader, just remember to credit me, and Chocapic13

*/

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	
	gl_Position = ftransform();
	
	color = gl_Color;
	
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
}