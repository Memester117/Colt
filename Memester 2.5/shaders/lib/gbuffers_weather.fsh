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

uniform sampler2D texture;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	
/* DRAWBUFFERS:7 */
	
	vec4 tex = texture2D(texture, texcoord.xy)*color;
	gl_FragData[0] = tex;
}